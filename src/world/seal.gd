## A seal (печать) of a seal room (GDD artifacts-and-secrets §3.3-3.4): visible
## from the start, impossible to open until the hero owns its artifact (all of
## them arrive on the first full clear). Stands on the Z mark. Locked: E shows
## the riddle `hint` for a moment and a dull knock, nothing else. With the
## artifact E opens it by the artifact's `open`:
## - fade / vanish / door: the X barrier cells stop being solid (melt, burst,
##   or slide up 4 cells);
## - pull: a rope to the O hook, the hero is pulled to the standing cell next to
##   it (every press pulls again after the first opening);
## - build: the W cells become one-way bridges one by one from the seal.
## Placeholder look per seal kind (artifacts.json seals[kind].shape).
class_name Seal
extends Node2D

signal opened(seal: Seal)

var world: World
## Seal kind id (artifacts.json seal, e.g. "moroc").
var kind: String = ""
## Level cell size, px.
var cell: float = 40.0
## Barrier cells (X) and future-bridge cells (W), level cells.
var x_cells: Array = []
var w_cells: Array = []
## Hook point (O) and the landing floor point next to it (world px); hook only.
var hook: Vector2 = Vector2.ZERO
var land: Vector2 = Vector2.ZERO
## Injected for tests: the save meta and the artifacts table.
var meta: MetaState
var tbl: Dictionary = {}
var is_open: bool = false
var near: bool = false
## Seconds the locked hint stays up.
var hint_t: float = 0.0
## Seconds since the opening effect started (-1 = none).
var anim: float = -1.0
var _t: float = 0.0
var _bar: StaticBody2D
var _bridge: StaticBody2D
var _pull_from: Vector2 = Vector2.ZERO
var _built: int = 0

func _ready() -> void:
	z_index = -2
	if not x_cells.is_empty():
		_bar = StaticBody2D.new()
		_bar.collision_layer = 1
		for c: Vector2i in x_cells:
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(cell, cell)
			shape.shape = rect
			shape.position = _local(c) + Vector2(cell, cell) * 0.5
			_bar.add_child(shape)
		add_child(_bar)

func _local(c: Vector2i) -> Vector2:
	return Vector2(c.x * cell, c.y * cell) - position

## The artifact row that opens this seal ({} when none).
func artifact() -> Dictionary:
	return Artifacts.for_seal(tbl, kind)

func _look() -> Dictionary:
	return (tbl.get("seals", {}) as Dictionary).get(kind, {})

func _times(key: String, def: float) -> float:
	return float((tbl.get("times", {}) as Dictionary).get(key, def))

## How it opens: fade, vanish, door, pull or build.
func open_mode() -> String:
	return String(artifact().get("open", "vanish"))

## True when the hero may open (or, for an opened hook, use) it now.
func can_open() -> bool:
	return Artifacts.can_open(meta, tbl, kind) and (not is_open or open_mode() == "pull")

## The line over the seal: the action with the artifact, else "?" (the riddle
## shows only after a press).
func prompt() -> String:
	if anim >= 0.0:
		return ""
	if Artifacts.can_open(meta, tbl, kind):
		if is_open and open_mode() != "pull":
			return ""
		return "E — %s (%s)" % [String(_look().get("verb", "открыть")), String(artifact().get("name", ""))]
	return String(artifact().get("hint", "Заперто")) if hint_t > 0.0 else "?"

func _physics_process(dt: float) -> void:
	_t += dt
	hint_t -= dt
	var p := world.player if world else null
	var ok := p != null and is_instance_valid(p) and not p.dead
	near = ok and p.position.distance_to(position) < _times("reach", 60.0) + 40.0
	if near and anim < 0.0 and not p.scripted and Input.is_action_just_pressed(&"interact"):
		press()
	if anim >= 0.0:
		anim += dt
		_tick_anim(p if ok else null)
	queue_redraw()

