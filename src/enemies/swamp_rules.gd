## Pure rules of the Топь Кикиморы roster (GDD design/gdd/bestiary.md §3.2, §4 B4,
## B7): Болванчик's forward swing, Шишига's cling and shake-off, Болотница's
## false hummock, Водяница's tina shield. No nodes, no globals: every number is
## passed in, so the unit tests feed fixtures.
class_name SwampRules
extends RefCounted

## Hero actions that throw a clinging Шишига off (§3.2: dash, roll, pogo off a foe).
const SHAKE_ACTIONS: Array[StringName] = [&"dash", &"roll", &"pogo"]

## Hero hit box from his feet position (Player.W x Player.H).
static func hero_rect(feet: Vector2) -> Rect2:
	return Rect2(feet.x - Player.W / 2.0, feet.y - Player.H, Player.W, Player.H)

## Strike box in front of an enemy at `feet` facing `face`: from its centre to
## w/2 + reach forward, `tall` px up from the feet.
static func front_rect(feet: Vector2, face: int, w: float, reach: float, tall: float) -> Rect2:
	var len := w / 2.0 + reach
	var x0 := feet.x if face > 0 else feet.x - len
	return Rect2(x0, feet.y - tall, len, tall)

## True when the hero at `hero_feet` is inside the forward swing (Болванчик, the
## arm blows of Болотница and Водяница).
static func swing_hits(feet: Vector2, face: int, w: float, reach: float, tall: float, hero_feet: Vector2) -> bool:
	return front_rect(feet, face, w, reach, tall).intersects(hero_rect(hero_feet))

## True when the hero is close enough to start a forward blow (|dx| < range_x,
## |dy| < range_y).
static func in_reach(dx: float, dy: float, range_x: float, range_y: float) -> bool:
	return absf(dx) < range_x and absf(dy) < range_y

## B7: hero speed multiplier with `n` Шишиги on him (n is capped at `max_n`).
static func cling_slow_mult(n: int, per: float, max_n: int) -> float:
	return maxf(0.0, 1.0 - per * float(clampi(n, 0, max_n)))

## A Шишига may latch only while fewer than `max_n` already hang on the hero.
static func can_latch(n_on_hero: int, max_n: int) -> bool:
	return n_on_hero < max_n

## True when the hero action throws a clinging Шишига off.
static func shakes_off(action: StringName) -> bool:
	return SHAKE_ACTIONS.has(action)

## True when the cling has lasted its time and the Шишига lets go by itself.
static func cling_over(clung_for: float, cling_time: float) -> bool:
	return clung_for >= cling_time

## True when the hero's feet stand on the hummock whose top centre is `top`
## (width `hw`): on the floor of a body, within the width, at its height.
static func on_hummock(hero_feet: Vector2, hero_on_floor: bool, top: Vector2, hw: float) -> bool:
	return hero_on_floor and absf(hero_feet.x - top.x) <= hw / 2.0 and absf(hero_feet.y - top.y) <= 4.0

## Time the hero has stood on the hummock after this tick (resets when he steps off).
static func stand_tick(stand_t: float, standing: bool, dt: float) -> float:
	return stand_t + dt if standing else 0.0

## The dive starts after the hero stood `need` s on the hummock (§3.2: 0.4 s).
static func dive_ready(stand_t: float, need: float) -> bool:
	return stand_t >= need

## Where Болотница surfaces after the dive: `dx` px beside the hero on the side
## she came from, kept inside [lo, hi].
static func rise_x(hero_x: float, from_x: float, dx: float, lo: float, hi: float) -> float:
	var side := 1.0 if from_x >= hero_x else -1.0
	var x := hero_x + side * dx
	if x < lo or x > hi:
		x = hero_x - side * dx
	return clampf(x, lo, hi)

## B4: tina shield an ally gets from the song.
static func tina_amount(ally_max_hp: float, frac: float) -> float:
	return ally_max_hp * frac

## Damage into the tina shield first: Vector2(absorbed, left over).
static func tina_absorb(tina: float, dmg: float) -> Vector2:
	var a := clampf(dmg, 0.0, maxf(tina, 0.0))
	return Vector2(a, dmg - a)

## Any hit or stun breaks the song (§3.2). True when the song must stop.
static func song_broken(singing: bool, hit_taken: bool, stunned: bool) -> bool:
	return singing and (hit_taken or stunned)
