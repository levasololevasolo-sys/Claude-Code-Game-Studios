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
	"thrower": preload("res://src/enemies/thrower.gd"),
	"bloat": preload("res://src/enemies/bloat.gd"),
	"knight": preload("res://src/enemies/knight.gd"),
	"ringer": preload("res://src/enemies/ringer.gd"),
	"rootling": preload("res://src/enemies/rootling.gd"),
	"wolf": preload("res://src/enemies/wolf.gd"),
	"jelly": preload("res://src/enemies/cold_spirit.gd"),
	"balvan": preload("res://src/enemies/balvan.gd"),
	"shishiga": preload("res://src/enemies/shishiga.gd"),
	"bognitsa": preload("res://src/enemies/bognitsa.gd"),
	"vodyanitsa": preload("res://src/enemies/vodyanitsa.gd"),
	"karachun": preload("res://src/enemies/karachun.gd"),
	"snezhnitsa": preload("res://src/enemies/snezhnitsa.gd"),
	"sosulnik": preload("res://src/enemies/sosulnik.gd"),
	"mara": preload("res://src/enemies/mara.gd"),
	"suchkovik": preload("res://src/enemies/suchkovik.gd"),
	"lesavka": preload("res://src/enemies/lesavka.gd"),
}

## New, not yet set up enemy of `kind` (null for an unknown kind).
static func make(kind: String) -> Enemy:
	if not KINDS.has(kind):
		push_error("EnemyRoster: unknown kind '%s'" % kind)
		return null
	return (KINDS[kind] as GDScript).new() as Enemy

## Roster of location `tier` (enemies-and-elites §3.3): {roster, late, intro}
## from locations.json, falling back to tuning swamp_roster / swamp_late.
## intro (bestiary §3.6) = kind -> first room k; {} = the old roster rules.
static func for_tier(tier: int, locs: Dictionary, t: Dictionary) -> Dictionary:
	var row: Dictionary = locs.get(str(tier), {})
	return { "roster": row.get("roster", t.get("swamp_roster", [])), "late": row.get("late", t.get("swamp_late", [])),
		"intro": row.get("intro", {}) }

## Kind id with spawn spot `spot` (enemies.json "spot", e.g. "bog") among the
## keys of `intro`; "" = none.
static func spot_kind(intro: Dictionary, table: Dictionary, spot: String) -> String:
	for id: String in intro:
		var row: Dictionary = table.get(id, {})
		if String(row.get("spot", "")) == spot:
			return id
	return ""

## Pack of a location with an `intro` map (bestiary §3.6-3.7): kinds open from
## their room k; the lead cycles through them; caps per pack: pack_role_max by
## enemies.json pack_role (support/ranged/bruiser/flyer/ambusher), a support
## only from pack_support_min members, pack_min of a kind (Шишиги by 2), at most
## pack_kinds_max[tier] distinct kinds; the rest is filled from the k = 1 row.
## Kinds with a spawn spot stay out of packs while `spot_ok` (the room places
## them on its markers); without spots they join packs already surfaced.
static func pack_kinds_intro(rng: RandomNumberGenerator, size: int, pack_i: int, k: int, tier: int,
		intro: Dictionary, table: Dictionary, t: Dictionary, spot_ok: bool = true) -> Array[String]:
	var out: Array[String] = []
	var open: Array[String] = []
	var first: Array[String] = []
	for id: String in intro:
		var row: Dictionary = table.get(id, {})
		if String(row.get("spot", "")) != "" and (spot_ok or bool(row.get("spot_only", false))):
			continue
		if int(intro[id]) <= k:
			open.append(id)
			if int(intro[id]) <= 1:
				first.append(id)
	if open.is_empty():
		return out
	if first.is_empty():
		first = open
	_add_kind(out, open[(k + pack_i) % open.size()], size, tier, table, t)
	var guard := 0
	while out.size() < size and guard < 48:
		guard += 1
		var pool: Array[String] = open if guard < 24 else first
		_add_kind(out, pool[rng.randi_range(0, pool.size() - 1)], size, tier, table, t)
	while out.size() < size:
		var added := false
		for id: String in out.duplicate() + first:
			if _add_kind(out, id, size, tier, table, t) > 0:
				added = true
				break
		if not added:
			break
	return out

## How many of `id` can join `out` now under the §3.7 caps (0 = none).
static func kind_fits(out: Array[String], id: String, size: int, tier: int, table: Dictionary, t: Dictionary) -> int:
	var row: Dictionary = table.get(id, {})
	var role := String(row.get("pack_role", "fodder"))
	var kinds := {}
	var same_role := 0
	for o: String in out:
		kinds[o] = true
		if String((table.get(o, {}) as Dictionary).get("pack_role", "fodder")) == role:
			same_role += 1
	var kmax_arr: Array = t.get("pack_kinds_max", [99])
	if not kinds.has(id) and kinds.size() >= int(kmax_arr[clampi(tier - 1, 0, kmax_arr.size() - 1)]):
		return 0
	if role == "support" and size < int(t.get("pack_support_min", 3)):
		return 0
	var caps: Dictionary = t.get("pack_role_max", {})
	var n := maxi(1, int(row.get("pack_min", 1)) - out.count(id))
	if bool(row.get("pack_pairs", false)):
		n = 2  # Снежные волки only in pairs (bestiary §3.7 item 4).
	# §3.7.2: some roles are capped per kind (two ambushers of one kind), not per role.
	var per_kind: Array = t.get("pack_role_per_kind", [])
	var have := out.count(id) if per_kind.has(role) else same_role
	if caps.has(role) and have + n > int(caps[role]):
		return 0
	if out.size() + n > size:
		return 0
	return n

static func _add_kind(out: Array[String], id: String, size: int, tier: int, table: Dictionary, t: Dictionary) -> int:
	var n := kind_fits(out, id, size, tier, table, t)
	for i in n:
		out.append(id)
	return n

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
