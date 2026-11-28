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
## Emitted once per part when a limb is cut (GDD limb-zones §3.4): "arm" or "head"
## (also when the part flies as part of the death, then `dead` is already true).
## The visual hook: the art pass swaps the placeholder LimbPart / LimbMark here.
signal limb_severed(enemy: Enemy, limb: String)

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
## True for kinds with a front shield (shield-bearer, knight on guard).
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
## Level mode (GDD level-structure §3.9): the height of this enemy's own floor
## (NAN = the room's ground_y), the floor span it walks inside ([x0, x1], zero =
## none: the room walls clamp) and whether each end of it is a wall (slams count)
## or a drop it must not walk off. Set by World.spawn_enemy from the LevelRoom.
var floor_y: float = NAN
var span: Vector2 = Vector2.ZERO
var span_wall: Vector2i = Vector2i(1, 1)
## Flyers in level mode keep inside their room's frame (edge case 6); empty = the flyer band.
var fly_box: Rect2 = Rect2()
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
## Ослоп (weapons-and-loot §3.3): {mult, r} while the hero's knockback carries
## this enemy; the next wall slam is ×mult and hits all within r. {} = none.
var slam_boost: Dictionary = {}
## Navi mark of an elite ("" = not an elite; enemies-and-elites §3.6). Set before
## the enemy enters the tree; setup() applies the elite numbers.
var mark: String = ""
## Not a foe (breakable wall): skipped by the room-clear count.
var prop: bool = false
## Colour of the "!" sign (red for the knight).
var alert_colour: Color = Color("#ffd36a")
## Заслон ward left / its size / seconds without damage; Морок timer and fade;
## Пламя drop timer; Зов howl left, enemies called, half-hp call done; Взрыв time since death.
var ward: float = 0.0
var ward_max: float = 0.0
var ward_t: float = 0.0
var blink_t: float = 0.0
var blink_fade: float = 0.0
var trail_t: float = 0.0
var howl: float = 0.0
var called: int = 0
var called_half: bool = false
var called_wake: bool = false
var mark_blast_t: float = 0.0
## Limb zones (GDD limb-zones): the attacking arm / the head is cut off.
var arm_off: bool = false
var head_off: bool = false
## Cut parts spawned while not in a world (tests read and free them).
var orphan_parts: Array[LimbPart] = []
var _limb_mark: LimbMark
## Precise hits landed per limb so far ({"arm": n, "head": n}; tough kinds, elites).
var limb_hits: Dictionary = {}
## Part thrown by the death (§3.5): "head", "arm" or "" (plain death).
var death_severed: String = ""
## Tina shield from Водяница's song (bestiary §3.2, B4): absorbs damage first,
## gone after tina_t s. 0 = none.
var tina: float = 0.0
var tina_t: float = 0.0
## Ice copy raised by Мара (bestiary §3.4): weaker blows (ice_copy_dmg), broken
## at once by a breaking blow, the Flare or a wall slam, plain death, no embers.
var ice_copy: bool = false
## Haste from Лесавка's whistle (bestiary §3.3): moves x haste_mult, cooldowns
## x haste_cd_mult, for haste_t s. 0 = none.
var haste_t: float = 0.0
var haste_mult: float = 1.0
var haste_cd_mult: float = 1.0
## True while a drawn skin (DrawnEnemyVisual) shows this enemy: the kind's own
## _draw() then paints only the wind-up glow and the overlay (_skin_draw()).
var art_skin: bool = false
## The last flying part thrown by _spawn_part (the skin gives it the real sprite).
var last_part: LimbPart

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
	# GDD difficulty F1/F2: hp and wind-ups of the level (identity at «Былина»).
	stats = Difficulty.scale_windups(stats, Difficulty.current, Difficulty.table())
	max_hp *= tier_mult(tier, Tune.f("tier_hp")) * Difficulty.f("enemy_hp")
	if mark != "":
		max_hp *= Tune.f("elite_hp")
		w *= Tune.f("elite_size")
		h *= Tune.f("elite_size")
		if mark == "ward":
			ward_max = max_hp * Tune.f("shield_frac")
			ward = ward_max
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

## Damage multiplier to the hero from the tier and the difficulty (GDD F 4.2,
## difficulty F1; ash and armour later).
func dmg_mult() -> float:
	var m := tier_mult(tier, Tune.f("tier_dmg")) * Difficulty.f("enemy_dmg")
	if ice_copy:
		m *= Tune.f("ice_copy_dmg")
	if status.blinded():
		# Dazhbog (gods-expansion §3.5): a blind enemy hits weaker.
		m *= Tune.f("blind_boss_dmg") if boss else Tune.f("blind_dmg")
	return m * Tune.f("elite_dmg") if mark != "" else m

## Centre of the hit box.
func center() -> Vector2:
	return position - Vector2(0, h / 2.0)

## Height of this enemy's floor: its own floor in a level, else ground_y.
func ground() -> float:
	return Tune.f("ground_y") if is_nan(floor_y) else floor_y

