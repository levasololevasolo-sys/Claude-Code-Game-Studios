## Turns a RoomGen layout into floor, walls and one-way platforms, and draws them.
class_name Room
extends Node2D

var layout: Dictionary = {}
## Location look (locations.json "look", art-bible §4.1): colours, parallax
## factors par_far / par_mid, props "ruins" (swamp) or "forest". {} = swamp colours.
var look: Dictionary = {}
var _time: float = 0.0

func _process(dt: float) -> void:
	_time += dt
	if String(look.get("props", "ruins")) == "forest":
		queue_redraw()

func _c(key: String, def: String) -> Color:
	return Color(String(look.get(key, def)))

## Builds collision for the layout.
func build(l: Dictionary) -> void:
	layout = l
	var ground := Tune.f("ground_y")
	var w: float = l.w
	_solid(Rect2(-200, ground, w + 400, 400))
	_solid(Rect2(-200, -2000, 200, 3000))
	_solid(Rect2(w, -2000, 200, 3000))
	# Chunk rooms (room-generation §3.3): solid earth of shafts, ledges and secret pockets.
	for r: Rect2 in l.get("solids", []):
		_solid(r)
	for p: Vector3 in l.plats:
		var body := StaticBody2D.new()
		body.collision_layer = 2
		var shape := CollisionShape2D.new()
		var seg := RectangleShape2D.new()
		seg.size = Vector2(p.z, 16)
		shape.shape = seg
		shape.one_way_collision = true
		shape.position = Vector2(p.x + p.z / 2.0, p.y + 8)
		body.add_child(shape)
		add_child(body)
	queue_redraw()

func _solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)
	add_child(body)

func _draw() -> void:
	if layout.is_empty() or bool(layout.get("base", false)):
		# The base draws its own yard (src/base/base.gd).
		return
	var ground := Tune.f("ground_y")
	var w: float = layout.w
	var forest := String(look.get("props", "ruins")) == "forest"
	if forest:
		_draw_forest_back(ground, w)
	else:
		# far ruins, a quiet backdrop band
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var x := 0.0
		while x < w:
			var bh := rng.randf_range(120, 320)
			draw_rect(Rect2(x, ground - bh, rng.randf_range(60, 140), bh), _c("far", "#16232a"))
			x += rng.randf_range(120, 260)
	draw_rect(Rect2(-200, ground, w + 400, 400), _c("near", "#1f2b2a"))
	draw_line(Vector2(-200, ground), Vector2(w + 200, ground), _c("edge", "#4f6d5c"), 4.0)
	for r: Rect2 in layout.get("solids", []):
		draw_rect(r, _c("solid", "#24302c"))
		if forest:
			# bark: vertical grain of a trunk or a stump wall
			var gx := r.position.x + 8.0
			while gx < r.end.x - 4.0:
				draw_line(Vector2(gx, r.position.y + 6.0), Vector2(gx + 3.0, r.end.y), _c("plat", "#5a4a3a"), 2.0)
				gx += 18.0
		draw_line(r.position, Vector2(r.end.x, r.position.y), _c("edge", "#4f6d5c"), 3.0)
	for p: Vector3 in layout.plats:
		if forest:
			_draw_branch(p)
		else:
			draw_rect(Rect2(p.x, p.y, p.z, 14), _c("plat", "#3a4a45"))
			draw_line(Vector2(p.x, p.y), Vector2(p.x + p.z, p.y), _c("plat_edge", "#7d9a7f"), 3.0)
	if forest:
		_draw_forest_front(ground, w)
	if bool(layout.get("portal", true)):
		draw_rect(Rect2(w - 30, ground - 160, 60, 160), Color("#3d2f4f"))
		draw_rect(Rect2(w - 22, ground - 150, 44, 150), Color("#8a6dd1", 0.6))
	if bool(layout.get("haven", false)):
		# Haven campfire (placeholder).
		var c := Vector2(w * 0.4, ground)
		draw_rect(Rect2(c.x - 40, c.y - 10, 80, 10), Color("#5b4026"))
		for k in 3:
			var fx := c.x + (k - 1) * 18.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 14, c.y - 8), Vector2(fx, c.y - 70 + absf(k - 1) * 22.0), Vector2(fx + 14, c.y - 8)]), Color("#ff9a3c", 0.85))
		draw_circle(c + Vector2(0, -30), 120, Color("#ffb35c", 0.08))
	if bool(layout.get("lair", false)):
		draw_rect(Rect2(-200, ground - 600, w + 400, 600), Color("#2a0e12", 0.25))

# ---------------- Тёмный бор (living-world §3.2, art-bible §4.1) ----------------

## Deterministic 0..1 hash of an integer (background props).
static func _h(i: int, salt: int) -> float:
	var v := (i * 73856093) ^ (salt * 19349663)
	return float(absi(v) % 1000) / 1000.0

