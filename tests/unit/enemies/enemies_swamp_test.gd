## Топь Кикиморы roster rules (GDD bestiary §3.2, §3.7, §4 B4, B7): Болванчик's
## swing, Шишига's cling / shake-off, Болотница's hummock dive, Водяница's
## song shield and its interrupt, pack composition caps.
extends GdUnitTestSuite

const G: float = 640.0
const DT: float = EnemyFixtures.DT

# ---------------- Болванчик ----------------

func test_balvan_winds_0_7_s_then_swings_then_recovers() -> void:
	var e: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 1, Vector2(1000, G)))
	e.cd = 0.0
	var hero := Vector2(940, G)
	e.think(DT, hero)
	assert_str(e.st).is_equal("wind")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.7, DT + 0.001)
	assert_str(e.st).is_equal("swing")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.25, DT + 0.001)
	assert_str(e.st).is_equal("recover")

func test_balvan_far_hero_walks_slowly_no_wind() -> void:
	var e: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 1, Vector2(1000, G)))
	e.cd = 0.0
	e.think(DT, Vector2(500, G))
	assert_str(e.st).is_equal("walk")
	assert_float(e.vel.x).is_equal(-90.0)

func test_swing_hits_only_in_front_within_reach() -> void:
	var feet := Vector2(1000, G)
	assert_bool(SwampRules.swing_hits(feet, 1, 40.0, 70.0, 72.0, Vector2(1080, G))).is_true()
	assert_bool(SwampRules.swing_hits(feet, 1, 40.0, 70.0, 72.0, Vector2(1120, G))).is_false()
	assert_bool(SwampRules.swing_hits(feet, -1, 40.0, 70.0, 72.0, Vector2(1080, G))).is_false()
	assert_bool(SwampRules.swing_hits(feet, -1, 40.0, 70.0, 72.0, Vector2(920, G))).is_true()

# ---------------- Шишига ----------------

func test_cling_slow_15_percent_each_capped_at_two() -> void:
	assert_float(SwampRules.cling_slow_mult(0, 0.15, 2)).is_equal_approx(1.0, 0.0001)
	assert_float(SwampRules.cling_slow_mult(1, 0.15, 2)).is_equal_approx(0.85, 0.0001)
	assert_float(SwampRules.cling_slow_mult(2, 0.15, 2)).is_equal_approx(0.7, 0.0001)
	assert_float(SwampRules.cling_slow_mult(5, 0.15, 2)).is_equal_approx(0.7, 0.0001)

func test_latch_allowed_only_below_max() -> void:
	assert_bool(SwampRules.can_latch(1, 2)).is_true()
	assert_bool(SwampRules.can_latch(2, 2)).is_false()

func test_dash_roll_pogo_shake_off_jump_does_not() -> void:
	assert_bool(SwampRules.shakes_off(&"dash")).is_true()
	assert_bool(SwampRules.shakes_off(&"roll")).is_true()
	assert_bool(SwampRules.shakes_off(&"pogo")).is_true()
	assert_bool(SwampRules.shakes_off(&"jump")).is_false()

func test_shishiga_latch_counts_and_shake_off_stuns() -> void:
	var e: Shishiga = auto_free(EnemyFixtures.make(Shishiga.new(), EnemyFixtures.shishiga(), 1, Vector2(1000, G)))
	var p: Player = auto_free(Player.new())
	e.latch(p)
	assert_str(e.st).is_equal("cling")
	assert_int(p.cling_n).is_equal(1)
	e.on_hero_acted(&"jump", 1.0)
	assert_str(e.st).is_equal("cling")
	e.on_hero_acted(&"roll", 1.0)
	assert_str(e.st).is_equal("recover")
	assert_float(e.stun).is_equal_approx(0.8, 0.0001)
	assert_int(p.cling_n).is_equal(0)

