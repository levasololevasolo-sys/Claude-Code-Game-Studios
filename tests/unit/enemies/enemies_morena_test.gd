## Морена (GDD enemies-and-elites §3.8, §3.11; story-bible §2.3): location 3
## makes her, 2 phases, the attacks wind up >= min_windup, the mirror only in
## phase 2, the breath cone is blocked by a pillar, spears leave at most
## pillar_max pillars, a dive into a pillar breaks it (stuck longer, ×1.5
## damage), her first line names Ждан, determinism.
extends GdUnitTestSuite

const G: float = 640.0

static func row() -> Dictionary:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/bosses.json"))
	return (t.morena as Dictionary).duplicate(true)

func _boss(p_seed: int = 42) -> MorenaBoss:
	var e := MorenaBoss.new()
	e.boss_id = "morena"
	e.beaten_before = 0
	e.stats = row()
	e.tier = 3
	e.room_w = 2200.0
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = p_seed
	e.position = Vector2(1300, G - 60)
	e.setup()
	return auto_free(e)

func _hit(e: LairBoss, dmg: float) -> void:
	e.hurt(Hit.make(Hit.Kind.STRIKE, dmg, e.position.x - 10.0, 0.0))

func _attacks(e: MorenaBoss, seconds: float, hero: Vector2) -> Array[String]:
	for i in roundi(seconds / EnemyFixtures.DT):
		e.think(EnemyFixtures.DT, hero)
	return e.attack_log

func test_location_3_makes_morena_and_she_names_zhdan() -> void:
	var locs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/locations.json"))
	assert_str(String(locs["3"].boss)).is_equal("morena")
	var b := LairBoss.make("morena")
	assert_bool(b is MorenaBoss).is_true()
	b.free()
	assert_str(LairBoss.pick_line(row().lines, "intro", 0)).contains("Ждан")
	assert_str(LairBoss.pick_line(row().lines, "death", 0)).is_not_empty()

func test_same_seed_same_attack_sequence() -> void:
	var a := _attacks(_boss(7), 40.0, Vector2(900, G))
	var b := _attacks(_boss(7), 40.0, Vector2(900, G))
	assert_int(a.size()).is_greater(5)
	assert_array(a).is_equal(b)

func test_phase_1_attacks_wind_up_and_no_mirror() -> void:
	var e := _boss(3)
	var mw := float(row().min_windup)
	var seen := {}
	for i in roundi(120.0 / EnemyFixtures.DT):
		var before := e.st
		e.think(EnemyFixtures.DT, Vector2(900, G))
		if before == "idle" and e.st.ends_with("_w"):
			seen[e.st] = true
			assert_float(e.t).is_greater_equal(mw - 0.0001)
	assert_array(seen.keys()).contains(["breath_w", "spears_w", "scythe_w", "dive_w"])
	assert_bool(seen.has("mirror_w")).is_false()

func test_phase_2_below_half_and_the_mirror_appears() -> void:
	var e := _boss(5)
	_hit(e, e.max_hp * 0.52)
	assert_int(e.phase).is_equal(2)
	assert_str(e.st).is_equal("roar")
	e.summon_queue.clear()
	var log := _attacks(e, 90.0, Vector2(900, G))
	assert_array(log).contains(["mirror"])

func test_breath_cone_and_pillar_cover() -> void:
	var o := Vector2(1000, 400)
	var ang := (Vector2(800, 600) - o).angle()
	assert_bool(MorenaBoss.in_cone(o, ang, 520.0, 0.34, Vector2(800, 600))).is_true()
	assert_bool(MorenaBoss.in_cone(o, ang, 520.0, 0.34, Vector2(1200, 600))).is_false()
	assert_bool(MorenaBoss.in_cone(o, ang, 200.0, 0.34, Vector2(800, 600))).is_false()
	var xs: Array[float] = [900.0]
	assert_bool(MorenaBoss.pillar_between(xs, 1000.0, 800.0)).is_true()
	assert_bool(MorenaBoss.pillar_between(xs, 1000.0, 950.0)).is_false()

func test_spear_xs_drop_the_ones_off_the_arena() -> void:
	var xs := MorenaBoss.spear_xs(100.0, [0, -280, 280], 2200.0, 50.0)
	assert_array(xs).is_equal([100.0, 380.0])

func test_spears_leave_at_most_pillar_max_pillars() -> void:
	var e := _boss(11)
	e.stats["pillar_chance"] = 1.0
	for k in 4:
		e.hazards.append({ "kind": "spear", "x": 300.0 + k * 400.0, "t": 0.0, "hit": false, "done": false })
	e.st = "stuck"
	e.t = 99.0
	for i in roundi(2.0 / EnemyFixtures.DT):
		e.think(EnemyFixtures.DT, Vector2(100, G))
	assert_int(e.pillars.size()).is_equal(int(row().pillar_max))
	assert_bool(e.hazards.is_empty()).is_true()

func test_dive_into_a_pillar_breaks_it_and_she_takes_more() -> void:
	var e := _boss(13)
	e.pillars.append(900.0)
	e.st = "dive"
	e.dive_x = 900.0
	e.t = float(row().dive_time)
	for i in 120:
		e.think(EnemyFixtures.DT, Vector2(900, G))
		if e.st == "stuck":
			break
	assert_str(e.st).is_equal("stuck")
	assert_bool(e.pillars.is_empty()).is_true()
	assert_float(e.t).is_equal_approx(float(row().dive_stuck_pillar), 0.001)
	var before := e.hp
	_hit(e, 10.0)
	assert_float(before - e.hp).is_equal_approx(10.0 * float(row().dive_pillar_mult), 0.01)

func test_dive_on_open_floor_stuck_for_the_phase_time() -> void:
	var e := _boss(17)
	e.st = "dive"
	e.dive_x = 900.0
	e.t = float(row().dive_time)
	for i in 120:
		e.think(EnemyFixtures.DT, Vector2(900, G))
		if e.st == "stuck":
			break
	assert_float(e.t).is_equal_approx(float((row().dive_stuck as Array)[0]), 0.001)
	assert_float(e.stuck_k).is_equal(1.0)
