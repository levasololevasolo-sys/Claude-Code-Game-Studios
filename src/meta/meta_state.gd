## Everything kept between runs (ADR-0003, GDD economy-and-meta §3.10). Data only.
## Fields this version does not know yet are kept in `extra` and written back,
## so an older build never drops what a newer one saved.
class_name MetaState
extends RefCounted

var embers: int = 0
## Bank of resources and hearts: gears, bronze, pearls, cores.
var res: Dictionary = {}
var runs: int = 0
var wins: int = 0
var best_rooms: int = 0
## Boss id -> times beaten.
var bosses: Dictionary = {}
## Weapons (weapons-and-loot §3.7, §3.10, AC 13): the main / secondary kind a run
## starts with, bought kinds (id -> true), and the pity counters {e, l}.
var weapon: String = "stick"
var sub: String = ""
var weapons: Dictionary = { "stick": true }
var subs: Dictionary = {}
var pity: Dictionary = { "e": 0, "l": 0 }
var extra: Dictionary = {}

## Defaults of every field (save keys as in economy-and-meta §3.10).
static func defaults() -> Dictionary:
	return { "embers": 0, "res": { "gears": 0, "bronze": 0, "pearls": 0, "cores": 0 },
		"runs": 0, "wins": 0, "bestRooms": 0, "bosses": {},
		"weapon": "stick", "sub": "", "weapons": { "stick": true }, "subs": {}, "pity": { "e": 0, "l": 0 } }

func to_dict() -> Dictionary:
	var d := extra.duplicate(true)
	d.merge({ "embers": embers, "res": res.duplicate(), "runs": runs, "wins": wins,
		"bestRooms": best_rooms, "bosses": bosses.duplicate(), "weapon": weapon, "sub": sub,
		"weapons": weapons.duplicate(), "subs": subs.duplicate(), "pity": pity.duplicate() }, true)
	return d

## Merges `d` over defaults(): a missing field gets its default.
static func from_dict(d: Dictionary) -> MetaState:
	var m := MetaState.new()
	var base := defaults()
	var r: Dictionary = base.res
	if d.get("res") is Dictionary:
		for k: String in d.res:
			r[k] = int(d.res[k])
	m.embers = int(d.get("embers", base.embers))
	m.res = r
	m.runs = int(d.get("runs", 0))
	m.wins = int(d.get("wins", 0))
	m.best_rooms = int(d.get("bestRooms", 0))
	var b: Dictionary = {}
	if d.get("bosses") is Dictionary:
		for k: String in d.bosses:
			b[k] = int(d.bosses[k])
	m.bosses = b
	m.weapon = String(d.get("weapon", "stick"))
	m.sub = String(d.get("sub", "")) if d.get("sub") is String else ""
	for k: String in ["weapons", "subs"]:
		var o: Dictionary = {}
		if d.get(k) is Dictionary:
			for id: String in d[k]:
				o[id] = bool(d[k][id])
		if k == "weapons":
			o["stick"] = true
			m.weapons = o
		else:
			m.subs = o
	if d.get("pity") is Dictionary:
		m.pity = { "e": int(d.pity.get("e", 0)), "l": int(d.pity.get("l", 0)) }
	for k: String in d:
		if not base.has(k):
			m.extra[k] = d[k]
	return m

## Sum of every boss kill (staged unlocks, room-generation §3.14).
func bosses_beaten() -> int:
	var n := 0
	for k: String in bosses:
		n += int(bosses[k])
	return n
