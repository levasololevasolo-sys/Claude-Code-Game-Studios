## A cracked wall on a B mark (GDD room-generation-and-doors §3.10, edge 10):
## any 3 hits (strike, shot, Flare) bring it down and open the secret pocket
## behind it. An Enemy so every hit source finds it, but a `prop`: it never
## wakes, acts, gives embers or counts for the room clear.
class_name BreakableWall
extends Enemy

## Hits taken.
var hits: int = 0
## Emitted when the wall falls.
signal broke(wall: BreakableWall)
var _body: StaticBody2D

func _load_stats() -> void:
	kind_id = "wall"
	prop = true
	stats = { "embers": 0, "color": "#3d4a3f", "eye": "#000000" }
	max_hp = 1.0
	weight = 99.0
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(0, -h / 2.0)
	_body.add_child(shape)
	add_child(_body)

func _behave(_dt: float) -> void:
	pass

func _physics_process(dt: float) -> void:
	flash -= dt
	queue_redraw()

func light_spots() -> Array[Vector4]:
	return []

## Counts a hit; the wall_hits-th one breaks it. No damage numbers, no embers.
func hurt(_hit: Hit) -> float:
	if dead:
		return 0.0
	hits += 1
	flash = Tune.f("enemy_flash_time")
	if world:
		world.add_shake(Tune.f("shake_hit"))
	if hits >= int(Tune.f("wall_hits")):
		dead = true
		remove_from_group("enemies")
		broke.emit(self)
		if world:
			world.add_ring(center(), 80.0)
		queue_free()
	return 0.0

func _draw() -> void:
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	draw_rect(Rect2(-w / 2, -h, w, h), c)
	var crack := Color("#c9b38a", 0.9)
	draw_polyline(PackedVector2Array([Vector2(-6, -h + 10), Vector2(4, -h * 0.7), Vector2(-5, -h * 0.5), Vector2(6, -h * 0.25), Vector2(-2, -6)]), crack, 2.5)
	if hits > 0:
		draw_line(Vector2(4, -h * 0.7), Vector2(14, -h * 0.6), crack, 2.0)
	if hits > 1:
		draw_line(Vector2(-5, -h * 0.5), Vector2(-16, -h * 0.42), crack, 2.0)
