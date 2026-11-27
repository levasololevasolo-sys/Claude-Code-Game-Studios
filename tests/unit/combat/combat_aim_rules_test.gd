## Unit tests for AimRules (GDD weapons-and-loot §3.4 «Прицел»).
extends GdUnitTestSuite

const HAND := Vector2(100, 100)
const DZ: float = 0.3
const EPS := Vector2(0.0001, 0.0001)

func _dir(aiming: bool, pad: bool, cursor: Vector2, stick: Vector2, face: int) -> Vector2:
	return AimRules.direction(aiming, pad, HAND, cursor, stick, face, DZ)

func test_cursor_right_points_right() -> void:
	var d := _dir(true, false, HAND + Vector2(300, 0), Vector2.ZERO, -1)
	assert_vector(d).is_equal_approx(Vector2.RIGHT, EPS)

func test_cursor_left_points_left() -> void:
	var d := _dir(true, false, HAND + Vector2(-50, 0), Vector2.ZERO, 1)
	assert_vector(d).is_equal_approx(Vector2.LEFT, EPS)

func test_cursor_up_points_up_and_keeps_face() -> void:
	var d := _dir(true, false, HAND + Vector2(0, -200), Vector2.ZERO, -1)
	assert_vector(d).is_equal_approx(Vector2.UP, EPS)
	assert_int(AimRules.face_of(d, -1)).is_equal(-1)

func test_cursor_diagonal_is_normalized_and_turns_left() -> void:
	var d := _dir(true, false, HAND + Vector2(-100, -100), Vector2.ZERO, 1)
	assert_vector(d).is_equal_approx(Vector2(-1, -1).normalized(), EPS)
	assert_int(AimRules.face_of(d, 1)).is_equal(-1)

func test_no_aim_falls_back_to_facing() -> void:
	assert_vector(_dir(false, false, HAND + Vector2(0, -200), Vector2.ZERO, -1)).is_equal(Vector2.LEFT)
	assert_vector(_dir(false, true, HAND, Vector2(0, 1), 1)).is_equal(Vector2.RIGHT)

func test_cursor_on_hand_falls_back_to_facing() -> void:
	assert_vector(_dir(true, false, HAND, Vector2.ZERO, -1)).is_equal(Vector2.LEFT)

func test_stick_inside_deadzone_falls_back_to_facing() -> void:
	assert_vector(_dir(true, true, Vector2.ZERO, Vector2(0.2, 0.1), -1)).is_equal(Vector2.LEFT)

func test_stick_outside_deadzone_aims_and_ignores_cursor() -> void:
	var d := _dir(true, true, HAND + Vector2(500, 0), Vector2(0, 0.8), 1)
	assert_vector(d).is_equal_approx(Vector2.DOWN, EPS)

func test_aimable_kinds_are_shots_pot_and_axes() -> void:
	assert_bool(AimRules.aimable({ "type": "shot" })).is_true()
	assert_bool(AimRules.aimable({ "type": "bomb" })).is_true()
	assert_bool(AimRules.aimable({ "type": "axes" })).is_true()
	assert_bool(AimRules.aimable({ "type": "trap" })).is_false()
	assert_bool(AimRules.aimable({ "type": "ring" })).is_false()

func test_axe_fan_unaimed_matches_old_velocity() -> void:
	# Old pair: (face * speed, dy), dy = (i - (n - 1) / 2) * spread.
	assert_vector(AimRules.axe_velocity(Vector2.RIGHT, 820.0, 0, 2, 40.0)).is_equal_approx(Vector2(820, -20), Vector2(0.001, 0.001))
	assert_vector(AimRules.axe_velocity(Vector2.LEFT, 820.0, 1, 2, 40.0)).is_equal_approx(Vector2(-820, 20), Vector2(0.001, 0.001))

func test_bomb_keeps_launch_speed() -> void:
	var v := AimRules.bomb_velocity(Vector2.UP, 520.0, 560.0)
	assert_float(v.length()).is_equal_approx(Vector2(520, 560).length(), 0.001)

func test_line_length_is_speed_times_life_or_fallback() -> void:
	assert_float(AimRules.line_length({ "speed": 1100, "life": 0.9 }, 500.0)).is_equal_approx(990.0, 0.001)
	assert_float(AimRules.line_length({ "type": "chain" }, 500.0)).is_equal_approx(500.0, 0.001)
