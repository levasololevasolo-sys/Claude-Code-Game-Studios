## Unit tests for HeroVisual: animation choice from the Player state (ADR-0005:
## attacks and dashes are seeked by progress) and slot file resolution (bible §5.7).
extends GdUnitTestSuite

func _state(o: Dictionary = {}) -> Dictionary:
	var s := { "dead": false, "flare_t": 0.0, "flare_dur": 1.0, "dash_t": 0.0, "dash_dur": 0.3, "rolling": false,
		"atk_t": 0.0, "atk_dur": 0.24, "atk_dir": "side", "combo": 1, "on_floor": true, "vx": 0.0, "vy": 0.0 }
	s.merge(o, true)
	return s

func test_choose_standing_still_is_idle() -> void:
	assert_str(HeroVisual.choose(_state()).anim).is_equal("idle")

func test_choose_moving_on_floor_is_run() -> void:
	assert_str(HeroVisual.choose(_state({ "vx": 360.0 })).anim).is_equal("run")

func test_choose_air_rising_is_jump_and_falling_is_fall() -> void:
	assert_str(HeroVisual.choose(_state({ "on_floor": false, "vy": -400.0 })).anim).is_equal("jump")
	assert_str(HeroVisual.choose(_state({ "on_floor": false, "vy": 300.0 })).anim).is_equal("fall")

func test_choose_side_strike_seeks_by_progress() -> void:
	var c := HeroVisual.choose(_state({ "atk_t": 0.06, "atk_dur": 0.24, "combo": 2 }))
	assert_str(c.anim).is_equal("strike_2")
	assert_float(c.k).is_equal_approx(0.75, 0.0001)

func test_choose_combo_past_three_uses_finisher() -> void:
	assert_str(HeroVisual.choose(_state({ "atk_t": 0.1, "combo": 4 })).anim).is_equal("strike_3")

func test_choose_up_and_down_strikes() -> void:
	assert_str(HeroVisual.choose(_state({ "atk_t": 0.1, "atk_dir": "up" })).anim).is_equal("strike_up")
	assert_str(HeroVisual.choose(_state({ "atk_t": 0.1, "atk_dir": "down", "on_floor": false })).anim) \
		.is_equal("strike_down")

func test_choose_roll_on_ground_dash_in_air() -> void:
	var r := HeroVisual.choose(_state({ "dash_t": 0.15, "dash_dur": 0.3, "rolling": true }))
	assert_str(r.anim).is_equal("roll")
	assert_float(r.k).is_equal_approx(0.5, 0.0001)
	assert_str(HeroVisual.choose(_state({ "dash_t": 0.1, "dash_dur": 0.17 })).anim).is_equal("dash")

func test_choose_dash_wins_over_strike_and_death_over_all() -> void:
	assert_str(HeroVisual.choose(_state({ "dash_t": 0.1, "atk_t": 0.1 })).anim).is_equal("dash")
	assert_str(HeroVisual.choose(_state({ "dead": true, "dash_t": 0.1 })).anim).is_equal("death")

func test_choose_hurt_clock_shows_hurt_unless_attacking() -> void:
	assert_str(HeroVisual.choose(_state(), 0.1).anim).is_equal("hurt")
	assert_str(HeroVisual.choose(_state({ "atk_t": 0.1 }), 0.1).anim).is_equal("strike_1")

func test_part_path_falls_back_to_lower_tier() -> void:
	assert_str(HeroVisual.part_path("arm_near_hand", "arm_near", 3)).ends_with("char_hero_arm_near_hand_t1_01.svg")
	assert_str(HeroVisual.part_path("helmet", "helmet", 5)).ends_with("char_hero_helmet_t5_01.svg")

func test_part_path_empty_slot_is_blank() -> void:
	assert_str(HeroVisual.part_path("helmet", "helmet", 1)).is_equal("")

func test_part_path_mannequin_has_no_tier() -> void:
	assert_str(HeroVisual.part_path("head_base", "head_base", 5)).ends_with("char_hero_head_base_01.svg")
