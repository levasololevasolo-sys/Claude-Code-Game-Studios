## Unit tests for LimbRules (GDD limb-zones F1-F5, §3) and the Enemy side:
## the arm only by a parry, the head only by a down-air hit on an attacking
## enemy, tough kinds and elites need N, two death variants.
extends GdUnitTestSuite

## Fixture row and tuning (the rules are tested, not the shipped numbers).
const ROW := { "arm": [0.2, 1.6, 0.1, 0.8], "head": [-0.25, 0.4, 0.74, 1.0], "attack_states": ["appear", "swipe"],
	"one_arm": { "swipe_x": 0.5 } }
const TUNE := { "limb_head_bonus": 2.0, "limb_contact_depth": 6.0, "limb_elites": 1, "limb_elite_hits_needed": 3,
	"death_sever_chance": 0.3 }
const W: float = 40.0
const H: float = 70.0
const POS := Vector2(500, 640)

func _hurt_rect() -> Rect2:
	return Rect2(POS.x - W / 2.0, POS.y - H, W, H)

func _pick(strike: Rect2, dir: String, hero_x: float, air: bool, st: String, face: int = -1, head_off: bool = false) -> String:
	return LimbRules.pick(strike, _hurt_rect(), ROW, POS, W, H, face, dir, hero_x, air, st, false, head_off, TUNE)

func _zone(strike: Rect2, dir: String, hero_x: float, face: int = -1) -> String:
	return LimbRules.zone_of(strike, _hurt_rect(), ROW, POS, W, H, face, dir, hero_x, false, false, TUNE)

## A side swing from the left at the hero's height (like Player.strike_rect side).
func _side() -> Rect2:
	return Rect2(430, 640 - 78, 82, 84)

## A down strike column over the enemy (like Player.strike_rect down).
func _down() -> Rect2:
	return Rect2(460, 640 - 150, 80, 130)

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

func test_zone_of_front_swing_is_arm_and_down_over_head_is_head() -> void:
	assert_str(_zone(_side(), "side", 430.0)).is_equal("arm")
	assert_str(_zone(_side(), "side", 430.0, 1)).is_equal("body")
	assert_str(_zone(_down(), "down", 500.0)).is_equal("head")

# ---- strikes: never the arm, the head only in an attack -------------------------

func test_pick_front_swing_during_attack_never_cuts_arm() -> void:
	assert_str(_pick(_side(), "side", 430.0, false, "swipe")).is_equal("")

func test_pick_down_air_over_head_during_attack_pops_head() -> void:
	assert_str(_pick(_down(), "down", 500.0, true, "appear")).is_equal("head")

func test_pick_down_air_over_head_outside_attack_is_plain() -> void:
	assert_str(_pick(_down(), "down", 500.0, true, "walk")).is_equal("")

func test_pick_down_from_ground_is_plain() -> void:
	assert_str(_pick(_down(), "down", 500.0, false, "swipe")).is_equal("")

func test_pick_head_already_off_is_plain() -> void:
	assert_str(_pick(_down(), "down", 500.0, true, "swipe", -1, true)).is_equal("")

func test_resolve_up_strike_on_head_is_plain() -> void:
	assert_str(LimbRules.resolve("head", "up", true, "swipe", ROW, false, false)).is_equal("")

func test_resolve_beast_never_cuts_alive() -> void:
	var beast := { "head": [0.3, 0.7, 0.45, 1.0], "death_only": true, "attack_states": ["bite"] }
	assert_str(LimbRules.resolve("head", "down", true, "bite", beast, false, false)).is_equal("")

# ---- parry -------------------------------------------------------------------------

func test_parry_takes_arm_only_in_attack_with_a_cuttable_arm() -> void:
	assert_bool(LimbRules.parry_takes_arm(ROW, "swipe", false)).is_true()
	assert_bool(LimbRules.parry_takes_arm(ROW, "walk", false)).is_false()
	assert_bool(LimbRules.parry_takes_arm(ROW, "swipe", true)).is_false()
	assert_bool(LimbRules.parry_takes_arm({ "head": [0, 1, 0, 1], "attack_states": ["bash"] }, "bash", false)).is_false()

# ---- formulas ---------------------------------------------------------------------

func test_bonus_mult_only_head() -> void:
	assert_float(LimbRules.bonus_mult("head", TUNE)).is_equal_approx(2.0, 0.0001)
	assert_float(LimbRules.bonus_mult("arm", TUNE)).is_equal_approx(1.0, 0.0001)
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

func test_hits_needed_tough_and_elite_use_knob() -> void:
	assert_int(LimbRules.hits_needed({ "tough": true }, false, TUNE)).is_equal(3)
	assert_int(LimbRules.hits_needed({}, true, TUNE)).is_equal(3)
	assert_int(LimbRules.hits_needed({}, false, TUNE)).is_equal(1)

func test_cuts_now_only_on_the_needed_hit() -> void:
	assert_bool(LimbRules.cuts_now(2, 3)).is_false()
	assert_bool(LimbRules.cuts_now(3, 3)).is_true()

# ---- two death variants ---------------------------------------------------------

func test_death_part_zone_decides_first() -> void:
	assert_str(LimbRules.death_part("head", 0.99, ROW, false, false, TUNE)).is_equal("head")
	assert_str(LimbRules.death_part("arm", 0.99, ROW, false, false, TUNE)).is_equal("arm")

