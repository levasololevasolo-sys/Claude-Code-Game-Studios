## Turns a RoomGen layout into floor, walls and one-way platforms, and draws them.
class_name Room
extends Node2D

var layout: Dictionary = {}

## Builds collision for the layout.
func build(l: Dictionary) -> void:
	layout = l
	var ground := Tune.f("ground_y")
	var w: float = l.w
	_solid(Rect2(-200, ground, w + 400, 400))
	_solid(Rect2(-200, -2000, 200, 3000))
	_solid(Rect2(w, -2000, 200, 3000))
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
	if layout.is_empty():
		return
	var ground := Tune.f("ground_y")
	var w: float = layout.w
	# far ruins, a quiet backdrop band
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := 0.0
	while x < w:
		var bh := rng.randf_range(120, 320)
		draw_rect(Rect2(x, ground - bh, rng.randf_range(60, 140), bh), Color("#16232a"))
		x += rng.randf_range(120, 260)
	draw_rect(Rect2(-200, ground, w + 400, 400), Color("#1f2b2a"))
	draw_line(Vector2(-200, ground), Vector2(w + 200, ground), Color("#4f6d5c"), 4.0)
	for p: Vector3 in layout.plats:
		draw_rect(Rect2(p.x, p.y, p.z, 14), Color("#3a4a45"))
		draw_line(Vector2(p.x, p.y), Vector2(p.x + p.z, p.y), Color("#7d9a7f"), 3.0)
	draw_rect(Rect2(w - 30, ground - 160, 60, 160), Color("#3d2f4f"))
	draw_rect(Rect2(w - 22, ground - 150, 44, 150), Color("#8a6dd1", 0.6))
