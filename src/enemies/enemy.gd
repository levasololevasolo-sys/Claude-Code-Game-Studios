## Base class of every enemy (ADR-0002). Node2D with its own simple kinematics,
## origin at the feet, hit box is a Rect2 (no Area2D, not a PhysicsBody2D).
## ALL damage to an enemy goes through hurt(hit); never write `hp` from outside.
## A subclass sets its stats in _load_stats(), writes _behave() and its drawing;
## do not override _ready() or _physics_process().
## GDD: movement-and-combat §3.7-3.9, enemies-and-elites §3.1.
@abstract
class_name Enemy
extends Node2D

## Emitted after every hurt() that went through (amount may be 0 on a full block).
signal damaged(enemy: Enemy, amount: float, hit: Hit)
## Emitted once, when hp reaches 0.
signal died(enemy: Enemy, hit: Hit)

## Key of the kind in the enemy table.
var kind_id: String = ""
## Hit box size, px. Origin at the feet.
var w: float = 0.0
var h: float = 0.0
var flies: bool = false
var dead: bool = false
var boss: bool = false
var hp: float = 0.0
var max_hp: float = 0.0
## Weight (F7, F8): knockback and launch are divided by it.
var weight: float = 1.0
## k_target of F8 for this kind (1 for ordinary enemies).
var kb_scale: float = 1.0
## Fraction of horizontal speed kept per second (F9).
var drag: float = 0.002
## True for kinds with a front shield (sentry, knight on guard).
var front_shield: bool = false
## Facing, -1 or 1. Front shields block hits from this side.
var face: int = 1
## Seconds of stun left. A stunned enemy does not _behave().
var stun: float = 0.0
var vel: Vector2 = Vector2.ZERO
## Seconds of the white hit flash left.
var flash: float = 0.0
## Floating damage numbers: {v: int, t: float, x: float}.
var numbers: Array[Dictionary] = []
## The combat scene root (hitstop owner). Injected by whoever spawns the enemy.
var world: World

func _ready() -> void:
	add_to_group("enemies")
	_load_stats()
	hp = max_hp

## Sets w, h, max_hp, weight, flies... of the kind. Called once from _ready().
@abstract func _load_stats() -> void

## The kind's behaviour for one tick; the base class does the rest.
@abstract func _behave(dt: float) -> void

## Hook after damage is applied and before the death check (dummy refill).
func _after_hurt(_hit: Hit) -> void:
	pass

## Hit box in world space.
func hurt_rect() -> Rect2:
	return Rect2(position.x - w / 2.0, position.y - h, w, h)

## What DamageRules needs to know about this enemy right now.
func hit_view() -> Dictionary:
	return {
		"x": position.x, "face": face, "flies": flies, "boss": boss,
		"airborne": DamageRules.is_airborne(position.y, Tune.f("ground_y"), Tune.f("air_target_margin")),
		"shield": front_shield, "stunned": stun > 0.0, "weight": weight, "kb_scale": kb_scale,
	}

## The ONLY way to damage an enemy (GDD §3.7 order). Returns the damage taken.
func hurt(hit: Hit) -> float:
	if dead:
		return 0.0
	var view := hit_view()
	var dmg := DamageRules.final(hit, view, Tune.data)
	hp -= dmg
	flash = Tune.f("enemy_flash_time")
	if hit.kind != Hit.Kind.TICK:
		vel.x = DamageRules.knockback(hit, view, Tune.data)
		numbers.append({ "v": roundi(dmg), "t": Tune.f("damage_number_time"), "x": randf_range(-10.0, 10.0) })
	if hit.stun > 0.0:
		stun = maxf(stun, hit.stun * (Tune.f("boss_stun_mult") if boss else 1.0))
	damaged.emit(self, dmg, hit)
	_after_hurt(hit)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit(self, hit)
		Events.enemy_killed.emit(self, hit)
	return dmg

## Throws the enemy upward (up strike, F7). Flyers and bosses are not launched.
func launch(speed: float) -> void:
	if flies or boss or dead:
		return
	vel.y = -DamageRules.launch_speed(speed, weight)

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	stun = maxf(0.0, stun - dt)
	if stun <= 0.0:
		_behave(dt)
	if not flies:
		vel.y = minf(vel.y + Tune.f("gravity") * dt, Tune.f("max_fall"))
	position += vel * dt
	var ground := Tune.f("ground_y")
	if not flies and position.y >= ground:
		position.y = ground
		vel.y = 0.0
	vel.x *= pow(drag, dt)
	flash -= dt
	for n: Dictionary in numbers:
		n.t -= dt
	numbers.assign(numbers.filter(func(n: Dictionary) -> bool: return n.t > 0.0))
	queue_redraw()

## Draws the hp bar and the damage numbers above the hit box. Call from _draw().
func _draw_overlay() -> void:
	var font: Font = ThemeDB.fallback_font
	var life := Tune.f("damage_number_time")
	draw_rect(Rect2(-22, -h - 18, 44, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-22, -h - 18, 44 * maxf(hp, 0.0) / maxf(max_hp, 1.0), 5), Color("#e05a4a"))
	for n: Dictionary in numbers:
		draw_string(font, Vector2(n.x - 8, -h - 26 - (life - n.t) * 60.0), str(n.v), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.5, n.t / life))
