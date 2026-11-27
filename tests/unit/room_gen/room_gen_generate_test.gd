## gdUnit4 suite for RoomGen.generate, legacy flat layout (safe_start = false,
## the --demo / single-room checks) and the BUG-0004 safe zone of chunk rooms.
extends GdUnitTestSuite

const TUNING_PATH := "res://assets/data/tuning.json"

func _tuning() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))

func _gen(seed_value: int, room_index: int, tier: int, tuning: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return RoomGen.generate(rng, room_index, tier, tuning, false)

func _chunk(seed_value: int, room_index: int, tier: int, tuning: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return RoomGen.generate(rng, room_index, tier, tuning)

func test_same_seed_returns_identical_room() -> void:
	var t := _tuning()
	assert_dict(_gen(5, 3, 1, t)).is_equal(_gen(5, 3, 1, t))

func test_first_room_uses_room_w_first_width() -> void:
	var t := _tuning()
	assert_float(_gen(1, 1, 1, t).w).is_equal(float(t.room_w_first))

func test_first_room_has_at_most_two_packs() -> void:
	var t := _tuning()
	assert_int(_gen(1, 1, 1, t).packs.size()).is_less_equal(2)

func test_second_room_width_is_base_plus_step() -> void:
	var t := _tuning()
	assert_float(_gen(1, 2, 1, t).w).is_equal(float(t.room_w_base + t.room_w_step))

func test_late_room_width_is_capped_at_room_w_max() -> void:
	var t := _tuning()
	assert_float(_gen(1, 9, 3, t).w).is_equal(float(t.room_w_max))

func test_platforms_and_enemies_stay_inside_room_over_50_seeds() -> void:
	var t := _tuning()
	var inside := true
	for s in 50:
		var r := _gen(s, 4, 2, t)
		for p: Vector3 in r.plats:
			if p.x < 0 or p.x + p.z > r.w or not (p.y in t.plat_levels):
				inside = false
		for pack: Array in r.packs:
			for x: float in pack:
				if x < 400 or x > r.w - 200:
					inside = false
	assert_bool(inside).is_true()

# BUG-0004: safe start zone, no pack member within aggro_range + start_safe_gap of the hero spawn.
func test_no_enemy_inside_safe_start_zone_over_many_rooms() -> void:
	var t := _tuning()
	var safe := float(t.hero_spawn_x) + float(t.aggro_range) + float(t.start_safe_gap)
	var min_x := INF
	for s in 40:
		for k in range(1, 6):
			for tier in range(1, 4):
				for pack: Array in _chunk(s, k, tier, t).packs:
					for x: float in pack:
						min_x = minf(min_x, x)
	assert_float(min_x).is_greater_equal(safe)

func test_first_room_keeps_two_packs_with_safe_zone() -> void:
	var t := _tuning()
	for s in 30:
		assert_int(_gen(s, 1, 1, t).packs.size()).is_equal(2)

func test_safe_start_off_keeps_the_legacy_flat_layout() -> void:
	var t := _tuning()
	var a := RandomNumberGenerator.new()
	a.seed = 9
	var b := RandomNumberGenerator.new()
	b.seed = 9
	var on := RoomGen.generate(a, 2, 1, t)
	var off := RoomGen.generate(b, 2, 1, t, false)
	assert_bool(on.has("chunks")).is_true()
	assert_bool(off.has("chunks")).is_false()
	assert_float(off.w).is_equal(float(t.room_w_base + t.room_w_step))
