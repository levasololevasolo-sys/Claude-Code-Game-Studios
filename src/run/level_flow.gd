## The live side of a graph-mode level (GDD level-structure §3.1, §3.5-3.6):
## fork gates (Door signs on the G markers), roots that close the other gates
## once the hero is gate_seal_cells past one, reward shrines on the H markers of
## the shrine rooms, the lair door on L, the map state (LevelMap) with the
## minimap and the full map, darkness by depth band and the shaft camera.
## Owns no reward rules: it reports to the RunDirector through signals, and the
## director sets the gates' infos (DoorRules) and gives the rewards.
class_name LevelFlow
extends Node2D

## The hero reached shrine `s` (index in level.shrines) and its rooms are clear.
signal shrine_reached(s: int)
## The hero went gate_seal_cells past gate `trail` of fork `fork` (0-based).
signal gate_entered(fork: int, trail: int)
## The hero stepped into fork room `fork` (0-based).
signal fork_entered(fork: int)
## The hero pressed interact at the lair door.
signal lair_used

var world: World
var lr: LevelRoom
var level: Dictionary = {}
var map: LevelMap
## Per fork: {room, gates: [{door, sock, trail, rooms, cells}], chosen (-1)}.
var forks: Array = []
## Per shrine: {room, pos, node, rooms (that must be clear)}.
var shrines: Array = []
var lair_door: Door
var lair_pos: Vector2 = Vector2.ZERO
var minimap: Minimap
var cur_room: int = -1
var _cam_margins: Vector2 = Vector2.ZERO
var _base_dark: float = -1.0
var _map_hold: float = 0.0
var _full: Minimap

func _lv(key: String, def: Variant) -> Variant:
	return (Tune.data.get("level", {}) as Dictionary).get(key, def)

## Builds gates, shrines, the lair door and the minimap for `world`'s LevelRoom.
func setup(p_world: World) -> void:
	world = p_world
	lr = world.level_room
	level = lr.level
	map = LevelMap.new(level)
	var rooms: Array = level.rooms
	var marks_by_room := {}
	for m: Dictionary in level.marks:
		var ri := int(m.room)
		if not marks_by_room.has(ri):
			marks_by_room[ri] = []
		(marks_by_room[ri] as Array).append(m)
	for f: Dictionary in level.forks:
		var fr := int(f.room)
		var gs: Array = []
		var free_g: Array = []
		for m: Dictionary in marks_by_room.get(fr, []):
			if String(m.ch) == "G":
				free_g.append(m.c)
		for ti in (f.trails as Array).size():
			var tr: Dictionary = f.trails[ti]
			var cells := _sock_cells(rooms[fr], String(tr.sock))
			var mid := Vector2.ZERO
			for c: Vector2i in cells:
				mid += Vector2(c)
			mid /= maxf(1.0, cells.size())
			var best := -1
			for gi in free_g.size():
				if best < 0 or Vector2(free_g[gi]).distance_to(mid) < Vector2(free_g[best]).distance_to(mid):
					best = gi
			var at := lr.cell_floor(Vector2i(mid.round()))
			if best >= 0:
				at = lr.cell_floor(free_g[best])
				free_g.remove_at(best)
			var d := Door.new()
			d.active = false
			d.position = at
			d.scale = Vector2.ONE * 0.8
			add_child(d)
			gs.append({ "door": d, "sock": String(tr.sock), "trail": ti, "rooms": tr.rooms, "cells": cells, "info": {} })
		forks.append({ "room": fr, "gates": gs, "chosen": -1 })
	var sh: Array = level.shrines
	for si in sh.size():
		var ri := int(sh[si])
		var pos := lr.cell_floor(Vector2i(int(rooms[ri].x) * lr.mw + 8, int(rooms[ri].y) * lr.mh + 7))
		for m: Dictionary in marks_by_room.get(ri, []):
			if String(m.ch) == "H":
				pos = lr.cell_floor(m.c)
		var must: Array = []
		if si == 0:
			for r: Dictionary in rooms:
				if int(r.sec) == 0 and String(r.path) == "main":
					must.append(int(r.i))
		else:
			for f: Dictionary in level.forks:
				for tr: Dictionary in f.trails:
					if int(tr.shrine) == ri:
						must = (tr.rooms as Array).duplicate()
		var node := Shrine.new()
		node.position = pos
		add_child(node)
		shrines.append({ "room": ri, "pos": pos, "node": node, "rooms": must, "taken": false })
	var lg := int(level.lairgate)
	for m: Dictionary in marks_by_room.get(lg, []):
		if String(m.ch) == "L":
			lair_pos = lr.cell_floor(m.c)
		elif String(m.ch) == "H":
			var spring := Shrine.new()
			spring.spring = true
			spring.position = lr.cell_floor(m.c)
			add_child(spring)
	lair_door = Door.new()
	lair_door.info = { "type": "lair", "god": "", "arg": String((Tune.table("locations").get(str(world.tier), {}) as Dictionary).get("boss_name", "")) }
	lair_door.position = lair_pos
	add_child(lair_door)
	var layer := CanvasLayer.new()
	layer.layer = PostFx.LAYER + 2
	minimap = Minimap.new()
	minimap.map = map
	minimap.flow = self
	layer.add_child(minimap)
	add_child(layer)
	if world.darkness:
		_base_dark = world.darkness.base
	if world.cam:
		_cam_margins = Vector2(world.cam.drag_top_margin, world.cam.drag_bottom_margin)
	_update_room()

