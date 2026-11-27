## Base class of every enemy (ADR-0002). Node2D with its own simple kinematics,
## origin at the feet, hit box is a Rect2 (no Area2D, not a PhysicsBody2D).
## ALL damage to an enemy goes through hurt(hit); never write `hp` from outside.
## A subclass sets its stats in _load_stats(), writes _behave() and its drawing;
## do not override _ready() or _physics_process().
## Kinds with a state machine keep it in think(dt, hero_pos), which reads no
## nodes, so a unit test can drive it tick by tick (tests/unit/enemies/).
## GDD: movement-and-combat §3.7-3.9, enemies-and-elites §3.1, room-generation §3.5.
@abstract
class_name Enemy
extends Node2D

## Emitted after every hurt() that went through (amount may be 0 on a full block).
signal damaged(enemy: Enemy, amount: float, hit: Hit)
## Emitted once, when hp reaches 0.
signal died(enemy: Enemy, hit: Hit)
## Emitted when the enemy wakes up (its pack was woken).
signal woke(enemy: Enemy)

## Key of the kind in the enemy table.
var kind_id: String = ""
## The kind's row of enemies.json. Set before setup() to inject a test fixture;
## left empty, setup() reads Tune.row("enemies", kind_id).
var stats: Dictionary = {}
## Hit box size, px. Origin at the feet.
var w: float = 0.0
var h: float = 0.0
var flies: bool = false
var dead: bool = false
var boss: bool = false
var hp: float = 0.0
var max_hp: float = 0.0
## Weight (F7, F8): knockback and launch are divided by it.
var weight: float = 1.0
## k_target of F8 for this kind (1 for ordinary enemies).
var kb_scale: float = 1.0
## Fraction of knockback speed kept per second (F9).
var drag: float = 0.002
## True for kinds with a front shield (sentry, knight on guard).
var front_shield: bool = false
## Facing, -1 or 1. Front shields block hits from this side.
var face: int = 1
## Seconds of stun left. A stunned enemy does not _behave().
var stun: float = 0.0
## Own movement, px/s (set by the kind's behaviour).
var vel: Vector2 = Vector2.ZERO
## Horizontal knockback speed, px/s; added to vel.x and decays by `drag`.
var kb: float = 0.0
## Seconds of the white hit flash left.
var flash: float = 0.0
## Floating damage numbers: {v: int, t: float, x: float}.
var numbers: Array[Dictionary] = []
## The combat scene root (hitstop owner). Injected by whoever spawns the enemy.
var world: World
## The hero to act on. Injected in tests; otherwise world.player.
var target: Player
## Location tier 1..5 (GDD §3.5 multipliers). Set before setup().
var tier: int = 1
## Room width for the wall clamp; 0 = no walls (tests).
var room_w: float = 0.0
## Sleeping enemies do nothing until their pack wakes (room-generation §3.5).
var asleep: bool = false
## Pack index in the room; -1 = no pack (wakes alone).
var pack: int = -1
## Name of the current state of the kind's state machine ("walk", "wind"...).
var st: String = "idle"
## State timer and attack cooldown, s (counted down by think()).
var t: float = 0.0
var cd: float = 0.0
## Seconds alive, drives bobbing and flapping.
var anim: float = 0.0
## Seconds left of the "!" shown on waking.
var alert: float = 0.0
## Draws the state name above the enemy (AI debugging).
var show_state: bool = false
## Random stream of this enemy (seeded by the spawner, or by a test).
var rng: RandomNumberGenerator
## Shots fired while not in a world (tests read and free them).
var orphan_shots: Array[EnemyShot] = []
## Eye points in local space recorded by the last _draw_eyes() (light_spots()).
var eye_pts: Array[Vector2] = []
var eye_size: float = 0.0
## God statuses on this enemy (gods-and-runes §3.7). Created in setup().
var status: StatusSet = StatusSet.new()
## Seconds until the next wall / enemy slam may count (movement-and-combat §3.8).
var wall_cd: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	setup()

