## Scripted check of the Царство Морены roster (GDD design/gdd/bestiary.md §3.4).
## A real frost room (location 3, room 3, chunk library "frost"), real hero
## (scripted input), one kind at a time: wolves come in pairs and bite;
## Студёный дух freezes the floor; Карачун's floor wave hurts a standing hero
## and a jump clears it; Снежница's needles stack 3 marks and freeze the hero;
## Сосульник hangs on a ceiling marker, shakes, drops on the hero; Мара raises
## a killed ally as an ice copy (40% HP) which cracks when Мара dies.
## Saves <out_dir>/frost-roster.png (all 6 labelled), frost-karachun.png,
## frost-snezhnitsa.png, frost-snezhnitsa-frozen.png, frost-sosulnik.png,
## frost-mara.png, frost-mara-copy.png and frost-check-log.txt.
## Started by world.gd with `-- --frost-check=<dir>`.
extends Node

var out_dir: String = "user://frost_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []
var _labels: Array[Node] = []
var HERO_X: float = 700.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[frost-check] ", s)
	_lines.append(s)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	_note(("OK   " if cond else "FAIL ") + what)

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _tick(fake: Dictionary = {}) -> void:
	var p := _w.player
	p.scripted = true
	p.fake = fake
	await p.stepped

func _ticks(n: int, fake: Dictionary = {}) -> void:
	for i in n:
		await _tick(fake)

func _clear() -> void:
	for n in _w.get_children():
		if n is Enemy or n is EnemyShot or n is LimbPart or n is IceWave or n is FrostPips:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()
	for l in _labels:
		l.queue_free()
	_labels.clear()

func _hero_at(at: Vector2, face: int = 1) -> void:
	var p := _w.player
	p.position = at
	p.velocity = Vector2.ZERO
	p.hp = 1000.0
	p.inv = 0.0
	p.face = face
	p.frost = 0
	p.frozen_t = 0.0
	p.freeze_guard_t = 0.0
	_w.cam.reset_smoothing()

func _spawn(kind: String, at: Vector2, seed_v: int, pack_id: int = 0) -> Enemy:
	return _w.spawn_enemy(EnemyRoster.make(kind), at, pack_id, false, seed_v)

func _until(cond: Callable, limit: int, fake: Dictionary = {}) -> bool:
	for i in limit:
		if cond.call():
			return true
		await _tick(fake)
	return bool(cond.call())

func _label(text: String, at: Vector2, size: int = 22) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#ede6f2"))
	l.add_theme_color_override("font_outline_color", Color("#120d12"))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 50
	_w.add_child(l)
	_labels.append(l)

func _g() -> float:
	return Tune.f("ground_y")

## Room x with no platform and no solid within `half` px.
func _free_x(half: float, from: float = 300.0) -> float:
	var wd := float(_w.room.layout.w)
	var x := from
	while x < wd - 300.0:
		var free := true
		for r: Rect2 in _w.room.layout.get("solids", []):
			if r.position.x < x + half and r.end.x > x - half and r.end.y > _g() - 300.0:
				free = false
		if free:
			return x
		x += 20.0
	return HERO_X

func _run() -> void:
	await _tick()
	# A real frost room with ceiling markers (location 3, room 3).
	_w.tier = 3
	_w.room_k = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 3303
	var layout := RoomGen.generate(rng, 3, 3, Tune.data, true, { "loc": "frost", "knight": false, "elites_ok": false, "secret_ok": false })
	_w.start_room(layout, rng)
	await _ticks(3)
	_ok((layout.get("ceilings", []) as Array).size() > 0, "frost room has ceiling markers: %d" % (layout.get("ceilings", []) as Array).size())
	var n_sos := 0
	for n in _w.get_children():
		if n is Sosulnik:
			n_sos += 1
	_ok(n_sos > 0 and n_sos <= int(Tune.f("ceiling_max")), "room spawned %d Сосульник on ceiling markers" % n_sos)
	_pack_rules()
	_clear()
	await _ticks(2)
	HERO_X = _free_x(520.0, 600.0)
	_note("hero x %.0f in a room %.0f px long" % [HERO_X, float(_w.room.layout.w)])
	for c: Callable in [_wolves, _jelly, _karachun, _snezhnitsa, _sosulnik, _mara]:
		await c.call()
		_clear()
		await _ticks(20)
	await _lineup()
	_finish()

## Packs of the real location 3 table: wolves even, no Сосульник, ≤1 Мара.
func _pack_rules() -> void:
	var ros := EnemyRoster.for_tier(3, Tune.table("locations"), Tune.data)
	var bad := 0
	var r := RandomNumberGenerator.new()
	for s in 60:
		r.seed = 500 + s
		var out := EnemyRoster.pack_kinds_intro(r, 2 + s % 6, s, 3, 3, ros.intro, Tune.table("enemies"), Tune.data, false)
		if out.count("wolf") % 2 != 0 or out.count("sosulnik") > 0 or out.count("mara") > 1:
			bad += 1
	_ok(bad == 0, "60 frost packs: wolves in pairs, no Сосульник, at most 1 Мара (bad %d)" % bad)