func test_death_part_body_uses_chance() -> void:
	assert_str(LimbRules.death_part("body", 0.29, ROW, false, false, TUNE)).is_equal("head")
	assert_str(LimbRules.death_part("body", 0.31, ROW, false, false, TUNE)).is_equal("")
	assert_str(LimbRules.death_part("body", 0.1, ROW, false, true, TUNE)).is_equal("arm")

func test_death_part_no_row_plain() -> void:
	assert_str(LimbRules.death_part("head", 0.0, {}, false, false, TUNE)).is_equal("")

# ---- on real enemies (shipped limb_zones.json rows) ------------------------------------

func _enemy(e: Enemy, kind: String) -> Enemy:
	auto_free(e)
	e.kind_id = kind
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = 5
	e.position = POS
	e.setup()
	return e

func _strike(limb: String, dmg: float, zone: String = "body") -> Hit:
	var h := Hit.make(Hit.Kind.STRIKE, dmg, POS.x - 60.0, 0.0)
	h.limb = limb
	h.zone = zone
	return h

func _free_parts(e: Enemy) -> void:
	for p in e.orphan_parts:
		p.free()
	e.orphan_parts.clear()

func test_enemy_strike_marked_arm_never_cuts() -> void:
	var e := _enemy(Ringer.new(), "ringer")
	e.st = "swipe"
	var d := e.hurt(_strike("arm", 4.0, "arm"))
	assert_bool(e.arm_off).is_false()
	assert_float(d).is_equal_approx(4.0, 0.0001)

func test_enemy_parry_in_attack_cuts_arm_once() -> void:
	var e := _enemy(Ringer.new(), "ringer")
	e.st = "swipe"
	assert_str(e.parried(POS.x - 60.0)).is_equal("arm")
	assert_bool(e.arm_off).is_true()
	assert_float(e.stun).is_greater(0.0)
	e.st = "swipe"
	assert_str(e.parried(POS.x - 60.0)).is_equal("stun")
	assert_int(e.orphan_parts.size()).is_equal(1)
	_free_parts(e)

func test_enemy_parry_outside_attack_only_stuns() -> void:
	var e := _enemy(Ringer.new(), "ringer")
	e.st = "walk"
	assert_str(e.parried(POS.x - 60.0)).is_equal("stun")
	assert_bool(e.arm_off).is_false()
	assert_float(e.stun).is_equal_approx(Tune.f("parry_stun"), 0.0001)

func test_knight_arm_flies_only_on_third_parry() -> void:
	var e := _enemy(Knight.new(), "knight")
	for i in 2:
		e.st = "lunge"
		assert_str(e.parried(POS.x - 60.0)).is_equal("nick")
	assert_bool(e.arm_off).is_false()
	e.st = "lunge"
	assert_str(e.parried(POS.x - 60.0)).is_equal("arm")
	assert_bool(e.arm_off).is_true()
	_free_parts(e)

func test_sentry_shield_arm_never_cut() -> void:
	var e := _enemy(Sentry.new(), "sentry")
	e.st = "bash"
	assert_str(e.parried(POS.x - 60.0)).is_equal("stun")
	assert_bool(e.arm_off).is_false()
	assert_bool(e.front_shield).is_true()

func test_elite_head_needs_counted_hits() -> void:
	var e := Ringer.new()
	e.mark = "fire"
	_enemy(e, "ringer")
	for i in int(Tune.f("limb_elite_hits_needed")) - 1:
		e.hurt(_strike("head", 0.5, "head"))
	assert_bool(e.head_off).is_false()
	e.hurt(_strike("head", 0.5, "head"))
	assert_bool(e.head_off).is_true()
	_free_parts(e)

func test_enemy_headless_does_not_die_of_head_loss() -> void:
	var e := _enemy(Ringer.new(), "ringer")
	var d := e.hurt(_strike("head", 2.0, "head"))
	assert_bool(e.head_off).is_true()
	assert_bool(e.dead).is_false()
	assert_float(d).is_equal_approx(2.0 * Tune.f("limb_head_bonus"), 0.0001)
	assert_float(e.hp).is_equal_approx(e.max_hp - d, 0.0001)
	_free_parts(e)

func test_enemy_killing_blow_on_head_zone_throws_head() -> void:
	var e := _enemy(Wolf.new(), "wolf")
	e.hurt(_strike("", e.hp, "head"))
	assert_bool(e.dead).is_true()
	assert_str(e.death_severed).is_equal("head")
	assert_int(e.orphan_parts.size()).is_equal(1)
	assert_float(e.orphan_parts[0].dmg).is_equal(0.0)
	_free_parts(e)

func test_boss_parry_short_stun_no_parts() -> void:
	var e := _enemy(Ringer.new(), "ringer")
	e.boss = true
	e.st = "swipe"
	assert_str(e.parried(POS.x)).is_equal("stun")
	assert_float(e.stun).is_equal_approx(Tune.f("parry_boss_stun"), 0.0001)
	assert_bool(e.arm_off).is_false()

func test_enemy_without_row_ignores_limb() -> void:
	var e := _enemy(Bat.new(), "bat")
	var d := e.hurt(_strike("head", 3.0, "head"))
	assert_bool(e.head_off).is_false()
	assert_float(d).is_equal_approx(3.0, 0.0001)
