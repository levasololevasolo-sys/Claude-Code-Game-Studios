## Упырь-щитник, the melee shield-bearer (GDD enemies-and-elites §3.2, §3.4;
## split from the old shield shooter 27.11, the stones went to Упырь-метатель).
## Holds a front shield that stops hero hits from the front (x shield_block of
## its row, DamageRules.shield_blocks), turns slowly, walks up and does a slow
## shield bash with a long wind-up. A parried bash only stuns it (the shield arm
## is never cut, limb-zones §3.1, parry §3.3); stunned, the shield does not hold.
## Head zone: yes. Stats: enemies.json "sentry".
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
	return st == "bash"

## One tick: walk (up to `stop`) -> bash wind-up -> blow -> recover -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd2 -= dt
	var dx := hp_pos.x - position.x
	var adx := absf(dx)
	var sdx := int(signf(dx))
	var want := sdx if sdx != 0 else face
	if want != face and st != "bash":
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
				st = "recover"
				t = stat("bash_recover")
				cd2 = stat("bash_cd")
				# Last: a parry here (Player.hurt -> parried) resets the state to idle.
				if adx < stat("bash_hit_x") and sdx == face and absf(hp_pos.y - position.y) < stat("bash_hit_y"):
					hurt_hero(stat("bash_dmg"), Hit.Kind.CONTACT)
		"recover":
			vel.x *= stat("recover_damp")
			if t <= 0.0:
				st = "walk"
		_:
			st = "walk"
			vel.x = face * stat("walk_speed") if adx > stat("stop") and sdx == face else 0.0
			if adx < stat("bash_range") and cd2 <= 0.0 and sdx == face and absf(hp_pos.y - position.y) < stat("bash_hit_y"):
				st = "bash"
				t = stat("bash_wind")
				vel.x = 0.0

func _draw() -> void:
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var top := 0.82 if head_off else 1.0
	var body := PackedVector2Array([Vector2(-w / 2, 0), Vector2(-w / 2 + 2, -h * 0.8), Vector2(-6, -h * top), Vector2(8, -h * top), Vector2(w / 2 - 4, -h * 0.8), Vector2(w / 2 - 6, 0)])
	draw_colored_polygon(body, c)
	# The bash leans the shield back on the wind-up and forward on the blow.
	var lean := 8.0 if st == "bash" else (-10.0 if st == "recover" else 0.0)
	var shield := PackedVector2Array([Vector2(w / 2 - 4 - lean, -h * 0.92), Vector2(w / 2 + 12 - lean, -h * 0.86), Vector2(w / 2 + 12 - lean, -h * 0.08), Vector2(w / 2 - 4 - lean, -h * 0.02)])
	var sc := Color(String(stats.shield))
	draw_colored_polygon(shield, sc.darkened(0.35) if stun > 0.0 else sc)
	draw_polyline(shield + PackedVector2Array([shield[0]]), Color(String(stats.shield_rim)), 2.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(0, -h * 0.85), Vector2(8, -h * 0.85), 2.5, face)
	_draw_overlay()
