## Кикимора Болотная (GDD enemies-and-elites §3.8-3.9): phase thresholds,
## summon marks, weighted attack choice and its determinism, wind-up floor.
extends GdUnitTestSuite

const G: float = 640.0

## Fixture row: copy of the GDD §3.8-3.9 numbers (bosses.json "kikimora").
static func row() -> Dictionary:
	return { "name": "Кикимора Болотная", "w": 120, "h": 200, "hp": 680, "weight": 6,
		"color": "#3f5a45", "hair": "#1f2e26", "eye": "#c8f07a", "rage_eye": "#ff8a5a", "staff": "#8a6f48",
		"dmg": 18, "rest": 1.0, "contact_mult": 0.8, "lunge_contact_mult": 1.3, "walk_speed": 70, "walk_keep": 260,
		"phase_marks": [0.5], "phase_fast": 1.3, "min_windup": 0.5, "weights": [[38, 34, 28, 0], [32, 30, 22, 16]],
		"throw_wind": 0.6, "throw_n": [3, 5], "throw_gap": 140, "throw_flight": 0.9, "throw_flight_step": 0.05,
		"throw_up": 520, "throw_g": 1300, "throw_r": 16, "throw_dmg_mult": 0.8, "throw_bounces": 1, "throw_bounce_k": 0.45,
		"throw_life": 4.0, "throw_hand_y": 150, "pend_wind": 0.55, "pend_offsets": [[0, -260, 260], [0, -260, 260, -520, 520]],
		"pend_w": 90, "pend_warn": 0.95, "pend_act": 0.5, "pend_dmg_mult": 0.9, "pend_rest_add": 0.6, "pend_top": -260,
		"pend_edge": 40, "lunge_wind": 0.6, "lunge_speed": 720, "lunge_time": 0.7, "lunge_wall": 100, "lunge_shake": 8,
		"wave_wind": 0.7, "wave_speed": 420, "wave_h": 46, "wave_w": 30, "wave_life": 2.4, "wave_dmg_mult": 0.7,
		"summon_marks": [0.65, 0.3], "summons": [["crawler", "bat"], ["crawler", "sentry", "bat"]], "summon_wind": 0.8,
		"summon_dx": 220, "summon_fly_y": 420, "water_h": 80, "water_rise": 2.0, "water_slow": 0.6, "water_dps": 4,
		"water_tick": 1.0, "water_drain": 3.0, "roar_time": 1.2, "phase_hitstop": 0.25, "phase_shake": 14, "phase_flash": 0.45,
		"death_hitstop": 0.3, "death_shake": 18, "line_time": 2.4, "death_linger": 3.5, "hazard_glow_r": 60, "hazard_glow_a": 0.7,
		"lines": { "intro_first": "A", "intro_repeat": "B", "rage": "R", "death_first": "C", "death_repeat": "D" } }

func _boss(p_seed: int = 42) -> LairBoss:
	var e := LairBoss.new()
	e.boss_id = "kikimora"
	e.beaten_before = 0
	e.stats = row()
	e.tier = 1
	e.room_w = 2200.0
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = p_seed
	e.position = Vector2(1300, G)
	e.setup()
	return auto_free(e)

func _hit(e: LairBoss, dmg: float) -> void:
	e.hurt(Hit.make(Hit.Kind.STRIKE, dmg, e.position.x - 10.0, 0.0))

func test_phase_for_thresholds() -> void:
	assert_int(LairBoss.phase_for(1.0, [0.5])).is_equal(1)
	assert_int(LairBoss.phase_for(0.5, [0.5])).is_equal(1)
	assert_int(LairBoss.phase_for(0.4999, [0.5])).is_equal(2)
	assert_int(LairBoss.phase_for(0.1, [0.6, 0.3])).is_equal(3)

