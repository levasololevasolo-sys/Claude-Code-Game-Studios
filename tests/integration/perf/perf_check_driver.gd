## Frame-cost probe (BUG: 15 FPS on the developer's PC). Starts the normal run
## flow, waits for the first room, wakes its enemies, then for each subsystem
## hides it and measures how much the frame gets cheaper. Writes perf-check-log.txt.
## Started by world.gd with `-- --perf-check=<dir>`.
extends Node

const FRAMES: int = 45

var out_dir: String = "user://perf_check"
var _w: World
var _lines: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[perf-check] ", s)
	_lines.append(s)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Average wall frame, process and physics time (ms) and draw calls over FRAMES.
func _measure(label: String) -> Dictionary:
	await _frames(10)
	var t0 := Time.get_ticks_usec()
	var proc := 0.0
	var phys := 0.0
	var calls := 0.0
	var objs := 0.0
	for i in FRAMES:
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var wall := float(Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
	var r := { "wall": wall, "proc": proc * 1000.0 / FRAMES, "phys": phys * 1000.0 / FRAMES, "calls": calls / FRAMES, "objs": objs / FRAMES }
	_note("%-28s frame %6.1f ms | process %5.1f ms | physics %5.1f ms | draw calls %5.0f | nodes %d" % [label, r.wall, r.proc, r.phys, r.calls, get_tree().get_node_count()])
	return r

func _shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot " + file)

## Turns one category off for the --perf-off= runs.
func _disable(what: String) -> void:
	var nodes: Array = []
	match what:
		"vfx": nodes = [_w.atmosphere.vfx]
		"atmosphere": nodes = [_w.atmosphere]
		"darkness": nodes = [_w.darkness]
		"room": nodes = [_w.room]
		"enemies", "enemy_draw": nodes = get_tree().get_nodes_in_group("enemies")
		"player_draw": nodes = [_w.player]
		"layers":
			for c in _w.get_children():
				if c is CanvasLayer:
					nodes.append(c)
		_:
			for c in _w.get_children() + (_w.room.get_children() if _w.room else []):
				if (c.get_script() and c.get_script().get_global_name() == what) or c.get_class() == what:
					nodes.append(c)
	_note("disabling %d nodes for %s" % [nodes.size(), what])
	for n in nodes:
		if n is CanvasItem or n is CanvasLayer:
			n.visible = false
		if what != "enemy_draw" and what != "player_draw":
			n.process_mode = Node.PROCESS_MODE_DISABLED

func _run() -> void:
	# wait for the run's first room
	for i in 600:
		if _w.room != null and _w.player != null and is_instance_valid(_w.player):
			break
		await get_tree().process_frame
	await _frames(30)
	# close the run's start rune offer, as a player would
	for i in 300:
		var sc: Variant = _w.director.screen if _w.director else null
		if sc is RuneOfferScreen:
			(sc as RuneOfferScreen).take(0)
			break
		if sc is GodChoiceScreen:
			(sc as GodChoiceScreen).take(0)
			break
		await get_tree().process_frame
	await _frames(30)
	var p := _w.player
	p.hp = 1000000.0
	p.scripted = true
	p.fake = { "move_right": true }
	await _frames(60)
	p.fake = {}
	await _frames(30)
	await _shot("perf-start.png")
	var off := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-off="):
			off = a.trim_prefix("--perf-off=")
	if off != "":
		_disable(off)
		await _frames(20)
		await _measure("OFF " + off)
		await _measure("OFF " + off)
		await _shot("perf-off-%s.png" % off)
		get_tree().quit()
		return
	var base := await _measure("everything on")
	if OS.get_cmdline_user_args().has("--perf-shots"):
		# a 3-hit combo per weapon kind, every 2nd frame cropped around the hero,
		# enemies removed and no blink, so the swing itself is what is seen
		for e in get_tree().get_nodes_in_group("enemies"):
			e.remove_from_group("enemies")
			e.queue_free()
		for wid in ["blade", "spear", "blade-up"]:
			p.equip(Weapon.from_dict({ "id": wid.trim_suffix("-left").trim_suffix("-up") }))
			p.fake = { "move_left": wid.ends_with("-left"), "move_right": not wid.ends_with("-left") }
			await _frames(4)
			p.fake = {}
			await _frames(30)
			var strip: Array[Image] = []
			Engine.time_scale = 0.06
			for f in 40:
				p.inv = 0.0
				p.fake = { "strike": f == 0 or f == 13 or f == 26, "move_up": wid.ends_with("-up") }
				await RenderingServer.frame_post_draw
				if true:
					var img := get_viewport().get_texture().get_image()
					var vs := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
					var at := p.get_global_transform_with_canvas().origin * vs
					var r := Rect2i(Vector2i(at) - Vector2i(110, 170), Vector2i(220, 200)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
					var reg := img.get_region(r)
					reg.convert(Image.FORMAT_RGBA8)
					strip.append(reg)
			var cols := 10
			var sheet := Image.create(220 * cols, 200 * ceili(strip.size() / float(cols)), false, Image.FORMAT_RGBA8)
			for i in strip.size():
				sheet.blit_rect(strip[i], Rect2i(Vector2i.ZERO, strip[i].get_size()), Vector2i((i % cols) * 220, (i / cols) * 200))
			Engine.time_scale = 1.0
			sheet.save_png(out_dir.path_join("perf-attack-%s.png" % wid))
			_note("screenshot perf-attack-%s.png" % wid)
		get_tree().quit()
		return
	# subsystem toggles: hide one, measure, show again
	var groups := {
		"vfx (grass, lamps, hits)": [_w.atmosphere.vfx] if _w.atmosphere and _w.atmosphere.vfx else [],
		"atmosphere (air, glow)": [_w.atmosphere],
		"darkness": [_w.darkness],
		"room (terrain, backdrop)": [_w.room],
		"enemies": get_tree().get_nodes_in_group("enemies"),
	}
	for name: String in groups:
		var nodes: Array = groups[name]
		var saved := []
		for n in nodes:
			if is_instance_valid(n) and n is CanvasItem:
				saved.append([n, n.visible, n.process_mode])
				n.visible = false
				n.process_mode = Node.PROCESS_MODE_DISABLED
		var r := await _measure("without " + name)
		_note("    -> saves %.1f ms of frame, %.1f ms of process" % [base.wall - r.wall, base.proc - r.proc])
		for s in saved:
			if is_instance_valid(s[0]):
				s[0].visible = s[1]
				s[0].process_mode = s[2]
	# every direct child of the world and of the room, one at a time
	var each: Array = []
	for c in _w.get_children():
		if c is CanvasItem and c != _w.room:
			each.append(c)
	if _w.atmosphere and _w.atmosphere.vfx:
		for c in _w.atmosphere.vfx.get_children():
			if c is CanvasItem:
				each.append(c)
		if _w.atmosphere.vfx.grass:
			each.append(_w.atmosphere.vfx.grass.get_child(0))
	if OS.get_cmdline_user_args().has("--perf-short"):
		each = each.slice(-8)
	if _w.room:
		for c in _w.room.get_children():
			if c is CanvasItem:
				each.append(c)
	for c in each:
		if not is_instance_valid(c) or not c.visible:
			continue
		var pm: int = c.process_mode
		var on := await _measure("  +%s %s" % [c.get_class(), c.get_script().get_global_name() if c.get_script() else c.name])
		c.visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
		var r := await _measure("  -%s %s" % [c.get_class(), c.get_script().get_global_name() if c.get_script() else c.name])
		_note("    => %s costs %.1f ms frame, %.1f ms process" % [c.get_script().get_global_name() if c.get_script() else c.name, on.wall - r.wall, on.proc - r.proc])
		c.visible = true
		c.process_mode = pm
	# post fx layers
	for c in _w.get_children():
		if c is CanvasLayer:
			_note("canvas layer %s (layer %d) children %d" % [c.name, c.layer, c.get_child_count()])
	await _shot("perf-end.png")
	var f := FileAccess.open(out_dir.path_join("perf-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	_note("DONE")
	get_tree().quit()
