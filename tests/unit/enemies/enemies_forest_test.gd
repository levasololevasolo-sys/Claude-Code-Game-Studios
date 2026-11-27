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
	for id: String in ["ringer", "rootling", "suchkovik", "lesavka"]:
		assert_bool(table.has(id)).is_true()
		assert_bool(EnemyRoster.KINDS.has(id)).is_true()
		assert_bool(bool(table[id].flies)).is_false()

# ---------------- Сучковик, Лесавка, packs (GDD bestiary §3.3, §3.7) ----------------

static func suchkovik_row() -> Dictionary:
	return { "w": 34, "h": 78, "hp": 39, "flies": false, "weight": 1.6, "contact": 0, "color": "#3a2e2a", "bark": "#5a4a3a",
		"eye": "#ff8a3d", "spear": "#8a7254", "line": "#c2502a", "fire_range": 900, "range_y": 70, "wind": 0.8,
		"spear_speed": 700, "spear_dmg": 15, "spear_r": 9, "spear_life": 3.0, "muzzle_x": 18, "muzzle_y": 44, "plat_w": 80,
		"plat_time": 4.0, "spear_max": 2, "deflect_stun": 1.0, "recover": 0.6, "cd_min": 1.8, "cd_max": 2.8 }

static func lesavka_row() -> Dictionary:
	return { "w": 30, "h": 40, "hp": 18, "flies": false, "weight": 0.6, "contact": 0, "speed": 150, "keep_dx": 350,
		"whistle": 0.7, "aura_r": 300, "haste_mult": 1.3, "haste_cd_mult": 0.77, "haste_time": 5.0, "whistle_cd": 6.0,
		"corner_px": 40, "bite_range": 120, "bite_wind": 0.5, "bite_time": 0.2, "bite_dmg": 7.2, "bite_hit_x": 40,
		"bite_hit_y": 60, "bite_cd": 1.2 }

func _suchkovik() -> Suchkovik:
	var e: Suchkovik = auto_free(EnemyFixtures.make(Suchkovik.new(), suchkovik_row(), 2, Vector2(1000, G)))
	e.room_w = 2000.0
	return e

func _lesavka() -> Lesavka:
	var e: Lesavka = auto_free(EnemyFixtures.make(Lesavka.new(), lesavka_row(), 2, Vector2(1000, G)))
	e.room_w = 2000.0
	return e

func _free_spears(e: Suchkovik) -> void:
	for s in e.orphan_shots:
		if is_instance_valid(s):
			s.free()

func test_spear_stop_x_without_solids_is_the_room_wall() -> void:
	assert_float(ForestRules.spear_stop_x(Vector2(500, 600), -1, [], 2000.0, 2.0)).is_equal(2.0)
	assert_float(ForestRules.spear_stop_x(Vector2(500, 600), 1, [], 2000.0, 2.0)).is_equal(1998.0)

func test_spear_stop_x_is_the_nearest_solid_at_its_height() -> void:
	var solids := [Rect2(100, 500, 50, 200), Rect2(300, 550, 40, 100), Rect2(200, 100, 40, 100)]
	assert_float(ForestRules.spear_stop_x(Vector2(500, 600), -1, solids, 2000.0, 2.0)).is_equal(340.0)
	# The solid at x 200 is above the line: ignored.
	assert_float(ForestRules.spear_stop_x(Vector2(250, 600), -1, solids, 2000.0, 2.0)).is_equal(150.0)
	assert_float(ForestRules.spear_stop_x(Vector2(0, 600), 1, solids, 2000.0, 2.0)).is_equal(100.0)

func test_step_rect_juts_back_into_the_room() -> void:
	assert_object(ForestRules.step_rect(2.0, -1, 596.0, 80.0)).is_equal(Rect2(2, 596, 80, ForestRules.STEP_THICK))
	assert_object(ForestRules.step_rect(1998.0, 1, 596.0, 80.0)).is_equal(Rect2(1918, 596, 80, ForestRules.STEP_THICK))

func test_can_throw_at_most_two_spears() -> void:
	assert_bool(ForestRules.can_throw(1, 2)).is_true()
	assert_bool(ForestRules.can_throw(2, 2)).is_false()

