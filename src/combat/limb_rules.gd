## Pure rules of limb zones (GDD design/gdd/limb-zones.md §3, §4). Static, no
## nodes, no autoloads: callers pass the kind's row of limb_zones.json and the
## tuning dictionary, so every rule is unit-tested (tests/unit/combat/).
## Developer rules 27.11: the arm is cut ONLY by a parry (ParryRules,
## Enemy.parried); the head ONLY by a down-air strike on an attacking enemy;
## an ordinary enemy dies one of two ways, plain or with a part flying.
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
	for k: String in [ARM, HEAD]:
		if row.has(k) and not (arm_off if k == ARM else head_off):
			var r := local_rect(row[k], w, h, face)
			out[k] = Rect2(r.position + pos, r.size)
	return out

## Where the blade meets the target (§4 F1). `target` = the enemy's silhouette
## (hit box merged with its zones). Side: the near edge plus `depth` at the
## middle height of the overlap; down: the top of the overlap plus `depth`;
## up: its bottom minus `depth`. Vector2.INF when the strike misses.
static func contact_point(strike: Rect2, target: Rect2, dir: String, hero_x: float, depth: float) -> Vector2:
	if not strike.intersects(target):
		return Vector2.INF
	var o := strike.intersection(target)
	if o.size.x <= 0.0 or o.size.y <= 0.0:
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

## Geometric zone a strike meets (F1): "head", "arm" or "body".
static func zone_of(strike: Rect2, hurt: Rect2, row: Dictionary, pos: Vector2, w: float, h: float, face: int,
		dir: String, hero_x: float, arm_off: bool, head_off: bool, tune: Dictionary) -> String:
	var zr := zones(row, pos, w, h, face, arm_off, head_off)
	var sil := hurt
	for k: String in zr:
		sil = sil.merge(zr[k])
	return zone_at(contact_point(strike, sil, dir, hero_x, float(tune.get("limb_contact_depth", 6.0))), zr)

## True while the enemy's state is one of its attack states (wind-up or blow).
static func in_attack(st: String, row: Dictionary) -> bool:
	return (row.get("attack_states", []) as Array).has(st)

## What a STRIKE does to a living enemy (§3.3): "head" only on the head zone,
## from a down strike of an airborne hero, while the enemy attacks; else "".
## A strike never cuts the arm (only a parry does, §3.2). Beasts (death_only)
## lose nothing alive.
static func resolve(zone: String, dir: String, hero_airborne: bool, st: String, row: Dictionary, _arm_off: bool, head_off: bool) -> String:
	if bool(row.get("death_only", false)):
		return ""
	if zone == HEAD and not head_off and row.has(HEAD) and dir == "down" and hero_airborne and in_attack(st, row):
		return HEAD
	return ""

## Full pick from geometry: zone (F1) then the rule (§3.3).
static func pick(strike: Rect2, hurt: Rect2, row: Dictionary, pos: Vector2, w: float, h: float, face: int,
		dir: String, hero_x: float, hero_airborne: bool, st: String, arm_off: bool, head_off: bool, tune: Dictionary) -> String:
	var zone := zone_of(strike, hurt, row, pos, w, h, face, dir, hero_x, arm_off, head_off, tune)
	return resolve(zone, dir, hero_airborne, st, row, arm_off, head_off)

## True when `limb` may still be cut on this living enemy (never twice).
static func can_cut(limb: String, row: Dictionary, arm_off: bool, head_off: bool) -> bool:
	if bool(row.get("death_only", false)):
		return false
	match limb:
		ARM:
			return row.has(ARM) and not arm_off
		HEAD:
			return row.has(HEAD) and not head_off
	return false

## True when a parry may take this enemy's arm (§3.2): a cuttable arm (the row
## has one; a shield arm is simply not listed), still on, and the enemy attacks.
## `arm_states`, when the row has it, narrows the parry to a melee blow (the
## thrower's shove; its throw wind-up is an attack for the head only).
static func parry_takes_arm(row: Dictionary, st: String, arm_off: bool) -> bool:
	if row.has("arm_states"):
		return can_cut(ARM, row, arm_off, false) and (row.arm_states as Array).has(st)
	return can_cut(ARM, row, arm_off, false) and in_attack(st, row)

## Precise hits (parries for the arm, down-air hits for the head) one limb needs
## before it flies (§3.6): limb_elite_hits_needed for a tough kind (Навий витязь)
## and every elite, else 1.
static func hits_needed(row: Dictionary, elite: bool, tune: Dictionary) -> int:
	if elite or bool(row.get("tough", false)):
		return maxi(1, int(tune.get("limb_elite_hits_needed", 3)))
	return 1

## True when the `count`-th precise hit (1-based, this one included) cuts.
static func cuts_now(count: int, needed: int) -> bool:
	return count >= needed

## F2: damage multiplier of the cutting hit (1 for a plain hit). The arm is
## cut by a parry, which deals no damage, so only the head has a bonus.
static func bonus_mult(limb: String, tune: Dictionary) -> float:
	return float(tune.get("limb_head_bonus", 1.0)) if limb == HEAD else 1.0

## F3: the enemy's hp after the cutting hit. Losing the head is not a death:
## only the damage counts, so it dies only when that damage empties the hp.
static func hp_after(hp: float, final_dmg: float) -> float:
	return hp - final_dmg

## §3.5 Death of an ordinary enemy, two variants: the part that flies as part of
## the death ("" = plain death). The killing blow's zone decides first (head or
## arm still on); otherwise a roll below death_sever_chance takes the head, or
## the arm when the head is gone. `roll` in [0, 1).
static func death_part(zone: String, roll: float, row: Dictionary, arm_off: bool, head_off: bool, tune: Dictionary) -> String:
	if row.is_empty():
		return ""
	if zone == HEAD and row.has(HEAD) and not head_off:
		return HEAD
	if zone == ARM and row.has(ARM) and not arm_off:
		return ARM
	if roll < float(tune.get("death_sever_chance", 0.0)):
		if row.has(HEAD) and not head_off:
			return HEAD
		if row.has(ARM) and not arm_off:
			return ARM
	return ""

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
