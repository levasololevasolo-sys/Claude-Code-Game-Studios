## Лесавка, the whistling root-crone (GDD bestiary §3.3 card 6, mechanic
## haste_aura). Runs from the hero (speed, keeps keep_dx). Whistles: `whistle`
## s wind-up (cheeks puff, rust sparks), then every ally within aura_r is
## hasted for haste_time s (Enemy.give_haste: moves x haste_mult, cooldowns
## x haste_cd_mult). Whistle cooldown whistle_cd. Cornered at a wall with the
## hero closer than bite_range: bite_wind -> bite; the bite is parried for a
## stun only (no arm). Stats: enemies.json "lesavka".
class_name Lesavka
extends Enemy

## Bite cooldown, s.
var bite_cd: float = 0.0
## True once the current bite has hit.
var bit: bool = false
## Allies hasted by the last whistle (for checks).
var last_hasted: int = 0

func _load_stats() -> void:
	kind_id = "lesavka"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos(), _around(stat("aura_r")))

func is_winding() -> bool:
	return st == "whistle" or st == "bite_wind"

func contact_damage() -> float:
	return 0.0

## True when an ally in `allies` could use haste now (alive, not hasted, not a boss).
static func wants_whistle(allies: Array) -> bool:
	for a in allies:
		var e := a as Enemy
		if e and not e.dead and e.haste_t <= 0.0 and not e.boss:
			return true
	return false

## Hastes every ally in `allies` within aura_r; returns how many.
func whistle_haste(allies: Array) -> int:
	var n := 0
	for a in allies:
		var e := a as Enemy
		if e == null or e.dead or e == self or e.boss:
			continue
		if not ForestRules.in_aura(center(), e.center(), stat("aura_r")):
			continue
		e.give_haste(stat("haste_mult"), stat("haste_cd_mult"), stat("haste_time"))
		n += 1
	if n > 0:
		Audio.play_at(&"haste_on", position)
	return n

func _cornered(dx: float) -> bool:
	return ForestRules.cornered(position.x, dx, w, room_w, Tune.f("wall_margin"), stat("corner_px"))

## One tick: run (keep away) -> whistle -> run; cornered and close: bite_wind
## -> bite -> run. `allies` = enemies within aura_r.
func think(dt: float, hp_pos: Vector2, allies: Array = []) -> void:
	t -= dt
	cd -= dt
	bite_cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"whistle":
			vel.x = 0.0
			if t <= 0.0:
				last_hasted = whistle_haste(allies)
				st = "run"
				cd = stat("whistle_cd")
		"bite_wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "bite"
				t = stat("bite_time")
				bit = false
		"bite":
			vel.x = 0.0
			if not bit and SwampRules.swing_hits(position, face, w, stat("bite_hit_x"), stat("bite_hit_y"), hp_pos):
				bit = true
				# Still "bite" here: a parry stuns (no arm to cut).
				hurt_hero(stat("bite_dmg"), Hit.Kind.CONTACT)
			if st == "bite" and t <= 0.0:
				st = "run"
				vel.x = 0.0
				bite_cd = stat("bite_cd")
		_:
			st = "run"
			var stuck := _cornered(dx)
			vel.x = ForestRules.flee_vx(dx, stat("keep_dx"), stat("speed"), stuck)
			if vel.x != 0.0:
				face = 1 if vel.x > 0.0 else -1
			elif dx != 0.0:
				face = 1 if dx > 0.0 else -1
			if stuck and absf(dx) < stat("bite_range") and bite_cd <= 0.0 and absf(hp_pos.y - position.y) < stat("bite_hit_y"):
				face = 1 if dx > 0.0 else -1
				st = "bite_wind"
				t = stat("bite_wind")
				vel.x = 0.0
			elif cd <= 0.0 and wants_whistle(allies):
				st = "whistle"
				t = stat("whistle")
				vel.x = 0.0

func _draw() -> void:
	var spark := Color(String(stats.spark))
	var k := 0.0
	if st == "whistle":
		k = clampf(1.0 - t / maxf(stat("whistle"), 0.01), 0.0, 1.0)
		# Rust sparks swirl up round her, the reach of the whistle shown faintly.
		draw_arc(center() - position, stat("aura_r"), 0, TAU, 48, Color(spark, 0.15 + 0.25 * k), 2.0)
		for i in 8:
			var a := anim * 5.0 + i * TAU / 8.0
			var rr := 18.0 + 22.0 * k + 6.0 * sin(anim * 9.0 + i)
			draw_circle(Vector2(cos(a) * rr, -h * 0.6 + sin(a) * rr * 0.6 - 10.0 * k), 2.5, Color(spark, 0.9))
	if _skin_draw():
		return
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var outline := Color("#120d12")
	var leaves := Color(String(stats.leaves))
	var hi := Color(String(stats.leaves_hi))
	var run := sin(anim * 14.0) if st == "run" and vel.x != 0.0 else 0.0
	# Thin legs.
	draw_line(Vector2(-4, -h * 0.35), Vector2(-6 + run * 4.0, 0), outline, 4.0)
	draw_line(Vector2(-4, -h * 0.35), Vector2(-6 + run * 4.0, 0), c, 2.0)
	draw_line(Vector2(4, -h * 0.35), Vector2(6 - run * 4.0, 0), outline, 4.0)
	draw_line(Vector2(4, -h * 0.35), Vector2(6 - run * 4.0, 0), c, 2.0)
	# Small root body.
	var body := PackedVector2Array([Vector2(-8, -h * 0.3), Vector2(-9, -h * 0.55), Vector2(9, -h * 0.55), Vector2(8, -h * 0.3)])
	draw_colored_polygon(body, c)
	# A huge mop of leaves, wider than the body, over the head.
	if not head_off:
		var mop := Vector2(-2, -h * 0.78)
		draw_circle(mop, w * 0.62 + 2.0, outline)
		for i in 7:
			var a := -PI + i * PI / 6.0
			draw_circle(mop + Vector2(cos(a) * w * 0.38, sin(a) * h * 0.18 - 2.0), w * 0.3, leaves)
		draw_circle(mop, w * 0.45, leaves)
		for i in 5:
			var a := -2.6 + i * 0.6
			draw_circle(mop + Vector2(cos(a), sin(a)) * w * 0.4, 3.5, hi)
		# Long root nose; cheeks puff in the whistle, the mouth in the bite.
		var nose_y := -h * 0.66
		draw_line(Vector2(6, nose_y), Vector2(22 + 4.0 * k, nose_y + 6.0), outline, 5.0)
		draw_line(Vector2(6, nose_y), Vector2(22 + 4.0 * k, nose_y + 6.0), c.lightened(0.15), 3.0)
		if st == "whistle":
			draw_circle(Vector2(10, -h * 0.56), 4.0 + 3.0 * k, c.lightened(0.25))
			_draw_glow(Vector2(20, -h * 0.6), 16.0, spark, 0.9)
		if st == "bite_wind" or st == "bite":
			draw_circle(Vector2(12, -h * 0.5), 4.0, Color("#120d12"))
			if st == "bite_wind":
				_draw_glow(Vector2(14, -h * 0.5), 18.0, Color("#c2502a"), 0.9)
	if is_winding():
		# Wind-up outline round the leaf mop (the body is mostly leaves).
		draw_arc(Vector2(-2, -h * 0.78), w * 0.62 + 4.0, 0.0, TAU, 32, Color(1.0, 0.95, 0.8, 0.9), 3.0)
	_draw_eyes(Vector2(2, -h * 0.72), Vector2(9, -h * 0.72), 2.2, face)
	_draw_overlay()
