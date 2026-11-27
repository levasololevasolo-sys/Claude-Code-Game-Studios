## Снежный волк, the pack runner of Царство Морены (GDD enemies-and-elites §3.2:
## «бежит парой, кусает и отскакивает»; frost roster §3.3). Runs at the hero; in
## range it crouches (wind-up: flattens, the eye glows), bites forward with a low
## hop (touch ×bite_mult), then hops back away and recovers. Stats: enemies.json "wolf".
class_name Wolf
extends Enemy

## Direction of the current bite (-1/1).
var bdir: int = 1

func _load_stats() -> void:
	kind_id = "wolf"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "crouch"

## The bite hits harder on touch (§3.1 rule: ×1.5-ish in the dash).
func contact_damage() -> float:
	return stat("contact") * (stat("bite_mult") if st == "bite" else 1.0)

## One tick: run -> crouch (telegraph) -> bite -> hop (back off) -> recover -> run.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "run":
			st = "run"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed") if absf(dx) > stat("stop") else 0.0
			if cd <= 0.0 and absf(dx) < stat("range_x") and absf(hp_pos.y - position.y) < stat("range_y"):
				st = "crouch"
				t = stat("crouch")
				vel.x = 0.0
		"crouch":
			vel.x = 0.0
			face = int(signf(dx)) if dx != 0.0 else face
			if t <= 0.0:
				st = "bite"
				bdir = face
				t = stat("bite_time")
				vel.y = -stat("bite_up")
		"bite":
			vel.x = bdir * stat("bite_speed")
			if t <= 0.0:
				st = "hop"
				t = stat("hop_time")
				vel.x = -bdir * stat("hop_speed")
				vel.y = -stat("hop_up")
		"hop":
			vel.x = -bdir * stat("hop_speed")
			if t <= 0.0:
				st = "recover"
				t = stat("recover")
				vel.x = 0.0
		"recover":
			vel.x = 0.0
			if t <= 0.0:
				st = "run"
				cd = _stat_range("cd_min", "cd_max")

func _draw() -> void:
	if _skin_draw():
		return
	_draw_windup_glow()
	var low := 10.0 if st == "crouch" else 0.0
	var stretch := 14.0 if st == "bite" else 0.0
	draw_set_transform(Vector2(0, low * 0.5), 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var mane := Color(String(stats.get("mane", "#dde8f0")))
	var top := -h + low
	var body := PackedVector2Array([Vector2(-w * 0.5, top * 0.45), Vector2(-w * 0.35, top * 0.9), Vector2(w * 0.15, top * 0.95),
		Vector2(w * 0.35 + stretch, top * 1.05), Vector2(w * 0.6 + stretch, top * 0.7), Vector2(w * 0.4 + stretch, top * 0.45),
		Vector2(w * 0.3, top * 0.35), Vector2(-w * 0.4, top * 0.35)])
	draw_colored_polygon(body, c)
	# ears, snowy mane ridge, tail
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3 + stretch, top * 1.0), Vector2(w * 0.36 + stretch, top * 1.35), Vector2(w * 0.44 + stretch, top * 0.95)]), c)
	draw_polyline(PackedVector2Array([Vector2(-w * 0.35, top * 0.9), Vector2(0, top * 0.98), Vector2(w * 0.3 + stretch, top * 1.02)]), mane, 4.0)
	draw_line(Vector2(-w * 0.5, top * 0.5), Vector2(-w * 0.75, top * 0.75 + sin(anim * 8.0) * 4.0), c, 6.0)
	# legs: run cycle, tucked in the crouch
	for i in 4:
		var lx := -w * 0.35 + i * w * 0.22
		var sw := 0.0 if st == "crouch" else sin(anim * 16.0 + i * 1.7) * 7.0
		draw_line(Vector2(lx, top * 0.4), Vector2(lx + sw, -2.0), c.darkened(0.25), 4.0)
	if st == "bite":
		draw_line(Vector2(w * 0.6 + stretch, top * 0.62), Vector2(w * 0.45 + stretch, top * 0.5), Color("#f3f6fa"), 2.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(w * 0.42 + stretch, top * 0.82), Vector2(w * 0.5 + stretch, top * 0.8), 2.6, face)
	_draw_overlay()
