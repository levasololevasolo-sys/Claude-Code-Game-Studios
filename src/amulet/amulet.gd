## The amulet the hero wears: its charge and its rules (GDD amulet-and-flare
## §3.1-3.4). Plain state + AmuletRules, no nodes, so tests can drive it. The
## hero owns one (Player.amulet); the HUD and the darkness read it.
class_name Amulet
extends RefCounted

## The charge reached 100 (first time in this filling) — sound and icon flash.
signal became_ready
## The charge reached the cap.
signal capped
## Overcharge was lost to a health hit (spark burst and crack sound).
signal spilled(before: float, after: float)
## The Flare was pressed below 100 ("pshik").
signal fizzled

## Row id in amulets.json: "ring", "beam", "wave", "knot".
var id: String = "ring"
## The row of amulets.json.
var row: Dictionary = {}
## The tuning dictionary (Tune.data in the game, a fixture in tests).
var tune: Dictionary = {}
## Charge c, 0..cap.
var charge: float = 0.0
## Ceiling of the charge (F1 c_cap).
var cap: float = 150.0
## Forge level 1..3 (§3.8). Only the level-2 cap is applied for now.
var level: int = 1
## Seconds of the icon shake after a fizzle.
var fizzle_t: float = 0.0

## Builds an amulet of row `p_id` with the tuning `p_tune`; `p_row` is injected in
## tests, empty reads amulets.json through Tune.
static func make(p_id: String, p_tune: Dictionary, p_row: Dictionary = {}, p_level: int = 1, first_run: bool = false) -> Amulet:
	var a := Amulet.new()
	a.id = p_id
	a.tune = p_tune
	a.row = p_row if not p_row.is_empty() else Tune.row("amulets", p_id)
	a.level = p_level
	a.cap = AmuletRules.cap_for(p_level, first_run, p_tune)
	return a

## 100: the ready threshold.
func ready_at() -> float:
	return float(tune.get("charge_ready", 100.0))

## True when the Flare can be fired (c ≥ 100).
func is_ready() -> bool:
	return charge >= ready_at()

## True above 100 (the risky part).
func is_over() -> bool:
	return charge > ready_at()

## Shape id of the Flare (the row's id; kept apart in case rows get variants).
func shape() -> String:
	return id

## Display name ("Коло").
func display_name() -> String:
	return String(row.get("name", id))

func _set_charge(v: float) -> void:
	var was_ready := is_ready()
	var was_cap := charge >= cap
	charge = v
	if not was_ready and is_ready():
		became_ready.emit()
	if not was_cap and charge >= cap and cap > ready_at():
		capped.emit()

## F1 for a landed hit: `f` = source factor (1 strike, 0.5 shield / slam, 2 slam
## with Волна), `k_weapon` = the weapon's charge multiplier.
func add_hit(f: float, k_weapon: float = 1.0, k_kindling: float = 1.0, chg_amulet: float = 0.0) -> void:
	var g := AmuletRules.hit_gain(float(tune.get("charge_per_hit", 10.0)), f, k_weapon, k_kindling, chg_amulet)
	_add(g)

## F1 flat gain (Луч per dash, Узел per kill): no other multipliers.
func add_flat(amount: float) -> void:
	_add(amount)

func _add(g: float) -> void:
	_set_charge(AmuletRules.add_charge(charge, g, cap, ready_at(), float(tune.get("over_gain", 0.5))))

## f of F1 for one enemy hit by a ground slam (0.5, or 2 with Волна).
func slam_f() -> float:
	return float(row.get("slam_charge_f", tune.get("charge_f_slam", 0.5)))

## Flat charge per dash (Луч 8, others 0).
func dash_charge() -> float:
	return float(row.get("dash_charge", 0.0))

## Flat charge per kill (Узел 12, others 0).
func kill_charge() -> float:
	return float(row.get("kill_charge", 0.0))

## F2: the hero lost health (not shield). Call only for hits that reached hp.
func on_health_damage() -> void:
	var before := charge
	charge = AmuletRules.after_health_hit(charge, ready_at(), float(tune.get("over_spill", 30.0)), bool(row.get("keeps_ready", false)))
	if charge != before:
		spilled.emit(before, charge)

## The Flare key was pressed. Returns P (F3) and empties the amulet when ready;
## returns 0 and fizzles (charge untouched) below 100. `ember_rest` is the charge
## left after the Flare (35 with the Rod rune "Тлеющий остаток", later).
func try_fire(ember_rest: float = 0.0) -> float:
	if not is_ready():
		fizzle_t = float(tune.get("flare_fizzle_time", 0.4))
		fizzled.emit()
		return 0.0
	var p := AmuletRules.power(charge, ready_at())
	charge = ember_rest
	return p

## Counts the icon shake down.
func tick(dt: float) -> void:
	fizzle_t = maxf(0.0, fizzle_t - dt)

## Light radius around the hero right now (F4).
func light_radius() -> float:
	return AmuletRules.light_radius(charge, tune)
