## Лихо Одноглазое, boss of Тёмный бор (GDD enemies-and-elites §3.8, §3.10;
## story-bible §2.2; lines living-world §4.2). Same cycle, phases, summons and
## death as LairBoss (Кикимора), its own attacks, every one with a glowing
## wind-up of at least min_windup s:
## - leap: crouches, leaps onto the hero's spot, two glowing ground waves on landing;
## - gaze: the one eye opens wide, a thin aim line, then a beam that turns after
##   the hero at gaze_turn rad/s (phase 2 faster and longer);
## - lunge: the ram at 560 px/s;
## - woe («лихо» = bad luck): eye sigils on the floor at the hero and at random
##   gaps around him (3, phase 2: 5); after woe_warn a dead branch falls on each.
## Deviation (approved in the task brief): §3.10's ring of 10 notes is replaced by
## gaze and woe, weights in bosses.json "likho". Phase 2 mechanic «гаснет свет»:
## every dark_every s the eye blinks for dark_blink s, then for dark_time s the
## hero's light shrinks to light_min (Darkness reads light_cap()); the eye, the
## wind-ups and the hazards still glow. All numbers: bosses.json "likho".
class_name LikhoBoss
extends LairBoss

## Gaze beam angle (rad, world space) and seconds until it may hit again.
var gaze_ang: float = 0.0
var gaze_cd: float = 0.0
## Darkness cycle: "" (off), "blink" (eye blinks, telegraph), "dark". Timer of
## the current step and seconds until the next blink.
var dark_state: String = ""
var dark_left: float = 0.0
var dark_t: float = 0.0
## Leap target x and airborne time.
var leap_x: float = 0.0

# ---------------- pure helpers (unit-tested) ----------------

## Angle `from` turned toward `to` by at most `step` rad (shortest way).
static func turn_toward(from: float, to: float, step: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -step, step)

## Distance from point p to the ray from o at angle a (length len); INF behind o.
static func ray_dist(o: Vector2, a: float, length: float, p: Vector2) -> float:
	var dir := Vector2.from_angle(a)
	var s := (p - o).dot(dir)
	if s < 0.0 or s > length:
		return INF
	return absf((p - o).cross(dir))

## Woe zone xs around the hero: the first on him, the rest at ±gap·i (side by rng),
## kept inside [edge, room_w − edge] when room_w > 0.
static func woe_xs(rng: RandomNumberGenerator, hx: float, n: int, gap: float, room_w: float, edge: float) -> Array[float]:
	var out: Array[float] = [hx]
	for i in range(1, n):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := hx + side * gap * ceilf(i / 2.0) * (1.0 if i % 2 == 1 else -1.0)
		if room_w > 0.0 and (x < edge or x > room_w - edge):
			x = hx - (x - hx)
		out.append(x if room_w <= 0.0 else clampf(x, edge, room_w - edge))
	return out

# ---------------- Enemy hooks ----------------

func _behave(dt: float) -> void:
	if not introduced:
		introduced = true
		say(story_line("intro"))
	think(dt, hero_pos())
	_redraw_fx()

func _dead_tick(dt: float) -> void:
	dark_state = ""
	# Killed mid-leap: the body falls to the floor instead of hanging in the air.
	position.y = move_toward(position.y, ground(), Tune.f("max_fall") * dt)
	super(dt)

## The leap and the lunge hit harder on touch.
func contact_damage() -> float:
	return stat("dmg") * (stat("lunge_contact_mult") if st == "lunge" or st == "leap" else stat("contact_mult"))

## Cap of the hero's light radius right now (0 = none): light_min while dark,
## eased over dark_fade at both ends.
func light_cap() -> float:
	if dead or dark_state != "dark":
		return 0.0
	var k := clampf(minf(stat("dark_time") - dark_left, dark_left) / maxf(stat("dark_fade"), 0.01), 0.0, 1.0)
	return lerpf(2000.0, AmuletRules.light_min(Tune.data), k)