## Loads the kind's stats, applies the tier multiplier and sets the first timers
## (GDD §3.1). Called by _ready(); tests call it directly on a node outside the tree.
func setup() -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_load_stats()
	max_hp *= tier_mult(tier, Tune.f("tier_hp"))
	hp = max_hp
	t = _range("enemy_first_t")
	cd = _range("enemy_first_cd")

## Sets w, h, max_hp, weight, flies... of the kind. Called once from setup().
@abstract func _load_stats() -> void

## The kind's behaviour for one tick; the base class does the rest.
@abstract func _behave(dt: float) -> void

## Hook after damage is applied and before the death check (dummy refill).
func _after_hurt(_hit: Hit) -> void:
	pass

## Hook called every tick while dead. Default: the body is removed.
func _dead_tick(_dt: float) -> void:
	remove_from_group("enemies")
	queue_free()

## True while the kind is telegraphing an attack (wind-up glow, GDD amulet-and-flare).
func is_winding() -> bool:
	return false

## Touch damage to the hero right now, before tier multipliers (0 = harmless).
func contact_damage() -> float:
	return float(stats.get("contact", 0.0))

# ---------------- pure helpers ----------------

## GDD §3.5 / F (enemy hp and damage): 1 + (tier - 1) * per_tier.
static func tier_mult(p_tier: int, per_tier: float) -> float:
	return 1.0 + float(maxi(p_tier, 1) - 1) * per_tier

## room-generation §3.5: wake when the hero is near on both axes, or when hurt.
static func should_wake(delta: Vector2, p_hp: float, p_max_hp: float, range_x: float, range_y: float) -> bool:
	return (absf(delta.x) < range_x and absf(delta.y) < range_y) or p_hp < p_max_hp

## Wakes every sleeping enemy of `pack_id` in `list`; only that pack (§3.5).
static func wake_pack(list: Array, pack_id: int) -> void:
	for n in list:
		var e := n as Enemy
		if e and e.asleep and not e.dead and e.pack == pack_id:
			e.wake()

## Reads a number of the kind's row; missing keys are reported once per call.
func stat(key: String) -> float:
	if not stats.has(key):
		push_error("Enemy %s: missing stat '%s'" % [kind_id, key])
		return 0.0
	return float(stats[key])

## Copies the common fields of the row (w, h, hp, weight, flies, shield).
func _apply_row() -> void:
	if stats.is_empty():
		stats = Tune.row("enemies", kind_id)
	w = stat("w")
	h = stat("h")
	max_hp = stat("hp")
	weight = stat("weight")
	flies = bool(stats.get("flies", false))
	front_shield = bool(stats.get("front_shield", false))
	drag = Tune.f("enemy_drag")

## Random float from a [min, max] pair in tuning.json.
func _range(key: String) -> float:
	var r: Array = Tune.get_value(key)
	return rng.randf_range(float(r[0]), float(r[1]))

## Random float between two stats of the row.
func _stat_range(lo: String, hi: String) -> float:
	return rng.randf_range(stat(lo), stat(hi))

## Damage multiplier to the hero from the tier (GDD F 4.2; ash and armour later).
func dmg_mult() -> float:
	return tier_mult(tier, Tune.f("tier_dmg"))

## Centre of the hit box.
func center() -> Vector2:
	return position - Vector2(0, h / 2.0)

## True when standing on the floor.
func on_ground() -> bool:
	return position.y >= Tune.f("ground_y") - 0.5

## Wakes this enemy: short first decision timer and the "!" sign.
func wake() -> void:
	if not asleep:
		return
	asleep = false
	t = _range("wake_t")
	alert = Tune.f("alert_time")
	woke.emit(self)

## The hero this enemy acts on (null in a bare test).
func hero() -> Player:
	if target:
		return target
	return world.player if world else null

## Position of the hero's feet; own position when there is no hero.
func hero_pos() -> Vector2:
	var p := hero()
	return p.position if p else position

