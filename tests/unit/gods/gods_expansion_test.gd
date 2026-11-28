## The 8 new gods, Горн Сварога and the Prophet (GDD gods-expansion §3.2,
## §3.12-3.14): timer statuses, god unlocks, the Prophet's minimum, the rare
## forge door, and forge upgrades reshaping the weapon's combo.
extends GdUnitTestSuite

const GODS := {
	"kupala": { "kind": "runes", "toggle": true, "unlock": {} },
	"perun": { "kind": "runes", "toggle": true, "unlock": { "runs": 1 } },
	"stribog": { "kind": "runes", "toggle": true, "unlock": { "runs": 1 } },
	"veles": { "kind": "runes", "toggle": true, "unlock": { "runs": 1 } },
	"zhiva": { "kind": "runes", "toggle": true, "unlock": { "runs": 1 } },
	"mokosh": { "kind": "runes", "toggle": true, "unlock": { "bosses": 1 } },
	"chernobog": { "kind": "runes", "toggle": true, "unlock": { "wins": 1 } },
	"rod": { "kind": "runes", "toggle": false, "unlock": {} },
	"svarog": { "kind": "forge", "toggle": false, "unlock": {} },
}

func _meta(wins: int, bosses: int) -> MetaState:
	var m := MetaState.new()
	m.runs = 3
	m.wins = wins
	if bosses > 0:
		m.bosses = { "likho": bosses }
	return m

# ---------------- statuses ----------------

func test_timer_status_keeps_the_longer_time() -> void:
	var s := StatusSet.new()
	assert_bool(s.add_timer("thread", 4.0)).is_true()
	s.add_timer("thread", 2.0)
	assert_float(s.thread).is_equal_approx(4.0, 0.001)

func test_blind_ends_into_immunity_and_cannot_be_reapplied() -> void:
	var s := StatusSet.new()
	s.add_timer("blind", 1.0)
	s.tick(1.1, { "blind_immune": 3.0 }, {})
	assert_bool(s.blinded()).is_false()
	assert_bool(s.add_timer("blind", 2.0)).is_false()
	s.tick(3.1, { "blind_immune": 3.0 }, {})
	assert_bool(s.add_timer("blind", 2.0)).is_true()

# ---------------- unlocks and the Prophet ----------------

func test_new_gods_open_by_progress_and_never_rod_or_svarog() -> void:
	var early := DoorRules.gods_open(GODS, ProphetRules.stats(_meta(0, 0)))
	assert_array(early).contains_exactly_in_any_order(["kupala", "perun", "stribog", "veles", "zhiva"])
	var late := DoorRules.gods_open(GODS, ProphetRules.stats(_meta(1, 1)))
	assert_array(late).contains(["mokosh", "chernobog"])
	assert_array(late).not_contains(["rod", "svarog"])

func test_prophet_keeps_at_least_four_gods() -> void:
	var m := _meta(1, 1)
	assert_int(ProphetRules.on_count(m, GODS)).is_equal(7)
	for g in ["kupala", "perun", "stribog"]:
		assert_bool(ProphetRules.toggle(m, GODS, g, 4)).is_true()
	assert_int(ProphetRules.on_count(m, GODS)).is_equal(4)
	assert_str(ProphetRules.block(m, GODS, "veles", 4)).is_not_empty()
	assert_bool(ProphetRules.toggle(m, GODS, "veles", 4)).is_false()
	assert_int(ProphetRules.on_count(m, GODS)).is_equal(4)
	# Calling a god back is always allowed.
	assert_bool(ProphetRules.toggle(m, GODS, "kupala", 4)).is_true()
	assert_bool(ProphetRules.is_on(m, "kupala")).is_true()

func test_sent_away_gods_leave_the_run_pool() -> void:
	var m := _meta(1, 1)
	ProphetRules.toggle(m, GODS, "perun", 4)
	var open := DoorRules.gods_open(GODS, ProphetRules.stats(m))
	var on := DoorRules.enabled_gods(open, m.gods_off, GODS, 4)
	assert_array(on).not_contains(["perun"])
	assert_int(on.size()).is_equal(6)