## Per-phase value of a [p1, p2] stat.
func per_phase(key: String) -> float:
	var v: Variant = stats.get(key, 0.0)
	if v is Array:
		var a := v as Array
		return float(a[mini(phase, a.size()) - 1])
	return float(v)

## Eye position in world space.
func eye_pos() -> Vector2:
	return position + Vector2(face * w * 0.12, -h * stat("gaze_eye_y"))

func _enter_rage() -> void:
	super()
	dark_t = stat("dark_first")

# ---------------- behaviour ----------------

## One tick of the state machine, the darkness cycle and the hazards.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	line_t -= dt
	gaze_cd -= dt
	var dx := hp_pos.x - position.x
	var hc := hp_pos - Vector2(0, Player.H / 2.0)
	if st != "lunge" and st != "leap" and st != "gaze":
		face = int(signf(dx)) if dx != 0.0 else face
	var mw := stat("min_windup")
	match st:
		"idle":
			vel.x = face * stat("walk_speed") if absf(dx) > stat("walk_keep") else 0.0
			if t <= 0.0:
				vel.x = 0.0
				if not summon_queue.is_empty():
					st = "summon_w"
					t = windup(stat("summon_wind"), fast(), mw)
				elif ng_pick(hp_pos):
					pass
				else:
					var names: Array = stats.get("attacks", [])
					var rows: Array = stats.get("weights", [])
					var a := String(names[pick_attack(rng.randf(), rows[mini(phase, rows.size()) - 1])])
					attack_log.append(a)
					st = a + "_w"
					t = windup(stat(a + "_wind"), fast(), mw)
					if a == "gaze":
						gaze_ang = (hc - eye_pos()).angle()
		"leap_w":
			vel.x = 0.0
			if t <= 0.0:
				st = "leap"
				leap_x = hp_pos.x if room_w <= 0.0 else clampf(hp_pos.x, w, room_w - w)
				var air := 2.0 * stat("leap_up") / maxf(Tune.f("gravity"), 1.0)
				vel.y = -stat("leap_up")
				vel.x = (leap_x - position.x) / air
				t = air
		"leap":
			# Lands on the floor after leap_land s of air; t < -leap_land is the
			# safety net (a test drives think() without moving it).
			if (on_ground() and vel.y >= 0.0 and t < 2.0 * stat("leap_up") / maxf(Tune.f("gravity"), 1.0) - stat("leap_land")) or t < -stat("leap_land"):
				vel = Vector2.ZERO
				for d: int in [-1, 1]:
					hazards.append({ "kind": "wave", "x": position.x + d * w * 0.5, "dir": d, "t": stat("wave_life"), "hit": false, "v": per_phase("wave_speed") })
				if world:
					world.add_shake(stat("leap_shake"))
				_rest(0.0)
		"gaze_w":
			vel.x = 0.0
			gaze_ang = (hc - eye_pos()).angle()
			if t <= 0.0:
				st = "gaze"
				t = ngv("time", 1.8) if ng_gaze else per_phase("gaze_time")
		"gaze":
			vel.x = 0.0
			var turn := ngv("turn", 1.1) if ng_gaze else per_phase("gaze_turn")
			gaze_ang = turn_toward(gaze_ang, (hc - eye_pos()).angle(), turn * dt)
			face = 1 if cos(gaze_ang) >= 0.0 else -1
			var glen := ngv("len", 1500.0) if ng_gaze else stat("gaze_len")
			var gw := ngv("w", 34.0) if ng_gaze else stat("gaze_w")
			if gaze_cd <= 0.0 and ray_dist(eye_pos(), gaze_ang, glen, hc) < gw / 2.0 + Player.W / 2.0 and _hero_open():
				gaze_cd = ngv("hit_cd", 0.5) if ng_gaze else stat("gaze_hit_cd")
				hurt_hero(stat("dmg") * (ngv("dmg", 0.55) if ng_gaze else stat("gaze_dmg_mult")), Hit.Kind.PROJECTILE)
			if t <= 0.0:
				ng_gaze = false
				_rest(stat("gaze_rest_add"))
		"lunge_w":
			vel.x = 0.0
			if t <= 0.0:
				st = "lunge"
				t = stat("lunge_time")
				ldir = face
		"lunge":
			vel.x = ldir * stat("lunge_speed")
			var wall := room_w > 0.0 and ((ldir < 0 and position.x < stat("lunge_wall")) or (ldir > 0 and position.x > room_w - stat("lunge_wall")))
			if t <= 0.0 or wall:
				vel.x = 0.0
				if world:
					world.add_shake(stat("lunge_shake"))
				_rest(0.0)
		"woe_w":
			vel.x = 0.0
			if t <= 0.0:
				for x in woe_xs(rng, hp_pos.x, int(per_phase("woe_n")), stat("woe_gap"), room_w, stat("woe_edge")):
					hazards.append({ "kind": "woe", "x": x, "t": 0.0, "hit": false })
				_rest(stat("woe_rest_add"))
		"summon_w":
			vel.x = 0.0
			if t <= 0.0:
				_summon(summon_queue.pop_front())
				_rest(0.0)
		"roar":
			vel.x = 0.0
			if t <= 0.0:
				_rest(0.0)
	if st.begins_with("ng_"):
		_ng_tick(dt, hp_pos)
	_tick_dark(dt)
	_tick_hazards(dt, hp_pos)

