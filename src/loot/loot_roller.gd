## Rolls a found weapon (GDD weapons-and-loot §3.7, §3.10, §4.1-4.5, edge cases
## 1-6). Pure: the random stream, the tables and the tuning are parameters, the
## pity counters are a Dictionary the caller keeps (MetaState.pity). Order:
## main or sub (4.1) → rarity first, by fixed shares, pity on top (4.2) → kind
## evenly inside that rarity of the drop pool (3.7) → quality (4.3) → affix only
## at ★★★ (4.5).
class_name LootRoller
extends RefCounted

const RARITIES: Array[String] = ["c", "r", "e", "l"]
const GODS: Array[String] = ["kupala", "perun", "stribog", "veles", "zhiva"]

## 4.1: true = main weapon. `kind` "arm"/"sub" forces the slot (Yaga: "arm").
static func roll_is_main(u: float, kind: String, t: Dictionary) -> bool:
	if kind != "":
		return kind == Weapon.ARM
	return u < float(t.get("main_share", 0.6))

## Rarity shares {c, r, e, l} (3.1); `luck` = Обет Рода «Удача» (luck_shift off c,
## luck_split_l of it to l, the rest to e).
static func rarity_weights(luck: bool, t: Dictionary) -> Dictionary:
	var w: Dictionary = (t.get("rar_w", { "c": 50, "r": 32, "e": 13, "l": 5 }) as Dictionary).duplicate()
	if luck:
		var s := float(t.get("luck_shift", 9))
		var sl := float(t.get("luck_split_l", 4))
		w.c = float(w.c) - s
		w.l = float(w.l) + sl
		w.e = float(w.e) + s - sl
	return w

## 4.2 without the pool: the rarity for random `u` (0..1) and the pity counters.
static func roll_rarity(u: float, pity: Dictionary, luck: bool, t: Dictionary) -> String:
	var w := rarity_weights(luck, t)
	if int(pity.get("l", 0)) >= int(t.get("pity_l_max", 25)):
		return "l"
	if int(pity.get("e", 0)) >= int(t.get("pity_e_max", 15)):
		var share_l := float(w.l) / maxf(float(w.e) + float(w.l), 0.001)
		return "l" if u < share_l else "e"
	var x := u * 100.0
	if x < float(w.l):
		return "l"
	if x < float(w.l) + float(w.e):
		return "e"
	if x < float(w.l) + float(w.e) + float(w.r):
		return "r"
	return "c"

## 3.10: counters after a drop of rarity `rar` (mutates `pity`).
static func update_pity(pity: Dictionary, rar: String) -> void:
	var i := RARITIES.find(rar)
	pity["e"] = 0 if i >= 2 else int(pity.get("e", 0)) + 1
	pity["l"] = 0 if i >= 3 else int(pity.get("l", 0)) + 1

## 3.7: kinds that may drop, by rarity. `rows` = weapons.json or subweapons.json,
## `owned` = save.weapons / save.subs (id -> true), `exclude` = the kind in hand
## in this slot and the kinds lying on this room's floor.
static func pool(rows: Dictionary, owned: Dictionary, exclude: Array) -> Dictionary:
	var out := { "c": [], "r": [], "e": [], "l": [] }
	var ids := rows.keys()
	ids.sort()
	for id: String in ids:
		if id.begins_with("_") or not rows[id] is Dictionary:
			continue
		var r: Dictionary = rows[id]
		if bool(r.get("no_drop", false)) or id in exclude:
			continue
		var priced := not (r.get("price", {}) as Dictionary).is_empty()
		if priced and not bool(owned.get(id, false)):
			continue
		var rar := String(r.get("rar", "c"))
		if out.has(rar):
			(out[rar] as Array).append(id)
	return out

## Edge case 1: an empty rarity shifts down (l → e → r → c), then up. "" = all empty.
static func settle_rarity(rar: String, by_rar: Dictionary) -> String:
	var i := RARITIES.find(rar)
	for j in range(i, -1, -1):
		if not (by_rar[RARITIES[j]] as Array).is_empty():
			return RARITIES[j]
	for j in range(i + 1, RARITIES.size()):
		if not (by_rar[RARITIES[j]] as Array).is_empty():
			return RARITIES[j]
	return ""

