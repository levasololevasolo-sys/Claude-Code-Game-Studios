## Purchases at the base (GDD economy-and-meta §3.4, §3.6; armor-and-hero-
## progression §3.2, §3.5, §4.1): paying from the MetaState bank, Потап's armor
## tiers (in order, even-growth rule), Сова's amulets, Капище Рода's rules.
## Pure logic: tables come in as parsed armor.json / base.json.
## A cost is { "embers": n, "res": { res_id: n } }.
class_name ShopRules
extends RefCounted

# ---------------- bank ----------------

## True when the bank holds the whole cost.
static func can_pay(meta: MetaState, cost: Dictionary) -> bool:
	return missing(meta, cost).is_empty()

## What the bank lacks: { "embers": n, res_id: n } (empty = affordable).
static func missing(meta: MetaState, cost: Dictionary) -> Dictionary:
	var out := {}
	var e := int(cost.get("embers", 0))
	if meta.embers < e:
		out["embers"] = e - meta.embers
	var res: Dictionary = cost.get("res", {})
	for k: String in res:
		var have := int(meta.res.get(k, 0))
		if have < int(res[k]):
			out[k] = int(res[k]) - have
	return out

## Takes the cost from the bank; false (and nothing taken) when it falls short.
static func pay(meta: MetaState, cost: Dictionary) -> bool:
	if not can_pay(meta, cost):
		return false
	meta.embers -= int(cost.get("embers", 0))
	var res: Dictionary = cost.get("res", {})
	for k: String in res:
		meta.res[k] = int(meta.res.get(k, 0)) - int(res[k])
	return true

## "угли 150, железо 12" for a cost.
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(cost.get("embers", 0)) > 0:
		parts.append("угли %d" % int(cost.embers))
	var res: Dictionary = cost.get("res", {})
	for k: String in res:
		parts.append("%s %d" % [RunDirector.res_name(k), int(res[k])])
	return ", ".join(parts) if not parts.is_empty() else "даром"

# ---------------- armor (Потап) ----------------

## Price of tier `t` (1..max) of `slot` (armor §4.1).
static func armor_price(slot: String, t: int, cfg: Dictionary) -> Dictionary:
	var s: Dictionary = cfg.slots[slot]
	var scale := float(cfg.get("cost_scale", 1.0))
	var res := {}
	res[String(s.res1 if t == 1 else s.res)] = roundi(float(cfg.r1) * pow(float(cfg.gr), t - 1) * scale)
	var hearts: Array = cfg.get("hearts", [])
	var h := int(hearts[t - 1]) if t - 1 < hearts.size() else 0
	if h > 0:
		res[String(cfg.get("hearts_res", "cores"))] = h
	return { "embers": roundi(float(cfg.e1) * pow(float(cfg.g), t - 1) * scale), "res": res }

## Why the next tier of `slot` cannot be bought ("" = it can), armor §3.5.
static func armor_block(meta: MetaState, slot: String, cfg: Dictionary) -> String:
	var cur := int(meta.armor.get(slot, 0))
	if cur >= int(cfg.get("max_tier", 4)):
		return "Уже на максимуме"
	var t := cur + 1
	var need := t - int(cfg.get("even_gap", 2))
	for s: String in cfg.slots:
		if int(meta.armor.get(s, 0)) < need:
			return "Сначала доведи «%s» до яруса %d" % [String(cfg.slots[s].name), need]
	var miss := missing(meta, armor_price(slot, t, cfg))
	if not miss.is_empty():
		var parts: PackedStringArray = []
		for k: String in miss:
			parts.append("%s %d" % ["угли" if k == "embers" else RunDirector.res_name(k), int(miss[k])])
		return "Не хватает: " + ", ".join(parts)
	return ""

## Buys the next tier of `slot`; false when armor_block() says no.
static func buy_armor(meta: MetaState, slot: String, cfg: Dictionary) -> bool:
	if armor_block(meta, slot, cfg) != "":
		return false
	var t := int(meta.armor.get(slot, 0)) + 1
	pay(meta, armor_price(slot, t, cfg))
	meta.armor[slot] = t
	if t == 2 or t == 4:
		var pick: Dictionary = meta.armor_pick.get(slot, {})
		pick["t%d" % t] = String(pick.get("t%d" % t, "a"))
		meta.armor_pick[slot] = pick
	return true

## Dresses `visual` (HeroVisual) in `armor`: every part of a slot shows the
## bought tier + 1 (art bible tiers 1-5; missing pictures fall back to tier 1).
static func dress(visual: Node, armor: Dictionary, cfg: Dictionary) -> void:
	if visual == null or not visual.has_method("set_tier"):
		return
	for slot: String in cfg.get("slots", {}):
		for part: String in cfg.slots[slot].parts:
			visual.call("set_tier", part, int(armor.get(slot, 0)) + 1)

# ---------------- amulets (Сова) ----------------

## Price of amulet `id` from base.json `amulets`.
static func amulet_price(id: String, base: Dictionary) -> Dictionary:
	var row: Dictionary = base.get("amulets", {}).get(id, {})
	var res := {}
	for k: String in row:
		if k != "embers":
			res[k] = int(row[k])
	return { "embers": int(row.get("embers", 0)), "res": res }

## Owned (or free) amulet: wears it. Else buys and wears it. False when unaffordable.
static func take_amulet(meta: MetaState, id: String, base: Dictionary) -> bool:
	if not base.get("amulets", {}).has(id):
		return false
	if not meta.lanterns.has(id):
		if not pay(meta, amulet_price(id, base)):
			return false
		meta.lanterns[id] = true
	meta.lantern = id
	return true

# ---------------- Капище Рода (Чур) ----------------

## Price of the next level of rule `id`, -1 when it is at its top level.
static func up_price(meta: MetaState, id: String, base: Dictionary) -> int:
	var prices: Array = base.kapishe[id].prices
	var lvl := int(meta.up.get(id, 0))
	if lvl >= prices.size():
		return -1
	return roundi(float(prices[lvl]) * float(base.get("up_cost_scale", 1.0)))

## Buys the next level of rule `id`; false at the top or when short of embers.
static func buy_up(meta: MetaState, id: String, base: Dictionary) -> bool:
	var p := up_price(meta, id, base)
	if p < 0 or not pay(meta, { "embers": p }):
		return false
	meta.up[id] = int(meta.up.get(id, 0)) + 1
	return true