func test_deflect_stun_only_for_the_thrower() -> void:
	assert_float(ForestRules.deflect_stun(true, 1.0)).is_equal(1.0)
	assert_float(ForestRules.deflect_stun(false, 1.0)).is_equal(0.0)

func test_haste_multipliers_speed_and_cooldowns() -> void:
	assert_float(ForestRules.haste_speed(1.0, 1.3)).is_equal(1.3)
	assert_float(ForestRules.haste_speed(0.0, 1.3)).is_equal(1.0)
	# Cooldowns x0.77: one second of haste takes 1 / 0.77 s off a cooldown.
	assert_float(1.0 + ForestRules.haste_cd_extra(1.0, 0.5, 0.77)).is_equal_approx(1.0 / 0.77, 0.0001)
	assert_float(ForestRules.haste_cd_extra(1.0, 0.0, 0.77)).is_equal(0.0)

func test_flee_vx_keeps_distance_and_stops_when_cornered() -> void:
	assert_float(ForestRules.flee_vx(100.0, 350.0, 150.0, false)).is_equal(-150.0)
	assert_float(ForestRules.flee_vx(-100.0, 350.0, 150.0, false)).is_equal(150.0)
	assert_float(ForestRules.flee_vx(100.0, 350.0, 150.0, true)).is_equal(0.0)
	assert_float(ForestRules.flee_vx(380.0, 350.0, 150.0, false)).is_equal(0.0)
	assert_bool(ForestRules.cornered(40.0, 100.0, 30.0, 2000.0, 8.0, 40.0)).is_true()
	assert_bool(ForestRules.cornered(1000.0, 100.0, 30.0, 2000.0, 8.0, 40.0)).is_false()

func test_suchkovik_winds_then_throws_a_spear_to_the_wall() -> void:
	var e := _suchkovik()
	e.cd = 0.0
	var hero := Vector2(600, G)
	e.think(EnemyFixtures.DT, hero)
	assert_str(e.st).is_equal("wind")
	assert_int(e.face).is_equal(-1)
	assert_float(EnemyFixtures.time_in_state(e, hero, 2.0)).is_equal_approx(0.8, EnemyFixtures.DT + 0.001)
	assert_int(e.orphan_shots.size()).is_equal(1)
	var s := e.orphan_shots[0] as BranchSpear
	assert_float(s.vel.x).is_equal(-700.0)
	assert_float(s.stop_x).is_equal(2.0)
	assert_float(s.position.y).is_equal(G - 44.0)
	_free_spears(e)

func test_suchkovik_never_walks() -> void:
	var e := _suchkovik()
	for i in 200:
		e.think(EnemyFixtures.DT, Vector2(1400, G))
		assert_float(e.vel.x).is_equal(0.0)
	_free_spears(e)

func test_suchkovik_holds_fire_with_two_live_spears() -> void:
	var e := _suchkovik()
	e.face = -1
	e.throw_spear()
	e.throw_spear()
	e.cd = 0.0
	e.think(EnemyFixtures.DT, Vector2(600, G))
	assert_str(e.st).is_equal("stand")
	_free_spears(e)

func test_spear_sticks_as_a_platform_and_breaks_after_plat_time() -> void:
	var e := _suchkovik()
	e.face = -1
	var s := e.throw_spear()
	var n := 0
	while not s.stuck and n < 200:
		s.step(EnemyFixtures.DT)
		n += 1
	assert_bool(s.stuck).is_true()
	assert_float(s.position.x).is_equal(2.0)
	assert_object(s.plat).is_not_null()
	assert_int(s.plat.collision_layer).is_equal(Player.PLATFORM_LAYER)
	assert_object(s.step_rect()).is_equal(Rect2(2, G - 44.0, 80, ForestRules.STEP_THICK))
	var held := 0.0
	while s.life > 0.0 and held < 10.0:
		s.step(EnemyFixtures.DT)
		held += EnemyFixtures.DT
	assert_float(held).is_equal_approx(4.0, EnemyFixtures.DT + 0.001)
	assert_object(s.plat).is_null()
	_free_spears(e)

