## The hero's runes for one run (GDD gods-and-runes §3.2, §3.10-3.12): the three
## combat slots (Удар, Рывок, Вспышка), unlimited Свойства, duos and the legend,
## rune levels 1-3. Turns the build into what combat reads: status payloads for
## a Hit (payload()), damage multipliers (damage_mods()) and the status context
## enemies use (ctx()). All numbers come from assets/data/runes.json (`table`)
## and tuning (`tune` parameters). Injected into the hero: player.build = build.
class_name RunBuild
extends RefCounted

## Combat slots in Гнев богов order (§3.12: Удар → Рывок → Вспышка → Удар).
const COMBAT_SLOTS: Array[String] = ["strike", "dash", "flare"]
## Slot labels shown to the player.
const SLOT_LABEL: Dictionary = { "strike": "Удар", "dash": "Рывок", "flare": "Вспышка",
	"passive": "Свойство", "duo": "Союз", "legend": "Легенда", "rest": "Отдых" }
const MAX_LEVEL: int = 3

## Rows of runes.json (id -> row). Injected in tests.
var table: Dictionary = {}
## Rune id per combat slot, "" = empty.
var slots: Dictionary = { "strike": "", "dash": "", "flare": "" }
## Level of every taken slot rune and passive (duos/legend have none).
var levels: Dictionary = {}
var passives: Array[String] = []
var duos: Array[String] = []
var legends: Array[String] = []
var _ctx: Dictionary = {}

## A build reading `p_table` (empty = Tune.table("runes")).
static func make(p_table: Dictionary = {}) -> RunBuild:
	var b := RunBuild.new()
	b.table = p_table if not p_table.is_empty() else Tune.table("runes")
	return b

## Parses the `--runes=` argument: "svarog_s:2,perun_d,duo_storm". Unknown ids
## are reported and skipped.
static func from_arg(arg: String, p_table: Dictionary = {}) -> RunBuild:
	var b := make(p_table)
	for part in arg.split(",", false):
		var bits := part.strip_edges().split(":")
		var id := bits[0]
		if not b.table.has(id) or id.begins_with("_"):
			push_error("RunBuild: unknown rune '%s' in --runes" % id)
			continue
		b.take(id)
		if bits.size() > 1:
			for i in clampi(int(bits[1]), 1, MAX_LEVEL) - 1:
				b.level_up(id)
	return b

## Save snapshot (ADR-0003 RunState.build): ids and levels only.
func to_dict() -> Dictionary:
	return { "slots": slots.duplicate(), "levels": levels.duplicate(), "passives": Array(passives),
		"duos": Array(duos), "legends": Array(legends) }

## Rebuilds a build from to_dict(). Unknown ids are dropped.
static func from_dict(d: Dictionary, p_table: Dictionary = {}) -> RunBuild:
	var b := make(p_table)
	var s: Dictionary = d.get("slots", {})
	for k: String in b.slots:
		var id := String(s.get(k, ""))
		b.slots[k] = id if b.table.has(id) else ""
	for id: String in (d.get("levels", {}) as Dictionary):
		if b.table.has(id):
			b.levels[id] = int(d.levels[id])
	for key: String in ["passives", "duos", "legends"]:
		var arr: Array[String] = b.get(key)
		for id: Variant in (d.get(key, []) as Array):
			if b.table.has(String(id)):
				arr.append(String(id))
	return b

## Held runes that Сурица can raise (level < MAX_LEVEL), sorted (§3.10).
func raisable() -> Array[String]:
	var out: Array[String] = []
	for id: String in levels:
		if has(id) and int(levels[id]) < MAX_LEVEL:
			out.append(id)
	out.sort()
	return out

## Every held rune id: slots, passives, duos, legend.
func held() -> Array[String]:
	var out: Array[String] = []
	for s in COMBAT_SLOTS:
		if slots[s] != "":
			out.append(slots[s])
	out.append_array(passives + duos + legends)
	return out

func row(id: String) -> Dictionary:
	var r: Variant = table.get(id, {})
	return r if r is Dictionary else {}

## Slot of a rune id ("strike", "passive", "duo"...).
func slot_of(id: String) -> String:
	return String(row(id).get("slot", ""))

## God of a rune id ("" for duos and the legend).
func god_of(id: String) -> String:
	return String(row(id).get("god", ""))

