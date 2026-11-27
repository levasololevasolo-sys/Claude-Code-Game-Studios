## Царство Морены roster rules (GDD bestiary §3.4, §3.7, §4 B5, §5 edge cases
## 1, 7, 16): Карачун's floor wave, Снежница's frost marks and the freeze,
## Сосульник's drop lane, Мара's ice copies, pack rules (wolves in pairs,
## Сосульник only on ceiling spots).
extends GdUnitTestSuite

const G: float = 640.0
const DT: float = EnemyFixtures.DT

static func karachun_row() -> Dictionary:
	return { "w": 72, "h": 98, "hp": 60, "flies": false, "weight": 2.2, "contact": 0, "speed": 60, "slam_range": 560,
		"range_y": 140, "slam_wind": 0.9, "slam_time": 0.15, "slam_recover": 0.8, "slam_cd": 3.2, "wave_speed": 420,
		"wave_h": 40, "wave_dist": 600, "wave_half": 16, "wave_dmg": 14.4, "wave_dirs": 2, "wave_linger": 0.35,
		"poke_range": 110, "poke_wind": 0.5, "poke_time": 0.2, "poke_reach": 95, "poke_dmg": 12, "poke_recover": 0.5,
		"cd_min": 1.2, "cd_max": 2.2 }

static func snezhnitsa_row() -> Dictionary:
	return { "w": 34, "h": 90, "hp": 27, "flies": false, "weight": 0.8, "contact": 0, "eye": "#a3206f", "needle": "#8fd3f5",
		"speed": 80, "back_speed": 120, "keep_min": 350, "keep_max": 550, "fire_range": 720, "range_y": 170, "cast": 0.6,
		"needles": 3, "needle_gap": 0.15, "needle_speed": 420, "needle_dmg": 4.8, "needle_r": 7, "needle_life": 2.4,
		"needle_stop": 0.4, "muzzle_y": 60, "cast_cd_min": 2.2, "cast_cd_max": 3.2 }

static func sosulnik_row() -> Dictionary:
	return { "w": 34, "h": 72, "hp": 24, "flies": false, "weight": 0.8, "contact": 0, "lane": 40, "shake": 0.5,
		"fall_speed": 1200, "fall_dmg": 18, "fall_hit_x": 46, "land": 0.5, "speed": 70, "poke_range": 80, "range_y": 90,
		"poke_wind": 0.6, "poke_time": 0.2, "reach": 70, "poke_dmg": 9.6, "recover": 0.6, "cd_min": 1.0, "cd_max": 1.8,
		"shadow_r0": 8, "shadow_r1": 44, "shatter_time": 0.6 }

static func mara_row() -> Dictionary:
	return { "w": 34, "h": 102, "hp": 30, "flies": false, "weight": 0.9, "contact": 0, "speed": 90, "keep_dx": 400,
		"raise_r": 400, "raise": 0.8, "raise_frac": 0.4, "raise_dmg": 0.8, "raise_max": 2, "raise_cd": 1.0,
		"scratch_range": 120, "scratch_wind": 0.5, "scratch_time": 0.2, "scratch_hit_x": 90, "scratch_hit_y": 90,
		"scratch_dmg": 7.2, "scratch_cd": 1.4 }

# ---------------- FrostRules: Карачун ----------------

func test_wave_runs_both_ways_with_arm_forward_only_without() -> void:
	assert_array(FrostRules.wave_dirs(1, 2)).contains_exactly([-1, 1])
	assert_array(FrostRules.wave_dirs(-1, 1)).contains_exactly([-1])
	assert_array(FrostRules.wave_dirs(1, 1)).contains_exactly([1])

func test_wave_end_stops_at_dist_room_edge_and_wall() -> void:
	assert_float(FrostRules.wave_end(1000, 1, 600, 0, 5000, [])).is_equal(1600.0)
	assert_float(FrostRules.wave_end(1000, -1, 600, 0, 5000, [])).is_equal(400.0)
	assert_float(FrostRules.wave_end(300, -1, 600, 0, 5000, [])).is_equal(0.0)
	assert_float(FrostRules.wave_end(1000, 1, 600, 0, 5000, [Vector2(1200, 1240)])).is_equal(1200.0)
	assert_float(FrostRules.wave_end(1000, -1, 600, 0, 5000, [Vector2(700, 760)])).is_equal(760.0)
	# A wall behind the wave does not stop it.
	assert_float(FrostRules.wave_end(1000, 1, 600, 0, 5000, [Vector2(700, 760)])).is_equal(1600.0)

