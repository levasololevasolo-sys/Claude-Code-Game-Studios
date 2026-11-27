## Scripted check of the Топь Кикиморы roster (GDD design/gdd/bestiary.md §3.2).
## Real hero (scripted input), real enemies, one kind at a time vs the hero:
## Болванчик winds 0.7 s and its swing hurts; Трясинник charges; Шишига latches,
## slows the hero and a dash throws it off stunned; Упырь-метатель throws;
## Утопленник swells; Болотница dives from under the hero's feet and surfaces;
## Водяница's song shields allies (ward_frac of max HP) and a hit breaks it.
## Saves <out_dir>/swamp-roster.png (all 7 side by side, labelled),
## bestiary-balvan.png, bestiary-shishiga.png, bestiary-bognitsa.png,
## bestiary-vodyanitsa.png and bestiary-check-log.txt.
## Started by world.gd with `-- --bestiary-check=<dir>`.
extends Node

const HERO_X: float = 700.0
const ROSTER: Array[String] = ["balvan", "crawler", "shishiga", "thrower", "bloat", "bognitsa", "vodyanitsa"]

var out_dir: String = "user://bestiary_check"
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
	print("[bestiary-check] ", s)
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

func _ticks(n: int) -> void:
	for i in n:
		await _tick()

func _clear() -> void:
	for n in _w.get_children():
		if n is Enemy or n is EnemyShot or n is LimbPart:
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
	p.cling_n = 0
	_w.cam.reset_smoothing()

func _spawn(kind: String, at: Vector2, seed_v: int, in_bog: bool = false) -> Enemy:
	var e := EnemyRoster.make(kind)
	if in_bog:
		e.set("in_bog", true)
	return _w.spawn_enemy(e, at, 0, false, seed_v)

## Ticks until `cond` holds (at most `limit` ticks); true when it did.
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

func _run() -> void:
	await _tick()
	_clear()
	await _ticks(2)
	for c: Callable in [_balvan, _crawler, _shishiga, _thrower, _bloat, _bognitsa, _vodyanitsa]:
		await c.call()
		_clear()
		await _ticks(20)
	await _lineup()
	_finish()

func _g() -> float:
	return Tune.f("ground_y")

## Болванчик: 0.7 s wind-up, then the club hurts the hero standing in front.
func _balvan() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("balvan", Vector2(HERO_X + 140.0, _g()), 3) as Balvan
	e.cd = 0.0
	_label("Болванчик: замах", Vector2(HERO_X - 40.0, _g() - 190.0))
	var hp0 := _w.player.hp
	var wound := await _until(func() -> bool: return e.st == "wind", 240)
	var n := 0
	var shot := false
	while e.st == "wind" and n < 120:
		n += 1
		if not shot and n == 25:
			shot = true
			await _shot("bestiary-balvan.png")
		await _tick()
	var wind_s := n / float(Engine.physics_ticks_per_second)
	_ok(wound and absf(wind_s - e.stat("wind")) < 0.1, "Болванчик wind-up %.2f s (want %.2f)" % [wind_s, e.stat("wind")])
	await _until(func() -> bool: return e.st == "recover", 60)
	_ok(_w.player.hp < hp0, "Болванчик swing hit the hero: hp %.1f -> %.1f" % [hp0, _w.player.hp])

## Трясинник: winds up and charges.
func _crawler() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("crawler", Vector2(HERO_X + 300.0, _g()), 4)
	e.cd = 0.0
	_ok(await _until(func() -> bool: return e.st == "charge", 300), "Трясинник charged (state %s)" % e.st)