## True when standing on the floor.
func on_ground() -> bool:
	return position.y >= ground() - 0.5

## Wakes this enemy: short first decision timer and the "!" sign.
func wake() -> void:
	if not asleep:
		return
	asleep = false
	t = _range("wake_t") * Difficulty.f("windup")
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
	if p and head_off:
		# Headless (limb-zones §3.3, F5): it swings at where it guesses the hero is.
		return LimbRules.headless_aim(p.position, anim, Tune.f("limb_headless_err"), Tune.f("limb_headless_freq"))
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
		"airborne": DamageRules.is_airborne(position.y, ground(), Tune.f("air_target_margin")),
		"shield": front_shield, "stunned": stun > 0.0, "weight": weight, "kb_scale": kb_scale,
		"burning": status.burning(), "cursed": status.cursed(), "rooted": status.rooted(),
		"clean": not status.has_god_status(),
		"block": float(stats.get("shield_block", Tune.f("sentry_block"))),
		"exposed": status.expose > StatusSet.EPS, "gloomed": status.gloom > StatusSet.EPS, "blind": status.blinded(),
	}

## The ONLY way to damage an enemy (GDD §3.7 order). Returns the damage taken.
## A hit on a sleeping enemy wakes its pack (room-generation §3.5).
func hurt(hit: Hit) -> float:
	if dead:
		return 0.0
	var view := hit_view()
	var ctx := status_ctx()
	var dmg := DamageRules.final(hit, view, Tune.data)
	if ice_copy and FrostRules.copy_breaks(hit.kind, hit.finisher):
		dmg = maxf(dmg, hp + tina + ward)
	# Limb zones (limb-zones §3.2-3.3, F2): the cutting hit is re-checked here, so a
	# part is never cut twice; a plain hit keeps its damage.
	# Only the head is cut by a strike (§3.3); the arm only by a parry (parried()).
	var limb := hit.limb if hit.kind == Hit.Kind.STRIKE and hit.limb == LimbRules.HEAD and limbs_on() and LimbRules.can_cut(hit.limb, limb_row(), arm_off, head_off) else ""
	var nick := 0
	if limb != "" and not _count_limb_hit(limb):
		nick = int(limb_hits[limb])
		limb = ""
	dmg *= LimbRules.bonus_mult(limb, Tune.data)
	if mark == "ward":
		var wa := EliteMarks.ward_absorb(ward, dmg, hit.kind == Hit.Kind.SLAM or hit.kind == Hit.Kind.WALL, Tune.f("shield_break_mult"))
		ward -= wa.x
		ward_t = 0.0
		dmg = wa.y
	if tina > 0.0:
		var ta := SwampRules.tina_absorb(tina, dmg)
		tina -= ta.x
		dmg = ta.y
		if tina <= 0.0:
			tina = 0.0
			tina_t = 0.0
			Audio.play_at(&"ward_break", position)
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
	if dmg > 0.0 and status.thread > StatusSet.EPS and hit.kind != Hit.Kind.TICK and hit.kind != Hit.Kind.SHARE:
		_share_thread(dmg, ctx)
	if limb != "":
		_cut(limb, hit.from_x)
	elif nick > 0:
		_nick(nick)
	if hit.has_status() or hit.boss_burst_min > 0:
		_apply_statuses(hit, ctx)
	_after_hurt(hit)
	if asleep:
		_wake_my_pack()
	if hp <= 0.0 and not dead:
		hp = 0.0
		dead = true
		if limb == "":
			_death_variant(hit)
		_status_death(status_ctx())
		died.emit(self, hit)
		Events.enemy_killed.emit(self, hit)
	return dmg

## Throws the enemy upward (up strike, F7). Flyers and bosses are not launched.
func launch(speed: float) -> void:
	if flies or boss or dead:
		return
	vel.y = -DamageRules.launch_speed(speed, weight)

## Puts a tina shield of `amount` on for `time` s (the larger shield wins, the
## timer restarts). Водяница's song calls it.
func give_tina(amount: float, time: float) -> void:
	tina = maxf(tina, amount)
	tina_t = time

## Hastes this enemy for `time` s (the timer restarts). Лесавка's whistle calls it.
func give_haste(mult: float, cd_mult: float, time: float) -> void:
	haste_mult = mult
	haste_cd_mult = cd_mult
	haste_t = time

func _wake_my_pack() -> void:
	if world and pack >= 0:
		world.wake_pack(pack)
	else:
		wake()

# ---------------- limb zones (GDD limb-zones) ----------------

## The kind's row of limb_zones.json ({} = no zones).
func limb_row() -> Dictionary:
	return Tune.table("limb_zones").get(kind_id, {})

## True when this enemy has limb zones now (never bosses; elites by the knob).
func limbs_on() -> bool:
	return LimbRules.eligible(limb_row(), boss, mark != "", prop, Tune.data)

## The live zones in world space ({"arm": Rect2, "head": Rect2}).
func limb_zones() -> Dictionary:
	if not limbs_on():
		return {}
	return LimbRules.zones(limb_row(), position, w, h, face, arm_off, head_off)

