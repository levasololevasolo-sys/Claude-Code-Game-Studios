## A hostile projectile (thrower stone, bat glob, boss shots). Flies straight or
## in an arc (`grav`), glows through darkness (amulet-and-flare §3), hits the hero
## through Player.hurt (ADR-0002) and can be swatted by the hero's strike
## (prototype shots loop). Reaching the hero inside the parry window it is
## reflected (GDD parry §3.5): it becomes the hero's and hurts enemies instead.
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
## Downward acceleration, px/s² (0 = straight flight; the thrower's lob).
var grav: float = 0.0
## True after a parry reflected it: the hero's now, it hurts enemies (parry §3.5).
var reflected: bool = false
## The combat scene root; null in tests.
var world: World
## Enemies a reflected shot can hit; injected in tests, else the "enemies" group.
var targets: Array = []
## Enemies a piercing reflected shot already went through (Горн Сварога «отбив»).
var targets_hit: Array = []

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
	vel.y += grav * dt
	position += vel * dt
	var room_w: float = world.room.layout.w if world and world.room else INF
	if position.x < 0.0 or position.x > room_w or World.shot_blocked(world, position, Tune.f("shot_floor")) or position.y < Tune.f("shot_top"):
		life = 0.0
	if life <= 0.0:
		return
	if reflected:
		_hit_enemies()
		return
	var p: Player = world.player if world else null
	if p == null or p.dead:
		return
	var pc := p.position - Vector2(0, Player.H / 2.0)
	var near := position.distance_to(pc) < r + Tune.f("shot_hit_r")
	if near and p.reflect_shot(self):
		return
	if near and p.inv <= 0.0 and p.dash_t <= 0.0:
		var hit := Hit.make(Hit.Kind.PROJECTILE, dmg, position.x, 0.0)
		hit.source = source
		p.hurt(hit)
		life = 0.0
		return
	if p.atk_t > 0.0 and not reflected:
		var reach: float = p.weapon.reach() if p.weapon else 0.0
		# Горн Сварога «отбив» (gods-expansion §3.12): the swing sends the shot back.
		var dfl: Dictionary = p.forge_hook("deflect")
		var fin := p.combo >= (p._body().get("mult", [1]) as Array).size()
		if bool(dfl.get("fin_only", false)) and not fin:
			dfl = {}
		var extra := float(dfl.get("extra", 0.0))
		var front := (position.x - p.position.x) * p.face > 0.0 or (bool(dfl.get("both", false)) or p.back_strike())
		if absf(position.y - (p.position.y - Tune.f("hero_aim_dy"))) < Tune.f("shot_swat_dy") + extra \
				and front and absf(position.x - p.position.x) < reach + Tune.f("shot_swat_extra") + extra:
			if dfl.is_empty() or p.powers == null:
				life = 0.0
			else:
				p.powers._reflect(self, float(dfl.get("k", 1.5)), int(dfl.get("pierce", 1)))

## Turns this shot into the hero's (GDD parry §3.5, P6-P7): new velocity
## `v`, no arc, damage `dmg_now` to enemies, owned by `owner`.
func reflect(v: Vector2, dmg_now: float, owner: Node) -> void:
	reflected = true
	vel = v
	grav = 0.0
	dmg = dmg_now
	source = owner
	life = maxf(life, Tune.f("parry_reflect_life"))
	color = Color(String(Tune.get_value("parry_reflect_colour")))
	queue_redraw()

## A reflected shot hits the first live enemy it touches (Enemy.hurt, ADR-0002).
func _hit_enemies() -> void:
	var list: Array = targets
	if list.is_empty() and is_inside_tree():
		list = get_tree().get_nodes_in_group("enemies")
	for n in list:
		var e := n as Enemy
		if e == null or e.dead or not is_instance_valid(e) or e in targets_hit:
			continue
		if e.hurt_rect().grow(r).has_point(position):
			var hit := Hit.make(Hit.Kind.PROJECTILE, dmg, position.x - signf(vel.x), Tune.f("parry_reflect_kb"))
			hit.source = source
			e.hurt(hit)
			var left := int(get_meta(&"pierce", 1)) - 1
			if left > 0:
				set_meta(&"pierce", left)
				targets_hit.append(e)
				continue
			life = 0.0
			return

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
