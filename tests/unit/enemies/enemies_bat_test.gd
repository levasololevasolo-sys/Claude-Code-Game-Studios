## Bat state machine timing (GDD enemies-and-elites §3.4, AC 2).
extends GdUnitTestSuite

const G: float = 640.0

func _bat(tier: int = 1) -> Bat:
	return auto_free(EnemyFixtures.make(Bat.new(), EnemyFixtures.bat(), tier, Vector2(800, 400)))

func test_hover_cooldown_done_starts_wind() -> void:
	var e := _bat()
	e.cd = EnemyFixtures.DT / 2.0
	e.think(EnemyFixtures.DT, Vector2(1000, G))
	assert_str(e.st).is_equal("wind")
	assert_bool(e.is_winding()).is_true()

func test_wind_lasts_wind_time_then_swoops_at_aim() -> void:
	var e := _bat()
	e.st = "wind"
	e.t = 0.55
	var hero := Vector2(1000, G)
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.55, EnemyFixtures.DT + 0.001)
	assert_str(e.st).is_equal("swoop")
	assert_float(e.vel.length()).is_equal_approx(540.0, 0.01)
	assert_float(e.vel.x).is_greater(0.0)
	assert_float(e.vel.y).is_greater(0.0)

func test_swoop_ends_after_swoop_time_with_new_cooldown() -> void:
	var e := _bat()
	e.st = "swoop"
	e.t = 0.85
	assert_float(EnemyFixtures.time_in_state(e, Vector2(1000, G), 2.0)).is_equal_approx(0.85, EnemyFixtures.DT + 0.001)
	assert_str(e.st).is_equal("hover")
	assert_float(e.cd).is_between(1.6, 2.8)

func test_tier1_never_spits_over_many_attacks() -> void:
	var e := _bat(1)
	var spat := false
	for i in 200:
		e.st = "hover"
		e.cd = 0.0
		e.think(EnemyFixtures.DT, Vector2(1000, G))
		spat = spat or e.st == "spitwind"
	assert_bool(spat).is_false()

func test_tier2_spitwind_fires_fan_of_three_globs() -> void:
	var e := _bat(2)
	e.st = "spitwind"
	e.t = 0.0
	e.think(EnemyFixtures.DT, Vector2(1000, G))
	assert_int(e.orphan_shots.size()).is_equal(3)
	assert_float(e.orphan_shots[0].vel.length()).is_equal_approx(280.0, 0.01)
	assert_str(e.st).is_equal("hover")
	for s in e.orphan_shots:
		s.free()
