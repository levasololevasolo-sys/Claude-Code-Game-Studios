## Scripted game-feel VFX check (design/art/vfx-spec.md §7). Real room, real
## hero, real enemies and hits:
## 1. a grid of every hit material + parry + hero hurt -> vfx-hits.png;
## 2. six consecutive frames of a blood hit and a metal spark hit -> vfx-strip.png;
## 3. emerge, wake and death -> vfx-spawn.png;
## 4. the hero walking through grass by a lamp in each location -> vfx-world-swamp/forest/frost.png;
## 5. frame time with 20 enemies under constant hits, particles много vs выкл.
## Saves vfx-check-log.txt. Started by world.gd with `-- --vfx-check=<dir>`.
extends Node

const HERO_X: float = 700.0
const STRIP_W: int = 300
const STRIP_H: int = 220
const PERF_FRAMES: int = 240
## Russian captions of the materials in vfx-hits.png.
const RU: Dictionary = { "flesh": "плоть", "undead": "нечисть", "bone": "кость", "wood": "дерево", "ice": "лёд", "metal": "металл (щит)" }

var out_dir: String = "user://vfx_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []
var _labels: Array[Node] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[vfx-check] ", s)
	_lines.append(s)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	_note(("OK   " if cond else "FAIL ") + what)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _vfx() -> Vfx:
	return _w.atmosphere.vfx

func _clear() -> void:
	for n in _w.get_children():
		if n is Enemy or n is EnemyShot or n is LimbPart:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()
	for l in _labels:
		l.queue_free()
	_labels.clear()
	_vfx().norm.clear()
	_vfx().addp.clear()

func _hero_at(x: float, face: int = 1) -> void:
	var p := _w.player
	p.scripted = true
	p.fake = {}
	p.position = Vector2(x, Tune.f("ground_y"))
	p.velocity = Vector2.ZERO
	p.hp = 100000.0
	p.inv = 0.0
	p.face = face
	_w.cam.reset_smoothing()

func _room(tier: int) -> void:
	_w.tier = tier
	_w.room_k = 1
	_w.start_room()
	await _frames(3)
	_hero_at(HERO_X)
	_vfx().fixed_dt = 1.0 / 60.0
	await _frames(2)

