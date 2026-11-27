## Everything about one hit: built by whoever strikes, passed to Enemy.hurt() or
## Player.hurt(). See ADR-0002 (Key Interfaces) and GDD movement-and-combat §3.7.
class_name Hit
extends RefCounted

## What kind of hit this is. Decides which rules of DamageRules apply.
## STATUS = a status discharge or burst (Perun lightning, Stribog cut burst):
## no knockback, cut by a front shield (gods-and-runes §5), not a tick.
## DASH = a rune dash passing through an enemy (gods-and-runes §3.5).
enum Kind { STRIKE, SLAM, PROJECTILE, FLARE, TICK, WALL, CONTACT, STATUS, DASH }

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
## Statuses this hit puts on the target (gods-and-runes §3.7), 0 = none.
## Durations in seconds (already × level × power); stacks are counts.
var burn: float = 0.0
var stun: float = 0.0
var curse: float = 0.0
var root: float = 0.0
var shock: int = 0
var cuts: int = 0
## Discharge the target right away (Perun Flare), with this many extra jumps.
var discharge: bool = false
var extra_jumps: int = 0
## Stribog Flare: a boss with at least this many cuts bursts them (0 = never).
var boss_burst_min: int = 0
## True for hits made by a status effect (discharge, burst, wrath): they never
## start Гнев богов again (gods-and-runes §3.12).
var nested: bool = false
## Hero build modifiers (runes, buffs): "reaper", "heat"... Keys fixed by ADR-0007.
var mods: Dictionary = {}
## Limb the hero's strike cuts (GDD limb-zones): "head" or "" (plain
## hit). Set by Player._strike_hits via Enemy.limb_at(); Enemy.hurt() re-checks it.
var limb: String = ""
## Zone the blade met ("head", "arm", "body"; "" = no zones): picks the death variant.
var zone: String = ""
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

## Copies a status payload (RunBuild.payload()) onto this hit.
func add_payload(p: Dictionary) -> void:
	burn = maxf(burn, float(p.get("burn", 0.0)))
	curse = maxf(curse, float(p.get("curse", 0.0)))
	root = maxf(root, float(p.get("root", 0.0)))
	shock += int(p.get("shock", 0))
	cuts += int(p.get("cuts", 0))
	if bool(p.get("discharge", false)):
		discharge = true
		extra_jumps = maxi(extra_jumps, int(p.get("extra_jumps", 0)))
	boss_burst_min = maxi(boss_burst_min, int(p.get("boss_burst_min", 0)))

## True when the hit carries any god status.
func has_status() -> bool:
	return burn > 0.0 or curse > 0.0 or root > 0.0 or shock > 0 or cuts > 0 or discharge
