## Unit tests for LimbRules (GDD limb-zones F1-F5, §3.1-3.3, Edge Cases) and
## the Enemy side of a cut (cannot cut twice, headless does not die of it).
extends GdUnitTestSuite

## Fixture row and tuning (the rules are tested, not the shipped numbers).
const ROW := { "arm": [0.2, 1.6, 0.1, 0.8], "head": [-0.25, 0.4, 0.74, 1.0], "attack_states": ["appear", "swipe"],
	"one_arm": { "swipe_x": 0.5 } }
const TUNE := { "limb_arm_bonus": 1.5, "limb_head_bonus": 2.0, "limb_contact_depth": 6.0, "limb_elites": 1 }
const W: float = 40.0
const H: float = 70.0
const POS := Vector2(500, 640)

func _pick(strike: Rect2, dir: String, hero_x: float, air: bool, st: String, face: int = -1, arm_off: bool = false, head_off: bool = false) -> String:
	var hurt := Rect2(POS.x - W / 2.0, POS.y - H, W, H)
	return LimbRules.pick(strike, hurt, ROW, POS, W, H, face, dir, hero_x, air, st, arm_off, head_off, TUNE)

## A side swing from the left at the hero's height (like Player.strike_rect side).
func _side() -> Rect2:
	return Rect2(430, 640 - 78, 82, 84)

## A down strike column over the enemy (like Player.strike_rect down).
func _down(x: float = 500.0) -> Rect2:
	return Rect2(x - 40, 640 - 150, 80, 130)

# ---- eligibility -------------------------------------------------------------

func test_eligible_boss_never() -> void:
	assert_bool(LimbRules.eligible(ROW, true, false, false, TUNE)).is_false()

func test_eligible_elite_follows_knob() -> void:
	assert_bool(LimbRules.eligible(ROW, false, true, false, TUNE)).is_true()
	assert_bool(LimbRules.eligible(ROW, false, true, false, { "limb_elites": 0 })).is_false()

func test_eligible_kind_without_row_false() -> void:
	assert_bool(LimbRules.eligible({}, false, false, false, TUNE)).is_false()

# ---- geometry ----------------------------------------------------------------

func test_local_rect_mirrors_with_face() -> void:
	var r := LimbRules.local_rect(ROW.arm, W, H, -1)
	assert_float(r.position.x).is_equal_approx(-64.0, 0.001)
	assert_float(r.end.x).is_equal_approx(-8.0, 0.001)
	assert_float(r.position.y).is_equal_approx(-56.0, 0.001)
	assert_float(r.end.y).is_equal_approx(-7.0, 0.001)

func test_contact_point_side_is_near_edge_mid_height() -> void:
	var c := LimbRules.contact_point(Rect2(0, 0, 100, 100), Rect2(50, 20, 100, 60), "side", 0.0, 6.0)
	assert_vector(c).is_equal_approx(Vector2(56, 50), Vector2(0.01, 0.01))

func test_contact_point_down_is_top_of_overlap() -> void:
	var c := LimbRules.contact_point(Rect2(40, 0, 40, 200), Rect2(50, 20, 100, 60), "down", 60.0, 6.0)
	assert_vector(c).is_equal_approx(Vector2(65, 26), Vector2(0.01, 0.01))

func test_contact_point_miss_is_inf() -> void:
	assert_bool(LimbRules.contact_point(Rect2(0, 0, 10, 10), Rect2(50, 50, 5, 5), "side", 0.0, 6.0) == Vector2.INF).is_true()

func test_zone_at_head_before_arm() -> void:
	var zr := { "arm": Rect2(0, 0, 10, 10), "head": Rect2(0, 0, 10, 10) }
	assert_str(LimbRules.zone_at(Vector2(5, 5), zr)).is_equal("head")
	assert_str(LimbRules.zone_at(Vector2(50, 5), zr)).is_equal("body")

# ---- arm window ----------------------------------------------------------------

func test_pick_front_swing_during_windup_cuts_arm() -> void:
	assert_str(_pick(_side(), "side", 430.0, false, "appear")).is_equal("arm")

func test_pick_front_swing_outside_attack_is_plain() -> void:
	assert_str(_pick(_side(), "side", 430.0, false, "walk")).is_equal("")

func test_pick_swing_on_back_during_attack_is_plain() -> void:
	# Facing right (away from the hero on the left): the arm is on the far side.
	assert_str(_pick(_side(), "side", 430.0, false, "swipe", 1)).is_equal("")

func test_pick_arm_already_cut_is_plain() -> void:
	assert_str(_pick(_side(), "side", 430.0, false, "swipe", -1, true)).is_equal("")

# ---- head ------------------------------------------------------------------------

func test_pick_down_air_over_head_pops_head() -> void:
	assert_str(_pick(_down(), "down", 500.0, true, "walk")).is_equal("head")