# ---------------- NG+ moves (artifacts-and-secrets §3.7) ----------------

## The NG+ gaze (Взгляд из темноты) uses boss_ng.json numbers.
var ng_gaze: bool = false
var _leap_k: float = 1.0
var _land_hit: bool = false

func _start_leap(hp_pos: Vector2, up_k: float) -> void:
	leap_x = hp_pos.x if room_w <= 0.0 else clampf(hp_pos.x, w, room_w - w)
	_leap_k = up_k
	var up := stat("leap_up") * up_k
	var air := 2.0 * up / maxf(Tune.f("gravity"), 1.0)
	vel.y = -up
	vel.x = (leap_x - position.x) / air
	t = air
	st = "ng_leap"

func _ng_fire(id: String, hp_pos: Vector2) -> void:
	match id:
		"likho_double_leap":
			ng_n = 2
			_start_leap(hp_pos, 1.0)
		"likho_blind_gaze":
			dark_state = "dark"
			dark_left = ngv("dark", 3.0)
			ng_gaze = true
			st = "gaze_w"
			t = ngv("pre", 0.3)
		"likho_woe_cage":
			var sw := ngv("w", 110.0)
			for d: int in [-1, 1]:
				var x := hp_pos.x + d * ngv("side_dx", 230.0)
				if room_w > 0.0:
					x = clampf(x, stat("woe_edge"), room_w - stat("woe_edge"))
				hazards.append({ "kind": "woe", "x": x, "t": 0.0, "hit": false, "warn": ngv("warn", 1.0), "act": ngv("act", 0.45), "w": sw, "dmgk": ngv("dmg", 1.0) })
			hazards.append({ "kind": "woe", "x": hp_pos.x, "t": -(ngv("warn", 1.0) + ngv("mid_delay", 0.5)), "hit": false,
				"warn": ngv("mid_warn", 0.6), "act": ngv("act", 0.45), "w": sw, "dmgk": ngv("dmg", 1.0) })
			_rest(stat("woe_rest_add"))
		_:
			_rest(0.0)

