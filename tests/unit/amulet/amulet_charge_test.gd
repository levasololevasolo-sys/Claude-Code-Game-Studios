## Charge, overcharge, spill, power and light formulas of the amulet
## (GDD amulet-and-flare F1-F5, AC 1-8, 15). Fixture numbers = the GDD defaults.
extends GdUnitTestSuite

const TUNE := { "charge_per_hit": 10.0, "over_gain": 0.5, "over_spill": 30.0, "charge_ready": 100.0,
	"c_cap": 150.0, "c_cap_l2": 200.0, "c_cap_first_run": 100.0, "flare_fizzle_time": 0.4,
	"flare_size_base": 0.5, "flare_size_per_power": 0.5,
	"light_base": 360.0, "light_gain": 200.0, "over_glow": 60.0, "threat_reach": 256.0,
	"light_full_frac": 0.15, "light_mid_frac": 0.6, "light_mid_level": 0.7,
	"darkness": 0.78, "darkness_max": 0.95, "darkness_calm": 0.55, "ash_dark": 0.08, "flash_dim": 0.9 }
const RING := { "name": "Коло", "keeps_ready": true, "slam_charge_f": 0.5 }
const BEAM := { "name": "Луч", "keeps_ready": false, "dash_charge": 8.0 }

func _amulet(row: Dictionary = BEAM, first_run: bool = false, level: int = 1) -> Amulet:
	return Amulet.make("test", TUNE, row, level, first_run)

func _hits(a: Amulet, n: int, k_weapon: float = 1.0, k_kindling: float = 1.0) -> void:
	for i in n:
		a.add_hit(1.0, k_weapon, k_kindling)

# ---- F1 ----

func test_ten_sword_hits_reach_100_and_nine_fizzle() -> void:
	var a := _amulet()
	_hits(a, 9)
	assert_float(a.charge).is_equal_approx(90.0, 0.001)
	assert_float(a.try_fire()).is_equal(0.0)
	assert_float(a.charge).is_equal_approx(90.0, 0.001)
	assert_float(a.fizzle_t).is_equal_approx(0.4, 0.001)
	_hits(a, 1)
	assert_float(a.charge).is_equal_approx(100.0, 0.001)
	assert_bool(a.is_ready()).is_true()

func test_overcharge_ten_more_hits_reach_cap_and_stop() -> void:
	var a := _amulet()
	_hits(a, 20)
	assert_float(a.charge).is_equal_approx(150.0, 0.001)
	_hits(a, 1)
	assert_float(a.charge).is_equal_approx(150.0, 0.001)

func test_first_run_cap_is_100() -> void:
	var a := _amulet(BEAM, true)
	_hits(a, 15)
	assert_float(a.charge).is_equal_approx(100.0, 0.001)

func test_forge_level_two_cap_is_200() -> void:
	assert_float(_amulet(BEAM, false, 2).cap).is_equal(200.0)

func test_mace_with_kindling_four_hits_give_104() -> void:
	var a := _amulet()
	_hits(a, 4, 1.8, 1.5)
	assert_float(a.charge).is_equal_approx(104.0, 0.001)

func test_gain_crossing_100_splits_at_threshold() -> void:
	assert_float(AmuletRules.add_charge(95.0, 10.0, 150.0, 100.0, 0.5)).is_equal_approx(102.5, 0.001)

func test_flat_gain_uses_over_gain_above_100() -> void:
	var a := _amulet()
	a.charge = 120.0
	a.add_flat(a.dash_charge())
	assert_float(a.charge).is_equal_approx(124.0, 0.001)

func test_hit_gain_multiplies_all_factors() -> void:
	assert_float(AmuletRules.hit_gain(10.0, 0.5, 1.8, 1.5, 0.2)).is_equal_approx(16.2, 0.001)

func test_became_ready_emitted_once() -> void:
	var a := _amulet()
	var n := [0]
	a.became_ready.connect(func() -> void: n[0] += 1)
	_hits(a, 12)
	assert_int(n[0]).is_equal(1)

# ---- F2 ----