## Which part a hero strike rect cuts: "arm", "head" or "" (limb-zones F1, §3.2-3.3).
func limb_at(strike: Rect2, dir: String, hero_x: float, hero_airborne: bool) -> String:
	if not limbs_on() or dead:
		return ""
	return LimbRules.pick(strike, hurt_rect(), limb_row(), position, w, h, face, dir, hero_x, hero_airborne, st, arm_off, head_off, Tune.data)

## Cuts `limb` (already checked by hurt()): sets the flag, changes the attack,
## throws the part, shows the word, hit-stop and shake, emits limb_severed.
func _cut(limb: String, from_x: float) -> void:
	var row := limb_row()
	var away := 1 if position.x >= from_x else -1
	if limb == LimbRules.ARM:
		arm_off = true
		stats = LimbRules.one_arm_stats(stats, row.get("one_arm", {}))
		if bool(row.get("drops_shield", false)):
			front_shield = false
		# The attack is cancelled: a stagger, then a fresh decision (§3.2).
		st = "idle"
		t = 0.0
		vel.x = 0.0
		stun = maxf(stun, Tune.f("limb_arm_stagger"))
		cd = maxf(cd, Tune.f("limb_arm_recover"))
	else:
		head_off = true
		eye_pts.clear()
	_spawn_part(limb, row, away)
	status.add_fx("burst", Tune.f("status_fx_time") * 1.5)
	_mark().say("Без руки!" if limb == LimbRules.ARM else "Голова с плеч!", Tune.f("limb_word_time"))
	Audio.play_at(&"limb_sever" if limb == LimbRules.ARM else &"limb_head_pop", position)
	if world:
		world.request_hitstop(Tune.f("limb_hitstop"))
		world.add_shake(Tune.f("limb_shake"))
	limb_severed.emit(self, limb)

## Counts one precise hit on `limb` (§3.6); true when this one cuts it.
func _count_limb_hit(limb: String) -> bool:
	limb_hits[limb] = int(limb_hits.get(limb, 0)) + 1
	return LimbRules.cuts_now(int(limb_hits[limb]), LimbRules.hits_needed(limb_row(), mark != "", Tune.data))

## A precise hit that did not cut yet (tough kinds, elites): blood and «Надруб n/N».
func _nick(n: int) -> void:
	status.add_fx("burst", Tune.f("status_fx_time"))
	_mark().say("Надруб %d/%d" % [n, LimbRules.hits_needed(limb_row(), mark != "", Tune.data)], Tune.f("limb_word_time") * 0.6)
	Audio.play_at(&"limb_sever", position, -1, 1.3)

## The hero parried this enemy's melee blow (GDD parry §3.3). Ordinary enemies
## lose the attack and are stunned for parry_stun; the arm flies when the row
## has a cuttable arm and it was attacking (on a tough kind or an elite only on
## the N-th parry). Bosses get parry_boss_stun only. Returns "arm", "nick",
## "stun" or "" (dead).
func parried(from_x: float) -> String:
	if dead:
		return ""
	var s := ParryRules.stun_for(boss, Tune.data)
	if boss:
		stun = maxf(stun, s)
		return "stun"
	var was := st
	var row := limb_row()
	var takes := limbs_on() and LimbRules.parry_takes_arm(row, was, arm_off)
	st = "idle"
	t = 0.0
	vel.x = 0.0
	stun = maxf(stun, s)
	cd = maxf(cd, Tune.f("limb_arm_recover"))
	if not takes:
		return "stun"
	if _count_limb_hit(LimbRules.ARM):
		_cut(LimbRules.ARM, from_x)
		stun = maxf(stun, s)
		return "arm"
	_nick(int(limb_hits[LimbRules.ARM]))
	return "nick"

## The death of an ordinary enemy, one of two (§3.5): plain, or with the head
## or the arm flying (harmless) when the killing blow met that zone or by
## death_sever_chance. Bosses and kinds without a row always die plainly.
func _death_variant(hit: Hit) -> void:
	if not limbs_on() or ice_copy:
		return
	var roll := rng.randf() if rng else 1.0
	var part := LimbRules.death_part(hit.zone, roll, limb_row(), arm_off, head_off, Tune.data)
	if part == "":
		return
	if part == LimbRules.HEAD:
		head_off = true
		eye_pts.clear()
	else:
		arm_off = true
	var p := _spawn_part(part, limb_row(), 1 if position.x >= hit.from_x else -1)
	p.dmg = 0.0
	status.add_fx("burst", Tune.f("status_fx_time") * 1.5)
	Audio.play_at(&"limb_head_pop" if part == LimbRules.HEAD else &"limb_sever", position)
	death_severed = part
	limb_severed.emit(self, part)

## Geometric zone a hero strike rect meets ("head", "arm", "body"; "" = no zones).
func limb_zone_at(strike: Rect2, dir: String, hero_x: float) -> String:
	if not limbs_on() or dead:
		return ""
	return LimbRules.zone_of(strike, hurt_rect(), limb_row(), position, w, h, face, dir, hero_x, arm_off, head_off, Tune.data)

