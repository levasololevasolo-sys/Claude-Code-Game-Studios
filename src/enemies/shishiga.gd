## Шишига, the clinging imp (GDD bestiary §3.2 card 4, mechanic cling, §4 B7).
## Hops at the hero, crouches and squeaks (0.6 s wind-up), leaps; a leap that
## lands on the hero latches on his shoulders: small damage every cling_tick,
## the hero runs cling_slow slower per clinger (at most cling_max). A dash, a
## roll or a pogo off a foe throws it off, stunned (shaken_stun); it lets go by
## itself after cling_time. The leap is parried like a melee blow: stun only
## (no arm). Stats: enemies.json "shishiga".
class_name Shishiga
extends Enemy

## The hero it hangs on (null = not clinging).
var latched_to: Player = null
## Seconds on the hero so far.
var clung_for: float = 0.0
## Seconds to the next cling bite.
var tick_t: float = 0.0
## True once the current leap has touched the hero.
var leap_hit: bool = false

func _ready() -> void:
	super()
	Events.hero_acted.connect(on_hero_acted)

func _exit_tree() -> void:
	release()

func _load_stats() -> void:
	kind_id = "shishiga"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "crouch"

func contact_damage() -> float:
	return 0.0

## One tick: walk (hops) -> crouch -> leap -> cling | recover -> walk.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "walk":
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed")
			if cd <= 0.0 and on_ground() and SwampRules.in_reach(dx, hp_pos.y - position.y, stat("leap_range"), stat("range_y")):
				st = "crouch"
				t = stat("crouch")
				vel.x = 0.0
		"crouch":
			vel.x = 0.0
			if t <= 0.0:
				st = "leap"
				leap_hit = false
				vel.x = face * stat("leap_speed")
				vel.y = -stat("leap_up")
				t = stat("leap_time")
		"leap":
			if not leap_hit and hurt_rect().intersects(SwampRules.hero_rect(hp_pos)):
				leap_hit = true
				_leap_touch()
			if st == "leap" and on_ground() and vel.y >= 0.0 and t < stat("leap_time") - stat("leap_min_air"):
				st = "recover"
				t = stat("recover")
				vel.x = 0.0
		"cling":
			clung_for += dt
			tick_t -= dt
			var p := latched_to
			if p == null or not is_instance_valid(p) or p.dead:
				drop(false)
				return
			position = p.position + Vector2(-p.face * stat("cling_dx"), -stat("cling_dy"))
			vel = Vector2.ZERO
			face = p.face
			if tick_t <= 0.0:
				tick_t = stat("cling_tick")
				hurt_hero(stat("cling_dmg"), Hit.Kind.TICK)
			if SwampRules.cling_over(clung_for, stat("cling_time")):
				drop(false)
		"recover":
			vel.x *= pow(0.85, dt * 60.0)
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")

## The leap met the hero: bite (parryable) and latch when there is room on him.
func _leap_touch() -> void:
	var p := hero()
	var dmg := hurt_hero(stat("leap_dmg"), Hit.Kind.CONTACT)
	# A parry inside hurt_hero already knocked it out of "leap".
	if st != "leap" or p == null:
		return
	if dmg > 0.0 and SwampRules.can_latch(p.cling_n, int(Tune.f("cling_max"))):
		latch(p)

## Hangs on `p`: counts itself in p.cling_n (the slow, B7).
func latch(p: Player) -> void:
	latched_to = p
	p.cling_n += 1
	st = "cling"
	clung_for = 0.0
	tick_t = stat("cling_tick")
	vel = Vector2.ZERO
	Audio.play_at(&"cling_latch", position)

## Lets go of the hero; `shaken` = thrown off (stunned, pushed away).
func drop(shaken: bool) -> void:
	var p := latched_to
	release()
	st = "recover"
	t = stat("recover")
	if shaken:
		stun = maxf(stun, stat("shaken_stun"))
		var side := -1.0
		if p and is_instance_valid(p):
			side = -float(p.face)
		vel = Vector2(side * stat("shaken_push"), -stat("shaken_up"))
		_mark().say("Стряхнул!", Tune.f("limb_word_time") * 0.6)

## Uncounts itself from the hero's clingers (safe to call twice).
func release() -> void:
	if latched_to and is_instance_valid(latched_to):
		latched_to.cling_n = maxi(0, latched_to.cling_n - 1)
	latched_to = null

## Events.hero_acted: a dash, a roll or a pogo throws it off.
func on_hero_acted(action: StringName, _power: float) -> void:
	if st == "cling" and not dead and SwampRules.shakes_off(action):
		drop(true)

func _after_hurt(_hit: Hit) -> void:
	if st == "cling" and (stun > 0.0 or hp <= 0.0):
		drop(true)

func _dead_tick(dt: float) -> void:
	release()
	super(dt)

func _draw() -> void:
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var outline := Color("#120d12")
	var squat := 6.0 if st == "crouch" else 0.0
	# Frog-legged imp: wide haunches, a hummock head with a sedge tuft, long fingers.
	var body := PackedVector2Array([Vector2(-w / 2 - 4, 0), Vector2(-w / 2, -h * 0.45 + squat), Vector2(-w * 0.2, -h * 0.8 + squat),
		Vector2(w * 0.35, -h * 0.75 + squat), Vector2(w / 2 + 2, -h * 0.35 + squat), Vector2(w / 2 + 4, 0)])
	draw_colored_polygon(body, outline)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(p * 0.86 + Vector2(0, -1))
	draw_colored_polygon(inner, c)
	var head := Vector2(w * 0.1, -h * 0.85 + squat)
	if not head_off:
		draw_circle(head, 10.0, outline)
		draw_circle(head, 8.5, c.lightened(0.08))
		var sedge := Color(String(stats.sedge))
		for i in 4:
			var a := -1.9 + i * 0.35
			draw_line(head + Vector2(0, -6), head + Vector2(cos(a) * 14, -6 + sin(a) * 14), sedge, 2.0)
		draw_circle(head + Vector2(cos(-1.2) * 14, -6 + sin(-1.2) * 14), 2.0, Color("#b6e36b"))
	# Haunch legs folded (walk/crouch) or stretched (leap).
	var leg := Vector2(-w * 0.55, -2) if st != "leap" else Vector2(-w * 0.9, 6)
	draw_line(Vector2(-w * 0.2, -h * 0.3 + squat), leg, outline, 6.0)
	draw_line(Vector2(-w * 0.2, -h * 0.3 + squat), leg, c.darkened(0.2), 4.0)
	# Long fingers reaching forward.
	var hand := Vector2(w * 0.6, -h * 0.4 + squat) if st != "cling" else Vector2(w * 0.3, -h * 0.05)
	for i in 3:
		draw_line(hand, hand + Vector2(8, -4 + i * 4), outline, 2.0)
	_draw_windup_outline(body)
	_draw_eyes(head + Vector2(1, 0), head + Vector2(6, 0), 2.2, face)
	_draw_overlay()
