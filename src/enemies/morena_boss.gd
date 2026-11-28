## Морена, boss of Царство Морены (GDD enemies-and-elites §3.8, §3.11;
## story-bible §2.3: she knows Ждан's name; lines living-world §4.3). Same cycle,
## phases, summons and death as LairBoss; she floats hover_h above the floor
## (§3.8 table: «лет.» = да). Her own attacks, each with a wind-up >= min_windup:
## - breath: she inhales (a dashed frost cone shows), then breathes a freezing
##   cone breath_len long for breath_time s (phase 2 longer); an ice pillar
##   between her and the hero blocks it;
## - spears: icicles drop from the ceiling at the hero and ±280 (phase 2 also
##   ±560); a shadow on the floor darkens for spear_warn s first. A spear that
##   lands leaves an ice pillar with pillar_chance (up to pillar_max, they stand
##   until the end of the fight);
## - scythe: she glides in with the sickle raised (the arc shows), then sweeps a
##   half-circle of radius scythe_r in front of her;
## - dive (§3.11): rises to the ceiling, a shadow tracks the hero then locks,
##   she dives and is stuck for dive_stuck s (phase 2 shorter). Diving into a
##   pillar breaks it: stuck dive_stuck_pillar s and she takes ×dive_pillar_mult;
## - mirror (phase 2 only): an ice double forms on the hero's far side and sweeps
##   after mirror_wind s, then she breathes at once (squeezes the hero between).
## Deviation (approved in the task brief): §3.11's bubble fan and floor tentacles
## are replaced by breath and spears; pillars come from spears instead of bubbles.
## All numbers: bosses.json "morena".
class_name MorenaBoss
extends LairBoss

## Standing ice pillars, x in world space.
var pillars: Array[float] = []
## Breath hit cooldown; dive target x; damage taken multiplier while stuck.
var breath_cd: float = 0.0
## Breath cone angle: aimed at the hero during the wind-up, locked in the breath.
var breath_ang: float = 0.0
var dive_x: float = 0.0
var stuck_k: float = 1.0
## Every time a dive broke a pillar (log and the boss check).
var pillar_breaks: int = 0

# ---------------- pure helpers (unit-tested) ----------------

## True when p is inside the cone from o along angle `ang` (rad), `length`
## long, half-angle `half` rad.
static func in_cone(o: Vector2, ang: float, length: float, half: float, p: Vector2) -> bool:
	var d := p - o
	if d.length() > length:
		return false
	return absf(wrapf(d.angle() - ang, -PI, PI)) <= half

## True when a pillar stands strictly between xs a and b (blocks the breath).
static func pillar_between(xs: Array[float], a: float, b: float) -> bool:
	for x in xs:
		if x > minf(a, b) and x < maxf(a, b):
			return true
	return false

## Index of the pillar within r of x, or -1.
static func pillar_near(xs: Array[float], x: float, r: float) -> int:
	for i in xs.size():
		if absf(xs[i] - x) <= r:
			return i
	return -1

## Spear xs: hx + each offset, those outside [edge, room_w − edge] dropped.
static func spear_xs(hx: float, offsets: Array, room_w: float, edge: float) -> Array[float]:
	var out: Array[float] = []
	for o: Variant in offsets:
		var x := hx + float(o)
		if room_w <= 0.0 or (x >= edge and x <= room_w - edge):
			out.append(x)
	return out

# ---------------- Enemy hooks ----------------

func _load_stats() -> void:
	super()
	flies = true

func _behave(dt: float) -> void:
	if not introduced:
		introduced = true
		say(story_line("intro"))
	think(dt, hero_pos())
	_redraw_fx()

func _dead_tick(dt: float) -> void:
	pillars.clear()
	position.y = move_toward(position.y, ground() - Tune.f("flyer_floor"), Tune.f("max_fall") * dt)
	super(dt)

