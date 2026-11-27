## Scripted check of the graph-mode level (GDD level-structure §3.1-3.6, AC 6-10;
## stage 1, the Swamp). Plays a run whose Swamp level is seed 7007
## (RunDirector.level_seed_override): checks the generator is deterministic and
## that another seed differs, walks the critical path room by room through
## teleports (each next room must be a graph neighbour and the hero must stand on
## its floor), clears the packs in the way, takes every shrine reward through the
## real reward screens, enters one gate of every fork (the others must close),
## checks the lair stays off the map until its door is seen, opens the full map
## and finally goes through the lair door into the boss scene.
## Saves <out_dir>/level2-room-1.png (section 1), level2-room-2.png (a shaft),
## level2-room-3.png (a fork with its gate signs), level2-minimap.png,
## level2-overview.png (the full map) and level2-check-log.txt.
## Started by world.gd with `-- --level2-check=<dir>`; run it with
## `--fresh --save=user://l2_save.json`.
extends Node

const SEED: int = 7007
const OTHER_SEED: int = 9001

var out_dir: String = "user://level2_check"
var _w: World
var _d: RunDirector
var _log: PackedStringArray = []
var _fail: int = 0
var _shots: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_node("/root/Game").meta.runs = 1
	RunDirector.level_seed_override = SEED
	_run.call_deferred()

func _note(s: String) -> void:
	_log.append(s)
	print("[level2-check] ", s)

