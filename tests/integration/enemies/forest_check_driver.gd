## Scripted check of the Тёмный бор roster (GDD design/gdd/bestiary.md §3.3).
## Real hero (scripted input), real enemies, one kind at a time in a forest room:
## Аука calls and steps out behind the hero; Лешачонок burrows and bursts up;
## Нетопырь winds and dives (or spits); Упырь-щитник's shield soaks a front hit
## but not a hit in the back; Сучковик winds (rust line), the spear sticks in
## the wall, the hero stands on it as on a one-way step, it breaks after
## plat_time, and a parried spear flies back and stuns it; Лесавка whistles,
## allies in reach get haste (move x1.3) and she runs from the hero.
## Saves <out_dir>/forest-roster.png (all 6 labelled), bestiary-suchkovik.png,
## bestiary-suchkovik-step.png, bestiary-lesavka.png and forest-check-log.txt.
## Started by bestiary_check_driver.gd with `--bestiary-check=<dir> --loc=2`.
extends Node

const HERO_X: float = 700.0
const ROSTER: Array[String] = ["ringer", "rootling", "bat", "sentry", "suchkovik", "lesavka"]
## The parry is pressed when the spear is this close to the hero's centre, px.
const PARRY_AT: float = 70.0

var out_dir: String = "user://forest_check"
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
	print("[forest-check] ", s)
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
	_w.cam.reset_smoothing()

func _spawn(kind: String, at: Vector2, seed_v: int) -> Enemy:
	return _w.spawn_enemy(EnemyRoster.make(kind), at, 0, false, seed_v)

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

func _spears() -> Array[BranchSpear]:
	var out: Array[BranchSpear] = []
	for n in _w.get_children():
		if n is BranchSpear and not n.is_queued_for_deletion():
			out.append(n)
	return out

func _run() -> void:
	if _w.tier != 2:
		_w.tier = 2
		_w.start_room()
	await get_tree().process_frame
	await _tick()
	_note("room: tier %d (%s), width %.0f" % [_w.tier, String(Tune.table("locations")["2"].name), float(_w.room.layout.w)])
	_clear()
	await _ticks(2)
	for c: Callable in [_ringer, _rootling, _bat, _sentry, _suchkovik, _suchkovik_parry, _lesavka]:
		await c.call()
		_clear()
		await _ticks(20)
	await _lineup()
	_finish()

## Аука: the call, then it stands on the other side of the hero.
func _ringer() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("ringer", Vector2(HERO_X + 300.0, _g()), 3)
	e.cd = 0.0
	var called := await _until(func() -> bool: return e.st == "call", 300)
	_ok(called, "Аука calls (state %s)" % e.st)
	var out := await _until(func() -> bool: return e.st == "appear" or e.st == "swipe", 120)
	_ok(out and e.position.x < _w.player.position.x, "Аука stepped out behind the hero (x %.0f, hero %.0f)" % [e.position.x, _w.player.position.x])

## Лешачонок: under the ground, then bursts up under the hero.
func _rootling() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("rootling", Vector2(HERO_X + 320.0, _g()), 4)
	e.cd = 0.0
	_ok(await _until(func() -> bool: return e.st == "under", 300), "Лешачонок went under (state %s)" % e.st)
	var burst := await _until(func() -> bool: return e.st == "burst", 240)
	_ok(burst and absf(e.position.x - _w.player.position.x) < e.stat("burst_r") + 30.0, "Лешачонок burst up by the hero (dx %.0f)" % (e.position.x - _w.player.position.x))

## Нетопырь: winds and dives or spits.
func _bat() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("bat", Vector2(HERO_X + 200.0, _g() - 220.0), 5)
	e.cd = 0.0
	_ok(await _until(func() -> bool: return e.st == "swoop" or e.st == "spitwind", 400), "Нетопырь attacked from above (state %s)" % e.st)

