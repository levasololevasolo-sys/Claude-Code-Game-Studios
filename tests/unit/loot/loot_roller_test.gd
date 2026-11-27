## LootRoller (GDD weapons-and-loot §3.7, §3.10, §4.1-4.5; AC 2-8). Rows are the
## shipped tables (AC: the data itself is checked); fixed seeds.
extends GdUnitTestSuite

func _t() -> Dictionary:
	return Tune.data

func _tables() -> Dictionary:
	return { "weapons": Tune.table("weapons"), "subweapons": Tune.table("subweapons"), "affixes": Tune.table("affixes") }

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _all_owned(rows: Dictionary) -> Dictionary:
	var o := {}
	for id: String in rows:
		o[id] = true
	return o

func test_rarity_thresholds_ac2() -> void:
	var t := _t()
	var cases := { 0.049: "l", 0.05: "e", 0.179: "e", 0.18: "r", 0.499: "r", 0.50: "c" }
	for u: float in cases:
		assert_str(LootRoller.roll_rarity(u, {}, false, t)).override_failure_message("u=%s" % u).is_equal(cases[u])
	var luck := { 0.089: "l", 0.269: "e", 0.27: "r", 0.59: "c" }
	for u: float in luck:
		assert_str(LootRoller.roll_rarity(u, {}, true, t)).override_failure_message("luck u=%s" % u).is_equal(luck[u])

func _legend_share(owned: Dictionary, held: String) -> float:
	var r := _rng(77)
	var n := 100000
	var l := 0
	var tb := _tables()
	for i in n:
		var d := LootRoller.roll(r, { "kind": "arm", "owned_arms": owned, "held_arm": held, "pity": {} }, tb, _t())
		if d.rar == "l":
			l += 1
	return float(l) / n

func test_purchases_do_not_dilute_legendaries_ac3() -> void:
	assert_float(_legend_share({ "stick": true }, "stick")).is_between(0.048, 0.052)
	assert_float(_legend_share(_all_owned(Tune.table("weapons")), "blade")).is_between(0.048, 0.052)

func test_quality_thresholds_ac4() -> void:
	var t := _t()
	assert_int(LootRoller.roll_quality(0.149, 1, 0, t)).is_equal(3)
	assert_int(LootRoller.roll_quality(0.15, 1, 0, t)).is_equal(2)
	assert_int(LootRoller.roll_quality(0.549, 1, 0, t)).is_equal(2)
	assert_int(LootRoller.roll_quality(0.55, 1, 0, t)).is_equal(1)
	assert_int(LootRoller.roll_quality(0.619, 5, 1, t)).is_equal(3)
	assert_int(LootRoller.roll_quality(0.99, 5, 1, t)).is_equal(2)

func test_quality_mult_and_affix_only_at_three_stars_ac5() -> void:
	var t := _t()
	assert_float(LootRoller.quality_mult(1, t)).is_equal_approx(1.0, 0.0001)
	assert_float(LootRoller.quality_mult(2, t)).is_equal_approx(1.15, 0.0001)
	assert_float(LootRoller.quality_mult(3, t)).is_equal_approx(1.3, 0.0001)
	var r := _rng(5)
	for i in 3000:
		var d := LootRoller.roll(r, { "tier": 1 + i % 5, "bonus": i % 2, "pity": {} }, _tables(), t)
		if int(d.q) < 3:
			assert_str(String(d.affix)).is_empty()
		else:
			assert_str(String(d.affix)).is_not_empty()

func test_affix_shares_follow_hero_gods_ac6() -> void:
	var r := _rng(9)
	var n := 100000
	var count := {}
	var row: Dictionary = Tune.table("weapons").blade
	for i in n:
		var a := LootRoller.roll_affix(r, Weapon.ARM, "blade", row, ["perun", "veles"], Tune.table("affixes"), _t())
		count[a] = int(count.get(a, 0)) + 1
	assert_float(float(count.get("a_perun", 0)) / n).is_between(0.295, 0.305)
	assert_float(float(count.get("a_veles", 0)) / n).is_between(0.295, 0.305)
	for g in ["a_svarog", "a_stribog", "a_zhiva"]:
		assert_int(int(count.get(g, 0))).is_equal(0)
	for c in ["a_speed", "a_reach", "a_charge", "a_boss"]:
		assert_float(float(count.get(c, 0)) / n).is_between(0.097, 0.103)

func test_affix_bans_ac6() -> void:
	var r := _rng(3)
	var w: Dictionary = Tune.table("weapons")
	for i in 5000:
		assert_str(LootRoller.roll_affix(r, Weapon.ARM, "ringsword", w.ringsword, [], Tune.table("affixes"), _t())).is_not_equal("a_charge")
		var a := LootRoller.roll_affix(r, Weapon.ARM, "thunderpike", w.thunderpike, ["perun"], Tune.table("affixes"), _t())
		assert_bool((Tune.table("affixes")[a] as Dictionary).has("god")).is_false()
		assert_bool(LootRoller.roll_affix(r, Weapon.SUB, "bow", {}, [], Tune.table("affixes"), _t()) in ["s_cd", "s_dmg", "s_twice"]).is_true()

