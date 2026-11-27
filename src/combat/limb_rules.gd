## Pure rules of limb zones (GDD design/gdd/limb-zones.md §3, §4). Static, no
## nodes, no autoloads: callers pass the kind's row of limb_zones.json and the
## tuning dictionary, so every rule is unit-tested (tests/unit/combat/).
## Zones: "arm" (the attacking arm, cut only during the attack) and "head"
## (knocked off only by a down-air strike). Anything else is "body".
class_name LimbRules
extends RefCounted

const ARM: String = "arm"
const HEAD: String = "head"
const BODY: String = "body"

## True when this enemy may have limb zones at all (§3.1): never a boss or a
## prop; an elite only while tuning "limb_elites" is not 0.
static func eligible(row: Dictionary, boss: bool, elite: bool, prop: bool, tune: Dictionary) -> bool:
	if row.is_empty() or boss or prop:
		return false
	return not elite or float(tune.get("limb_elites", 1.0)) != 0.0

## Local rect of a zone spec [x0, x1, y0, y1] (fractions of w forward, of h up),
## mirrored by `face`. Origin at the feet, y down (Godot).
static func local_rect(spec: Array, w: float, h: float, face: int) -> Rect2:
	var xa := float(spec[0]) * w * face
	var xb := float(spec[1]) * w * face
	return Rect2(minf(xa, xb), -float(spec[3]) * h, absf(xb - xa), (float(spec[3]) - float(spec[2])) * h)

## The live zones in world space: {"arm": Rect2, "head": Rect2}; a cut part is gone.
static func zones(row: Dictionary, pos: Vector2, w: float, h: float, face: int, arm_off: bool, head_off: bool) -> Dictionary:
	var out := {}
	if row.has(ARM) and not arm_off:
		out[ARM] = Rect2(local_rect(row[ARM], w, h, face).position + pos, local_rect(row[ARM], w, h, face).size)
	if row.has(HEAD) and not head_off:
		out[HEAD] = Rect2(local_rect(row[HEAD], w, h, face).position + pos, local_rect(row[HEAD], w, h, face).size)
	return out

## Where the blade meets the target (§4 F1). `target` = the enemy's silhouette
## (hit box merged with its zones). Side: the near edge plus `depth` at the
## middle height of the overlap; down: the top of the overlap plus `depth`;
## up: its bottom minus `depth`. Vector2.INF when the strike misses.
static func contact_point(strike: Rect2, target: Rect2, dir: String, hero_x: float, depth: float) -> Vector2:
	var o := strike.intersection(target)
	if not strike.intersects(target) or o.size.x <= 0.0 or o.size.y <= 0.0:
		return Vector2.INF
	var c := o.get_center()
	match dir:
		"down":
			return Vector2(c.x, minf(o.position.y + depth, o.end.y))
		"up":
			return Vector2(c.x, maxf(o.end.y - depth, o.position.y))
	var near := o.position.x + minf(depth, o.size.x) if hero_x <= target.get_center().x else o.end.x - minf(depth, o.size.x)
	return Vector2(near, c.y)

## The zone under the contact point: head before arm (they may overlap), else body.
static func zone_at(contact: Vector2, zone_rects: Dictionary) -> String:
	if contact == Vector2.INF:
		return BODY
	for k: String in [HEAD, ARM]:
		if zone_rects.has(k) and (zone_rects[k] as Rect2).grow(0.001).has_point(contact):
			return k
	return BODY

## True while the enemy's state is one of its attack states (wind-up or blow).
static func in_attack(st: String, row: Dictionary) -> bool:
	return (row.get("attack_states", []) as Array).has(st)

## What the hit does (§3.2, §3.3): "arm" only on the arm zone during an attack,
## "head" only on the head zone from a down strike of an airborne hero; else "".
## A part already cut never triggers again.
static func resolve(zone: String, dir: String, hero_airborne: bool, st: String, row: Dictionary, arm_off: bool, head_off: bool) -> String:
	if zone == ARM and not arm_off and row.has(ARM) and in_attack(st, row):
		return ARM
	if zone == HEAD and not head_off and row.has(HEAD) and dir == "down" and hero_airborne:
		return HEAD
	return ""

## Full pick from geometry: contact point -> zone -> rule (F1 + §3.2-3.3).
static func pick(strike: Rect2, hurt: Rect2, row: Dictionary, pos: Vector2, w: float, h: float, face: int,
		dir: String, hero_x: float, hero_airborne: bool, st: String, arm_off: bool, head_off: bool, tune: Dictionary) -> String:
	var zr := zones(row, pos, w, h, face, arm_off, head_off)
	var sil := hurt
	for k: String in zr:
		sil = sil.merge(zr[k])
	var c := contact_point(strike, sil, dir, hero_x, float(tune.get("limb_contact_depth", 6.0)))
	return resolve(zone_at(c, zr), dir, hero_airborne, st, row, arm_off, head_off)

## True when `limb` may still be cut on this enemy (cannot be cut twice).
static func can_cut(limb: String, row: Dictionary, arm_off: bool, head_off: bool) -> bool:
	match limb:
		ARM:
			return row.has(ARM) and not arm_off
		HEAD:
			return row.has(HEAD) and not head_off
	return false

## F2: damage multiplier of the cutting hit (1 for a plain hit).
static func bonus_mult(limb: String, tune: Dictionary) -> float:
	match limb:
		ARM:
			return float(tune.get("limb_arm_bonus", 1.0))
		HEAD:
			return float(tune.get("limb_head_bonus", 1.0))
	return 1.0

## F3: the enemy's hp after the cutting hit. Losing the head is not a death:
## only the damage counts, so it dies only when that damage empties the hp.
static func hp_after(hp: float, final_dmg: float) -> float:
	return hp - final_dmg

## F4: stats of the one-armed variant: every key of `mults` multiplied.
static func one_arm_stats(stats: Dictionary, mults: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	for k: String in mults:
		if out.has(k):
			out[k] = float(out[k]) * float(mults[k])
	return out

## F5: where a headless enemy thinks the hero is: the real spot swayed by
## err * sin(2 pi freq t) on x. err 0 = exact.
static func headless_aim(hero: Vector2, t: float, err: float, freq: float) -> Vector2:
	return Vector2(hero.x + err * sin(TAU * freq * t), hero.y)

## F6: launch velocity of a cut part flying away from the hero (`away` = -1/1).
static func part_velocity(away: int, speed: float, up: float) -> Vector2:
	return Vector2(float(away) * speed, -up)