## Takes rune `id` (§3.2). A combat-slot rune replaces the old one of its slot
## together with its level; returns the replaced id ("" if none). Taking a rune
## already held does nothing ("rest" can be taken again and is not stored).
func take(id: String) -> String:
	var slot := slot_of(id)
	if slot == "" or (has(id) and slot != "rest"):
		return ""
	var old := ""
	match slot:
		"strike", "dash", "flare":
			old = slots[slot]
			if old != "":
				levels.erase(old)
			slots[slot] = id
			levels[id] = 1
		"passive":
			passives.append(id)
			levels[id] = 1
		"duo":
			duos.append(id)
		"legend":
			legends.append(id)
	_ctx.clear()
	return old

## True when rune `id` is in the build.
func has(id: String) -> bool:
	return id in slots.values() or id in passives or id in duos or id in legends

## Level of a held rune (0 = not held or no levels).
func level(id: String) -> int:
	return int(levels.get(id, 0))

## Сурица (§3.10): +1 level, at most 3. False when it cannot rise.
func level_up(id: String) -> bool:
	if not levels.has(id) or int(levels[id]) >= MAX_LEVEL:
		return false
	levels[id] = int(levels[id]) + 1
	_ctx.clear()
	return true

## Value `key` of a HELD rune at its level: arrays are per-level (§3.10), a
## scalar is level-independent. Not held -> `fallback`.
func value(id: String, key: String, fallback: float = 0.0) -> float:
	if not has(id):
		return fallback
	return level_value(row(id), key, maxi(level(id), 1), fallback)

## Value `key` of a row at level `lvl` (1-3).
static func level_value(r: Dictionary, key: String, lvl: int, fallback: float = 0.0) -> float:
	var v: Variant = r.get(key, null)
	if v is Array:
		var arr: Array = v
		return float(arr[clampi(lvl, 1, arr.size()) - 1]) if not arr.is_empty() else fallback
	if v == null:
		return fallback
	return float(v)

## God of the rune in a combat slot ("" when empty).
func slot_god(slot: String) -> String:
	var id: String = slots.get(slot, "")
	return god_of(id) if id != "" else ""

## godsTaken (§3.2): every god but Rod with at least one slot rune or passive.
func gods_taken() -> Array[String]:
	var out: Array[String] = []
	for id: String in slots.values() + passives:
		var g := god_of(id)
		if id != "" and g != "" and g != "rod" and not g in out:
			out.append(g)
	return out

## slotGods (§3.2): distinct gods (not Rod) in the three combat slots, 0-3.
func slot_gods() -> int:
	var seen: Array[String] = []
	for s in COMBAT_SLOTS:
		var g := slot_god(s)
		if g != "" and g != "rod" and not g in seen:
			seen.append(g)
	return seen.size()

## Every duo of the data whose both gods the hero has and which is not taken
## (§3.4 step 1). Data-driven: a duo is any row with slot "duo" and "gods".
func available_duos() -> Array[String]:
	var mine := gods_taken()
	var out: Array[String] = []
	for id: String in table:
		var r := row(id)
		if id.begins_with("_") or String(r.get("slot", "")) != "duo" or has(id):
			continue
		var gs: Array = r.get("gods", [])
		if gs.size() == 2 and String(gs[0]) in mine and String(gs[1]) in mine:
			out.append(id)
	out.sort()
	return out

## available_duos() that involve `god` (the god whose door was opened).
func duos_for(god: String) -> Array[String]:
	var out: Array[String] = []
	for id in available_duos():
		if god in (row(id).get("gods", []) as Array):
			out.append(id)
	return out

## Flare element (amulet-and-flare §3.6): god of the Flare-slot rune, or pure.
func flare_element() -> String:
	var g := slot_god("flare")
	return g if g != "" and g != "rod" else FlareElement.PURE

## movement-and-combat F5 with the rune factors: «Лёгкая поступь», «Вихрь».
## `legs` (armour) and `vow` (Обет Перуна) are hooks, 0 and 1 for now.
func dash_cd(tune: Dictionary, dash_dur: float, legs: float = 0.0, vow: float = 1.0) -> float:
	var raw := float(tune.get("dash_cooldown", 0.55)) * value("swift", "cd", 1.0) * (1.0 - legs) * vow
	if slots.dash != "":
		raw *= float(row(slots.dash).get("dash_cd_mult", 1.0))
	return maxf(maxf(float(tune.get("dash_cd_floor", 0.25)), dash_dur + float(tune.get("dash_gap", 0.2))), raw)