func _mark() -> LimbMark:
	if _limb_mark == null:
		_limb_mark = LimbMark.new()
		_limb_mark.name = "LimbMark"
		_limb_mark.enemy = self
		add_child(_limb_mark)
	return _limb_mark

## The flying piece (placeholder shape in the kind's colours, LimbPart).
func _spawn_part(limb: String, row: Dictionary, away: int) -> LimbPart:
	var part := LimbPart.new()
	part.limb = limb
	part.source = self
	part.world = world
	part.life = Tune.f("limb_part_life")
	var body := Color(String(stats.get("color", "#666666")))
	part.eye = Color(String(stats.get("eye", "#ffffff")))
	if limb == LimbRules.ARM:
		var key := String(row.get("arm_colour", ""))
		part.colour = Color(String(stats[key])) if stats.has(key) else (Color(key) if key.begins_with("#") else body.darkened(0.2))
		var ln := float(row.get("arm_len", 30.0))
		part.poly = PackedVector2Array([Vector2(0, -3), Vector2(ln, -4), Vector2(ln + 4, 0), Vector2(ln, 4), Vector2(0, 3)])
		var rt: Array = row.get("arm_root", [0.3, 0.6])
		part.position = position + Vector2(float(rt[0]) * w * face, -float(rt[1]) * h)
		part.vel = LimbRules.part_velocity(away, Tune.f("limb_arm_speed"), Tune.f("limb_arm_up"))
		part.spin = 9.0 * away
	else:
		var hs: Array = row.head
		var rr := Tune.f("limb_head_r")
		part.r = rr
		part.colour = body.lightened(0.05)
		var pts := PackedVector2Array()
		for i in 10:
			var a := TAU * float(i) / 10.0
			pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.9 - rr * 0.6))
		part.poly = pts
		part.position = position + Vector2((float(hs[0]) + float(hs[1])) * 0.5 * w * face, -float(hs[3]) * h + rr)
		part.vel = LimbRules.part_velocity(away, Tune.f("limb_head_speed"), Tune.f("limb_head_up"))
		part.spin = 7.0 * away
		part.dmg = Tune.f("limb_head_dmg") * dmg_mult()
		part.kb = Tune.f("limb_part_kb")
	if world:
		world.add_child(part)
	else:
		orphan_parts.append(part)
	last_part = part
	return part

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
		if mark == "blast" and mark_blast_t >= 0.0:
			mark_blast_t += dt
			if mark_blast_t < Tune.f("death_blast_delay"):
				queue_redraw()
				return
			_death_blast()
			mark_blast_t = -1.0
		_dead_tick(dt)
		queue_redraw()
		return
	wall_cd -= dt
	if tina_t > 0.0:
		tina_t -= dt
		if tina_t <= 0.0:
			tina = 0.0
	if haste_t > 0.0:
		cd -= ForestRules.haste_cd_extra(dt, haste_t, haste_cd_mult)
		haste_t -= dt
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
	elif mark != "" and _mark_tick(dt):
		pass
	elif status.blinded():
		# Blind (gods-expansion §3.5): wind-ups and steps run slower.
		_behave(dt * (Tune.f("blind_boss_slow") if boss else Tune.f("blind_slow")))
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
	var ground := ground()
	if not flies:
		vel.y = minf(vel.y + Tune.f("gravity") * dt, Tune.f("max_fall"))
	position += (vel * ForestRules.haste_speed(haste_t, haste_mult) + Vector2(kb, 0.0)) * dt
	if flies and fly_box.has_area():
		position = position.clamp(fly_box.position + Vector2(w / 2.0, h), fly_box.end - Vector2(w / 2.0, 0.0))
	elif flies:
		position.y = clampf(position.y, Tune.f("flyer_ceiling") + h, ground - Tune.f("flyer_floor"))
	elif position.y >= ground:
		position.y = ground
		vel.y = 0.0
	var at_wall := 0
	if span.y > span.x and not flies:
		# Level mode: never walk off the own floor span; only a real wall end slams.
		var hw := w / 2.0
		if position.x <= span.x + hw:
			at_wall = -1 if span_wall.x == 1 else 0
		elif position.x >= span.y - hw:
			at_wall = 1 if span_wall.y == 1 else 0
		position.x = clampf(position.x, span.x + hw, maxf(span.x + hw, span.y - hw))
	elif room_w > 0.0:
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