## Stuck after a dive into a pillar: she takes ×dive_pillar_mult.
func hurt(hit: Hit) -> float:
	if st == "stuck" and stuck_k > 1.0:
		hit.dmg *= stuck_k
	return super(hit)

func contact_damage() -> float:
	if st == "stuck":
		return 0.0
	return stat("dmg") * (stat("lunge_contact_mult") if st == "dive" else stat("contact_mult"))

## Per-phase value of a [p1, p2] stat.
func per_phase(key: String) -> float:
	var v: Variant = stats.get(key, 0.0)
	if v is Array:
		var a := v as Array
		return float(a[mini(phase, a.size()) - 1])
	return float(v)

## Mouth (breath origin) in world space.
func mouth() -> Vector2:
	return position + Vector2(face * w * 0.2, -h * stat("breath_mouth_y"))

## Height of the floor she floats over, y.
func hover_y() -> float:
	return ground() - stat("hover_h") + sin(anim * 1.4) * stat("hover_bob")

# ---------------- behaviour ----------------

## One tick of the state machine and the hazards (tests drive it directly).
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	line_t -= dt
	breath_cd -= dt
	var ground := ground()
	var dx := hp_pos.x - position.x
	var hc := hp_pos - Vector2(0, Player.H / 2.0)
	if st == "idle" or st.ends_with("_w") and st != "dive_w":
		face = int(signf(dx)) if dx != 0.0 else face
	var mw := stat("min_windup")
	var rise := stat("rise_speed") * dt
	match st:
		"idle":
			vel.x = face * stat("walk_speed") if absf(dx) > stat("walk_keep") else 0.0
			position.y = move_toward(position.y, hover_y(), rise)
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
					if a == "dive":
						dive_x = hp_pos.x
					elif a == "mirror":
						var side := 1.0 if dx >= 0.0 else -1.0
						var mx := hp_pos.x + side * stat("mirror_dx")
						if room_w > 0.0:
							mx = clampf(mx, stat("spear_edge"), room_w - stat("spear_edge"))
						hazards.append({ "kind": "clone", "x": mx, "y": hover_y(), "t": 0.0, "hit": false, "warn": t })
		"breath_w":
			vel.x = 0.0
			breath_ang = (hc - mouth()).angle()
			if t <= 0.0:
				st = "breath"
				t = per_phase("breath_time")
		"breath":
			vel.x = 0.0
			var blen := stat("breath_len")
			var bhalf := stat("breath_half")
			if ng_bliz:
				var k := 1.0 - clampf(t / maxf(ngv("sweep_t", 1.6), 0.01), 0.0, 1.0)
				breath_ang = lerp_angle(bliz_a0, bliz_a1, k)
				blen = ngv("len", 520.0)
				bhalf = ngv("half", 0.34)
			if breath_cd <= 0.0 and in_cone(mouth(), breath_ang, blen, bhalf, hc) \
					and not pillar_between(pillars, mouth().x, hp_pos.x) and _hero_open():
				breath_cd = ngv("hit_cd", 0.45) if ng_bliz else stat("breath_hit_cd")
				hurt_hero(stat("dmg") * (ngv("dmg_breath", 0.5) if ng_bliz else stat("breath_dmg_mult")), Hit.Kind.PROJECTILE)
			if t <= 0.0:
				if ng_bliz:
					ng_bliz = false
					dive_x = hp_pos.x if room_w <= 0.0 else clampf(hp_pos.x, w, room_w - w)
					st = "dive"
					t = stat("dive_time")
					face = 1 if dive_x >= position.x else -1
				else:
					_rest(stat("breath_rest_add"))
		"spears_w":
			vel.x = 0.0
			if t <= 0.0:
				var rows: Array = stats.get("spear_offsets", [[0]])
				for x in spear_xs(hp_pos.x, rows[mini(phase, rows.size()) - 1], room_w, stat("spear_edge")):
					hazards.append({ "kind": "spear", "x": x, "t": 0.0, "hit": false, "done": false })
				_rest(stat("spears_rest_add"))
		"scythe_w":
			var goal := hp_pos.x - face * stat("scythe_reach")
			var glide := ngv("glide", 520.0) if ng_twin else stat("scythe_glide")
			vel.x = clampf((goal - position.x) / maxf(t, 0.05), -glide, glide)
			position.y = move_toward(position.y, hover_y(), rise)
			if t <= 0.0:
				vel.x = 0.0
				st = "scythe"
				t = stat("scythe_time")
				var sr := ngv("r", 250.0) if ng_twin else stat("scythe_r")
				if _sweep_hits(position + Vector2(0, -h * 0.5), face, sr, hc) and _hero_open():
					hurt_hero(stat("dmg") * (ngv("dmg", 1.1) if ng_twin else stat("scythe_dmg_mult")), Hit.Kind.STRIKE)
				ng_twin = false
		"scythe":
			vel.x = 0.0
			if t <= 0.0:
				_rest(0.0)
		"dive_w":
			vel.x = 0.0
			position.y = move_toward(position.y, stat("dive_top"), rise * 1.5)
			# The shadow tracks the hero, then locks for the last dive_lock of the wind-up.
			if t > windup(stat("dive_wind"), fast(), mw) * (1.0 - stat("dive_lock")):
				dive_x = hp_pos.x if room_w <= 0.0 else clampf(hp_pos.x, w, room_w - w)
			if t <= 0.0:
				st = "dive"
				t = stat("dive_time")
				face = 1 if dive_x >= position.x else -1
		"dive":
			var target := Vector2(dive_x, ground)
			var to := target - position
			var step := stat("dive_speed") * dt
			vel = Vector2.ZERO
			if to.length() <= step or t <= 0.0:
				position = target
				_land()
			else:
				position += to.normalized() * step
		"stuck":
			vel.x = 0.0
			if t <= 0.0:
				stuck_k = 1.0
				_rest(0.0)
		"summon_w":
			vel.x = 0.0
			if t <= 0.0:
				_summon(summon_queue.pop_front())
				_rest(0.0)
		"mirror_w":
			vel.x = 0.0
			if t <= 0.0:
				# Right after the double sweeps she breathes: no rest between.
				st = "breath_w"
				t = windup(stat("breath_wind"), fast(), mw)
		"roar":
			vel.x = 0.0
			if t <= 0.0:
				_rest(0.0)
	if st.begins_with("ng_"):
		_ng_tick(dt, hp_pos)
	_tick_hazards(dt, hp_pos)

