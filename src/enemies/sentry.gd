## Упырь-щитник, the shield shooter (GDD enemies-and-elites §3.2, §3.4). Holds
## a front shield (DamageRules.shield_blocks: x sentry_block), turns slowly,
## keeps its distance, aims and fires shots, and bashes a hero right in front.
## Stats: enemies.json "sentry".
class_name Sentry
extends Enemy

## Seconds the hero has been behind it (turns after `turn`).
var turn_t: float = 0.0
## Shield bash cooldown, s.
var cd2: float = 0.0

func _load_stats() -> void:
	kind_id = "sentry"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "aim" or st == "bash"

## Muzzle point in world space.
func muzzle() -> Vector2:
	return position + Vector2(face * stat("muzzle_x"), -stat("muzzle_y"))

## One tick: walk (keep distance) -> aim -> shot -> walk, or walk -> bash -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd2 -= dt
	var dx := hp_pos.x - position.x
	var adx := absf(dx)
	var sdx := int(signf(dx))
	var want := sdx if sdx != 0 else face
	if want != face:
		turn_t += dt
		if turn_t > stat("turn"):
			face = want
			turn_t = 0.0
	else:
		turn_t = 0.0
	match st:
		"bash":
			vel.x = 0.0
			if t <= 0.0:
				vel.x = face * stat("bash_push")
				st = "walk"
				cd2 = stat("bash_cd")
				if adx < stat("bash_hit_x") and sdx == face and absf(hp_pos.y - position.y) < stat("bash_hit_y"):
					hurt_hero(stat("bash_dmg"), Hit.Kind.CONTACT)
		"aim":
			vel.x = 0.0
			if t <= 0.0:
				var from := muzzle()
				var to := Vector2(hp_pos.x, hp_pos.y - Tune.f("hero_aim_dy"))
				fire(from, (to - from).normalized() * stat("shot_speed"), stat("shot_r"), stat("shot_dmg"), stat("shot_life"))
				st = "walk"
				var j := stat("fire_jitter")
				cd = stat("fire") * rng.randf_range(1.0 - j, 1.0 + j)
		_:
			st = "walk"
			if adx > stat("keep_max"):
				vel.x = face * stat("walk_speed")
			elif adx < stat("keep_min"):
				vel.x = -signf(dx) * stat("back_speed")
			else:
				vel.x = 0.0
			cd -= dt
			if adx < stat("bash_range") and cd2 <= 0.0 and sdx == face:
				st = "bash"
				t = stat("bash_wind")
			elif cd <= 0.0 and adx < stat("fire_range"):
				st = "aim"
				t = stat("aim")
				vel.x = 0.0

func _draw() -> void:
	_draw_windup_glow()
	if st == "aim":
		_draw_glow(muzzle() - position, 26.0, Color(String(stats.eye)), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var body := PackedVector2Array([Vector2(-w / 2, 0), Vector2(-w / 2 + 2, -h * 0.8), Vector2(-6, -h), Vector2(8, -h), Vector2(w / 2 - 4, -h * 0.8), Vector2(w / 2 - 6, 0)])
	draw_colored_polygon(body, c)
	var lean := -6.0 if st == "bash" else 0.0
	var shield := PackedVector2Array([Vector2(w / 2 - 4 - lean, -h * 0.85), Vector2(w / 2 + 10 - lean, -h * 0.8), Vector2(w / 2 + 10 - lean, -h * 0.15), Vector2(w / 2 - 4 - lean, -h * 0.1)])
	draw_colored_polygon(shield, Color("#8d7a55") if not (stun > 0.0) else Color("#5a4d36"))
	draw_polyline(shield + PackedVector2Array([shield[0]]), Color("#c9b88a"), 2.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(0, -h * 0.85), Vector2(8, -h * 0.85), 2.5, face)
	_draw_overlay()
