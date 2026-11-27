## Frost chunk library (GDD room-generation-and-doors §3.1, §3.3-3.4, AC 1-2):
## every swamp library rule re-run on assets/data/chunks_frost.json, plus the
## frost's own: ice pillars as cover, the frost prefix, RoomGen picks it by
## location, and location 3 is no longer a stub while location 4 still is.
extends "res://tests/unit/room_gen/room_gen_chunks_test.gd"

func _lib() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chunks_frost.json"))

static func _locs() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/locations.json"))

func test_frost_has_ice_pillars_as_cover() -> void:
	var pillars := (_lib().chunks as Array).filter(func(c: Dictionary) -> bool:
		return (c.get("solids", []) as Array).any(func(s: Array) -> bool: return int(s[1]) == 0 and int(s[2]) == 1 and int(s[3]) <= 2))
	assert_int(pillars.size()).is_greater_equal(4)

func test_every_frost_id_has_its_prefix_and_fallback_exists() -> void:
	var ids := {}
	for c: Dictionary in _lib().chunks:
		assert_str(String(c.id)).starts_with("frost_")
		ids[c.id] = true
	for id: String in _lib().fallback:
		assert_bool(ids.has(id)).is_true()

func test_room_gen_picks_the_frost_library_for_location_3() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r := RoomGen.generate(rng, 3, 3, _t(), true, { "loc": "frost" })
	assert_bool((r.chunks as Array).all(func(c: Dictionary) -> bool: return String(c.id).begins_with("frost_"))).is_true()
	assert_str(String(_locs()["3"].lib)).is_equal("frost")

func test_frost_roster_per_gdd_3_3_and_one_flyer_kind() -> void:
	var ros := EnemyRoster.for_tier(3, _locs(), _t())
	# Bestiary §3.4: six frost kinds, Студёный дух the only flyer; Трясинник and Упырь-щитник left.
	assert_array(ros.roster).contains_exactly(["wolf", "karachun", "jelly", "snezhnitsa", "sosulnik", "mara"])
	assert_array(ros.late).is_empty()

func test_location_3_is_live_and_light_and_4_is_still_a_stub() -> void:
	var l := _locs()
	assert_bool(bool(l["3"].get("stub", false))).is_false()
	assert_str(String(l["3"].boss)).is_equal("morena")
	assert_str(String(l["3"].look.props)).is_equal("frost")
	assert_float(float(l["3"].darkness)).is_less(float(l["2"].darkness))
	assert_bool(bool(l["4"].get("stub", false))).is_true()
