## Difficulty level (GDD design/gdd/difficulty.md): «Сказка», «Былина», «Навь».
## The ONE place that turns the chosen level into numbers; every caller (Enemy
## setup and dmg_mult, Player and RunDirector heals, RunDirector embers, Player
## revive) asks this class, never a literal. Levels live in
## assets/data/difficulty.json; a missing level or key reads as identity (1.0,
## 0 revives), so «Былина» is exactly the game before difficulty existed.
## Separate from Пепел (economy-and-meta): both multiply.
## `current` is set by the Game autoload from MetaState.difficulty.
class_name Difficulty
extends RefCounted

## Level used when the save has none or an unknown id.
const DEFAULT: String = "bylina"
## Keys whose missing value is 0 instead of the identity 1.0.
const ZERO_KEYS: Array[String] = ["revives"]

## The level in force (Game sets it on load and on change; tests set it directly).
static var current: String = DEFAULT

## The difficulty table (assets/data/difficulty.json).
static func table() -> Dictionary:
	return Tune.table("difficulty")

## Level ids in menu order.
static func order(t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in t.get("order", [DEFAULT]):
		out.append(String(id))
	return out

## `id` if the table knows it, else the table default (old or broken saves).
static func normalize(id: String, t: Dictionary) -> String:
	var levels: Dictionary = t.get("levels", {})
	return id if levels.has(id) else String(t.get("default", DEFAULT))

## Value of `key` at `level`: identity (1.0, or 0 for ZERO_KEYS) when missing.
static func value(level: String, key: String, t: Dictionary) -> float:
	var levels: Dictionary = t.get("levels", {})
	var row: Dictionary = levels.get(normalize(level, t), {})
	return float(row.get(key, 0.0 if key in ZERO_KEYS else 1.0))

## Value of `key` at the current level.
static func f(key: String) -> float:
	return value(current, key, table())

## Display name of `level` («Былина»).
static func name_of(level: String, t: Dictionary) -> String:
	var levels: Dictionary = t.get("levels", {})
	return String((levels.get(normalize(level, t), {}) as Dictionary).get("name", level))

## Heal amount after the level's heal multiplier (F3).
static func heal_for(amount: float, level: String, t: Dictionary) -> float:
	return amount * value(level, "heal", t)

## Heal at the current level.
static func heal(amount: float) -> float:
	return heal_for(amount, current, table())

## Embers multiplier: tuning embers_mult × level embers (F4).
static func embers_mult_for(base_mult: float, level: String, t: Dictionary) -> float:
	return base_mult * value(level, "embers", t)

## Embers multiplier at the current level.
static func embers_mult() -> float:
	return embers_mult_for(Tune.f("embers_mult"), current, table())

## Revive tokens of one run at `level` (F5).
static func revives_for(level: String, t: Dictionary) -> int:
	return maxi(0, roundi(value(level, "revives", t)))

## True for a stat key that is an attack wind-up time ("wind", "*_wind").
## min_windup is not one: it is the readability floor and never shrinks.
static func is_windup_key(key: String, t: Dictionary) -> bool:
	var keys: Array = t.get("windup_keys", ["wind"])
	return key in keys or key.ends_with(String(t.get("windup_suffix", "_wind")))

## Copy of an enemy stats row with every wind-up key × windup (F2). The input
## row is never changed (it is the shared Tune row). Identity returns `stats`.
static func scale_windups(stats: Dictionary, level: String, t: Dictionary) -> Dictionary:
	var m := value(level, "windup", t)
	if is_equal_approx(m, 1.0):
		return stats
	var out := stats.duplicate(true)
	for k: String in out:
		if is_windup_key(k, t) and (out[k] is float or out[k] is int):
			out[k] = float(out[k]) * m
	return out
