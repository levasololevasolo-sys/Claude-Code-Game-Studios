## One weapon instance in a slot or on the floor (GDD weapons-and-loot §3.3-3.6,
## §3.9): kind ("arm" main / "sub" secondary), id, quality 1-3, affix id ("" =
## none). Stats are read from the rows of weapons.json / subweapons.json /
## weapon_bodies.json / affixes.json (ADR-0001) and tuning.json; the tables are
## injectable so the class is testable without the Tune autoload.
class_name Weapon
extends RefCounted

const ARM: String = "arm"
const SUB: String = "sub"
## Rarity colours (§3.1).
const RAR_COLOUR: Dictionary = { "c": "#d8cfb8", "r": "#6fb6ff", "e": "#c77dff", "l": "#ffb347" }
const RAR_NAME: Dictionary = { "c": "Обычное", "r": "Редкое", "e": "Эпическое", "l": "Легендарное" }
const Q_NAME: Array[String] = ["", "Простое", "Добротное", "Заветное"]

var kind: String = ARM
var id: String = ""
var q: int = 1
var affix: String = ""
## Tables: {weapons, subweapons, bodies, affixes, tune}. Empty = read Tune.
var tables: Dictionary = {}

## A new instance. `p_tables` as in `tables` (tests pass fixtures).
static func make(p_id: String, p_kind: String = ARM, p_q: int = 1, p_affix: String = "", p_tables: Dictionary = {}) -> Weapon:
	var w := Weapon.new()
	w.id = p_id
	w.kind = p_kind
	w.q = clampi(p_q, 1, 3)
	w.affix = p_affix
	w.tables = p_tables
	return w

## Save form (§3.9 p.6: id, quality, affix).
func to_dict() -> Dictionary:
	return { "kind": kind, "id": id, "q": q, "affix": affix }

## From to_dict(); null for an empty dictionary or an id missing from the data
## (edge case 18: a cut kind does not load).
static func from_dict(d: Dictionary, p_tables: Dictionary = {}) -> Weapon:
	if d.is_empty() or String(d.get("id", "")) == "":
		return null
	var w := make(String(d.id), String(d.get("kind", ARM)), int(d.get("q", 1)), String(d.get("affix", "")), p_tables)
	return w if not w.row().is_empty() else null

func copy() -> Weapon:
	return make(id, kind, q, affix, tables)

func _t(name: String) -> Dictionary:
	if tables.has(name):
		return tables[name]
	if name == "tune":
		return Tune.data
	return Tune.table(name)

## The weapon's row ({} if unknown).
func row() -> Dictionary:
	var t := _t("weapons" if kind == ARM else "subweapons")
	return t.get(id, {}) if t.get(id) is Dictionary else {}

## The strike body row of a main weapon.
func body() -> Dictionary:
	var b := _t("weapon_bodies")
	return b.get(String(row().get("body", "blade")), {})

func body_id() -> String:
	return String(row().get("body", ""))

func affix_row() -> Dictionary:
	if affix == "":
		return {}
	var a := _t("affixes")
	return a.get(affix, {}) if a.get(affix) is Dictionary else {}

func mech() -> String:
	return String(row().get("mech", ""))

func rarity() -> String:
	return String(row().get("rar", "c"))

## §4.4 qMult.
func quality_mult() -> float:
	return LootRoller.quality_mult(q, _t("tune"))

## Damage multiplier over strike_dmg × combo mult (main) or the absolute damage
## multiplier (sub): row dmg × qMult (× 1.4 «Тяжёлое» for subs).
func dmg_mult() -> float:
	var m := quality_mult()
	if kind == ARM:
		return float(row().get("dmg", 1.0)) * m
	return m * float(affix_row().get("dmg", 1.0))

## Swing speed multiplier (row spd × «Быстрое»). Quality does not change it (§3.5).
func speed() -> float:
	return float(row().get("spd", 1.0)) * float(affix_row().get("speed", 1.0))

## Reach multiplier (row reach × «Длинное»).
func reach_mult() -> float:
	return float(row().get("reach", 1.0)) * float(affix_row().get("reach", 1.0))

## Swing times of the combo, scaled by speed().
func times() -> Array:
	var out: Array = []
	for x: Variant in body().get("times", [0.3]):
		out.append(float(x) / speed())
	return out

## Hit reach in px (before the «Широкий взмах» rune).
func reach() -> float:
	return float(body().get("reach", 78.0)) * reach_mult()

## Amulet charge factor per hit: body charge × Звонкий меч × «Звонкое».
func charge() -> float:
	return float(body().get("charge", 1.0)) * float(row().get("charge_mult", 1.0)) * float(affix_row().get("charge", 1.0))

## Sub: cooldown in s (× «Скорое»).
func cooldown() -> float:
	return float(row().get("cd", 1.0)) * float(affix_row().get("cd", 1.0))

## Sub: damage of one hit.
func sub_dmg() -> float:
	return float(row().get("dmg", 0.0)) * dmg_mult()

## Name with the affix prefix (§3.9 p.1: «[приставка ·] название»).
func title() -> String:
	var n := String(row().get("name", id))
	var a := String(affix_row().get("name", ""))
	return n if a == "" else "%s · %s" % [a, n]

## "★★☆" style quality string.
func stars() -> String:
	return "★".repeat(q) + "☆".repeat(3 - q)

func colour() -> Color:
	return Color(String(RAR_COLOUR.get(rarity(), "#d8cfb8")))

## Numbers the comparison card shows (§3.9): dmg = mean damage of one hit,
## speed = hits per second over a full combo (main) / shots per s (sub),
## reach = px (main) / 0 (sub).
func card_stats() -> Dictionary:
	var tune := _t("tune")
	if kind == SUB:
		var hits := 2.0 if String(affix_row().get("twice", "")) != "" or affix == "s_twice" else 1.0
		return { "dmg": sub_dmg() * float(row().get("count", 1)) * hits, "speed": 1.0 / maxf(cooldown(), 0.01), "reach": 0.0 }
	var mults: Array = body().get("mult", [1.0])
	var tm := times()
	var sum_m := 0.0
	var sum_t := 0.0
	for i in mults.size():
		sum_m += float(mults[i])
		sum_t += float(tm[mini(i, tm.size() - 1)])
	return { "dmg": float(tune.get("strike_dmg", 11.0)) * dmg_mult() * sum_m / maxf(mults.size(), 1),
		"speed": mults.size() / maxf(sum_t, 0.01), "reach": reach() }
