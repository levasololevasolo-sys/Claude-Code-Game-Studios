## VfxRules (material lookup, burst counts, heavy hits) and VfxPool (caps,
## floor splats, ageing). Fixture data inline as factory functions; no files.
extends GdUnitTestSuite

const DT: float = 1.0 / 60.0

static func _vfx() -> Dictionary:
	return {
		"default_material": "flesh",
		"kind_material": { "dummy": "wood", "boss": "undead" },
		"levels": { "2": 1.0, "1": 0.4, "0": 0.0 },
		"heavy_mult": 2.0,
		"heavy_frac": 0.5,
		"materials": { "flesh": {}, "wood": {}, "undead": {}, "metal": {}, "ice": {} },
	}

static func _enemies() -> Dictionary:
	return { "knight": { "material": "metal" }, "odd": { "material": "glass" }, "plain": {} }

func test_material_from_enemy_row() -> void:
	assert_str(VfxRules.material_of("knight", _enemies(), _vfx())).is_equal("metal")

func test_unknown_row_material_falls_back_to_default() -> void:
	assert_str(VfxRules.material_of("odd", _enemies(), _vfx())).is_equal("flesh")

func test_row_without_material_uses_default() -> void:
	assert_str(VfxRules.material_of("plain", _enemies(), _vfx())).is_equal("flesh")

func test_kind_material_map_for_kinds_outside_the_table() -> void:
	assert_str(VfxRules.material_of("dummy", _enemies(), _vfx())).is_equal("wood")
	assert_str(VfxRules.material_of("boss", _enemies(), _vfx())).is_equal("undead")

func test_missing_kind_gets_default() -> void:
	assert_str(VfxRules.material_of("nobody", {}, _vfx())).is_equal("flesh")

func test_every_real_enemy_kind_has_a_known_material() -> void:
	var vfx := Tune.table("vfx")
	var mats: Dictionary = vfx.materials
	for id: String in Tune.table("enemies"):
		if id.begins_with("_"):
			continue
		assert_bool(mats.has(VfxRules.material_of(id, Tune.table("enemies"), vfx))).override_failure_message("kind " + id).is_true()

func test_shield_block_rings_as_metal() -> void:
	assert_str(VfxRules.hit_material("undead", true)).is_equal("metal")
	assert_str(VfxRules.hit_material("undead", false)).is_equal("undead")

func test_count_scales_by_level_and_heavy() -> void:
	var spec := { "n": 10 }
	assert_int(VfxRules.count(spec, VfxRules.LEVEL_HIGH, false, _vfx())).is_equal(10)
	assert_int(VfxRules.count(spec, VfxRules.LEVEL_LOW, false, _vfx())).is_equal(4)
	assert_int(VfxRules.count(spec, VfxRules.LEVEL_OFF, false, _vfx())).is_equal(0)
	assert_int(VfxRules.count(spec, VfxRules.LEVEL_HIGH, true, _vfx())).is_equal(20)

func test_always_specs_survive_particles_off() -> void:
	assert_int(VfxRules.count({ "n": 1, "always": true }, VfxRules.LEVEL_OFF, false, _vfx())).is_equal(1)
	assert_int(VfxRules.count({ "n": 30, "always_n": 8 }, VfxRules.LEVEL_LOW, false, _vfx())).is_equal(12)
	assert_int(VfxRules.count({ "n": 30, "always_n": 8 }, VfxRules.LEVEL_OFF, false, _vfx())).is_equal(0)

func test_heavy_hits() -> void:
	assert_bool(VfxRules.is_heavy(Hit.Kind.STRIKE, true, "", 1.0, 100.0, _vfx())).is_true()
	assert_bool(VfxRules.is_heavy(Hit.Kind.SLAM, false, "", 1.0, 100.0, _vfx())).is_true()
	assert_bool(VfxRules.is_heavy(Hit.Kind.STRIKE, false, "head", 1.0, 100.0, _vfx())).is_true()
	assert_bool(VfxRules.is_heavy(Hit.Kind.STRIKE, false, "", 50.0, 100.0, _vfx())).is_true()
	assert_bool(VfxRules.is_heavy(Hit.Kind.STRIKE, false, "", 49.0, 100.0, _vfx())).is_false()

