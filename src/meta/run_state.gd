## One run (ADR-0003): route position, hp, runes, loot of the run, rune pacing
## (room-generation §3.8, F4.4) and the RunRng stream states. Data only — no
## nodes. Owned by the Game autoload, passed to the run scene by reference.
class_name RunState
extends RefCounted

## Emitted by systems that change a field (HUD listens).
signal changed(field: StringName)

var run_seed: int = 0
## Location number 1..5 and combat room 1..rooms_per_loc.
var tier: int = 1
var room_k: int = 1
## "room" (combat), "lair" or "haven".
var stage: String = "room"
var hp: float = 100.0
var max_hp: float = 100.0
var charge: float = 0.0
var amulet: String = "ring"
## RunBuild.to_dict().
var build: Dictionary = {}
var embers: int = 0
var res: Dictionary = {}
var since_god: int = 0
var gap_need: int = 1
## Reward promised for the room being played: {type, god}.
var reward: Dictionary = {}
var rooms_cleared: int = 0
var kills: int = 0
var bosses: int = 0
var killed_by: String = ""
## Id of the killer (enemy kind, or the location's boss id) for the dialogue events.
var killer_id: String = ""
var rng_states: Dictionary = {}
## Weapons in hand (weapons-and-loot §3.9 p.6): Weapon.to_dict(), {} = empty.
var arm: Dictionary = {}
var sub: Dictionary = {}
## Weapons dropped by "auto" sources this run (arms_auto_cap, §3.8).
var arms_auto: int = 0
## Story events of this run (StoryRules: rune_first, duo_first, weapon_found,
## needle_found); they become fresh base events at endRun.
var story_ev: Array = []
## The needle of Кощей was found this run (stub until location 5).
var needle: bool = false
## Нить Мокоши tokens spent this run (GDD difficulty F5).
var revives_used: int = 0
## Locations (tiers) where a Горн Сварога door already showed this run (§3.12).
var forge_tiers: Array = []

const FIELDS: Array[String] = ["run_seed", "tier", "room_k", "stage", "hp", "max_hp", "charge", "amulet",
	"build", "embers", "res", "since_god", "gap_need", "reward", "rooms_cleared", "kills", "bosses",
	"killed_by", "killer_id", "rng_states", "arm", "sub", "arms_auto", "story_ev", "needle", "revives_used", "forge_tiers"]

func to_dict() -> Dictionary:
	var d := {}
	for f in FIELDS:
		var v: Variant = get(f)
		d[f] = plain(v)
	return d

## JSON-shaped copy: untyped arrays, whole floats inside dictionaries become
## ints (JSON reads every number as float), so to_dict() == to_dict() after a
## trip through the file.
static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var o := {}
		for k: Variant in v:
			o[String(k)] = _num(plain(v[k]))
		return o
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_num(plain(x)))
		return a
	return v

static func _num(v: Variant) -> Variant:
	return int(v) if v is float and v == floorf(v) and absf(v) < 9.0e15 else v

## Missing fields keep their defaults (old saves load).
static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	for f in FIELDS:
		if not d.has(f):
			continue
		var cur: Variant = r.get(f)
		var v: Variant = d[f]
		if cur is int:
			r.set(f, int(v))
		elif cur is float:
			r.set(f, float(v))
		elif cur is String:
			r.set(f, String(v))
		elif cur is bool:
			r.set(f, bool(v))
		elif cur is Dictionary and v is Dictionary:
			r.set(f, plain(v))
		elif cur is Array and v is Array:
			r.set(f, plain(v))
	var clean := {}
	for k: String in r.res:
		clean[k] = int(r.res[k])
	r.res = clean
	return r

## Adds `n` of resource `id` to the run's loot.
func add_res(id: String, n: int) -> void:
	res[id] = int(res.get(id, 0)) + n
	changed.emit(&"res")
