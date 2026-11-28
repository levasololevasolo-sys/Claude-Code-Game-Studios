## Door forks and rune pacing (GDD room-generation-and-doors §3.8, §3.9, §3.14,
## §3.16, F4.4, F4.6, edge cases 2, 3, 15). Pure: the random stream and the
## tuning are parameters (ADR-0003). A door is {type, god} where god is "" except
## for "god" doors. Not yet: cache, yaga, knight helmets (later steps).
class_name DoorRules
extends RefCounted

## Rewards that reset sinceGod.
const GOD_TYPES: Array[String] = ["god", "rod", "surica", "svarog"]
## Ordinary door types implemented now, with their tuning weight keys.
const ORDINARY: Array[String] = ["arms", "loot", "heal"]

## F4.4: is it time for a god?
static func god_time(since_god: int, gap_need: int) -> bool:
	return since_god >= gap_need

## gapNeed ∈ gap_need [lo, hi] (default {1, 2}, 50/50).
static func roll_gap(rng: RandomNumberGenerator, t: Dictionary) -> int:
	var g: Array = t.get("gap_need", [1, 2])
	return rng.randi_range(int(g[0]), int(g[1]))

## After a reward of `type`: god / rod / surica reset sinceGod and reroll gapNeed,
## anything else adds 1.
static func apply_pacing(run: RunState, type: String, rng: RandomNumberGenerator, t: Dictionary) -> void:
	if type in GOD_TYPES:
		run.since_god = 0
		run.gap_need = roll_gap(rng, t)
	else:
		run.since_god += 1

## Staged unlocks (§3.14, gods-and-runes §3.13): {gods, types}. `runs_done` =
## finished runs before this one, `bosses` = bosses ever beaten.
static func unlocks(runs_done: int, bosses: int, all_gods: Array[String], t: Dictionary) -> Dictionary:
	var gods: Array[String] = []
	var types: Array[String] = ["god", "loot", "heal"]
	if runs_done < int(t.get("unlock_all_gods_runs", 1)):
		gods.append(String(t.get("first_run_god", "kupala")))
	else:
		gods.assign(all_gods)
		types.append_array(["rod", "arms"])
	if bosses >= 1:
		types.append("surica")
	return { "gods": gods, "types": types }

## Builds a fork. ctx: god_time (bool), gods (open gods), types (open types),
## can_surica (the hero holds a rune below max level).
## ctx also: held (gods the hero holds: their doors are god_held_w times more
## likely, gods-expansion §3.6 balance note), svarog_ok (the forge may show).
static func make_fork(rng: RandomNumberGenerator, ctx: Dictionary, t: Dictionary) -> Array[Dictionary]:
	var n := 3 if rng.randf() < float(t.get("fork_three", 0.45)) else 2
	var doors: Array[Dictionary] = []
	var types: Array = ctx.get("types", [])
	var gods: Array = ctx.get("gods", [])
	var held: Array = ctx.get("held", [])
	var hw := float(t.get("god_held_w", 1.0))
	if bool(ctx.get("god_time", false)) and "god" in types and not gods.is_empty():
		doors.append(_god_door(rng, gods, doors, held, hw))
		while doors.size() < n:
			if _free_gods(gods, doors).size() > 0 and rng.randf() < float(t.get("god_other_chance", 0.5)):
				doors.append(_god_door(rng, gods, doors, held, hw))
			elif "surica" in types and bool(ctx.get("can_surica", false)) and not _has(doors, "surica") \
					and rng.randf() < float(t.get("surica_chance", 0.35)):
				doors.append({ "type": "surica", "god": "" })
			elif "rod" in types and not _has(doors, "rod") and rng.randf() < float(t.get("rod_chance", 0.4)):
				doors.append({ "type": "rod", "god": "" })
			else:
				doors.append(ordinary(rng, doors, types, t))
	else:
		while doors.size() < n:
			doors.append(ordinary(rng, doors, types, t))
	if bool(ctx.get("svarog_ok", false)) and svarog_roll(rng, int(ctx.get("svarog_dry", 0)), t):
		var at := doors.size() - 1
		for i in range(doors.size() - 1, -1, -1):
			if doors[i].type != "god":
				at = i
				break
		doors[at] = { "type": "svarog", "god": "svarog" }
	return doors

## Горн Сварога roll (gods-expansion §3.12, F): svarog_chance, × svarog_dry_mult
## after svarog_dry_runs runs in a row without one.
static func svarog_roll(rng: RandomNumberGenerator, dry: int, t: Dictionary) -> bool:
	var c := float(t.get("svarog_chance", 0.05))
	if dry >= int(t.get("svarog_dry_runs", 3)):
		c *= float(t.get("svarog_dry_mult", 2.0))
	return rng.randf() < c