## Снежные волки: a pair, one bites.
func _wolves() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var a := _spawn("wolf", Vector2(HERO_X + 260.0, _g()), 3)
	var b := _spawn("wolf", Vector2(HERO_X + 330.0, _g()), 4)
	a.cd = 0.0
	b.cd = 0.0
	_ok(await _until(func() -> bool: return a.st == "bite" or b.st == "bite", 360), "a wolf of the pair bit (%s / %s)" % [a.st, b.st])

## Студёный дух: winds up and leaves a floor zone.
func _jelly() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("jelly", Vector2(HERO_X + 120.0, _g() - 230.0), 5) as ColdSpirit
	e.cd = 0.0
	_ok(await _until(func() -> bool: return e.zones.size() > 0, 400), "Студёный дух froze the floor (zones %d)" % e.zones.size())

## Карачун: wind-up 0.9 s with the lane glow; the wave hurts the standing hero;
## the next wave is jumped over.
func _karachun() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("karachun", Vector2(HERO_X + 340.0, _g()), 6) as Karachun
	e.cd = 0.0
	e.slam_cd = 0.0
	_label("Карачун: посох вверх, лёд по полу", Vector2(HERO_X - 60.0, _g() - 260.0))
	var wound := await _until(func() -> bool: return e.st == "slam_wind", 200)
	var n := 0
	while e.st == "slam_wind" and n < 200:
		n += 1
		if n == 40:
			await _shot("frost-karachun.png")
		await _tick()
	var wind_s := n / float(Engine.physics_ticks_per_second)
	_ok(wound and absf(wind_s - e.stat("slam_wind")) < 0.1, "Карачун slam wind-up %.2f s (want %.2f)" % [wind_s, e.stat("slam_wind")])
	_ok(e.last_waves.size() == 2, "the slam sent %d waves (both ways)" % e.last_waves.size())
	var hp0 := _w.player.hp
	await _ticks(70)
	_ok(_w.player.hp < hp0, "the wave hit the standing hero: hp %.1f -> %.1f" % [hp0, _w.player.hp])
	# Second slam: jump when the front is close.
	_hero_at(Vector2(HERO_X, _g()))
	await _ticks(60)
	_w.player.inv = 0.0
	e.cd = 0.0
	e.slam_cd = 0.0
	e.position.x = HERO_X + 340.0
	await _until(func() -> bool: return e.st == "slam", 300)
	var wv: IceWave = null
	for x in e.last_waves:
		if is_instance_valid(x) and x.dir < 0:
			wv = x
	var hp1 := _w.player.hp
	var jumped := false
	for i in 120:
		if wv == null or not is_instance_valid(wv):
			break
		var close := absf(wv.front() - _w.player.position.x) < 70.0
		if close and not jumped:
			jumped = true
		await _tick({ &"jump": jumped and i % 1 == 0 })
	_ok(jumped and _w.player.hp == hp1, "a jump cleared the spikes: hp %.1f -> %.1f" % [hp1, _w.player.hp])

## Снежница: needles stack 3 marks and freeze the hero 0.7 s.
func _snezhnitsa() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("snezhnitsa", Vector2(HERO_X + 430.0, _g()), 7) as Snezhnitsa
	e.cd = 0.0
	_label("Снежница: иней копится", Vector2(HERO_X - 40.0, _g() - 240.0))
	var p := _w.player
	var two := await _until(func() -> bool: return p.frost >= 2 or p.frozen_t > 0.0, 400)
	if p.frozen_t <= 0.0:
		await _shot("frost-snezhnitsa.png")
	_ok(two, "needles left marks on the hero (%d)" % p.frost)
	var froze := await _until(func() -> bool: return p.frozen_t > 0.0, 500)
	var t_det := p.frozen_t
	_ok(froze and absf(t_det - Tune.f("freeze_time")) < 0.05, "3 marks froze the hero for %.2f s (want %.2f)" % [t_det, Tune.f("freeze_time")])
	await _ticks(4)
	await _shot("frost-snezhnitsa-frozen.png")
	var x0 := p.position.x
	var n := 0
	while p.frozen_t > 0.0 and n < 120:
		n += 1
		await _tick({ &"move_left": true, &"dash": n == 3 })
	_ok(p.frozen_t <= 0.0 and n > 3 and absf(p.position.x - x0) < 2.0 and p.dash_t <= 0.0,
		"while frozen: no walking or dashing (moved %.1f px), thawed after %d more ticks" % [p.position.x - x0, n])
	_ok(p.freeze_guard_t > 0.0 and p.add_frost() == false and p.frost == 0, "freeze guard: no new marks for %.1f s" % p.freeze_guard_t)

