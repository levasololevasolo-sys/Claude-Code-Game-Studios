## Artifacts and the clear count (GDD design/gdd/artifacts-and-secrets.md):
## permanent key items, all granted at once on the first full clear (meta.wins
## 0 -> 1), kept forever, never lost on death. Each opens one seal kind in the
## levels. The number of full clears also drives the bosses' extra move sets
## (boss_ng.json). Pure functions over MetaState and the artifacts table.
class_name Artifacts
extends RefCounted

## The artifact rows of `tbl` (artifacts.json): [{id, name, desc, hint, icon, seal, color}].
static func rows(tbl: Dictionary) -> Array:
	return tbl.get("artifacts", []) as Array

## Row of artifact `id` ({} when unknown).
static func row(tbl: Dictionary, id: String) -> Dictionary:
	for r: Dictionary in rows(tbl):
		if String(r.get("id", "")) == id:
			return r
	return {}

## The artifact that opens seal kind `seal` ({} when none does).
static func for_seal(tbl: Dictionary, seal: String) -> Dictionary:
	for r: Dictionary in rows(tbl):
		if String(r.get("seal", "")) == seal:
			return r
	return {}

## True when `meta` owns artifact `id`.
static func owned(meta: MetaState, id: String) -> bool:
	return meta != null and bool(meta.artifacts.get(id, false))

## True when `meta` can open seal kind `seal` (owns the artifact for it).
static func can_open(meta: MetaState, tbl: Dictionary, seal: String) -> bool:
	var r := for_seal(tbl, seal)
	return not r.is_empty() and owned(meta, String(r.id))

## Grants every artifact `meta` lacks once it has at least one full clear (also
## repairs a save that won before artifacts existed). Returns the new ids.
static func grant_if_cleared(meta: MetaState, tbl: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if meta == null or meta.wins < 1:
		return out
	for r: Dictionary in rows(tbl):
		var id := String(r.get("id", ""))
		if id != "" and not meta.artifacts.has(id):
			meta.artifacts[id] = true
			out.append(id)
	return out

## Full clears that count for the bosses' extra moves (= meta.wins).
static func clears(meta: MetaState) -> int:
	return meta.wins if meta != null else 0