## Cap of the hero's light radius this enemy imposes, px (0 = none; Лихо's
## «гаснет свет», enemies-and-elites §3.10). Darkness takes the smallest cap.
func light_cap() -> float:
	return 0.0

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
	if head_off:
		eye_pts.clear()
		return
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
	if mark != "":
		_draw_mark(font)
	if tina > 0.0:
		# Tina shield: a green contour round the body (bestiary §3.2 Водяница).
		var tc := Color(String(Tune.get_value("tina_colour")))
		var r := Rect2(-w / 2.0 - 5.0, -h - 5.0, w + 10.0, h + 8.0)
		draw_rect(r, Color(tc, 0.18), true)
		draw_rect(r, Color(tc, 0.75 + 0.25 * sin(anim * 6.0)), false, 3.0)
	if ice_copy and not art_skin:
		# Ice copy (bestiary §3.4 Мара): a pale ice contour with glints (a drawn
		# skin shows the copy through ice_copy.gdshader instead).
		var ic := Color(String(Tune.get_value("ice_tint")))
		var ir := Rect2(-w / 2.0 - 4.0, -h - 4.0, w + 8.0, h + 6.0)
		draw_rect(ir, Color(ic, 0.5), true)
		draw_rect(ir, Color(Color.WHITE, 0.7 + 0.3 * sin(anim * 5.0)), false, 3.0)
		for gi in 3:
			var gp := Vector2(-w * 0.3 + gi * w * 0.3, -h * (0.3 + 0.25 * gi))
			draw_line(gp + Vector2(-5, 0), gp + Vector2(5, 0), Color.WHITE, 2.0)
			draw_line(gp + Vector2(0, -5), gp + Vector2(0, 5), Color.WHITE, 2.0)
	if haste_t > 0.0:
		# Haste: rust sparks at the feet (bestiary §3.3 Лесавка).
		var hc := Color(String(Tune.get_value("haste_colour")))
		for i in 5:
			var ph := fmod(anim * 2.5 + i * 0.2, 1.0)
			draw_circle(Vector2((i - 2) * w * 0.22 + sin(anim * 7.0 + i) * 3.0, -ph * 18.0), 2.5 * (1.0 - ph) + 1.0, Color(hc, 1.0 - ph))
	if alert > 0.0:
		draw_string(font, Vector2(-6, -h - 26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, alert_colour)
	if show_state:
		draw_string(font, Vector2(-30, -h - 52), "%s %.2f" % ["zz" if asleep else st, t], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 1, 0.9))
	_draw_status(font)
	for n: Dictionary in numbers:
		draw_string(font, Vector2(n.x - 8, -h - 26 - (life - n.t) * 60.0), str(n.v), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.5, n.t / life))

## Call first in _draw(): with a drawn skin attached (art_skin) paints the
## wind-up glow and the overlay and returns true, so the code body is skipped.
func _skin_draw() -> bool:
	if not art_skin:
		return false
	_draw_windup_glow()
	_draw_overlay()
	return true

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
		_say("ГОРИТ", "kupala")
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
	_apply_timers(hit, ctx)

## The timer statuses of gods-expansion §3.2 (wet, thread, blind, halo, yar,
## gloom, prey, expose), then Kupala's steam and the thread duos.
func _apply_timers(hit: Hit, ctx: Dictionary) -> void:
	var duos: Dictionary = ctx.get("duos", {})
	for st: String in hit.timers:
		var dur := float(hit.timers[st])
		if st == "thread" and status.thread <= StatusSet.EPS:
			_make_thread_room(int(Tune.f("thread_cap")) if hit.ignore_cap else int(ctx.get("thread_max", Tune.f("thread_max"))))
		if status.add_timer(st, dur):
			var g := TIMER_GOD.get(st, "") as String
			_say(String((Tune.table("gods").get(g, {}) as Dictionary).get("word", st.to_upper())), g)
	if status.wet > StatusSet.EPS and status.burning() and status.steam_cd <= StatusSet.EPS and not dead:
		steam(ctx)
	if hit.kind != Hit.Kind.SHARE and status.thread > StatusSet.EPS and not hit.nested:
		var others := _linked()
		if duos.has("duo_fate_fire") and hit.burn > 0.0:
			for o in others:
				o.status.add_burn(Tune.f("burn_time") * float((duos["duo_fate_fire"] as Dictionary).get("burn", 0.5)))
		if duos.has("duo_fate_navi") and hit.curse > 0.0:
			for o in others:
				o.status.add_curse(Tune.f("curse_time") * float((duos["duo_fate_navi"] as Dictionary).get("curse", 0.5)))

## God of each timer status (the word and its colour).
const TIMER_GOD: Dictionary = { "wet": "kupala", "thread": "mokosh", "blind": "dazhbog", "halo": "khors",
	"yar": "yarilo", "gloom": "chernobog", "prey": "semargl", "expose": "svyatovit" }

## Kupala's steam (gods-expansion §3.3): wet comes off, every enemy within
## steam_r (this one too) takes steam_dmg × k_steam, no knockback, no chains.
func steam(ctx: Dictionary) -> void:
	status.wet = 0.0
	status.steam_cd = Tune.f("steam_cd")
	var k := float(ctx.get("steam_k", 1.0)) * _night_k(ctx, "steam")
	status.add_fx("steam", Tune.f("status_fx_time") * 1.4)
	_say("ПАР", "kupala", true)
	var targets: Array[Enemy] = [self]
	targets.append_array(_around(Tune.f("steam_r")))
	for o in targets:
		var h := _status_hit(Hit.Kind.STATUS, Tune.f("steam_dmg") * k, ctx)
		o.hurt(h)