func test_too_few_called_gods_fall_back_to_all_open() -> void:
	var open: Array[String] = ["kupala", "perun", "stribog", "veles", "zhiva"]
	var off: Array[String] = ["kupala", "perun", "stribog"]
	assert_int(DoorRules.enabled_gods(open, off, GODS, 4).size()).is_equal(5)

func test_gods_off_survives_a_save_round_trip() -> void:
	var m := _meta(1, 1)
	m.gods_off.append("veles")
	m.svarog_dry = 2
	var back := MetaState.from_dict(m.to_dict())
	assert_array(back.gods_off).is_equal(["veles"])
	assert_int(back.svarog_dry).is_equal(2)

# ---------------- Горн Сварога ----------------

func test_forge_door_needs_location_two_and_once_per_location() -> void:
	var t := { "svarog_min_loc": 2, "svarog_per_run": 2 }
	assert_bool(DoorRules.svarog_ok(true, 1, [], 0, 5, t)).is_false()
	assert_bool(DoorRules.svarog_ok(true, 2, [], 0, 5, t)).is_true()
	assert_bool(DoorRules.svarog_ok(true, 2, [2], 0, 5, t)).is_false()
	assert_bool(DoorRules.svarog_ok(true, 3, [2], 2, 5, t)).is_false()
	assert_bool(DoorRules.svarog_ok(true, 3, [2], 1, 0, t)).is_false()
	assert_bool(DoorRules.svarog_ok(false, 3, [], 0, 5, t)).is_false()

func test_forge_door_is_rare_and_dry_runs_double_it() -> void:
	var t := { "svarog_chance": 0.05, "svarog_dry_runs": 3, "svarog_dry_mult": 2.0 }
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var base := 0
	var dry := 0
	for i in 4000:
		if DoorRules.svarog_roll(rng, 0, t):
			base += 1
	for i in 4000:
		if DoorRules.svarog_roll(rng, 3, t):
			dry += 1
	assert_int(base).is_between(120, 290)
	assert_int(dry).is_between(300, 520)

func test_forge_family_upgrade_sleeps_with_another_weapon() -> void:
	var b := RunBuild.make({ "_forge": {
		"a": { "family": "any", "dmg": 1.2 },
		"f": { "family": "blade", "extra_step": { "time": 0.36, "mult": 2.4 } } } })
	b.take_forge("a")
	b.take_forge("f")
	b.take_forge("f")
	assert_int(b.forge.size()).is_equal(2)
	assert_int(b.forge_active("blade").size()).is_equal(2)
	assert_int(b.forge_active("spear").size()).is_equal(1)

func test_forged_blade_gets_a_fourth_step_and_faster_swings() -> void:
	var b := RunBuild.make({ "_forge": {
		"q": { "family": "any", "swing": 1.25 },
		"f": { "family": "blade", "extra_step": { "time": 0.36, "mult": 2.4 } } } })
	var body := { "times": [0.3, 0.3, 0.4], "mult": [1.0, 1.0, 1.6] }
	b.take_forge("q")
	b.take_forge("f")
	var fb := b.forged_body(body, "blade")
	assert_int((fb.times as Array).size()).is_equal(4)
	assert_float(float((fb.mult as Array)[3])).is_equal_approx(2.4, 0.001)
	assert_float(float((fb.times as Array)[0])).is_less(0.3)
	# The source body is left alone, and another family keeps three steps.
	assert_int((body.times as Array).size()).is_equal(3)
	assert_int((b.forged_body(body, "spear").times as Array).size()).is_equal(3)

func test_forge_pool_offers_only_untaken_upgrades_of_the_family() -> void:
	var b := RunBuild.make({ "_forge": {
		"a": { "family": "any" }, "f": { "family": "blade" }, "s": { "family": "spear" } } })
	b.take_forge("a")
	var pool := b.forge_pool("blade")
	assert_array(pool.fam).is_equal(["f"])
	assert_array(pool.any).is_empty()

func test_shipped_forge_table_has_upgrades_for_every_family() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/svarog.json"))
	var per := {}
	for id: String in d.ups:
		var f := String(d.ups[id].family)
		per[f] = int(per.get(f, 0)) + 1
	for f in ["any", "stick", "blade", "spear", "sickles", "hammer", "staff"]:
		assert_int(int(per.get(f, 0))).override_failure_message(f).is_greater_equal(4)
