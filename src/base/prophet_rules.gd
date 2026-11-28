## The Prophet's rules (gods-expansion §3.13): after the first win the Пророк
## at the base lets the player call or send away the gods a run may meet.
## Only open gods with "toggle" count; at least `min_on` of them stay called
## (tuning gods_min_on), at most all. The choice lives in MetaState.gods_off.
class_name ProphetRules
extends RefCounted

## Unlock stats of `m` for DoorRules.gods_open (§3.14).
static func stats(m: MetaState) -> Dictionary:
	return { "runs": maxi(m.runs, 1), "bosses": m.bosses_beaten(), "boss_kinds": m.boss_kinds(), "wins": m.wins }

## Open gods the Prophet can switch, in gods.json order.
static func gods(m: MetaState, tbl: Dictionary) -> Array[String]:
	var open := DoorRules.gods_open(tbl, stats(m))
	var out: Array[String] = []
	for id: String in tbl:
		if id in open and bool((tbl[id] as Dictionary).get("toggle", true)):
			out.append(id)
	return out

## True when god `g` is called (not in gods_off).
static func is_on(m: MetaState, g: String) -> bool:
	return not g in m.gods_off

## Called gods among the switchable ones.
static func on_count(m: MetaState, tbl: Dictionary) -> int:
	var n := 0
	for g in gods(m, tbl):
		if is_on(m, g):
			n += 1
	return n

## Why `g` cannot be switched now ("" = it can): sending one away is refused
## when only `min_on` stay called.
static func block(m: MetaState, tbl: Dictionary, g: String, min_on: int) -> String:
	if not g in gods(m, tbl):
		return "Этот бог ещё не явился"
	if is_on(m, g) and on_count(m, tbl) <= min_on:
		return "Нужно не меньше %d богов" % min_on
	return ""

## Switches god `g`; false (and no change) when block() refuses it.
static func toggle(m: MetaState, tbl: Dictionary, g: String, min_on: int) -> bool:
	if block(m, tbl, g, min_on) != "":
		return false
	if is_on(m, g):
		m.gods_off.append(g)
	else:
		m.gods_off.erase(g)
	return true