func test_wave_front_moves_at_speed_and_stops_at_end() -> void:
	assert_float(FrostRules.wave_front(1000, 1, 420, 0.5, 1600)).is_equal(1210.0)
	assert_float(FrostRules.wave_front(1000, 1, 420, 5.0, 1600)).is_equal(1600.0)
	assert_float(FrostRules.wave_front(1000, -1, 420, 0.5, 400)).is_equal(790.0)

func test_wave_hits_standing_hero_but_jump_clears_it() -> void:
	assert_bool(FrostRules.wave_hits(1000, Vector2(1010, G), G, 40, 16, 32)).is_true()
	assert_bool(FrostRules.wave_hits(1000, Vector2(1010, G - 60), G, 40, 16, 32)).is_false()
	assert_bool(FrostRules.wave_hits(1000, Vector2(1100, G), G, 40, 16, 32)).is_false()

# ---------------- FrostRules: Снежница (B5) ----------------

func test_marks_stack_to_three_and_freeze() -> void:
	var m := 0
	for i in 3:
		m = FrostRules.add_mark(m, 3, 0.0, 0.0)
	assert_int(m).is_equal(3)
	assert_bool(FrostRules.freezes(m, 3)).is_true()
	assert_bool(FrostRules.freezes(2, 3)).is_false()
	assert_int(FrostRules.add_mark(3, 3, 0.0, 0.0)).is_equal(3)

func test_no_marks_during_guard_or_freeze() -> void:
	assert_int(FrostRules.add_mark(0, 3, 2.0, 0.0)).is_equal(0)
	assert_int(FrostRules.add_mark(1, 3, 0.0, 0.3)).is_equal(1)

func test_mark_falls_off_every_1_5_s() -> void:
	var v := FrostRules.decay_tick(2, 1.4, 1.5, 0.05)
	assert_int(int(v.x)).is_equal(2)
	v = FrostRules.decay_tick(int(v.x), v.y, 1.5, 0.1)
	assert_int(int(v.x)).is_equal(1)
	assert_int(int(FrostRules.decay_tick(0, 3.0, 1.5, 0.1).x)).is_equal(0)

func test_keep_band_350_550() -> void:
	assert_int(FrostRules.keep_dir(200, 350, 550)).is_equal(-1)
	assert_int(FrostRules.keep_dir(450, 350, 550)).is_equal(0)
	assert_int(FrostRules.keep_dir(700, 350, 550)).is_equal(1)

# ---------------- FrostRules: Сосульник, Мара ----------------

func test_drop_lane_is_40_px_and_below() -> void:
	var ic := Vector2(1000, 400)
	assert_bool(FrostRules.under_lane(ic, Vector2(1030, G), 40)).is_true()
	assert_bool(FrostRules.under_lane(ic, Vector2(1050, G), 40)).is_false()
	assert_bool(FrostRules.under_lane(ic, Vector2(1000, 300), 40)).is_false()

func test_shadow_grows_during_shake() -> void:
	assert_float(FrostRules.shadow_r(0.5, 0.5, 8, 44)).is_equal(8.0)
	assert_float(FrostRules.shadow_r(0.0, 0.5, 8, 44)).is_equal(44.0)

func test_can_raise_rules() -> void:
	assert_bool(FrostRules.can_raise(300, 400, false, false, "wolf", 0, 2)).is_true()
	assert_bool(FrostRules.can_raise(450, 400, false, false, "wolf", 0, 2)).is_false()
	assert_bool(FrostRules.can_raise(100, 400, true, false, "wolf", 0, 2)).is_false()
	assert_bool(FrostRules.can_raise(100, 400, false, true, "wolf", 0, 2)).is_false()
	assert_bool(FrostRules.can_raise(100, 400, false, false, "mara", 0, 2)).is_false()
	assert_bool(FrostRules.can_raise(100, 400, false, false, "wolf", 2, 2)).is_false()
	assert_bool(FrostRules.can_raise(100, 400, false, false, "bonner", 0, 2, true)).is_false()

