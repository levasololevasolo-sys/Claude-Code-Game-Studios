## Scripted level check (GDD room-generation-and-doors §3.3-3.6, §3.10, §3.13;
## enemies-and-elites §3.6-3.7). Builds a chunk room of tier 2 room 3 with the
## knight, 2 forced elites and a forced breakable wall, and saves
## <out_dir>/level-chunks.png (a shaft: vertical layout), level-elite.png (an
## elite with its mark word and aura), level-knight.png, level-cache.png (the
## wall broken, the rich chest open, traps) and level-check-log.txt.
## Started by world.gd with `-- --level-check=<dir>` (a legacy flag: no run).
extends Node

var out_dir: String = "user://level_check"
var _w: World
var _log: PackedStringArray = []
var _fail: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	_log.append(s)
	print("[level-check] ", s)

func _check(ok: bool, what: String) -> void:
	_note(("OK   " if ok else "FAIL ") + what)
	if not ok:
		_fail += 1

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _look(at: Vector2) -> void:
	var p := _w.player
	p.position = at
	p.velocity = Vector2.ZERO
	_w.cam.reset_smoothing()

func _run() -> void:
	await _frames(3)
	var layout: Dictionary = {}
	var rng: RandomNumberGenerator
	var opts := { "knight": true, "elite_force": 2, "secret_ok": true, "secret_force": true }
	for s in range(1, 400):
		rng = RandomNumberGenerator.new()
		rng.seed = s
		var l := RoomGen.generate(rng, 3, 2, Tune.data, true, opts)
		var tall := false
		for c: Dictionary in l.chunks:
			tall = tall or (c.kind == "shaft" and int(c.h) >= 2)
		if not l.fallback and not (l.wall as Dictionary).is_empty() and tall:
			layout = l
			_note("seed %d: chunks %s" % [s, (l.chunks as Array).map(func(c: Dictionary) -> String: return c.id)])
			break
	_check(not layout.is_empty(), "found a chunk room with a shaft and a breakable wall")
	if layout.is_empty():
		_finish()
		return
	_w.tier = 2
	_w.room_k = 3
	_w.start_room(layout, rng)
	await _frames(2)
	var p := _w.player
	p.scripted = true
	p.inv = 1.0e6
	_check((layout.solids as Array).size() > 0 and float(layout.top) < Tune.f("ground_y") - 360.0, "vertical pieces: %d solids, top y %d" % [(layout.solids as Array).size(), int(layout.top)])
	# 1. A shaft.
	var shaft: Dictionary = {}
	for c: Dictionary in layout.chunks:
		if c.kind == "shaft" and int(c.h) >= 2:
			shaft = c
			break
	_look(Vector2(float(shaft.x) + 320.0, Tune.f("ground_y") - 240.0))
	await _frames(4)
	await _shot("level-chunks.png")
	# 2. An elite with its mark.
	var elites: Array = []
	var knight: Knight = null
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.mark != "":
			elites.append(e)
		if e is Knight:
			knight = e
	_check(elites.size() == 2, "2 forced elites: %s" % [elites.map(func(e: Enemy) -> String: return "%s/%s hp %d" % [e.kind_id, e.mark, int(e.max_hp)])])
	if not elites.is_empty():
		var el: Enemy = elites[0]
		var base := float(Tune.row("enemies", el.kind_id).hp) * Enemy.tier_mult(2, Tune.f("tier_hp"))
		_check(absf(el.max_hp - base * Tune.f("elite_hp")) < 0.01, "elite hp ×%.1f: %d" % [Tune.f("elite_hp"), int(el.max_hp)])
		_look(Vector2(el.position.x - 260.0, Tune.f("ground_y")))
		await _frames(20)
		_look(Vector2(el.position.x - 260.0, Tune.f("ground_y")))
		await _frames(3)
		await _shot("level-elite.png")
	# 3. The knight.
	_check(knight != null and absf(knight.max_hp - 230.0 * Enemy.tier_mult(2, Tune.f("tier_hp"))) < 0.01, "the knight stands at x %d" % (int(knight.position.x) if knight else -1))
	if knight:
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if e != knight and not e.prop and absf(e.position.x - knight.position.x) < 700.0:
				e.hurt(Hit.make(Hit.Kind.STRIKE, 1.0e6, e.position.x, 0.0))
		await _frames(2)
		_look(Vector2(knight.position.x - 300.0, Tune.f("ground_y")))
		await _frames(24)
		_check(not knight.asleep and knight.alert_colour == Color("#ff3b3b"), "knight woke on his own (state %s)" % knight.st)
		_look(Vector2(knight.position.x - 300.0, Tune.f("ground_y")))
		await _frames(2)
		await _shot("level-knight.png")
	# 4. The cache: three hits break the wall, the rich chest opens.
	var wall: BreakableWall = null
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e is BreakableWall:
			wall = e
	_check(wall != null, "breakable wall stands")
	if wall:
		wall.hurt(Hit.make(Hit.Kind.STRIKE, 10.0, wall.position.x - 30.0, 0.0))
		wall.hurt(Hit.make(Hit.Kind.PROJECTILE, 10.0, wall.position.x - 30.0, 0.0))
		_check(is_instance_valid(wall) and not wall.dead, "wall holds after 2 hits")
		wall.hurt(Hit.make(Hit.Kind.FLARE, 10.0, wall.position.x - 30.0, 0.0))
		_check(wall.dead, "wall falls on the 3rd hit (strike, shot, Flare)")
	var chest: Chest = null
	var traps := 0
	for c in _w.get_children():
		if c is Chest and (c as Chest).rich:
			chest = c
		if c is Trap:
			traps += 1
	_check(chest != null and traps >= 2, "secret pocket: rich chest, %d traps" % traps)
	if chest:
		chest.open()
		_check(chest.is_open, "cache chest opens")
		_look(Vector2(chest.position.x - 170.0, chest.position.y - 2.0))
		await _frames(50)
		_look(Vector2(chest.position.x - 170.0, chest.position.y - 2.0))
		await _frames(2)
		await _shot("level-cache.png")
	_finish()

func _finish() -> void:
	_note("DONE: %d failed checks" % _fail)
	var f := FileAccess.open(out_dir.path_join("level-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().quit(1 if _fail > 0 else 0)
