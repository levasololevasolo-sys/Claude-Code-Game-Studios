## Boss of the lair (GDD enemies-and-elites §3.8-3.9): Кикимора Болотная.
## Cycle: rest (walks to keep distance) -> one of the attacks by weight -> rest.
## Attacks, every one with a glowing wind-up of at least min_windup s
## (references-and-feel §3 rule 5): throw of bouncing bog clods (3, phase 2: 5),
## pendulums dropping over the hero (±260, phase 2 also ±520, warn 0.95 s),
## lunge at 720 px/s, and in phase 2 a bog wave along the floor (deviation: not
## in §3.9, weight 0 in phase 1). Phase 2 below 50% hp: «в ярости», timers ×1.3,
## hitstop + shake + flash, the bog water rises to 80 px (hero ×0.6 speed, 4 dps;
## the arena platforms save him). Minions are summoned at 65% and 30%; the water
## drains for 3 s after each summon. Intro and death lines float over her
## (living-world §4.1). On death her minions, clods and hazards vanish.
## All numbers: assets/data/bosses.json row `boss_id`. RunDirector API: `title`.
class_name LairBoss
extends Enemy

## Attack ids, in the order of the bosses.json "weights" rows.
const ATTACKS: Array[String] = ["throw", "pend", "lunge", "wave"]
## Row used when the location's boss has no row of its own.
const FALLBACK_ID: String = "kikimora"

## Name shown on the summary «кто убил» and the lair door.
var title: String = "Хозяин"
## Row id in bosses.json (locations.json "boss" of the tier).
var boss_id: String = ""
## 1, or 2 after phase_marks (enemy hp fraction thresholds).
var phase: int = 1
## Summon marks already used (index into summon_marks).
var summons_done: int = 0
## Summons waiting for the boss to be free (a big hit can cross two marks).
var summon_queue: Array[int] = []
## Water level above the floor, px, and seconds the water stays drained.
var water: float = 0.0
var drain_t: float = 0.0
## Live hazards: {kind: "clod"|"pend"|"wave", ...} in world space.
var hazards: Array[Dictionary] = []
## Minions she summoned (they vanish with her).
var minions: Array[Enemy] = []
## Floating line over her and its seconds left.
var line: String = ""
var line_t: float = 0.0
## True once the intro line was said.
var introduced: bool = false
## Lunge direction (-1/1).
var ldir: int = 1
## Every attack started, in order (debug log and the boss check).
var attack_log: Array[String] = []
## How many times this boss was beaten before this fight (picks the lines).
var beaten_before: int = -1
var _water_tick: float = 0.0
var _death_done: bool = false
var _linger: float = 0.0
var _fx: Node2D
var _ui: Node2D

# ---------------- pure helpers (unit-tested) ----------------

## Phase for an hp fraction: 1 + the number of marks it is below.
static func phase_for(frac: float, marks: Array) -> int:
	var p := 1
	for m: Variant in marks:
		if frac < float(m):
			p += 1
	return p

## Index of the attack a roll in [0, 1) picks from `weights` (non-negative).
## A zero total falls back to 0.
static func pick_attack(roll: float, weights: Array) -> int:
	var total := 0.0
	for x: Variant in weights:
		total += maxf(float(x), 0.0)
	if total <= 0.0:
		return 0
	var acc := 0.0
	for i in weights.size():
		acc += maxf(float(weights[i]), 0.0)
		if roll * total < acc:
			return i
	return weights.size() - 1