func test_copy_hp_and_breaking_hits() -> void:
	assert_float(FrostRules.copy_hp(60, 0.4)).is_equal_approx(24.0, 0.001)
	assert_bool(FrostRules.copy_breaks(Hit.Kind.FLARE, false)).is_true()
	assert_bool(FrostRules.copy_breaks(Hit.Kind.SLAM, false)).is_true()
	assert_bool(FrostRules.copy_breaks(Hit.Kind.WALL, false)).is_true()
	assert_bool(FrostRules.copy_breaks(Hit.Kind.STRIKE, true)).is_true()
	assert_bool(FrostRules.copy_breaks(Hit.Kind.STRIKE, false)).is_false()

# ---------------- states ----------------

func test_karachun_slam_winds_0_9_s_and_sends_two_waves() -> void:
	var e: Karachun = auto_free(EnemyFixtures.make(Karachun.new(), karachun_row(), 1, Vector2(1000, G)))
	e.cd = 0.0
	var hero := Vector2(1300, G)
	e.think(DT, hero)
	assert_str(e.st).is_equal("slam_wind")
	assert_float(EnemyFixtures.time_in_state(e, hero, 3.0)).is_equal_approx(0.9, DT + 0.001)
	assert_str(e.st).is_equal("slam")
	assert_int(e.last_waves.size()).is_equal(2)
	for wv in e.last_waves:
		wv.free()

func test_karachun_close_hero_gets_the_poke() -> void:
	var e: Karachun = auto_free(EnemyFixtures.make(Karachun.new(), karachun_row(), 1, Vector2(1000, G)))
	e.cd = 0.0
	var hero := Vector2(1080, G)
	e.think(DT, hero)
	assert_str(e.st).is_equal("poke_wind")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.5, DT + 0.001)
	assert_str(e.st).is_equal("poke")

func test_karachun_without_arm_waves_forward_only_slower() -> void:
	var e: Karachun = auto_free(EnemyFixtures.make(Karachun.new(), karachun_row(), 1, Vector2(1000, G)))
	e.stats = LimbRules.one_arm_stats(e.stats, { "wave_dirs": 0.5, "slam_wind": 1.3 })
	e.arm_off = true
	e.cd = 0.0
	var hero := Vector2(1300, G)
	e.think(DT, hero)
	assert_float(EnemyFixtures.time_in_state(e, hero, 3.0)).is_equal_approx(1.17, DT + 0.001)
	assert_int(e.last_waves.size()).is_equal(1)
	assert_int(e.last_waves[0].dir).is_equal(1)
	e.last_waves[0].free()

func test_snezhnitsa_casts_0_6_s_then_fires_three_needles() -> void:
	var e: Snezhnitsa = auto_free(EnemyFixtures.make(Snezhnitsa.new(), snezhnitsa_row(), 1, Vector2(1000, G)))
	e.cd = 0.0
	var hero := Vector2(1450, G)
	e.think(DT, hero)
	assert_str(e.st).is_equal("cast")
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.6, DT + 0.001)
	EnemyFixtures.run(e, 0.5, hero)
	assert_int(e.orphan_shots.size()).is_equal(3)
	assert_float(e.orphan_shots[0].vel.length()).is_equal_approx(420.0, 0.5)
	for s in e.orphan_shots:
		s.free()

func test_snezhnitsa_steps_back_when_hero_is_close() -> void:
	var e: Snezhnitsa = auto_free(EnemyFixtures.make(Snezhnitsa.new(), snezhnitsa_row(), 1, Vector2(1000, G)))
	e.cd = 99.0
	e.think(DT, Vector2(1200, G))
	assert_float(e.vel.x).is_equal(-120.0)

func test_sosulnik_shakes_only_when_hero_is_under_it() -> void:
	var e: Sosulnik = auto_free(EnemyFixtures.make(Sosulnik.new(), sosulnik_row(), 1, Vector2(1000, 300)))
	e.think(DT, Vector2(1200, G))
	assert_str(e.st).is_equal("hang")
	assert_float(e.position.y).is_equal(372.0)
	e.think(DT, Vector2(1020, G))
	assert_str(e.st).is_equal("shake")
	assert_float(EnemyFixtures.time_in_state(e, Vector2(1020, G), 2.0)).is_equal_approx(0.5, DT + 0.001)
	assert_str(e.st).is_equal("fall")
	assert_bool(e.hanging).is_false()