# ---------------- NG+ moves (artifacts-and-secrets §3.7) ----------------

var ng_twin: bool = false
var ng_bliz: bool = false
var bliz_a0: float = 0.0
var bliz_a1: float = 0.0

func _ng_begin(id: String, _hp_pos: Vector2) -> void:
	if id == "morena_blizzard":
		position.y = maxf(position.y - ngv("rise", 300.0), stat("dive_top"))

func _ng_fire(id: String, hp_pos: Vector2) -> void:
	match id:
		"morena_ice_path":
			var n := int(ngv("n", 8))
			var dir := 1.0 if hp_pos.x >= position.x else -1.0
			for i in n:
				var x := position.x + dir * ngv("gap", 120.0) * (i + 1)
				if room_w > 0.0 and (x < stat("spear_edge") or x > room_w - stat("spear_edge")):
					continue
				hazards.append({ "kind": "spear", "x": x, "t": -ngv("step_t", 0.12) * i, "hit": false, "done": false,
					"warn": ngv("warn", 0.6), "act": ngv("act", 0.3), "w": ngv("w", 60.0), "dmgk": ngv("dmg", 0.9), "pillar_ok": i == n - 1 })
			_rest(stat("spears_rest_add"))
		"morena_twin_scythe":
			var side := 1.0 if position.x < hp_pos.x else -1.0
			var cx := hp_pos.x + side * ngv("dx", 230.0)
			if room_w > 0.0:
				cx = clampf(cx, stat("spear_edge"), room_w - stat("spear_edge"))
			var glide_t := clampf(absf(hp_pos.x - position.x) / maxf(ngv("glide", 520.0), 1.0), 0.3, 1.0)
			hazards.append({ "kind": "clone", "x": cx, "y": hover_y(), "t": 0.0, "hit": false, "warn": glide_t,
				"r": ngv("clone_r", 200.0), "dmgk": ngv("dmg_clone", 0.9) })
			ng_twin = true
			face = int(signf(hp_pos.x - position.x)) if hp_pos.x != position.x else face
			st = "scythe_w"
			t = glide_t
		"morena_blizzard":
			ng_bliz = true
			var m := mouth()
			var g := ground()
			var lx := 40.0
			var rx := room_w - 40.0 if room_w > 0.0 else m.x + 900.0
			var from_left := hp_pos.x > m.x
			bliz_a0 = (Vector2(lx if from_left else rx, g) - m).angle()
			bliz_a1 = (Vector2(rx if from_left else lx, g) - m).angle()
			breath_ang = bliz_a0
			st = "breath"
			t = ngv("sweep_t", 1.6)
		_:
			_rest(0.0)

