## Упырь-метатель state machine: distance, flight, lob, cornered shove, parry
## (GDD enemies-and-elites §3.4, limb-zones §3.2, parry §3.3, §3.5).
extends GdUnitTestSuite

const G: float = 640.0

func _thrower() -> Thrower:
	var e: Thrower = auto_free(EnemyFixtures.make(Thrower.new(), EnemyFixtures.thrower(), 1, Vector2(1000, G)))
	e.face = -1
	return e

func test_close_hero_makes_it_flee_fast() -> void:
	var e := _thrower()
	e.cd = 99.0
	e.think(EnemyFixtures.DT, Vector2(900, G))
	assert_float(e.vel.x).is_equal(140.0)

func test_far_hero_walks_in_mid_range_backs_off() -> void:
	var e := _thrower()
	e.cd = 99.0
	e.think(EnemyFixtures.DT, Vector2(300, G))
	assert_float(e.vel.x).is_equal(-75.0)
	e.think(EnemyFixtures.DT, Vector2(750, G))
	assert_float(e.vel.x).is_equal(70.0)

func test_aims_then_lobs_an_arcing_stone() -> void:
	var e := _thrower()
	e.cd = 0.0
	var hero := Vector2(600, G)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("aim")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.8, EnemyFixtures.DT + 0.001)
	assert_int(e.orphan_shots.size()).is_equal(1)
	var s := e.orphan_shots[0]
	assert_float(s.grav).is_equal(900.0)
	assert_float(s.vel.x).is_less(0.0)
	assert_float(s.vel.y).is_less(0.0)
	for sh in e.orphan_shots:
		sh.free()

func test_lob_velocity_lands_on_target() -> void:
	var from := Vector2(1000, 574)
	var to := Vector2(600, 600)
	var v := Thrower.lob_velocity(from, to, 380.0, 0.7, 1.4, 900.0)
	var tt := 400.0 / 380.0
	var at := from + v * tt + Vector2(0, 0.5 * 900.0 * tt * tt)
	assert_vector(at).is_equal_approx(to, Vector2(0.01, 0.01))

func test_cornered_and_close_shoves_instead_of_fleeing() -> void:
	var e := _thrower()
	e.room_w = 1100.0
	e.position.x = 1040.0
	e.cd = 99.0
	e.cd2 = 0.0
	e.think(EnemyFixtures.DT, Vector2(970, G))
	assert_str(e.st).is_equal("shove")
	assert_float(e.vel.x).is_equal(0.0)

func test_parried_shove_cuts_throwing_arm() -> void:
	var e := _thrower()
	var p: Player = auto_free(Player.new())
	p.position = Vector2(950, G)
	e.target = p
	p.parry_t = 0.1
	e.st = "shove"
	e.t = 0.0
	e.think(EnemyFixtures.DT, p.position)
	assert_float(p.hp).is_equal(100.0)
	assert_bool(e.arm_off).is_true()
	for part in e.orphan_parts:
		part.free()

func test_bump_parry_while_walking_only_stuns() -> void:
	var e := _thrower()
	e.st = "walk"
	assert_str(e.parried(900.0)).is_equal("stun")
	assert_bool(e.arm_off).is_false()
	assert_float(e.stun).is_greater(0.0)

func test_parry_during_throw_windup_takes_no_arm() -> void:
	var e := _thrower()
	e.st = "aim"
	assert_str(e.parried(900.0)).is_equal("stun")
	assert_bool(e.arm_off).is_false()
