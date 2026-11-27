## Forest chunk library (GDD room-generation-and-doors §3.1, §3.3-3.4, AC 1-2):
## every swamp library rule re-run on assets/data/chunks_forest.json, plus the
## forest's own: more vertical than the swamp, trunks as solids, and RoomGen
## picks the library by location (opts.loc / locations.json lib).
extends "res://tests/unit/room_gen/room_gen_chunks_test.gd"

func _lib() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chunks_forest.json"))

func _swamp() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chunks_swamp.json"))

static func _tall(lib: Dictionary) -> int:
	return (lib.chunks as Array).filter(func(c: Dictionary) -> bool: return int(c.h) >= 2).size()

func test_forest_is_more_vertical_than_the_swamp() -> void:
	assert_int(_tall(_lib())).is_greater(_tall(_swamp()))
	var trunks := (_lib().chunks as Array).filter(func(c: Dictionary) -> bool:
		return (c.get("solids", []) as Array).any(func(s: Array) -> bool: return int(s[3]) > int(s[2])))
	assert_int(trunks.size()).is_greater_equal(4)

func test_every_forest_id_has_its_prefix_and_fallback_exists() -> void:
	var ids := {}
	for c: Dictionary in _lib().chunks:
		assert_str(String(c.id)).starts_with("forest_")
		ids[c.id] = true
	for id: String in _lib().fallback:
		assert_bool(ids.has(id)).is_true()

func test_room_gen_picks_the_library_by_location() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r := RoomGen.generate(rng, 2, 2, _t(), true, { "loc": "forest" })
	assert_bool((r.chunks as Array).all(func(c: Dictionary) -> bool: return String(c.id).begins_with("forest_"))).is_true()
	var locs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/locations.json"))
	assert_str(String(locs["2"].lib)).is_equal("forest")
	assert_str(String(locs["1"].lib)).is_equal("swamp")

func test_forest_roster_per_gdd_3_3() -> void:
	var locs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/locations.json"))
	var ros := EnemyRoster.for_tier(2, locs, _t())
	assert_array(ros.roster).contains_exactly(["ringer", "sentry", "rootling"])
	assert_array(ros.late).contains_exactly(["bat"])
	assert_array(EnemyRoster.for_tier(1, locs, _t()).roster).contains_exactly(["crawler", "sentry", "bat"])
