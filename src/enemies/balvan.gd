## Болванчик, the plain fodder (GDD bestiary §3.2 card 0, mechanic plain_swing).
## A clay field-guardian: walks slowly at the hero, raises the club over its head
## (0.7 s wind-up, eyes flare), swings once forward, rests. Nothing else: no dash,
## no jump, no shots. The swing is parried like any melee blow and the parry cuts
## the club arm (limb_zones.json "balvan"): one-armed it swings shorter and weaker.
## Stats: enemies.json "balvan".
class_name Balvan
extends Enemy

## True once the current swing has hit (one hit per swing).
var swung: bool = false

func _load_stats() -> void:
	kind_id = "balvan"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "wind"

## No touch damage: only the club hurts.
func contact_damage() -> float:
	return 0.0

## The club's strike box right now (world space).
func swing_rect() -> Rect2:
	return SwampRules.front_rect(position, face, w, stat("reach"), h)

## One tick: walk -> wind (club up) -> swing (one hit) -> recover -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "walk":
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed") if absf(dx) > stat("swing_range") * 0.6 else 0.0
			if cd <= 0.0 and SwampRules.in_reach(dx, hp_pos.y - position.y, stat("swing_range"), stat("range_y")):
				st = "wind"
				t = stat("wind")
				vel.x = 0.0
		"wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "swing"
				t = stat("swing_time")
				swung = false
		"swing":
			vel.x = face * stat("swing_step")
			if not swung and SwampRules.swing_hits(position, face, w, stat("reach"), h, hp_pos):
				swung = true
				# Still "swing" here, so a parry (Player.hurt -> parried) takes the club arm.
				hurt_hero(stat("swing_dmg"), Hit.Kind.CONTACT)
			if st == "swing" and t <= 0.0:
				st = "recover"
				t = stat("recover")
				vel.x = 0.0
		"recover":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")

func _draw() -> void:
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var outline := Color("#120d12")
	var top := 0.82 if head_off else 1.0
	# Squat clay block with a round head; straw tufts at the shoulders.
	var body := PackedVector2Array([Vector2(-w / 2 - 2, 0), Vector2(-w / 2, -h * 0.7), Vector2(-w * 0.3, -h * 0.8),
		Vector2(w * 0.3, -h * 0.8), Vector2(w / 2, -h * 0.7), Vector2(w / 2 + 2, 0)])
	draw_colored_polygon(body, outline)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(p * 0.92 + Vector2(0, -1))
	draw_colored_polygon(inner, c)
	if not head_off:
		draw_circle(Vector2(0, -h * 0.88), w * 0.33 + 2, outline)
		draw_circle(Vector2(0, -h * 0.88), w * 0.33, c)
	# Cracks and straw.
	draw_line(Vector2(-6, -h * 0.6), Vector2(2, -h * 0.4), c.darkened(0.45), 2.0)
	draw_line(Vector2(2, -h * 0.4), Vector2(-2, -h * 0.22), c.darkened(0.45), 2.0)
	var straw := Color(String(stats.straw))
	for i in 3:
		draw_line(Vector2(-w * 0.35, -h * 0.78), Vector2(-w * 0.55 - i * 3, -h * 0.9 + i * 5), straw, 2.0)
	# Club arm: down and forward when walking, over the head in the wind-up, out in the swing.
	var root := Vector2(w * 0.25, -h * 0.72)
	var club := Color(String(stats.club))
	if not arm_off:
		var hand := Vector2(w * 0.55, -h * 0.35)
		var tip := hand + Vector2(10, 26)
		if st == "wind":
			var k := clampf(1.0 - t / maxf(stat("wind"), 0.01), 0.0, 1.0)
			hand = Vector2(w * 0.1, -h * (1.05 + 0.1 * k))
			tip = hand + Vector2(-18, -28)
		elif st == "swing":
			hand = Vector2(w * 0.5 + stat("reach") * 0.4, -h * 0.55)
			tip = Vector2(w * 0.5 + stat("reach"), -h * 0.45)
		draw_line(root, hand, outline, 9.0)
		draw_line(root, hand, c.darkened(0.15), 6.0)
		draw_line(hand, tip, outline, 13.0)
		draw_line(hand, tip, club, 9.0)
		if st == "wind":
			_draw_glow(tip, 26.0, Color("#c2502a"), 0.9)
	else:
		draw_line(root, root + Vector2(5, 9), c.darkened(0.25), 7.0)
	_draw_windup_outline(body)
	var eye_k := 3.5 if st == "wind" else 2.5
	_draw_eyes(Vector2(-4, -h * 0.9), Vector2(5, -h * 0.9), eye_k, face)
	_draw_overlay()
