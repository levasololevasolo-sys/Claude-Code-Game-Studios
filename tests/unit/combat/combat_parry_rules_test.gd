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

const REFLECT := { "parry_reflect_speed": 1.5, "parry_reflect_dmg": 2.0 }

func test_reflects_only_inside_window_and_not_twice() -> void:
	assert_bool(ParryRules.reflects(0.1, false)).is_true()
	assert_bool(ParryRules.reflects(0.0, false)).is_false()
	assert_bool(ParryRules.reflects(0.1, true)).is_false()

func test_reflect_velocity_aims_at_live_shooter_faster() -> void:
	var v := ParryRules.reflect_velocity(Vector2(100, 500), Vector2(-200, 0), true, Vector2(400, 100), REFLECT)
	assert_float(v.length()).is_equal_approx(300.0, 0.001)
	assert_vector(v.normalized()).is_equal_approx(Vector2(0.6, -0.8), Vector2(0.001, 0.001))

func test_reflect_velocity_straight_back_without_shooter() -> void:
	var v := ParryRules.reflect_velocity(Vector2(100, 500), Vector2(-200, 0), false, Vector2.ZERO, REFLECT)
	assert_vector(v).is_equal_approx(Vector2(300, 0), Vector2(0.001, 0.001))
	assert_vector(ParryRules.reflect_velocity(Vector2.ZERO, Vector2.ZERO, false, Vector2.ZERO, REFLECT)).is_equal(Vector2.ZERO)

func test_reflect_damage_multiplied_never_negative() -> void:
	assert_float(ParryRules.reflect_damage(12.0, REFLECT)).is_equal_approx(24.0, 0.001)
	assert_float(ParryRules.reflect_damage(-1.0, REFLECT)).is_equal(0.0)
