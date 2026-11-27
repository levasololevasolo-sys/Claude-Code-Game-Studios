## Scripted parry reflect / shield-bearer / thrower check (GDD design/gdd/parry.md
## §3.5, enemies-and-elites §3.4). Real hero input (scripted), real enemies:
## 1. a thrower's stone caught in the parry window flies back and hurts the thrower;
## 2. Упырь-щитник: a front strike is stopped by the shield, a back strike deals
##    full damage, a parried bash only stuns it (no arm, shield stays);
## 3. the thrower runs from a hero who comes close.
## Saves <out_dir>/parry-reflect.png, shield-thrower.png, parry-check-log.txt.
## Started by world.gd with `-- --parry-check=<dir>`.
extends Node

const HERO_X: float = 600.0
## Thrower distance for the reflect case, px.
const FAR_DX: float = 480.0
## Melee distance in front of the hero, px.
const NEAR_DX: float = 70.0
## The parry is pressed when the stone is this close to the hero's centre, px.
const PARRY_AT: float = 70.0
## Thrower distance for the retreat case, px (inside flee_range).
const CLOSE_DX: float = 150.0

var out_dir: String = "user://parry_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[parry-check] ", s)
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

func _hero_at(at: Vector2, face: int = 1) -> void:
	var p := _w.player
	p.position = at
	p.velocity = Vector2.ZERO
	p.hp = 1000.0
	p.inv = 0.0
	p.face = face
	p.parry_cd = 0.0
	p.parry_lock = 0.0
	_w.cam.reset_smoothing()

func _plain() -> float:
	return Tune.f("strike_dmg") * _w.player.weapon.dmg_mult()

func _shots() -> Array[EnemyShot]:
	var out: Array[EnemyShot] = []
	for n in _w.get_children():
		if n is EnemyShot and not n.is_queued_for_deletion():
			out.append(n)
	return out

func _run() -> void:
	await _tick()
	_clear()
	await _ticks(2)
	await _reflect_case()
	_clear()
	await _ticks(20)
	await _shield_case()
	_clear()
	await _ticks(20)
	await _retreat_case()
	_finish()

## 1. A stone parried back hits its thrower.
func _reflect_case() -> void:
	var g := Tune.f("ground_y")
	_hero_at(Vector2(HERO_X, g))
	var e := _w.spawn_enemy(EnemyRoster.make("thrower"), Vector2(HERO_X + FAR_DX, g), 0, false, 5) as Thrower
	await _tick()
	var res: Array[String] = []
	_w.player.parry_succeeded.connect(func(_e: Enemy, r: String) -> void: res.append(r), CONNECT_ONE_SHOT)
	var took: Array[float] = []
	e.damaged.connect(func(_e: Enemy, amount: float, _h: Hit) -> void: took.append(amount))
	var hp0 := _w.player.hp
	e.face = -1
	e.st = "aim"
	e.t = 0.05
	var stone: EnemyShot = null
	var pressed := false
	var shot_taken := false
	var threw := false
	for i in 240:
		if stone == null and not _shots().is_empty():
			stone = _shots()[0]
			threw = true
		var fake := {}
		if stone and is_instance_valid(stone) and not stone.reflected and not pressed:
			var pc := _w.player.position - Vector2(0, Player.H / 2.0)
			if stone.position.distance_to(pc) < PARRY_AT:
				fake = { &"parry": true }
				pressed = true
		if stone and is_instance_valid(stone) and stone.reflected and not shot_taken and absf(stone.position.x - _w.player.position.x) > 140.0:
			shot_taken = true
			await _shot("parry-reflect.png")
		if not took.is_empty():
			break
		e.cd = 99.0
		await _tick(fake)
	_ok(threw, "the thrower threw a stone")
	_ok(res == ["reflect"], "parry result on the stone: %s" % [res])
	_ok(_w.player.hp == hp0, "no damage to the hero: hp %.0f" % _w.player.hp)
	var want := ParryRules.reflect_damage(e.stat("shot_dmg") * e.dmg_mult(), Tune.data)
	_ok(took.size() == 1 and absf(took[0] - want) < 0.01, "reflected stone hurt its thrower: %s (want %.1f)" % [took, want])
	_ok(shot_taken, "screenshot of the reflected stone in flight")

## 2. The shield-bearer: front strike blocked, back strike full, parried bash stuns.
func _shield_case() -> void:
	var g := Tune.f("ground_y")
	_hero_at(Vector2(HERO_X, g))
	var e := _w.spawn_enemy(EnemyRoster.make("sentry"), Vector2(HERO_X + NEAR_DX, g), 0, false, 9) as Sentry
	await _tick()
	var took: Array[float] = []
	e.damaged.connect(func(_e: Enemy, amount: float, _h: Hit) -> void: took.append(amount))
	e.face = -1
	e.cd2 = 99.0
	await _tick({ &"strike": true })
	await _ticks(25)
	_ok(took.size() == 1 and took[0] == 0.0, "front strike stopped by the shield: %s" % [took])
	took.clear()
	e.position.x = HERO_X + NEAR_DX
	e.face = -1
	e.stun = 0.0
	_hero_at(Vector2(e.position.x + NEAR_DX, g), -1)
	await _tick({ &"strike": true })
	await _ticks(10)
	_ok(took.size() == 1 and absf(took[0] - _plain()) < 0.01, "back strike full damage: %s (want %.1f)" % [took, _plain()])
	# Parried bash.
	await _ticks(30)
	_hero_at(Vector2(HERO_X, g))
	e.position.x = HERO_X + NEAR_DX
	e.face = -1
	e.stun = 0.0
	e.kb = 0.0
	var res: Array[String] = []
	_w.player.parry_succeeded.connect(func(_e: Enemy, r: String) -> void: res.append(r), CONNECT_ONE_SHOT)
	var hp0 := _w.player.hp
	e.st = "bash"
	e.t = 0.08
	await _tick({ &"parry": true })
	for i in 20:
		if not res.is_empty():
			break
		await _tick()
	_ok(res == ["stun"] and not e.arm_off and e.stun > 0.0, "parried bash only stuns: %s, stun %.2f" % [res, e.stun])
	_ok(_w.player.hp == hp0, "no damage from the parried bash: hp %.0f" % _w.player.hp)

## 3. The thrower runs from a close hero; screenshot of both kinds.
func _retreat_case() -> void:
	var g := Tune.f("ground_y")
	_hero_at(Vector2(HERO_X, g))
	var e := _w.spawn_enemy(EnemyRoster.make("thrower"), Vector2(HERO_X + CLOSE_DX, g), 0, false, 4) as Thrower
	var s := _w.spawn_enemy(EnemyRoster.make("sentry"), Vector2(HERO_X - 150.0, g), 0, false, 6) as Sentry
	await _tick()
	s.face = 1
	var x0 := e.position.x
	for i in 45:
		e.cd = 99.0
		await _tick()
	var gone := e.position.x - x0
	_ok(gone > 40.0 and e.position.x - _w.player.position.x > CLOSE_DX, "thrower retreated %.0f px (now dx %.0f)" % [gone, e.position.x - _w.player.position.x])
	e.st = "aim"
	e.t = 0.6
	s.st = "bash"
	s.t = 0.5
	s.cd2 = 0.0
	await _ticks(6)
	await _shot("shield-thrower.png")

func _finish() -> void:
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("parry-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
