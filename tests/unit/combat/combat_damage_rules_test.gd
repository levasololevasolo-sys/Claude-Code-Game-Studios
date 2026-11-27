## Unit tests for DamageRules (ADR-0002 Validation Criteria: finisher multiplier,
## air multiplier, front shield, weight). GDD movement-and-combat F6-F8, F12.
extends GdUnitTestSuite

## Fixture tuning values (the formulas are tested, not the shipped numbers).
const TUNE := { "air_mult": 1.25, "sentry_block": 0.15, "shield_kb_mult": 0.4 }
const COMBO := [1.0, 1.0, 1.8]

## A grounded, unshielded, weight-1 target at x = 100 facing right.
func _view(overrides: Dictionary = {}) -> Dictionary:
	var v := { "x": 100.0, "face": 1, "flies": false, "boss": false, "airborne": false,
		"shield": false, "stunned": false, "weight": 1.0, "kb_scale": 1.0 }
	v.merge(overrides, true)
	return v

func _hit(kind: Hit.Kind, dmg: float, from_x: float, kb: float = 0.0) -> Hit:
	return Hit.make(kind, dmg, from_x, kb)

# ---- combo / finisher -------------------------------------------------------

func test_strike_damage_third_swing_uses_finisher_mult() -> void:
	# Act
	var d := DamageRules.strike_damage(11.0, COMBO, 3)
	# Assert
	assert_float(d).is_equal_approx(19.8, 0.0001)

func test_strike_damage_combo_out_of_range_is_clamped() -> void:
	# Act / Assert
	assert_float(DamageRules.strike_damage(11.0, COMBO, 0)).is_equal_approx(11.0, 0.0001)
	assert_float(DamageRules.strike_damage(11.0, COMBO, 9)).is_equal_approx(19.8, 0.0001)

func test_strike_damage_empty_combo_table_returns_base() -> void:
	assert_float(DamageRules.strike_damage(11.0, [], 2)).is_equal_approx(11.0, 0.0001)

func test_is_finisher_only_last_swing_true() -> void:
	assert_bool(DamageRules.is_finisher(2, 3)).is_false()
	assert_bool(DamageRules.is_finisher(3, 3)).is_true()

func test_strike_knockback_finisher_multiplies() -> void:
	assert_float(DamageRules.strike_knockback(260.0, true, 1.8)).is_equal_approx(468.0, 0.0001)
	assert_float(DamageRules.strike_knockback(260.0, false, 1.8)).is_equal_approx(260.0, 0.0001)

# ---- air multiplier (§3.9) --------------------------------------------------

func test_is_airborne_above_margin_true_within_margin_false() -> void:
	assert_bool(DamageRules.is_airborne(631.0, 640.0, 8.0)).is_true()
	assert_bool(DamageRules.is_airborne(633.0, 640.0, 8.0)).is_false()

func test_final_strike_on_launched_ground_enemy_gets_air_mult() -> void:
	# Arrange — F6 example: blade finisher on a launched target = 24.75
	var hit := _hit(Hit.Kind.STRIKE, 19.8, 50.0)
	# Act
	var d := DamageRules.final(hit, _view({ "airborne": true }), TUNE)
	# Assert
	assert_float(d).is_equal_approx(24.75, 0.0001)

func test_final_strike_on_flyer_no_air_mult() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 50.0)
	assert_float(DamageRules.final(hit, _view({ "airborne": true, "flies": true }), TUNE)).is_equal_approx(10.0, 0.0001)

func test_final_strike_on_boss_no_air_mult() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 50.0)
	assert_float(DamageRules.final(hit, _view({ "airborne": true, "boss": true }), TUNE)).is_equal_approx(10.0, 0.0001)

func test_final_slam_on_airborne_enemy_no_air_mult() -> void:
	var hit := _hit(Hit.Kind.SLAM, 14.0, 50.0)
	assert_float(DamageRules.final(hit, _view({ "airborne": true }), TUNE)).is_equal_approx(14.0, 0.0001)

func test_final_grounded_enemy_no_air_mult() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 50.0)
	assert_float(DamageRules.final(hit, _view(), TUNE)).is_equal_approx(10.0, 0.0001)

# ---- front shield (§3.7 step 3) ---------------------------------------------

func test_final_shield_hit_from_front_reduced_to_block() -> void:
	# Arrange — target faces right (+1), hit comes from x = 150 (in front)
	var hit := _hit(Hit.Kind.STRIKE, 20.0, 150.0)
	# Act
	var d := DamageRules.final(hit, _view({ "shield": true }), TUNE)
	# Assert
	assert_float(d).is_equal_approx(3.0, 0.0001)

