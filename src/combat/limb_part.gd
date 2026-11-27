## A cut part flying off an enemy (GDD limb-zones §3.4): the arm (a harmless
## prop) or the head (a projectile that hurts OTHER enemies until it first
## touches the floor). Placeholder art: a polygon in the enemy's colours, a
## blood spray and a trail of Nav mist. The art pass may replace _draw() or
## put a Sprite2D child here; the motion and damage stay.
class_name LimbPart
extends Node2D

## "arm" or "head".
var limb: String = ""
## Shape in local space (drawn rotated by `ang`).
var poly: PackedVector2Array = PackedVector2Array()
var colour: Color = Color.WHITE
## Eye colour (the head keeps its glow for a moment).
var eye: Color = Color.WHITE
var vel: Vector2 = Vector2.ZERO
var spin: float = 0.0
var ang: float = 0.0
var life: float = 2.5
## Damage to other enemies, before nothing (already scaled by the caller). 0 = harmless.
var dmg: float = 0.0
## Knockback of that hit, px/s.
var kb: float = 0.0
## Hit radius of the projectile, px.
var r: float = 14.0
## The enemy it came from (never hit by its own part).
var source: Node = null
var world: World
## Enemies already hit (once each).
var hit_list: Array = []
## Blood drops and mist puffs: {p: Vector2 (world), v: Vector2, t: float, mist: bool}.
var drops: Array[Dictionary] = []
var _t: float = 0.0
var _trail_t: float = 0.0
var _landed: bool = false

func _ready() -> void:
	z_index = 5
	for i in 14:
		var a := -PI * 0.5 + (float(i) / 13.0 - 0.5) * 2.2
		var s := 120.0 + 25.0 * float(i % 5)
		drops.append({ "p": position, "v": Vector2(cos(a), sin(a)) * s + vel * 0.25, "t": 0.6 + 0.04 * float(i % 4), "mist": i % 3 == 0 })

## One tick of flight; callable from a test without a world.
func step(dt: float) -> void:
	_t += dt
	var g := Tune.f("gravity")
	var floor_y := World.floor_at(world, position)
	vel.y += g * dt
	position += vel * dt
	ang += spin * dt
	if position.y >= floor_y - r * 0.5:
		position.y = floor_y - r * 0.5
		if vel.y > 0.0:
			if not _landed and is_inside_tree():
				Audio.play_at(&"limb_part_thud", global_position)
			_landed = true
			vel.y *= -0.35
			vel.x *= 0.6
			spin *= 0.5
			dmg = 0.0
	_trail_t -= dt
	if _trail_t <= 0.0 and vel.length() > 60.0:
		_trail_t = 0.05
		drops.append({ "p": position, "v": Vector2(0, -30), "t": 0.5, "mist": true })
	for d: Dictionary in drops:
		d.t -= dt
		d.p += (d.v as Vector2) * dt
		if not bool(d.mist):
			d.v = (d.v as Vector2) + Vector2(0, g * 0.5 * dt)
	drops.assign(drops.filter(func(d: Dictionary) -> bool: return float(d.t) > 0.0))
	if dmg > 0.0 and is_inside_tree():
		_hit_others()
	life -= dt

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	step(dt)
	queue_redraw()
	if life <= 0.0:
		queue_free()

func _hit_others() -> void:
	var box := Rect2(position - Vector2(r, r), Vector2(r, r) * 2.0)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or e == source or e.dead or e.prop or hit_list.has(e):
			continue
		if not box.intersects(e.hurt_rect()):
			continue
		hit_list.append(e)
		var h := Hit.make(Hit.Kind.PROJECTILE, dmg, position.x - signf(vel.x), kb)
		h.source = source
		e.hurt(h)

func _draw() -> void:
	var fade := clampf(life / 0.5, 0.0, 1.0)
	for d: Dictionary in drops:
		var p: Vector2 = (d.p as Vector2) - position
		var k := clampf(float(d.t) / 0.6, 0.0, 1.0)
		if bool(d.mist):
			draw_circle(p, 5.0 + 6.0 * (1.0 - k), Color(0.55, 0.85, 0.78, 0.35 * k))
		else:
			draw_circle(p, 2.5, Color(0.55, 0.04, 0.08, k))
	draw_set_transform(Vector2.ZERO, ang)
	if poly.size() >= 3:
		draw_colored_polygon(poly, Color(colour, fade))
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color(colour.darkened(0.5), fade), 2.0)
	# The cut face: a red cap at the local origin.
	draw_circle(Vector2.ZERO, 4.0, Color(0.7, 0.05, 0.1, fade))
	if limb == LimbRules.HEAD and _t < 0.8:
		draw_circle(Vector2(4, -r * 0.6), 2.2, Color(eye, fade * (1.0 - _t / 0.8)))
		draw_circle(Vector2(-3, -r * 0.6), 2.2, Color(eye, fade * (1.0 - _t / 0.8)))