## Level cells of socket `s` of a LevelGen room dictionary.
func _sock_cells(r: Dictionary, s: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var k := int(s.substr(1))
	var rx := int(r.x) * lr.mw
	var ry := int(r.y) * lr.mh
	match s[0]:
		"L":
			for y in range(k * lr.mh + 4, k * lr.mh + 8):
				out.append(Vector2i(rx, ry + y))
		"R":
			for y in range(k * lr.mh + 4, k * lr.mh + 8):
				out.append(Vector2i(rx + int(r.w) * lr.mw - 1, ry + y))
		"T":
			for x in range(k * lr.mw + 6, k * lr.mw + 10):
				out.append(Vector2i(rx + x, ry))
		"B":
			for x in range(k * lr.mw + 6, k * lr.mw + 10):
				out.append(Vector2i(rx + x, ry + int(r.h) * lr.mh - 1))
	return out

## Shows `infos` (DoorRules) over the gates of fork `fi`; the gates open.
func set_gates(fi: int, infos: Array) -> void:
	if fi < 0 or fi >= forks.size():
		return
	var gs: Array = forks[fi].gates
	for i in gs.size():
		var g: Dictionary = gs[i]
		g.info = infos[i] if i < infos.size() else {}
		(g.door as Door).info = g.info
		(g.door as Door).active = forks[fi].chosen < 0
		(g.door as Door).queue_redraw()

## True when fork `fi` has its gate signs.
func gates_set(fi: int) -> bool:
	return fi >= 0 and fi < forks.size() and not (forks[fi].gates[0].info as Dictionary).is_empty()

## Chooses gate `ti` of fork `fi`: roots close the others (physically and on the map).
func choose(fi: int, ti: int) -> void:
	var f: Dictionary = forks[fi]
	if f.chosen >= 0:
		return
	f.chosen = ti
	var closed: Array = []
	for g: Dictionary in f.gates:
		var d := g.door as Door
		if int(g.trail) == ti:
			d.note = "выбрано"
			continue
		d.active = false
		d.note = "заросло корнями"
		d.queue_redraw()
		closed.append_array(g.rooms)
		var roots := Roots.new()
		roots.cells = g.cells
		roots.cell = lr.cell
		roots.grow_time = float(_lv("roots_time", 0.6))
		add_child(roots)
	map.choose(int(f.room), f.gates[ti].info, closed)
	var au := get_node_or_null("/root/Audio")
	if au:
		au.call("play", &"roots_close")
	gate_entered.emit(fi, ti)

## Marks shrine `s` taken (grey on the map, the light goes out).
func take_shrine(s: int) -> void:
	shrines[s].taken = true
	map.taken[int(shrines[s].room)] = true
	(shrines[s].node as Shrine).taken = true
	(shrines[s].node as Shrine).queue_redraw()

## Sets the reward sign of shrine `s` (what its trail promised).
func set_shrine_info(s: int, info: Dictionary) -> void:
	if s >= 0 and s < shrines.size():
		(shrines[s].node as Shrine).info = info
		(shrines[s].node as Shrine).queue_redraw()

func _alive_in(rooms: Array) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.dead or en.prop:
			continue
		if lr.room_at(en.position) in rooms:
			n += 1
	return n

func _update_room() -> void:
	var p := world.player
	if p == null or not is_instance_valid(p):
		return
	var ri := lr.room_at(p.position - Vector2(0, 20))
	if ri == cur_room or ri < 0:
		return
	cur_room = ri
	map.visit(ri)
	var r: Dictionary = level.rooms[ri]
	if world.darkness and _base_dark >= 0.0:
		world.darkness.base = minf(0.97, _base_dark + float(_lv("depth_dark", 0.05)) * int(r.band))
	if world.cam:
		# Shafts read better with half the vertical dead zone (§3.5).
		var k := 0.5 if String(r.kind) == "shaft" else 1.0
		world.cam.drag_top_margin = _cam_margins.x * k
		world.cam.drag_bottom_margin = _cam_margins.y * k
	for fi in forks.size():
		if int(forks[fi].room) == ri:
			fork_entered.emit(fi)

func _physics_process(dt: float) -> void:
	var p := world.player if world else null
	if p == null or not is_instance_valid(p) or p.dead:
		return
	_update_room()
	# The lair is found when its door is on screen (or its room was entered).
	if not map.lair_seen and world.cam:
		var half := get_viewport_rect().size / world.cam.zoom / 2.0
		if Rect2(world.cam.get_screen_center_position() - half, half * 2.0).has_point(lair_pos - Vector2(0, 60)):
			map.see_lair()
	# Gates: gate_seal_cells past a gate's socket inside its trail closes the others.
	var seal := float(_lv("gate_seal_cells", 3)) * lr.cell
	for fi in forks.size():
		var f: Dictionary = forks[fi]
		if int(f.chosen) >= 0 or not gates_set(fi):
			continue
		for g: Dictionary in f.gates:
			if not (cur_room in (g.rooms as Array)):
				continue
			var mid := Vector2.ZERO
			for c: Vector2i in g.cells:
				mid += (Vector2(c) + Vector2(0.5, 0.5)) * lr.cell
			mid /= 4.0
			var d := p.position - Vector2(0, Player.H / 2.0) - mid
			var past := absf(d.x) if String(g.sock)[0] in ["L", "R"] else d.y
			if past >= seal:
				choose(fi, int(g.trail))
				break
	# Shrines give their reward when their rooms hold no living enemy.
	for si in shrines.size():
		var s: Dictionary = shrines[si]
		if bool(s.taken):
			continue
		if absf(p.position.x - (s.pos as Vector2).x) < Tune.f("door_reach") and absf(p.position.y - (s.pos as Vector2).y) < 120.0:
			var alive := _alive_in(s.rooms)
			(s.node as Shrine).blocked = alive > 0
			if alive == 0:
				shrine_reached.emit(si)
	# Lair door.
	var near := absf(p.position.x - lair_pos.x) < Tune.f("door_reach") and absf(p.position.y - lair_pos.y) < 120.0
	if near != lair_door.near:
		lair_door.near = near
		lair_door.queue_redraw()
	if near and not p.scripted and Input.is_action_just_pressed(&"interact"):
		lair_used.emit()
	# Map button: M / hold View (map_hold_time) opens the full map.
	if InputMap.has_action(&"map_pad") and Input.is_action_pressed(&"map_pad"):
		_map_hold += dt
		if _map_hold >= float(_lv("map_hold_time", 0.4)) and _full == null:
			open_full_map()
	else:
		_map_hold = 0.0

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed(&"map") and _full == null and not get_tree().paused:
		get_viewport().set_input_as_handled()
		open_full_map()

## The full map (pauses the game; closes with the same button, Esc or B).
func open_full_map() -> Minimap:
	_full = Minimap.new()
	_full.map = map
	_full.flow = self
	_full.full = true
	world.show_screen(_full, 45)
	_full.tree_exited.connect(func() -> void: _full = null)
	return _full

## A reward shrine / spring marker: an idol with a glow and the promised sign.
class Shrine:
	extends Node2D
	var info: Dictionary = {}
	var taken: bool = false
	var blocked: bool = false
	var spring: bool = false
	var _t: float = 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var col := Color("#9fe0ff") if spring else Color("#f0c060")
		if taken:
			col = Color("#606060")
		var a := 0.5 + 0.2 * sin(_t * 2.5)
		if not taken:
			for i in 5:
				draw_circle(Vector2(0, -70), 90.0 - i * 16.0, Color(col, 0.05 * a * (i + 1)))
		draw_rect(Rect2(-14, -120, 28, 120), Color("#3a2c20"))
		draw_rect(Rect2(-22, -132, 44, 14), Color("#5a4630"))
		draw_circle(Vector2(0, -96), 9.0, Color(col, 0.9))
		draw_rect(Rect2(-36, -8, 72, 8), Color("#2a2018"))
		if not info.is_empty() and not taken:
			var t := String(info.get("type", ""))
			var g := String(info.get("god", ""))
			var ic := Enemy.god_colour(g) if t == "god" and g != "" else col
			GodGlyph.door_icon(self, t, g, Vector2(0, -170), 24.0, ic)
		if blocked and not taken:
			draw_string(ThemeDB.fallback_font, Vector2(-90, -200), "сперва очисти тропу", HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color(1, 0.8, 0.7))

## Roots growing over a closed gate's opening: a solid body and the vines.
class Roots:
	extends Node2D
	var cells: Array[Vector2i] = []
	var cell: float = 40.0
	var grow_time: float = 0.6
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 5
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var r := Rect2()
		for i in cells.size():
			var cr := Rect2(Vector2(cells[i]) * cell, Vector2.ONE * cell)
			r = cr if i == 0 else r.merge(cr)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
		add_child(body)

	func _process(dt: float) -> void:
		if _t < grow_time:
			_t += dt
			queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / maxf(grow_time, 0.01), 0.0, 1.0)
		for i in cells.size():
			var c := Vector2(cells[i]) * cell
			draw_rect(Rect2(c, Vector2.ONE * cell), Color("#2a1e14", k))
			for j in 3:
				var x := c.x + 6.0 + j * 12.0
				draw_line(Vector2(x, c.y + cell), Vector2(x + 6.0 * sin(i + j), c.y + cell - cell * k), Color("#6b4a2a"), 4.0)
