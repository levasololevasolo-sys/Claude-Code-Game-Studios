## Forest enemies (GDD enemies-and-elites §3.2-3.3): Аука steps out behind the
## hero after a marked call, Лешачонок burrows to the hero's x and bursts up
## after a mound telegraph; neither can be hit while gone / under.
extends GdUnitTestSuite

const G: float = 640.0

static func ringer_row() -> Dictionary:
	return { "w": 36, "h": 70, "hp": 40, "flies": false, "weight": 1.2, "contact": 6, "color": "#3f5240", "eye": "#ffb35c",
		"speed": 85, "stop": 150, "range_x": 560, "range_y": 160, "call": 0.7, "gone": 0.35, "behind_dx": 130,
		"appear": 0.45, "swipe_time": 0.2, "swipe_step": 180, "swipe_x": 90, "swipe_dmg": 13, "recover": 0.8,
		"cd_min": 2.0, "cd_max": 3.2 }

static func rootling_row() -> Dictionary:
	return { "w": 40, "h": 42, "hp": 30, "flies": false, "weight": 0.9, "contact": 8, "color": "#5b4632", "eye": "#c8f07a",
		"speed": 80, "range_x": 640, "range_y": 200, "dig": 0.5, "under_max": 2.2, "under_speed": 300, "under_stop": 12,
		"rise_w": 0.6, "burst_up": 620, "burst_time": 0.3, "burst_r": 60, "burst_h": 120, "burst_dmg": 14, "recover": 0.9,
		"cd_min": 1.8, "cd_max": 3.0 }

func _ringer() -> Ringer:
	return auto_free(EnemyFixtures.make(Ringer.new(), ringer_row(), 2, Vector2(1000, G)))

func _rootling() -> Rootling:
	return auto_free(EnemyFixtures.make(Rootling.new(), rootling_row(), 2, Vector2(1000, G)))

func test_ringer_calls_then_reappears_behind_the_hero() -> void:
	var e := _ringer()
	e.cd = 0.0
	var hero := Vector2(700, G)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("call")
	assert_bool(e.is_winding()).is_true()
	assert_float(e.dest_x).is_equal(700.0 - 130.0)
	var seen := EnemyFixtures.run(e, 1.3, hero)
	assert_array(seen).contains(["gone", "appear"])
	assert_float(e.position.x).is_equal(570.0)
	assert_int(e.face).is_equal(1)

func test_ringer_cannot_be_hit_while_gone() -> void:
	var e := _ringer()
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(700, G))
	EnemyFixtures.time_in_state(e, Vector2(700, G), 2.0)
	assert_str(e.st).is_equal("gone")
	assert_bool(e.hurt_rect().has_point(e.center())).is_false()
	assert_float(e.contact_damage()).is_equal(0.0)

func test_ringer_call_lasts_its_wind_up() -> void:
	var e := _ringer()
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(700, G))
	assert_float(EnemyFixtures.time_in_state(e, Vector2(700, G), 2.0)).is_equal_approx(0.7, EnemyFixtures.DT + 0.001)

func test_rootling_digs_travels_under_and_bursts_after_the_mound() -> void:
	var e := _rootling()
	e.cd = 0.0
	var hero := Vector2(800, G)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("dig")
	EnemyFixtures.time_in_state(e, hero, 2.0)
	assert_str(e.st).is_equal("under")
	assert_bool(e.hurt_rect().has_point(e.center())).is_false()
	# Tests drive think() only, so move it by hand as _move() would.
	for i in 120:
		e.position.x += e.vel.x * EnemyFixtures.DT
		e.think(EnemyFixtures.DT, hero)
		if e.st != "under":
			break
	assert_str(e.st).is_equal("rise_w")
	assert_float(absf(e.position.x - 800.0)).is_less_equal(12.0 + 300.0 * EnemyFixtures.DT)
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.6, EnemyFixtures.DT + 0.001)
	assert_str(e.st).is_equal("burst")
	assert_bool(e.burst_hit).is_true()

func test_rootling_same_seed_same_states() -> void:
	var a := _rootling()
	var b := _rootling()
	assert_array(EnemyFixtures.run(a, 6.0, Vector2(800, G))).is_equal(EnemyFixtures.run(b, 6.0, Vector2(800, G)))

func test_forest_kinds_are_in_the_roster_and_table() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/enemies.json"))
	for id: String in ["ringer", "rootling"]:
		assert_bool(table.has(id)).is_true()
		assert_bool(EnemyRoster.KINDS.has(id)).is_true()
		assert_bool(bool(table[id].flies)).is_false()
