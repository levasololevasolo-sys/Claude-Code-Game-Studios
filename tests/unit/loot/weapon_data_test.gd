## Weapon data and the Weapon instance (GDD weapons-and-loot §3.2-3.5, §4.4, §4.7;
## AC 1, 5, 12, 13, 15; movement-and-combat §3.4 bodies).
extends GdUnitTestSuite

const OLD_BLADE := { "times": [0.24, 0.24, 0.32], "mult": [1.0, 1.0, 1.8], "win": [0.25, 0.7], "lunge": 120, "reach": 78, "charge": 1.0 }

func _rows(name: String) -> Dictionary:
	var out := {}
	var t := Tune.table(name)
	for id: String in t:
		if not id.begins_with("_"):
			out[id] = t[id]
	return out

func test_counts_and_rarity_split_ac1() -> void:
	var w := _rows("weapons")
	var s := _rows("subweapons")
	assert_int(w.size()).is_equal(23)
	assert_int(s.size()).is_equal(12)
	var cw := { "c": 0, "r": 0, "e": 0, "l": 0 }
	for id: String in w:
		if id != "stick":
			cw[w[id].rar] += 1
	assert_dict(cw).is_equal({ "c": 7, "r": 8, "e": 4, "l": 3 })
	var cs := { "c": 0, "r": 0, "e": 0, "l": 0 }
	for id: String in s:
		cs[s[id].rar] += 1
	assert_dict(cs).is_equal({ "c": 5, "r": 3, "e": 2, "l": 2 })

func test_every_rarity_has_two_run_only_kinds_ac1() -> void:
	var need := int(Tune.f("tier_min_runonly"))
	for name in ["weapons", "subweapons"]:
		var rows := _rows(name)
		for rar in ["c", "r", "e", "l"]:
			var n := 0
			for id: String in rows:
				if rows[id].rar == rar and (rows[id].price as Dictionary).is_empty() and not bool(rows[id].get("no_drop", false)):
					n += 1
			assert_int(n).override_failure_message("%s %s" % [name, rar]).is_greater_equal(need)

func test_no_cut_kinds_and_bodies_exist_ac1() -> void:
	var w := _rows("weapons")
	for cut in ["firesword", "frostsword", "liftberdysh"]:
		assert_bool(w.has(cut)).is_false()
	var bodies := _rows("weapon_bodies")
	assert_array(bodies.keys()).contains_exactly_in_any_order(["blade", "spear", "sickles", "hammer", "staff"])
	for id: String in w:
		assert_bool(bodies.has(String(w[id].body))).override_failure_message(id).is_true()

func test_bodies_shape() -> void:
	for id: String in _rows("weapon_bodies"):
		var b: Dictionary = Tune.table("weapon_bodies")[id]
		assert_int((b.times as Array).size()).override_failure_message(id).is_equal((b.mult as Array).size())
		assert_float(float(b.win[0])).is_less(float(b.win[1]))
	var st: Dictionary = Tune.table("weapon_bodies").staff
	assert_int((st.times as Array).size()).is_equal(4)
	assert_float(float(st.fin_kb)).is_equal_approx(2.2, 0.0001)
	assert_int(int(st.arc_deg)).is_equal(200)

func test_blade_body_identical_to_the_old_port_numbers() -> void:
	var b: Dictionary = Tune.table("weapon_bodies").blade
	for k: String in OLD_BLADE:
		assert_str(JSON.stringify(b[k])).override_failure_message(k).is_equal(JSON.stringify(JSON.parse_string(JSON.stringify(OLD_BLADE[k]))))
	var w := Weapon.make("blade")
	assert_float(w.dmg_mult()).is_equal(1.0)
	assert_array(w.times()).is_equal([0.24, 0.24, 0.32])
	assert_float(w.reach()).is_equal(78.0)
	assert_float(w.charge()).is_equal(1.0)

func test_multipliers_match_table_ac1() -> void:
	var w := _rows("weapons")
	var exp := { "stick": [0.75, 1, 0.9], "thunderpike": [1.1, 1, 1.1], "marascythe": [1.1, 1, 1.15], "whirlsickles": [1, 1.1, 1],
		"flail": [0.9, 1.1, 1], "staff": [0.85, 1, 1.1], "koromyslo": [0.8, 1, 1], "batog": [0.9, 1, 1], "oslop": [1, 0.95, 1.1], "ringsword": [0.95, 1, 1] }
	for id: String in exp:
		assert_float(float(w[id].dmg)).override_failure_message(id).is_equal_approx(float(exp[id][0]), 0.0001)
		assert_float(float(w[id].spd)).is_equal_approx(float(exp[id][1]), 0.0001)
		assert_float(float(w[id].reach)).is_equal_approx(float(exp[id][2]), 0.0001)

func test_price_sums_ac15() -> void:
	var sum := {}
	for name in ["weapons", "subweapons"]:
		var rows := _rows(name)
		for id: String in rows:
			for k: String in rows[id].price:
				sum[k] = int(sum.get(k, 0)) + int(rows[id].price[k])
	assert_dict(sum).is_equal({ "iron": 70, "resin": 48, "frost": 40, "hearts": 2 })

func test_quality_and_affix_stats_ac5() -> void:
	var a := Weapon.make("flail", Weapon.ARM, 3, "a_perun")
	assert_float(a.dmg_mult()).is_equal_approx(0.9 * 1.3, 0.0001)
	assert_float(11.0 * a.dmg_mult()).is_equal_approx(12.87, 0.001)
	assert_float(Weapon.make("blade", Weapon.ARM, 2).speed()).is_equal(1.0)
	assert_float(Weapon.make("blade", Weapon.ARM, 3, "a_speed").speed()).is_equal_approx(1.15, 0.0001)
	assert_float(Weapon.make("blade", Weapon.ARM, 3, "a_reach").reach()).is_equal_approx(78.0 * 1.2, 0.0001)
	assert_float(Weapon.make("ringsword").charge()).is_equal_approx(2.0, 0.0001)
	assert_float(Weapon.make("hammer").charge()).is_equal_approx(1.8, 0.0001)
	var s := Weapon.make("bow", Weapon.SUB, 3, "s_dmg")
	assert_float(s.sub_dmg()).is_equal_approx(14.0 * 1.3 * 1.4, 0.0001)
	assert_float(Weapon.make("bow", Weapon.SUB, 3, "s_cd").cooldown()).is_equal_approx(0.49, 0.0001)
	assert_str(Weapon.make("flail", Weapon.ARM, 3, "a_perun").title()).is_equal("Громовое · Кистень")
	assert_str(Weapon.make("flail", Weapon.ARM, 2).stars()).is_equal("★★☆")

func test_round_trip_and_unknown_id_edge18() -> void:
	var w := Weapon.make("oslop", Weapon.ARM, 3, "a_stribog")
	assert_dict(Weapon.from_dict(w.to_dict()).to_dict()).is_equal(w.to_dict())
	assert_object(Weapon.from_dict({ "id": "firesword" })).is_null()
	assert_object(Weapon.from_dict({})).is_null()

func test_new_save_defaults_ac13() -> void:
	var m := MetaState.from_dict({})
	assert_str(m.weapon).is_equal("stick")
	assert_dict(m.weapons).is_equal({ "stick": true })
	assert_dict(m.pity).is_equal({ "e": 0, "l": 0 })
	assert_str(m.sub).is_empty()
	assert_int(int(Tune.table("weapons").blade.price.iron)).is_equal(8)