func _ng_tick(dt: float, hp_pos: Vector2) -> void:
	match st:
		"ng_w":
			vel.x = 0.0
			if t <= 0.0:
				_ng_fire(String(ng_row.get("id", "")), hp_pos)
		"ng_leap":
			var air := 2.0 * stat("leap_up") * _leap_k / maxf(Tune.f("gravity"), 1.0)
			if (on_ground() and vel.y >= 0.0 and t < air - stat("leap_land")) or t < -stat("leap_land"):
				vel = Vector2.ZERO
				var second := ng_n <= 1
				var v := per_phase("wave_speed") + (ngv("wave_add", 80.0) if second else 0.0)
				for d: int in [-1, 1]:
					hazards.append({ "kind": "wave", "x": position.x + d * w * 0.5, "dir": d, "t": stat("wave_life"), "hit": false, "v": v, "dmgk": ngv("dmg_wave", 0.7) })
				if absf(hp_pos.x - position.x) < w * 0.7 and _hero_open():
					hurt_hero(stat("dmg") * ngv("dmg_land", 1.3), Hit.Kind.STRIKE)
				if world:
					world.add_shake(stat("leap_shake"))
				ng_n -= 1
				if ng_n > 0:
					st = "ng_gap"
					t = ngv("gap", 0.35)
				else:
					_rest(0.0)
		"ng_gap":
			vel.x = 0.0
			if t <= 0.0:
				_start_leap(hp_pos, ngv("up_k", 0.8))

## Phase 2 «гаснет свет»: off -> blink (telegraph) -> dark -> off, every dark_every s.
func _tick_dark(dt: float) -> void:
	if (phase < 2 and dark_state != "dark") or dead:
		dark_state = ""
		return
	match dark_state:
		"":
			dark_t -= dt
			if dark_t <= 0.0:
				dark_state = "blink"
				dark_left = stat("dark_blink")
		"blink":
			dark_left -= dt
			if dark_left <= 0.0:
				dark_state = "dark"
				dark_left = stat("dark_time")
		"dark":
			dark_left -= dt
			if dark_left <= 0.0:
				dark_state = ""
				dark_t = maxf(stat("dark_every") - stat("dark_time") - stat("dark_blink"), 0.0)

func _tick_hazards(dt: float, hp_pos: Vector2) -> void:
	var ground := ground()
	var dmg := stat("dmg")
	for hz: Dictionary in hazards:
		match String(hz.kind):
			"wave":
				hz.t -= dt
				hz.x = float(hz.x) + int(hz.dir) * float(hz.v) * dt
				if room_w > 0.0 and (hz.x < 0.0 or hz.x > room_w):
					hz.t = 0.0
				if not hz.hit and absf(hp_pos.x - float(hz.x)) < stat("wave_w") \
						and hp_pos.y > ground - stat("wave_h") and _hero_open():
					hz.hit = true
					hurt_hero(dmg * float(hz.get("dmgk", stat("wave_dmg_mult"))), Hit.Kind.PROJECTILE)
			"woe":
				hz.t += dt
				var warn := float(hz.get("warn", stat("woe_warn")))
				if not hz.hit and hz.t > warn and hz.t < warn + float(hz.get("act", stat("woe_act"))) \
						and absf(hp_pos.x - float(hz.x)) < float(hz.get("w", stat("woe_w"))) / 2.0 + Player.W / 2.0 and _hero_open():
					hz.hit = true
					hurt_hero(dmg * float(hz.get("dmgk", stat("woe_dmg_mult"))), Hit.Kind.PROJECTILE)
				if absf(hz.t - warn) < dt and world:
					world.add_shake(5.0)
	hazards.assign(hazards.filter(func(hz: Dictionary) -> bool:
		if hz.kind == "woe":
			return float(hz.t) < float(hz.get("warn", stat("woe_warn"))) + float(hz.get("act", stat("woe_act"))) + 0.25
		return float(hz.t) > 0.0))

# ---------------- light and drawing ----------------

