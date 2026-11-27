## Everything about one hit: built by whoever strikes, passed to Enemy.hurt() or
## Player.hurt(). See ADR-0002 (Key Interfaces) and GDD movement-and-combat §3.7.
class_name Hit
extends RefCounted

## What kind of hit this is. Decides which rules of DamageRules apply.
enum Kind { STRIKE, SLAM, PROJECTILE, FLARE, TICK, WALL, CONTACT }

## Kind of hit.
var kind: Kind = Kind.STRIKE
## Base damage before target multipliers.
var dmg: float = 0.0
## World x the hit came from (knockback direction and front-shield check).
var from_x: float = 0.0
## Knockback strength before the division by weight, px/s.
var kb: float = 0.0
## Ignores a front shield (mace).
var pierce: bool = false
## Last swing of a combo.
var finisher: bool = false
## Status strengths to apply, 0 = none.
var burn: float = 0.0
var stun: float = 0.0
## Hero build modifiers (runes, buffs): "reaper", "heat"... Keys fixed by ADR-0007.
var mods: Dictionary = {}
## Who struck (may be null).
var source: Node = null

## Shorthand constructor.
static func make(p_kind: Kind, p_dmg: float, p_from_x: float, p_kb: float) -> Hit:
	var h := Hit.new()
	h.kind = p_kind
	h.dmg = p_dmg
	h.from_x = p_from_x
	h.kb = p_kb
	return h
