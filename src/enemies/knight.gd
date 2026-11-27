## Навий витязь (GDD enemies-and-elites §3.7): one per location. Walks at the
## hero, stops at `stop`; in range and level winds up (eyes flash white), lunges,
## holds his shield (front ×sentry_block damage), rests. Rage below rage_at hp:
## shorter wind-up, faster lunge, shorter guard and rest, ×rage_walk walking.
## Wakes on his own (own pack id), red "!". Stats: enemies.json "knight".
## Never an elite. His reward (three stones) is laid by RunDirector.
class_name Knight
extends Enemy

var _hit_done: bool = false

func _load_stats() -> void:
	kind_id = "knight"
	_apply_row()
	alert_colour = Color("#ff3b3b")
	mark = ""

## Wakes on his own with the bell line «Навий витязь!» (§3.7).
func wake() -> void:
	var was := asleep
	super.wake()
	if was and world and world.director:
		world.director._say("Навий витязь!")

## True below rage_at of max hp (§3.7 «Ярость»).
func raging() -> bool:
	return hp < max_hp * stat("rage_at")

func _p(key: String) -> float:
	return stat("rage_" + key) if raging() else stat(key)

func is_winding() -> bool:
	return st == "wind"

func hit_view() -> Dictionary:
	var v := super.hit_view()
	v.shield = st == "guard"
	return v

func _behave(dt: float) -> void:
	think(dt, hero_pos())

## One tick: walk -> wind -> lunge -> guard -> rest -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "walk":
			st = "walk"
			face = 1 if dx > 0.0 else -1
			var sp := stat("speed") * (stat("rage_walk") if raging() else 1.0)
			vel.x = 0.0 if absf(dx) <= stat("stop") else signf(dx) * sp
			if cd <= 0.0 and absf(dx) < stat("range_x") and absf(hp_pos.y - position.y) < stat("range_y"):
				st = "wind"
				t = _p("wind")
				vel.x = 0.0
		"wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "lunge"
				t = stat("lunge_time")
				_hit_done = false
				vel.x = face * _p("lunge")
		"lunge":
			vel.x = face * _p("lunge")
			var p := hero()
			if p and not _hit_done and absf(p.position.x - (position.x + face * w / 2.0)) < stat("lunge_hit_x") and absf(p.position.y - position.y) < h:
				_hit_done = true
				hurt_hero(stat("dmg"), Hit.Kind.CONTACT)
			if t <= 0.0:
				st = "guard"
				t = _p("guard")
				vel.x = 0.0
		"guard":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = _p("cd")

func _draw() -> void:
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	draw_rect(Rect2(-w / 2, -h * 0.78, w, h * 0.78), c)
	if not head_off:
		draw_rect(Rect2(-w / 2 + 4, -h, w - 8, h * 0.26), c.darkened(0.2))
		draw_rect(Rect2(-w / 2 - 2, -h * 1.02, w + 4, 6), Color("#7a1f24"))
		draw_line(Vector2(-4, -h), Vector2(-4, -h - 22), Color("#b0202a"), 6.0)
	var shield_x := w / 2 + (2.0 if st == "guard" else -6.0)
	draw_rect(Rect2(shield_x, -h * 0.75, 10, h * 0.5), Color("#8c8f9e") if st == "guard" else Color("#4a4d5a"))
	if not arm_off:
		var spear := 40.0 + (40.0 if st == "lunge" else 0.0)
		draw_line(Vector2(w / 2 - 4, -h * 0.55), Vector2(w / 2 + spear, -h * 0.55), Color("#c9c3b0"), 4.0)
	elif st == "lunge":
		# One-armed: a shoulder ram with the shield forward (limb-zones §3.2).
		draw_rect(Rect2(w / 2 + 2, -h * 0.75, 12, h * 0.5), Color("#8c8f9e"))
	_draw_windup_outline(PackedVector2Array([Vector2(-w / 2, 0), Vector2(-w / 2, -h), Vector2(w / 2, -h), Vector2(w / 2, 0)]))
	var eye := 4.0 if st == "wind" else 2.5
	_draw_eyes(Vector2(4, -h * 0.88), Vector2(14, -h * 0.88), eye, face)
	_draw_overlay()
	draw_string(ThemeDB.fallback_font, Vector2(-80, -h - 34), "Навий витязь", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color("#ff8a8a"))