## Hits the hero through Player.hurt (ADR-0002). `dmg` is before tier multipliers.
func hurt_hero(dmg: float, kind: Hit.Kind) -> float:
	var p := hero()
	if p == null:
		return 0.0
	var hit := Hit.make(kind, dmg * dmg_mult(), position.x, 0.0)
	hit.source = self
	return p.hurt(hit)

## Fires a shot from `from` with velocity `v`. In a world it is added to it.
func fire(from: Vector2, v: Vector2, radius: float, dmg: float, life: float) -> EnemyShot:
	var s := EnemyShot.new()
	s.position = from
	s.vel = v
	s.r = radius
	s.dmg = dmg * dmg_mult()
	s.life = life
	s.color = Color(String(stats.get("eye", "#ffffff")))
	s.source = self
	s.world = world
	if world:
		world.add_child(s)
	else:
		orphan_shots.append(s)
	return s

# ---------------- damage ----------------

## Hit box in world space.
func hurt_rect() -> Rect2:
	return Rect2(position.x - w / 2.0, position.y - h, w, h)

## What DamageRules needs to know about this enemy right now.
func hit_view() -> Dictionary:
	return {
		"x": position.x, "face": face, "flies": flies, "boss": boss,
		"airborne": DamageRules.is_airborne(position.y, Tune.f("ground_y"), Tune.f("air_target_margin")),
		"shield": front_shield, "stunned": stun > 0.0, "weight": weight, "kb_scale": kb_scale,
		"burning": status.burning(), "cursed": status.cursed(), "rooted": status.rooted(),
		"clean": not status.has_god_status(),
	}

## The ONLY way to damage an enemy (GDD §3.7 order). Returns the damage taken.
## A hit on a sleeping enemy wakes its pack (room-generation §3.5).
func hurt(hit: Hit) -> float:
	if dead:
		return 0.0
	var view := hit_view()
	var ctx := status_ctx()
	var dmg := DamageRules.final(hit, view, Tune.data)
	hp -= dmg
	flash = Tune.f("enemy_flash_time")
	if hit.kind != Hit.Kind.TICK:
		# Roots hold against knockback, except with Рвущий ветер (gods-and-runes §5).
		if not status.rooted() or (ctx.duos as Dictionary).has("duo_spring"):
			var k := DamageRules.knockback(hit, view, Tune.data)
			if hit.kind != Hit.Kind.STATUS or k != 0.0:
				kb = k
		numbers.append({ "v": roundi(dmg), "t": Tune.f("damage_number_time"), "x": rng.randf_range(-10.0, 10.0) if rng else 0.0 })
	if hit.stun > 0.0:
		stun = maxf(stun, hit.stun * (Tune.f("boss_stun_mult") if boss else 1.0))
	damaged.emit(self, dmg, hit)
	if hit.has_status() or hit.boss_burst_min > 0:
		_apply_statuses(hit, ctx)
	_after_hurt(hit)
	if asleep:
		_wake_my_pack()
	if hp <= 0.0 and not dead:
		hp = 0.0
		dead = true
		_status_death(status_ctx())
		died.emit(self, hit)
		Events.enemy_killed.emit(self, hit)
	return dmg

## Throws the enemy upward (up strike, F7). Flyers and bosses are not launched.
func launch(speed: float) -> void:
	if flies or boss or dead:
		return
	vel.y = -DamageRules.launch_speed(speed, weight)

func _wake_my_pack() -> void:
	if world and pack >= 0:
		world.wake_pack(pack)
	else:
		wake()

