## Builds the list of runes offered at a god's door (GDD gods-and-runes §3.4,
## F9). Pure: the random stream, build and tuning are parameters (ADR-0003: the
## caller passes its named RunRng stream; tests pass a seeded RNG).
class_name RuneOffer
extends RefCounted

## Rune ids to show for `god` ("rod" for a Rod door). `count` = 3, or 4 for
## «Широкий выбор». `opts`: duos_open, legend_open (§3.13 unlocks, default true
## / false). Never contains a held rune, except the repeatable "rest".
static func build_offer(god: String, b: RunBuild, rng: RandomNumberGenerator, tune: Dictionary,
		count: int, opts: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	if god != "rod" and bool(opts.get("duos_open", true)):
		var ds := b.duos_for(god)
		if not ds.is_empty() and rng.randf() < float(tune.get("duo_chance", 0.5)):
			out.append(ds[rng.randi_range(0, ds.size() - 1)])
	if god != "rod" and bool(opts.get("legend_open", false)) and b.table.has("wrath") \
			and not b.has("wrath") and b.slot_gods() == 3 and rng.randf() < float(tune.get("legend_chance", 0.35)):
		out.append("wrath")
	_fill(out, _pool(b, god, int(opts.get("embers", 1 << 30))), count, rng)
	if god != "rod":
		_fill(out, _pool(b, "rod"), count, rng)
	while out.size() < count and b.table.has("rest") and not "rest" in out:
		out.append("rest")
	return out

## Untaken slot runes and passives of `god`, sorted (deterministic before shuffle).
## `embers` = what the hero can pay: a rune whose price asks more is left out
## (Затмение, gods-expansion §3.8).
static func _pool(b: RunBuild, god: String, embers: int = 1 << 30) -> Array[String]:
	var out: Array[String] = []
	for id: String in b.table:
		if id.begins_with("_"):
			continue
		var r := b.row(id)
		if String(r.get("god", "")) == god and String(r.get("slot", "")) in ["strike", "dash", "flare", "passive"] \
				and not b.has(id) and int(b.price(id).get("embers", 0)) <= embers:
			out.append(id)
	out.sort()
	return out

static func _fill(out: Array[String], pool: Array[String], count: int, rng: RandomNumberGenerator) -> void:
	var p := pool.duplicate()
	for i in range(p.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: String = p[i]
		p[i] = p[j]
		p[j] = t
	for id: String in p:
		if out.size() >= count:
			return
		if not id in out:
			out.append(id)
