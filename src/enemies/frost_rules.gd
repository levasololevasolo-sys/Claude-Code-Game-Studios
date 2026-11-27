## Pure rules of the Царство Морены roster (GDD design/gdd/bestiary.md §3.4,
## §4 B5, §5 edge cases 1, 7, 16): Карачун's floor wave of ice spikes,
## Снежница's frost marks and the hero's freeze, Сосульник's ceiling drop and
## Мара's ice copies. No nodes, no globals: every number is passed in.
class_name FrostRules
extends RefCounted

## Hit kinds that break an ice copy of Мара at once (§3.4: a breaking blow, the
## Flare, a wall slam). A combo finisher strike counts as a breaking blow.
const COPY_BREAK_KINDS: Array[int] = [Hit.Kind.SLAM, Hit.Kind.FLARE, Hit.Kind.WALL]

# ---------------- Карачун: ground_wave ----------------

## Directions the staff slam sends spikes: both ways with the staff arm, only
## forward (`face`) once the arm is cut (`dirs` < 2).
static func wave_dirs(face: int, dirs: int) -> Array[int]:
	if dirs >= 2:
		return [-1, 1]
	return [face if face != 0 else 1]

## Farthest x the wave front reaches from `x0` going `dir`: max_dist, the room
## edges [lo, hi] and the nearest floor-standing wall (`walls` = Array of
## Vector2(x_left, x_right) spans touching the floor) stop it.
static func wave_end(x0: float, dir: int, max_dist: float, lo: float, hi: float, walls: Array) -> float:
	var end := clampf(x0 + dir * max_dist, lo, hi)
	for wv: Vector2 in walls:
		if dir > 0 and wv.x >= x0 and wv.x < end:
			end = wv.x
		elif dir < 0 and wv.y <= x0 and wv.y > end:
			end = wv.y
	return end

## Front x after `elapsed` s at `speed`, never past `end`.
static func wave_front(x0: float, dir: int, speed: float, elapsed: float, end: float) -> float:
	var x := x0 + dir * speed * elapsed
	return minf(x, end) if dir > 0 else maxf(x, end)

## True when the spikes at the front hit the hero: his feet within `half` px
## (plus half his width) of the front and lower than the spike height above the
## floor (a jump clears them).
static func wave_hits(front: float, hero_feet: Vector2, ground_y: float, spike_h: float, half: float, hero_w: float) -> bool:
	return absf(hero_feet.x - front) <= half + hero_w / 2.0 and hero_feet.y > ground_y - spike_h

# ---------------- Снежница: freeze_stack (B5) ----------------

## Marks after one needle hit: +1 up to `max_marks`; none while the freeze
## guard runs (guard_left > 0) or while frozen.
static func add_mark(marks: int, max_marks: int, guard_left: float, frozen_left: float) -> int:
	if guard_left > 0.0 or frozen_left > 0.0:
		return marks
	return mini(marks + 1, max_marks)

## True when the marks freeze the hero.
static func freezes(marks: int, max_marks: int) -> bool:
	return marks >= max_marks

## One tick of the mark decay: Vector2(marks, clock). A mark falls off every
## `decay` s; the clock restarts on every new mark (the caller sets it to 0).
static func decay_tick(marks: int, clock: float, decay: float, dt: float) -> Vector2:
	if marks <= 0:
		return Vector2(0, 0.0)
	clock += dt
	if clock >= decay:
		return Vector2(marks - 1, clock - decay)
	return Vector2(marks, clock)

## Distance band Снежница keeps: -1 = step back, 1 = step in, 0 = hold.
static func keep_dir(adx: float, keep_min: float, keep_max: float) -> int:
	if adx < keep_min:
		return -1
	if adx > keep_max:
		return 1
	return 0

# ---------------- Сосульник: ceiling_drop ----------------

## True when the hero stands in the drop lane under the icicle: |dx| <= lane and
## below it.
static func under_lane(icicle: Vector2, hero_feet: Vector2, lane: float) -> bool:
	return absf(hero_feet.x - icicle.x) <= lane and hero_feet.y > icicle.y

## Shadow radius on the floor during the shake: grows from r0 to r1 as the shake
## runs out (`left` of `total` s).
static func shadow_r(left: float, total: float, r0: float, r1: float) -> float:
	var k := 1.0 - clampf(left / maxf(total, 0.001), 0.0, 1.0)
	return lerpf(r0, r1, k)

# ---------------- Мара: raise_frozen ----------------

## True when a fallen ally can be raised: within `r` px, a raisable kind (not a
## copy, not a boss, not a Мара, not the dummy, not self-reassembling), and Мара
## has fewer than `max_copies` live copies (edge cases 1-2).
static func can_raise(dist: float, r: float, is_copy: bool, is_boss: bool, kind: String, copies: int, max_copies: int, self_rebuild: bool = false) -> bool:
	return dist <= r and not is_copy and not is_boss and kind != "mara" and kind != "dummy" and not self_rebuild and copies < max_copies

## HP of an ice copy (§3.4: raise_frac = 40% of the original's max HP).
static func copy_hp(orig_max_hp: float, frac: float) -> float:
	return orig_max_hp * frac

## True when a hit breaks an ice copy outright.
static func copy_breaks(kind: int, finisher: bool) -> bool:
	return COPY_BREAK_KINDS.has(kind) or (kind == Hit.Kind.STRIKE and finisher)