## Summon marks newly crossed when hp falls to `frac`, given `done` used ones.
## Marks are in falling order (0.65, 0.3).
static func summons_crossed(frac: float, marks: Array, done: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(done, marks.size()):
		if frac < float(marks[i]):
			out.append(i)
	return out

## Wind-up time: the base time sped up by `fast`, never shorter than `min_t`.
static func windup(base: float, fast: float, min_t: float) -> float:
	return maxf(base / maxf(fast, 0.001), min_t)

## The line for `moment` ("intro"/"death") by how often the boss was beaten.
static func pick_line(lines: Dictionary, moment: String, beaten: int) -> String:
	var key := moment + ("_first" if beaten <= 0 else "_repeat")
	return String(lines.get(key, ""))

## New boss node of location boss `id`: the row's "script" class (likho:
## LikhoBoss), else LairBoss with that row (Кикимора and the stand-ins).
static func make(id: String) -> LairBoss:
	var row: Dictionary = Tune.table("bosses").get(id, {})
	var path := String(row.get("script", ""))
	var b: LairBoss = (load(path) as GDScript).new() if path != "" else LairBoss.new()
	b.boss_id = id
	return b

## The arena platforms of the lair (Vector3 x, y, width) from bosses.json.
static func arena_plats(id: String = FALLBACK_ID) -> Array:
	var t := Tune.table("bosses")
	var r: Dictionary = t.get(id, t.get(FALLBACK_ID, {}))
	var out: Array = []
	for p: Variant in r.get("arena_plats", []):
		out.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	return out

# ---------------- Enemy hooks ----------------

func _load_stats() -> void:
	if boss_id == "":
		boss_id = _location_boss()
	if stats.is_empty():
		var t := Tune.table("bosses")
		stats = (t.get(boss_id, t.get(FALLBACK_ID, {})) as Dictionary).duplicate(true)
		if not t.has(boss_id):
			stats["lines"] = {}
	kind_id = boss_id
	w = stat("w")
	h = stat("h")
	max_hp = stat("hp")
	weight = stat("weight")
	drag = Tune.f("enemy_drag")
	boss = true
	stats["name"] = title
	if beaten_before < 0:
		beaten_before = _beaten()
	st = "idle"

func _ready() -> void:
	super()
	_fx = Node2D.new()
	_fx.top_level = true
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_ui = Node2D.new()
	_ui.top_level = true
	_ui.z_index = Darkness.Z + 2
	_ui.draw.connect(_draw_ui)
	add_child(_ui)

func is_winding() -> bool:
	return not dead and (st.ends_with("_w") or st == "roar")

## dmg ×contact_mult, in the lunge ×lunge_contact_mult (§3.8).
func contact_damage() -> float:
	return stat("dmg") * (stat("lunge_contact_mult") if st == "lunge" else stat("contact_mult"))

func _behave(dt: float) -> void:
	if not introduced:
		introduced = true
		say(pick_line(stats.get("lines", {}), "intro", beaten_before))
	think(dt, hero_pos())
	_water_on_hero(dt)
	_redraw_fx()

func _after_hurt(_hit: Hit) -> void:
	if hp <= 0.0:
		return
	var frac := hp / maxf(max_hp, 1.0)
	for i in summons_crossed(frac, stats.get("summon_marks", []), summons_done):
		summon_queue.append(i)
		summons_done = i + 1
	var p := phase_for(frac, stats.get("phase_marks", []))
	if p > phase:
		phase = p
		_enter_rage()

func _dead_tick(dt: float) -> void:
	if not _death_done:
		_death_done = true
		remove_from_group("enemies")
		hazards.clear()
		water = 0.0
		for m in minions:
			if is_instance_valid(m):
				m.remove_from_group("enemies")
				m.queue_free()
		minions.clear()
		if world:
			for c in world.get_children():
				if c is EnemyShot and (c as EnemyShot).source == self:
					c.queue_free()
			world.request_hitstop(stat("death_hitstop"))
			world.add_shake(stat("death_shake"))
		say(pick_line(stats.get("lines", {}), "death", beaten_before), stat("death_linger"))
	_linger += dt
	line_t -= dt
	_redraw_fx()
	if _linger >= stat("death_linger"):
		queue_free()

# ---------------- behaviour ----------------

## Shows `text` over her for `time` s (line_time by default). Empty text = none.
func say(text: String, time: float = -1.0) -> void:
	if text == "":
		return
	line = text
	line_t = stat("line_time") if time < 0.0 else time

## Timer speed-up of the current phase (§3.8: ×1.3 in phase 2).
func fast() -> float:
	return stat("phase_fast") if phase >= 2 else 1.0

## One tick of the state machine and the hazards; reads no nodes except through
## hurt_hero() (a no-op without a hero), so tests drive it directly.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	line_t -= dt
	drain_t -= dt
	var dx := hp_pos.x - position.x
	if st != "lunge":
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
				else:
					var rows: Array = stats.get("weights", [])
					var a := ATTACKS[pick_attack(rng.randf(), rows[mini(phase, rows.size()) - 1])]
					attack_log.append(a)
					st = a + "_w"
					t = windup(stat(a + "_wind"), fast(), mw)
		"throw_w":
			vel.x = 0.0
			if t <= 0.0:
				_throw(hp_pos)
				_rest(0.0)
		"pend_w":
			vel.x = 0.0
			if t <= 0.0:
				_pendulums(hp_pos)
				_rest(stat("pend_rest_add"))
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
		"wave_w":
			vel.x = 0.0
			if t <= 0.0:
				for d: int in [-1, 1]:
					hazards.append({ "kind": "wave", "x": position.x + d * w * 0.5, "dir": d, "t": stat("wave_life"), "hit": false })
				_rest(0.0)
		"summon_w":
			vel.x = 0.0
			if t <= 0.0:
				_summon(summon_queue.pop_front())
				_rest(0.0)
		"roar":
			vel.x = 0.0
			if t <= 0.0:
				_rest(0.0)
	_tick_water(dt)
	_tick_hazards(dt, hp_pos)

func _rest(extra: float) -> void:
	st = "idle"
	t = (stat("rest") + extra) / fast()

func _enter_rage() -> void:
	st = "roar"
	t = stat("roar_time")
	vel.x = 0.0
	say(String((stats.get("lines", {}) as Dictionary).get("rage", "%s в ярости" % title)))
	if world:
		world.request_hitstop(stat("phase_hitstop"))
		world.add_shake(stat("phase_shake"))
		world.add_flash(stat("phase_flash"))

func _throw(hp_pos: Vector2) -> void:
	var ns: Array = stats.get("throw_n", [3])
	var n := int(ns[mini(phase, ns.size()) - 1])
	var from := Vector2(position.x + face * w * 0.35, position.y - stat("throw_hand_y"))
	for i in n:
		var tx := hp_pos.x + (float(i) - float(n - 1) / 2.0) * stat("throw_gap")
		var ft := stat("throw_flight") + i * stat("throw_flight_step")
		hazards.append({ "kind": "clod", "p": from, "v": Vector2((tx - from.x) / ft, -stat("throw_up")),
			"t": stat("throw_life"), "b": int(stat("throw_bounces")), "spin": 0.0 })

func _pendulums(hp_pos: Vector2) -> void:
	var rows: Array = stats.get("pend_offsets", [[0]])
	var edge := stat("pend_edge")
	for o: Variant in rows[mini(phase, rows.size()) - 1]:
		var x := hp_pos.x + float(o)
		if room_w <= 0.0 or (x > edge and x < room_w - edge):
			hazards.append({ "kind": "pend", "x": x, "t": 0.0, "hit": false })

func _summon(i: int) -> void:
	drain_t = stat("water_drain")
	var rows: Array = stats.get("summons", [])
	if i < 0 or i >= rows.size():
		return
	var kinds: Array = rows[i]
	for j in kinds.size():
		var e := EnemyRoster.make(String(kinds[j]))
		if e == null:
			continue
		var side := -1.0 if j % 2 == 0 else 1.0
		var x := clampf(position.x + side * stat("summon_dx") * float(1 + (j >> 1)), 80.0, room_w - 80.0 if room_w > 0.0 else INF)
		var y := Tune.f("ground_y")
		if bool(Tune.row("enemies", String(kinds[j])).get("flies", false)):
			y = stat("summon_fly_y")
		minions.append(e)
		if world:
			world.spawn_enemy(e, Vector2(x, y), -1, false, rng.randi())
		else:
			e.position = Vector2(x, y)

## Target water level: water_h in phase 2 unless drained after a summon.
func water_target() -> float:
	return stat("water_h") if phase >= 2 and drain_t <= 0.0 else 0.0

func _tick_water(dt: float) -> void:
	var rate := stat("water_h") / maxf(stat("water_rise"), 0.01)
	water = move_toward(water, water_target(), rate * dt)

## Bog water on the hero: ×water_slow of his own move (undone after his tick,
## Player runs first, priority -1) and water_dps as one hit per water_tick s.
func _water_on_hero(dt: float) -> void:
	var p := hero()
	if p == null or p.dead or water <= 1.0:
		_water_tick = 0.0
		return
	if p.position.y < Tune.f("ground_y") - water:
		_water_tick = 0.0
		return
	var nx := p.position.x - p.velocity.x * dt * (1.0 - stat("water_slow"))
	if room_w > 0.0:
		nx = clampf(nx, Player.W, room_w - Player.W)
	p.position.x = nx
	_water_tick += dt
	if _water_tick >= stat("water_tick"):
		_water_tick -= stat("water_tick")
		var keep := p.velocity
		# A tick of the water, not a blow: the hero keeps his motion.
		hurt_hero(stat("water_dps") * stat("water_tick"), Hit.Kind.TICK)
		p.velocity = keep

func _tick_hazards(dt: float, hp_pos: Vector2) -> void:
	var ground := Tune.f("ground_y")
	var hc := hp_pos - Vector2(0, Player.H / 2.0)
	var dmg := stat("dmg")
	for hz: Dictionary in hazards:
		match String(hz.kind):
			"clod":
				hz.t -= dt
				var v: Vector2 = hz.v
				v.y += stat("throw_g") * dt
				var p: Vector2 = hz.p + v * dt
				var r := stat("throw_r")
				if p.y > ground - r:
					p.y = ground - r
					if int(hz.b) > 0:
						v.y = -absf(v.y) * stat("throw_bounce_k")
						hz.b = int(hz.b) - 1
					else:
						hz.t = 0.0
				hz.v = v
				hz.p = p
				hz.spin = float(hz.spin) + dt * 10.0
				if room_w > 0.0 and (p.x < 0.0 or p.x > room_w):
					hz.t = 0.0
				if hz.t > 0.0 and p.distance_to(hc) < r + Tune.f("shot_hit_r") and _hero_open():
					hurt_hero(dmg * stat("throw_dmg_mult"), Hit.Kind.PROJECTILE)
					hz.t = 0.0
			"pend":
				hz.t += dt
				var warn := stat("pend_warn")
				if not hz.hit and hz.t > warn and hz.t < warn + stat("pend_act") \
						and absf(hp_pos.x - float(hz.x)) < stat("pend_w") / 2.0 + Player.W / 2.0 and _hero_open():
					hz.hit = true
					hurt_hero(dmg * stat("pend_dmg_mult"), Hit.Kind.PROJECTILE)
				if absf(hz.t - warn) < dt and world:
					world.add_shake(6.0)
			"wave":
				hz.t -= dt
				hz.x = float(hz.x) + int(hz.dir) * stat("wave_speed") * dt
				if room_w > 0.0 and (hz.x < 0.0 or hz.x > room_w):
					hz.t = 0.0
				if not hz.hit and absf(hp_pos.x - float(hz.x)) < stat("wave_w") \
						and hp_pos.y > ground - stat("wave_h") and _hero_open():
					hz.hit = true
					hurt_hero(dmg * stat("wave_dmg_mult"), Hit.Kind.PROJECTILE)
	var pend_end := stat("pend_warn") + stat("pend_act") + 0.2
	hazards.assign(hazards.filter(func(hz: Dictionary) -> bool:
		return float(hz.t) < pend_end if hz.kind == "pend" else float(hz.t) > 0.0))

## True when the hero can be hit right now (no hero in tests counts as open).
func _hero_open() -> bool:
	var p := hero()
	return p == null or (not p.dead and p.inv <= 0.0 and p.dash_t <= 0.0)

# ---------------- light and drawing ----------------

## Eyes, wind-up, and every hazard glow through the darkness (amulet-and-flare §3.9).
func light_spots() -> Array[Vector4]:
	var out := super()
	var r := stat("hazard_glow_r")
	var a := stat("hazard_glow_a")
	var ground := Tune.f("ground_y")
	for hz: Dictionary in hazards:
		match String(hz.kind):
			"clod":
				out.append(Vector4(hz.p.x, hz.p.y, r, a))
			"pend":
				out.append(Vector4(float(hz.x), ground - 40.0, r, a))
				out.append(Vector4(float(hz.x), stat("pend_top") + 80.0, r, a))
			"wave":
				out.append(Vector4(float(hz.x), ground - 20.0, r, a))
	return out

func _redraw_fx() -> void:
	if _fx:
		_fx.queue_redraw()
	if _ui:
		_ui.queue_redraw()

func _draw() -> void:
	if dead:
		var k := clampf(_linger / maxf(stat("death_linger"), 0.01), 0.0, 1.0)
		draw_set_transform(Vector2(0, h * 0.6 * k), 0.0, Vector2(face, 1.0 - 0.6 * k))
	else:
		_draw_windup_glow()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var wind := is_winding()
	var hunch := -10.0 if wind else (16.0 if st == "lunge" else 6.0 + sin(anim * 1.5) * 3.0)
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var body := PackedVector2Array([Vector2(-w * 0.45, 0), Vector2(-w * 0.5, -h * 0.45), Vector2(-w * 0.3 + hunch, -h * 0.85),
		Vector2(hunch, -h), Vector2(w * 0.3 + hunch, -h * 0.88), Vector2(w * 0.42, -h * 0.4), Vector2(w * 0.38, 0)])
	draw_colored_polygon(body, c)
	var hair := Color(String(stats.hair))
	for i in 7:
		var hx := -w * 0.3 + hunch + i * w * 0.1
		var sway := sin(anim * 2.0 + i) * 6.0
		draw_line(Vector2(hx, -h * 0.95), Vector2(hx - 10 + sway, -h * 0.35 + i * 6.0), hair, 5.0)
	# spindle staff: raised high in wind-ups, forward in the lunge
	var arm := Vector2(w * 0.3 + hunch, -h * 0.7)
	var tip := arm + (Vector2(10, -h * 0.6) if wind else (Vector2(w * 0.9, -10) if st == "lunge" else Vector2(20, h * 0.65)))
	draw_line(arm, tip, Color(String(stats.staff)), 6.0)
	draw_circle(tip, 9.0, Color(String(stats.eye), 0.9 if wind else 0.4))
	_draw_windup_outline(body)
	var eye := Color(String(stats.rage_eye)) if phase >= 2 else Color(String(stats.eye))
	stats["eye"] = eye.to_html(false)
	if not dead:
		_draw_eyes(Vector2(hunch + 8, -h * 0.86), Vector2(hunch + 26, -h * 0.84), 4.5, face)
	_draw_overlay()

## Hazards and water, world space, above the room and the hero.
func _draw_fx() -> void:
	var ground := Tune.f("ground_y")
	var room_x := room_w if room_w > 0.0 else 4000.0
	if water > 0.5:
		var top := ground - water
		_fx.draw_rect(Rect2(0, top, room_x, water), Color(0.16, 0.3, 0.22, 0.55))
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= room_x:
			pts.append(Vector2(x, top + sin(x * 0.03 + anim * 3.0) * 3.0))
			x += 24.0
		_fx.draw_polyline(pts, Color(0.55, 0.8, 0.5, 0.8), 3.0)
	var eye := Color(String(stats.get("eye", "#c8f07a")))
	var warn := stat("pend_warn")
	for hz: Dictionary in hazards:
		match String(hz.kind):
			"clod":
				var p: Vector2 = hz.p
				var r := stat("throw_r")
				_fx.draw_circle(p, r * 2.2, Color(eye, 0.25))
				_fx.draw_circle(p, r, Color("#4a3b26"))
				var s := float(hz.spin)
				_fx.draw_line(p + Vector2(cos(s), sin(s)) * r, p - Vector2(cos(s), sin(s)) * r, Color("#7d9a5f"), 3.0)
			"pend":
				var px := float(hz.x)
				var top := stat("pend_top")
				var hw := stat("pend_w") / 2.0
				if float(hz.t) < warn:
					var k := float(hz.t) / warn
					_fx.draw_rect(Rect2(px - hw, top, hw * 2.0, ground - top), Color(eye, 0.08 + 0.17 * k))
					_fx.draw_line(Vector2(px, top), Vector2(px, ground), Color(eye, 0.4 + 0.5 * k), 2.0)
					_fx.draw_circle(Vector2(px, ground - 6.0), 10.0 + 8.0 * k, Color(eye, 0.5))
				else:
					var k2 := clampf((float(hz.t) - warn) / stat("pend_act"), 0.0, 1.0)
					var by := lerpf(top, ground - 30.0, minf(k2 * 2.0, 1.0))
					_fx.draw_line(Vector2(px, top), Vector2(px, by), Color("#5a4a35"), 4.0)
					_fx.draw_colored_polygon(PackedVector2Array([Vector2(px - hw, by), Vector2(px + hw, by), Vector2(px, by + 34.0)]), Color("#b9c7a8"))
			"wave":
				var wx := float(hz.x)
				var wh := stat("wave_h")
				_fx.draw_colored_polygon(PackedVector2Array([Vector2(wx - stat("wave_w") * int(hz.dir), ground), Vector2(wx, ground - wh),
					Vector2(wx + stat("wave_w") * 0.6 * int(hz.dir), ground)]), Color(0.3, 0.5, 0.3, 0.9))
				_fx.draw_circle(Vector2(wx, ground - wh), 6.0, Color(eye, 0.8))

## Floating line and the wide boss bar, above the darkness.
func _draw_ui() -> void:
	var font: Font = ThemeDB.fallback_font
	var at := position + Vector2(0, -h - 40)
	if not dead:
		var bw := 220.0
		_ui.draw_rect(Rect2(at.x - bw / 2.0, at.y, bw, 8), Color(0, 0, 0, 0.7))
		_ui.draw_rect(Rect2(at.x - bw / 2.0, at.y, bw * maxf(hp, 0.0) / maxf(max_hp, 1.0), 8), Color("#c8503e") if phase >= 2 else Color("#7fae5a"))
		for m: Variant in stats.get("phase_marks", []):
			var mx := at.x - bw / 2.0 + bw * float(m)
			_ui.draw_line(Vector2(mx, at.y - 2), Vector2(mx, at.y + 10), Color.WHITE, 2.0)
		_ui.draw_string_outline(font, at + Vector2(-bw / 2.0, -6), title, HORIZONTAL_ALIGNMENT_CENTER, bw, 18, 4, Color.BLACK)
		_ui.draw_string(font, at + Vector2(-bw / 2.0, -6), title, HORIZONTAL_ALIGNMENT_CENTER, bw, 18, Color("#e8dcb8"))
	if line_t > 0.0 and line != "":
		var a := clampf(line_t * 2.0, 0.0, 1.0)
		var lp := at + Vector2(-360, -34)
		_ui.draw_string_outline(font, lp, "«%s»" % line, HORIZONTAL_ALIGNMENT_CENTER, 720, 26, 6, Color(0, 0, 0, a))
		_ui.draw_string(font, lp, "«%s»" % line, HORIZONTAL_ALIGNMENT_CENTER, 720, 26, Color(0.85, 1.0, 0.75, a))

# ---------------- context ----------------

func _location_boss() -> String:
	var row: Dictionary = Tune.table("locations").get(str(tier), {})
	return String(row.get("boss", FALLBACK_ID))

func _beaten() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = tree.root.get_node_or_null("Game") if tree else null
	if g == null or g.get("meta") == null:
		return 0
	return int((g.meta.bosses as Dictionary).get(boss_id, 0))
