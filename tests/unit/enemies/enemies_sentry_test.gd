## Упырь-щитник (melee shield-bearer) state machine, front shield and parry
## (GDD enemies-and-elites §3.4, parry §3.3 item 6).
extends GdUnitTestSuite

const G: float = 640.0

func _sentry() -> Sentry:
	var e: Sentry = auto_free(EnemyFixtures.make(Sentry.new(), EnemyFixtures.sentry(), 1, Vector2(1000, G)))
	e.face = -1
	return e

func test_walks_at_hero_in_front_stops_at_stop() -> void:
	var e := _sentry()
	e.cd2 = 99.0
	e.think(EnemyFixtures.DT, Vector2(600, G))
	assert_float(e.vel.x).is_equal(-65.0)
	e.think(EnemyFixtures.DT, Vector2(950, G))
	assert_float(e.vel.x).is_equal(0.0)

func test_never_shoots() -> void:
	var e := _sentry()
	e.cd = 0.0
	e.cd2 = 99.0
	for i in 300:
		e.think(EnemyFixtures.DT, Vector2(600, G))
	assert_int(e.orphan_shots.size()).is_equal(0)

func test_turns_only_after_turn_time_behind() -> void:
	var e := _sentry()
	e.cd2 = 99.0
	var behind := Vector2(1300, G)
	for i in 40:
		e.think(EnemyFixtures.DT, behind)
	assert_int(e.face).is_equal(-1)
	for i in 5:
		e.think(EnemyFixtures.DT, behind)
	assert_int(e.face).is_equal(1)

func test_hero_in_front_and_close_bash_winds_up_slowly() -> void:
	var e := _sentry()
	e.cd2 = 0.0
	e.think(EnemyFixtures.DT, Vector2(930, G))
	assert_str(e.st).is_equal("bash")
	assert_float(EnemyFixtures.time_in_state(e, Vector2(930, G), 2.0)).is_equal_approx(0.6, EnemyFixtures.DT + 0.001)
	assert_float(e.cd2).is_equal_approx(2.0, 0.001)

func test_bash_hits_hero_through_player_hurt() -> void:
	var e := _sentry()
	var p: Player = auto_free(Player.new())
	p.position = Vector2(930, G)
	e.target = p
	e.st = "bash"
	e.t = 0.0
	e.think(EnemyFixtures.DT, p.position)
	assert_float(p.hp).is_equal_approx(100.0 - 16.0, 0.001)

func test_parried_bash_only_stuns_shield_arm_stays() -> void:
	var e := _sentry()
	var p: Player = auto_free(Player.new())
	p.position = Vector2(930, G)
	e.target = p
	p.parry_t = 0.1
	e.st = "bash"
	e.t = 0.0
	e.think(EnemyFixtures.DT, p.position)
	assert_float(p.hp).is_equal(100.0)
	assert_bool(e.arm_off).is_false()
	assert_float(e.stun).is_greater(0.0)
	assert_str(e.st).is_equal("idle")

func test_front_strike_stopped_back_strike_full() -> void:
	var e := _sentry()
	var front := Hit.make(Hit.Kind.STRIKE, 20.0, 900.0, 0.0)
	var back := Hit.make(Hit.Kind.STRIKE, 20.0, 1100.0, 0.0)
	assert_float(DamageRules.final(front, e.hit_view(), Tune.data)).is_equal(0.0)
	assert_float(DamageRules.final(back, e.hit_view(), Tune.data)).is_equal(20.0)

func test_stunned_shield_does_not_hold() -> void:
	var e := _sentry()
	e.stun = 0.5
	var front := Hit.make(Hit.Kind.STRIKE, 20.0, 900.0, 0.0)
	assert_float(DamageRules.final(front, e.hit_view(), Tune.data)).is_equal(20.0)
