## Лихо Одноглазое (GDD enemies-and-elites §3.8, §3.10): the boss is chosen per
## location, 2 phases, 4 telegraphed attacks (leap, gaze, lunge, woe) with
## wind-ups >= min_windup, the gaze turns after the hero at a limited rate, the
## phase-2 darkness cycle (blink, dark at light_min, off), determinism.
extends GdUnitTestSuite

const G: float = 640.0

static func row() -> Dictionary:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/bosses.json"))
	return (t.likho as Dictionary).duplicate(true)

func _boss(p_seed: int = 42) -> LikhoBoss:
	var e := LikhoBoss.new()
	e.boss_id = "likho"
	e.beaten_before = 0
	e.stats = row()
	e.tier = 2
	e.room_w = 2200.0
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = p_seed
	e.position = Vector2(1300, G)
	e.setup()
	return auto_free(e)

func _hit(e: LairBoss, dmg: float) -> void:
	e.hurt(Hit.make(Hit.Kind.STRIKE, dmg, e.position.x - 10.0, 0.0))

func _attacks(e: LikhoBoss, seconds: float, hero: Vector2) -> Array[String]:
	for i in roundi(seconds / EnemyFixtures.DT):
		e.think(EnemyFixtures.DT, hero)
	return e.attack_log

func test_location_2_makes_likho_and_location_1_kikimora() -> void:
	var locs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/locations.json"))
	assert_str(String(locs["2"].boss)).is_equal("likho")
	var b := LairBoss.make("likho")
	assert_bool(b is LikhoBoss).is_true()
	b.free()
	var k := LairBoss.make("kikimora")
	assert_bool(k is LikhoBoss).is_false()
	k.free()

func test_same_seed_same_attack_sequence() -> void:
	var a := _attacks(_boss(7), 40.0, Vector2(900, G))
	var b := _attacks(_boss(7), 40.0, Vector2(900, G))
	assert_int(a.size()).is_greater(5)
	assert_array(a).is_equal(b)

func test_all_four_attacks_appear_and_wind_up_long_enough() -> void:
	var e := _boss(3)
	var hero := Vector2(900, G)
	var seen := {}
	var mw := float(row().min_windup)
	for i in roundi(120.0 / EnemyFixtures.DT):
		var before := e.st
		e.think(EnemyFixtures.DT, hero)
		if before == "idle" and e.st.ends_with("_w"):
			seen[e.st] = true
			assert_float(e.t).is_greater_equal(mw - 0.0001)
	for s: String in ["leap_w", "gaze_w", "lunge_w", "woe_w"]:
		assert_bool(seen.has(s)).is_true()

func test_gaze_turns_at_most_gaze_turn_per_second() -> void:
	var a := 0.0
	var step := 0.9 * EnemyFixtures.DT
	assert_float(LikhoBoss.turn_toward(a, 2.0, step)).is_equal_approx(step, 1e-6)
	assert_float(LikhoBoss.turn_toward(a, -2.0, step)).is_equal_approx(-step, 1e-6)
	assert_float(LikhoBoss.turn_toward(a, 0.001, step)).is_equal_approx(0.001, 1e-6)
	assert_float(LikhoBoss.ray_dist(Vector2.ZERO, 0.0, 100.0, Vector2(50, 10))).is_equal_approx(10.0, 1e-4)
	assert_float(LikhoBoss.ray_dist(Vector2.ZERO, 0.0, 100.0, Vector2(-5, 0))).is_equal(INF)

func test_woe_zones_count_per_phase_and_inside_the_room() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var xs := LikhoBoss.woe_xs(rng, 100.0, 5, 230.0, 2200.0, 60.0)
	assert_int(xs.size()).is_equal(5)
	assert_float(xs[0]).is_equal(100.0)
	for x in xs:
		assert_float(x).is_between(60.0, 2140.0)
	var e := _boss()
	assert_float(e.per_phase("woe_n")).is_equal(3.0)
	e.phase = 2
	assert_float(e.per_phase("woe_n")).is_equal(5.0)

func test_rage_below_half_and_darkness_cycle() -> void:
	var e := _boss()
	var r := row()
	_hit(e, e.max_hp * 0.45)
	assert_int(e.phase).is_equal(1)
	assert_float(e.light_cap()).is_equal(0.0)
	_hit(e, e.max_hp * 0.1)
	assert_int(e.phase).is_equal(2)
	assert_str(e.st).is_equal("roar")
	var hero := Vector2(900, G)
	var t := 0.0
	while e.dark_state != "blink" and t < 10.0:
		e.think(EnemyFixtures.DT, hero)
		t += EnemyFixtures.DT
	assert_float(t).is_equal_approx(float(r.dark_first), EnemyFixtures.DT * 2.0)
	t = 0.0
	while e.dark_state != "dark" and t < 10.0:
		e.think(EnemyFixtures.DT, hero)
		t += EnemyFixtures.DT
	assert_float(t).is_equal_approx(float(r.dark_blink), EnemyFixtures.DT * 2.0)
	for i in roundi(1.0 / EnemyFixtures.DT):
		e.think(EnemyFixtures.DT, hero)
	assert_float(e.light_cap()).is_equal_approx(AmuletRules.light_min(Tune.data), 0.5)
	t = 0.0
	while e.dark_state == "dark" and t < 10.0:
		e.think(EnemyFixtures.DT, hero)
		t += EnemyFixtures.DT
	assert_float(t).is_equal_approx(float(r.dark_time) - 1.0, EnemyFixtures.DT * 2.0)
	assert_float(e.light_cap()).is_equal(0.0)
	# Summons made outside a world are plain nodes: free them here.
	for m in e.minions:
		m.free()

func test_lines_follow_living_world_4_2() -> void:
	var l: Dictionary = row().lines
	assert_str(LairBoss.pick_line(l, "intro", 0)).is_equal("Раз шаг. Два шаг. Звенишь, звенишь, звенишь.")
	assert_str(LairBoss.pick_line(l, "death", 2)).is_equal("Не буди. Не бу...")