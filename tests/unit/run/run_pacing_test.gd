## Rune pacing godTime (GDD room-generation-and-doors §3.8, F4.4; AC 10).
extends GdUnitTestSuite

const T := { "gap_need": [1, 2] }

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_god_time_is_since_at_least_gap() -> void:
	assert_bool(DoorRules.god_time(0, 1)).is_false()
	assert_bool(DoorRules.god_time(1, 1)).is_true()
	assert_bool(DoorRules.god_time(1, 2)).is_false()
	assert_bool(DoorRules.god_time(2, 2)).is_true()

func test_god_rod_surica_reset_since_and_reroll_gap() -> void:
	for type in ["god", "rod", "surica"]:
		var run := RunState.new()
		run.since_god = 3
		DoorRules.apply_pacing(run, type, _rng(1), T)
		assert_int(run.since_god).is_equal(0)
		assert_int(run.gap_need).is_between(1, 2)

func test_other_rewards_add_one() -> void:
	for type in ["loot", "heal", "arms"]:
		var run := RunState.new()
		run.since_god = 1
		run.gap_need = 2
		DoorRules.apply_pacing(run, type, _rng(1), T)
		assert_int(run.since_god).is_equal(2)
		assert_int(run.gap_need).is_equal(2)

func test_gap_need_is_one_or_two_about_half_each() -> void:
	var r := _rng(7)
	var ones := 0
	for i in 1000:
		var g := DoorRules.roll_gap(r, T)
		assert_int(g).is_between(1, 2)
		if g == 1:
			ones += 1
	assert_int(ones).is_between(400, 600)

func test_first_room_reward_is_god_only_at_god_time() -> void:
	var ctx := { "god_time": true, "gods": ["perun"], "types": ["god", "loot", "heal"] }
	assert_dict(DoorRules.first_room_reward(_rng(3), ctx, { "loot_w": 0.4, "heal_w": 0.18 })).is_equal({ "type": "god", "god": "perun" })
	ctx.god_time = false
	assert_str(String(DoorRules.first_room_reward(_rng(3), ctx, { "loot_w": 0.4, "heal_w": 0.18 }).type)).is_not_equal("god")
