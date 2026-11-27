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
	}

## The ONLY way to damage an enemy (GDD §3.7 order). Returns the damage taken.
## A hit on a sleeping enemy wakes its pack (room-generation §3.5).
func hurt(hit: Hit) -> float:
	if dead:
		return 0.0
	var view := hit_view()
	var dmg := DamageRules.final(hit, view, Tune.data)
	hp -= dmg
	flash = Tune.f("enemy_flash_time")
	if hit.kind != Hit.Kind.TICK:
		kb = DamageRules.knockback(hit, view, Tune.data)
		numbers.append({ "v": roundi(dmg), "t": Tune.f("damage_number_time"), "x": rng.randf_range(-10.0, 10.0) if rng else 0.0 })
	if hit.stun > 0.0:
		stun = maxf(stun, hit.stun * (Tune.f("boss_stun_mult") if boss else 1.0))
	damaged.emit(self, dmg, hit)
	_after_hurt(hit)
	if asleep:
		_wake_my_pack()
	if hp <= 0.0:
		hp = 0.0
		dead = true
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
	if room_w > 0.0:
		var m := w / 2.0 + Tune.f("wall_margin")
		position.x = clampf(position.x, m, room_w - m)
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

## Two glowing eyes of the kind's colour; closed slits while asleep.
func _draw_eyes(a: Vector2, b: Vector2, size: float) -> void:
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
	for n: Dictionary in numbers:
		draw_string(font, Vector2(n.x - 8, -h - 26 - (life - n.t) * 60.0), str(n.v), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.5, n.t / life))

## Wind-up glow behind the body; call first in _draw().
func _draw_windup_glow() -> void:
	if is_winding():
		_draw_glow(center() - position, Tune.f("windup_glow_r"), Color(1.0, 0.85, 0.6), Tune.f("windup_glow_a"))
