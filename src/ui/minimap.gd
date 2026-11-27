## Minimap (top right, x 1536-1856, y 156-336 on 1920x1080; GDD level-structure
## §3.6, design/ux/hud.md) and the full map (`full`: the whole screen, the game
## paused, depth bands labelled, the list of what is still open). Display only:
## reads a LevelMap and the hero's position from its LevelFlow, never changes them
## (the full map closes itself on `map` / Esc / pad B; the wheel or triggers zoom).
class_name Minimap
extends Control

var map: LevelMap
var flow: LevelFlow
var full: bool = false
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO

const BAND_FILL: Array = ["#4f6d5c", "#5e5438", "#4a2d55"]
const BAND_NAME: Array = ["поверхность", "под корнями", "глубь"]
const FRAME: Color = Color("#b08a4a")
const BG: Color = Color("#0d1210")

func _lv(key: String, def: Variant) -> Variant:
	return (Tune.data.get("level", {}) as Dictionary).get(key, def)

func _ready() -> void:
	if full:
		process_mode = Node.PROCESS_MODE_ALWAYS
		position = Vector2.ZERO
		size = Vector2(1920, 1080)
		get_tree().paused = true
		var au := get_node_or_null("/root/Audio")
		if au:
			au.call("play", &"map_open")
	else:
		var sz: Array = _lv("minimap_size", [320, 180])
		size = Vector2(float(sz[0]), float(sz[1]))
		position = Vector2(1856.0 - size.x, 156.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if not full else Control.MOUSE_FILTER_STOP

func _process(_dt: float) -> void:
	queue_redraw()

func _input(ev: InputEvent) -> void:
	if not full:
		return
	if ev.is_action_pressed(&"map") or ev.is_action_pressed(&"ui_cancel") or PauseMenu.is_open_event(ev) \
			or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		close()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(3.0, zoom * 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(0.4, zoom / 1.15)
	elif ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pan += (ev as InputEventMouseMotion).relative
	elif ev is InputEventJoypadMotion:
		var jm := ev as InputEventJoypadMotion
		if jm.axis == JOY_AXIS_TRIGGER_RIGHT and jm.axis_value > 0.5:
			zoom = minf(3.0, zoom * 1.05)
		elif jm.axis == JOY_AXIS_TRIGGER_LEFT and jm.axis_value > 0.5:
			zoom = maxf(0.4, zoom / 1.05)

## Closes the full map and unpauses.
func close() -> void:
	get_tree().paused = false
	queue_free()

## Hero position in module units (level top-left = 0,0).
func _hero_m() -> Vector2:
	if flow == null or flow.world == null or flow.world.player == null or not is_instance_valid(flow.world.player):
		return Vector2.ZERO
	var lr := flow.lr
	return (flow.world.player.position - Vector2(0, 30)) / Vector2(lr.cell * lr.mw, lr.cell * lr.mh)

func _draw() -> void:
	if map == null:
		return
	var level := map.level
	var px := float(_lv("minimap_px_per_module", 10))
	var alpha := float(_lv("minimap_alpha", 0.85))
	var hero := _hero_m()
	var origin: Vector2
	if full:
		px = minf(1700.0 / float(level.mcols), 900.0 / float(level.mrows)) * zoom
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.92))
		origin = Vector2(960, 560) - Vector2(float(level.mcols), float(level.mrows)) * px / 2.0 + pan
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(BG, alpha))
		origin = size / 2.0 - hero * px
	var clip := Rect2(Vector2.ZERO, size)
	var rooms: Array = level.rooms
	# Band labels on the full map.
	if full:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, 70), "Карта уровня", HORIZONTAL_ALIGNMENT_CENTER, 1920, 44, Color("#f0e2c0"))
		var band_top := [1000000.0, 1000000.0, 1000000.0]
		for r: Dictionary in rooms:
			if map.state(int(r.i)) != "hidden":
				band_top[int(r.band)] = minf(band_top[int(r.band)], float(r.y))
		for b in 3:
			if band_top[b] < 999999.0:
				var y: float = origin.y + band_top[b] * px
				draw_line(Vector2(60, y), Vector2(1860, y), Color(1, 1, 1, 0.12), 1.0)
				draw_string(font, Vector2(70, y + 26), BAND_NAME[b], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(String(BAND_FILL[b])).lightened(0.4))
	for r: Dictionary in rooms:
		var st := map.state(int(r.i))
		if st == "hidden":
			continue
		var rect := Rect2(origin + Vector2(float(r.x), float(r.y)) * px, Vector2(float(r.w), float(r.h)) * px).grow(-1.0)
		if not full and not clip.intersects(rect):
			continue
		var col := Color(String(BAND_FILL[int(r.band)]))
		if st == "visited":
			draw_rect(rect, Color(col, 0.9))
			draw_rect(rect, Color(col.lightened(0.35), 1.0), false, 1.5)
		else:
			draw_rect(rect, Color(0.8, 0.8, 0.75, 0.7), false, 1.5)
			draw_string(ThemeDB.fallback_font, rect.get_center() + Vector2(-px * 0.25, px * 0.3), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10.0, px * 0.9)), Color(0.9, 0.9, 0.85, 0.85))
		if map.closed.has(int(r.i)):
			draw_line(rect.position, rect.end, Color(0.55, 0.55, 0.55, 0.9), 2.0)
			draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), Color(0.55, 0.55, 0.55, 0.9), 2.0)
	var isz := 12.0 if not full else clampf(px * 0.5, 12.0, 26.0)
	for ic: Dictionary in map.icons():
		var p: Vector2 = origin + (ic.at as Vector2) * px
		if not full and not clip.grow(-4.0).has_point(p):
			continue
		_icon(String(ic.kind), p, isz, bool(ic.grey), ic.info)
	# Hero: a white triangle pointing where he looks.
	var hp := origin + hero * px
	var face := float(flow.world.player.face) if flow and flow.world and flow.world.player and is_instance_valid(flow.world.player) else 1.0
	draw_colored_polygon(PackedVector2Array([hp + Vector2(7 * face, 0), hp + Vector2(-5 * face, -6), hp + Vector2(-5 * face, 6)]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), FRAME, false, 3.0 if not full else 0.0)
	if full:
		_legend()

