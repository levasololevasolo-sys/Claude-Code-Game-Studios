## Лешачонок, the burrower (GDD enemies-and-elites §3.2: «уходит в пол,
## выныривает под игроком»; forest roster §3.3, story-bible §2.2). Walks at the
## hero; in range it digs in (wind-up: it shakes and throws dirt), travels under
## the floor to the hero's x (only a moving dirt ripple shows), stops, and a
## glowing mound marks the spot for rise_w s before it bursts up. While under it
## cannot be hit and does no touch damage. Stats: enemies.json "rootling".
class_name Rootling
extends Enemy

## True once the current burst has hit.
var burst_hit: bool = false

func _load_stats() -> void:
	kind_id = "rootling"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "dig" or st == "rise_w"

## True while it is under the floor (no hit box, no touch).
func is_under() -> bool:
	return st == "under" or st == "rise_w"

func contact_damage() -> float:
	return 0.0 if is_under() else stat("contact")

func hurt_rect() -> Rect2:
	if is_under():
		return Rect2(position.x, position.y + 4000.0, 0.0, 0.0)
	return super()

## One tick: walk -> dig -> under (moves to the hero's x) -> rise_w (mound
## telegraph, fixed spot) -> burst (hits once) -> recover -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "walk":
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed")
			if cd <= 0.0 and absf(dx) < stat("range_x") and absf(hp_pos.y - position.y) < stat("range_y"):
				st = "dig"
				t = stat("dig")
				vel.x = 0.0
		"dig":
			vel.x = 0.0
			if t <= 0.0:
				st = "under"
				t = stat("under_max")
		"under":
			vel.x = signf(dx) * stat("under_speed") if absf(dx) > stat("under_stop") else 0.0
			if absf(dx) <= stat("under_stop") or t <= 0.0:
				vel.x = 0.0
				st = "rise_w"
				t = stat("rise_w")
		"rise_w":
			vel.x = 0.0
			if t <= 0.0:
				st = "burst"
				t = stat("burst_time")
				vel.y = -stat("burst_up")
				burst_hit = false
				if absf(hp_pos.x - position.x) < stat("burst_r") and hp_pos.y > position.y - stat("burst_h"):
					burst_hit = true
					hurt_hero(stat("burst_dmg"), Hit.Kind.CONTACT)
		"burst":
			if t <= 0.0 and on_ground():
				st = "recover"
				t = stat("recover")
		"recover":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")

func _draw() -> void:
	var eye := Color(String(stats.eye))
	var dirt := Color(String(stats.get("dirt", "#5a4a3a")))
	if is_under():
		# The ripple of dirt moving under the floor, a glowing mound before the burst.
		var bump := 6.0 + sin(anim * 18.0) * 3.0
		if not art_skin:
			draw_colored_polygon(PackedVector2Array([Vector2(-28, 0), Vector2(-10, -bump), Vector2(10, -bump - 2), Vector2(28, 0)]), dirt)
		if st == "rise_w":
			var k := 1.0 - clampf(t / maxf(stat("rise_w"), 0.01), 0.0, 1.0)
			var r := stat("burst_r")
			draw_rect(Rect2(-r, -6.0, r * 2.0, 6.0), Color(eye, 0.35 + 0.45 * k))
			draw_arc(Vector2(0, -4), 18.0 + 14.0 * k, PI, TAU, 16, Color(eye, 0.6 + 0.4 * k), 3.0)
			for i in 3:
				draw_line(Vector2(-12 + i * 12, -4), Vector2(-14 + i * 14, -18.0 - 14.0 * k), Color(eye, 0.7), 2.0)
		_draw_overlay()
		return
	if _skin_draw():
		return
	_draw_windup_glow()
	var shake := sin(anim * 60.0) * 3.0 if st == "dig" else 0.0
	var sink := h * 0.4 * (1.0 - clampf(t / maxf(stat("dig"), 0.01), 0.0, 1.0)) if st == "dig" else 0.0
	draw_set_transform(Vector2(shake, sink), 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	# a stump-child: round root body, twig horns, root legs
	var top := 0.58 if head_off else 1.0
	var body := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(-w * 0.5, -h * minf(0.6, top)), Vector2(-w * 0.2, -h * top), Vector2(w * 0.25, -h * top),
		Vector2(w * 0.5, -h * minf(0.6, top)), Vector2(w * 0.5, 0)])
	draw_colored_polygon(body, c)
	var twig := Color(String(stats.get("twig", "#7a6248")))
	if not head_off:
		draw_line(Vector2(-w * 0.15, -h), Vector2(-w * 0.35, -h - 14), twig, 3.0)
		draw_line(Vector2(w * 0.15, -h), Vector2(w * 0.3, -h - 16), twig, 3.0)
		draw_line(Vector2(w * 0.3, -h - 16), Vector2(w * 0.45, -h - 20), twig, 2.0)
	for i in 3:
		var lx := -w * 0.35 + i * w * 0.35
		draw_line(Vector2(lx, -2), Vector2(lx - 5 + sin(anim * 10 + i) * 3, 0), twig, 3.0)
	if st == "dig":
		for i in 4:
			var a := anim * 9.0 + i * 1.6
			draw_circle(Vector2(cos(a) * 26.0, -6.0 - absf(sin(a)) * 18.0), 3.0, dirt)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(w * 0.05, -h * 0.7), Vector2(w * 0.28, -h * 0.68), 3.0, face)
	_draw_overlay()