## The interact press: opens with the artifact, else shows the hint (true when it opened).
func press() -> bool:
	if not can_open():
		hint_t = _times("hint", 2.4)
		var au := get_node_or_null("/root/Audio")
		if au and au.has_method("play"):
			au.call("play", &"ui_locked")
		return false
	var first := not is_open
	is_open = true
	anim = 0.0
	var p := world.player if world else null
	if p != null and is_instance_valid(p):
		_pull_from = p.position
	match open_mode():
		"fade", "vanish", "door":
			if _bar:
				_bar.queue_free()
				_bar = null
	if world:
		world.add_ring(position + Vector2(0, -40), 90.0)
		world.add_shake(4.0 if open_mode() == "door" else 2.0)
	if first:
		opened.emit(self)
	return true

func _tick_anim(p: Player) -> void:
	match open_mode():
		"pull":
			var rope := _times("pull_rope", 0.2)
			var dur := _times("pull", 0.5)
			if p:
				p.velocity = Vector2.ZERO
				if anim < rope:
					p.position = _pull_from
				else:
					var k := clampf((anim - rope) / dur, 0.0, 1.0)
					var e := k * k * (3.0 - 2.0 * k)
					p.position = _pull_from.lerp(land, e) + Vector2(0, -sin(k * PI) * 50.0)
			if anim >= rope + _times("pull", 0.5):
				if p:
					p.position = land
				anim = -1.0
		"build":
			var n := int(anim / _times("build_cell", 0.05))
			while _built < mini(n, w_cells.size()):
				_add_bridge(_order_w()[_built])
				_built += 1
			if _built >= w_cells.size():
				anim = -1.0
		"door":
			if anim >= _times("door", 0.8):
				anim = -1.0
		"fade":
			if anim >= _times("fade", 0.6):
				anim = -1.0
		_:
			if anim >= _times("vanish", 0.5):
				anim = -1.0

## W cells nearest to the seal first.
func _order_w() -> Array:
	var arr := w_cells.duplicate()
	var me := position
	arr.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a.x * cell, a.y * cell).distance_to(me) < Vector2(b.x * cell, b.y * cell).distance_to(me))
	return arr

func _add_bridge(c: Vector2i) -> void:
	if _bridge == null:
		_bridge = StaticBody2D.new()
		_bridge.collision_layer = 2
		add_child(_bridge)
	var shape := CollisionShape2D.new()
	var seg := RectangleShape2D.new()
	seg.size = Vector2(cell, 16)
	shape.shape = seg
	shape.one_way_collision = true
	shape.position = _local(c) + Vector2(cell * 0.5, 8)
	_bridge.add_child(shape)

func _col() -> Color:
	return Color(String(artifact().get("color", "#c9a24a")))

