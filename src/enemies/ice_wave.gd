## One run of ice spikes along the floor from Карачун's staff slam (GDD
## bestiary §3.4 card 3, mechanic ground_wave). The front runs from x0 in `dir`
## at `speed` until `end` (wave_dist, room edge or an ice wall, FrostRules);
## spikes rise behind it and sink `linger` s later. The front hurts the hero
## once if his feet are lower than the spike height (a jump clears it). It is a
## zone: never parried (Hit.Kind.PROJECTILE without an enemy source).
class_name IceWave
extends Node2D

var x0: float = 0.0
var dir: int = 1
var speed: float = 420.0
var end: float = 0.0
var spike_h: float = 40.0
var half: float = 16.0
var dmg: float = 0.0
var linger: float = 0.35
var elapsed: float = 0.0
var hit_done: bool = false
var world: World
## Hero injected in tests (else world.player).
var target: Player
## Drawn spike strip (DrawnEnemyVisual.fx "karachun"/"spike"), {} = code shapes.
var _spike: Dictionary = {}
var _spike_checked: bool = false

## Current front x.
func front() -> float:
	return FrostRules.wave_front(x0, dir, speed, elapsed, end)

## True when the front has stopped and the last spikes sank.
func finished() -> bool:
	return front() == end and elapsed - absf(end - x0) / maxf(speed, 1.0) >= linger

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	if world:
		dt *= world.time_mult()
	step(dt)
	if finished():
		queue_free()
	queue_redraw()

## One tick: move the front, hurt the hero once.
func step(dt: float) -> void:
	elapsed += dt
	var p: Player = target if target else (world.player if world else null)
	if hit_done or p == null or p.dead or front() == end:
		return
	if FrostRules.wave_hits(front(), p.position, position.y, spike_h, half, Player.W):
		hit_done = true
		var h := Hit.make(Hit.Kind.PROJECTILE, dmg, front() - dir, 0.0)
		p.hurt(h)

## Draws one drawn spike sprite of height hh at sx; false without the sprite.
func _draw_spike(sx: float, hh: float, i: int) -> bool:
	if not _spike_checked:
		_spike_checked = true
		_spike = DrawnEnemyVisual.fx("karachun", "spike")
	if _spike.is_empty():
		return false
	var tex: Texture2D = _spike.tex
	var n := maxi(1, int(_spike.frames))
	var cw := tex.get_width() / float(n)
	var o: Vector2 = _spike.origin
	var sc := float(_spike.scale) * hh / maxf(spike_h, 1.0)
	draw_set_transform(Vector2(sx, 0.0), 0.0, Vector2(float(_spike.scale) * (-1.0 if i % 2 else 1.0), sc))
	draw_texture_rect_region(tex, Rect2(-o.x, -o.y, cw, tex.get_height()), Rect2(cw * (i % n), 0.0, cw, tex.get_height()))
	draw_set_transform(Vector2.ZERO)
	return true

func _draw() -> void:
	# Drawn in local space: position = (x0, floor y).
	var fx := front() - x0
	var ice := Color("#8fd3f5")
	var spacing := 22.0
	var n := int(absf(fx) / spacing) + 1
	var t_front := absf(fx) / maxf(speed, 1.0)
	for i in n:
		var d := i * spacing
		# Spike age: how long ago the front passed it.
		var age := elapsed - d / maxf(speed, 1.0)
		var k := 1.0 if age < 0.08 else clampf(1.0 - (age - 0.08) / maxf(linger, 0.01), 0.0, 1.0)
		if age > t_front + linger:
			k = 0.0
		if k <= 0.0:
			continue
		var sx := d * dir
		var hh := spike_h * k * (0.8 + 0.2 * sin(i * 2.3))
		if _draw_spike(sx, hh, i):
			continue
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 9, 0), Vector2(sx, -hh - 4), Vector2(sx + 9, 0)]), Color("#2c3b52"))
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 7, 0), Vector2(sx, -hh), Vector2(sx + 7, 0)]), ice)
		draw_line(Vector2(sx, -hh * 0.9), Vector2(sx - 2, -2), Color(1, 1, 1, 0.8), 2.0)
	if front() != end:
		# The leading tip: a bright frost burst.
		for r in [24.0, 14.0]:
			draw_circle(Vector2(fx, -10), r, Color(ice, 0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 11, 0), Vector2(fx, -spike_h - 6), Vector2(fx + 11, 0)]), Color.WHITE)