## Упырь-щитник: a front hit is soaked by the shield, one in the back is not.
func _sentry() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var e := _spawn("sentry", Vector2(HERO_X + 160.0, _g()), 6)
	await _ticks(3)
	e.face = -1
	var hp0 := e.hp
	var front := e.hurt(Hit.make(Hit.Kind.STRIKE, 10.0, e.position.x - 60.0, 0.0))
	e.stun = 0.0
	e.face = -1
	var back := e.hurt(Hit.make(Hit.Kind.STRIKE, 10.0, e.position.x + 60.0, 0.0))
	_ok(front < back, "Упырь-щитник shield: front %.1f < back %.1f (hp %.1f -> %.1f)" % [front, back, hp0, e.hp])

## Сучковик: wind-up line, the spear sticks in the wall, the hero stands on it, it breaks.
func _suchkovik() -> void:
	var g := _g()
	_hero_at(Vector2(260.0, g))
	var e := _spawn("suchkovik", Vector2(760.0, g), 7) as Suchkovik
	e.cd = 0.0
	_label("Сучковик: рыжая линия, сук в стену", Vector2(260.0, g - 240.0))
	var wound := await _until(func() -> bool: return e.st == "wind", 120)
	_ok(wound and e.face == -1, "Сучковик winds up facing the hero")
	await _ticks(int(e.stat("wind") * 0.6 * Engine.physics_ticks_per_second))
	await _shot("bestiary-suchkovik.png")
	# Let the spear pass the hero (invulnerable) so it reaches the wall.
	_w.player.inv = 5.0
	var threw := await _until(func() -> bool: return not _spears().is_empty(), 60)
	_ok(threw, "Сучковик threw a spear")
	if not threw:
		return
	var s := _spears()[0]
	_ok(absf(s.vel.y) < 0.001 and s.vel.x < 0.0, "the spear flies horizontally (vel %s)" % s.vel)
	var stuck := await _until(func() -> bool: return s.stuck, 120)
	var r := s.step_rect()
	_ok(stuck and absf(s.position.x - s.stop_x) < 0.5, "the spear stuck in the wall at x %.0f (step %s)" % [s.position.x, r])
	# Stand on the step.
	# Facing the wall: the camera leads left and shows the step.
	_hero_at(Vector2(r.get_center().x, r.position.y - 40.0), -1)
	_w.player.inv = 5.0
	await _ticks(2)
	var stood := await _until(func() -> bool: return _w.player.is_on_floor() and _w.player.velocity.y >= 0.0, 60)
	_ok(stood and absf(_w.player.position.y - r.position.y) < 2.0, "hero stands on the spear (feet %.1f, step top %.1f)" % [_w.player.position.y, r.position.y])
	await _ticks(10)
	await _shot("bestiary-suchkovik-step.png")
	_ok(is_instance_valid(s) and s.stuck, "the step still holds after %.1f s" % (s.plat_time - s.stuck_t))
	var sw: WeakRef = weakref(s)
	var broke := await _until(func() -> bool: return sw.get_ref() == null or (sw.get_ref() as BranchSpear).life <= 0.0, int((s.plat_time + 0.5) * Engine.physics_ticks_per_second))
	_ok(broke, "the spear broke after plat_time")
	var fell := await _until(func() -> bool: return _w.player.is_on_floor() and _w.player.position.y > g - 2.0, 90)
	_ok(fell, "hero dropped to the floor when it broke (y %.0f)" % _w.player.position.y)

