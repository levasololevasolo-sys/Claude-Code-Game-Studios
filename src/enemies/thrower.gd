## Упырь-метатель, the ranged thrower (GDD enemies-and-elites §3.2, §3.4; split
## from the old shield shooter 27.11). Keeps its distance, lobs a stone in an arc
## after a clear wind-up (the arm goes back, the hand glows), runs from a hero who
## comes close and, cornered at a wall, shoves him with a weak melee blow. The
## shove can be parried and the parry cuts the throwing arm (limb-zones §3.2:
## `arm_states` = shove only); one-armed it throws weaker and slower. A stone
## caught in the parry window flies back at it (parry §3.5).
## Stats: enemies.json "thrower".
class_name Thrower
extends Enemy

## Shove cooldown, s.
var cd2: float = 0.0

func _load_stats() -> void:
	kind_id = "thrower"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "aim" or st == "shove"

## Hand point in world space (the stone leaves from here, raised behind the head).
func muzzle() -> Vector2:
	return position + Vector2(-face * stat("muzzle_x"), -stat("muzzle_y"))

## True when running from the hero at `dx` would put it against a wall.
func cornered(dx: float) -> bool:
	if room_w <= 0.0:
		return false
	var m := w / 2.0 + Tune.f("wall_margin") + stat("corner_px")
	return (dx > 0.0 and position.x < m) or (dx < 0.0 and position.x > room_w - m)

## Launch velocity of a lob from `from` that comes down on `to` (F: flight time
## T = clamp(|dx| / speed, t_min, t_max), vx = dx / T, vy = (dy - g T² / 2) / T).
static func lob_velocity(from: Vector2, to: Vector2, speed: float, t_min: float, t_max: float, g: float) -> Vector2:
	var d := to - from
	var tt := clampf(absf(d.x) / maxf(speed, 1.0), t_min, t_max)
	return Vector2(d.x / tt, (d.y - 0.5 * g * tt * tt) / tt)

## One tick: walk (keep distance / flee) -> aim -> throw -> walk; cornered and
## close: shove wind-up -> shove -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd2 -= dt
	var dx := hp_pos.x - position.x
	var adx := absf(dx)
	if st != "shove" and st != "aim" and dx != 0.0:
		face = 1 if dx > 0.0 else -1
	match st:
		"shove":
			vel.x = 0.0
			if t <= 0.0:
				cd2 = stat("shove_cd")
				if adx < stat("shove_hit_x") and absf(hp_pos.y - position.y) < stat("shove_hit_y") and int(signf(dx)) == face:
					# Still "shove" here, so a parry (Player.hurt -> parried) takes the arm.
					hurt_hero(stat("shove_dmg"), Hit.Kind.CONTACT)
				if st == "shove":
					vel.x = face * stat("shove_push")
					st = "walk"
		"aim":
			vel.x = 0.0
			if t <= 0.0:
				var from := muzzle()
				var to := Vector2(hp_pos.x, hp_pos.y - Tune.f("hero_aim_dy"))
				var g := stat("lob_grav")
				var s := fire(from, lob_velocity(from, to, stat("lob_speed"), stat("lob_t_min"), stat("lob_t_max"), g), stat("shot_r"), stat("shot_dmg"), stat("shot_life"))
				s.grav = g
				st = "walk"
				var j := stat("fire_jitter")
				cd = stat("fire") * rng.randf_range(1.0 - j, 1.0 + j)
		_:
			st = "walk"
			cd -= dt
			var stuck := cornered(dx)
			if adx < stat("flee_range") and not stuck:
				vel.x = -signf(dx) * stat("flee_speed")
			elif adx > stat("keep_max"):
				vel.x = signf(dx) * stat("walk_speed")
			elif adx < stat("keep_min") and not stuck:
				vel.x = -signf(dx) * stat("back_speed")
			else:
				vel.x = 0.0
			if stuck and adx < stat("shove_range") and cd2 <= 0.0:
				st = "shove"
				t = stat("shove_wind")
				vel.x = 0.0
			elif cd <= 0.0 and adx < stat("fire_range") and (adx >= stat("flee_range") or stuck):
				st = "aim"
				t = stat("aim")
				vel.x = 0.0

func _draw() -> void:
	_draw_windup_glow()
	if st == "aim":
		_draw_glow(muzzle() - position, 22.0, Color(String(stats.eye)), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var top := 0.8 if head_off else 1.0
	# Hunched, narrower than the shield-bearer, no shield: a stone pouch on the hip.
	var body := PackedVector2Array([Vector2(-w / 2, 0), Vector2(-w / 2 - 2, -h * 0.7), Vector2(-4, -h * top), Vector2(10, -h * (top - 0.04)), Vector2(w / 2, -h * 0.72), Vector2(w / 2 - 4, 0)])
	draw_colored_polygon(body, c)
	draw_circle(Vector2(-w * 0.35, -h * 0.35), 7.0, Color(String(stats.pouch)))
	var arm_c := c.darkened(0.2)
	var root := Vector2(-w * 0.1, -h * 0.72)
	if not arm_off:
		var hand := Vector2(w * 0.7, -h * 0.55)
		if st == "aim":
			hand = Vector2(-stat("muzzle_x"), -stat("muzzle_y"))
		elif st == "shove":
			hand = Vector2(w * 1.1, -h * 0.5)
		draw_line(root, hand, arm_c, 5.0)
		if st == "aim":
			draw_circle(hand, stat("shot_r") * 0.8, Color(String(stats.eye)))
	else:
		# One-armed: the stump; the stone goes underhand with the other arm.
		draw_line(root, root + Vector2(-6, 10), arm_c, 6.0)
		if st == "aim":
			draw_line(Vector2(w * 0.2, -h * 0.6), Vector2(w * 0.5, -h * 0.25), arm_c, 4.0)
			draw_circle(Vector2(w * 0.5, -h * 0.25), stat("shot_r") * 0.7, Color(String(stats.eye)))
	_draw_windup_outline(body)
	_draw_eyes(Vector2(2, -h * 0.86), Vector2(10, -h * 0.85), 2.5, face)
	_draw_overlay()