func test_health_hit_in_overcharge_drops_to_70() -> void:
	var a := _amulet()
	a.charge = 135.0
	a.on_health_damage()
	assert_float(a.charge).is_equal_approx(70.0, 0.001)
	assert_bool(a.is_ready()).is_false()

func test_ring_health_hit_in_overcharge_keeps_100() -> void:
	var a := _amulet(RING)
	a.charge = 135.0
	a.on_health_damage()
	assert_float(a.charge).is_equal_approx(100.0, 0.001)

func test_health_hit_at_exactly_100_changes_nothing() -> void:
	var a := _amulet()
	a.charge = 100.0
	a.on_health_damage()
	assert_float(a.charge).is_equal_approx(100.0, 0.001)

func test_second_hit_after_spill_changes_nothing() -> void:
	var a := _amulet()
	a.charge = 140.0
	a.on_health_damage()
	a.on_health_damage()
	assert_float(a.charge).is_equal_approx(70.0, 0.001)

# ---- F3 ----

func test_fire_returns_power_and_empties() -> void:
	var a := _amulet()
	a.charge = 150.0
	assert_float(a.try_fire()).is_equal_approx(1.5, 0.001)
	assert_float(a.charge).is_equal(0.0)

func test_fire_keeps_ember_rest() -> void:
	var a := _amulet()
	a.charge = 120.0
	a.try_fire(35.0)
	assert_float(a.charge).is_equal_approx(35.0, 0.001)

func test_size_and_damage_at_150() -> void:
	assert_float(AmuletRules.size_mult(1.5, TUNE)).is_equal_approx(1.25, 0.001)
	assert_float(AmuletRules.flare_damage(38.0, 1.0, 1.5)).is_equal_approx(57.0, 0.001)
	assert_float(AmuletRules.flare_damage(38.0, 1.8, 2.0, 3, 0.15)).is_equal_approx(198.36, 0.01)

# ---- F4 / F5 ----

func test_light_radius_examples() -> void:
	assert_float(AmuletRules.light_radius(0.0, TUNE)).is_equal_approx(360.0, 1.0)
	assert_float(AmuletRules.light_radius(100.0, TUNE)).is_equal_approx(560.0, 1.0)
	assert_float(AmuletRules.light_radius(150.0, TUNE)).is_equal_approx(590.0, 1.0)
	assert_float(AmuletRules.light_radius(200.0, TUNE)).is_equal_approx(620.0, 1.0)

func test_light_min_covers_threat_reach() -> void:
	var lm := AmuletRules.light_min(TUNE)
	assert_float(lm).is_equal(359.0)
	var low := TUNE.duplicate()
	low["light_base"] = 200.0
	var r := AmuletRules.light_radius(0.0, low)
	assert_float(r).is_equal(359.0)
	# half of the darkness is lifted at threat_reach
	assert_float(AmuletRules.light_at(256.0, r, 0.15, 0.6, 0.7)).is_greater_equal(0.5)

func test_light_profile_points() -> void:
	assert_float(AmuletRules.light_at(10.0, 100.0, 0.15, 0.6, 0.7)).is_equal(1.0)
	assert_float(AmuletRules.light_at(60.0, 100.0, 0.15, 0.6, 0.7)).is_equal_approx(0.7, 0.001)
	assert_float(AmuletRules.light_at(100.0, 100.0, 0.15, 0.6, 0.7)).is_equal(0.0)
	assert_float(AmuletRules.half_light_frac(0.15, 0.6, 0.7)).is_equal_approx(0.714, 0.001)

func test_darkness_examples() -> void:
	assert_float(AmuletRules.darkness(TUNE)).is_equal_approx(0.78, 0.001)
	assert_float(AmuletRules.darkness(TUNE, false, 1)).is_equal_approx(0.86, 0.001)
	assert_float(AmuletRules.darkness(TUNE, true)).is_equal_approx(0.429, 0.001)
	assert_float(AmuletRules.darkness(TUNE, false, 0, 0.7)).is_equal_approx(0.2886, 0.001)