func test_shishiga_lets_go_after_cling_time() -> void:
	assert_bool(SwampRules.cling_over(2.9, 3.0)).is_false()
	assert_bool(SwampRules.cling_over(3.0, 3.0)).is_true()

func test_shishiga_crouches_0_6_s_before_the_leap() -> void:
	var e: Shishiga = auto_free(EnemyFixtures.make(Shishiga.new(), EnemyFixtures.shishiga(), 1, Vector2(1000, G)))
	e.cd = 0.0
	var hero := Vector2(800, G)
	e.think(DT, hero)
	assert_str(e.st).is_equal("crouch")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.6, DT + 0.001)
	assert_str(e.st).is_equal("leap")
	assert_float(e.vel.x).is_equal(-420.0)

# ---------------- Болотница ----------------

func test_on_hummock_needs_floor_width_and_height() -> void:
	var top := Vector2(1000, 520)
	assert_bool(SwampRules.on_hummock(Vector2(1040, 520), true, top, 120.0)).is_true()
	assert_bool(SwampRules.on_hummock(Vector2(1070, 520), true, top, 120.0)).is_false()
	assert_bool(SwampRules.on_hummock(Vector2(1000, 520), false, top, 120.0)).is_false()
	assert_bool(SwampRules.on_hummock(Vector2(1000, 640), true, top, 120.0)).is_false()

func test_stand_time_resets_when_hero_steps_off() -> void:
	var s := SwampRules.stand_tick(0.3, true, 0.1)
	assert_bool(SwampRules.dive_ready(s, 0.4)).is_true()
	assert_float(SwampRules.stand_tick(0.3, false, 0.1)).is_equal(0.0)

func test_bognitsa_dives_after_stand_and_telegraph() -> void:
	var e: Bognitsa = auto_free(EnemyFixtures.make(Bognitsa.new(), EnemyFixtures.bognitsa(), 1, Vector2(1000, 520)))
	e.st = "hide"
	var hero := Vector2(1000, 520)
	var n := 0
	while e.st == "hide" and n < 100:
		e.think(DT, hero, true)
		n += 1
	assert_float(n * DT).is_equal_approx(0.4, DT + 0.001)
	assert_str(e.st).is_equal("bubble")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.5, DT + 0.001)
	assert_str(e.st).is_equal("dive")
	assert_float(e.position.y).is_equal(Tune.f("ground_y"))

func test_bognitsa_not_standing_stays_a_hummock() -> void:
	var e: Bognitsa = auto_free(EnemyFixtures.make(Bognitsa.new(), EnemyFixtures.bognitsa(), 1, Vector2(1000, 520)))
	e.st = "hide"
	for i in 120:
		e.think(DT, Vector2(700, G), false)
	assert_str(e.st).is_equal("hide")

func test_rise_x_beside_hero_flips_at_the_wall() -> void:
	assert_float(SwampRules.rise_x(500.0, 600.0, 120.0, 30.0, 2000.0)).is_equal(620.0)
	assert_float(SwampRules.rise_x(1950.0, 2000.0, 120.0, 30.0, 2000.0)).is_equal(1830.0)

# ---------------- Водяница ----------------

func test_tina_shield_is_quarter_of_ally_hp() -> void:
	assert_float(SwampRules.tina_amount(34.0, 0.25)).is_equal_approx(8.5, 0.0001)

func test_tina_absorbs_first_then_spills() -> void:
	assert_vector(SwampRules.tina_absorb(8.5, 5.0)).is_equal(Vector2(5.0, 0.0))
	assert_vector(SwampRules.tina_absorb(8.5, 12.0)).is_equal(Vector2(8.5, 3.5))