func _icon(kind: String, p: Vector2, s: float, grey: bool, info: Dictionary) -> void:
	match kind:
		"fork":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 0.6), p + Vector2(s * 0.6, 0), p + Vector2(0, s * 0.6), p + Vector2(-s * 0.6, 0)]), Color("#7fd0ff"))
			if not info.is_empty():
				GodGlyph.door_icon(self, String(info.get("type", "")), String(info.get("god", "")), p + Vector2(s, -s), s * 0.5, Color.WHITE)
		"shrine":
			draw_circle(p, s * 0.55, Color("#606060") if grey else Color("#f0c060"))
			draw_circle(p, s * 0.3, Color("#1a1410"))
		"chest":
			draw_rect(Rect2(p - Vector2(s, s) * 0.35, Vector2(s, s) * 0.7), Color("#e8c060"))
		"wall":
			draw_polyline(PackedVector2Array([p + Vector2(-s * 0.3, -s * 0.5), p + Vector2(s * 0.2, -s * 0.1), p + Vector2(-s * 0.2, s * 0.2), p + Vector2(s * 0.3, s * 0.5)]), Color("#c9b38a"), 2.0)
		"spring":
			draw_circle(p + Vector2(0, s * 0.15), s * 0.35, Color.WHITE)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.3, s * 0.05), p + Vector2(0, -s * 0.55), p + Vector2(s * 0.3, s * 0.05)]), Color.WHITE)
		"lair":
			draw_circle(p, s * 0.6, Color("#d03030"))
			draw_circle(p, s * 0.3, Color("#2a0808"))

func _legend() -> void:
	var font := ThemeDB.fallback_font
	var chests := 0
	var passes := 0
	for ic: Dictionary in map.icons():
		if String(ic.kind) == "chest":
			chests += 1
	passes = map.seen.size()
	var lines := PackedStringArray(["Не открыто:", "сундуков: %d" % chests, "замеченных проходов: %d" % passes,
		"", "M / удержание View, Esc или B — закрыть", "колесо или курки — масштаб, мышь — сдвиг"])
	for i in lines.size():
		draw_string(font, Vector2(70, 900 + i * 28), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.85, 0.8))
