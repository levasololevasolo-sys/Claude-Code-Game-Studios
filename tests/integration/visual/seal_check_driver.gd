## Seal check (artifacts-and-secrets §3.3-3.4, AC 5): for locations 1-3 builds
## the graph level, walks the hero to each seal, first without artifacts (E shows
## the riddle, nothing opens), then with all of them (E opens it by its artifact)
## and saves seal-<tier>-<n>-locked.png / -open.png plus a log of what opened.
## Started by world.gd with `-- --seal-check=<dir>`; run with
## `--fresh --save=user://seal_save.json`.
extends Node

var out_dir: String = "user://seal_check"
var _w: World
var _d: RunDirector
var _log: PackedStringArray = []
var _fails: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	_log.append(s)
	print("[seal-check] ", s)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(960, 540)
	img.save_png(out_dir.path_join(file))

func _seals() -> Array[Seal]:
	var out: Array[Seal] = []
	for c in _w.get_children():
		if c is Seal:
			out.append(c)
	return out

func _take_offer() -> void:
	for i in 300:
		if _d.screen is RuneOfferScreen:
			(_d.screen as RuneOfferScreen).take(0)
			return
		await get_tree().process_frame

func _run() -> void:
	_d = _w.director
	await _take_offer()
	await _frames(20)
	var meta: MetaState = _d.game.meta
	for tier in [1, 2, 3]:
		meta.wins = 0
		meta.artifacts.clear()
		if tier > 1:
			_d.run.tier = tier
			_d.run.room_k = 1
			_d.enter_room()
			await _frames(10)
			await _take_offer()
		await _frames(10)
		for e in get_tree().get_nodes_in_group("enemies"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
		var seals := _seals()
		_note("tier %d: %d seals %s" % [tier, seals.size(), seals.map(func(s: Seal) -> String: return s.kind)])
		if seals.is_empty():
			_fails += 1
		for n in seals.size():
			var se := seals[n]
			meta.wins = 0
			meta.artifacts.clear()
			var p := _w.player
			p.hp = 1.0e6
			p.position = se.position + Vector2(-30, -2)
			p.velocity = Vector2.ZERO
			_w.cam.reset_smoothing()
			await _frames(20)
			var opened := se.press()
			await _frames(6)
			await _shot("seal-%d-%d-locked.png" % [tier, n])
			if opened:
				_note("  FAIL %s opened without the artifact" % se.kind)
				_fails += 1
			meta.wins = 1
			Artifacts.grant_if_cleared(meta, se.tbl)
			p.position = se.position + Vector2(-30, -2)
			await _frames(4)
			var ok := se.press()
			await _frames(70)
			_w.cam.reset_smoothing()
			await _frames(4)
			await _shot("seal-%d-%d-open.png" % [tier, n])
			var mode := se.open_mode()
			var detail := ""
			match mode:
				"pull":
					detail = "hero at %s, land %s" % [p.position.round(), se.land.round()]
					ok = ok and p.position.distance_to(se.land) < 4.0
				"build":
					detail = "%d of %d bridge cells" % [se._built, se.w_cells.size()]
					ok = ok and se._built == se.w_cells.size() and se.w_cells.size() > 0
				_:
					detail = "barrier %s" % ("gone" if se._bar == null else "STILL THERE")
					ok = ok and se._bar == null
			_note("  %s (%s): %s — %s" % [se.kind, mode, "OK" if ok else "FAIL", detail])
			if not ok:
				_fails += 1
	_note("fails: %d" % _fails)
	var f := FileAccess.open(out_dir.path_join("seal-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	_note("DONE")
	get_tree().quit(1 if _fails > 0 else 0)