func test_song_gives_allies_the_shield() -> void:
	var v: Vodyanitsa = auto_free(EnemyFixtures.make(Vodyanitsa.new(), EnemyFixtures.vodyanitsa(), 1, Vector2(1000, G)))
	var a: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 1, Vector2(900, G)))
	v.cd = 0.0
	var hero := Vector2(600, G)
	v.think(DT, hero, [a])
	assert_str(v.st).is_equal("song")
	assert_float(EnemyFixtures.time_in_state_with(v, hero, [a], 2.0)).is_equal_approx(0.8, DT + 0.001)
	assert_float(a.tina).is_equal_approx(a.max_hp * 0.25, 0.0001)
	assert_float(a.tina_t).is_equal(6.0)
	assert_float(v.cd).is_equal(5.0)

func test_hit_breaks_the_song() -> void:
	assert_bool(SwampRules.song_broken(true, true, false)).is_true()
	assert_bool(SwampRules.song_broken(true, false, true)).is_true()
	assert_bool(SwampRules.song_broken(false, true, false)).is_false()
	var v: Vodyanitsa = auto_free(EnemyFixtures.make(Vodyanitsa.new(), EnemyFixtures.vodyanitsa(), 1, Vector2(1000, G)))
	v.st = "song"
	v.t = 0.5
	v.hurt(Hit.make(Hit.Kind.STRIKE, 1.0, 950.0, 0.0))
	assert_str(v.st).is_equal("walk")
	assert_float(v.cd).is_equal(2.0)

func test_shielded_enemy_loses_tina_before_hp() -> void:
	var a: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 1, Vector2(900, G)))
	a.give_tina(6.0, 6.0)
	var hp0 := a.hp
	a.hurt(Hit.make(Hit.Kind.STRIKE, 4.0, 850.0, 0.0))
	assert_float(a.hp).is_equal(hp0)
	assert_float(a.tina).is_less(6.0)

# ---------------- packs (§3.7) ----------------

func _table() -> Dictionary:
	return {
		"balvan": { "pack_role": "fodder" }, "crawler": { "pack_role": "bruiser" },
		"shishiga": { "pack_role": "fodder", "pack_min": 2 }, "thrower": { "pack_role": "ranged" },
		"bloat": { "pack_role": "flyer", "flies": true }, "bognitsa": { "pack_role": "ambusher", "spot": "bog" },
		"vodyanitsa": { "pack_role": "support" },
	}

func _intro() -> Dictionary:
	return { "balvan": 1, "crawler": 1, "shishiga": 1, "thrower": 2, "bloat": 2, "bognitsa": 3, "vodyanitsa": 3 }

func _tune() -> Dictionary:
	return { "pack_kinds_max": [2, 3, 3, 4, 4], "pack_role_max": { "support": 1, "ranged": 2, "bruiser": 2, "flyer": 2, "ambusher": 2 },
		"pack_support_min": 3 }

func test_room_1_packs_only_first_row_kinds() -> void:
	for s in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var kinds := EnemyRoster.pack_kinds_intro(rng, 3, s % 3, 1, 1, _intro(), _table(), _tune())
		assert_int(kinds.size()).is_equal(3)
		for k: String in kinds:
			assert_array(["balvan", "crawler", "shishiga"]).contains([k])

func test_packs_keep_the_caps() -> void:
	for s in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var size := 2 + s % 4
		var kinds := EnemyRoster.pack_kinds_intro(rng, size, s % 2, 3, 1, _intro(), _table(), _tune())
		var distinct := {}
		for k: String in kinds:
			distinct[k] = true
		assert_int(distinct.size()).is_less_equal(2)
		assert_int(kinds.count("vodyanitsa")).is_less_equal(1 if size >= 3 else 0)
		assert_int(kinds.count("bognitsa")).is_equal(0)
		var sh := kinds.count("shishiga")
		assert_bool(sh == 0 or sh >= 2).is_true()

func test_without_bog_spots_bognitsa_may_join_packs() -> void:
	var seen := false
	for s in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		if EnemyRoster.pack_kinds_intro(rng, 3, s % 4, 3, 1, _intro(), _table(), _tune(), false).has("bognitsa"):
			seen = true
	assert_bool(seen).is_true()