func _land() -> void:
	var i := pillar_near(pillars, position.x, stat("pillar_hit_r"))
	st = "stuck"
	if i >= 0:
		pillars.remove_at(i)
		pillar_breaks += 1
		t = stat("dive_stuck_pillar")
		stuck_k = stat("dive_pillar_mult")
		if world:
			world.add_shake(stat("dive_pillar_shake"))
	else:
		t = per_phase("dive_stuck")
		stuck_k = 1.0
		if world:
			world.add_shake(stat("dive_shake"))

## Half-circle sweep in front: within r of c and not more than scythe_back behind.
func _sweep_hits(c: Vector2, dir: int, r: float, p: Vector2) -> bool:
	return c.distance_to(p) <= r and (p.x - c.x) * dir >= -stat("scythe_back")

func _tick_hazards(dt: float, hp_pos: Vector2) -> void:
	var hc := hp_pos - Vector2(0, Player.H / 2.0)
	var dmg := stat("dmg")
	var warn := stat("spear_warn")
	for hz: Dictionary in hazards:
		hz.t = float(hz.t) + dt
		match String(hz.kind):
			"spear":
				var sw := float(hz.get("warn", warn))
				if not hz.hit and hz.t > sw and hz.t < sw + float(hz.get("act", stat("spear_act"))) \
						and absf(hp_pos.x - float(hz.x)) < float(hz.get("w", stat("spear_w"))) / 2.0 + Player.W / 2.0 and _hero_open():
					hz.hit = true
					hurt_hero(dmg * float(hz.get("dmgk", stat("spear_dmg_mult"))), Hit.Kind.PROJECTILE)
				if not hz.done and hz.t >= sw:
					hz.done = true
					if world:
						world.add_shake(4.0)
					if bool(hz.get("pillar_ok", true)) and pillars.size() < int(stat("pillar_max")) and pillar_near(pillars, float(hz.x), stat("pillar_w")) < 0 \
							and rng.randf() < stat("pillar_chance"):
						pillars.append(float(hz.x))
			"clone":
				if not hz.hit and hz.t >= float(hz.warn):
					hz.hit = true
					var c := Vector2(float(hz.x), float(hz.y) - h * 0.5)
					var dir := 1 if hp_pos.x >= float(hz.x) else -1
					if _sweep_hits(c, dir, float(hz.get("r", stat("scythe_r") * stat("mirror_r_k"))), hc) and _hero_open():
						hurt_hero(dmg * float(hz.get("dmgk", stat("mirror_dmg_mult"))), Hit.Kind.STRIKE)
	var spear_end := warn + stat("spear_act") + 0.25
	hazards.assign(hazards.filter(func(hz: Dictionary) -> bool:
		if hz.kind == "spear":
			return float(hz.t) < float(hz.get("warn", warn)) + float(hz.get("act", stat("spear_act"))) + 0.25
		return float(hz.t) < float(hz.get("warn", 0.0)) + stat("mirror_act")))

