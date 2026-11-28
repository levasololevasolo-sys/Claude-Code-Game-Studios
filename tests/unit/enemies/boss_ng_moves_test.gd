## Bosses after full clears (GDD artifacts-and-secrets §3.7, F1-F3, AC 7):
## clear 0 keeps the old attacks only, clears 1/2/3 add 1/2/3 moves from
## boss_ng.json and the bosses use them in a fight, ng 8 gives +30% HP and
## −20% wind-ups, every NG move ends back in idle.
extends GdUnitTestSuite

const G: float = 640.0
const BOSSES: Array[String] = ["kikimora", "likho", "morena"]

static func _tbl(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/%s.json" % name))

func _boss(id: String, clears: int, p_seed: int = 5) -> LairBoss:
	var e := LairBoss.make(id)
	e.beaten_before = 0
	e.clears = clears
	e.stats = (_tbl("bosses")[id] as Dictionary).duplicate(true)
	e.tier = {"kikimora": 1, "likho": 2, "morena": 3}[id]
	e.room_w = 2200.0
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = p_seed
	e.position = Vector2(1300, G - (60.0 if id == "morena" else 0.0))
	e.setup()
	return auto_free(e)

func _fight(e: LairBoss, seconds: float) -> void:
	var hero := Vector2(900, G)
	for i in roundi(seconds / EnemyFixtures.DT):
		hero.x = 700.0 + 500.0 * sin(i * EnemyFixtures.DT * 0.7)
		e.think(EnemyFixtures.DT, hero)

func test_moves_unlock_one_per_clear() -> void:
	var t := _tbl("boss_ng")
	for id in BOSSES:
		for n in 4:
			assert_int(LairBoss.ng_moves_for(t, id, n).size()).is_equal(mini(n, 3))

func test_unknown_boss_uses_kikimora_moves() -> void:
	var t := _tbl("boss_ng")
	assert_int(LairBoss.ng_moves_for(t, "gorynych", 2).size()).is_equal(2)
	assert_str(String(LairBoss.ng_moves_for(t, "gorynych", 1)[0].id)).is_equal("kik_tide")

func test_step_caps_at_30_percent_hp_and_20_percent_windup() -> void:
	var t := _tbl("boss_ng")
	assert_vector(LairBoss.ng_step(t, 3)).is_equal(Vector2(1.0, 1.0))
	var k4 := LairBoss.ng_step(t, 4)
	assert_float(k4.x).is_equal_approx(1.06, 0.0001)
	assert_float(k4.y).is_equal_approx(0.96, 0.0001)
	var k8 := LairBoss.ng_step(t, 8)
	assert_float(k8.x).is_equal_approx(1.30, 0.0001)
	assert_float(k8.y).is_equal_approx(0.80, 0.0001)
	assert_vector(LairBoss.ng_step(t, 20)).is_equal_approx(k8, Vector2(0.0001, 0.0001))

func test_no_clears_no_new_moves_in_the_fight() -> void:
	var ng_ids := []
	for r: Dictionary in _tbl("boss_ng").morena:
		ng_ids.append(String(r.id))
	var e := _boss("morena", 0)
	_fight(e, 90.0)
	for a in e.attack_log:
		assert_bool(a in ng_ids).is_false()

func test_three_clears_every_boss_uses_its_new_moves() -> void:
	var t := _tbl("boss_ng")
	for id in BOSSES:
		var e := _boss(id, 3, 11)
		# Phase 2 so the moves with phase-1 weight 0 can come up too.
		e.phase = 2
		_fight(e, 180.0)
		for r: Dictionary in t[id]:
			assert_bool(String(r.id) in e.attack_log).override_failure_message("%s never used %s: %s" % [id, r.id, e.attack_log]).is_true()

func test_ng_moves_return_to_idle() -> void:
	for id in BOSSES:
		var e := _boss(id, 3, 23)
		e.phase = 2
		var busy := 0.0
		var worst := 0.0
		for i in roundi(120.0 / EnemyFixtures.DT):
			e.think(EnemyFixtures.DT, Vector2(900, G))
			busy = busy + EnemyFixtures.DT if e.st.begins_with("ng_") else 0.0
			worst = maxf(worst, busy)
		assert_float(worst).override_failure_message("%s stuck in an NG state %.1f s" % [id, worst]).is_less(8.0)

func test_eight_clears_raise_hp() -> void:
	var base := _boss("likho", 0).max_hp
	var e := _boss("likho", 8)
	assert_float(e.max_hp).is_equal_approx(base * 1.3, 0.01)
