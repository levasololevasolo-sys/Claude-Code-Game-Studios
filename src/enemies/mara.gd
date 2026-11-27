## Мара, Морена's dark servant (GDD bestiary §3.4 card 6, mechanic raise_frozen,
## edge cases 1-2). Keeps keep_dx from the hero. When an ally dies within
## raise_r she winds up (raise 0.8 s, a magenta thread from her hands to the
## body) and the body rises as an ice copy (Enemy.ice_copy): raise_frac of its
## max HP, blows ×ice_copy_dmg, broken at once by a breaking blow / the Flare /
## a wall slam, no embers. At most raise_max copies; a hit in the wind-up stops
## the raise; when Мара dies her copies crack. Close in she scratches
## (scratch_wind 0.5 s): parried, the parry takes the arm (limb_zones.json
## "mara"), one-armed her raise is ×1.5 longer. Stats: enemies.json "mara".
class_name Mara
extends Enemy

## Bodies waiting to be raised: {kind, pos, max_hp}.
var corpses: Array[Dictionary] = []
## Live ice copies she raised.
var copies: Array[Enemy] = []
## The body the current wind-up is raising ({} = none).
var raising: Dictionary = {}
var scratched: bool = false
var scratch_cd: float = 0.0
var _watched: Dictionary = {}

func _load_stats() -> void:
	kind_id = "mara"
	_apply_row()

func _behave(dt: float) -> void:
	watch(_around(stat("raise_r")))
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "raise_w" or st == "scratch_wind"

func contact_damage() -> float:
	return 0.0

## Starts listening to the deaths of `allies` (once each).
func watch(allies: Array) -> void:
	for a in allies:
		var e := a as Enemy
		if e == null or e == self or e.dead or _watched.has(e.get_instance_id()):
			continue
		_watched[e.get_instance_id()] = true
		e.died.connect(on_ally_died)

## Live copies now (dead or freed ones are dropped).
func live_copies() -> int:
	copies.assign(copies.filter(func(c: Enemy) -> bool: return is_instance_valid(c) and not c.dead))
	return copies.size()

## An ally died: its body is queued when it can be raised (FrostRules.can_raise).
func on_ally_died(e: Enemy, _hit: Hit) -> void:
	if dead or e == null:
		return
	var dist := e.position.distance_to(position)
	if FrostRules.can_raise(dist, stat("raise_r"), e.ice_copy, e.boss, e.kind_id, live_copies() + corpses.size() + (1 if not raising.is_empty() else 0),
			int(stat("raise_max")), bool(e.stats.get("reassemble", false))):
		corpses.append({ "kind": e.kind_id, "pos": Vector2(e.position.x, Tune.f("ground_y")) if not e.flies else e.position, "max_hp": e.max_hp })

## Raises `c` as an ice copy now; returns it (also kept in `copies`).
func raise_copy(c: Dictionary) -> Enemy:
	var e := EnemyRoster.make(String(c.kind))
	if e == null:
		return null
	e.ice_copy = true
	if world:
		world.spawn_enemy(e, c.pos, pack, false, rng.randi() if rng else 1)
	else:
		e.position = c.pos
		e.tier = tier
		e.setup()
	e.stats = e.stats.duplicate()
	e.stats["embers"] = 0
	e.max_hp = FrostRules.copy_hp(float(c.max_hp), stat("raise_frac"))
	e.hp = e.max_hp
	e.died.connect(func(_e: Enemy, _h: Hit) -> void: Audio.play_at(&"frozen_crack", _e.position))
	copies.append(e)
	Audio.play_at(&"frozen_rise", e.position)
	return e

## Cracks every live copy (Мара died, §3.4).
func shatter_copies() -> int:
	var n := 0
	for cp: Enemy in copies:
		if is_instance_valid(cp) and not cp.dead:
			cp.hurt(Hit.make(Hit.Kind.FLARE, cp.hp + 1.0, cp.position.x, 0.0))
			n += 1
	copies.clear()
	return n

## One tick: walk (keep distance) -> raise_w -> walk; hero close: scratch_wind ->
## scratch -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	scratch_cd -= dt
	var dx := hp_pos.x - position.x
	var adx := absf(dx)
	if st != "scratch" and st != "scratch_wind" and dx != 0.0:
		face = 1 if dx > 0.0 else -1
	match st:
		"raise_w":
			vel.x = 0.0
			if t <= 0.0:
				raise_copy(raising)
				raising = {}
				st = "walk"
				cd = stat("raise_cd")
		"scratch_wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "scratch"
				t = stat("scratch_time")
				scratched = false
		"scratch":
			vel.x = 0.0
			if not scratched and SwampRules.swing_hits(position, face, w, stat("scratch_hit_x"), stat("scratch_hit_y"), hp_pos):
				scratched = true
				hurt_hero(stat("scratch_dmg"), Hit.Kind.CONTACT)
			if st == "scratch" and t <= 0.0:
				st = "walk"
				scratch_cd = stat("scratch_cd")
		_:
			st = "walk"
			var keep := stat("keep_dx")
			if adx < keep - 60.0:
				vel.x = -signf(dx) * stat("speed")
			elif adx > keep + 60.0:
				vel.x = signf(dx) * stat("speed")
			else:
				vel.x = 0.0
			if adx < stat("scratch_range") and scratch_cd <= 0.0 and absf(hp_pos.y - position.y) < stat("scratch_hit_y"):
				st = "scratch_wind"
				t = stat("scratch_wind")
				vel.x = 0.0
			elif cd <= 0.0 and not corpses.is_empty() and live_copies() < int(stat("raise_max")):
				raising = corpses.pop_front()
				st = "raise_w"
				t = stat("raise")
				vel.x = 0.0
				face = 1 if float((raising.pos as Vector2).x) >= position.x else -1

