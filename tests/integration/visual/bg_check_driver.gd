## Background check (the developer: the backdrop must change as the hero walks
## on, and underground needs its own look in every location). For locations 1-3
## builds the graph level, puts the hero in surface rooms from the start to the
## far end and in underground rooms of both depth bands, and saves one strip per
## location: bg-<tier>-surface.png (4 spots left to right) and
## bg-<tier>-under.png (4 underground spots). Started by world.gd with
## `-- --bg-check=<dir>`; run with `--fresh --save=user://bg_save.json`.
extends Node

var out_dir: String = "user://bg_check"
var _w: World
var _d: RunDirector
var _log: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	_log.append(s)
	print("[bg-check] ", s)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(640, 360)
	return img

## A standing spot in room `ri` (floor under, 2 free cells above), its centre-most.
func _spot(ri: int) -> Vector2:
	var lr := _w.level_room
	var r: Dictionary = lr.level.rooms[ri]
	var x0 := int(r.x) * lr.mw
	var y0 := int(r.y) * lr.mh
	var c0 := Vector2(x0 + int(r.w) * lr.mw * 0.5, y0 + int(r.h) * lr.mh * 0.5)
	var best := Vector2i(-1, -1)
	var best_d := INF
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

func _strip(rooms: Array, file: String) -> void:
	var sheet := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for i in mini(rooms.size(), 4):
		var p := _w.player
		p.position = _spot(rooms[i]) - Vector2(0, 2)
		p.velocity = Vector2.ZERO
		p.hp = 1.0e6
		_w.cam.reset_smoothing()
		await _frames(25)
		var img := await _grab()
		sheet.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
	sheet.save_png(out_dir.path_join(file))
	_note("screenshot " + file)

func _run() -> void:
	_d = _w.director
	for i in 600:
		if _d.screen is RuneOfferScreen:
			break
		await get_tree().process_frame
	if _d.screen is RuneOfferScreen:
		(_d.screen as RuneOfferScreen).take(0)
	await _frames(20)
	for tier in [1, 2, 3]:
		if tier > 1:
			_d.run.tier = tier
			_d.run.room_k = 1
			_d.enter_room()
			await _frames(20)
			if _d.screen is RuneOfferScreen:
				(_d.screen as RuneOfferScreen).take(0)
		await _frames(10)
		for e in get_tree().get_nodes_in_group("enemies"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
		var lr := _w.level_room
		if lr == null:
			_note("tier %d: not a graph level" % tier)
			continue
		var surf: Array = []
		var under: Array = []
		for r: Dictionary in lr.level.rooms:
			if int(r.get("band", 0)) <= 0:
				surf.append(r)
			else:
				under.append(r)
		surf.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.x) < int(b.x))
		under.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.band) * 1000 + int(a.x) < int(b.band) * 1000 + int(b.x))
		var pick := func(arr: Array) -> Array:
			var out: Array = []
			for k in 4:
				if arr.is_empty():
					break
				out.append(int((arr[int(round(k * (arr.size() - 1) / 3.0))] as Dictionary).i))
			return out
		_note("tier %d: %d surface rooms, %d underground, level %d x %d px" % [tier, surf.size(), under.size(), int(lr.layout.w), int(lr.layout.h)])
		await _strip(pick.call(surf), "bg-%d-surface.png" % tier)
		await _strip(pick.call(under), "bg-%d-under.png" % tier)
	var f := FileAccess.open(out_dir.path_join("bg-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	_note("DONE")
	get_tree().quit()