## May a forge door show now: open, location ≥ svarog_min_loc, none yet in this
## location, fewer than svarog_per_run upgrades, and something left to offer.
static func svarog_ok(open: bool, tier: int, tiers_seen: Array, taken: int, offer_left: int, t: Dictionary) -> bool:
	return open and tier >= int(t.get("svarog_min_loc", 2)) and not tier in tiers_seen \
		and taken < int(t.get("svarog_per_run", 2)) and offer_left > 0

## Rune gods open for these stats (gods-expansion §3.14): rows of `gods_tbl`
## of kind "runes" (not Rod) whose `unlock` minimums are all met. stats: runs,
## bosses, boss_kinds, wins. Sorted.
static func gods_open(gods_tbl: Dictionary, stats: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in gods_tbl:
		var r: Variant = gods_tbl[id]
		if id.begins_with("_") or not r is Dictionary or id == "rod":
			continue
		if String((r as Dictionary).get("kind", "runes")) != "runes":
			continue
		var need: Dictionary = (r as Dictionary).get("unlock", {})
		var ok := true
		for k: String in need:
			ok = ok and int(stats.get(k, 0)) >= int(need[k])
		if ok:
			out.append(id)
	out.sort()
	return out

## The Prophet's choice (§3.13): `open` minus `off` (only gods with toggle);
## fewer than `min_on` left -> every open god.
static func enabled_gods(open: Array[String], off: Array[String], gods_tbl: Dictionary, min_on: int) -> Array[String]:
	var out: Array[String] = []
	for g in open:
		var tog := bool((gods_tbl.get(g, {}) as Dictionary).get("toggle", true))
		if not tog or not g in off:
			out.append(g)
	if out.size() < mini(min_on, open.size()):
		return open.duplicate()
	return out

## F4.6: weighted ordinary door not yet in the fork; empty pool -> loot (edge 2).
static func ordinary(rng: RandomNumberGenerator, doors: Array[Dictionary], types: Array, t: Dictionary) -> Dictionary:
	var pool: Array[String] = []
	var total := 0.0
	for ty in ORDINARY:
		if ty in types and not _has(doors, ty) and float(t.get(ty + "_w", 0.0)) > 0.0:
			pool.append(ty)
			total += float(t.get(ty + "_w", 0.0))
	if pool.is_empty():
		return { "type": "loot", "god": "" }
	var roll := rng.randf() * total
	for ty in pool:
		roll -= float(t.get(ty + "_w", 0.0))
		if roll < 0.0:
			return { "type": ty, "god": "" }
	return { "type": pool[-1], "god": "" }

## Room 1 of a location (§3.8 last line): a random god's rune if it is god time, else ordinary.
static func first_room_reward(rng: RandomNumberGenerator, ctx: Dictionary, t: Dictionary) -> Dictionary:
	var gods: Array = ctx.get("gods", [])
	if bool(ctx.get("god_time", false)) and not gods.is_empty():
		return _god_door(rng, gods, [])
	return ordinary(rng, [], ctx.get("types", []), t)

## Lair reward (§3.16, gods-and-runes §3.3): up to `count` different open gods;
## if the hero lacks some open god, at least one card is such a god.
static func lair_gods(rng: RandomNumberGenerator, open_gods: Array, held: Array, count: int) -> Array[String]:
	var pool: Array[String] = []
	pool.assign(open_gods)
	pool.sort()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array[String] = []
	out.assign(pool.slice(0, mini(count, pool.size())))
	var fresh: Array[String] = []
	fresh.assign(pool.filter(func(g: String) -> bool: return not g in held))
	if not fresh.is_empty() and out.all(func(g: String) -> bool: return g in held):
		out[out.size() - 1] = fresh[rng.randi_range(0, fresh.size() - 1)]
	return out

static func _god_door(rng: RandomNumberGenerator, gods: Array, doors: Array, held: Array = [], hw: float = 1.0) -> Dictionary:
	var free := _free_gods(gods, doors)
	if held.is_empty() or hw == 1.0:
		return { "type": "god", "god": free[rng.randi_range(0, free.size() - 1)] }
	var total := 0.0
	for g in free:
		total += hw if g in held else 1.0
	var roll := rng.randf() * total
	for g in free:
		roll -= hw if g in held else 1.0
		if roll < 0.0:
			return { "type": "god", "god": g }
	return { "type": "god", "god": free[-1] }

static func _free_gods(gods: Array, doors: Array) -> Array[String]:
	var out: Array[String] = []
	for g: String in gods:
		if not doors.any(func(d: Dictionary) -> bool: return d.type == "god" and d.god == g):
			out.append(g)
	out.sort()
	return out

static func _has(doors: Array, type: String) -> bool:
	return doors.any(func(d: Dictionary) -> bool: return d.type == type)
