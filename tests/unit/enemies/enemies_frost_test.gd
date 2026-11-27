## Frost enemies (GDD enemies-and-elites §3.2-3.3): Снежный волк crouches (the
## telegraph), bites forward and hops back; Студёный дух marks the floor under
## the hero, then freezes it for zone_time s (no more than zone_max zones).
extends GdUnitTestSuite

const G: float = 640.0

static func _rows() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/enemies.json"))

func _wolf() -> Wolf:
	return auto_free(EnemyFixtures.make(Wolf.new(), (_rows().wolf as Dictionary).duplicate(true), 3, Vector2(1000, G)))

func _spirit() -> ColdSpirit:
	return auto_free(EnemyFixtures.make(ColdSpirit.new(), (_rows().jelly as Dictionary).duplicate(true), 3, Vector2(1000, G - 230)))

func test_roster_makes_the_new_kinds() -> void:
	var w := EnemyRoster.make("wolf")
	var j := EnemyRoster.make("jelly")
	assert_bool(w is Wolf).is_true()
	assert_bool(j is ColdSpirit).is_true()
	w.free()
	j.free()

func test_wolf_crouches_before_the_bite_then_hops_back() -> void:
	var e := _wolf()
	e.cd = 0.0
	var hero := Vector2(800, G)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("crouch")
	assert_bool(e.is_winding()).is_true()
	assert_float(e.t).is_greater_equal(0.4)
	var seen := EnemyFixtures.run(e, 0.5, hero)
	assert_array(seen).contains(["bite"])
	assert_float(e.vel.x).is_less(0.0)
	assert_float(e.contact_damage()).is_greater(float(e.stats.contact))
	seen = EnemyFixtures.run(e, 0.4, hero)
	assert_array(seen).contains(["hop"])
	assert_float(e.vel.x).is_greater(0.0)

func test_wolf_does_not_bite_out_of_range() -> void:
	var e := _wolf()
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(200, G))
	assert_str(e.st).is_equal("run")
	assert_float(e.vel.x).is_less(0.0)

func test_spirit_marks_the_floor_then_freezes_it() -> void:
	var e := _spirit()
	e.cd = 0.0
	var hero := Vector2(900, G)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("chill_w")
	assert_float(e.mark_x).is_equal(900.0)
	assert_bool(e.zones.is_empty()).is_true()
	EnemyFixtures.run(e, float(e.stats.chill_w) + 0.05, Vector2(400, G))
	assert_int(e.zones.size()).is_equal(1)
	# The zone stays where it was marked, not where the hero went.
	assert_bool(e.in_zone(Vector2(900, G))).is_true()
	assert_bool(e.in_zone(Vector2(400, G))).is_false()
	assert_bool(e.in_zone(Vector2(900, G - 120))).is_false()

func test_spirit_zone_melts_and_caps_at_zone_max() -> void:
	var e := _spirit()
	var hero := Vector2(900, G)
	for i in 4:
		e.cd = 0.0
		EnemyFixtures.run(e, float(e.stats.chill_w) + 0.05, hero)
	assert_int(e.zones.size()).is_less_equal(int(e.stats.zone_max))
	e.cd = 99.0
	EnemyFixtures.run(e, float(e.stats.zone_time) + 0.1, hero)
	assert_bool(e.zones.is_empty()).is_true()
