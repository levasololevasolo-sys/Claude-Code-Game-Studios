## Сучковик, the living tree at the wall (GDD bestiary §3.3 card 5, mechanic
## spear_platform). Never walks: it turns to the hero and, with the hero in
## line (fire_range ahead, range_y up/down), draws a branch back for `wind` s
## (creak, a thin rust line along the line of fire to the wall) and throws a
## BranchSpear horizontally at spear_speed. The spear sticks in the wall and
## is a one-way step plat_w px wide for plat_time s; at most spear_max of its
## spears live at once. A parry reflects the spear: back at the thrower it
## stuns it for deflect_stun s. Head zone in the wind-up only; no arm to cut.
## Stats: enemies.json "suchkovik".
class_name Suchkovik
extends Enemy

## Its live spears (flying or stuck), pruned every tick.
var spears: Array[BranchSpear] = []
## X of the wall the drawn spear will stick in (for the telegraph line).
var aim_x: float = 0.0

func _load_stats() -> void:
	kind_id = "suchkovik"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "wind"

func contact_damage() -> float:
	return 0.0

## Spear start in world space (the drawn branch at shoulder height).
func muzzle() -> Vector2:
	return position + Vector2(face * stat("muzzle_x"), -stat("muzzle_y"))

## Live spears now (drops freed and broken ones).
func live_spears() -> int:
	spears.assign(spears.filter(func(s: BranchSpear) -> bool: return is_instance_valid(s) and s.life > 0.0))
	return spears.size()

func _solids() -> Array:
	if world and world.room:
		return world.room.layout.get("solids", [])
	return []

## Wall x along the line of fire from the muzzle (ForestRules.spear_stop_x).
func wall_x() -> float:
	var rw := room_w if room_w > 0.0 else 100000.0
	return ForestRules.spear_stop_x(muzzle(), face, _solids(), rw, 2.0)

## Throws one spear now; returns it.
func throw_spear() -> BranchSpear:
	var s := BranchSpear.new()
	s.position = muzzle()
	s.dir = face
	s.vel = Vector2(face * stat("spear_speed"), 0.0)
	s.stop_x = wall_x()
	s.r = stat("spear_r")
	s.dmg = stat("spear_dmg") * dmg_mult()
	s.life = stat("spear_life")
	s.plat_w = stat("plat_w")
	s.plat_time = stat("plat_time")
	s.deflect_stun = stat("deflect_stun")
	s.wood = Color(String(stats.spear))
	s.color = Color(String(stats.eye))
	s.source = self
	s.world = world
	if world:
		world.add_child(s)
	else:
		orphan_shots.append(s)
	spears.append(s)
	Audio.play_at(&"branch_spear", position)
	return s

## One tick: stand (turn to the hero) -> wind -> throw -> recover -> stand.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	vel.x = 0.0
	var dx := hp_pos.x - position.x
	match st:
		"wind":
			aim_x = wall_x()
			if t <= 0.0:
				throw_spear()
				st = "recover"
				t = stat("recover")
		"recover":
			if t <= 0.0:
				st = "stand"
				cd = _stat_range("cd_min", "cd_max")
		_:
			st = "stand"
			if dx != 0.0:
				face = 1 if dx > 0.0 else -1
			if cd <= 0.0 and ForestRules.in_line(dx, hp_pos.y - position.y, stat("fire_range"), stat("range_y")) \
					and ForestRules.can_throw(live_spears(), int(stat("spear_max"))):
				st = "wind"
				t = stat("wind")
				aim_x = wall_x()

func _draw() -> void:
	var line_c := Color(String(stats.line))
	var k := 0.0
	if st == "wind":
		k = clampf(1.0 - t / maxf(stat("wind"), 0.01), 0.0, 1.0)
		# The line of fire to the wall: a thin rust stripe, brighter as the throw nears.
		var m := muzzle() - position
		draw_line(m, Vector2(aim_x - position.x, m.y), Color(line_c, 0.35 + 0.55 * k), 2.0 + k)
		draw_circle(Vector2(aim_x - position.x, m.y), 4.0 + 3.0 * k, Color(line_c, 0.6 * k))
	if _skin_draw():
		return
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var bark := Color(String(stats.bark))
	var outline := Color("#120d12")
	var top := 0.84 if head_off else 1.0
	# A tall thin trunk with broken joints, roots for feet.
	var body := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(-w * 0.2, -h * 0.08), Vector2(-w * 0.3, -h * 0.45),
		Vector2(-w * 0.12, -h * 0.62), Vector2(-w * 0.22, -h * top), Vector2(w * 0.2, -h * (top - 0.03)),
		Vector2(w * 0.1, -h * 0.6), Vector2(w * 0.25, -h * 0.4), Vector2(w * 0.15, -h * 0.08), Vector2(w * 0.5, 0)])
	draw_colored_polygon(body, outline)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(Vector2(p.x * 0.8, p.y * 0.97 - 1.0))
	draw_colored_polygon(inner, c)
	for i in 3:
		draw_line(Vector2(-3 + i * 3, -h * (0.15 + 0.2 * i)), Vector2(-1 + i * 2, -h * (0.28 + 0.2 * i)), bark, 2.0)
	# Back arm: a long bare branch hanging to the ground.
	var sh2 := Vector2(-w * 0.15, -h * 0.72)
	draw_line(sh2, Vector2(-w * 0.9, -h * 0.35), outline, 6.0)
	draw_line(sh2, Vector2(-w * 0.9, -h * 0.35), bark, 3.5)
	draw_line(Vector2(-w * 0.9, -h * 0.35), Vector2(-w * 1.1, -h * 0.05), bark, 3.0)
	draw_line(Vector2(-w * 0.9, -h * 0.35), Vector2(-w * 1.25, -h * 0.4), bark, 2.0)
	# Front arm with the loaded spear: pulled back along the line in the wind-up.
	var sh := Vector2(w * 0.1, -h * 0.74)
	var my := -stat("muzzle_y")
	var hand := Vector2(w * 0.9, my)
	var pull := 30.0 * k
	if st == "recover":
		hand = Vector2(w * 1.4, my)
	draw_line(sh, hand - Vector2(pull, 0), outline, 6.0)
	draw_line(sh, hand - Vector2(pull, 0), bark, 3.5)
	if st != "recover" and live_spears() < int(stat("spear_max")):
		var sp := Color(String(stats.spear))
		var a := Vector2(stat("muzzle_x") - pull - 46.0, my)
		var b := Vector2(stat("muzzle_x") - pull + 22.0, my)
		draw_line(a, b, outline, 7.0)
		draw_line(a, b, sp, 4.5)
		draw_colored_polygon(PackedVector2Array([b + Vector2(9, 0), b + Vector2(0, -4), b + Vector2(0, 4)]), sp.lightened(0.3))
		if st == "wind":
			_draw_glow(b, 18.0, line_c, 0.9)
	# Twig crown.
	if not head_off:
		var hy := -h * 0.98
		for i in 4:
			var ang := -2.4 + i * 0.5
			draw_line(Vector2(0, hy), Vector2(0, hy) + Vector2(cos(ang), sin(ang)) * (12.0 + i * 2.0), bark, 2.5)
	_draw_windup_outline(body)
	# One glowing eye in the bark (§3.3: like the background trees, but the eye burns).
	var ek := 3.2 + 1.5 * k
	_draw_eyes(Vector2(w * 0.05, -h * 0.86), Vector2(w * 0.05, -h * 0.86), ek, face)
	_draw_overlay()