## Damage multipliers for Hit.mods (DamageRules.status_mult). `strike` adds edge.
func damage_mods(strike: bool) -> Dictionary:
	var m := {}
	if has("svarog_p"):
		m["heat"] = value("svarog_p", "heat", 1.0)
	if has("reaper"):
		m["reaper"] = value("reaper", "mult", 1.0)
	if strike and has("edge"):
		m["edge"] = value("edge", "mult", 1.0)
	return m

## The status context enemies read (StatusSet.tick, Enemy._discharge): shock
## stacks needed, extra jumps, root multiplier, duo rows by id, damage mods.
func ctx(tune: Dictionary) -> Dictionary:
	if not _ctx.is_empty():
		return _ctx
	var d := {}
	for id in duos:
		d[id] = row(id)
	var need := int(tune.get("shock_stacks", 3))
	var bonus := int(value("perun_p", "jumps", 0.0))
	if d.has("duo_storm"):
		need = int((d["duo_storm"] as Dictionary).get("shock_stacks", need))
		bonus += int((d["duo_storm"] as Dictionary).get("jumps", 1))
	_ctx = { "shock_need": need, "jumps_bonus": bonus, "root_mult": value("zhiva_p", "root_mult", 1.0),
		"shield_on_rooted": value("zhiva_p", "shield_on_rooted", 0.0), "duos": d, "mods": damage_mods(false) }
	return _ctx

## Statuses the rune in combat `slot` puts on one enemy (§3.5, §3.10), plus the
## Гнев богов second status (§3.12) unless `nested`. `power` = Flare power P
## (1 for strikes and dashes); `finisher` = last swing of the combo.
func payload(slot: String, power: float, tune: Dictionary, finisher: bool = false, nested: bool = false) -> Dictionary:
	var id: String = slots.get(slot, "")
	if id == "":
		return {}
	var r := row(id)
	var lvl := maxi(level(id), 1)
	var p := {}
	if not (bool(r.get("finisher_only", false)) and not finisher):
		var amount := level_value(r, "amount", lvl, 0.0) * (power if bool(r.get("scale_p", false)) else 1.0)
		_add_status(p, String(r.get("status", "")), amount, tune)
		if String(r.get("status", "")) == "discharge":
			p["extra_jumps"] = int(level_value(r, "jumps", lvl, 0.0))
	if r.has("boss_burst_min"):
		p["boss_burst_min"] = int(r["boss_burst_min"])
	if not nested and not p.is_empty() and has("wrath"):
		var i := COMBAT_SLOTS.find(slot)
		var next_god := slot_god(COMBAT_SLOTS[(i + 1) % COMBAT_SLOTS.size()])
		if next_god != "" and next_god != "rod":
			var st := String((Tune.table("gods").get(next_god, {}) as Dictionary).get("wrath_status", ""))
			_add_status(p, st, float(tune.get("wrath_power", 0.5)), tune)
	return p

## Adds status `st` of strength `amount` to payload `p`: durations take the
## larger, stacks add (0.5 rounds up to 1 stack, §3.12).
static func _add_status(p: Dictionary, st: String, amount: float, tune: Dictionary) -> void:
	if amount <= 0.0 and st != "discharge":
		return
	match st:
		"burn":
			p["burn"] = maxf(float(p.get("burn", 0.0)), float(tune.get("burn_time", 3.0)) * amount)
		"curse":
			p["curse"] = maxf(float(p.get("curse", 0.0)), float(tune.get("curse_time", 6.0)) * amount)
		"root":
			p["root"] = maxf(float(p.get("root", 0.0)), float(tune.get("root_time", 1.5)) * amount)
		"shock":
			p["shock"] = int(p.get("shock", 0)) + ceili(amount)
		"cuts":
			p["cuts"] = int(p.get("cuts", 0)) + ceili(amount)
		"discharge":
			p["discharge"] = true

## Knockback multiplier of the rune in `slot` (Stribog), 1 otherwise.
func kb_mult(slot: String) -> float:
	var id: String = slots.get(slot, "")
	return value(id, "kb", 1.0) if id != "" else 1.0

## Short text of the build for the HUD: slot names with level dots.
func hud_text() -> String:
	var parts: PackedStringArray = []
	for s in COMBAT_SLOTS:
		var id: String = slots[s]
		parts.append("%s: %s" % [SLOT_LABEL[s], "—" if id == "" else "%s %s" % [row(id).get("name", id), "●".repeat(level(id))]])
	if not passives.is_empty() or not duos.is_empty():
		var extra: PackedStringArray = []
		for id in passives + duos + legends:
			extra.append(String(row(id).get("name", id)))
		parts.append("Свойства: " + ", ".join(extra))
	return "   ".join(parts)
