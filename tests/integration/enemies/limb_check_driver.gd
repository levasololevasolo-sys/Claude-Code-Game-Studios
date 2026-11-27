## Scripted limb zones check (GDD design/gdd/limb-zones.md, AC 1-7). A Аука
## (ringer) is put into its wind-up in front of the hero, and the hero's real
## side swing (scripted input) cuts its arm: the attack is cancelled, the
## one-armed stats apply, the part flies, a second arm cut is impossible. Then a
## fresh Аука under the hero takes a real down-air strike on the head: bonus
## damage, the head flies and hurts a straw idol behind it, the Аука lives on
## headless. Saves <out_dir>/limb-arm.png, limb-head.png and limb-check-log.txt.
## Started by world.gd with `-- --limb-check=<dir>`.
extends Node

const HERO_X: float = 600.0
## Ringer distance in front of the hero for the arm cut, px.
const ARM_DX: float = 70.0
## Hero height above the floor for the down strike, px.
const HEAD_UP: float = 130.0
## Idol distance behind the ringer, on the head's flight line, px.
const IDOL_DX: float = 215.0

var out_dir: String = "user://limb_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[limb-check] ", s)
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

func _clear() -> void:
	for n in _w.get_children():
		if n is Enemy or n is EnemyShot or n is LimbPart:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()

func _hero_at(at: Vector2) -> void:
	var p := _w.player
	p.position = at
	p.velocity = Vector2.ZERO
	p.hp = 1000.0
	p.inv = 5.0
	p.face = 1
	_w.cam.reset_smoothing()

func _run() -> void:
	await _tick()
	_clear()
	await _tick()
	await _arm_case()
	_clear()
	for i in 30:
		await _tick()
	await _head_case()
	_finish()

func _arm_case() -> void:
	var g := Tune.f("ground_y")
	_hero_at(Vector2(HERO_X, g))
	var e := _w.spawn_enemy(EnemyRoster.make("ringer"), Vector2(HERO_X + ARM_DX, g), 0, false, 7) as Ringer
	await _tick()
	var cuts: Array[String] = []
	e.limb_severed.connect(func(_e: Enemy, limb: String) -> void: cuts.append(limb))
	var took: Array[float] = []
	e.damaged.connect(func(_e: Enemy, amount: float, _h: Hit) -> void: took.append(amount))
	var swipe_x := e.stat("swipe_x")
	e.face = -1
	e.st = "appear"
	e.t = 2.0
	await _tick({ &"strike": true })
	for i in 40:
		if e.arm_off:
			break
		await _tick()
	var plain := Tune.f("strike_dmg") * _w.player.weapon.dmg_mult()
	_ok(e.arm_off and cuts == ["arm"], "arm cut during the wind-up: cuts %s" % [cuts])
	_ok(took.size() == 1 and absf(took[0] - plain * Tune.f("limb_arm_bonus")) < 0.01,
		"bonus damage of the cut: %s (plain %.1f x %.2f)" % [took, plain, Tune.f("limb_arm_bonus")])
	_ok(e.st != "appear" and e.stun > 0.0, "attack cancelled: state %s, stun %.2f" % [e.st, e.stun])
	_ok(absf(e.stat("swipe_x") - swipe_x * 0.6) < 0.01, "one-armed swipe reach %.1f (was %.1f)" % [e.stat("swipe_x"), swipe_x])
	var parts := _w.get_children().filter(func(n: Node) -> bool: return n is LimbPart and (n as LimbPart).limb == "arm")
	_ok(parts.size() == 1, "arm piece flies: %d" % parts.size())
	for i in 14:
		await _tick()
	await _shot("limb-arm.png")
	# A second arm hit during an attack cuts nothing (cannot be cut twice).
	e.stun = 0.0
	e.st = "swipe"
	e.t = 2.0
	var h := Hit.make(Hit.Kind.STRIKE, 5.0, _w.player.position.x, 0.0)
	h.limb = "arm"
	var d := e.hurt(h)
	_ok(cuts.size() == 1 and absf(d - 5.0) < 0.01, "second arm cut refused: cuts %d, damage %.1f" % [cuts.size(), d])

func _head_case() -> void:
	var g := Tune.f("ground_y")
	var e := _w.spawn_enemy(EnemyRoster.make("ringer"), Vector2(HERO_X, g), 0, false, 9) as Ringer
	var idol := _w.spawn_enemy(StrawDummy.new(), Vector2(HERO_X + IDOL_DX, g), -1, false, 1)
	_hero_at(Vector2(HERO_X, g - HEAD_UP))
	await _tick()
	e.st = "recover"
	e.t = 3.0
	var cuts: Array[String] = []
	e.limb_severed.connect(func(_e: Enemy, limb: String) -> void: cuts.append(limb))
	var took: Array[float] = []
	e.damaged.connect(func(_e: Enemy, amount: float, _h: Hit) -> void: took.append(amount))
	var idol_took: Array[float] = []
	idol.damaged.connect(func(_e: Enemy, amount: float, hh: Hit) -> void:
		if hh.kind == Hit.Kind.PROJECTILE:
			idol_took.append(amount))
	await _tick({ &"move_down": true, &"strike": true })
	for i in 40:
		if e.head_off:
			break
		await _tick({ &"move_down": true })
	var plain := Tune.f("strike_dmg") * _w.player.weapon.dmg_mult()
	_ok(e.head_off and cuts == ["head"], "head off from the down-air strike: cuts %s" % [cuts])
	_ok(took.size() >= 1 and absf(took[0] - plain * Tune.f("limb_head_bonus")) < 0.01,
		"head bonus damage: %s (plain %.1f x %.2f)" % [took, plain, Tune.f("limb_head_bonus")])
	_ok(not e.dead and e.hp > 0.0, "it lives on headless: hp %.1f / %.1f" % [e.hp, e.max_hp])
	_ok(not e.limb_zones().has("head"), "no head zone any more")
	for i in 12:
		await _tick()
	await _shot("limb-head.png")
	for i in 40:
		if not idol_took.is_empty():
			break
		await _tick()
	_ok(idol_took.size() == 1 and absf(idol_took[0] - Tune.f("limb_head_dmg")) < 0.01,
		"the flying head hurts another enemy: %s" % [idol_took])
	_ok(not e.dead, "still alive after the head flew")

func _finish() -> void:
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("limb-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