# ---------------- light and drawing ----------------

func light_spots() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var c := center()
	out.append(Vector4(c.x, position.y - h * 0.85, 80.0, 1.0))
	if is_winding():
		out.append(Vector4(c.x, c.y, Tune.f("windup_glow_r"), Tune.f("windup_glow_a")))
	var r := stat("hazard_glow_r")
	var a := stat("hazard_glow_a")
	var ground := ground()
	for hz: Dictionary in hazards:
		out.append(Vector4(float(hz.x), ground - 30.0, r, a))
	for x in pillars:
		out.append(Vector4(x, ground - stat("pillar_h") * 0.5, r, a * 0.6))
	return out

func _draw() -> void:
	if _skin_draw():
		return
	if dead:
		var k := clampf(_linger / maxf(stat("death_linger"), 0.01), 0.0, 1.0)
		draw_set_transform(Vector2(0, h * 0.6 * k), 0.0, Vector2(face, 1.0 - 0.6 * k))
	else:
		_draw_windup_glow()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var a := 1.0 - (clampf(_linger / maxf(stat("death_linger"), 0.01), 0.0, 1.0) if dead else 0.0)
	_draw_figure(self, c, a, st, anim, phase)
	_draw_windup_outline(_robe())
	eye_pts.assign([Vector2(-6.0 * face, -h * 0.86), Vector2(6.0 * face, -h * 0.86)])
	eye_size = 3.5
	_draw_overlay()

func _robe() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w * 0.55, 0), Vector2(-w * 0.28, -h * 0.7), Vector2(-w * 0.18, -h * 0.8),
		Vector2(w * 0.18, -h * 0.8), Vector2(w * 0.28, -h * 0.7), Vector2(w * 0.55, 0), Vector2(w * 0.2, -h * 0.06), Vector2(0, 0), Vector2(-w * 0.2, -h * 0.06)])

## Her figure on canvas `cv` (herself, or the fx layer for the ice double):
## symmetric robe, pale face, icicle crown, the sickle.
func _draw_figure(cv: CanvasItem, c: Color, alpha: float, state: String, tm: float, ph: int, at: Vector2 = Vector2.ZERO) -> void:
	var robe := _robe()
	for i in robe.size():
		robe[i] += at
	cv.draw_colored_polygon(robe, Color(c, alpha))
	cv.draw_polyline(robe + PackedVector2Array([robe[0]]), Color(Color(String(stats.robe_edge)), 0.9 * alpha), 2.0)
	# frost hem trailing under her: she floats
	for i in 5:
		var hx := -w * 0.4 + i * w * 0.2
		cv.draw_line(at + Vector2(hx, 0), at + Vector2(hx + sin(tm * 2.0 + i) * 6.0, 18.0 + (i % 2) * 10.0), Color(Color(String(stats.crown)), 0.4 * alpha), 3.0)
	var head := at + Vector2(0, -h * 0.86)
	cv.draw_circle(head, 15.0, Color(Color(String(stats.face)), alpha))
	# icicle crown, symmetric
	var crown := Color(String(stats.crown))
	for i in 7:
		var cx := -18.0 + i * 6.0
		var tall := 14.0 + (12.0 if i == 3 else (6.0 if i == 2 or i == 4 else 0.0))
		cv.draw_colored_polygon(PackedVector2Array([head + Vector2(cx - 3.0, -10.0), head + Vector2(cx, -10.0 - tall), head + Vector2(cx + 3.0, -10.0)]), Color(crown, alpha))
	var eye := Color(String(stats.rage_eye)) if ph >= 2 else Color(String(stats.eye))
	if not dead:
		cv.draw_circle(head + Vector2(-6, 0), 3.5, Color(eye, alpha))
		cv.draw_circle(head + Vector2(6, 0), 3.5, Color(eye, alpha))
	if state == "breath_w" or state == "breath":
		cv.draw_circle(head + Vector2(w * 0.2, 8.0), 5.0, Color(crown, 0.8 * alpha))
	# the sickle: raised in the wind-ups, swung low in the sweep
	var sh := at + Vector2(w * 0.22, -h * 0.62)
	var hand: Vector2
	if state == "scythe_w" or state == "spears_w" or state == "dive_w" or state == "mirror_w":
		hand = sh + Vector2(24.0, -90.0)
	elif state == "scythe":
		hand = sh + Vector2(110.0, 50.0)
	else:
		hand = sh + Vector2(30.0, 60.0 + sin(tm * 1.4) * 6.0)
	cv.draw_line(sh, hand, Color(c.lightened(0.25), alpha), 6.0)
	var blade := Color(String(stats.sickle))
	cv.draw_arc(hand + Vector2(18.0, 0), 22.0, PI * 0.9, PI * 2.1, 14, Color(blade, alpha), 5.0)

