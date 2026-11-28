## Unit tests for RunBuild and RuneOffer (GDD gods-and-runes §3.2, §3.4, §3.10,
## §3.11, F5, F9; AC 1, 13, 14, 15, 20). Reads the shipped runes.json: duo
## detection must be data-driven, so the real table is what is checked.
extends GdUnitTestSuite

const TUNE := { "burn_time": 3.0, "curse_time": 6.0, "root_time": 1.5, "shock_stacks": 3, "wrath_power": 0.5,
	"duo_chance": 0.5, "legend_chance": 0.35, "dash_cooldown": 0.55, "dash_cd_floor": 0.25, "dash_gap": 0.2 }

func _b(arg: String = "") -> RunBuild:
	return RunBuild.from_arg(arg) if arg != "" else RunBuild.make()

func test_slot_replacement_drops_old_rune_and_level() -> void:
	var b := _b("kupala_s:2")
	assert_int(b.level("kupala_s")).is_equal(2)
	var old := b.take("perun_s")
	assert_str(old).is_equal("kupala_s")
	assert_str(b.slots.strike).is_equal("perun_s")
	assert_int(b.level("perun_s")).is_equal(1)
	assert_bool(b.has("kupala_s")).is_false()
	assert_int(b.level("kupala_s")).is_equal(0)

func test_passives_accumulate_and_same_rune_not_taken_twice() -> void:
	var b := _b("kupala_p,edge")
	b.take("edge")
	assert_int(b.passives.size()).is_equal(2)
	assert_bool(b.level_up("edge")).is_true()
	assert_bool(b.level_up("edge")).is_true()
	assert_bool(b.level_up("edge")).is_false()
	assert_float(b.value("edge", "mult")).is_equal_approx(2.0, 0.0001)

func test_replacing_slot_keeps_duo() -> void:
	var b := _b("kupala_s,perun_d,duo_firestorm")
	b.take("stribog_d")
	assert_bool(b.has("duo_firestorm")).is_true()

func test_duos_detected_from_data_only_with_both_gods() -> void:
	var b := _b("kupala_s")
	assert_array(b.available_duos()).is_empty()
	b.take("perun_p")
	assert_array(b.available_duos()).is_equal(["duo_firestorm"])
	b.take("veles_d")
	assert_array(b.available_duos()).is_equal(["duo_black", "duo_firestorm", "duo_pyre"])
	assert_array(b.duos_for("kupala")).is_equal(["duo_firestorm", "duo_pyre"])
	b.take("duo_pyre")
	assert_array(b.duos_for("kupala")).is_equal(["duo_firestorm"])

func test_data_has_twenty_three_duos_and_no_removed_runes() -> void:
	var b := _b()
	var n := 0
	for id: String in b.table:
		if b.slot_of(id) == "duo":
			n += 1
	assert_int(n).is_equal(23)
	assert_bool(b.table.has("shell")).is_false()
	assert_bool(b.table.has("zhiva_step")).is_false()

func test_storm_ctx_needs_two_charges_and_adds_jump() -> void:
	var c := _b("perun_s,stribog_d,duo_storm").ctx(TUNE)
	assert_int(c.shock_need).is_equal(2)
	assert_int(c.jumps_bonus).is_equal(1)

func test_payload_levels_and_finisher_only() -> void:
	var b := _b("kupala_s:3,zhiva_d")
	assert_float(float(b.payload("strike", 1.0, TUNE).burn)).is_equal_approx(6.0, 0.0001)
	b.take("zhiva_s")
	assert_bool(b.payload("strike", 1.0, TUNE, false).is_empty()).is_true()
	assert_float(float(b.payload("strike", 1.0, TUNE, true).root)).is_equal_approx(1.5, 0.0001)

func test_wrath_adds_next_slot_status_every_time() -> void:
	# AC 15: Удар Сварог / Рывок Перун / Вспышка Велес + Гнев → burn and +1 charge.
	var b := _b("kupala_s,perun_d,veles_f,wrath")
	var ok := 0
	for i in 1000:
		var p := b.payload("strike", 1.0, TUNE)
		if float(p.get("burn", 0.0)) > 0.0 and int(p.get("shock", 0)) == 1:
			ok += 1
	assert_int(ok).is_equal(1000)
	var f := b.payload("flare", 1.0, TUNE)
	assert_float(float(f.curse)).is_equal_approx(9.0, 0.0001)
	assert_float(float(f.burn)).is_equal_approx(1.5, 0.0001)
	assert_bool(b.payload("strike", 1.0, TUNE, false, true).has("shock")).is_false()

func test_dash_cd_floor_holds_with_swift_and_vihr() -> void:
	var b := _b("swift:3,stribog_d")
	# raw 0.55 × 0.35 × 0.7 = 0.135 < floor max(0.25, 0.3 + 0.2)
	assert_float(b.dash_cd(TUNE, 0.3)).is_equal_approx(0.5, 0.0001)
	assert_float(_b().dash_cd(TUNE, 0.17)).is_equal_approx(0.55, 0.0001)

func test_flare_element_from_flare_slot_god() -> void:
	assert_str(_b().flare_element()).is_equal(FlareElement.PURE)
	assert_str(_b("perun_f").flare_element()).is_equal("perun")

func test_flare_element_puts_statuses_with_power() -> void:
	var b := _b("kupala_f")
	var h := Hit.make(Hit.Kind.FLARE, 38.0, 0.0, 0.0)
	FlareElement.apply("kupala", h, 1.5, { "flare_god_stun": 0.4, "flare_god_min_power": 0.5, "burn_time": 3.0 }, b)
	assert_float(h.burn).is_equal_approx(9.0, 0.0001)
	assert_float(h.stun).is_equal_approx(0.4, 0.0001)

# ---- offers (§3.4, AC 13, 14) ----

func test_offer_never_contains_held_rune() -> void:
	var b := _b("kupala_s,kupala_p,kupala_d")
	for seed_i in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var ids := RuneOffer.build_offer("kupala", b, rng, TUNE, 3)
		assert_int(ids.size()).is_equal(3)
		for id in ids:
			assert_bool(b.has(id)).is_false()

func test_no_duo_without_second_god_1000_seeds() -> void:
	var b := _b("kupala_s")
	var duos := 0
	for seed_i in 1000:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		for id in RuneOffer.build_offer("kupala", b, rng, TUNE, 3):
			if b.slot_of(id) == "duo":
				duos += 1
	assert_int(duos).is_equal(0)

func test_duo_appears_with_second_god() -> void:
	var b := _b("kupala_s,perun_d")
	var seen := false
	for seed_i in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		if "duo_firestorm" in RuneOffer.build_offer("perun", b, rng, TUNE, 3):
			seen = true
	assert_bool(seen).is_true()

func test_wide_choice_gives_four_and_rest_fills_last() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_int(RuneOffer.build_offer("zhiva", _b(), rng, TUNE, 4).size()).is_equal(4)
	var full := _b()
	for id: String in full.table:
		if full.god_of(id) in ["rod", "veles"] and full.slot_of(id) in ["strike", "dash", "flare", "passive"]:
			full.take(id)
	var ids := RuneOffer.build_offer("veles", full, rng, TUNE, 3)
	assert_array(ids).contains(["rest"])
