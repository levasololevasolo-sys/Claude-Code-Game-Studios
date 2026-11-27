## Crawler state machine timing (GDD enemies-and-elites §3.4, AC 2).
extends GdUnitTestSuite

const G: float = 640.0

func _crawler(tier: int = 1) -> Crawler:
	return auto_free(EnemyFixtures.make(Crawler.new(), EnemyFixtures.crawler(), tier, Vector2(1000, G)))

func test_in_range_with_cooldown_done_winds_up_and_stops() -> void:
	var e := _crawler()
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(800, G))
	assert_str(e.st).is_equal("wind")
	assert_float(e.vel.x).is_equal(0.0)
	assert_bool(e.is_winding()).is_true()

func test_out_of_range_walks_toward_hero() -> void:
	var e := _crawler()
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(400, G))
	assert_str(e.st).is_equal("walk")
	assert_float(e.vel.x).is_equal(-95.0)

func test_wind_lasts_wind_time_then_charges() -> void:
	var e := _crawler()
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(800, G))
	var secs := EnemyFixtures.time_in_state(e, Vector2(800, G), 2.0)
	assert_float(secs).is_equal_approx(0.5, EnemyFixtures.DT + 0.001)
	assert_str(e.st).is_equal("charge")

func test_charge_then_recover_then_walk_with_new_cooldown() -> void:
	var e := _crawler()
	e.st = "charge"
	e.t = 0.6
	e.face = -1
	assert_float(EnemyFixtures.time_in_state(e, Vector2(800, G), 2.0)).is_equal_approx(0.6, EnemyFixtures.DT + 0.001)
	assert_str(e.st).is_equal("recover")
	assert_float(EnemyFixtures.time_in_state(e, Vector2(800, G), 2.0)).is_equal_approx(0.7, EnemyFixtures.DT + 0.001)
	assert_str(e.st).is_equal("walk")
	assert_float(e.cd).is_between(1.2, 2.4)

func test_charge_contact_is_one_and_a_half_times_walk_contact() -> void:
	var e := _crawler()
	e.st = "walk"
	assert_float(e.contact_damage()).is_equal(12.0)
	e.st = "charge"
	assert_float(e.contact_damage()).is_equal(18.0)

func test_tier1_never_crouches_with_hero_above() -> void:
	var e := _crawler(1)
	e.cd = 0.0
	var seen := EnemyFixtures.run(e, 6.0, Vector2(900, G - 200))
	assert_bool("crouch" in seen).is_false()

func test_tier2_hero_above_crouches_then_leaps_up() -> void:
	var e := _crawler(2)
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(900, G - 200))
	assert_str(e.st).is_equal("crouch")
	EnemyFixtures.time_in_state(e, Vector2(900, G - 200), 2.0)
	assert_str(e.st).is_equal("leap")
	assert_float(e.vel.y).is_equal(-980.0)
	assert_float(e.vel.x).is_equal(-160.0)

func test_tier2_hp_scaled_by_tier_hp() -> void:
	var e := _crawler(2)
	assert_float(e.max_hp).is_equal_approx(34.0 * (1.0 + Tune.f("tier_hp")), 0.001)