## Шишига: leaps, latches (hero slowed), a dash throws it off stunned.
func _shishiga() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("shishiga", Vector2(HERO_X + 200.0, _g()), 5) as Shishiga
	e.cd = 0.0
	_label("Шишига: висит на герое", Vector2(HERO_X - 80.0, _g() - 190.0))
	var latched := await _until(func() -> bool: return e.st == "cling", 360)
	_ok(latched and _w.player.cling_n == 1, "Шишига latched on the hero (cling_n %d)" % _w.player.cling_n)
	var mult := SwampRules.cling_slow_mult(_w.player.cling_n, Tune.f("cling_slow"), int(Tune.f("cling_max")))
	_ok(absf(mult - (1.0 - Tune.f("cling_slow"))) < 0.001, "hero run speed x%.2f with one clinger" % mult)
	# Run right for a while: the clinger rides along and slows him.
	var x0 := _w.player.position.x
	for i in 30:
		await _tick({ &"move_right": true })
	var ran := _w.player.position.x - x0
	_ok(e.st == "cling" and absf(e.position.x - _w.player.position.x) < 20.0, "Шишига rides on the hero (ran %.0f px)" % ran)
	await _shot("bestiary-shishiga.png")
	_w.player.dash_cd = 0.0
	await _tick({ &"dash": true })
	await _ticks(2)
	_ok(e.st != "cling" and e.stun > 0.0 and _w.player.cling_n == 0, "a dash threw it off: state %s, stun %.2f" % [e.st, e.stun])

## Упырь-метатель: lobs a stone.
func _thrower() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("thrower", Vector2(HERO_X + 420.0, _g()), 6)
	e.cd = 0.0
	var threw := await _until(func() -> bool:
		for n in _w.get_children():
			if n is EnemyShot:
				return true
		return false, 300)
	_ok(threw, "Упырь-метатель threw a stone")

## Утопленник: flies close and swells.
func _bloat() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("bloat", Vector2(HERO_X + 220.0, _g() - 120.0), 7)
	_ok(await _until(func() -> bool: return e.st == "swell" or e.dead, 400), "Утопленник swelled (state %s)" % e.st)

## Болотница: the hero stands on the hummock, it bubbles, dives, he falls, it surfaces.
func _bognitsa() -> void:
	var top := Vector2(_free_x(260.0), _g() - 120.0)
	_hero_at(Vector2(top.x - 200.0, _g()))
	var e := _spawn("bognitsa", top, 8, true) as Bognitsa
	await _ticks(2)
	_ok(e.st == "hide" and e.plat != null, "Болотница lies as a hummock (state %s)" % e.st)
	_hero_at(top - Vector2(0, 2))
	_label("Болотница: кочка дрожит", Vector2(top.x - 100.0, top.y - 150.0))
	var stood := await _until(func() -> bool: return _w.player.is_on_floor(), 30)
	_ok(stood and absf(_w.player.position.y - top.y) < 4.0, "hero stands on the hummock (y %.0f, top %.0f)" % [_w.player.position.y, top.y])
	var bubbled := await _until(func() -> bool: return e.st == "bubble", 60)
	_ok(bubbled, "it bubbles after the hero stood on it")
	await _ticks(12)
	await _shot("bestiary-bognitsa.png")
	var dived := await _until(func() -> bool: return e.st == "dive", 60)
	_ok(dived and e.plat == null, "it dived, the hummock is gone")
	var fell := await _until(func() -> bool: return _w.player.is_on_floor() and _w.player.position.y > _g() - 2.0, 90)
	_ok(fell, "hero fell to the floor (y %.0f)" % _w.player.position.y)
	var rose := await _until(func() -> bool: return e.st == "walk" or e.st == "wind", 120)
	_ok(rose and absf(e.position.x - _w.player.position.x) < e.stat("rise_dx") + 60.0, "it surfaced beside the hero (dx %.0f)" % (e.position.x - _w.player.position.x))
	var hp0 := _w.player.hp
	await _until(func() -> bool: return e.st == "recover", 200)
	_ok(_w.player.hp < hp0, "its tina arm hit the hero: hp %.1f -> %.1f" % [hp0, _w.player.hp])

## Room x with no platform within `half` px on either side (the hero must fall
## to the floor when the hummock goes).
func _free_x(half: float) -> float:
	var w := float(_w.room.layout.w)
	var x := 300.0
	while x < w - 300.0:
		var free := true
		for p: Vector3 in _w.room.layout.plats:
			if p.x < x + half and p.x + p.z > x - half:
				free = false
				break
		if free:
			return x
		x += 20.0
	return HERO_X

