## Bloat state machine timing (GDD enemies-and-elites §3.4, Edge Cases 1-2).
extends GdUnitTestSuite

const G: float = 640.0

func _bloat() -> Bloat:
	return auto_free(EnemyFixtures.make(Bloat.new(), EnemyFixtures.bloat(), 1, Vector2(1000, 400)))

func test_far_hero_approaches_at_speed() -> void:
	var e := _bloat()
	e.think(EnemyFixtures.DT, Vector2(400, 400 + 28 + 40))
	assert_str(e.st).is_equal("approach")
	assert_float(e.vel.x).is_equal_approx(-75.0, 0.5)

func test_close_hero_swells_and_bursts_after_fuse() -> void:
	var e := _bloat()
	var hero := Vector2(950, 400 - 28 + 40)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("swell")
	assert_bool(e.is_winding()).is_true()
	var n := 1
	while not e.exploded and n < 600:
		e.think(EnemyFixtures.DT, hero)
		n += 1
	assert_float(n * EnemyFixtures.DT).is_equal_approx(0.85 + EnemyFixtures.DT, EnemyFixtures.DT + 0.001)
	assert_bool(e.dead).is_true()

func test_burst_hurts_hero_in_radius_through_player_hurt() -> void:
	var e := _bloat()
	var p: Player = auto_free(Player.new())
	p.position = Vector2(1000, 400 - 28 + 32 + 60)
	e.target = p
	e.burst()
	assert_float(p.hp).is_equal_approx(100.0 - 22.0, 0.001)

func test_self_burst_emits_no_died_signal() -> void:
	var e := _bloat()
	var died := [false]
	e.died.connect(func(_e: Enemy, _h: Hit) -> void: died[0] = true)
	e.st = "swell"
	e.t = 0.0
	e.think(EnemyFixtures.DT, Vector2(1000, 400))
	assert_bool(e.exploded).is_true()
	assert_bool(died[0]).is_false()

func test_killed_bloat_bursts_after_death_fuse() -> void:
	var e := _bloat()
	e.hurt(Hit.make(Hit.Kind.STRIKE, 999.0, 900.0, 0.0))
	assert_bool(e.dead).is_true()
	var n := 0
	while not e.exploded and n < 600:
		e._dead_tick(EnemyFixtures.DT)
		n += 1
	assert_float(n * EnemyFixtures.DT).is_equal_approx(0.35, EnemyFixtures.DT + 0.001)
