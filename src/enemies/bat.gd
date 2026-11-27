## Нетопырь, the air harrier (GDD enemies-and-elites §3.2, §3.4). Hovers beside
## and above the hero, winds up (rises, aims) and swoops along a straight line.
## From tier 2 it may spit a fan of globs instead. Stats: enemies.json "bat".
class_name Bat
extends Enemy

## Point the swoop is aimed at (fixed during the wind-up).
var aim: Vector2 = Vector2.ZERO

func _load_stats() -> void:
	kind_id = "bat"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "wind" or st == "spitwind"

## One tick: hover -> wind -> swoop -> hover, or hover -> spitwind -> hover.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "hover":
			st = "hover"
			var hx := hp_pos.x + (-stat("hover_dx") if position.x < hp_pos.x else stat("hover_dx"))
			var hy := hp_pos.y - stat("hover_dy") + sin(anim * stat("hover_bob_freq")) * stat("hover_bob")
			var g := stat("hover_gain")
			var r := stat("hover_resp")
			vel.x += ((hx - position.x) * g - vel.x) * dt * r
			vel.y += ((hy - position.y) * g - vel.y) * dt * r
			vel.x = clampf(vel.x, -stat("hover_max_x"), stat("hover_max_x"))
			vel.y = clampf(vel.y, -stat("hover_max_y"), stat("hover_max_y"))
			face = int(signf(dx)) if dx != 0.0 else 1
			cd -= dt
			if cd <= 0.0:
				var spit := tier >= int(stat("spit_tier")) and rng.randf() < stat("spit_chance")
				st = "spitwind" if spit else "wind"
				t = stat("wind")
		"wind":
			vel.x *= pow(stat("wind_damp"), dt * 60.0)
			vel.y = -stat("wind_rise")
			aim = Vector2(hp_pos.x, hp_pos.y - stat("aim_dy"))
			if t <= 0.0:
				vel = Vector2.from_angle((aim - center()).angle()) * stat("swoop")
				st = "swoop"
				t = stat("swoop_time")
		"spitwind":
			vel *= pow(stat("wind_damp"), dt * 60.0)
			if t <= 0.0:
				var base := (Vector2(hp_pos.x, hp_pos.y - Tune.f("hero_aim_dy")) - center()).angle()
				var n := int(stat("spit_count"))
				for i in n:
					var off := (float(i) - float(n - 1) / 2.0) * stat("spit_spread")
					fire(center(), Vector2.from_angle(base + off) * stat("spit_speed"), stat("spit_r"), stat("spit_dmg"), stat("spit_life"))
				st = "hover"
				cd = _stat_range("spit_cd_min", "spit_cd_max")
		"swoop":
			if t <= 0.0 or position.y > Tune.f("ground_y") - stat("swoop_floor"):
				st = "hover"
				cd = _stat_range("cd_min", "cd_max")

func _draw() -> void:
	if _skin_draw():
		return
	_draw_windup_glow()
	var flap := sin(anim * (30.0 if st == "swoop" else 14.0)) * 10.0
	if st == "wind":
		flap = -12.0
	var cy := -h / 2.0
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var wings := PackedVector2Array([Vector2(-6, cy), Vector2(-w / 2 - 6, cy - 6 + flap), Vector2(-w / 2 + 4, cy + 4), Vector2(-10, cy + 8), Vector2(10, cy + 8), Vector2(w / 2 - 4, cy + 4), Vector2(w / 2 + 6, cy - 6 + flap), Vector2(6, cy)])
	draw_colored_polygon(wings, c.darkened(0.2))
	var body := PackedVector2Array([Vector2(-9, cy - 10), Vector2(9, cy - 10), Vector2(11, cy + 8), Vector2(0, cy + 14), Vector2(-11, cy + 8)])
	draw_colored_polygon(body, c)
	_draw_windup_outline(wings)
	_draw_eyes(Vector2(-4 + face * 2, cy - 3), Vector2(4 + face * 2, cy - 3), 2.5)
	_draw_overlay()
