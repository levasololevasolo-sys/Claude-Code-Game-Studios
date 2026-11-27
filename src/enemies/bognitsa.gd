## Болотница, the false floor (GDD bestiary §3.2 card 5, mechanic false_floor).
## Placed by the room on a `bog` spot (chunks G marker): lies as a hummock
## platform the hero can stand on, two dim eyes showing. When he has stood on it
## stand_time s it bubbles and shakes (shake s telegraph), dives (the hummock
## goes, he drops), surfaces rise_dx beside him (rise s) and then fights as an
## ordinary enemy: walk -> wind (0.6 s, tina arm raised) -> swipe -> recover. It
## never returns to the hummock. A hit while in_bog makes it surface at once.
## The swipe is parried and the parry cuts the arm (limb_zones.json "bognitsa");
## one-armed it butts with the head: reach x0.5, wind-up x1.3.
## With no bog spot in the room it is spawned already surfaced (`in_bog` false).
## Stats: enemies.json "bognitsa".
class_name Bognitsa
extends Enemy

## States while it is a hummock (it holds its place, the platform is live).
const HIDDEN: Array[String] = ["hide", "bubble"]

## Set before add_child: start as a hummock on its spot (position = hummock top).
var in_bog: bool = false
## Seconds the hero has stood on the hummock.
var stand_t: float = 0.0
## True once the current swipe has hit.
var swiped: bool = false
## The one-way platform body of the hummock (null when surfaced).
var plat: StaticBody2D = null

func _load_stats() -> void:
	kind_id = "bognitsa"
	_apply_row()

func _ready() -> void:
	super()
	if in_bog:
		st = "hide"
		_make_hummock()

func _behave(dt: float) -> void:
	var p := hero()
	var standing := p != null and st == "hide" and SwampRules.on_hummock(p.position, p.is_on_floor(), position, stat("hummock_w"))
	think(dt, hero_pos(), standing)

func is_winding() -> bool:
	return st == "bubble" or st == "wind" or st == "rise"

func contact_damage() -> float:
	return 0.0

## True while it still lies as a hummock.
func is_hidden() -> bool:
	return HIDDEN.has(st)

## Hidden: the hummock is the hit box; under water: nothing to hit.
func hurt_rect() -> Rect2:
	if is_hidden():
		var hw := stat("hummock_w")
		return Rect2(position.x - hw / 2.0, position.y - 14.0, hw, stat("hummock_h") + 14.0)
	if st == "dive":
		return Rect2(position.x, position.y + 4000.0, 0.0, 0.0)
	return super()

## A hummock holds its place: no gravity, no knockback.
func _move(dt: float) -> void:
	if is_hidden():
		kb = 0.0
		vel = Vector2.ZERO
		return
	super(dt)

## One tick: hide -> bubble (telegraph) -> dive -> rise -> walk -> wind -> swipe
## -> recover -> walk. `standing` = the hero stands on the hummock now.
func think(dt: float, hp_pos: Vector2, standing: bool = false) -> void:
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"hide":
			stand_t = SwampRules.stand_tick(stand_t, standing, dt)
			if SwampRules.dive_ready(stand_t, stat("stand_time")):
				st = "bubble"
				t = stat("shake")
		"bubble":
			if t <= 0.0:
				st = "dive"
				t = stat("dive_time")
				_drop_hummock()
				position.y = Tune.f("ground_y")
		"dive":
			vel.x = 0.0
			if t <= 0.0:
				var m := w / 2.0 + Tune.f("wall_margin")
				position.x = SwampRules.rise_x(hp_pos.x, position.x, stat("rise_dx"), m, room_w - m if room_w > 0.0 else 1.0e9)
				face = 1 if hp_pos.x > position.x else -1
				st = "rise"
				t = stat("rise")
		"rise":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = 0.2
		"idle", "walk":
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed") if absf(dx) > stat("reach") * 0.7 else 0.0
			if cd <= 0.0 and SwampRules.in_reach(dx, hp_pos.y - position.y, stat("reach") + w / 2.0, stat("range_y")):
				st = "wind"
				t = stat("wind")
				vel.x = 0.0
		"wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "swipe"
				t = stat("swipe_time")
				swiped = false
		"swipe":
			vel.x = 0.0
			if not swiped and SwampRules.swing_hits(position, face, w, stat("reach"), h, hp_pos):
				swiped = true
				hurt_hero(stat("swipe_dmg"), Hit.Kind.CONTACT)
			if st == "swipe" and t <= 0.0:
				st = "recover"
				t = stat("recover")
		"recover":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")

## A hit on the hummock: it surfaces where it lies (and falls to the floor).
func _after_hurt(_hit: Hit) -> void:
	if is_hidden():
		_drop_hummock()
		st = "recover"
		t = stat("recover")