func _label(text: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.z_index = 60
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	_w.add_child(l)
	_labels.append(l)

func _run() -> void:
	await _frames(2)
	await _room(1)
	await _hits_grid()
	await _strip()
	await _spawn_case()
	await _perf()
	for t: Array in [[1, "swamp"], [2, "forest"], [3, "frost"]]:
		await _world_case(int(t[0]), String(t[1]))
	_finish()

## 1. Every material, the parry and the hero hurt, side by side.
func _hits_grid() -> void:
	_clear()
	_hero_at(HERO_X)
	await _frames(2)
	var v := _vfx()
	var g := Tune.f("ground_y")
	# Grid centre = camera centre (look-ahead); 4 columns × 2 rows.
	var c := get_viewport().get_camera_2d().get_screen_center_position()
	var mats: Array = (v.data.materials as Dictionary).keys()
	var made := {}
	var cells: Array = mats.duplicate()
	cells.append("heavy")
	cells.append("parry")
	var parry_n := 0
	for k in cells.size():
		var at := Vector2(c.x - 450.0 + (k % 4) * 300.0, c.y - 200.0 + float(k / 4) * 190.0)
		var cell := String(cells[k])
		if cell == "parry":
			parry_n = v.parry_fx(at, Vector2.RIGHT)
			_label("парирование", at + Vector2(-60, -90))
		elif cell == "heavy":
			made[cell] = v.hit_fx("flesh", at, Vector2.RIGHT, true, g)
			_label("плоть, тяжёлый", at + Vector2(-70, -90))
		else:
			made[cell] = v.hit_fx(cell, at, Vector2.RIGHT, false, g)
			_label(String(RU.get(cell, cell)), at + Vector2(-30, -90))
	# Real hero hurt: blood and the red edge flash through Player.hurt.
	var before := v.norm.alive()
	_w.player.hurt(Hit.make(Hit.Kind.CONTACT, 1.0, HERO_X + 60.0, 0.0))
	_label("герой ранен", _w.player.position + Vector2(-50, -110))
	_ok(v.norm.alive() > before, "hero hurt bled (%d -> %d particles)" % [before, v.norm.alive()])
	for m: String in made:
		_ok(int(made[m]) > 0, "material %s made %d particles" % [m, int(made[m])])
	_ok(parry_n > 20, "parry burst made %d particles" % parry_n)
	await _frames(4)
	await _shot("vfx-hits.png")
	await _frames(40)
	_ok(v.norm.splats() > 0, "blood left floor splats: %d" % v.norm.splats())
	_w.request_hitstop(0.0)

## Image rect (in a screenshot of `size`) around a world point.
func _screen_rect(world_at: Vector2, size: Vector2i) -> Rect2i:
	var vp := get_viewport().get_visible_rect().size
	var sp := get_viewport().get_canvas_transform() * world_at
	var k := Vector2(size) / vp
	return Rect2i(int(sp.x * k.x) - STRIP_W / 2, int(sp.y * k.y) - STRIP_H / 2, STRIP_W, STRIP_H)

## 2. Six consecutive frames of a blood hit (Трясинник) and a spark hit (Навий витязь).
func _strip() -> void:
	var img := Image.create(STRIP_W * 6, STRIP_H * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var g := Tune.f("ground_y")
	var row := 0
	for kind: String in ["crawler", "knight"]:
		_clear()
		_hero_at(HERO_X)
		var e := _w.spawn_enemy(Knight.new() if kind == "knight" else EnemyRoster.make(kind), Vector2(HERO_X + 70.0, g), 0, false, 3)
		e.face = -1
		await _frames(2)
		e.stun = 5.0
		var got: Array[String] = []
		var mat_seen := _vfx().material_of(e)
		var dmg := e.hurt(Hit.make(Hit.Kind.STRIKE, 6.0, HERO_X, 0.0))
		got.append("%s dmg %.1f material %s" % [kind, dmg, mat_seen])
		_note(got[0])
		_ok(_vfx().norm.alive() + _vfx().addp.alive() > 0, "%s hit made particles" % kind)
		if kind == "knight":
			_ok(mat_seen == "metal", "knight rings as metal (%s)" % mat_seen)
		var at := VfxRules.hit_point(e.position, e.w, e.h, HERO_X) + Vector2(60, 0)
		for f in 6:
			await RenderingServer.frame_post_draw
			var shot := get_viewport().get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			img.blit_rect(shot, _screen_rect(at, shot.get_size()), Vector2i(f * STRIP_W, row * STRIP_H))
		row += 1
	img.save_png(out_dir.path_join("vfx-strip.png"))
	_note("screenshot vfx-strip.png")

## 3. An enemy rising from the ground, one waking, one dying.
func _spawn_case() -> void:
	_clear()
	_hero_at(HERO_X - 300.0)
	var g := Tune.f("ground_y")
	var sleeper := _w.spawn_enemy(EnemyRoster.make("balvan"), Vector2(HERO_X + 380.0, g), 7, true, 11)
	var dying := _w.spawn_enemy(EnemyRoster.make("crawler"), Vector2(HERO_X + 120.0, g), 8, false, 12)
	await _frames(3)
	var riser := _w.spawn_enemy(EnemyRoster.make("rootling"), Vector2(HERO_X - 120.0, g), 9, false, 13)
	await _frames(2)
	_ok(riser.scale.y < 0.95, "emerge: the riser is still coming out of the ground (scale.y %.2f)" % riser.scale.y)
	sleeper.wake()
	dying.hurt(Hit.make(Hit.Kind.STRIKE, 999.0, HERO_X - 200.0, 0.0))
	_label("из-под земли", riser.position + Vector2(-70, -150))
	_label("проснулся", sleeper.position + Vector2(-50, -150))
	_label("смерть", dying.position + Vector2(-30, -150))
	await _frames(2)
	await _shot("vfx-spawn.png")
	await _frames(40)
	_ok(is_equal_approx(riser.scale.y, 1.0), "emerge finished at full size")

## 5. Average frame time with 20 enemies and a hit every 3 frames.
func _perf() -> void:
	var res := {}
	for lv: int in [VfxRules.LEVEL_HIGH, VfxRules.LEVEL_OFF, -1]:
		_clear()
		GameSettings.particles_level = maxi(lv, 0)
		var on := lv >= 0
		_vfx().process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		_vfx().visible = on
		_vfx().fixed_dt = 0.0
		_hero_at(HERO_X)
		var g := Tune.f("ground_y")
		var kinds := ["crawler", "sentry", "balvan", "shishiga", "rootling"]
		var list: Array[Enemy] = []
		for i in 20:
			var e := _w.spawn_enemy(EnemyRoster.make(kinds[i % kinds.size()]), Vector2(HERO_X - 500.0 + i * 55.0, g), 20 + i, false, 40 + i)
			list.append(e)
		await _frames(10)
		var t0 := Time.get_ticks_usec()
		Vfx.cost_us = 0
		var proc := 0.0
		var peak := 0
		for f in PERF_FRAMES:
			if f % 3 == 0:
				var e := list[f % list.size()]
				if is_instance_valid(e) and not e.dead:
					e.hp = e.max_hp
					e.hurt(Hit.make(Hit.Kind.STRIKE, 1.0, e.position.x - 30.0 * (1 if f % 2 == 0 else -1), 0.0))
			_w.player.hp = 100000.0
			await get_tree().process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			peak = maxi(peak, _vfx().norm.alive() + _vfx().addp.alive())
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / PERF_FRAMES
		res[lv] = ms
		var own := float(Vfx.cost_us) / 1000.0 / PERF_FRAMES
		if lv == VfxRules.LEVEL_HIGH:
			res["own"] = own
		_note("perf level %s: VFX own CPU %.3f ms/frame (tick + draw calls)" % [VfxRules.LEVEL_NAMES[lv] if lv >= 0 else "узел выключен", own])
		_note("perf level %s: frame %.2f ms avg, process %.2f ms avg, peak particles %d, fps monitor %.0f" %
			[VfxRules.LEVEL_NAMES[lv] if lv >= 0 else "VFX узел выключен", ms, proc / PERF_FRAMES * 1000.0, peak, Performance.get_monitor(Performance.TIME_FPS)])
	GameSettings.particles_level = VfxRules.LEVEL_HIGH
	_vfx().process_mode = Node.PROCESS_MODE_INHERIT
	_vfx().visible = true
	_vfx().fixed_dt = 1.0 / 60.0
	_note("perf: VFX cost ≈ %.2f ms/frame (много − узел выключен, software GL under xvfb)" % (float(res[VfxRules.LEVEL_HIGH]) - float(res[-1])))
	# Budget (vfx-spec §2): the VFX's own CPU (tick + draw submission) ≤ 2 ms/frame
	# with 20 enemies under hits. Whole-frame times above are noisy on the shared
	# software-GL box and are reported only.
	_ok(float(res["own"]) <= 2.0, "VFX own CPU %.3f ms/frame ≤ 2 ms budget" % float(res["own"]))

## 4. The hero walks through grass next to a lamp; swamp bog ripples, frost gust.
func _world_case(tier: int, name: String) -> void:
	await _room(tier)
	_clear()
	var v := _vfx()
	_ok(v.grass != null and v.grass.x.size() > 10, "%s: grass tufts %d" % [name, v.grass.x.size() if v.grass else 0])
	_ok(v.lamps != null and not v.lamps.at.is_empty(), "%s: lamps %d" % [name, v.lamps.at.size() if v.lamps else 0])
	var x := HERO_X
	if v.lamps and not v.lamps.at.is_empty():
		x = v.lamps.at[0].x - 260.0
	_hero_at(x)
	if name == "swamp":
		v.extra_bogs = [Vector2(x, Tune.f("ground_y")), Vector2(x + 200.0, Tune.f("ground_y")), Vector2(x + 400.0, Tune.f("ground_y"))]
	if name == "frost":
		v._gust_wait = 0.0
		v._gust_t = -1.0
	_w.player.fake = { &"move_right": true }
	await _frames(30 if name == "frost" else 14)
	if name == "swamp":
		_ok(v.addp.alive() > 0, "swamp: ripples / glow particles live in the bog")
	if name == "frost":
		_ok(v.grass.gust > 0.05, "frost: a wind gust is blowing (%.2f)" % v.grass.gust)
	var bent := 0
	for i in v.grass.x.size():
		if absf(v.grass.a[i]) > 0.25:
			bent += 1
	_ok(bent > 0, "%s: %d tufts bent by the hero / wind" % [name, bent])
	await _shot("vfx-world-%s.png" % name)
	_w.player.fake = {}

func _finish() -> void:
	_note("done, %d failures" % _fails)
	var f := FileAccess.open(out_dir.path_join("vfx-check-log.txt"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	get_tree().quit(1 if _fails > 0 else 0)