## Купальская ночь (duo_kupala_night): × its `key` when the hero is below half health.
func _night_k(ctx: Dictionary, key: String) -> float:
	var row: Dictionary = (ctx.get("duos", {}) as Dictionary).get("duo_kupala_night", {})
	var p := hero()
	if row.is_empty() or p == null or p.hp >= Tune.f("player_hp") * float(row.get("below", 0.5)):
		return 1.0
	return float(row.get(key, 1.5))

## Other living enemies on a thread (Mokosh).
func _linked() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group("enemies"):
		var o := n as Enemy
		if o and o != self and not o.dead and o.status.thread > StatusSet.EPS:
			out.append(o)
	return out

## Keeps at most `cap` - 1 other threads so this one fits: the thread that ends
## soonest goes first (gods-expansion §3.4).
func _make_thread_room(cap: int) -> void:
	var others := _linked()
	others.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.status.thread < b.status.thread)
	while others.size() >= maxi(cap, 1):
		others[0].status.thread = 0.0
		others.remove_at(0)

## Shared damage along the threads: every other linked enemy takes dmg × share.
func _share_thread(dmg: float, ctx: Dictionary) -> void:
	var share := float(ctx.get("thread_share", Tune.f("thread_share")))
	for o in _linked():
		var h := _status_hit(Hit.Kind.SHARE, dmg * share, ctx)
		h.mods = {}
		o.status.add_fx("thread", Tune.f("status_fx_time"), center())
		o.hurt(h)

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
		if duos.has("duo_blindbolt"):
			h.timers["blind"] = Tune.f("blind_time") * float((duos["duo_blindbolt"] as Dictionary).get("blind", 0.5))
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
	var gd := int(get_meta(&"gloom_depth", 0))
	if status.gloom > StatusSet.EPS and not boss and gd < int(Tune.f("gloom_depth")):
		_gloom_burst(ctx, gd)
	if status.thread > StatusSet.EPS and float(ctx.get("thread_pass", 0.0)) > 0.0:
		for o in _around(float(ctx.thread_pass)):
			if o.status.thread <= StatusSet.EPS:
				o.status.thread = status.thread
				o._say("НИТЬ", "mokosh")
				break
	if duos.has("duo_cycle") and status.cursed():
		for o in _around(float((duos["duo_cycle"] as Dictionary).get("r", 200.0))):
			var h := _status_hit(Hit.Kind.TICK, 0.0, ctx)
			h.root = Tune.f("root_time")
			o.hurt(h)

## Chernobog's burst (gods-expansion §3.8): every enemy within gloom_r takes
## gloom_frac × this one's max hp (≤ gloom_cap); a gloomed enemy it kills bursts
## too, `depth` deep at most gloom_depth. Bosses take it but never burst.
func _gloom_burst(ctx: Dictionary, depth: int) -> void:
	var duos: Dictionary = ctx.get("duos", {})
	var dn: Dictionary = duos.get("duo_dark_navi", {})
	var r := Tune.f("gloom_r") * float(dn.get("r_mult", 1.0))
	var dmg := minf(Tune.f("gloom_cap"), Tune.f("gloom_frac") * max_hp) * float(ctx.get("gloom_mult", 1.0))
	status.add_fx("gloom", Tune.f("status_fx_time") * 1.6)
	if world:
		world.add_ring(center(), r)
	for o in _around(r):
		var h := _status_hit(Hit.Kind.STATUS, dmg, ctx)
		if not dn.is_empty():
			h.curse = Tune.f("curse_time") * float(dn.get("curse", 0.6))
		o.set_meta(&"gloom_depth", depth + 1)
		o.hurt(h)

## movement-and-combat §3.8 F10/F11: wall slam and enemy-into-enemy ("кегли").
## Both open Stribog cuts (gods-and-runes §3.9). Bosses and the dummy take no part.
func _check_slams(at_wall: int) -> void:
	if absf(kb) <= Tune.f("wall_slam_speed"):
		slam_boost = {}
	if boss or kind_id == "dummy" or wall_cd > 0.0 or absf(kb) <= Tune.f("wall_slam_speed"):
		return
	var spring := (status_ctx().duos as Dictionary).has("duo_spring") and status.rooted()
	if at_wall != 0 and signi(int(signf(kb))) == at_wall:
		var speed := absf(kb)
		wall_cd = Tune.f("wall_slam_cd")
		if spring:
			status.break_roots()
		cut_burst(2.0 if spring else 1.0)
		var boost := slam_boost
		slam_boost = {}
		var h := Hit.make(Hit.Kind.WALL, Tune.f("wall_slam_dmg") * speed / Tune.f("wall_slam_speed") * float(boost.get("mult", 1.0)), position.x, 0.0)
		h.stun = Tune.f("wall_slam_stun")
		var wave_dmg := h.dmg
		hurt(h)
		if not boost.is_empty():
			# The Ослоп wave hits without knockback: it never starts new slams (edge case 15).
			for o: Enemy in _around(float(boost.get("r", 140))):
				o.hurt(Hit.make(Hit.Kind.WALL, wave_dmg, position.x, 0.0))
			if world:
				world.add_ring(position, float(boost.get("r", 140)))
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
		var fc := god_colour("kupala")
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
	_draw_new_status(c, top)
	for f: Dictionary in status.fx:
		match String(f.kind):
			"steam":
				var k3 := 1.0 - float(f.t) / (Tune.f("status_fx_time") * 1.4)
				for j in 7:
					var a3 := j * TAU / 7.0 + k3 * 1.5
					draw_circle(c + Vector2(cos(a3), sin(a3) * 0.6) * (16.0 + 60.0 * k3) + Vector2(0, -30.0 * k3), 12.0 + 14.0 * k3, Color(0.95, 0.97, 1.0, 0.55 * (1.0 - k3)))
			"thread":
				var from2: Vector2 = (f.to as Vector2) - position
				draw_line(from2, c, Color(god_colour("mokosh"), clampf(float(f.t) * 5.0, 0.0, 1.0)), 3.0)
			"gloom":
				var k4 := 1.0 - float(f.t) / (Tune.f("status_fx_time") * 1.6)
				draw_circle(c, 14.0 + 110.0 * k4, Color(0.05, 0.04, 0.08, 0.7 * (1.0 - k4)))
				draw_arc(c, 14.0 + 110.0 * k4, 0.0, TAU, 32, Color(god_colour("chernobog"), 1.0 - k4), 3.0)
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

