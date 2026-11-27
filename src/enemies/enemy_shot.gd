## A hostile projectile (sentry shot, bat glob). Flies straight, glows through
## darkness (amulet-and-flare §3), hits the hero through Player.hurt (ADR-0002)
## and can be swatted by the hero's strike (prototype shots loop).
class_name EnemyShot
extends Node2D

var vel: Vector2 = Vector2.ZERO
## Radius, px.
var r: float = 8.0
## Damage to the hero (tier multiplier already applied by the shooter).
var dmg: float = 0.0
## Seconds left before it fades.
var life: float = 1.0
var color: Color = Color.WHITE
## The enemy that fired it (Hit.source).
var source: Node = null
## The combat scene root; null in tests.
var world: World

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	if world:
		dt *= world.time_mult()
	step(dt)
	if life <= 0.0:
		queue_free()
	queue_redraw()

## One tick of flight and hero checks.
func step(dt: float) -> void:
	life -= dt
	position += vel * dt
	var room_w: float = world.room.layout.w if world and world.room else INF
	if position.x < 0.0 or position.x > room_w or position.y > Tune.f("ground_y") + Tune.f("shot_floor") or position.y < Tune.f("shot_top"):
		life = 0.0
	var p: Player = world.player if world else null
	if p == null or p.dead or life <= 0.0:
		return
	var pc := p.position - Vector2(0, Player.H / 2.0)
	if position.distance_to(pc) < r + Tune.f("shot_hit_r") and p.inv <= 0.0 and p.dash_t <= 0.0:
		var hit := Hit.make(Hit.Kind.PROJECTILE, dmg, position.x, 0.0)
		hit.source = source
		p.hurt(hit)
		life = 0.0
		return
	if p.atk_t > 0.0:
		var reach: float = p.weapon.reach() if p.weapon else 0.0
		if absf(position.y - (p.position.y - Tune.f("hero_aim_dy"))) < Tune.f("shot_swat_dy") \
				and (position.x - p.position.x) * p.face > 0.0 and absf(position.x - p.position.x) < reach + Tune.f("shot_swat_extra"):
			life = 0.0

## Glow through the darkness (amulet-and-flare §3.9): one spot shot_glow_r at shot_glow_a.
func light_spots() -> Array[Vector4]:
	if life <= 0.0:
		return []
	return [Vector4(position.x, position.y, Tune.f("shot_glow_r"), Tune.f("shot_glow_a"))]

func _draw() -> void:
	draw_circle(Vector2.ZERO, Tune.f("shot_glow_r"), Color(color, Tune.f("shot_glow_a") * 0.25))
	draw_circle(Vector2.ZERO, r * 1.6, Color(color, 0.35))
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2.ZERO, r * 0.45, Color.WHITE)
