## Pure rules of the hero's parry (GDD design/gdd/parry.md). Static, no nodes:
## Player keeps the timers and calls these; tests/unit/combat/ covers them.
class_name ParryRules
extends RefCounted

## True when a parry may start now: no cooldown, no whiff lock, not dashing
## and not in a swing.
static func can_start(cd: float, lock: float, dashing: bool, swinging: bool) -> bool:
	return cd <= 0.0 and lock <= 0.0 and not dashing and not swinging

## True when `kind` (Hit.Kind) from a source that is an enemy is a melee blow a
## parry catches. Shots (PROJECTILE) and everything else are not parried.
static func catches(window_left: float, kind: Hit.Kind, from_enemy: bool) -> bool:
	return window_left > 0.0 and from_enemy and kind == Hit.Kind.CONTACT

## Stun a successful parry puts on the attacker: parry_stun, or parry_boss_stun
## for a boss (0 = none).
static func stun_for(boss: bool, tune: Dictionary) -> float:
	return float(tune.get("parry_boss_stun", 0.0)) if boss else float(tune.get("parry_stun", 0.6))

## One tick of the window: returns {left, whiff}. `whiff` is true on the tick
## the window runs out without a catch.
static func tick_window(left: float, dt: float) -> Dictionary:
	if left <= 0.0:
		return { "left": 0.0, "whiff": false }
	var n := left - dt
	return { "left": maxf(n, 0.0), "whiff": n <= 0.0 }

## P5 (GDD parry §3.5): true when an enemy shot that reaches the hero now is
## reflected instead of hitting: the window is open and the shot is still the
## enemy's (a reflected shot is the hero's and never reflects again).
static func reflects(window_left: float, already_reflected: bool) -> bool:
	return window_left > 0.0 and not already_reflected

## P6: velocity of a reflected shot. Aimed at the shooter's centre when it is
## still alive (`has_shooter`), else straight back along -vel; the speed is
## |vel| x parry_reflect_speed. A zero velocity stays zero.
static func reflect_velocity(pos: Vector2, vel: Vector2, has_shooter: bool, shooter_at: Vector2, tune: Dictionary) -> Vector2:
	var speed := vel.length() * float(tune.get("parry_reflect_speed", 1.5))
	var dir := -vel.normalized()
	if has_shooter and shooter_at.distance_to(pos) > 0.001:
		dir = (shooter_at - pos).normalized()
	return dir * speed

## P7: damage a reflected shot deals to an enemy: shot damage x parry_reflect_dmg.
static func reflect_damage(shot_dmg: float, tune: Dictionary) -> float:
	return maxf(0.0, shot_dmg * float(tune.get("parry_reflect_dmg", 2.0)))