# ---------------- tick ----------------

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	if world:
		dt *= world.time_mult()
	anim += dt
	flash -= dt
	alert = maxf(0.0, alert - dt)
	for n: Dictionary in numbers:
		n.t -= dt
	numbers.assign(numbers.filter(func(n: Dictionary) -> bool: return n.t > 0.0))
	if dead:
		_dead_tick(dt)
		queue_redraw()
		return
	wall_cd -= dt
	_tick_status(dt)
	if dead:
		queue_redraw()
		return
	if asleep:
		vel.x = 0.0
		if should_wake(hero_pos() - position, hp, max_hp, Tune.f("aggro_range"), Tune.f("aggro_range_y")) and hero():
			_wake_my_pack()
	elif stun > 0.0:
		stun = maxf(0.0, stun - dt)
		var k := pow(Tune.f("stun_damp"), dt * 60.0)
		vel.x *= k
		if flies:
			vel.y *= k
	else:
		_behave(dt)
	if status.rooted():
		# Roots (§3.7): no walking, no jumping; flyers hang; attacks still allowed.
		vel.x = 0.0
		vel.y = 0.0 if flies else maxf(vel.y, 0.0)
	_move(dt)
	if not asleep and not dead and stun <= 0.0:
		_touch_hero()
	queue_redraw()

## Gravity, movement, floor, flyer band and walls; knockback decay.
func _move(dt: float) -> void:
	var ground := Tune.f("ground_y")
	if not flies:
		vel.y = minf(vel.y + Tune.f("gravity") * dt, Tune.f("max_fall"))
	position += (vel + Vector2(kb, 0.0)) * dt
	if flies:
		position.y = clampf(position.y, Tune.f("flyer_ceiling") + h, ground - Tune.f("flyer_floor"))
	elif position.y >= ground:
		position.y = ground
		vel.y = 0.0
	var at_wall := 0
	if room_w > 0.0:
		var m := w / 2.0 + Tune.f("wall_margin")
		if position.x <= m:
			at_wall = -1
		elif position.x >= room_w - m:
			at_wall = 1
		position.x = clampf(position.x, m, room_w - m)
	_check_slams(at_wall)
	kb *= pow(drag, dt)

## Touch damage (GDD §3.1): only awake, not stunned enemies with contact > 0.
func _touch_hero() -> void:
	var c := contact_damage()
	var p := hero()
	if c <= 0.0 or p == null or p.dead:
		return
	var pr := Rect2(p.position.x - Player.W / 2.0, p.position.y - Player.H, Player.W, Player.H)
	if pr.intersects(hurt_rect()):
		hurt_hero(c, Hit.Kind.CONTACT)

# ---------------- drawing helpers (placeholder art) ----------------

## Soft light spot (wind-ups and shots glow through darkness, amulet-and-flare §3).
func _draw_glow(at: Vector2, radius: float, c: Color, alpha: float) -> void:
	for i in 6:
		var k := 1.0 - float(i) / 6.0
		draw_circle(at, radius * k, Color(c, alpha * 0.18))

## What glows through the darkness (amulet-and-flare §3.9): Vector4(x, y, radius,
## strength) in world space. Eyes always at full strength; the wind-up adds a
## windup_glow_r spot at windup_glow_a over the body.
func light_spots() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var r := eye_size * Tune.f("eye_glow_mult")
	for p: Vector2 in eye_pts:
		out.append(Vector4(position.x + p.x, position.y + p.y, r, 1.0))
	if is_winding():
		var c := center()
		out.append(Vector4(c.x, c.y, Tune.f("windup_glow_r"), Tune.f("windup_glow_a")))
	return out

## Two glowing eyes of the kind's colour; closed slits while asleep. `flip` is the
## x scale of the current draw transform (kinds that mirror with face pass it),
## so the recorded eye points for light_spots() are in plain local space.
func _draw_eyes(a: Vector2, b: Vector2, size: float, flip: float = 1.0) -> void:
	eye_pts.assign([Vector2(a.x * flip, a.y), Vector2(b.x * flip, b.y)])
	eye_size = size
	var c := Color(String(stats.get("eye", "#ffffff")))
	for p: Vector2 in [a, b]:
		if asleep:
			draw_line(p - Vector2(size, 0), p + Vector2(size, 0), c, 2.0)
		else:
			draw_circle(p, size * 2.2, Color(c, 0.25))
			draw_circle(p, size, c)

## Light outline of the body while winding up.
func _draw_windup_outline(points: PackedVector2Array) -> void:
	if not is_winding():
		return
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(1.0, 0.95, 0.8, 0.9), 3.0)