func test_summons_crossed_in_order_and_once() -> void:
	assert_array(LairBoss.summons_crossed(0.7, [0.65, 0.3], 0)).is_empty()
	assert_array(LairBoss.summons_crossed(0.6, [0.65, 0.3], 0)).contains_exactly([0])
	assert_array(LairBoss.summons_crossed(0.6, [0.65, 0.3], 1)).is_empty()
	assert_array(LairBoss.summons_crossed(0.2, [0.65, 0.3], 0)).contains_exactly([0, 1])

func test_pick_attack_weight_bands() -> void:
	var wts := [38, 34, 28, 0]
	assert_int(LairBoss.pick_attack(0.0, wts)).is_equal(0)
	assert_int(LairBoss.pick_attack(0.379, wts)).is_equal(0)
	assert_int(LairBoss.pick_attack(0.38, wts)).is_equal(1)
	assert_int(LairBoss.pick_attack(0.719, wts)).is_equal(1)
	assert_int(LairBoss.pick_attack(0.72, wts)).is_equal(2)
	assert_int(LairBoss.pick_attack(0.9999, wts)).is_equal(2)
	assert_int(LairBoss.pick_attack(0.5, [0, 0])).is_equal(0)

func test_phase1_never_picks_wave() -> void:
	for i in 1000:
		assert_int(LairBoss.pick_attack(float(i) / 1000.0, [38, 34, 28, 0])).is_not_equal(3)

func test_windup_never_below_floor() -> void:
	assert_float(LairBoss.windup(0.55, 1.3, 0.5)).is_equal(0.5)
	assert_float(LairBoss.windup(0.7, 1.3, 0.5)).is_equal_approx(0.7 / 1.3, 0.0001)
	assert_float(LairBoss.windup(0.6, 1.0, 0.5)).is_equal(0.6)

func test_same_seed_same_attack_sequence() -> void:
	var a := _boss(7)
	var b := _boss(7)
	for i in 1200:
		a.think(EnemyFixtures.DT, Vector2(1000, G))
		b.think(EnemyFixtures.DT, Vector2(1000, G))
	assert_int(a.attack_log.size()).is_greater(3)
	assert_array(a.attack_log).is_equal(b.attack_log)

func test_every_attack_winds_up_at_least_half_a_second() -> void:
	var e := _boss(3)
	var wind_t := 0.0
	var prev := e.st
	for i in 3000:
		e.think(EnemyFixtures.DT, Vector2(1000, G))
		if e.is_winding():
			wind_t += EnemyFixtures.DT
		elif prev.ends_with("_w"):
			assert_float(wind_t).is_greater_equal(0.5 - EnemyFixtures.DT)
			wind_t = 0.0
		prev = e.st

func test_rage_below_half_hp() -> void:
	var e := _boss()
	_hit(e, e.max_hp * 0.45)
	assert_int(e.phase).is_equal(1)
	assert_array(e.summon_queue).contains_exactly([0])
	_hit(e, e.max_hp * 0.1)
	assert_int(e.phase).is_equal(2)
	assert_str(e.st).is_equal("roar")
	assert_str(e.line).is_equal("R")

func test_water_rises_in_phase2_and_drains_after_summon() -> void:
	var e := _boss()
	_hit(e, e.max_hp * 0.55)
	e.summon_queue.clear()
	for i in 150:
		e.think(EnemyFixtures.DT, Vector2(1000, G))
	assert_float(e.water).is_equal_approx(80.0, 0.01)
	e._summon(0)
	for m in e.minions:
		auto_free(m)
	assert_float(e.water_target()).is_equal(0.0)

func test_lines_by_beaten_count() -> void:
	var l := { "intro_first": "A", "intro_repeat": "B" }
	assert_str(LairBoss.pick_line(l, "intro", 0)).is_equal("A")
	assert_str(LairBoss.pick_line(l, "intro", 2)).is_equal("B")
	assert_str(LairBoss.pick_line(l, "death", 0)).is_equal("")

func test_kill_in_one_blow_summons_nothing() -> void:
	var e := _boss()
	_hit(e, 1.0e6)
	assert_bool(e.dead).is_true()
	assert_array(e.summon_queue).is_empty()
	assert_int(e.phase).is_equal(1)
