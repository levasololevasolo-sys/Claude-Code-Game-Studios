## Трясинник, the ram (GDD enemies-and-elites §3.2, §3.4). Crawls at the hero;
## in range and level with him it rears up (wind-up), rushes, then rests. From
## tier 2 it crouches and leaps at a hero standing above it. Stats: enemies.json "crawler".
class_name Crawler
extends Enemy

func _load_stats() -> void:
	kind_id = "crawler"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "wind" or st == "crouch"

## ×charge_contact_mult while rushing or leaping (GDD §3.2).
func contact_damage() -> float:
	var c := stat("contact")
	return c * stat("charge_contact_mult") if st == "charge" or st == "leap" else c

## One tick of the state machine: walk -> wind -> charge -> recover -> walk,
## or (tier >= leap_tier) walk -> crouch -> leap -> recover.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	var adx := absf(dx)
	match st:
		"idle", "walk":
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed")
			if cd <= 0.0 and tier >= int(stat("leap_tier")) and hp_pos.y < position.y - stat("leap_dy") and adx < stat("leap_range_x"):
				st = "crouch"
				t = stat("crouch")
				vel.x = 0.0
			elif cd <= 0.0 and adx < stat("range_x") and absf(hp_pos.y - position.y) < stat("range_y"):
				st = "wind"
				t = stat("wind")
				vel.x = 0.0
		"wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "charge"
				t = stat("charge_time")
		"charge":
			vel.x = face * stat("charge")
			var at_wall := room_w > 0.0 and (position.x < stat("wall_stop") or position.x > room_w - stat("wall_stop"))
			if t <= 0.0 or at_wall:
				st = "recover"
				t = stat("recover")
		"crouch":
			vel.x = 0.0
			if t <= 0.0:
				st = "leap"
				vel.y = -stat("leap_up")
				vel.x = clampf(dx * stat("leap_side_mult"), -stat("leap_side_max"), stat("leap_side_max"))
				t = stat("leap_time")
		"leap":
			if on_ground() and vel.y >= 0.0 and t < stat("leap_time") - stat("leap_min_air"):
				st = "recover"
				t = stat("leap_recover")
				vel.x = 0.0
		"recover":
			vel.x *= pow(stat("recover_damp"), dt * 60.0)
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")

func _draw() -> void:
	_draw_windup_glow()
	var rear := 0.0
	if st == "wind":
		rear = 8.0 + sin(anim * 60.0) * 2.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var body := PackedVector2Array([Vector2(-w / 2, 0), Vector2(-w / 2 + 6, -h * 0.7), Vector2(-4, -h), Vector2(w / 2 - 8, -h * 0.9 - rear), Vector2(w / 2, -h * 0.35 - rear * 0.5), Vector2(w / 2 - 4, 0)])
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	draw_colored_polygon(body, c)
	for i in 4:
		var lx := -w / 2 + 10 + i * 12
		draw_line(Vector2(lx, -4), Vector2(lx - 6 + sin(anim * 12 + i) * 3, 0), Color("#2b3527"), 3.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(w / 2 - 12, -h * 0.75 - rear), Vector2(w / 2 - 4, -h * 0.6 - rear), 3.0)
	_draw_overlay()
