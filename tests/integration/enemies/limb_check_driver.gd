## Scripted limb zones and parry check (GDD design/gdd/limb-zones.md,
## design/gdd/parry.md). With real hero input (scripted) and real enemy blows:
## 1. a parried Аука swipe cuts its arm (no damage to the hero, stun);
## 2. a plain swing on the arm during its attack cuts nothing;
## 3. Навий витязь loses the arm only on the 3rd parry of his lunge;
## 4. a down-air strike on the head of a Аука NOT attacking is a plain hit; the
##    same strike while it attacks knocks the head off, the head hurts an idol;
## 5. two deaths of a wolf: plain and with the head flying.
## Saves <out_dir>/limb-parry.png, limb-head.png, limb-death.png, limb-check-log.txt.
## Started by world.gd with `-- --limb-check=<dir>`.
extends Node

const HERO_X: float = 600.0
## Enemy distance in front of the hero, px.
const NEAR_DX: float = 70.0
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

func _ticks(n: int) -> void:
	for i in n:
		await _tick()

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
	p.inv = 0.0
	p.face = 1
	p.parry_cd = 0.0
	p.parry_lock = 0.0
	_w.cam.reset_smoothing()

func _plain() -> float:
	return Tune.f("strike_dmg") * _w.player.weapon.dmg_mult()

func _run() -> void:
	await _tick()
	_clear()
	await _ticks(2)
	await _parry_case()
	_clear()
	await _ticks(20)
	await _plain_arm_case()
	_clear()
	await _ticks(20)
	await _knight_case()
	_clear()
	await _ticks(20)
	await _head_case()
	_clear()
	await _ticks(20)
	await _death_case()
	_finish()

## 1. The parry cuts the arm.
func _parry_case() -> void:
	var g := Tune.f("ground_y")
	_hero_at(Vector2(HERO_X, g))
	var e := _w.spawn_enemy(EnemyRoster.make("ringer"), Vector2(HERO_X + NEAR_DX, g), 0, false, 7) as Ringer
	await _tick()
	var res: Array[String] = []
	_w.player.parry_succeeded.connect(func(_e: Enemy, r: String) -> void: res.append(r), CONNECT_ONE_SHOT)
	var hp0 := _w.player.hp
	var swipe_x := e.stat("swipe_x")
	await _tick({ &"parry": true })
	e.face = -1
	e.st = "swipe"
	e.t = 0.5
	e.swiped = false
	for i in 20:
		if not res.is_empty():
			break
		await _tick()
	_ok(res == ["arm"] and e.arm_off, "parried swipe cuts the arm: %s" % [res])
	_ok(_w.player.hp == hp0, "no damage to the hero on a parry: hp %.0f" % _w.player.hp)
	_ok(e.stun > 0.0 and e.st != "swipe", "attacker stunned, attack gone: stun %.2f, state %s" % [e.stun, e.st])
	_ok(absf(e.stat("swipe_x") - swipe_x * 0.6) < 0.01, "one-armed swipe reach %.1f (was %.1f)" % [e.stat("swipe_x"), swipe_x])
	await _ticks(10)
	await _shot("limb-parry.png")

## 2. A plain strike on the arm during the attack does not cut.
func _plain_arm_case() -> void:
	var g := Tune.f("ground_y")
	_hero_at(Vector2(HERO_X, g))
	var e := _w.spawn_enemy(EnemyRoster.make("ringer"), Vector2(HERO_X + NEAR_DX, g), 0, false, 8) as Ringer
	await _tick()
	var took: Array[float] = []
	e.damaged.connect(func(_e: Enemy, amount: float, _h: Hit) -> void: took.append(amount))
	e.face = -1
	e.st = "appear"
	e.t = 2.0
	await _tick({ &"strike": true })
	await _ticks(20)
	_ok(not e.arm_off and took.size() == 1 and absf(took[0] - _plain()) < 0.01, "plain swing on the arm in its attack: no cut, damage %s" % [took])

