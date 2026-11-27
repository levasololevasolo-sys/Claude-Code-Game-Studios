## Navi marks of elites (GDD enemies-and-elites §3.6, §5 edge 5). Pure rules;
## Enemy applies them. Marks: fire (Пламя), blink (Морок), blast (Взрыв),
## ward (Заслон), call (Зов). Порча (curse) is not implemented yet.
class_name EliteMarks
extends RefCounted

## A mark for an elite of `kind`, among the marks of tuning "elite_marks" minus
## "elite_forbid"[kind]. None fits: the first allowed of "elite_fallback".
static func pick(rng: RandomNumberGenerator, kind: String, t: Dictionary) -> String:
	var forbid: Array = (t.get("elite_forbid", {}) as Dictionary).get(kind, [])
	var pool: Array = []
	for m: String in (t.get("elite_marks", {}) as Dictionary):
		if not m in forbid:
			pool.append(m)
	if pool.is_empty():
		for m: String in t.get("elite_fallback", ["blast", "call"]):
			if not m in forbid:
				return m
		return String((t.get("elite_fallback", ["call"]) as Array)[-1])
	return String(pool[rng.randi_range(0, pool.size() - 1)])

## Заслон: damage `dmg` against a ward of `ward`; breaking hits (slam, wall) hit
## the ward ×`brk`. Returns Vector2(ward lost, damage left for hp).
static func ward_absorb(ward: float, dmg: float, breaking: bool, brk: float) -> Vector2:
	if ward <= 0.0:
		return Vector2(0.0, dmg)
	var m := brk if breaking else 1.0
	var lost := minf(ward, dmg * m)
	return Vector2(lost, dmg - lost / m)

## Морок: where the elite reappears, `dist` past the hero on the far side, inside [lo, hi].
static func blink_x(self_x: float, hero_x: float, dist: float, lo: float, hi: float) -> float:
	var side := 1.0 if hero_x >= self_x else -1.0
	var x := hero_x + side * dist
	if x < lo or x > hi:
		x = hero_x - side * dist
	return clampf(x, lo, hi)

## Взрыв: damage to the hero at distance `d` from the body (0 outside the radius).
static func blast_damage(d: float, t: Dictionary) -> float:
	return float(t.get("death_blast_dmg", 20)) if d <= float(t.get("death_blast_r", 140)) else 0.0

## Display name and colour of a mark.
static func info(mark: String, t: Dictionary) -> Dictionary:
	return (t.get("elite_marks", {}) as Dictionary).get(mark, { "name": mark, "colour": "#ffffff" })