func test_final_shield_hit_from_behind_full_damage() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 20.0, 50.0)
	assert_float(DamageRules.final(hit, _view({ "shield": true }), TUNE)).is_equal_approx(20.0, 0.0001)

func test_final_shield_pierce_hit_full_damage() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 20.0, 150.0)
	hit.pierce = true
	assert_float(DamageRules.final(hit, _view({ "shield": true }), TUNE)).is_equal_approx(20.0, 0.0001)

func test_final_shield_stunned_target_full_damage() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 20.0, 150.0)
	assert_float(DamageRules.final(hit, _view({ "shield": true, "stunned": true }), TUNE)).is_equal_approx(20.0, 0.0001)

func test_final_shield_flare_and_tick_full_damage() -> void:
	assert_float(DamageRules.final(_hit(Hit.Kind.FLARE, 20.0, 150.0), _view({ "shield": true }), TUNE)).is_equal_approx(20.0, 0.0001)
	assert_float(DamageRules.final(_hit(Hit.Kind.TICK, 20.0, 150.0), _view({ "shield": true }), TUNE)).is_equal_approx(20.0, 0.0001)

func test_final_negative_damage_clamped_to_zero() -> void:
	assert_float(DamageRules.final(_hit(Hit.Kind.STRIKE, -5.0, 50.0), _view(), TUNE)).is_equal(0.0)

# ---- knockback and weight (F7, F8) ------------------------------------------

func test_knockback_divided_by_weight_and_pushes_away() -> void:
	# Arrange — F8 example: mace finisher on a bat, 260 × 1.8 × 1.5 / 0.6 = 1170
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 50.0, 702.0)
	# Act
	var kb := DamageRules.knockback(hit, _view({ "weight": 0.6 }), TUNE)
	# Assert
	assert_float(kb).is_equal_approx(1170.0, 0.0001)

func test_knockback_from_right_pushes_left() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 150.0, 260.0)
	assert_float(DamageRules.knockback(hit, _view(), TUNE)).is_equal_approx(-260.0, 0.0001)

func test_knockback_kb_scale_applied() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 50.0, 260.0)
	assert_float(DamageRules.knockback(hit, _view({ "kb_scale": 0.6 }), TUNE)).is_equal_approx(156.0, 0.0001)

func test_knockback_shield_block_uses_shield_kb_mult() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 150.0, 260.0)
	assert_float(DamageRules.knockback(hit, _view({ "shield": true, "weight": 1.8 }), TUNE)).is_equal_approx(-260.0 * 0.4 / 1.8, 0.0001)

func test_knockback_tick_is_zero() -> void:
	var hit := _hit(Hit.Kind.TICK, 3.0, 50.0, 260.0)
	assert_float(DamageRules.knockback(hit, _view(), TUNE)).is_equal(0.0)

func test_knockback_same_x_is_zero() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 100.0, 260.0)
	assert_float(DamageRules.knockback(hit, _view(), TUNE)).is_equal(0.0)

func test_knockback_zero_weight_does_not_divide_by_zero() -> void:
	var hit := _hit(Hit.Kind.STRIKE, 10.0, 50.0, 1.0)
	assert_float(DamageRules.knockback(hit, _view({ "weight": 0.0 }), TUNE)).is_equal_approx(1.0 / DamageRules.MIN_WEIGHT, 0.01)

func test_launch_speed_divided_by_weight() -> void:
	# F7 example: sentry (1.8) → 640 / 1.8 ≈ 355.6
	assert_float(DamageRules.launch_speed(640.0, 1.8)).is_equal_approx(355.5556, 0.001)

# ---- hero shield (F12) ------------------------------------------------------

func test_split_shield_partial_absorb_rest_to_hp() -> void:
	var s := DamageRules.split_shield(18.0, 5.0)
	assert_float(s.x).is_equal_approx(5.0, 0.0001)
	assert_float(s.y).is_equal_approx(13.0, 0.0001)

func test_split_shield_full_absorb_rest_zero() -> void:
	var s := DamageRules.split_shield(4.0, 10.0)
	assert_float(s.x).is_equal_approx(4.0, 0.0001)
	assert_float(s.y).is_equal(0.0)

func test_split_shield_no_shield_all_to_hp() -> void:
	var s := DamageRules.split_shield(7.0, 0.0)
	assert_float(s.x).is_equal(0.0)
	assert_float(s.y).is_equal_approx(7.0, 0.0001)
