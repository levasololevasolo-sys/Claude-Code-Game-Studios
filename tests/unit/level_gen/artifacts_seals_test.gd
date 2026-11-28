## Artifacts and seal rooms (GDD artifacts-and-secrets §3.1-3.6, AC 1-4, 6):
## all 11 artifacts arrive at once on the first clear and stay through death
## and save round trips; every seal kind has its artifact; every location's
## levels hold 1-2 seal rooms of its own kinds, never the same kind twice, with
## the seal, the vault and the barrier, bridge or hook their opening needs.
extends GdUnitTestSuite

static func _arts() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/artifacts.json"))

func test_at_least_ten_artifacts_each_with_its_own_seal() -> void:
	var a := _arts()
	var rows := Artifacts.rows(a)
	assert_int(rows.size()).is_greater_equal(10)
	var seals := {}
	for r: Dictionary in rows:
		assert_bool(seals.has(String(r.seal))).is_false()
		seals[String(r.seal)] = true
		assert_bool((a.seals as Dictionary).has(String(r.seal))).is_true()
		assert_str(String(r.hint)).is_not_empty()
		assert_bool(String(r.hint).contains(String(r.name))).is_false()

func test_no_artifacts_before_the_first_clear() -> void:
	var m := MetaState.new()
	assert_array(Artifacts.grant_if_cleared(m, _arts())).is_empty()
	assert_bool(Artifacts.can_open(m, _arts(), "moroc")).is_false()

func test_first_clear_grants_all_and_death_keeps_them() -> void:
	var a := _arts()
	var m := MetaState.new()
	m.wins = 1
	var got := Artifacts.grant_if_cleared(m, a)
	assert_int(got.size()).is_equal(Artifacts.rows(a).size())
	assert_bool(Artifacts.can_open(m, a, "hook")).is_true()
	# A later run (death or not) grants nothing new and removes nothing.
	assert_array(Artifacts.grant_if_cleared(m, a)).is_empty()
	var back := MetaState.from_dict(m.to_dict())
	assert_int(back.artifacts.size()).is_equal(Artifacts.rows(a).size())

func test_old_winning_save_gets_them_on_load() -> void:
	var m := MetaState.from_dict({ "wins": 2 })
	assert_int(m.artifacts.size()).is_equal(0)
	assert_int(Artifacts.grant_if_cleared(m, _arts()).size()).is_equal(Artifacts.rows(_arts()).size())

func _level(lib_id: String, tier: int, s: int) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))
	var t := LevelGen.with_seals(LevelGen.tuning_for(data), _arts(), tier)
	return LevelGen.build(s, tier, LevelGen.library(lib_id), t)

func test_every_location_places_its_own_seal_rooms() -> void:
	var a := _arts()
	for loc: Array in [["swamp", 1], ["forest", 2], ["frost", 3]]:
		var set_k: Array = a.seal_sets[str(loc[1])]
		var levels_with := 0
		for s in 10:
			var l := _level(String(loc[0]), int(loc[1]), 100 + s)
			assert_bool(bool(l.ok)).is_true()
			var kinds := {}
			for sl: Dictionary in l.get("seals", []):
				var k := String(sl.kind)
				assert_bool(k in set_k).override_failure_message("%s: %s not in its set" % [loc[0], k]).is_true()
				assert_bool(kinds.has(k)).is_false()
				kinds[k] = true
				var z: Vector2i = sl.z
				assert_int(z.x).is_greater_equal(0)
				var open := String(Artifacts.for_seal(a, k).open)
				match open:
					"pull":
						assert_int((sl.o as Vector2i).x).is_greater_equal(0)
					"build":
						assert_array(sl.wc).is_not_empty()
					_:
						assert_array(sl.x).is_not_empty()
			var vaults := 0
			for c: Dictionary in l.chests:
				if bool(c.get("vault", false)):
					vaults += 1
			assert_int(vaults).is_equal((l.get("seals", []) as Array).size())
			assert_int(kinds.size()).is_less_equal(int(a.seal_max))
			if kinds.size() >= int(a.seal_min):
				levels_with += 1
		assert_int(levels_with).override_failure_message("%s: too few levels with a seal room" % loc[0]).is_greater_equal(8)

func test_seal_rooms_never_in_the_first_section() -> void:
	for s in 10:
		var l := _level("swamp", 1, 300 + s)
		for r: Dictionary in l.rooms:
			if String(r.kind) == "seal":
				assert_int(int(r.sec)).is_greater(0)

func test_without_seal_tuning_levels_are_unchanged() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))
	var plain := LevelGen.build(7007, 1, LevelGen.library("swamp"), LevelGen.tuning_for(data))
	for r: Dictionary in plain.rooms:
		assert_str(String(r.kind)).is_not_equal("seal")
