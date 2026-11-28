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
## Armor (armor-and-hero-progression §3.7): slot -> bought tier 0..4, and the
## picked property of tiers 2 / 4 (slot -> {t2, t4}).
var armor: Dictionary = { "head": 0, "torso": 0, "arms": 0, "legs": 0, "cloak": 0 }
var armor_pick: Dictionary = {}
## Капище Рода rules (economy-and-meta §3.4): reroll 0..2, second 0..1, wide 0..1.
var up: Dictionary = { "reroll": 0, "second": 0, "wide": 0 }
## Amulets of Сова (economy §3.10 `lanterns` / `lantern`): bought ids and the worn one.
var lanterns: Dictionary = { "ring": true }
var lantern: String = "ring"
## Dialogue memory (living-world §1.4): said, flags, deaths_by, killed_by_count,
## fresh (events of the last run), visits, last (repeat line -> visit), ambient_recent;
## story wiring (StoryRules): gods_seen, duos_seen, weapons_found, needles,
## death_streak, embers_spent (+_total), wins_no_needle, pending (base events for
## the next visit), god_seen / god_recent (god lines), history (last runs).
var story: Dictionary = story_defaults()
## Difficulty level id (GDD difficulty): "" on a new save until the player
## picks it (reads as «Былина»); old saves migrate to "bylina".
var difficulty: String = ""
## Artifacts (artifacts-and-secrets): id -> true. All of them arrive on the first
## full clear and are never lost (not on death, not by a new run).
var artifacts: Dictionary = {}
## Gods the Prophet switched off (gods-expansion §3.13): they never come in a run.
var gods_off: Array[String] = []
## Runs in a row without a Горн Сварога door (its pity, §3.12).
var svarog_dry: int = 0
var extra: Dictionary = {}

## Defaults of every field (save keys as in economy-and-meta §3.10).
static func defaults() -> Dictionary:
	return { "embers": 0, "res": { "gears": 0, "bronze": 0, "pearls": 0, "cores": 0 },
		"runs": 0, "wins": 0, "bestRooms": 0, "bosses": {},
		"weapon": "stick", "sub": "", "weapons": { "stick": true }, "subs": {}, "pity": { "e": 0, "l": 0 },
		"armor": { "head": 0, "torso": 0, "arms": 0, "legs": 0, "cloak": 0 }, "armor_pick": {},
		"up": { "reroll": 0, "second": 0, "wide": 0 }, "lanterns": { "ring": true }, "lantern": "ring",
		"story": story_defaults(), "difficulty": "", "artifacts": {}, "gods_off": [], "svarog_dry": 0 }

## Empty dialogue memory (living-world §1.4).
static func story_defaults() -> Dictionary:
	return { "said": {}, "flags": {}, "deaths_by": {}, "killed_by_count": {}, "fresh": [],
		"visits": 0, "last": {}, "ambient_recent": [],
		"gods_seen": {}, "duos_seen": {}, "weapons_found": 0, "needles": 0, "death_streak": 0,
		"embers_spent": 0, "embers_spent_total": 0, "wins_no_needle": 0, "pending": [],
		"god_seen": {}, "god_recent": [], "history": [] }

func to_dict() -> Dictionary:
	var d := extra.duplicate(true)
	d.merge({ "embers": embers, "res": res.duplicate(), "runs": runs, "wins": wins,
		"bestRooms": best_rooms, "bosses": bosses.duplicate(), "weapon": weapon, "sub": sub,
		"weapons": weapons.duplicate(), "subs": subs.duplicate(), "pity": pity.duplicate(),
		"armor": armor.duplicate(), "armor_pick": armor_pick.duplicate(true), "up": up.duplicate(),
		"lanterns": lanterns.duplicate(), "lantern": lantern, "story": story.duplicate(true), "difficulty": difficulty, "artifacts": artifacts.duplicate(),
		"gods_off": Array(gods_off), "svarog_dry": svarog_dry }, true)
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
	for k: String in ["armor", "up"]:
		var o: Dictionary = base[k]
		if d.get(k) is Dictionary:
			for id: String in d[k]:
				o[id] = int(d[k][id])
		m.set(k, o)
	if d.get("armor_pick") is Dictionary:
		m.armor_pick = (d.armor_pick as Dictionary).duplicate(true)
	if d.get("lanterns") is Dictionary and not (d.lanterns as Dictionary).is_empty():
		m.lanterns = (d.lanterns as Dictionary).duplicate()
	m.lantern = String(d.get("lantern", "ring")) if d.get("lantern") is String else "ring"
	var st: Dictionary = story_defaults()
	if d.get("story") is Dictionary:
		st.merge((d.story as Dictionary).duplicate(true), true)
	st.visits = int(st.visits)
	for k: String in ["weapons_found", "needles", "death_streak", "embers_spent", "embers_spent_total", "wins_no_needle"]:
		st[k] = int(st[k])
	m.story = st
	m.difficulty = String(d.get("difficulty", "")) if d.get("difficulty") is String else ""
	if d.get("artifacts") is Dictionary:
		for id: Variant in d.artifacts:
			if bool(d.artifacts[id]):
				m.artifacts[String(id)] = true
	if d.get("gods_off") is Array:
		for id: Variant in d.gods_off:
			if not String(id) in m.gods_off:
				m.gods_off.append(String(id))
	m.svarog_dry = int(d.get("svarog_dry", 0))
	for k: String in d:
		if not base.has(k):
			m.extra[k] = d[k]
	return m

## Distinct bosses ever beaten (gods-expansion §3.14 `boss_kinds`).
func boss_kinds() -> int:
	var n := 0
	for k: String in bosses:
		if int(bosses[k]) > 0:
			n += 1
	return n

## Sum of every boss kill (staged unlocks, room-generation §3.14).
func bosses_beaten() -> int:
	var n := 0
	for k: String in bosses:
		n += int(bosses[k])
	return n
