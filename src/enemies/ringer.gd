## Аука, the flanker (GDD enemies-and-elites §3.2: «появляется за спиной»; forest
## roster §3.3). Walks at the hero; in range it calls «ау!» (wind-up: its mouth
## glows and a glowing ring marks the spot behind the hero where it will step
## out), fades, reappears there facing the hero, swipes after a short second
## wind-up, then recovers. Stats: enemies.json "ringer".
class_name Ringer
extends Enemy

## World x where it will reappear (fixed when the call starts).
var dest_x: float = 0.0
## True once the current swipe has hit (one hit per swipe).
var swiped: bool = false

func _load_stats() -> void:
	kind_id = "ringer"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "call" or st == "appear"

## Gone: no touch, no hit box (the hero cannot hit what is not there).
func contact_damage() -> float:
	return 0.0 if st == "gone" else stat("contact")

func hurt_rect() -> Rect2:
	if st == "gone":
		return Rect2(position.x, position.y + 4000.0, 0.0, 0.0)
	return super()

## The spot behind the hero (away from the ringer), clamped inside the room.
func behind_x(hp_x: float) -> float:
	var side := 1.0 if position.x < hp_x else -1.0
	var x := hp_x + side * stat("behind_dx")
	if room_w > 0.0:
		var m := w / 2.0 + Tune.f("wall_margin")
		if x < m or x > room_w - m:
			x = hp_x - side * stat("behind_dx")
		x = clampf(x, m, room_w - m)
	return x

## One tick: walk -> call (wind-up, mark shown) -> gone -> appear (wind-up)
## -> swipe -> recover -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "walk":
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed") if absf(dx) > stat("stop") else 0.0
			if cd <= 0.0 and absf(dx) < stat("range_x") and absf(hp_pos.y - position.y) < stat("range_y"):
				st = "call"
				t = stat("call")
				vel.x = 0.0
				dest_x = behind_x(hp_pos.x)
		"call":
			vel.x = 0.0
			if t <= 0.0:
				st = "gone"
				t = stat("gone")
		"gone":
			vel.x = 0.0
			if t <= 0.0:
				position.x = dest_x
				face = int(signf(hp_pos.x - position.x)) if hp_pos.x != position.x else face
				st = "appear"
				t = stat("appear")
		"appear":
			vel.x = 0.0
			if t <= 0.0:
				st = "swipe"
				t = stat("swipe_time")
				swiped = false
		"swipe":
			vel.x = face * stat("swipe_step")
			if not swiped and swipe_rect().intersects(_hero_rect(hp_pos)):
				swiped = true
				hurt_hero(stat("swipe_dmg"), Hit.Kind.CONTACT)
			if t <= 0.0:
				st = "recover"
				t = stat("recover")
		"recover":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")

## Swipe hit box in world space (in front of it).
func swipe_rect() -> Rect2:
	var hx := stat("swipe_x")
	return Rect2(position.x + (0.0 if face > 0 else -hx), position.y - h, hx, h)

static func _hero_rect(p: Vector2) -> Rect2:
	return Rect2(p.x - Player.W / 2.0, p.y - Player.H, Player.W, Player.H)

func _draw() -> void:
	var eye := Color(String(stats.eye))
	# The mark behind the hero: a ring on the floor while it calls and while gone.
	if st == "call" or st == "gone":
		var k := 1.0 - clampf(t / maxf(stat("call") if st == "call" else stat("gone"), 0.01), 0.0, 1.0)
		var at := Vector2(dest_x - position.x, 0)
		draw_arc(at + Vector2(0, -6), 26.0 + 10.0 * k, 0.0, TAU, 24, Color(eye, 0.5 + 0.4 * k), 3.0)
		draw_line(at + Vector2(0, -6), at + Vector2(0, -h * 0.9), Color(eye, 0.25 + 0.3 * k), 2.0)
	if st == "gone":
		_draw_overlay()
		return
	_draw_windup_glow()
	var fade := 1.0
	if st == "call":
		fade = clampf(t / maxf(stat("call"), 0.01) * 1.5, 0.35, 1.0)
	elif st == "appear":
		fade = clampf(1.0 - t / maxf(stat("appear"), 0.01) + 0.4, 0.4, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var lean := 10.0 if st == "swipe" else (-4.0 if st == "appear" else sin(anim * 3.0) * 2.0)
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	c.a = fade
	# a thin, stooped forest voice: long body, hood of moss, long arms
	# Headless (limb-zones §3.4): the hood is gone, the shoulders end at the neck.
	var top := 0.74 if head_off else 1.0
	var body := PackedVector2Array([Vector2(-w * 0.4, 0), Vector2(-w * 0.45, -h * 0.55), Vector2(-w * 0.2 + lean * 0.5, -h * top),
		Vector2(w * 0.3 + lean, -h * minf(0.92, top)), Vector2(w * 0.45 + lean * 0.5, -h * 0.5), Vector2(w * 0.35, 0)])
	draw_colored_polygon(body, c)
	var arm := Color(String(stats.get("arm", "#3a4a3a")), fade)
	var reach := Vector2(w * 0.9 + 18.0, -h * 0.45) if st == "swipe" else Vector2(w * 0.5, -h * 0.15 + sin(anim * 2.0) * 4.0)
	if not arm_off:
		draw_line(Vector2(w * 0.2 + lean, -h * 0.75), reach, arm, 4.0)
		for f in 3:
			draw_line(reach, reach + Vector2(8.0, -6.0 + f * 6.0), arm, 2.0)
	if st == "call" and not head_off:
		# the «ау!» mouth: a glowing O
		draw_circle(Vector2(w * 0.3 + lean, -h * 0.7), 5.0 + 2.0 * sin(anim * 20.0), Color(eye, 0.9))
	if st == "swipe":
		# One-armed: the swipe is a short shoulder shove (shorter arc, one_arm stats).
		draw_arc(Vector2(w * 0.4, -h * 0.5), stat("swipe_x") * 0.6, -1.2, 1.0, 12, Color(eye, 0.7), 3.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(w * 0.05 + lean, -h * 0.84), Vector2(w * 0.22 + lean, -h * 0.82), 2.5, face)
	_draw_overlay()
