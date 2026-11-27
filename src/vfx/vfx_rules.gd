## Pure rules of the game-feel VFX pass (design/art/vfx-spec.md): which material
## an enemy kind bleeds, how many particles a burst gets at a particles level,
## when a hit counts as heavy. Static and data-in (vfx.json, enemies.json rows),
## so tests drive it without a scene.
class_name VfxRules
extends RefCounted

## Particles levels of the «Частицы» setting.
const LEVEL_OFF: int = 0
const LEVEL_LOW: int = 1
const LEVEL_HIGH: int = 2
## Names shown in the settings screen, by level.
const LEVEL_NAMES: Array[String] = ["выкл", "мало", "много"]

## Material of a kind: the enemies.json row's "material" when vfx.json knows it,
## else vfx.json kind_material[kind], else default_material ("flesh").
static func material_of(kind_id: String, enemies: Dictionary, vfx: Dictionary) -> String:
	var mats: Dictionary = vfx.get("materials", {})
	var row: Variant = enemies.get(kind_id, {})
	if row is Dictionary:
		var m := String((row as Dictionary).get("material", ""))
		if mats.has(m):
			return m
	var k := String((vfx.get("kind_material", {}) as Dictionary).get(kind_id, ""))
	if mats.has(k):
		return k
	var d := String(vfx.get("default_material", "flesh"))
	return d if mats.has(d) else (String(mats.keys()[0]) if not mats.is_empty() else "")

## The material a hit shows: a blow stopped by a front shield rings as metal.
static func hit_material(base: String, blocked_by_shield: bool) -> String:
	return "metal" if blocked_by_shield else base

## Count multiplier of a particles level (vfx.json "levels"; unknown = 1).
static func level_mult(level: int, vfx: Dictionary, key: String = "levels") -> float:
	return float((vfx.get(key, {}) as Dictionary).get(str(level), 1.0))

## Particles of one emitter: n × level × (heavy_mult when heavy) × extra.
## A spec with "always" never drops below its own n·extra (readability: hit
## flash, parry ring); "always_n" keeps at least that many at any level.
static func count(spec: Dictionary, level: int, heavy: bool, vfx: Dictionary, extra: float = 1.0) -> int:
	var n := float(spec.get("n", 1)) * extra
	if bool(spec.get("always", false)):
		return maxi(1, roundi(n))
	var k := level_mult(level, vfx)
	if heavy:
		k *= float(vfx.get("heavy_mult", 1.8))
	return maxi(roundi(n * k), int(spec.get("always_n", 0)) if level > LEVEL_OFF else 0)

## True when a hit should get the big burst: a finisher, a slam or wall slam,
## a cut limb, or damage of at least heavy_frac of the enemy's max hp.
static func is_heavy(kind: int, finisher: bool, limb: String, amount: float, max_hp: float, vfx: Dictionary) -> bool:
	if finisher or limb != "" or kind == Hit.Kind.SLAM or kind == Hit.Kind.WALL:
		return true
	return max_hp > 0.0 and amount >= max_hp * float(vfx.get("heavy_frac", 0.34))

## True when a hit gets no burst at all (status ticks, auras).
static func silent(kind: int) -> bool:
	return kind == Hit.Kind.TICK or kind == Hit.Kind.STATUS

## Unit direction a burst flies: away from the attacker along x, tilted up by
## `up_deg` (screen y grows down). from_x == at_x flies to `fallback` side.
static func hit_dir(at_x: float, from_x: float, up_deg: float = 0.0, fallback: int = 1) -> Vector2:
	var sx := signf(at_x - from_x)
	if sx == 0.0:
		sx = float(fallback)
	return Vector2(sx, 0.0).rotated(-sx * deg_to_rad(up_deg))

## Contact point on a w×h body (origin at the feet) facing an attacker at from_x.
static func hit_point(feet: Vector2, w: float, h: float, from_x: float) -> Vector2:
	var hw := w * 0.5
	return Vector2(clampf(from_x, feet.x - hw * 0.8, feet.x + hw * 0.8), feet.y - h * 0.55)

## Settings level clamped to 0..2.
static func clamp_level(v: int) -> int:
	return clampi(v, LEVEL_OFF, LEVEL_HIGH)