## A hit in the wind-up stops the raise (the body is lost).
func _after_hurt(hit: Hit) -> void:
	if st == "raise_w" and hit != null and hit.kind != Hit.Kind.TICK:
		st = "walk"
		raising = {}
		cd = stat("raise_cd")

func _dead_tick(dt: float) -> void:
	shatter_copies()
	super._dead_tick(dt)

func _draw() -> void:
	_draw_windup_glow()
	if st == "raise_w" and not raising.is_empty():
		# Telegraph: a magenta thread from her hands to the body, a frost bloom on it.
		var k := clampf(1.0 - t / maxf(stat("raise"), 0.01), 0.0, 1.0)
		var to: Vector2 = (raising.pos as Vector2) - position
		var from := Vector2(face * w * 0.7, -h * 0.62)
		var thread := Color(String(stats.thread))
		var pts := PackedVector2Array()
		for i in 13:
			var u := i / 12.0
			pts.append(from.lerp(to + Vector2(0, -12), u) + Vector2(0, sin(u * 9.0 + anim * 10.0) * 7.0 * (1.0 - u)))
		draw_polyline(pts, Color(thread, 0.35), 12.0)
		draw_polyline(pts, thread, 5.0)
		draw_polyline(pts, Color(1, 1, 1, 0.7), 1.5)
		_draw_glow(to + Vector2(0, -16), 30.0 + 30.0 * k, thread, 1.0)
		_draw_glow(to + Vector2(0, -16), 20.0 + 20.0 * k, Color("#8fd3f5"), 1.0)
		for i in 5:
			var a := TAU * i / 5.0 + anim
			draw_line(to + Vector2(0, -16), to + Vector2(0, -16) + Vector2(cos(a), sin(a)) * (10.0 + 20.0 * k), Color.WHITE, 2.0)
	if art_skin:
		_draw_overlay()
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var veil := Color(String(stats.veil))
	# Thin vertical figure in a torn veil.
	var body := PackedVector2Array([Vector2(-w * 0.55, 0), Vector2(-w * 0.35, -6), Vector2(-w * 0.45, -14), Vector2(-w * 0.2, -8),
		Vector2(0, -16), Vector2(w * 0.2, -6), Vector2(w * 0.5, -12), Vector2(w * 0.45, 0), Vector2(w * 0.3, -h * 0.8),
		Vector2(0, -h * 0.98), Vector2(-w * 0.3, -h * 0.8)])
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.55, 0), Vector2(w * 0.5, 0), Vector2(w * 0.3, -h * 0.8), Vector2(0, -h * 0.98), Vector2(-w * 0.3, -h * 0.8)]), veil)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.4, -4), Vector2(w * 0.38, -4), Vector2(w * 0.22, -h * 0.78), Vector2(0, -h * 0.93), Vector2(-w * 0.22, -h * 0.78)]), c)
	for i in 4:
		var rx := -w * 0.4 + i * w * 0.26
		draw_colored_polygon(PackedVector2Array([Vector2(rx, -4), Vector2(rx + 8, -4), Vector2(rx + 3, 10)]), veil)
	# Long arms: down at rest, raised to the body in the raise, clawing forward in the scratch.
	var sh := Vector2(w * 0.15, -h * 0.75)
	var hand := Vector2(w * 0.35, -h * 0.3)
	if st == "raise_w":
		hand = Vector2(w * 0.7, -h * 0.62)
	elif st == "scratch_wind":
		hand = Vector2(-w * 0.1, -h * 0.95)
	elif st == "scratch":
		hand = Vector2(w * 0.5 + stat("scratch_hit_x") * 0.8, -h * 0.55)
	if not arm_off:
		draw_line(sh, hand, veil, 6.0)
		draw_line(sh, hand, c.lightened(0.15), 3.0)
		for i in 3:
			draw_line(hand, hand + Vector2(8, -4 + i * 4), Color("#dde8f0"), 2.0)
		if st == "scratch_wind" or st == "raise_w":
			_draw_glow(hand, 20.0, Color(String(stats.eye)), 0.9)
	draw_line(Vector2(-w * 0.15, -h * 0.75), Vector2(-w * 0.35, -h * 0.3), c.lightened(0.15), 3.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(-3, -h * 0.86), Vector2(4, -h * 0.86), 2.6 if is_winding() else 2.0, face)
	_draw_overlay()