## Looks of the gods-expansion statuses (§3.3-3.10): wet drops, Mokosh's
## spindle mark, a blind halo over the eyes, Khors's ring, Yarilo's sparks,
## gloom smoke, Semargl's prey flame, Svyatovit's four-point cross.
func _draw_new_status(c: Vector2, top: float) -> void:
	var st := status
	var rr := maxf(w, h)
	if st.wet > StatusSet.EPS:
		for i in 3:
			var x := -w * 0.3 + w * 0.3 * i
			var y := top * 0.6 + fmod(anim * 50.0 + i * 13.0, 26.0)
			draw_circle(Vector2(x, y), 3.5, Color("#6fc8ff"))
	if st.thread > StatusSet.EPS:
		var mc := god_colour("mokosh")
		var p := Vector2(0, top - 18)
		draw_circle(p, 7.0, Color(mc, 0.35))
		draw_line(p + Vector2(0, -8), p + Vector2(0, 8), mc, 2.0)
		draw_arc(p, 5.0, anim * 3.0, anim * 3.0 + PI * 1.3, 8, mc, 2.0)
	if st.blinded():
		var dc := god_colour("dazhbog")
		draw_arc(Vector2(0, top * 0.82), w * 0.45, PI * 1.1, PI * 1.9, 14, Color(dc, 0.9), 4.0)
		for i in 5:
			var a := PI * 1.1 + i * PI * 0.2
			draw_line(Vector2(0, top * 0.82) + Vector2(cos(a), sin(a)) * w * 0.5, Vector2(0, top * 0.82) + Vector2(cos(a), sin(a)) * (w * 0.5 + 8.0), Color(dc, 0.8), 2.0)
	elif st.blind_immune > StatusSet.EPS:
		draw_arc(Vector2(0, top * 0.82), w * 0.45, PI * 1.1, PI * 1.9, 14, Color(0.6, 0.6, 0.6, 0.5), 2.0)
	if st.halo > StatusSet.EPS:
		var hc := god_colour("khors")
		draw_arc(Vector2(0, top - 8), w * 0.38, 0.0, TAU, 20, hc, 3.0)
		draw_arc(Vector2(0, top - 8), w * 0.38 + 5.0, anim * 4.0, anim * 4.0 + 1.0, 6, Color(1, 1, 1, 0.8), 2.0)
	if st.yar > StatusSet.EPS:
		var yc := god_colour("yarilo")
		for i in 4:
			var a := anim * 5.0 + i * TAU / 4.0
			draw_circle(c + Vector2(cos(a), sin(a)) * rr * 0.5, 3.0, yc)
	if st.gloom > StatusSet.EPS:
		for i in 5:
			var a := anim * 1.3 + i * TAU / 5.0
			draw_circle(c + Vector2(cos(a) * w * 0.4, sin(a) * h * 0.3 - h * 0.1), 9.0, Color(0.06, 0.05, 0.1, 0.45))
	if st.prey > StatusSet.EPS:
		var pc := god_colour("semargl")
		var q := Vector2(w * 0.35, top - 6)
		draw_colored_polygon(PackedVector2Array([q + Vector2(-6, 6), q + Vector2(0, -12 - 3.0 * sin(anim * 12.0)), q + Vector2(6, 6)]), Color(pc, 0.9))
	if st.expose > StatusSet.EPS:
		var ec := god_colour("svyatovit")
		for i in 4:
			var a := i * TAU / 4.0 + anim
			draw_circle(c + Vector2(cos(a), sin(a)) * rr * 0.62, 3.5, ec)

# ---------------- elite marks (enemies-and-elites §3.6) ----------------

