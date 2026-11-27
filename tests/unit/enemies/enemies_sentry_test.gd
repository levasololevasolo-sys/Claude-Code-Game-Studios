## Sentry state machine timing and front shield (GDD enemies-and-elites §3.4, AC 3).
extends GdUnitTestSuite

const G: float = 640.0

func _sentry() -> Sentry:
	var e: Sentry = auto_free(EnemyFixtures.make(Sentry.new(), EnemyFixtures.sentry(), 1, Vector2(1000, G)))
	e.face = -1
	return e

func test_cooldown_done_aims_then_fires_after_aim_time() -> void:
	var e := _sentry()
	e.cd = 0.0
	var hero := Vector2(650, G)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("aim")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.6, EnemyFixtures.DT + 0.001)
	assert_int(e.orphan_shots.size()).is_equal(1)
	assert_float(e.orphan_shots[0].vel.length()).is_equal_approx(310.0, 0.01)
	assert_float(e.orphan_shots[0].vel.x).is_less(0.0)
	assert_float(e.cd).is_between(2.4 * 0.85, 2.4 * 1.15)
	for s in e.orphan_shots:
		s.free()

func test_hero_too_close_backs_away_too_far_walks_in() -> void:
	var e := _sentry()
	e.cd = 99.0
	e.think(EnemyFixtures.DT, Vector2(850, G))
	assert_float(e.vel.x).is_equal(60.0)
	e.think(EnemyFixtures.DT, Vector2(400, G))
	assert_float(e.vel.x).is_equal(-70.0)

func test_turns_only_after_turn_time_behind() -> void:
	var e := _sentry()
	e.cd = 99.0
	e.cd2 = 99.0
	var behind := Vector2(1300, G)
	for i in 40:
		e.think(EnemyFixtures.DT, behind)
	assert_int(e.face).is_equal(-1)
	for i in 5:
		e.think(EnemyFixtures.DT, behind)
	assert_int(e.face).is_equal(1)

func test_hero_in_front_and_close_bash_winds_up() -> void:
	var e := _sentry()
	e.cd2 = 0.0
	e.think(EnemyFixtures.DT, Vector2(930, G))
	assert_str(e.st).is_equal("bash")
	assert_float(EnemyFixtures.time_in_state(e, Vector2(930, G), 2.0)).is_equal_approx(0.35, EnemyFixtures.DT + 0.001)
	assert_float(e.cd2).is_equal_approx(2.2, 0.001)

func test_bash_hits_hero_through_player_hurt() -> void:
	var e := _sentry()
	var p: Player = auto_free(Player.new())
	p.position = Vector2(930, G)
	e.target = p
	e.st = "bash"
	e.t = 0.0
	e.think(EnemyFixtures.DT, p.position)
	assert_float(p.hp).is_equal_approx(100.0 - 14.0, 0.001)

func test_front_strike_deals_sentry_block_back_strike_full() -> void:
	var e := _sentry()
	var front := Hit.make(Hit.Kind.STRIKE, 20.0, 900.0, 0.0)
	var back := Hit.make(Hit.Kind.STRIKE, 20.0, 1100.0, 0.0)
	assert_float(DamageRules.final(front, e.hit_view(), Tune.data)).is_equal_approx(20.0 * Tune.f("sentry_block"), 0.001)
	assert_float(DamageRules.final(back, e.hit_view(), Tune.data)).is_equal(20.0)