## Сосульник: hangs under a platform, shakes, drops on the hero below.
func _sosulnik() -> void:
	var ceils: Array = _w.room.layout.get("ceilings", [])
	var at: Vector2 = ceils[0] if not ceils.is_empty() else Vector2(HERO_X, _g() - 280.0)
	_hero_at(Vector2(at.x - 260.0, _g()))
	var e := _spawn("sosulnik", at, 8) as Sosulnik
	await _ticks(10)
	_ok(e.st == "hang" and e.hanging and absf(e.position.y - (at.y + e.h)) < 1.0, "Сосульник hangs at the marker (state %s, y %.0f)" % [e.st, e.position.y])
	_label("Сосульник: тень сверху", Vector2(at.x - 100.0, at.y - 120.0))
	_hero_at(Vector2(at.x + 10.0, _g()))
	var shook := await _until(func() -> bool: return e.st == "shake", 30)
	_ok(shook, "the hero below: it shakes")
	await _ticks(20)
	await _shot("frost-sosulnik.png")
	var hp0 := _w.player.hp
	var landed := await _until(func() -> bool: return e.st == "land" or e.st == "walk", 120)
	_ok(landed and e.on_ground() and _w.player.hp < hp0, "it fell on the hero: hp %.1f -> %.1f" % [hp0, _w.player.hp])

## Мара: a killed ally rises as an ice copy (40% HP); Мара dies, the copy cracks.
func _mara() -> void:
	_hero_at(Vector2(HERO_X - 260.0, _g()))
	var m := _spawn("mara", Vector2(HERO_X + 260.0, _g()), 9) as Mara
	var a := _spawn("wolf", Vector2(HERO_X + 60.0, _g()), 10)
	a.cd = 99.0
	m.cd = 0.0
	await _ticks(5)
	_label("Мара: поднимает павших", Vector2(HERO_X - 40.0, _g() - 250.0))
	var max0 := a.max_hp
	a.hurt(Hit.make(Hit.Kind.STRIKE, 9999.0, a.position.x - 50.0, 0.0))
	var w0 := await _until(func() -> bool: return m.st == "raise_w", 120)
	_ok(w0, "Мара winds up the raise")
	await _ticks(25)
	await _shot("frost-mara.png")
	var rose := await _until(func() -> bool: return m.copies.size() > 0, 120)
	var cp: Enemy = m.copies[0] if rose else null
	_ok(rose and cp.ice_copy and absf(cp.max_hp - max0 * m.stat("raise_frac")) < 0.01,
		"the wolf rose as an ice copy: hp %.1f (want %.1f)" % [cp.max_hp if cp else 0.0, max0 * m.stat("raise_frac")])
	if cp:
		cp.cd = 99.0
	await _ticks(20)
	await _shot("frost-mara-copy.png")
	m.hurt(Hit.make(Hit.Kind.STRIKE, 9999.0, m.position.x - 50.0, 0.0))
	var mdead := m.dead
	var cracked := await _until(func() -> bool: return not is_instance_valid(cp) or cp.dead, 90)
	_ok(mdead and cracked, "Мара died: the copy cracked")

## All six side by side, labelled; Сосульник hangs, Мара stands by an ice copy.
func _lineup() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	await _ticks(30)
	var hx := _w.player.position.x
	var kinds: Array[String] = ["wolf", "karachun", "jelly", "snezhnitsa", "sosulnik", "mara"]
	var names := { "wolf": "Снежный волк", "karachun": "Карачун", "jelly": "Студёный дух", "snezhnitsa": "Снежница",
		"sosulnik": "Сосульник", "mara": "Мара" }
	var offs: Array[float] = [-460.0, -280.0, 140.0, 270.0, 400.0, 520.0]
	for i in kinds.size():
		var kind := kinds[i]
		var x := hx + offs[i]
		var y := _g()
		if kind == "jelly":
			y = _g() - 200.0
		elif kind == "sosulnik":
			y = _g() - 300.0
		var e := _spawn(kind, Vector2(x, y), 20 + i)
		e.face = -1 if offs[i] > 0.0 else 1
		e.st = "hang" if kind == "sosulnik" else "walk"
		if kind == "sosulnik":
			(e as Sosulnik)._anchor()
		e.set_physics_process(false)
		e.queue_redraw()
		_label(String(names[kind]), Vector2(x - 60.0, _g() + 16.0 + (26.0 if i % 2 == 1 else 0.0)), 20)
	var c := EnemyRoster.make("wolf")
	c.ice_copy = true
	var cp := _w.spawn_enemy(c, Vector2(hx + 610.0, _g()), 0, false, 40)
	cp.face = -1
	cp.set_physics_process(false)
	_label("ледяная копия", Vector2(hx + 560.0, _g() + 42.0), 20)
	await _ticks(3)
	for n in _w.get_children():
		if n is Enemy:
			n.queue_redraw()
	await _shot("frost-roster.png")

func _finish() -> void:
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("frost-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
