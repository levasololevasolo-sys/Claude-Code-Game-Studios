## Pure rules of the Тёмный бор roster (GDD design/gdd/bestiary.md §3.3):
## Сучковик's branch-spear (where it sticks, the step it leaves, how many at
## once, the stun of a deflected one) and Лесавка's whistle (haste multipliers,
## who it reaches, running from the hero). No nodes, no globals: every number
## is passed in, so the unit tests feed fixtures.
class_name ForestRules
extends RefCounted

## Platform thickness of a stuck spear, px (collision only; the art is thinner).
const STEP_THICK: float = 8.0

## X where a horizontal spear from `from` flying `dir` (-1 / 1) meets a wall:
## the nearest side of a solid (Rect2) crossing its height, else the room edge
## (0 or room_w) moved in by `margin`.
static func spear_stop_x(from: Vector2, dir: int, solids: Array, room_w: float, margin: float) -> float:
	var best := margin if dir < 0 else room_w - margin
	for s: Variant in solids:
		var r := s as Rect2
		if from.y < r.position.y or from.y > r.end.y:
			continue
		if dir > 0 and r.position.x >= from.x and r.position.x < best:
			best = r.position.x
		elif dir < 0 and r.end.x <= from.x and r.end.x > best:
			best = r.end.x
	return best

## The step a spear stuck at `stop_x` (flying `dir`) at height `y` leaves: it
## juts `plat_w` px back into the room from the wall, top at `y`.
static func step_rect(stop_x: float, dir: int, y: float, plat_w: float) -> Rect2:
	var x0 := stop_x if dir < 0 else stop_x - plat_w
	return Rect2(x0, y, plat_w, STEP_THICK)

## A Сучковик may throw while fewer than `max_n` of its spears live (flying or stuck).
static func can_throw(live: int, max_n: int) -> bool:
	return live < max_n

## True when the stuck spear's time is up (it breaks, the step is gone).
static func step_gone(left: float) -> bool:
	return left <= 0.0

## True when the hero is in the line of a horizontal throw: within range_x
## ahead, within range_y up or down.
static func in_line(dx: float, dy: float, range_x: float, range_y: float) -> bool:
	return absf(dx) <= range_x and absf(dy) <= range_y

## Stun a deflected spear gives the enemy it hits: `stun` for a Сучковик, 0 else.
static func deflect_stun(hit_is_thrower: bool, stun: float) -> float:
	return stun if hit_is_thrower else 0.0

## Speed multiplier of an enemy with `haste_t` s of haste left.
static func haste_speed(haste_t: float, mult: float) -> float:
	return mult if haste_t > 0.0 else 1.0

## Extra cooldown spent per tick while hasted: cooldowns run 1 / cd_mult as
## fast (cd_mult 0.77 -> x1.3), so the extra on top of dt is dt * (1 / cd_mult - 1).
static func haste_cd_extra(dt: float, haste_t: float, cd_mult: float) -> float:
	if haste_t <= 0.0 or cd_mult <= 0.0:
		return 0.0
	return dt * (1.0 / cd_mult - 1.0)

## True when an ally at `ally` is reached by a whistle from `from` (radius r).
static func in_aura(from: Vector2, ally: Vector2, r: float) -> bool:
	return from.distance_to(ally) <= r

## Лесавка's run: away from the hero (at `dx` = hero.x - self.x) while closer
## than keep, back towards the pack when far (keep + 80); 0 when cornered.
static func flee_vx(dx: float, keep: float, speed: float, cornered: bool) -> float:
	var adx := absf(dx)
	if adx < keep:
		return 0.0 if cornered else -signf(dx) * speed
	if adx > keep + 80.0:
		return signf(dx) * speed * 0.5
	return 0.0

## True when running away from the hero at `dx` would push past a wall
## (`x` within `w`/2 + margin + corner of the edge on the far side).
static func cornered(x: float, dx: float, w: float, room_w: float, margin: float, corner: float) -> bool:
	if room_w <= 0.0:
		return false
	var m := w / 2.0 + margin + corner
	return (dx > 0.0 and x < m) or (dx < 0.0 and x > room_w - m)