## One tick of the mark. Returns true when the mark takes the whole tick (howl,
## blink fade): the kind's behaviour is skipped.
func _mark_tick(dt: float) -> bool:
	match mark:
		"ward":
			ward_t += dt
			if ward < ward_max and ward_t >= Tune.f("shield_regrow"):
				ward = ward_max
		"fire":
			trail_t -= dt
			if trail_t <= 0.0 and absf(vel.x) > 10.0 and world:
				trail_t = Tune.f("fire_trail_every")
				var f := FireTrail.new()
				f.world = world
				f.dmg_mult = dmg_mult() / Tune.f("elite_dmg")
				f.position = Vector2(position.x, ground())
				world.add_child(f)
		"blink":
			if blink_fade > 0.0:
				blink_fade -= dt
				vel = Vector2.ZERO
				if blink_fade <= 0.0:
					var m := w / 2.0 + Tune.f("wall_margin")
					position.x = EliteMarks.blink_x(position.x, hero_pos().x, Tune.f("blink_dist"), m, room_w - m if room_w > 0.0 else 1.0e9)
					face = 1 if hero_pos().x > position.x else -1
				return true
			blink_t += dt
			if blink_t >= Tune.f("blink_cd"):
				blink_t = 0.0
				blink_fade = Tune.f("blink_fade")
				return true
		"call":
			if howl > 0.0:
				howl -= dt
				vel.x = 0.0
				if howl <= 0.0:
					_call_kin()
				return true
			var half := hp <= max_hp * 0.5
			if called < int(Tune.f("call_max")) and (not called_wake or (half and not called_half)):
				called_wake = true
				if half:
					called_half = true
				howl = Tune.f("call_howl")
				return true
	return false

## Зов: call_count ordinary enemies of the location's roster, at most call_max in all.
func _call_kin() -> void:
	if world == null:
		return
	var roster: Array = EnemyRoster.for_tier(tier, Tune.table("locations"), Tune.data).roster
	for i in mini(int(Tune.f("call_count")), int(Tune.f("call_max")) - called):
		var kind := String(roster[rng.randi_range(0, roster.size() - 1)])
		var e := EnemyRoster.make(kind)
		var y := ground()
		if bool(Tune.row("enemies", kind).get("flies", false)):
			var fy: Array = Tune.get_value("flyer_spawn_y")
			y = ground() - (Tune.f("ground_y") - float(fy[0]))
		world.spawn_enemy(e, Vector2(clampf(position.x + (i * 2 - 1) * 90.0, 60.0, maxf(60.0, room_w - 60.0)), y), pack, false, rng.randi())
		called += 1

## Взрыв: death_blast_dmg to the hero within death_blast_r; enemies are not hurt.
func _death_blast() -> void:
	var p := hero()
	if world:
		world.add_ring(center(), Tune.f("death_blast_r"))
		world.add_shake(Tune.f("shake_slam"))
	if p and not p.dead:
		var d := EliteMarks.blast_damage((p.position - Vector2(0, Player.H / 2.0)).distance_to(center()), Tune.data)
		if d > 0.0:
			hurt_hero(d / dmg_mult(), Hit.Kind.CONTACT)

## The mark shown three ways (§3.6): aura colour, the word over the enemy, the hp bar pattern.
func _draw_mark(font: Font) -> void:
	var inf := EliteMarks.info(mark, Tune.data)
	var c := Color(String(inf.colour))
	var a := 0.25 + 0.1 * sin(anim * 4.0)
	if blink_fade > 0.0:
		a *= 2.0
	draw_circle(Vector2(0, -h / 2.0), maxf(w, h) * 0.85, Color(c, a * 0.6))
	draw_arc(Vector2(0, -h / 2.0), maxf(w, h) * 0.85, 0.0, TAU, 40, Color(c, 0.8), 3.0)
	if mark == "ward" and ward > 0.0:
		draw_arc(Vector2(0, -h / 2.0), maxf(w, h) * 0.7, 0.0, TAU * ward / maxf(ward_max, 1.0), 40, Color(c, 0.95), 5.0)
	if mark == "blast" and dead:
		draw_circle(Vector2(0, -h / 2.0), Tune.f("death_blast_r") * mark_blast_t / maxf(Tune.f("death_blast_delay"), 0.01), Color(c, 0.25 if int(mark_blast_t * 12.0) % 2 == 0 else 0.45))
	var word := String(inf.name)
	draw_string_outline(font, Vector2(-80, -h - 40), word, HORIZONTAL_ALIGNMENT_CENTER, 160, 24, 6, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-80, -h - 40), word, HORIZONTAL_ALIGNMENT_CENTER, 160, 24, c)
	# Bar pattern: striped in the mark colour, always shown for elites.
	draw_rect(Rect2(-26, -h - 20, 52, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-26, -h - 20, 52 * maxf(hp, 0.0) / maxf(max_hp, 1.0), 7), Color("#e05a4a"))
	for i in 6:
		draw_line(Vector2(-24 + i * 9, -h - 13), Vector2(-20 + i * 9, -h - 20), Color(c, 0.9), 2.0)
