## Pure damage formulas (ADR-0002, GDD movement-and-combat §3.7-3.11, F6-F8, F12).
## No nodes, no autoloads: every number comes in as a parameter, `tune` is the
## tuning dictionary (Tune.data in the game, a fixture in tests).
##
## A target is described by a `view` Dictionary built by Enemy.hit_view():
##   x: float, face: int (-1/1), flies: bool, boss: bool, airborne: bool,
##   shield: bool (has a front shield right now), stunned: bool,
##   weight: float (> 0), kb_scale: float (k_target of F8 for this kind).
class_name DamageRules
extends RefCounted

## Smallest weight used in divisions, guards against a zero in the data.
const MIN_WEIGHT: float = 0.001

## F6 (part): base damage of combo swing number `combo` (1-based, clamped).
static func strike_damage(strike_dmg: float, combo_mults: Array, combo: int) -> float:
	if combo_mults.is_empty():
		return strike_dmg
	var i := clampi(combo, 1, combo_mults.size()) - 1
	return strike_dmg * float(combo_mults[i])

## True when `combo` is the last swing of a combo of `combo_len` swings.
static func is_finisher(combo: int, combo_len: int) -> bool:
	return combo >= combo_len

## F8 kb_src for a weapon strike: knockback × finisher multiplier.
static func strike_knockback(knockback: float, finisher: bool, finisher_mult: float) -> float:
	return knockback * (finisher_mult if finisher else 1.0)

## §3.9: a target is airborne when it is more than `margin` px above the floor.
static func is_airborne(y: float, ground_y: float, margin: float) -> bool:
	return y < ground_y - margin

## §3.7 step 3: the target's front shield takes this hit.
static func shield_blocks(hit: Hit, view: Dictionary) -> bool:
	if not bool(view.get("shield", false)) or bool(view.get("stunned", false)):
		return false
	if hit.pierce or hit.kind == Hit.Kind.FLARE or hit.kind == Hit.Kind.TICK:
		return false
	return int(signf(hit.from_x - float(view.get("x", 0.0)))) == int(view.get("face", 1))

## §3.7 steps 2-3 and §3.9: damage the target actually takes from `hit`.
static func final(hit: Hit, view: Dictionary, tune: Dictionary) -> float:
	var d := hit.dmg
	if hit.kind == Hit.Kind.STRIKE and bool(view.get("airborne", false)) \
			and not bool(view.get("flies", false)) and not bool(view.get("boss", false)):
		d *= float(tune.get("air_mult", 1.0))
	if shield_blocks(hit, view):
		d *= float(tune.get("sentry_block", 1.0))
	return maxf(0.0, d)

## F8: signed horizontal knockback speed for the target, px/s. Ticks push nothing;
## a hit from exactly the target's x pushes nothing (as in the Godot port).
static func knockback(hit: Hit, view: Dictionary, tune: Dictionary) -> float:
	if hit.kind == Hit.Kind.TICK:
		return 0.0
	var x := float(view.get("x", 0.0))
	if x == hit.from_x:
		return 0.0
	var k := float(view.get("kb_scale", 1.0))
	if shield_blocks(hit, view):
		k *= float(tune.get("shield_kb_mult", 1.0))
	return signf(x - hit.from_x) * hit.kb * k / maxf(float(view.get("weight", 1.0)), MIN_WEIGHT)

## F7: upward launch speed (positive number) of a target of `weight`.
static func launch_speed(speed: float, weight: float) -> float:
	return speed / maxf(weight, MIN_WEIGHT)

## F12 (shield part): the shield absorbs first. Returns Vector2(absorbed, rest).
static func split_shield(dmg: float, shield: float) -> Vector2:
	var absorbed := clampf(shield, 0.0, maxf(dmg, 0.0))
	return Vector2(absorbed, maxf(dmg, 0.0) - absorbed)