func _make_hummock() -> void:
	plat = StaticBody2D.new()
	plat.collision_layer = Player.PLATFORM_LAYER
	plat.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(stat("hummock_w"), 16.0)
	shape.shape = r
	shape.one_way_collision = true
	shape.position = Vector2(0, 8)
	plat.add_child(shape)
	add_child(plat)

func _drop_hummock() -> void:
	if plat:
		plat.queue_free()
		plat = null

func _draw() -> void:
	if _skin_draw():
		return
	if st == "dive":
		# Under water: only rings and bubbles where it went down.
		var k := 1.0 - clampf(t / maxf(stat("dive_time"), 0.01), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 20.0 + 40.0 * k, PI, TAU, 18, Color(Color("#b6e36b"), 0.6 * (1.0 - k)), 2.0)
		_draw_overlay()
		return
	if is_hidden():
		_draw_hummock()
		_draw_overlay()
		return
	_draw_windup_glow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var outline := Color("#120d12")
	var rise_k := 1.0
	if st == "rise":
		rise_k = 1.0 - clampf(t / maxf(stat("rise"), 0.01), 0.0, 1.0) * 0.6
	var hh := h * rise_k
	var top := 0.8 if head_off else 1.0
	# Wide blob, tina hair down to the water.
	var body := PackedVector2Array([Vector2(-w / 2 - 4, 0), Vector2(-w / 2, -hh * 0.55), Vector2(-w * 0.25, -hh * top),
		Vector2(w * 0.2, -hh * top), Vector2(w / 2, -hh * 0.55), Vector2(w / 2 + 4, 0)])
	draw_colored_polygon(body, outline)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(p * 0.9 + Vector2(0, -1))
	draw_colored_polygon(inner, c)
	var hair := Color(String(stats.hair))
	for i in 6:
		var x := -w * 0.4 + i * w * 0.14
		draw_line(Vector2(x, -hh * top * 0.95), Vector2(x - 4 + sin(anim * 3 + i) * 3, -2), hair, 4.0)
	draw_circle(Vector2(-w * 0.25, -hh * 0.95), 2.0, Color("#b6e36b"))
	# One long tina arm.
	var root := Vector2(w * 0.3, -hh * 0.65)
	if not arm_off:
		var hand := Vector2(w * 0.7, -hh * 0.2)
		if st == "wind":
			hand = Vector2(w * 0.2, -hh * 1.3)
		elif st == "swipe":
			hand = Vector2(w / 2 + stat("reach"), -hh * 0.45)
		draw_line(root, hand, outline, 8.0)
		draw_line(root, hand, hair.lightened(0.25), 5.0)
		if st == "wind":
			_draw_glow(hand, 24.0, Color("#c2502a"), 0.9)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(w * 0.05, -hh * 0.8), Vector2(w * 0.2, -hh * 0.8), 2.5, face)
	_draw_overlay()

## The hummock: a moss mound with sedge; it trembles and bubbles in the telegraph.
func _draw_hummock() -> void:
	var hw := stat("hummock_w")
	var hh := stat("hummock_h")
	var shake := sin(anim * 70.0) * 3.0 if st == "bubble" else 0.0
	var o := Vector2(shake, 0)
	var outline := Color("#120d12")
	var moss := Color.WHITE if flash > 0.0 else Color(String(stats.moss))
	var mound := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		mound.append(o + Vector2(cos(a) * hw / 2.0, sin(a) * 10.0))
	for i in 13:
		var a := PI * float(i) / 12.0
		mound.append(o + Vector2(cos(a) * hw / 2.0 * 0.8, sin(a) * hh))
	draw_colored_polygon(mound, outline)
	var inner := PackedVector2Array()
	for p in mound:
		inner.append(o + (p - o) * 0.92)
	draw_colored_polygon(inner, moss)
	var sedge := Color(String(stats.sedge))
	for i in 7:
		var x := -hw * 0.35 + i * hw * 0.115
		var a := -PI / 2.0 + sin(anim * 1.5 + i) * 0.25 + (x / hw) * 0.8
		draw_line(o + Vector2(x, -6), o + Vector2(x + cos(a) * 16, -6 + sin(a) * 16), sedge, 2.0)
	draw_circle(o + Vector2(-hw * 0.2, -20), 2.0, Color("#b6e36b"))
	draw_circle(o + Vector2(hw * 0.25, -19), 2.0, Color("#b6e36b"))
	if st == "bubble":
		_draw_glow(o + Vector2(0, -4), hw * 0.6, Color("#c2502a"), 0.8)
		for i in 4:
			var ph := fmod(anim * 1.8 + i * 0.27, 1.0)
			draw_arc(o + Vector2(-hw * 0.3 + i * hw * 0.2, -6 - ph * 26.0), 3.0 + ph * 3.0, 0, TAU, 10, Color(Color("#b6e36b"), 1.0 - ph), 1.5)
	# Two dim eyes in the side of the mound.
	_draw_eyes(o + Vector2(-9, hh * 0.35), o + Vector2(9, hh * 0.35), 2.0)
