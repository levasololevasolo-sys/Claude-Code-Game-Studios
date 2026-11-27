## Turns a RoomGen layout into floor, walls and one-way platforms, and draws them.
class_name Room
extends Node2D

var layout: Dictionary = {}
## Location look (locations.json "look", art-bible §4.1): colours, parallax
## factors par_far / par_mid, props "ruins" (swamp), "forest" or "frost". {} = swamp colours.
var look: Dictionary = {}
## The visuals.json style of this room (Backdrop layers, TerrainArt colours).
var vis: Dictionary = {}

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
	if not bool(l.get("base", false)):
		# Visual layers (visual-upgrade-plan §2.1, §2.2); collision above is untouched.
		var bd := Backdrop.new()
		add_child(bd)
		bd.build(vis, ground, float(l.get("top", ground)) - 900.0)
		var ta := TerrainArt.new()
		ta.layout = l
		ta.t = vis.get("terrain", {})
		ta.ground = ground
		add_child(ta)
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
	# Ground, solids and platforms: TerrainArt; background: Backdrop (children).
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

# ---------------- helpers (also used by BackdropPainter, TerrainArt) ----------------

## Deterministic 0..1 hash of an integer (background props).
static func _h(i: int, salt: int) -> float:
	var v := (i * 73856093) ^ (salt * 19349663)
	return float(absi(v) % 1000) / 1000.0

static func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