func test_mara_raises_a_fallen_ally_as_a_weak_ice_copy() -> void:
	var m: Mara = auto_free(EnemyFixtures.make(Mara.new(), mara_row(), 1, Vector2(1000, G)))
	var ally: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 1, Vector2(1200, G)))
	m.watch([ally])
	ally.hurt(Hit.make(Hit.Kind.STRIKE, 999.0, 1300.0, 0.0))
	assert_int(m.corpses.size()).is_equal(1)
	m.cd = 0.0
	var hero := Vector2(1500, G)
	m.think(DT, hero)
	assert_str(m.st).is_equal("raise_w")
	assert_float(EnemyFixtures.time_in_state(m, hero, 2.0)).is_equal_approx(0.8, DT + 0.001)
	assert_int(m.copies.size()).is_equal(1)
	var cp: Enemy = m.copies[0]
	assert_bool(cp.ice_copy).is_true()
	assert_float(cp.max_hp).is_equal_approx(ally.max_hp * 0.4, 0.01)
	assert_int(int(cp.stats.embers)).is_equal(0)
	# Мара dies: the copy cracks.
	assert_int(m.shatter_copies()).is_equal(1)
	assert_bool(cp.dead).is_true()
	cp.free()
	for lp in ally.orphan_parts:
		lp.free()

func test_mara_raise_is_stopped_by_a_hit() -> void:
	var m: Mara = auto_free(EnemyFixtures.make(Mara.new(), mara_row(), 1, Vector2(1000, G)))
	m.corpses.append({ "kind": "balvan", "pos": Vector2(1100, G), "max_hp": 24.0 })
	m.cd = 0.0
	m.think(DT, Vector2(1500, G))
	assert_str(m.st).is_equal("raise_w")
	m.hurt(Hit.make(Hit.Kind.STRIKE, 1.0, 900.0, 0.0))
	assert_str(m.st).is_equal("walk")
	assert_int(m.copies.size()).is_equal(0)

func test_ice_copy_breaks_from_a_flare_hit() -> void:
	var e: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 1, Vector2(1000, G)))
	e.ice_copy = true
	e.hurt(Hit.make(Hit.Kind.FLARE, 1.0, 900.0, 0.0))
	assert_bool(e.dead).is_true()

# ---------------- packs (§3.7) ----------------

func _table() -> Dictionary:
	return { "wolf": { "pack_role": "fodder", "pack_min": 2, "pack_pairs": true }, "karachun": { "pack_role": "bruiser" },
		"jelly": { "pack_role": "flyer", "flies": true }, "snezhnitsa": { "pack_role": "ranged" },
		"sosulnik": { "pack_role": "ambusher", "spot": "ceiling", "spot_only": true }, "mara": { "pack_role": "support" } }

func _tune() -> Dictionary:
	return { "pack_kinds_max": [2, 3, 3, 4, 4], "pack_support_min": 3,
		"pack_role_max": { "support": 1, "ranged": 2, "bruiser": 2, "flyer": 2, "ambusher": 2 } }

func _intro() -> Dictionary:
	return { "wolf": 1, "karachun": 1, "jelly": 2, "snezhnitsa": 2, "sosulnik": 3, "mara": 3 }

func test_frost_packs_wolves_in_pairs_no_sosulnik_support_caps() -> void:
	var rng := RandomNumberGenerator.new()
	for s in 40:
		rng.seed = 100 + s
		var size := 2 + s % 6
		var out := EnemyRoster.pack_kinds_intro(rng, size, s, 3, 3, _intro(), _table(), _tune(), false)
		assert_int(out.count("wolf") % 2).is_equal(0)
		assert_int(out.count("sosulnik")).is_equal(0)
		assert_int(out.count("mara")).is_less_equal(1)
		if size < 3:
			assert_int(out.count("mara")).is_equal(0)

func test_frost_room_1_only_wolves_and_karachun() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out := EnemyRoster.pack_kinds_intro(rng, 4, 0, 1, 3, _intro(), _table(), _tune(), false)
	for k in out:
		assert_array(["wolf", "karachun"]).contains([k])

func test_frost_location_roster_and_intro_data() -> void:
	var locs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/locations.json"))
	var ros := EnemyRoster.for_tier(3, locs, {})
	assert_array(ros.roster).contains_exactly_in_any_order(["wolf", "karachun", "jelly", "snezhnitsa", "sosulnik", "mara"])
	var want := _intro()
	assert_int(ros.intro.size()).is_equal(want.size())
	for k: String in want:
		assert_int(int(ros.intro[k])).is_equal(int(want[k]))