func test_reflected_spear_stuns_the_suchkovik() -> void:
	var e := _suchkovik()
	e.face = -1
	var s := e.throw_spear()
	s.position = Vector2(e.position.x - e.w / 2.0 - 10.0, e.position.y - 30.0)
	s.reflect(Vector2(400, 0), 5.0, null)
	s.targets = [e]
	s.step(EnemyFixtures.DT)
	assert_float(e.hp).is_less(e.max_hp)
	assert_float(e.stun).is_greater_equal(1.0)
	_free_spears(e)

func test_lesavka_whistle_hastes_allies_in_reach() -> void:
	var e := _lesavka()
	var near: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 2, Vector2(1200, G)))
	var far: Balvan = auto_free(EnemyFixtures.make(Balvan.new(), EnemyFixtures.balvan(), 2, Vector2(1500, G)))
	e.cd = 0.0
	var hero := Vector2(200, G)
	e.think(EnemyFixtures.DT, hero, [near, far])
	assert_str(e.st).is_equal("whistle")
	assert_float(EnemyFixtures.time_in_state_with(e, hero, [near, far], 2.0)).is_equal_approx(0.7, EnemyFixtures.DT + 0.001)
	assert_int(e.last_hasted).is_equal(1)
	assert_float(near.haste_t).is_equal(5.0)
	assert_float(near.haste_mult).is_equal(1.3)
	assert_float(far.haste_t).is_equal(0.0)
	assert_float(e.cd).is_equal(6.0)

func test_lesavka_runs_from_the_hero_and_bites_when_cornered() -> void:
	var e := _lesavka()
	e.cd = 99.0
	e.think(EnemyFixtures.DT, Vector2(1100, G))
	assert_float(e.vel.x).is_equal(-150.0)
	e.position.x = 40.0
	e.think(EnemyFixtures.DT, Vector2(120, G))
	assert_str(e.st).is_equal("bite_wind")
	assert_float(EnemyFixtures.time_in_state(e, Vector2(120, G), 2.0)).is_equal_approx(0.5, EnemyFixtures.DT + 0.001)
	assert_str(e.st).is_equal("bite")

func test_forest_packs_cap_ambushers_per_kind() -> void:
	var table := { "ringer": { "pack_role": "ambusher" }, "rootling": { "pack_role": "ambusher" },
		"sentry": { "pack_role": "bruiser" }, "bat": { "pack_role": "flyer", "flies": true },
		"suchkovik": { "pack_role": "ranged" }, "lesavka": { "pack_role": "support" } }
	var t := { "pack_kinds_max": [2, 3, 3, 4, 4], "pack_role_max": { "support": 1, "ranged": 2, "bruiser": 2, "flyer": 2, "ambusher": 2 },
		"pack_support_min": 3, "pack_role_per_kind": ["ambusher"] }
	var intro := { "ringer": 1, "rootling": 1, "sentry": 2, "bat": 2, "suchkovik": 3, "lesavka": 3 }
	var rng := RandomNumberGenerator.new()
	for s in 40:
		rng.seed = s
		var k1 := EnemyRoster.pack_kinds_intro(rng, 4, s % 3, 1, 2, intro, table, t)
		assert_int(k1.size()).is_equal(4)
		assert_int(k1.count("ringer")).is_equal(2)
		var k3 := EnemyRoster.pack_kinds_intro(rng, 5, s % 4, 3, 2, intro, table, t)
		assert_int(k3.count("ringer")).is_less_equal(2)
		assert_int(k3.count("lesavka")).is_less_equal(1)
		assert_int(k3.count("suchkovik")).is_less_equal(2)

func test_location_2_roster_and_intro_match_the_bestiary() -> void:
	var locs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/locations.json"))
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/enemies.json"))
	var intro: Dictionary = locs["2"].intro
	assert_int(intro.size()).is_equal(6)
	var roles := {}
	for id: String in intro:
		assert_bool(EnemyRoster.KINDS.has(id)).is_true()
		roles[String(table[id].pack_role)] = true
	assert_int(roles.size()).is_greater_equal(5)
	assert_int(int(intro.suchkovik)).is_equal(3)
	assert_int(int(intro.lesavka)).is_equal(3)
