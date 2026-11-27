## Pure formulas and shape hit tests of the amulet and the Flare (GDD
## amulet-and-flare §3, §4 F1-F5). No nodes, no autoloads: every number comes in
## as a parameter, `tune` is the tuning dictionary (Tune.data in the game, a
## fixture in tests). Geometry works on Rect2 hit boxes (Enemy.hurt_rect()).
class_name AmuletRules
extends RefCounted

# ---------------- charge (F1, F2) ----------------

## F1: adds `gain` (already multiplied by everything except k_over) to charge `c`.
## Below `ready` the gain counts in full; the part past `ready` counts × over_gain;
## the result is clamped to [0, cap]. A cap at or below `ready` loses the excess
## (first run, §3.10).
static func add_charge(c: float, gain: float, cap: float, ready: float, over_gain: float) -> float:
	if gain <= 0.0:
		return clampf(c, 0.0, cap)
	var out := c
	if out < ready:
		var to_ready := ready - out
		if gain <= to_ready:
			return clampf(out + gain, 0.0, cap)
		out = ready
		gain -= to_ready
	out += gain * over_gain
	return clampf(out, 0.0, cap)

## F1: the hit-based gain before k_over:
## charge_per_hit × f × k_weapon × k_kindling × (1 + chg_amulet).
static func hit_gain(charge_per_hit: float, f: float, k_weapon: float = 1.0,
		k_kindling: float = 1.0, chg_amulet: float = 0.0) -> float:
	return charge_per_hit * f * k_weapon * k_kindling * (1.0 + chg_amulet)

## F2: charge after the hero took health damage. Only above `ready` (overcharge)
## anything happens: to `ready` with a forgiving amulet (Коло), else to
## ready - over_spill. A hit fully taken by a shield never gets here.
static func after_health_hit(c: float, ready: float, over_spill: float, keeps_ready: bool) -> float:
	if c <= ready:
		return c
	return ready if keeps_ready else ready - over_spill

## The cap of the charge: first run 100 (§3.10), forge level 2+ c_cap_l2, else c_cap.
static func cap_for(level: int, first_run: bool, tune: Dictionary) -> float:
	if first_run:
		return float(tune.get("c_cap_first_run", 100.0))
	return float(tune.get("c_cap_l2", 200.0)) if level >= 2 else float(tune.get("c_cap", 150.0))

# ---------------- power and size (F3) ----------------

## F3: P = c / 100 (the charge at the moment of the press).
static func power(c: float, ready: float = 100.0) -> float:
	return c / maxf(ready, 0.001)

## F3: S = 0.5 + 0.5 × P, the multiplier of every size of the shape.
static func size_mult(p: float, tune: Dictionary) -> float:
	return float(tune.get("flare_size_base", 0.5)) + float(tune.get("flare_size_per_power", 0.5)) * p

## F3: D = flare_dmg × shape_dmg × P × (1 + bright_step × up_bright).
static func flare_damage(flare_dmg: float, shape_dmg: float, p: float, up_bright: int = 0, bright_step: float = 0.15) -> float:
	return flare_dmg * shape_dmg * p * (1.0 + bright_step * float(up_bright))

# ---------------- light and darkness (F4, F5) ----------------

## Light level 0..1 of the soft hero circle at distance `d` from its centre for
## radius `r`: 1 up to full_frac·R, linear to mid_level at mid_frac·R, linear to 0 at R.
static func light_at(d: float, r: float, full_frac: float, mid_frac: float, mid_level: float) -> float:
	if r <= 0.0 or d >= r:
		return 0.0
	var x := d / r
	if x <= full_frac:
		return 1.0
	if x <= mid_frac:
		return lerpf(1.0, mid_level, (x - full_frac) / maxf(mid_frac - full_frac, 0.0001))
	return lerpf(mid_level, 0.0, (x - mid_frac) / maxf(1.0 - mid_frac, 0.0001))

## F4: the fraction of R where the soft circle lifts exactly half of the darkness
## (0.714 for the default 0.15 / 0.6 / 0.7 profile).
static func half_light_frac(full_frac: float, mid_frac: float, mid_level: float) -> float:
	if mid_level <= 0.5:
		return full_frac + (mid_frac - full_frac) * (1.0 - 0.5) / maxf(1.0 - mid_level, 0.0001)
	return mid_frac + (1.0 - mid_frac) * (mid_level - 0.5) / mid_level

## F4: light_min = ceil(threat_reach / half_light_frac).
static func light_min(tune: Dictionary) -> float:
	var k := half_light_frac(float(tune.get("light_full_frac", 0.15)), float(tune.get("light_mid_frac", 0.6)),
		float(tune.get("light_mid_level", 0.7)))
	return ceilf(float(tune.get("threat_reach", 256.0)) / maxf(k, 0.0001))