## Draws the hp bar, the "!" sign, the state name and the damage numbers.
## Call from _draw() with the transform reset.
func _draw_overlay() -> void:
	draw_set_transform(Vector2.ZERO)
	var font: Font = ThemeDB.fallback_font
	var life := Tune.f("damage_number_time")
	if hp < max_hp:
		draw_rect(Rect2(-22, -h - 18, 44, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-22, -h - 18, 44 * maxf(hp, 0.0) / maxf(max_hp, 1.0), 5), Color("#e05a4a"))
	if alert > 0.0:
		draw_string(font, Vector2(-6, -h - 26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#ffd36a"))
	if show_state:
		draw_string(font, Vector2(-30, -h - 52), "%s %.2f" % ["zz" if asleep else st, t], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 1, 0.9))
	_draw_status(font)
	for n: Dictionary in numbers:
		draw_string(font, Vector2(n.x - 8, -h - 26 - (life - n.t) * 60.0), str(n.v), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.5, n.t / life))

## Wind-up glow behind the body; call first in _draw().
func _draw_windup_glow() -> void:
	if is_winding():
		_draw_glow(center() - position, Tune.f("windup_glow_r"), Color(1.0, 0.85, 0.6), Tune.f("windup_glow_a"))

# ---------------- god statuses (gods-and-runes §3.7-3.9, §3.11, §3.14) ----------------

## Build context of the hero (RunBuild.ctx) or the base one without a hero.
func status_ctx() -> Dictionary:
	var p := hero()
	if p and p.build:
		return p.build.ctx(Tune.data)
	return StatusSet.default_ctx(Tune.data)

## Colour of a god (gods.json), white for an unknown id.
static func god_colour(god: String) -> Color:
	var r: Dictionary = Tune.table("gods").get(god, {})
	return Color(String(r.get("colour", "#ffffff")))

func _say(text: String, god: String, always: bool = false) -> void:
	status.say(text, god, Tune.f("status_word_time"), Tune.f("status_word_cd"), always)

## A status-made hit on this enemy (discharge, burst, burn tick, duo effects).
func _status_hit(kind: Hit.Kind, dmg: float, ctx: Dictionary) -> Hit:
	var h := Hit.make(kind, dmg, position.x, 0.0)
	h.nested = true
	h.mods = (ctx.get("mods", {}) as Dictionary).duplicate()
	h.source = hero()
	return h

## Puts the statuses carried by `hit` on this enemy (§3.7 "Повторное наложение").
func _apply_statuses(hit: Hit, ctx: Dictionary) -> void:
	var duos: Dictionary = ctx.get("duos", {})
	if status.add_burn(hit.burn) or hit.burn > 0.0:
		_say("ГОРИТ", "svarog")
	if hit.curse > 0.0:
		status.add_curse(hit.curse)
		_say("ПРОКЛЯТ", "veles")
	if hit.root > 0.0:
		var dur := hit.root * float(ctx.get("root_mult", 1.0)) * (Tune.f("boss_root_mult") if boss else 1.0)
		if status.add_root(dur, Tune.f("root_immune")):
			_say("ОПЛЕТЁН", "zhiva")
		else:
			status.add_fx("dry", Tune.f("status_fx_time"))
	if hit.cuts > 0:
		var added := status.add_cuts(hit.cuts, int(Tune.f("cut_max")), Tune.f("cut_time"))
		_say("ПОРЕЗ %d" % status.cuts, "stribog", true)
		if added > 0 and duos.has("duo_naviwind"):
			status.add_curse(Tune.f("curse_time") * float((duos["duo_naviwind"] as Dictionary).get("curse", 0.5)))
			_say("ПРОКЛЯТ", "veles")
		if boss and hit.boss_burst_min > 0 and status.cuts >= hit.boss_burst_min:
			cut_burst(1.0)
	if hit.shock > 0:
		var need := int(ctx.get("shock_need", 3))
		var fire := status.add_shock(hit.shock, need)
		if not fire:
			_say("ЗАРЯД %d/%d" % [status.shock, need], "perun", true)
		elif not dead:
			discharge(false, hit.extra_jumps)
	if hit.discharge and not dead:
		discharge(false, hit.extra_jumps)

