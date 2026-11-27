## Which enemy kinds make up a pack, and the factory from kind id to node.
## Pure logic except make(). Rules: GDD enemies-and-elites §3.2 (at most
## max_flyers_per_pack flyers in a pack), §3.3 (roster + late kinds), prototype genWaves.
class_name EnemyRoster
extends RefCounted

## Kind id -> script. A new kind = one file + one line here + one row in enemies.json.
const KINDS: Dictionary = {
	"crawler": preload("res://src/enemies/crawler.gd"),
	"bat": preload("res://src/enemies/bat.gd"),
	"sentry": preload("res://src/enemies/sentry.gd"),
	"bloat": preload("res://src/enemies/bloat.gd"),
	"knight": preload("res://src/enemies/knight.gd"),
	"ringer": preload("res://src/enemies/ringer.gd"),
	"rootling": preload("res://src/enemies/rootling.gd"),
}

## New, not yet set up enemy of `kind` (null for an unknown kind).
static func make(kind: String) -> Enemy:
	if not KINDS.has(kind):
		push_error("EnemyRoster: unknown kind '%s'" % kind)
		return null
	return (KINDS[kind] as GDScript).new() as Enemy

## Roster of location `tier` (enemies-and-elites §3.3): {roster, late} from
## locations.json, falling back to tuning swamp_roster / swamp_late.
static func for_tier(tier: int, locs: Dictionary, t: Dictionary) -> Dictionary:
	var row: Dictionary = locs.get(str(tier), {})
	return { "roster": row.get("roster", t.get("swamp_roster", [])), "late": row.get("late", t.get("swamp_late", [])) }

## Kinds of the `size` members of pack number `pack_i` (0-based) in room k of `tier`.
## `table` is the enemy table (flies flags), `t` the tuning dictionary.
static func pack_kinds(rng: RandomNumberGenerator, size: int, pack_i: int, k: int, tier: int,
		roster: Array, late: Array, table: Dictionary, t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if roster.is_empty():
		return out
	if tier == 1 and k == 1:
		for i in size:
			out.append(String(roster[0]))
		return out
	var pool: Array = roster.duplicate()
	if k >= int(t.get("late_from_room", 3)) or tier >= int(t.get("late_from_tier", 2)):
		pool.append_array(late)
	var max_fly := int(t.get("max_flyers_per_pack", 2))
	var flyers := 0
	var lead := String(roster[(k + pack_i) % roster.size()])
	out.append(lead)
	if _flies(lead, table):
		flyers += 1
	var ground: Array = pool.filter(func(id: Variant) -> bool: return not _flies(String(id), table))
	while out.size() < size:
		var id := String(pool[rng.randi_range(0, pool.size() - 1)])
		if _flies(id, table):
			if flyers >= max_fly:
				if ground.is_empty():
					break
				id = String(ground[rng.randi_range(0, ground.size() - 1)])
			else:
				flyers += 1
		out.append(id)
	return out

static func _flies(id: String, table: Dictionary) -> bool:
	var row: Variant = table.get(id)
	return row is Dictionary and bool((row as Dictionary).get("flies", false))
