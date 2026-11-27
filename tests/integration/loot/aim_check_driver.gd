## Scripted aim check (GDD weapons-and-loot §3.4 «Прицел»): equips the bow,
## fires once without aim (straight by facing), then holds `aim` with the
## scripted cursor up-left of the hero and fires: the arrow must fly toward the
## cursor at its normal speed and the hero must turn left; then the run speed
## while aiming must be aim_move_mult of the normal one. Screenshot
## <out_dir>/aim-shot.png. Started by world.gd with `-- --aim-check=<dir>`.
extends Node

const HERO_X: float = 1200.0
## Cursor offset from the hand for the aimed shot (up-left), world px.
const AIM_AT: Vector2 = Vector2(-420, -300)

var out_dir: String = "user://aim_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[aim-check] ", s)
	_lines.append(s)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	_note(("OK   " if cond else "FAIL ") + what)

func _frames(n: int, keys: Dictionary = {}) -> void:
	var p: Player = _w.player
	for i in n:
		p.fake = keys
		await p.stepped
	p.fake = {}

func _clear() -> void:
	for n in _w.get_children():
		if n is Enemy or n is EnemyShot or n is HeroShot:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()

func _place() -> void:
	var p: Player = _w.player
	p.scripted = true
	p.position = Vector2(HERO_X, Tune.f("ground_y"))
	p.velocity = Vector2.ZERO
	p.face = 1
	p.hp = 1000.0
	p.sub_cd = 0.0
	_w.cam.reset_smoothing()

func _last_shot() -> HeroShot:
	var out: HeroShot = null
	for n in _w.get_children():
		if n is HeroShot and not n.is_queued_for_deletion():
			out = n
	return out

func _run() -> void:
	await _frames(10)
	_clear()
	var p: Player = _w.player
	p.equip(Weapon.make("bow", Weapon.SUB))
	_place()
	await _frames(2)
	# 1. No aim: straight by facing (old behaviour).
	await _frames(1, { "sub": true })
	var s0 := _last_shot()
	_ok(s0 != null and s0.vel.normalized().is_equal_approx(Vector2.RIGHT), "no aim: arrow flies right by facing (%s)" % [s0.vel if s0 else "none"])
	await _frames(60)
	_clear()
	_place()
	# 2. Aim up-left at a point and fire.
	var target := p.hand() + AIM_AT
	p.fake_aim_point = target
	await _frames(6, { "aim": true })
	_ok(p.face == -1, "aiming up-left turns the hero left (face %d)" % p.face)
	await _frames(1, { "aim": true, "sub": true })
	var s1 := _last_shot()
	var want := (target - p.hand()).normalized()
	_ok(s1 != null and s1.vel.normalized().dot(want) > 0.999, "aimed arrow flies toward the cursor (vel %s, want %s)" % [s1.vel if s1 else "none", want])
	_ok(s1 != null and absf(s1.vel.length() - float(p.sub.row().speed)) < 0.5, "arrow speed unchanged (%.1f)" % (s1.vel.length() if s1 else 0.0))
	await _frames(8, { "aim": true })
	p.fake = { "aim": true }
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("aim-shot.png"))
	_note("screenshot aim-shot.png")
	await _frames(60)
	# 3. Slow walk while aiming.
	_clear()
	_place()
	await _frames(40, { "move_right": true })
	var free_v := absf(p.velocity.x)
	p.fake_aim_point = p.hand() + Vector2(400, 0)
	await _frames(40, { "move_right": true, "aim": true })
	var aim_v := absf(p.velocity.x)
	_ok(absf(aim_v - free_v * Tune.f("aim_move_mult")) < 8.0, "run speed while aiming %.0f = %.0f x aim_move_mult" % [aim_v, free_v])
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("aim-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