func _check(ok: bool, what: String) -> void:
	_note(("OK   " if ok else "FAIL ") + what)
	if not ok:
		_fail += 1

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _wait(cond: Callable, max_frames: int = 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _take_screen() -> void:
	var s := _d.screen
	if s is RuneOfferScreen:
		(s as RuneOfferScreen).take(0)
	elif s is GodChoiceScreen:
		(s as GodChoiceScreen).take(0)

## A standing spot in room `ri` (floor under, 2 free cells above), nearest to `near` (cells).
func _spot(ri: int, near: Vector2 = Vector2(-1, -1)) -> Vector2:
	var lr := _w.level_room
	var r: Dictionary = lr.level.rooms[ri]
	var best := Vector2i(-1, -1)
	var best_d := INF
	var x0 := int(r.x) * lr.mw
	var y0 := int(r.y) * lr.mh
	var c0 := near if near.x >= 0.0 else Vector2(x0 + int(r.w) * lr.mw * 0.5, y0 + int(r.h) * lr.mh * 0.5)
	for y in range(y0 + 1, y0 + int(r.h) * lr.mh - 1):
		for x in range(x0 + 1, x0 + int(r.w) * lr.mw - 1):
			var c := Vector2i(x, y)
			if lr.at(c) != "." or lr.at(c + Vector2i(0, -1)) != "." or lr.at(c + Vector2i(0, -2)) == "#":
				continue
			var below := lr.at(c + Vector2i(0, 1))
			if not (below == "#" or below == "="):
				continue
			var d := Vector2(c).distance_to(c0)
			if d < best_d:
				best_d = d
				best = c
	return lr.cell_floor(best) if best.x >= 0 else lr.room_rect(ri).get_center()

func _tp(at: Vector2) -> void:
	var p := _w.player
	p.position = at - Vector2(0, 2)
	p.velocity = Vector2.ZERO
	_w.cam.reset_smoothing()

func _kill_in(rooms: Array) -> int:
	var n := 0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and not e.prop and _w.level_room.room_at(e.position) in rooms:
			e.hurt(Hit.make(Hit.Kind.STRIKE, 1.0e6, e.position.x, 0.0))
			n += 1
	return n

## Walks rooms `path` one by one; each step must follow a level edge.
func _walk(path: Array, edges: Dictionary) -> void:
	for i in path.size():
		var ri: int = path[i]
		if i > 0:
			var prev: int = path[i - 1]
			_check(edges.has("%d-%d" % [prev, ri]), "room %d -> %d is a level edge" % [prev, ri])
		_kill_in([ri])
		_tp(_spot(ri))
		await _frames(6)
		var p := _w.player
		var lr := _w.level_room
		var here := lr.room_at(p.position - Vector2(0, 20))
		var r: Dictionary = lr.level.rooms[ri]
		_check(p.is_on_floor() and here == ri, "stands in room %d %s (%s) at %s" % [ri, r.id, r.kind, p.position.round()])
		if String(r.kind) == "shaft" and not _shots.has("level2-room-2.png"):
			_shots["level2-room-2.png"] = true
			_tp(lr.room_rect(ri).get_center() - Vector2(0, lr.room_rect(ri).size.y * 0.3))
			p.velocity = Vector2(0, 900)
			await _frames(8)
			await _shot("level2-room-2.png")
			_tp(_spot(ri))
			await _frames(4)

func _run() -> void:
	_d = _w.director
	_d.noted.connect(func(s: String) -> void: _log.append("  " + s))
	# Generator: one seed, one level; another seed, another level.
	var lib := LevelGen.library("swamp")
	var t := LevelGen.tuning_for(Tune.data)
	var a := LevelGen.build(SEED, 1, lib, t)
	var b := LevelGen.build(SEED, 1, lib, t)
	var c := LevelGen.build(OTHER_SEED, 1, lib, t)
	_check(a.grid == b.grid and LevelGen.main_signature(a) == LevelGen.main_signature(b), "seed %d builds the same level twice" % SEED)
	_check(LevelGen.main_signature(a) != LevelGen.main_signature(c), "seed %d builds another main path (%d vs %d rooms)" % [OTHER_SEED, (a.rooms as Array).size(), (c.rooms as Array).size()])
	var ok := await _wait(func() -> bool: return _d.screen is RuneOfferScreen)
	_check(ok, "run starts with a rune offer")
	_take_screen()
	ok = await _wait(func() -> bool: return _d.phase == "level" and _d.flow != null)
	_check(ok, "the Swamp is one graph level (phase level)")
	if not ok:
		_finish()
		return
	var lv := _d.level
	var fl := _d.flow
	_w.player.scripted = true
	_w.player.inv = 1.0e6
	_check((lv.forks as Array).size() == 3, "3 forks: trails %s" % [(lv.forks as Array).map(func(f: Dictionary) -> int: return (f.trails as Array).size())])
	var edges := {}
	for e: Array in lv.edges:
		edges["%d-%d" % [e[0], e[1]]] = true
		edges["%d-%d" % [e[1], e[0]]] = true
	await _frames(10)
	var asleep := 0
	var total := 0
	var on_floor := 0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.prop:
			continue
		total += 1
		if e.asleep:
			asleep += 1
		if e.flies or absf(e.position.y - _w.level_room.floor_below(e.position - Vector2(0, 10))) < 2.0:
			on_floor += 1
	_check(total > 10 and asleep == total, "%d enemies sleep in the level on entry" % total)
	_check(on_floor == total, "every walker stands on its own floor (%d of %d)" % [on_floor, total])
	await _shot("level2-room-1.png")
	_check(not fl.map.shows_lair(), "the lair is not on the map at the start")
	# Section 1 up to its shrine.
	var sec0: Array = []
	for r: Dictionary in lv.rooms:
		if int(r.sec) == 0 and String(r.path) == "main" and String(r.kind) != "fork":
			sec0.append(int(r.i))
	await _walk(sec0, edges)
	await _shrine(0)
	for fi in (lv.forks as Array).size():
		var f: Dictionary = lv.forks[fi]
		var fr := int(f.room)
		await _walk([fr], edges)
		ok = await _wait(func() -> bool: return fl.gates_set(fi), 120)
		_check(ok, "fork %d shows its gate signs: %s" % [fi + 1, (fl.forks[fi].gates as Array).map(func(g: Dictionary) -> String: return "%s %s" % [g.info.get("type"), g.info.get("god")])])
		if not _shots.has("level2-room-3.png"):
			_shots["level2-room-3.png"] = true
			var hc := Vector2(-1, -1)
			for m: Dictionary in lv.marks:
				if int(m.room) == fr and String(m.ch) == "H":
					hc = Vector2(m.c)
			_tp(_spot(fr, hc))
			await _frames(20)
			await _shot("level2-room-3.png")
		_check(not fl.map.shows_lair(), "fork %d: the lair is still off the map" % (fi + 1))
		# Enter the first gate: the hero goes into its first trail room.
		var tr: Dictionary = f.trails[0]
		var first := int((tr.rooms as Array)[0])
		_kill_in(tr.rooms)
		_tp(_spot(first))
		ok = await _wait(func() -> bool: return int(fl.forks[fi].chosen) >= 0, 120)
		var closed := 0
		for g: Dictionary in fl.forks[fi].gates:
			if int(g.trail) != 0 and not (g.door as Door).active:
				closed += 1
		_check(ok and int(fl.forks[fi].chosen) == 0 and closed == (f.trails as Array).size() - 1, "fork %d: gate 1 taken, %d other gate(s) closed by roots" % [fi + 1, closed])
		_check(String(_d.run.reward.get("type", "")) == String(fl.forks[fi].gates[0].info.get("type", "?")), "the trail promises the gate's reward %s" % _d.run.reward)
		await _walk(tr.rooms, edges)
		await _shrine((lv.shrines as Array).find(int(tr.shrine)))
		# Down through the links into the junction, then the descent.
		var after: Array = []
		for r: Dictionary in lv.rooms:
			if int(r.sec) == fi + 1 and String(r.path) == "main":
				after.append(int(r.i))
		after.sort_custom(func(x: int, y: int) -> bool: return _order(x, lv) < _order(y, lv))
		var links: Array = []
		for r: Dictionary in lv.rooms:
			if String(r.kind) == "link" and (r.trail as Array) == [fi + 1, 0]:
				links.append(int(r.i))
		await _walk(links, edges)
		after = after.filter(func(x: int) -> bool: return String(lv.rooms[x].kind) != "fork")
		await _walk(after, edges)
		if fi == 0:
			_tp(_spot(int(after[0])))
			await _frames(20)
			await _shot("level2-minimap.png")
	ok = await _wait(func() -> bool: return fl.map.shows_lair(), 60)
	_check(ok, "the lair shows on the map once the lair gate room is seen")
	# Full map with everything revealed.
	for r: Dictionary in lv.rooms:
		if String(r.path) != "branch":
			fl.map.visit(int(r.i))
	var full := fl.open_full_map()
	await _frames(6)
	_check(get_tree().paused, "the full map pauses the game")
	await _shot("level2-overview.png")
	full.close()
	await _frames(3)
	_tp(fl.lair_pos)
	await _frames(4)
	fl.lair_used.emit()
	ok = await _wait(func() -> bool: return _d.run.stage == "lair" and _d.phase == "fight", 200)
	_check(ok and _d.flow == null or ok, "the lair door leads to the boss scene (stage %s)" % _d.run.stage)
	_finish()

## Order of the rooms after a junction: the junction first, then by docking order (index).
func _order(i: int, lv: Dictionary) -> int:
	return -1 if String(lv.rooms[i].kind) == "junction" else i

func _shrine(s: int) -> void:
	var fl := _d.flow
	var info := _d.run.reward.duplicate()
	_kill_in(fl.shrines[s].rooms)
	await _frames(2)
	_tp(fl.shrines[s].pos)
	var ok := await _wait(func() -> bool: return _d.screen != null or _d.phase == "level" and bool(fl.shrines[s].taken), 300)
	_check(ok and bool(fl.shrines[s].taken), "shrine %d gives its reward %s" % [s + 1, info])
	for i in 3:
		if _d.screen != null:
			_take_screen()
			await _frames(4)
	await _wait(func() -> bool: return _d.phase == "level", 200)

func _finish() -> void:
	_note("DONE: %d failed checks" % _fail)
	var f := FileAccess.open(out_dir.path_join("level2-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().paused = false
	get_tree().quit(1 if _fail > 0 else 0)