func test_status_ticks_are_silent() -> void:
	assert_bool(VfxRules.silent(Hit.Kind.TICK)).is_true()
	assert_bool(VfxRules.silent(Hit.Kind.STRIKE)).is_false()

func test_hit_dir_flies_away_from_attacker() -> void:
	assert_float(VfxRules.hit_dir(100.0, 40.0).x).is_equal(1.0)
	assert_float(VfxRules.hit_dir(100.0, 160.0).x).is_equal(-1.0)
	assert_float(VfxRules.hit_dir(100.0, 100.0, 0.0, -1).x).is_equal(-1.0)
	assert_float(VfxRules.hit_dir(100.0, 40.0, 30.0).y).is_less(0.0)

func test_clamp_level() -> void:
	assert_int(VfxRules.clamp_level(7)).is_equal(2)
	assert_int(VfxRules.clamp_level(-3)).is_equal(0)

# ---------------- pool ----------------

func test_pool_never_exceeds_cap() -> void:
	var p := VfxPool.new(16)
	for i in 40:
		p.add(VfxPool.Shape.MIST, Vector2(i, 0), Vector2.ZERO, 5.0, 4.0, Color.WHITE)
	assert_int(p.alive()).is_equal(16)

func test_pool_frees_dead_particles() -> void:
	var p := VfxPool.new(8)
	p.add(VfxPool.Shape.FLASH, Vector2.ZERO, Vector2.ZERO, 0.05, 4.0, Color.WHITE)
	p.add(VfxPool.Shape.FLASH, Vector2.ZERO, Vector2.ZERO, 1.0, 4.0, Color.WHITE)
	for i in 6:
		p.step(DT)
	assert_int(p.alive()).is_equal(1)

func test_drop_lands_as_splat() -> void:
	var p := VfxPool.new(8, 4)
	p.add(VfxPool.Shape.DROP, Vector2(0, 90), Vector2(0, 100), 2.0, 3.0, Color.RED, { "grav": 900.0, "floor_y": 100.0, "splat": true })
	for i in 30:
		p.step(DT)
	assert_int(p.splats()).is_equal(1)
	assert_int(p.shape[0]).is_equal(VfxPool.Shape.SPLAT)
	assert_float(p.pos[0].y).is_equal(100.0)

func test_splat_cap_drops_oldest() -> void:
	var p := VfxPool.new(32, 3)
	for i in 5:
		p.add(VfxPool.Shape.DROP, Vector2(i * 10, 99), Vector2(0, 200), 2.0, 3.0, Color.RED, { "floor_y": 100.0, "splat": true })
	p.step(DT)
	assert_int(p.splats()).is_equal(3)
	assert_int(p.alive()).is_equal(3)

func test_shard_without_bounce_lies_on_floor() -> void:
	var p := VfxPool.new(4)
	p.add(VfxPool.Shape.SHARD, Vector2(0, 95), Vector2(50, 200), 3.0, 3.0, Color.WHITE, { "floor_y": 100.0, "spin": 5.0 })
	for i in 10:
		p.step(DT)
	var x := p.pos[0].x
	p.step(DT)
	assert_float(p.pos[0].x).is_equal(x)
	assert_float(p.pos[0].y).is_equal(100.0)

func test_clear_empties_pool() -> void:
	var p := VfxPool.new(4)
	p.add(VfxPool.Shape.MIST, Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, Color.WHITE)
	p.clear()
	assert_int(p.alive()).is_equal(0)

func test_settings_particles_round_trip() -> void:
	var s: GameSettings = auto_free(GameSettings.new())
	s.particles = 1
	var t: GameSettings = auto_free(GameSettings.new())
	t.from_config(s.to_config())
	assert_int(t.particles).is_equal(1)
