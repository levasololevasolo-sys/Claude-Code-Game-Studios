## Unit tests for ParryRules (GDD parry §3, §4).
extends GdUnitTestSuite

const TUNE := { "parry_stun": 0.6, "parry_boss_stun": 0.2 }

func test_can_start_blocked_by_cooldown_lock_dash_swing() -> void:
	assert_bool(ParryRules.can_start(0.0, 0.0, false, false)).is_true()
	assert_bool(ParryRules.can_start(0.1, 0.0, false, false)).is_false()
	assert_bool(ParryRules.can_start(0.0, 0.1, false, false)).is_false()
	assert_bool(ParryRules.can_start(0.0, 0.0, true, false)).is_false()
	assert_bool(ParryRules.can_start(0.0, 0.0, false, true)).is_false()

func test_catches_only_enemy_melee_inside_window() -> void:
	assert_bool(ParryRules.catches(0.1, Hit.Kind.CONTACT, true)).is_true()
	assert_bool(ParryRules.catches(0.0, Hit.Kind.CONTACT, true)).is_false()
	assert_bool(ParryRules.catches(0.1, Hit.Kind.PROJECTILE, true)).is_false()
	assert_bool(ParryRules.catches(0.1, Hit.Kind.CONTACT, false)).is_false()

func test_stun_for_boss_is_shorter() -> void:
	assert_float(ParryRules.stun_for(false, TUNE)).is_equal_approx(0.6, 0.0001)
	assert_float(ParryRules.stun_for(true, TUNE)).is_equal_approx(0.2, 0.0001)

func test_tick_window_whiff_once_when_it_runs_out() -> void:
	var r := ParryRules.tick_window(0.05, 0.1)
	assert_bool(r.whiff).is_true()
	assert_float(r.left).is_equal(0.0)
	var r2 := ParryRules.tick_window(0.0, 0.1)
	assert_bool(r2.whiff).is_false()
	var r3 := ParryRules.tick_window(0.18, 0.05)
	assert_bool(r3.whiff).is_false()
	assert_float(r3.left).is_equal_approx(0.13, 0.0001)