func test_pick_down_from_ground_is_plain() -> void:
	assert_str(_pick(_down(), "down", 500.0, false, "walk")).is_equal("")

func test_pick_side_swing_never_pops_head() -> void:
	var high := Rect2(430, 640 - 74, 82, 14)
	assert_str(_pick(high, "side", 430.0, true, "walk")).is_equal("")

func test_pick_head_already_off_is_plain() -> void:
	assert_str(_pick(_down(), "down", 500.0, true, "walk", -1, false, true)).is_equal("")

func test_resolve_up_strike_on_head_is_plain() -> void:
	assert_str(LimbRules.resolve("head", "up", true, "walk", ROW, false, false)).is_equal("")

# ---- formulas ---------------------------------------------------------------------

func test_bonus_mult_per_limb() -> void:
	assert_float(LimbRules.bonus_mult("arm", TUNE)).is_equal_approx(1.5, 0.0001)
	assert_float(LimbRules.bonus_mult("head", TUNE)).is_equal_approx(2.0, 0.0001)
	assert_float(LimbRules.bonus_mult("", TUNE)).is_equal_approx(1.0, 0.0001)

func test_one_arm_stats_multiplies_only_listed_keys() -> void:
	var s := LimbRules.one_arm_stats({ "swipe_x": 90.0, "hp": 40.0 }, { "swipe_x": 0.5, "missing": 2.0 })
	assert_float(float(s.swipe_x)).is_equal_approx(45.0, 0.0001)
	assert_float(float(s.hp)).is_equal_approx(40.0, 0.0001)
	assert_bool(s.has("missing")).is_false()

func test_headless_aim_sways_and_zero_err_is_exact() -> void:
	var hero := Vector2(300, 640)
	assert_vector(LimbRules.headless_aim(hero, 0.25, 100.0, 1.0)).is_equal_approx(Vector2(400, 640), Vector2(0.01, 0.01))
	assert_vector(LimbRules.headless_aim(hero, 0.25, 0.0, 1.0)).is_equal(hero)

func test_hp_after_head_loss_only_damage_counts() -> void:
	assert_float(LimbRules.hp_after(40.0, 22.0)).is_equal_approx(18.0, 0.0001)

func test_can_cut_twice_false() -> void:
	assert_bool(LimbRules.can_cut("arm", ROW, false, false)).is_true()
	assert_bool(LimbRules.can_cut("arm", ROW, true, false)).is_false()
	assert_bool(LimbRules.can_cut("head", ROW, false, true)).is_false()
	assert_bool(LimbRules.can_cut("head", { "arm": [0, 1, 0, 1] }, false, false)).is_false()

# ---- on a real enemy (shipped limb_zones.json row of the ringer) --------------------

func _ringer() -> Ringer:
	var e: Ringer = auto_free(Ringer.new())
	e.kind_id = "ringer"
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = 3
	e.position = POS
	e.setup()
	return e

func _cut_hit(limb: String, dmg: float) -> Hit:
	var h := Hit.make(Hit.Kind.STRIKE, dmg, POS.x - 60.0, 0.0)
	h.limb = limb
	return h

func _free_parts(e: Enemy) -> void:
	for p in e.orphan_parts:
		p.free()
	e.orphan_parts.clear()

func test_enemy_arm_cut_once_then_plain() -> void:
	var e := _ringer()
	e.st = "swipe"
	var d1 := e.hurt(_cut_hit("arm", 4.0))
	var d2 := e.hurt(_cut_hit("arm", 4.0))
	assert_bool(e.arm_off).is_true()
	assert_float(d1).is_equal_approx(4.0 * Tune.f("limb_arm_bonus"), 0.0001)
	assert_float(d2).is_equal_approx(4.0, 0.0001)
	assert_int(e.orphan_parts.size()).is_equal(1)
	_free_parts(e)

func test_enemy_headless_does_not_die_of_head_loss() -> void:
	var e := _ringer()
	var d := e.hurt(_cut_hit("head", 2.0))
	assert_bool(e.head_off).is_true()
	assert_bool(e.dead).is_false()
	assert_float(e.hp).is_equal_approx(e.max_hp - d, 0.0001)
	_free_parts(e)

func test_enemy_head_hit_that_kills_kills() -> void:
	var e := _ringer()
	e.hurt(_cut_hit("head", e.max_hp))
	assert_bool(e.dead).is_true()
	assert_bool(e.head_off).is_true()
	_free_parts(e)

func test_enemy_without_row_ignores_limb() -> void:
	var e: Wolf = auto_free(Wolf.new())
	e.rng = RandomNumberGenerator.new()
	e.position = POS
	e.setup()
	var d := e.hurt(_cut_hit("head", 3.0))
	assert_bool(e.head_off).is_false()
	assert_float(d).is_equal_approx(3.0, 0.0001)