## A spear caught in the parry window flies back and stuns the Сучковик.
func _suchkovik_parry() -> void:
	var g := _g()
	_hero_at(Vector2(360.0, g))
	var e := _spawn("suchkovik", Vector2(760.0, g), 8) as Suchkovik
	e.cd = 0.0
	var p := _w.player
	p.parry_cd = 0.0
	p.parry_lock = 0.0
	var res: Array[String] = []
	p.parry_succeeded.connect(func(_e: Enemy, rr: String) -> void: res.append(rr), CONNECT_ONE_SHOT)
	var pressed := false
	var stunned := false
	for i in 300:
		var fake := {}
		var sp := _spears()
		if not sp.is_empty() and not pressed and not sp[0].reflected:
			var pc := p.position - Vector2(0, Player.H / 2.0)
			if sp[0].position.distance_to(pc) < PARRY_AT:
				fake = { &"parry": true }
				pressed = true
		if e.stun > 0.0:
			stunned = true
			break
		await _tick(fake)
	_ok(res == ["reflect"], "the parry reflected the spear (%s)" % [res])
	_ok(stunned and e.stun >= e.stat("deflect_stun") - 0.1, "the reflected spear stunned the Сучковик (stun %.2f)" % e.stun)

## Лесавка: the whistle hastes allies in reach (they move faster), she runs from the hero.
func _lesavka() -> void:
	var g := _g()
	_hero_at(Vector2(HERO_X, g))
	var l := _spawn("lesavka", Vector2(HERO_X + 260.0, g), 9) as Lesavka
	var a := _spawn("sentry", Vector2(HERO_X + 420.0, g), 10)
	var far := _spawn("sentry", Vector2(HERO_X + 260.0 + l.stat("aura_r") + 400.0, g), 11)
	l.cd = 0.0
	_label("Лесавка: свист, стая быстрее", Vector2(HERO_X, g - 230.0))
	var d0 := absf(l.position.x - _w.player.position.x)
	var whistled := await _until(func() -> bool: return l.st == "whistle", 120)
	_ok(whistled, "Лесавка whistles")
	await _ticks(int(l.stat("whistle") * 0.6 * Engine.physics_ticks_per_second))
	await _shot("bestiary-lesavka.png")
	var hasted := await _until(func() -> bool: return a.haste_t > 0.0, 60)
	_ok(hasted and far.haste_t <= 0.0 and absf(a.haste_mult - l.stat("haste_mult")) < 0.001,
		"ally in reach hasted x%.2f for %.1f s; far one not (%.1f)" % [a.haste_mult, a.haste_t, far.haste_t])
	# Hasted ally walks faster than the plain one, both after the hero.
	var ax := a.position.x
	var fx := far.position.x
	await _ticks(30)
	var da := absf(a.position.x - ax)
	var df := absf(far.position.x - fx)
	_ok(da > df * 1.2, "hasted ally covered %.0f px, plain one %.0f px" % [da, df])
	await _ticks(20)
	_ok(absf(l.position.x - _w.player.position.x) >= d0, "Лесавка keeps away from the hero (%.0f -> %.0f px)" % [d0, absf(l.position.x - _w.player.position.x)])

## All six side by side, labelled.
func _lineup() -> void:
	_hero_at(Vector2(HERO_X, _g()))
	var names := { "ringer": "Аука", "rootling": "Лешачонок", "bat": "Нетопырь", "sentry": "Упырь-щитник",
		"suchkovik": "Сучковик", "lesavka": "Лесавка" }
	await _ticks(40)
	var hx := _w.player.position.x
	var offs: Array[float] = [-400.0, -260.0, -130.0, 150.0, 290.0, 430.0]
	for i in ROSTER.size():
		var kind := ROSTER[i]
		var x := hx + offs[i]
		var y := _g() - 170.0 if kind == "bat" else _g()
		var e := _spawn(kind, Vector2(x, y), 20 + i)
		e.set_physics_process(false)
		e.face = -1 if offs[i] > 0.0 else 1
		e.queue_redraw()
		_label(String(names[kind]), Vector2(x - 55.0, _g() + 16.0 + (26.0 if i % 2 == 1 else 0.0)), 20)
	await _ticks(3)
	for n in _w.get_children():
		if n is Enemy:
			n.queue_redraw()
	await _shot("forest-roster.png")

func _finish() -> void:
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("forest-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
