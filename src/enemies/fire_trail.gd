## A patch of the fire trail of a «Пламя» elite (enemies-and-elites §3.6): burns
## fire_trail_time s and hurts the hero standing in it fire_trail_dmg every fire_trail_tick s.
class_name FireTrail
extends Node2D

var world: World
var life: float = 0.0
var _tick: float = 0.0
var dmg_mult: float = 1.0

func _ready() -> void:
	life = Tune.f("fire_trail_time")

func _physics_process(dt: float) -> void:
	life -= dt
	_tick -= dt
	if life <= 0.0:
		queue_free()
		return
	var p := world.player if world else null
	if _tick <= 0.0 and p and is_instance_valid(p) and not p.dead:
		var half := Tune.f("fire_trail_w") / 2.0
		if absf(p.position.x - position.x) < half + Player.W / 2.0 and p.position.y > position.y - 30.0 and p.position.y < position.y + 10.0:
			var hit := Hit.make(Hit.Kind.CONTACT, Tune.f("fire_trail_dmg") * dmg_mult, position.x, 0.0)
			p.hurt(hit)
			_tick = Tune.f("fire_trail_tick")
	queue_redraw()

func _draw() -> void:
	var k := clampf(life / Tune.f("fire_trail_time"), 0.0, 1.0)
	var half := Tune.f("fire_trail_w") / 2.0
	draw_rect(Rect2(-half, -6, half * 2.0, 6), Color(1.0, 0.45, 0.1, 0.5 * k + 0.2))
	for i in 3:
		var fx := -half + 8 + i * (half - 8)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 7, -4), Vector2(fx, -22 * k - 6 - sin(life * 9.0 + i) * 4), Vector2(fx + 7, -4)]), Color(1.0, 0.6, 0.15, 0.8 * k))