func _cam_x() -> float:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	return cam.get_screen_center_position().x if cam else 0.0

## Two parallax rows of pine trunks (far thin, mid thick with eye hollows that blink).
func _draw_forest_back(ground: float, w: float) -> void:
	var cx := _cam_x()
	var top := float(layout.get("top", ground)) - 900.0
	draw_rect(Rect2(-200, top, w + 400, ground - top), _c("sky", "#2e4466"))
	draw_circle(Vector2(cx * 0.9 + 420.0, top + 700.0), 220.0, Color(_c("sky", "#2e4466").lightened(0.12), 0.5))
	for layer in 2:
		var f := float(look.get("par_far" if layer == 0 else "par_mid", 0.0))
		var gap := 150.0 if layer == 0 else 290.0
		var col := _c("far" if layer == 0 else "mid", "#1b2a44")
		var off := cx * f
		var i0 := floori((cx - 1300.0 - off) / gap)
		for i in range(i0, i0 + ceili(2600.0 / gap) + 2):
			var x := i * gap + off + _h(i, layer) * gap * 0.6
			var tw := (18.0 + _h(i, 9 + layer) * 26.0) * (1.0 if layer == 0 else 2.4)
			draw_rect(Rect2(x - tw / 2.0, top, tw, ground - top), col)
			# pine branches
			for b in 4:
				var by := ground - 160.0 - b * 130.0 - _h(i, b) * 60.0
				var side := -1.0 if (i + b) % 2 == 0 else 1.0
				draw_line(Vector2(x, by), Vector2(x + side * tw * 2.2, by + 26.0), col, 4.0 if layer == 0 else 7.0)
			if layer == 1 and _h(i, 31) < 0.45:
				# a hollow with one eye; blinks now and then (story-bible §2.2)
				var ey := ground - 220.0 - _h(i, 41) * 260.0
				draw_colored_polygon(_oval(Vector2(x, ey), tw * 0.22, 20.0), Color(0.02, 0.03, 0.05))
				var blink := fmod(_time + _h(i, 51) * 7.0, 5.0) < 0.18
				if not blink:
					draw_circle(Vector2(x, ey), 9.0, Color(_c("accent", "#ff8a3d"), 0.25))
					draw_circle(Vector2(x, ey), 3.5, _c("accent", "#ff8a3d"))

## Falling needles, roots on the floor and fireflies.
func _draw_forest_front(ground: float, w: float) -> void:
	var cx := _cam_x()
	var needle := _c("plat_edge", "#8a7254")
	for i in 46:
		var x := cx - 900.0 + _h(i, 3) * 1800.0 + sin(_time * 0.7 + i) * 30.0
		var y := ground - 900.0 + fmod(_time * (40.0 + _h(i, 4) * 50.0) + _h(i, 5) * 900.0, 900.0)
		draw_line(Vector2(x, y), Vector2(x + 5.0, y + 7.0), Color(needle, 0.55), 1.5)
	var x0 := 0.0
	var k := 0
	while x0 < w:
		var rx := x0 + _h(k, 6) * 120.0
		draw_arc(Vector2(rx, ground + 6.0), 22.0 + _h(k, 7) * 20.0, PI, TAU, 10, _c("edge", "#5a4a3a"), 4.0)
		x0 += 180.0
		k += 1
	for i in 12:
		var fx := cx - 700.0 + _h(i, 8) * 1400.0 + sin(_time * 0.9 + i * 2.0) * 40.0
		var fy := ground - 60.0 - _h(i, 10) * 380.0 + cos(_time * 1.3 + i) * 20.0
		var a := 0.35 + 0.35 * sin(_time * 3.0 + i)
		draw_circle(Vector2(fx, fy), 6.0, Color(1.0, 0.85, 0.45, a * 0.3))
		draw_circle(Vector2(fx, fy), 2.0, Color(1.0, 0.9, 0.6, a))

## A one-way branch: bark log, a forked tip and needle tufts.
func _draw_branch(p: Vector3) -> void:
	var bark := _c("plat", "#5a4a3a")
	draw_rect(Rect2(p.x, p.y, p.z, 12), bark)
	draw_line(Vector2(p.x, p.y), Vector2(p.x + p.z, p.y), _c("plat_edge", "#8a7254"), 3.0)
	draw_line(Vector2(p.x + p.z, p.y + 6.0), Vector2(p.x + p.z + 22.0, p.y - 8.0), bark, 4.0)
	var n := int(p.z / 50.0)
	for i in n:
		var tx := p.x + 20.0 + i * 50.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 14.0, p.y + 12.0), Vector2(tx, p.y + 26.0), Vector2(tx + 14.0, p.y + 12.0)]), Color("#1f3a2e"))

static func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