func light_spots() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var e := eye_pos()
	var big := 1.6 if dark_state != "" or st == "gaze" or st == "gaze_w" else 1.0
	out.append(Vector4(e.x, e.y, 70.0 * big, 1.0))
	if is_winding():
		var c := center()
		out.append(Vector4(c.x, c.y, Tune.f("windup_glow_r"), Tune.f("windup_glow_a")))
	var r := stat("hazard_glow_r")
	var a := stat("hazard_glow_a")
	var ground := ground()
	for hz: Dictionary in hazards:
		match String(hz.kind):
			"wave":
				out.append(Vector4(float(hz.x), ground - 24.0, r, a))
			"woe":
				out.append(Vector4(float(hz.x), ground - 20.0, r, a))
	if st == "gaze" or st == "gaze_w":
		var dir := Vector2.from_angle(gaze_ang)
		for i in range(1, 9):
			var p := e + dir * (stat("gaze_len") * i / 9.0)
			out.append(Vector4(p.x, p.y, 46.0 if st == "gaze" else 26.0, a))
	return out

func _draw() -> void:
	if _skin_draw():
		return
	if dead:
		var k := clampf(_linger / maxf(stat("death_linger"), 0.01), 0.0, 1.0)
		draw_set_transform(Vector2(0, h * 0.5 * k), 0.0, Vector2(face, 1.0 - 0.5 * k))
	else:
		_draw_windup_glow()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var wind := is_winding()
	var crouch := 30.0 if st == "leap_w" else 0.0
	var lean := 22.0 if st == "lunge" else (6.0 + sin(anim * 1.2) * 4.0)
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var bark := Color(String(stats.bark))
	# a tall thin hunched shape: narrow trunk-body, a big round head with one eye
	var top := -h + crouch
	var body := PackedVector2Array([Vector2(-w * 0.3, 0), Vector2(-w * 0.34, top * 0.5), Vector2(-w * 0.2 + lean * 0.5, top * 0.78),
		Vector2(-w * 0.42 + lean, top * 0.92), Vector2(-w * 0.2 + lean, top), Vector2(w * 0.3 + lean, top), Vector2(w * 0.46 + lean, top * 0.9),
		Vector2(w * 0.24 + lean * 0.5, top * 0.74), Vector2(w * 0.3, top * 0.45), Vector2(w * 0.26, 0)])
	draw_colored_polygon(body, c)
	for i in 4:
		var bx := -w * 0.2 + i * w * 0.13
		draw_line(Vector2(bx, -8), Vector2(bx + lean * 0.4, top * 0.7), Color(bark, 0.7), 2.0)
	# long branch arms: raised in wind-ups, forward in the lunge
	for side: int in [-1, 1]:
		var sh := Vector2(side * w * 0.3 + lean * 0.6, top * 0.72)
		var hand: Vector2
		if wind:
			hand = sh + Vector2(side * 70.0, -120.0)
		elif st == "lunge":
			hand = sh + Vector2(w * 1.1, 20.0 + side * 20.0)
		else:
			hand = sh + Vector2(side * 40.0, h * 0.55 + sin(anim * 1.5 + side) * 8.0)
		var mid := (sh + hand) / 2.0 + Vector2(side * 18.0, 0)
		draw_polyline(PackedVector2Array([sh, mid, hand]), bark, 7.0)
		for f in 3:
			draw_line(hand, hand + Vector2(side * (10.0 + f * 4.0), -14.0 + f * 12.0), bark, 3.0)
	draw_polyline(body + PackedVector2Array([body[0]]), Color(bark, 0.9), 2.0)
	_draw_windup_outline(body)
	# the one eye
	var ec := Color(String(stats.rage_eye)) if phase >= 2 else Color(String(stats.eye))
	var e := Vector2(w * 0.12 + lean * 0.8, -h * stat("gaze_eye_y") + crouch)
	var open := 1.0
	if asleep:
		open = 0.1
	elif dark_state == "blink":
		open = 0.15 if fmod(dark_left, 0.25) < 0.12 else 1.0
	elif st == "gaze" or st == "gaze_w":
		open = 1.35
	if not dead:
		var r := 16.0 * open
		draw_circle(e, 30.0 * maxf(open, 0.4), Color(ec, 0.22))
		draw_set_transform(Vector2.ZERO if not dead else Vector2(0, h * 0.5), 0.0, Vector2(face, 1))
		draw_colored_polygon(_ellipse(e, 20.0, maxf(r, 2.0)), Color("#f3e6c8"))
		draw_circle(e + Vector2(4.0, 0), maxf(r * 0.55, 1.5), ec)
		draw_circle(e + Vector2(5.0, 0), maxf(r * 0.2, 1.0), Color.BLACK)
		draw_polyline(_ellipse(e, 22.0, maxf(r, 2.0) + 2.0), Color(String(stats.lid)), 3.0)
	eye_pts.assign([Vector2(e.x * face, e.y)])
	eye_size = 16.0
	_draw_overlay()