func test_no_gods_means_all_five_edge6() -> void:
	var r := _rng(4)
	var seen := {}
	for i in 4000:
		seen[LootRoller.roll_affix(r, Weapon.ARM, "blade", {}, [], Tune.table("affixes"), _t())] = true
	for g in ["a_svarog", "a_perun", "a_stribog", "a_veles", "a_zhiva"]:
		assert_bool(seen.has(g)).is_true()

func test_pity_legendary_ac7() -> void:
	var pity := { "e": 0, "l": 0 }
	for i in 25:
		LootRoller.update_pity(pity, "c")
	assert_int(int(pity.l)).is_equal(25)
	assert_str(LootRoller.roll_rarity(0.99, pity, false, _t())).is_equal("l")
	LootRoller.update_pity(pity, "l")
	assert_int(int(pity.l)).is_equal(0)
	assert_int(int(pity.e)).is_equal(0)

func test_pity_epic_ac7() -> void:
	var pity := { "e": 0, "l": 0 }
	for i in 15:
		LootRoller.update_pity(pity, "r")
	assert_int(int(pity.e)).is_equal(15)
	for u in [0.0, 0.3, 0.5, 0.99]:
		assert_bool(LootRoller.roll_rarity(u, pity, false, _t()) in ["e", "l"]).is_true()
	LootRoller.update_pity(pity, "e")
	assert_int(int(pity.e)).is_equal(0)
	assert_int(int(pity.l)).is_equal(16)

func test_pity_through_roll_and_meta_round_trip() -> void:
	var m := MetaState.new()
	var r := _rng(21)
	for i in 40:
		LootRoller.roll(r, { "kind": "arm", "owned_arms": m.weapons, "pity": m.pity }, _tables(), _t())
	var back := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_dict(back.pity).is_equal({ "e": int(m.pity.e), "l": int(m.pity.l) })
	assert_int(int(m.pity.l)).is_less(26)

func test_pool_new_save_ac8() -> void:
	var p := LootRoller.pool(Tune.table("weapons"), { "stick": true }, ["stick"])
	assert_array(p.c).contains_exactly_in_any_order(["ringsword", "koromyslo"])
	assert_int((p.r as Array).size()).is_equal(4)
	assert_int((p.e as Array).size()).is_equal(4)
	assert_int((p.l as Array).size()).is_equal(3)
	var s := LootRoller.pool(Tune.table("subweapons"), {}, [""])
	assert_array(s.c).contains_exactly_in_any_order(["javelin", "sling"])

func test_stick_priced_held_and_floor_never_drop_ac8() -> void:
	var r := _rng(13)
	var owned := { "stick": true, "spear": true }
	for i in 100000:
		var d := LootRoller.roll(r, { "kind": "arm", "owned_arms": owned, "held_arm": "ringsword", "floor": ["koromyslo"], "pity": {} }, _tables(), _t())
		assert_bool(String(d.id) in ["stick", "blade", "sickles", "hammer", "staff", "ringsword", "koromyslo"]).override_failure_message(String(d.id)).is_false()

func test_empty_rarity_shifts_down_then_up_edge1() -> void:
	var by := { "c": ["a"], "r": [], "e": [], "l": [] }
	assert_str(LootRoller.settle_rarity("l", by)).is_equal("c")
	by = { "c": [], "r": [], "e": ["x"], "l": [] }
	assert_str(LootRoller.settle_rarity("c", by)).is_equal("e")
	assert_str(LootRoller.settle_rarity("c", { "c": [], "r": [], "e": [], "l": [] })).is_empty()

func test_nothing_to_drop_does_not_grow_pity_edge1() -> void:
	var pity := { "e": 3, "l": 3 }
	var rows := { "x": { "rar": "c", "price": { "iron": 1 } } }
	var d := LootRoller.roll(_rng(1), { "kind": "arm", "pity": pity }, { "weapons": rows, "subweapons": {}, "affixes": {} }, _t())
	assert_dict(d).is_empty()
	assert_dict(pity).is_equal({ "e": 3, "l": 3 })

func test_main_share_and_forced_kind() -> void:
	var t := _t()
	assert_bool(LootRoller.roll_is_main(0.59, "", t)).is_true()
	assert_bool(LootRoller.roll_is_main(0.6, "", t)).is_false()
	assert_bool(LootRoller.roll_is_main(0.99, "arm", t)).is_true()

func test_yaga_forced_legendary_two_stars_no_affix() -> void:
	var d := LootRoller.roll(_rng(2), { "kind": "arm", "rar": "l", "q": 2, "pity": { "e": 0, "l": 7 } }, _tables(), _t())
	assert_str(String(d.rar)).is_equal("l")
	assert_int(int(d.q)).is_equal(2)
	assert_str(String(d.affix)).is_empty()