## 4.3 quality for random `u`: tier = location 1-5, bonus 0/1 (generous source).
static func roll_quality(u: float, tier: int, bonus: int, t: Dictionary) -> int:
	var s := float(t.get("q_tier", 8)) * (tier - 1) + float(t.get("q_bonus", 15)) * bonus
	var x := u * 100.0
	if x < float(t.get("q3_base", 15)) + s:
		return 3
	if x < float(t.get("q2_base", 55)) + s:
		return 2
	return 1

## 4.4.
static func quality_mult(q: int, t: Dictionary) -> float:
	match q:
		2: return float(t.get("q_mult2", 1.15))
		3: return float(t.get("q_mult3", 1.3))
	return 1.0

## 4.5 / 3.6: affix id of a ★★★ weapon. `gods` = gods the hero holds (Rod
## excluded by the caller; empty = all 5). Bans: not_for rows, no_god_affix kinds.
static func roll_affix(rng: RandomNumberGenerator, kind: String, weapon_id: String, weapon_row: Dictionary,
		gods: Array, affixes: Dictionary, t: Dictionary) -> String:
	var god_ids: Array[String] = []
	var craft: Array[String] = []
	var ids := affixes.keys()
	ids.sort()
	for id: String in ids:
		if id.begins_with("_") or not affixes[id] is Dictionary:
			continue
		var a: Dictionary = affixes[id]
		if String(a.get("slot", "")) != kind or weapon_id in (a.get("not_for", []) as Array):
			continue
		if a.has("god"):
			god_ids.append(id)
		else:
			craft.append(id)
	if kind == Weapon.SUB:
		return craft[rng.randi_range(0, craft.size() - 1)] if not craft.is_empty() else ""
	var use_god := not bool(weapon_row.get("no_god_affix", false)) and rng.randf() < float(t.get("affix_god_share", 0.6))
	if use_god:
		var held: Array[String] = []
		for g: String in gods:
			if g in GODS and not g in held:
				held.append(g)
		if held.is_empty():
			held.assign(GODS)
		var g := held[rng.randi_range(0, held.size() - 1)]
		for id in god_ids:
			if String(affixes[id].god) == g:
				return id
	if craft.is_empty():
		return ""
	# Banned crafts (Звонкое on Звонкий меч) leave the pool; the god share stays.
	return craft[rng.randi_range(0, craft.size() - 1)]

## One full roll. ctx: kind ("" / "arm" / "sub"), tier, bonus, luck, gods,
## held_arm, held_sub (ids in hand), floor (ids on this room's floor),
## owned_arms, owned_subs, pity (mutated), rar ("" or a forced rarity: Yaga "l").
## tables: {weapons, subweapons, affixes}. Returns {} when nothing can drop
## (pity does not grow then), else Weapon.to_dict() + {"rar"}.
static func roll(rng: RandomNumberGenerator, ctx: Dictionary, tables: Dictionary, t: Dictionary) -> Dictionary:
	var main := roll_is_main(rng.randf(), String(ctx.get("kind", "")), t)
	var kind := Weapon.ARM if main else Weapon.SUB
	var rows: Dictionary = tables.weapons if main else tables.subweapons
	var exclude: Array = (ctx.get("floor", []) as Array).duplicate()
	exclude.append(String(ctx.get("held_arm" if main else "held_sub", "")))
	var by_rar := pool(rows, ctx.get("owned_arms" if main else "owned_subs", {}), exclude)
	var pity: Dictionary = ctx.get("pity", {})
	var u := rng.randf()
	var want := String(ctx.get("rar", ""))
	if want == "":
		want = roll_rarity(u, pity, bool(ctx.get("luck", false)), t)
	var rar := settle_rarity(want, by_rar)
	if rar == "":
		return {}
	var ids: Array = by_rar[rar]
	var id := String(ids[rng.randi_range(0, ids.size() - 1)])
	update_pity(pity, rar)
	var q := int(ctx.q) if ctx.has("q") else roll_quality(rng.randf(), int(ctx.get("tier", 1)), int(ctx.get("bonus", 0)), t)
	var affix := ""
	if q >= 3:
		affix = roll_affix(rng, kind, id, rows[id], ctx.get("gods", []), tables.affixes, t)
	return { "kind": kind, "id": id, "q": q, "affix": affix, "rar": rar }