## Hazards, pillars, cones and shadows, world space, above the room.
func _draw_fx() -> void:
	var ground := ground()
	var ice := Color(String(stats.crown))
	var threat := Color(String(stats.rage_eye)) if phase >= 2 else Color(String(stats.eye))
	for x in pillars:
		var pw := stat("pillar_w") / 2.0
		var ph := stat("pillar_h")
		var poly := PackedVector2Array([Vector2(x - pw, ground), Vector2(x - pw * 0.8, ground - ph * 0.8), Vector2(x - pw * 0.2, ground - ph),
			Vector2(x + pw * 0.5, ground - ph * 0.85), Vector2(x + pw, ground)])
		_fx.draw_colored_polygon(poly, Color(Color("#5f86b0"), 0.92))
		_fx.draw_polyline(poly + PackedVector2Array([poly[0]]), Color("#e8f6ff"), 2.0)
		_fx.draw_line(Vector2(x - pw * 0.3, ground - 10.0), Vector2(x - pw * 0.1, ground - ph * 0.9), Color(1, 1, 1, 0.6), 3.0)
	if not dead and (st == "breath_w" or st == "breath"):
		var o := mouth()
		var len := stat("breath_len")
		var half := stat("breath_half")
		var pts := PackedVector2Array([o])
		for i in 9:
			var ang := breath_ang - half + 2.0 * half * i / 8.0
			pts.append(o + Vector2.from_angle(ang) * len)
		if st == "breath_w":
			var k := 1.0 - clampf(t / maxf(stat("breath_wind"), 0.01), 0.0, 1.0)
			_fx.draw_colored_polygon(pts, Color(threat, 0.06 + 0.12 * k))
			_fx.draw_polyline(pts + PackedVector2Array([o]), Color(threat, 0.4 + 0.5 * k), 2.0)
		else:
			_fx.draw_colored_polygon(pts, Color(Color("#e8f6ff"), 0.55))
			for i in 7:
				var dir2 := Vector2.from_angle(breath_ang - half + 2.0 * half * fmod(anim * 3.0 + i * 0.37, 1.0))
				var r0 := fmod(anim * 900.0 + i * 140.0, len)
				_fx.draw_line(o + dir2 * r0, o + dir2 * minf(r0 + 60.0, len), ice, 3.0)
			_fx.draw_polyline(pts + PackedVector2Array([o]), Color(ice, 0.9), 2.0)
	if not dead and (st == "dive_w" or st == "dive"):
		var k2 := 1.0 if st == "dive" else 1.0 - clampf(t / maxf(stat("dive_wind"), 0.01), 0.0, 1.0)
		_fx.draw_colored_polygon(Room._oval(Vector2(dive_x, ground - 2.0), 40.0 + 30.0 * k2, 9.0), Color(threat, 0.25 + 0.45 * k2))
		_fx.draw_arc(Vector2(dive_x, ground - 2.0), 46.0 + 30.0 * k2, PI, TAU, 16, Color(threat, 0.8), 3.0)
	if not dead and (st == "scythe_w" or st == "scythe"):
		var cc := position + Vector2(0, -h * 0.5)
		var r := stat("scythe_r")
		var a0 := -PI / 2.0 if face > 0 else PI / 2.0
		if st == "scythe_w":
			_fx.draw_arc(cc, r, a0, a0 + PI * face, 24, Color(threat, 0.65), 3.0)
		else:
			_fx.draw_arc(cc, r, a0, a0 + PI * face, 24, Color("#f3f8ff"), 14.0)
			_fx.draw_arc(cc, r - 10.0, a0, a0 + PI * face, 24, Color(ice, 0.8), 6.0)
	var warn := stat("spear_warn")
	for hz: Dictionary in hazards:
		var hx := float(hz.x)
		match String(hz.kind):
			"spear":
				var tt := float(hz.t)
				var top := stat("spear_top")
				var sw := float(hz.get("w", stat("spear_w"))) / 2.0
				warn = float(hz.get("warn", stat("spear_warn")))
				if tt < 0.0:
					continue
				if tt < warn:
					var k3 := tt / warn
					_fx.draw_colored_polygon(Room._oval(Vector2(hx, ground - 2.0), sw * (0.5 + 0.6 * k3), 7.0), Color(threat, 0.25 + 0.55 * k3))
					_fx.draw_colored_polygon(PackedVector2Array([Vector2(hx - 10.0, top), Vector2(hx, top + 46.0), Vector2(hx + 10.0, top)]), Color(ice, 0.5 + 0.5 * k3))
					_fx.draw_line(Vector2(hx, top + 50.0), Vector2(hx, ground), Color(threat, 0.12 + 0.2 * k3), 2.0)
				else:
					var k4 := clampf((tt - warn) / float(hz.get("act", stat("spear_act"))), 0.0, 1.0)
					var tip := lerpf(top + 46.0, ground, minf(k4 * 2.5, 1.0))
					_fx.draw_colored_polygon(PackedVector2Array([Vector2(hx - sw * 0.4, tip - 90.0), Vector2(hx, tip), Vector2(hx + sw * 0.4, tip - 90.0)]), Color("#e8f6ff"))
					_fx.draw_polyline(PackedVector2Array([Vector2(hx - sw * 0.4, tip - 90.0), Vector2(hx, tip), Vector2(hx + sw * 0.4, tip - 90.0)]), ice, 2.0)
			"clone":
				var k5 := clampf(float(hz.t) / maxf(float(hz.warn), 0.01), 0.0, 1.0)
				var skin := get_node_or_null("ArtSkin") as DrawnEnemyVisual
				if skin == null or not skin.draw_frame(_fx, "scythe" if hz.hit else "scythe_w", 1.0 if hz.hit else k5,
						Vector2(hx, float(hz.y)), -face, Color(0.62, 0.77, 0.91, 0.25 + 0.45 * k5)):
					_fx.draw_set_transform(Vector2(hx, float(hz.y)), 0.0, Vector2(-face, 1))
					_draw_figure(_fx, Color("#9fc4e8"), 0.25 + 0.45 * k5, "scythe" if hz.hit else "scythe_w", anim, phase)
					_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var cc2 := Vector2(hx, float(hz.y) - h * 0.5)
				var r2 := stat("scythe_r") * stat("mirror_r_k")
				_fx.draw_arc(cc2, r2, 0.0, TAU, 32, Color(threat, 0.3 + 0.5 * k5) if not hz.hit else Color("#f3f8ff"), 3.0 if not hz.hit else 12.0)