static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 21:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _draw_fx() -> void:
	var ground := ground()
	var eye := Color(String(stats.rage_eye)) if phase >= 2 else Color(String(stats.eye))
	if st == "gaze_w" or st == "gaze":
		var o := eye_pos()
		var dir := Vector2.from_angle(gaze_ang)
		var len := stat("gaze_len")
		if dir.y > 0.001:
			len = minf(len, (ground - o.y) / dir.y)
		var end := o + dir * len
		if st == "gaze_w":
			var k := 1.0 - clampf(t / maxf(stat("gaze_wind"), 0.01), 0.0, 1.0)
			_fx.draw_dashed_line(o, end, Color(eye, 0.35 + 0.5 * k), 2.0, 14.0)
		else:
			_fx.draw_line(o, end, Color(eye, 0.25), stat("gaze_w") * 1.8)
			_fx.draw_line(o, end, Color(eye, 0.85), stat("gaze_w") * 0.7)
			_fx.draw_line(o, end, Color("#fff0d0"), 4.0)
	for hz: Dictionary in hazards:
		match String(hz.kind):
			"wave":
				var wx := float(hz.x)
				var wh := stat("wave_h")
				var d := int(hz.dir)
				_fx.draw_colored_polygon(PackedVector2Array([Vector2(wx - stat("wave_w") * d, ground), Vector2(wx, ground - wh),
					Vector2(wx + stat("wave_w") * 0.6 * d, ground)]), Color("#5a4a3a"))
				_fx.draw_polyline(PackedVector2Array([Vector2(wx - stat("wave_w") * d, ground), Vector2(wx, ground - wh),
					Vector2(wx + stat("wave_w") * 0.6 * d, ground)]), Color(eye, 0.9), 3.0)
			"woe":
				var px := float(hz.x)
				var hw := float(hz.get("w", stat("woe_w"))) / 2.0
				var warn := float(hz.get("warn", stat("woe_warn")))
				var tt := float(hz.t)
				if tt < 0.0:
					continue
				if tt < warn:
					var k := tt / warn
					_fx.draw_rect(Rect2(px - hw, ground - 8.0, hw * 2.0, 8.0), Color(eye, 0.2 + 0.4 * k))
					_fx.draw_colored_polygon(_ellipse(Vector2(px, ground - 14.0), 22.0 + 10.0 * k, 9.0 + 4.0 * k), Color(eye, 0.35 + 0.5 * k))
					_fx.draw_circle(Vector2(px, ground - 14.0), 5.0 + 3.0 * k, Color(0.05, 0.03, 0.02, 0.9))
					_fx.draw_line(Vector2(px, stat("woe_top")), Vector2(px, ground - 30.0), Color(eye, 0.1 + 0.25 * k), 2.0)
				else:
					var k2 := clampf((tt - warn) / float(hz.get("act", stat("woe_act"))), 0.0, 1.0)
					var by := lerpf(stat("woe_top"), ground - 26.0, minf(k2 * 2.0, 1.0))
					var bark := Color(String(stats.bark))
					_fx.draw_line(Vector2(px - hw, by - 10.0), Vector2(px + hw, by + 6.0), bark, 12.0)
					_fx.draw_line(Vector2(px - hw * 0.3, by - 6.0), Vector2(px - hw * 0.6, by - 30.0), bark, 5.0)
					_fx.draw_line(Vector2(px + hw * 0.4, by + 2.0), Vector2(px + hw * 0.7, by - 22.0), bark, 5.0)
