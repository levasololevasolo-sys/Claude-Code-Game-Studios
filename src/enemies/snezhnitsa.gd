## Снежница, the frost maiden (GDD bestiary §3.4 card 4, mechanic freeze_stack,
## §4 B5). Keeps 350..550 px from the hero, sliding back. Casts (0.6 s wind-up,
## arm out, three needles gather in a fan), then fires 3 needles straight at the
## hero 0.15 s apart (420 px/s). Each needle that hurts the hero adds a frost
## mark (Player.add_frost); 3 marks freeze him 0.7 s. Needles are reflected by a
## parry; every reflected needle that hits her stops her for needle_stop s.
## Head zone in the cast only. Stats: enemies.json "snezhnitsa".
class_name Snezhnitsa
extends Enemy

## Needles left to fire in this volley and the gap clock.
var left: int = 0
var gap: float = 0.0
var _hooked: Player = null

func _load_stats() -> void:
	kind_id = "snezhnitsa"
	_apply_row()

func _behave(dt: float) -> void:
	_hook_hero()
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "cast"

func contact_damage() -> float:
	return 0.0

## Listens to the hero's hurts: a needle of hers that took HP adds a mark.
func _hook_hero() -> void:
	var p := hero()
	if p == null or p == _hooked:
		return
	_hooked = p
	FrostPips.ensure(p, world)
	p.hurt_taken.connect(_on_hero_hurt)

func _on_hero_hurt(_amount: float, hit: Hit) -> void:
	if hit.source == self and hit.kind == Hit.Kind.PROJECTILE and _hooked:
		_hooked.add_frost()

## Fires one needle at the hero's chest.
func needle(hp_pos: Vector2) -> EnemyShot:
	var from := position + Vector2(face * w * 0.6, -stat("muzzle_y"))
	var to := hp_pos - Vector2(0, Player.H * 0.55)
	var v := (to - from).normalized() * stat("needle_speed")
	var s := FrostNeedle.new()
	s.position = from
	s.vel = v
	s.r = stat("needle_r")
	s.dmg = stat("needle_dmg") * dmg_mult()
	s.life = stat("needle_life")
	s.color = Color(String(stats.needle))
	s.source = self
	s.world = world
	if world:
		world.add_child(s)
	else:
		orphan_shots.append(s)
	Audio.play_at(&"needle_fly", from)
	return s

## One tick: walk (keep the band) -> cast -> volley (3 needles) -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	gap -= dt
	var dx := hp_pos.x - position.x
	if dx != 0.0:
		face = 1 if dx > 0.0 else -1
	match st:
		"cast":
			vel.x = 0.0
			if t <= 0.0:
				st = "volley"
				left = int(stat("needles"))
				gap = 0.0
		"volley":
			vel.x = 0.0
			if gap <= 0.0 and left > 0:
				needle(hp_pos)
				left -= 1
				gap = stat("needle_gap")
			if left <= 0 and gap <= 0.0:
				st = "walk"
				cd = _stat_range("cast_cd_min", "cast_cd_max")
		_:
			st = "walk"
			var kd := FrostRules.keep_dir(absf(dx), stat("keep_min"), stat("keep_max"))
			vel.x = signf(dx) * (stat("speed") if kd > 0 else -stat("back_speed")) if kd != 0 else 0.0
			if cd <= 0.0 and absf(dx) < stat("fire_range") and absf(hp_pos.y - position.y) < stat("range_y"):
				st = "cast"
				t = stat("cast")
				vel.x = 0.0

## A reflected needle (now the hero's) stops her for needle_stop s (§3.4).
func _after_hurt(hit: Hit) -> void:
	if hit.kind == Hit.Kind.PROJECTILE and hit.source is Player:
		stun = maxf(stun, stat("needle_stop"))
		st = "walk"
		left = 0

func _draw() -> void:
	if _skin_draw():
		return
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var dress := Color(String(stats.dress))
	var outline := Color("#2c3b52")
	# Tall thin figure, triangle skirt, symmetric.
	var skirt := PackedVector2Array([Vector2(-w * 0.75, 0), Vector2(0, -h * 0.62), Vector2(w * 0.75, 0)])
	draw_colored_polygon(skirt, outline)
	var inner := PackedVector2Array([Vector2(-w * 0.66, -2), Vector2(0, -h * 0.58), Vector2(w * 0.66, -2)])
	draw_colored_polygon(inner, dress)
	draw_rect(Rect2(-w * 0.18, -h * 0.82, w * 0.36, h * 0.26), outline)
	draw_rect(Rect2(-w * 0.14, -h * 0.8, w * 0.28, h * 0.24), c)
	if not head_off:
		draw_circle(Vector2(0, -h * 0.87), 9.0, outline)
		draw_circle(Vector2(0, -h * 0.87), 7.5, c)
		# Snowflake kokoshnik: a fan of six ice rays.
		var crown := Color(String(stats.crown))
		for i in 7:
			var a := PI + PI * (i + 0.5) / 7.0
			var tip := Vector2(0, -h * 0.9) + Vector2(cos(a), sin(a)) * 18.0
			draw_line(Vector2(0, -h * 0.9), tip, crown, 2.5)
			draw_circle(tip, 2.5, Color("#8fd3f5"))
	# Arms: by her side; in the cast the front arm is out and three needles fan.
	var sh := Vector2(w * 0.1, -h * 0.78)
	var hand := Vector2(w * 0.3, -h * 0.5)
	if st == "cast" or st == "volley":
		hand = Vector2(w * 0.9, -stat("muzzle_y") + 2.0)
	draw_line(sh, hand, outline, 5.0)
	draw_line(sh, hand, c, 3.0)
	draw_line(Vector2(-w * 0.1, -h * 0.78), Vector2(-w * 0.3, -h * 0.5), c, 3.0)
	if st == "cast":
		var k := clampf(1.0 - t / maxf(stat("cast"), 0.01), 0.0, 1.0)
		var nc := Color(String(stats.needle))
		for i in 3:
			var a := (i - 1) * 0.35 * (1.0 - 0.6 * k)
			var d := Vector2(cos(a), sin(a))
			draw_line(hand + d * 6.0, hand + d * (16.0 + 14.0 * k), nc, 3.0)
			draw_circle(hand + d * (16.0 + 14.0 * k), 2.5, Color.WHITE)
		_draw_glow(hand, 18.0 + 14.0 * k, Color(String(stats.eye)), 0.9)
	_draw_windup_outline(skirt)
	_draw_eyes(Vector2(-3, -h * 0.88), Vector2(3, -h * 0.88), 2.2 if st != "cast" else 3.0, face)
	_draw_overlay()