## Perun's discharge (§3.8, F3). `fed` = the last charge came from the
## Огненная гроза feed: no jumps, only this enemy is set on fire (loop cap).
func discharge(fed: bool, extra: int = 0) -> void:
	var ctx := status_ctx()
	var duos: Dictionary = ctx.get("duos", {})
	status.shock = 0
	var jumps := StatusSet.discharge_jumps(ctx, fed, status.rooted(), extra, int(Tune.f("shock_jumps")))
	var chain: Array[Enemy] = [self]
	if jumps > 0 and is_inside_tree():
		var others: Array[Enemy] = []
		var pts: Array[Vector2] = []
		for n in get_tree().get_nodes_in_group("enemies"):
			var o := n as Enemy
			if o and o != self and not o.dead:
				others.append(o)
				pts.append(o.center())
		for i in StatusSet.chain(center(), pts, jumps, Tune.f("shock_jump_r")):
			chain.append(others[i])
	var black := float((duos.get("duo_black", {}) as Dictionary).get("dmg_mult", 0.0))
	var prev := center()
	for i in chain.size():
		var e := chain[i]
		var h := _status_hit(Hit.Kind.STATUS, StatusSet.discharge_dmg(Tune.f("shock_dmg"), i,
			e.status.cursed(), black, Tune.f("shock_jump_mult")), ctx)
		if duos.has("duo_firestorm") and (i == 0 or not fed):
			h.burn = Tune.f("burn_time")
		if duos.has("duo_black"):
			h.curse = Tune.f("curse_time") * float((duos["duo_black"] as Dictionary).get("curse", 0.6))
		if duos.has("duo_lifebolt"):
			h.root = Tune.f("root_time") * float((duos["duo_lifebolt"] as Dictionary).get("root", 0.5))
		e.status.add_fx("bolt", Tune.f("status_fx_time"), prev)
		e._say("РАЗРЯД", "perun", true)
		prev = e.center()
		e.hurt(h)

## Stribog's burst (§3.9, F2): all cuts open at once. `k` = Рвущий ветер ×2.
func cut_burst(k: float) -> float:
	var n := status.take_cuts()
	if n <= 0:
		return 0.0
	status.add_fx("burst", Tune.f("status_fx_time") * 1.5)
	_say("ВСКРЫТ", "stribog", true)
	return hurt(_status_hit(Hit.Kind.STATUS, StatusSet.burst_dmg(Tune.f("cut_burst"), n, k), status_ctx()))

## One status tick: burn damage, firestorm feed, firewind spread.
func _tick_status(dt: float) -> void:
	var ctx := status_ctx()
	var r := status.tick(dt, Tune.data, ctx)
	if float(r.burn) > 0.0:
		hurt(_status_hit(Hit.Kind.TICK, float(r.burn), ctx))
	if dead:
		return
	if bool(r.feed) and status.add_shock(1, int(ctx.get("shock_need", 3))):
		discharge(true)
	elif bool(r.feed):
		_say("ЗАРЯД %d/%d" % [status.shock, int(ctx.get("shock_need", 3))], "perun", true)
	if bool(r.firewind):
		var fw: Dictionary = (ctx.duos as Dictionary)["duo_firewind"]
		_burn_around(float(fw.get("r", 180.0)), Tune.f("burn_time") * float(fw.get("burn", 0.7)), ctx)