func _draw() -> void:
	var c := _col()
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	var mode := open_mode()
	# The barrier.
	if not x_cells.is_empty():
		var k := 1.0
		var dy := 0.0
		if is_open:
			var tt := _times(mode, 0.6)
			k = 0.0 if anim < 0.0 else 1.0 - clampf(anim / tt, 0.0, 1.0)
			if mode == "door":
				dy = -4.0 * cell * (1.0 - k)
				k = 1.0 if anim >= 0.0 else 0.0
		if k > 0.0:
			for xc: Vector2i in x_cells:
				_draw_bar_cell(_local(xc) + Vector2(0, dy), c, pulse, k)
	# Bridges built so far (red thread / branches).
	var order := _order_w() if _built > 0 else []
	for i in _built:
		var wc: Vector2i = order[i]
		var q := _local(wc)
		if String(_look().get("shape", "")) == "wall":
			draw_rect(Rect2(q + Vector2(0, 2), Vector2(cell, 10)), Color("#5a4428"))
			draw_line(q + Vector2(4, 4), q + Vector2(cell - 6, 0), Color("#8fbf6a"), 3.0)
		else:
			draw_line(q + Vector2(0, 4), q + Vector2(cell, 4), c, 4.0)
			draw_line(q + Vector2(0, 8), q + Vector2(cell, 8), c.darkened(0.3), 2.0)
	# Faint outline of the bridge to come while locked.
	if _built == 0 and not w_cells.is_empty():
		for wc: Vector2i in w_cells:
			draw_line(_local(wc) + Vector2(4, 6), _local(wc) + Vector2(cell - 4, 6), Color(c, 0.12 + 0.1 * pulse), 2.0)
	# Hook.
	if mode == "pull":
		var hp := hook - position
		draw_circle(hp, 24.0, Color(c, 0.08 + 0.1 * pulse))
		draw_arc(hp + Vector2(0, 4), 11.0, 0.0, TAU, 18, c, 4.0)
		draw_line(hp + Vector2(0, -8), hp + Vector2(0, -24), c.darkened(0.3), 5.0)
		if anim >= 0.0 and world and world.player:
			draw_line(world.player.position - position + Vector2(0, -40), hp + Vector2(0, 8), Color("#b89a6a"), 3.0)
	# The seal mark on the floor (Z): a glowing sign.
	var a := 0.35 if not Artifacts.can_open(meta, tbl, kind) else 0.75
	var s := Vector2(0, -50)
	draw_colored_polygon(PackedVector2Array([s + Vector2(0, -14), s + Vector2(10, 0), s + Vector2(0, 14), s + Vector2(-10, 0)]), Color(c, a * (0.6 + 0.4 * pulse)))
	if near:
		var txt := prompt()
		if txt != "":
			draw_string(ThemeDB.fallback_font, Vector2(-220, -90), txt, HORIZONTAL_ALIGNMENT_CENTER, 440, 18, Color(1, 0.95, 0.82, 0.95))

func _draw_bar_cell(q: Vector2, c: Color, pulse: float, k: float) -> void:
	var r := Rect2(q, Vector2(cell, cell))
	match String(_look().get("shape", "door")):
		"rock":
			draw_rect(r, Color(Color("#26302b"), k))
			draw_rect(r, Color(c, 0.06 + 0.06 * pulse * k))
		"water":
			draw_rect(r, Color(Color("#0d2a2c"), 0.85 * k))
			draw_line(r.position + Vector2(4, 10 + 6 * pulse), r.position + Vector2(cell - 4, 10 + 6 * pulse), Color(c, 0.4 * k), 2.0)
		"stone":
			draw_rect(r, Color(Color("#3a3a34"), k))
			draw_line(r.position + Vector2(8, 8), r.position + Vector2(cell - 10, cell - 12), Color(Color("#7de36b"), 0.5 * pulse * k), 2.0)
		"thorn":
			draw_rect(r, Color(Color("#2a2015"), 0.6 * k))
			for i in 3:
				draw_line(r.position + Vector2(4 + i * 12, cell), r.position + Vector2(10 + i * 10, 4), Color(Color("#6a5230"), k), 3.0)
		"eye":
			draw_rect(r, Color(Color("#2c2418"), k))
			draw_circle(r.get_center(), 9.0, Color(c, 0.5 * k))
			draw_circle(r.get_center(), 4.0, Color(0, 0, 0, k))
		"chain":
			draw_rect(r, Color(Color("#1c1a16"), 0.7 * k))
			draw_arc(r.get_center(), 12.0, 0.0, TAU, 14, Color(Color("#8a8a80"), k), 4.0)
		"ice":
			draw_rect(r, Color(Color("#a8d8f0"), 0.55 * k))
			draw_line(r.position + Vector2(6, 4), r.position + Vector2(16, 30), Color(1, 1, 1, 0.5 * k), 2.0)
		_:
			draw_rect(r, Color(Color("#3a2a1c"), k))
			draw_rect(r, Color(c, 0.6 * k), false, 2.0)
