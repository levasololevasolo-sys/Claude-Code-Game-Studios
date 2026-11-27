## Elites and navi marks (GDD enemies-and-elites §3.6, §5 edge 5, §7) and the
## knight (§3.7). Rules in EliteMarks; numbers from Tune (tuning.json).
extends GdUnitTestSuite

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_marks_respect_the_compatibility_table() -> void:
	var bad: Array = []
	for s in 300:
		var r := _rng(s)
		if EliteMarks.pick(r, "bloat", Tune.data) == "blast":
			bad.append("bloat blast")
		if EliteMarks.pick(r, "sentry", Tune.data) == "ward":
			bad.append("sentry ward")
	assert_array(bad).is_empty()

func test_every_mark_shows_up_for_a_crawler() -> void:
	var seen := {}
	for s in 300:
		seen[EliteMarks.pick(_rng(s), "crawler", Tune.data)] = true
	assert_int(seen.size()).is_equal((Tune.get_value("elite_marks") as Dictionary).size())

func test_no_fitting_mark_falls_back_to_blast_then_call() -> void:
	var t := { "elite_marks": { "fire": {} }, "elite_forbid": { "x": ["fire"], "y": ["fire", "blast"] }, "elite_fallback": ["blast", "call"] }
	assert_str(EliteMarks.pick(_rng(1), "x", t)).is_equal("blast")
	assert_str(EliteMarks.pick(_rng(1), "y", t)).is_equal("call")

func test_ward_takes_damage_first_and_breaking_hits_count_double() -> void:
	assert_vector(EliteMarks.ward_absorb(20.0, 10.0, false, 2.0)).is_equal(Vector2(10.0, 0.0))
	assert_vector(EliteMarks.ward_absorb(20.0, 30.0, false, 2.0)).is_equal(Vector2(20.0, 10.0))
	assert_vector(EliteMarks.ward_absorb(20.0, 15.0, true, 2.0)).is_equal(Vector2(20.0, 5.0))
	assert_vector(EliteMarks.ward_absorb(0.0, 15.0, true, 2.0)).is_equal(Vector2(0.0, 15.0))

func test_blink_lands_past_the_hero_inside_the_room() -> void:
	assert_float(EliteMarks.blink_x(100.0, 500.0, 200.0, 30.0, 2000.0)).is_equal(700.0)
	assert_float(EliteMarks.blink_x(900.0, 500.0, 200.0, 30.0, 2000.0)).is_equal(300.0)
	# Edge 4: near the wall it lands on the near side instead.
	assert_float(EliteMarks.blink_x(1500.0, 1900.0, 200.0, 30.0, 2000.0)).is_equal(1700.0)

func test_death_blast_hits_only_inside_its_radius() -> void:
	assert_float(EliteMarks.blast_damage(100.0, Tune.data)).is_equal(Tune.f("death_blast_dmg"))
	assert_float(EliteMarks.blast_damage(Tune.f("death_blast_r") + 1.0, Tune.data)).is_equal(0.0)

func test_elite_gets_hp_size_damage_and_ward() -> void:
	var plain: Crawler = auto_free(EnemyFixtures.make(Crawler.new(), EnemyFixtures.crawler(), 1, Vector2(1000, 640)))
	var e := Crawler.new()
	e.mark = "ward"
	e = auto_free(EnemyFixtures.make(e, EnemyFixtures.crawler(), 1, Vector2(1000, 640)))
	assert_float(e.max_hp).is_equal_approx(plain.max_hp * Tune.f("elite_hp"), 0.001)
	assert_float(e.w).is_equal_approx(plain.w * Tune.f("elite_size"), 0.001)
	assert_float(e.dmg_mult()).is_equal_approx(plain.dmg_mult() * Tune.f("elite_dmg"), 0.001)
	assert_float(e.ward).is_equal_approx(e.max_hp * Tune.f("shield_frac"), 0.001)

func test_knight_row_matches_the_gdd() -> void:
	var k := Tune.row("enemies", "knight")
	assert_float(float(k.hp)).is_equal(230.0)
	assert_float(float(k.dmg)).is_equal(20.0)
	assert_float(float(k.speed)).is_equal(150.0)

func test_knight_winds_up_in_range_then_lunges_and_guards() -> void:
	var kn: Knight = auto_free(EnemyFixtures.make(Knight.new(), Tune.row("enemies", "knight"), 1, Vector2(1000, 640)))
	kn.cd = 0.0
	kn.think(EnemyFixtures.DT, Vector2(800, 640))
	assert_str(kn.st).is_equal("wind")
	kn.think(float(kn.stats.wind) + 0.01, Vector2(800, 640))
	assert_str(kn.st).is_equal("lunge")
	assert_float(kn.vel.x).is_equal(-float(kn.stats.lunge))
	kn.think(float(kn.stats.lunge_time) + 0.01, Vector2(800, 640))
	assert_str(kn.st).is_equal("guard")
	assert_bool(kn.hit_view().shield).is_true()

func test_raging_knight_uses_the_rage_numbers() -> void:
	var kn: Knight = auto_free(EnemyFixtures.make(Knight.new(), Tune.row("enemies", "knight"), 1, Vector2(1000, 640)))
	kn.hp = kn.max_hp * 0.4
	assert_bool(kn.raging()).is_true()
	kn.cd = 0.0
	kn.think(EnemyFixtures.DT, Vector2(800, 640))
	kn.think(float(kn.stats.rage_wind) + 0.01, Vector2(800, 640))
	assert_str(kn.st).is_equal("lunge")
	assert_float(absf(kn.vel.x)).is_equal(float(kn.stats.rage_lunge))

func test_trap_cycle_warns_before_it_hurts() -> void:
	var tr: Trap = auto_free(Trap.new())
	tr.t = 0.0
	assert_str(tr.step(0.01)).is_equal("warn")
	assert_float(Tune.f("trap_warn")).is_greater_equal(0.5)
	assert_str(tr.step(Tune.f("trap_warn"))).is_equal("active")
	assert_str(tr.step(Tune.f("trap_active"))).is_equal("idle")