## 3. The knight loses the arm only on the 3rd parried lunge.
func _knight_case() -> void:
	var g := Tune.f("ground_y")
	var k := _w.spawn_enemy(Knight.new(), Vector2(HERO_X + 50.0, g), 0, false, 3) as Knight
	await _tick()
	var res: Array[String] = []
	_w.player.parry_succeeded.connect(func(_e: Enemy, r: String) -> void: res.append(r))
	for i in 3:
		_hero_at(Vector2(HERO_X, g))
		k.position.x = HERO_X + 50.0
		k.stun = 0.0
		await _tick({ &"parry": true })
		k.face = -1
		k.st = "lunge"
		k.t = 0.3
		k.set("_hit_done", false)
		var n := res.size()
		for j in 20:
			if res.size() > n:
				break
			await _tick()
		_note("knight parry %d: %s, arm_off %s" % [i + 1, res, k.arm_off])
		if i < 2:
			_ok(not k.arm_off, "knight keeps the arm after parry %d" % (i + 1))
		await _ticks(5)
	for c in _w.player.parry_succeeded.get_connections():
		_w.player.parry_succeeded.disconnect(c.callable)
	_ok(res == ["nick", "nick", "arm"] and k.arm_off, "knight arm flies on the 3rd parry: %s" % [res])

## 4. The head: plain without an attack, off during an attack; it hurts an idol.
func _head_case() -> void:
	var g := Tune.f("ground_y")
	var e := _w.spawn_enemy(EnemyRoster.make("ringer"), Vector2(HERO_X, g), 0, false, 9) as Ringer
	var idol := _w.spawn_enemy(StrawDummy.new(), Vector2(HERO_X + IDOL_DX, g), -1, false, 1)
	_hero_at(Vector2(HERO_X, g - HEAD_UP))
	await _tick()
	var took: Array[float] = []
	e.damaged.connect(func(_e: Enemy, amount: float, _h: Hit) -> void: took.append(amount))
	var idol_took: Array[float] = []
	idol.damaged.connect(func(_e: Enemy, amount: float, hh: Hit) -> void:
		if hh.kind == Hit.Kind.PROJECTILE:
			idol_took.append(amount))
	e.st = "recover"
	e.t = 5.0
	await _tick({ &"move_down": true, &"strike": true })
	for i in 30:
		if not took.is_empty():
			break
		await _tick({ &"move_down": true })
	_ok(not e.head_off and took.size() == 1 and absf(took[0] - _plain()) < 0.01, "down-air on the head outside an attack: plain %s" % [took])
	# Again, now while it winds up.
	await _ticks(30)
	_hero_at(Vector2(HERO_X, g - HEAD_UP))
	e.position.x = HERO_X
	e.st = "appear"
	e.t = 5.0
	took.clear()
	await _tick({ &"move_down": true, &"strike": true })
	for i in 40:
		if e.head_off:
			break
		await _tick({ &"move_down": true })
	_ok(e.head_off and took.size() >= 1 and absf(took[0] - _plain() * Tune.f("limb_head_bonus")) < 0.01,
		"down-air on the head during its attack: head off, damage %s" % [took])
	_ok(not e.dead and e.hp > 0.0, "it lives on headless: hp %.1f / %.1f" % [e.hp, e.max_hp])
	await _ticks(12)
	await _shot("limb-head.png")
	for i in 40:
		if not idol_took.is_empty():
			break
		await _tick()
	_ok(idol_took.size() == 1 and absf(idol_took[0] - Tune.f("limb_head_dmg")) < 0.01, "the flying head hurts another enemy: %s" % [idol_took])

## 5. Two deaths of a wolf: plain (chance 0, body hit), with the head (chance 1).
func _death_case() -> void:
	var g := Tune.f("ground_y")
	var keep := Tune.f("death_sever_chance")
	var got: Array[String] = []
	for chance: float in [0.0, 1.0]:
		Tune.data["death_sever_chance"] = chance
		_hero_at(Vector2(HERO_X, g))
		var e := _w.spawn_enemy(EnemyRoster.make("wolf"), Vector2(HERO_X + NEAR_DX, g), 0, false, 11)
		await _tick()
		e.face = 1
		e.st = "recover"
		e.t = 5.0
		e.hp = 1.0
		await _tick({ &"strike": true })
		for i in 20:
			if e.dead:
				break
			await _tick()
		got.append(e.death_severed)
		if chance > 0.0:
			await _ticks(10)
			await _shot("limb-death.png")
		await _ticks(30)
	Tune.data["death_sever_chance"] = keep
	_ok(got == ["", "head"], "two wolf deaths, plain and with the head: %s" % [got])

func _finish() -> void:
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("limb-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