## Водяница: the song shields allies; a hit breaks the next song.
func _vodyanitsa() -> void:
	_hero_at(Vector2(HERO_X - 300.0, _g()))
	var v := _spawn("vodyanitsa", Vector2(HERO_X + 100.0, _g()), 9) as Vodyanitsa
	var a := _spawn("balvan", Vector2(HERO_X - 20.0, _g()), 10)
	var b := _spawn("crawler", Vector2(HERO_X + 220.0, _g()), 11)
	for e: Enemy in [a, b]:
		e.cd = 99.0
	v.cd = 0.0
	_label("Водяница: песня, щит из тины", Vector2(HERO_X - 120.0, _g() - 230.0))
	var sang := await _until(func() -> bool: return v.st == "song", 200)
	_ok(sang, "Водяница started the song")
	await _ticks(25)
	await _shot("bestiary-vodyanitsa.png")
	var warded := await _until(func() -> bool: return a.tina > 0.0 and b.tina > 0.0, 60)
	var want_a := SwampRules.tina_amount(a.max_hp, v.stat("ward_frac"))
	_ok(warded and absf(a.tina - want_a) < 0.01 and absf(b.tina - SwampRules.tina_amount(b.max_hp, v.stat("ward_frac"))) < 0.01,
		"allies got tina shields %.1f / %.1f (want %.1f / %.1f)" % [a.tina, b.tina, want_a, b.max_hp * v.stat("ward_frac")])
	await _ticks(10)
	# The shield takes damage first.
	var hp_a := a.hp
	var tina0 := a.tina
	a.hurt(Hit.make(Hit.Kind.STRIKE, 4.0, a.position.x - 50.0, 0.0))
	_ok(a.hp == hp_a and a.tina < tina0, "a hit went into the shield: hp %.1f, tina %.1f -> %.1f" % [a.hp, tina0, a.tina])
	# A hit breaks the song.
	a.tina = 0.0
	v.cd = 0.0
	await _until(func() -> bool: return v.st == "song", 120)
	v.hurt(Hit.make(Hit.Kind.STRIKE, 1.0, v.position.x - 50.0, 0.0))
	await _ticks(60)
	_ok(v.st != "song" and a.tina == 0.0, "a hit broke the song: state %s, ally tina %.1f" % [v.st, a.tina])

## All seven side by side, frozen in a readable pose, labelled.
func _lineup() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var names := { "balvan": "Болванчик", "crawler": "Трясинник", "shishiga": "Шишига", "thrower": "Упырь-метатель",
		"bloat": "Утопленник", "bognitsa": "Болотница", "vodyanitsa": "Водяница" }
	await _ticks(40)
	# Around the hero (his light shows them), the camera leads him to the right.
	var hx := _w.player.position.x
	var offs: Array[float] = [-415.0, -280.0, -145.0, 145.0, 280.0, 415.0, 550.0]
	for i in ROSTER.size():
		var kind := ROSTER[i]
		var x := hx + offs[i]
		var y := _g() - 160.0 if kind == "bloat" else _g()
		var e := _spawn(kind, Vector2(x, y), 20 + i)
		e.set_physics_process(false)
		e.face = -1 if offs[i] > 0.0 else 1
		e.st = "walk"
		e.queue_redraw()
		_label(String(names[kind]), Vector2(x - 60.0, _g() + 16.0 + (26.0 if i % 2 == 1 else 0.0)), 20)
	# Болотница as a hummock too.
	var h := _spawn("bognitsa", Vector2(hx + 680.0, _g() - 150.0), 40, true)
	h.set_physics_process(false)
	_label("Болотница (кочка)", Vector2(hx + 590.0, _g() - 220.0), 20)
	await _ticks(3)
	for n in _w.get_children():
		if n is Enemy:
			n.queue_redraw()
	await _shot("swamp-roster.png")

func _finish() -> void:
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("bestiary-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