## F4: R_light = max(light_min, light_base + min(c,100)/100 × light_gain)
## + over_glow × max(0, c − 100)/100; × 1.4 at the base (`hub_mult`).
static func light_radius(c: float, tune: Dictionary, hub_mult: float = 1.0) -> float:
	var ready := float(tune.get("charge_ready", 100.0))
	var base := float(tune.get("light_base", 360.0)) + minf(c, ready) / ready * float(tune.get("light_gain", 200.0))
	var r := maxf(light_min(tune), base) + float(tune.get("over_glow", 60.0)) * maxf(0.0, c - ready) / ready
	return r * hub_mult

## F5: dk = clamp(darkness × k_calm + ash_dark × ash_level, 0, max) × (1 − flash_dim × flash).
static func darkness(tune: Dictionary, calm: bool = false, ash_level: int = 0, flash: float = 0.0) -> float:
	var k_calm := float(tune.get("darkness_calm", 0.55)) if calm else 1.0
	var dk := clampf(float(tune.get("darkness", 0.78)) * k_calm + float(tune.get("ash_dark", 0.08)) * float(ash_level),
		0.0, float(tune.get("darkness_max", 0.95)))
	return dk * (1.0 - float(tune.get("flash_dim", 0.9)) * clampf(flash, 0.0, 1.0))

# ---------------- shape hit tests (§3.5) ----------------

## Distance from point `p` to the nearest point of `r` (0 inside).
static func dist_to_rect(p: Vector2, r: Rect2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q)

## Коло: the target's edge is closer than `radius` to the hero's chest.
static func ring_hits(chest: Vector2, target: Rect2, radius: float) -> bool:
	return dist_to_rect(chest, target) < radius

## Луч: the beam rectangle from the chest forward (`face` -1/1), `length` long and
## `height` tall, cut at the room edges [0, room_w] (room_w <= 0 = no walls).
static func beam_rect(chest: Vector2, face: int, length: float, height: float, room_w: float) -> Rect2:
	var x0 := chest.x
	var x1 := chest.x + float(signi(face) if face != 0 else 1) * length
	if room_w > 0.0:
		x1 = clampf(x1, 0.0, room_w)
	return Rect2(minf(x0, x1), chest.y - height / 2.0, absf(x1 - x0), height)

## Луч: the target box overlaps the beam.
static func beam_hits(beam: Rect2, target: Rect2) -> bool:
	return beam.intersects(target)

## Волна / Узел: the surface under (x, y): Vector3(x0, surface_y, x1). `plats` are
## Vector3(x, y, width) one-way platforms; the nearest one at or below `y` whose
## span holds `x` wins, else the floor [0, room_w] at ground_y.
static func surface_under(x: float, y: float, plats: Array, ground_y: float, room_w: float) -> Vector3:
	var best := Vector3(0.0, ground_y, room_w if room_w > 0.0 else INF)
	for p: Vector3 in plats:
		if x >= p.x and x <= p.x + p.z and p.y >= y - 1.0 and p.y < best.y:
			best = Vector3(p.x, p.y, p.x + p.z)
	return best

## Волна: the swept band of one wave front this tick, from front x `x_prev` to
## `x_now`, standing `height` px above `surface_y`.
static func wave_band(x_prev: float, x_now: float, surface_y: float, height: float) -> Rect2:
	return Rect2(minf(x_prev, x_now), surface_y - height, absf(x_now - x_prev), height)

## Волна: front x after `t` s for a wave from `origin` going `dir` at `speed`,
## stopped at the surface edges [x0, x1].
static func wave_front(origin: float, dir: int, speed: float, t: float, x0: float, x1: float) -> float:
	return clampf(origin + float(dir) * speed * t, x0, x1)

## Узел: an enemy is near enough to set the knot off.
static func knot_triggered(knot: Vector2, targets: Array, trigger: float) -> bool:
	for r: Rect2 in targets:
		if dist_to_rect(knot, r) < trigger:
			return true
	return false

## Узел: pull velocity of a target at `at` towards `centre` (px/s), divided by
## weight and scaled for bosses; zero once it is at the centre.
static func pull_velocity(at: Vector2, centre: Vector2, speed: float, weight: float, k: float = 1.0) -> Vector2:
	var d := centre - at
	if d.length() < 1.0:
		return Vector2.ZERO
	return d.normalized() * speed * k / maxf(weight, DamageRules.MIN_WEIGHT)
