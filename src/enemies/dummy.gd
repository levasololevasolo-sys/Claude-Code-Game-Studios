## A straw idol that takes hits, flies back, falls and stands again.
## Stand-in for real enemies while the core is checked. Origin at the feet.
class_name StrawDummy
extends Node2D

## Hit box width and height in px (origin at the feet).
var w: float = 40.0
var h: float = 70.0
## True for flying enemies (no air bonus, no launch). Dummies never fly.
var flies: bool = false
var dead: bool = false
var hp: float = 60.0
var max_hp: float = 60.0
var vel: Vector2 = Vector2.ZERO
var flash: float = 0.0
## The Main scene (hitstop owner). Set by whoever spawns the dummy.
var world: Main
var numbers: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("enemies")
	max_hp = Tune.f("dummy_hp")
	hp = max_hp

## Takes damage and a push away from from_x.
func hurt(dmg: float, from_x: float, kb: float) -> void:
	hp -= dmg
	flash = 0.12
	vel.x = signf(position.x - from_x) * kb * Tune.f("dummy_knockback_mult") if position.x != from_x else 0.0
	numbers.append({ "v": roundi(dmg), "t": 0.7, "x": randf_range(-10, 10) })
	if hp <= 0.0:
		hp = max_hp

## Throws the dummy upward (up strike).
func launch(speed: float) -> void:
	vel.y = -speed

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	var ground := Tune.f("ground_y")
	vel.y = minf(vel.y + Tune.f("gravity") * dt, Tune.f("max_fall"))
	position += vel * dt
	if position.y >= ground:
		position.y = ground
		vel.y = 0.0
	vel.x *= pow(Tune.f("dummy_drag"), dt)
	flash -= dt
	for n: Dictionary in numbers:
		n.t -= dt
	numbers.assign(numbers.filter(func(n: Dictionary) -> bool: return n.t > 0.0))
	queue_redraw()

func _draw() -> void:
	var c := Color("#c9a45a") if flash <= 0.0 else Color.WHITE
	draw_line(Vector2(0, 0), Vector2(0, -h), Color("#5b4026"), 5.0)
	draw_line(Vector2(-22, -h * 0.68), Vector2(22, -h * 0.68), Color("#5b4026"), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -h * 0.25), Vector2(-11, -h * 0.8), Vector2(11, -h * 0.8), Vector2(14, -h * 0.25)]), c)
	draw_circle(Vector2(0, -h * 0.88), 10.0, c)
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(-22, -h - 18, 44, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-22, -h - 18, 44 * hp / max_hp, 5), Color("#e05a4a"))
	for n: Dictionary in numbers:
		draw_string(font, Vector2(n.x - 8, -h - 26 - (0.7 - n.t) * 60.0), str(n.v), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.5, n.t / 0.7))