## Enemies around this one (alive, not self) within `r` of its centre.
func _around(r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group("enemies"):
		var o := n as Enemy
		if o and o != self and not o.dead and o.center().distance_to(center()) <= r:
			out.append(o)
	return out

func _burn_around(r: float, dur: float, ctx: Dictionary) -> void:
	for o in _around(r):
		var h := _status_hit(Hit.Kind.TICK, 0.0, ctx)
		h.burn = dur
		o.hurt(h)

## statusDeath (§3.11 death duos). Boss deaths of the room skip this (caller).
func _status_death(ctx: Dictionary) -> void:
	var duos: Dictionary = ctx.get("duos", {})
	if duos.has("duo_pyre") and status.cursed() and status.burning():
		var brow: Dictionary = Tune.table("enemies").get("bloat", {})
		var dmg := float(brow.get("dmg", 22.0)) * float((duos["duo_pyre"] as Dictionary).get("dmg_mult", 2.0))
		status.add_fx("burst", Tune.f("status_fx_time") * 1.5)
		for o in _around(float(brow.get("radius", 125.0))):
			o.hurt(_status_hit(Hit.Kind.STATUS, dmg, ctx))
	if duos.has("duo_cleanse") and status.rooted() and status.burning():
		_burn_around(float((duos["duo_cleanse"] as Dictionary).get("r", 150.0)), Tune.f("burn_time"), ctx)
	if duos.has("duo_cycle") and status.cursed():
		for o in _around(float((duos["duo_cycle"] as Dictionary).get("r", 200.0))):
			var h := _status_hit(Hit.Kind.TICK, 0.0, ctx)
			h.root = Tune.f("root_time")
			o.hurt(h)

## movement-and-combat §3.8 F10/F11: wall slam and enemy-into-enemy ("кегли").
## Both open Stribog cuts (gods-and-runes §3.9). Bosses and the dummy take no part.
func _check_slams(at_wall: int) -> void:
	if boss or kind_id == "dummy" or wall_cd > 0.0 or absf(kb) <= Tune.f("wall_slam_speed"):
		return
	var spring := (status_ctx().duos as Dictionary).has("duo_spring") and status.rooted()
	if at_wall != 0 and signi(int(signf(kb))) == at_wall:
		var speed := absf(kb)
		wall_cd = Tune.f("wall_slam_cd")
		if spring:
			status.break_roots()
		cut_burst(2.0 if spring else 1.0)
		var h := Hit.make(Hit.Kind.WALL, Tune.f("wall_slam_dmg") * speed / Tune.f("wall_slam_speed"), position.x, 0.0)
		h.stun = Tune.f("wall_slam_stun")
		hurt(h)
		kb = -signf(at_wall) * speed * Tune.f("wall_bounce")
		if world:
			world.request_hitstop(Tune.f("wall_slam_hitstop"))
			world.add_shake(Tune.f("wall_slam_shake"))
		return
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("enemies"):
		var o := n as Enemy
		if o == null or o == self or o.dead or o.boss or o.kind_id == "dummy" or o.wall_cd > 0.0:
			continue
		if not o.hurt_rect().intersects(hurt_rect()):
			continue
		var speed := absf(kb)
		var dir := signf(kb)
		wall_cd = Tune.f("wall_slam_cd")
		o.wall_cd = Tune.f("wall_slam_cd")
		var o_spring := spring or ((status_ctx().duos as Dictionary).has("duo_spring") and o.status.rooted())
		if o_spring:
			o.status.break_roots()
		o.cut_burst(2.0 if o_spring else 1.0)
		cut_burst(2.0 if spring else 1.0)
		var ho := Hit.make(Hit.Kind.WALL, Tune.f("kegli_mult") * Tune.f("wall_slam_dmg"), o.position.x - dir, speed * Tune.f("kegli_kb") * weight)
		ho.stun = Tune.f("kegli_stun")
		o.hurt(ho)
		hurt(Hit.make(Hit.Kind.WALL, Tune.f("kegli_mult") * Tune.f("wall_slam_dmg"), position.x, 0.0))
		kb = dir * speed * Tune.f("kegli_keep")
		return

## Status visuals (§3.14) and the words, drawn by _draw_overlay().
func _draw_status(font: Font) -> void:
	var c := center() - position
	var top := -h
	if status.cursed():
		var vc := god_colour("veles")
		draw_circle(c, maxf(w, h) * 0.7, Color(vc, 0.18))
		for i in 3:
			draw_arc(c, maxf(w, h) * 0.55 + i * 6.0, -PI * 0.9 + anim * 1.5 + i, -PI * 0.3 + anim * 1.5 + i, 10, Color(vc, 0.8), 2.0)
	if status.burning():
		var fc := god_colour("svarog")
		for i in 4:
			var x := -w * 0.4 + w * 0.8 * float(i) / 3.0
			var fh := 14.0 + 6.0 * sin(anim * 14.0 + i * 1.7)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 6, top * 0.35), Vector2(x, top * 0.35 - fh - 10), Vector2(x + 6, top * 0.35)]), Color(fc, 0.85))
	if status.shock > 0:
		var pc := god_colour("perun")
		for i in 2 + status.shock:
			var a := anim * 7.0 + i * TAU / float(2 + status.shock)
			var p0 := c + Vector2(cos(a), sin(a)) * maxf(w, h) * 0.45
			var p1 := p0 + Vector2(cos(a + 1.2), sin(a + 1.2)) * 9.0
			var p2 := p1 + Vector2(cos(a - 0.6), sin(a - 0.6)) * 9.0
			draw_polyline(PackedVector2Array([p0, p1, p2]), pc, 2.0)
	for i in status.cuts:
		var y := top * 0.8 + i * (h * 0.6 / 5.0)
		draw_line(Vector2(-w * 0.35, y), Vector2(w * 0.35, y + 10), Color("#e0303a"), 3.0)
	if status.cuts > 0:
		draw_circle(Vector2(w * 0.25, top * 0.2 + fmod(anim * 40.0, 20.0)), 2.5, Color("#c01a24"))
	var stems := status.rooted() or status.immune > 0.0
	if stems:
		var gc := god_colour("zhiva") if status.rooted() else Color("#7a5a30")
		for i in 5:
			var x := -w * 0.45 + w * 0.9 * float(i) / 4.0
			draw_polyline(PackedVector2Array([Vector2(x, 0), Vector2(x + 5 * sin(i + anim), top * 0.25), Vector2(x - 3, top * 0.5)]), gc, 3.0)
	for f: Dictionary in status.fx:
		match String(f.kind):
			"bolt":
				var from: Vector2 = (f.to as Vector2) - position
				var pts := PackedVector2Array([from])
				for k in range(1, 6):
					var q := from.lerp(c, float(k) / 6.0)
					pts.append(q + Vector2(sin(k * 7.3 + anim * 30.0) * 10.0, cos(k * 5.1) * 8.0))
				pts.append(c)
				draw_polyline(pts, Color(god_colour("perun"), clampf(f.t * 5.0, 0.0, 1.0)), 4.0)
				draw_polyline(pts, Color(1, 1, 1, clampf(f.t * 5.0, 0.0, 1.0)), 1.5)
			"burst":
				var k2 := 1.0 - float(f.t) / (Tune.f("status_fx_time") * 1.5)
				draw_circle(c, 10.0 + 40.0 * k2, Color(0.9, 0.1, 0.15, 0.6 * (1.0 - k2)))
				for j in 8:
					var a2 := j * TAU / 8.0
					draw_circle(c + Vector2(cos(a2), sin(a2)) * (20.0 + 50.0 * k2), 3.0, Color(0.8, 0.05, 0.1, 1.0 - k2))
			"dry":
				draw_rect(Rect2(-w * 0.5, top * 0.5, w, -top * 0.5), Color(0.5, 0.35, 0.2, 0.4), false, 2.0)
	# Words sit above the damage numbers (which rise from -h - 26 for ~42 px).
	var y0 := -h - 78.0
	for wd: Dictionary in status.words:
		var col := Color(god_colour(String(wd.god)), clampf(float(wd.t) * 3.0, 0.0, 1.0))
		draw_string_outline(font, Vector2(-110, y0), String(wd.text), HORIZONTAL_ALIGNMENT_CENTER, 220, 22, 5, Color(0, 0, 0, col.a))
		draw_string(font, Vector2(-110, y0), String(wd.text), HORIZONTAL_ALIGNMENT_CENTER, 220, 22, col)
		y0 -= 24.0
