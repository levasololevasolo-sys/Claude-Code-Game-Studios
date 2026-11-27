## Level generator (GDD level-structure §3.2-3.4, F1-F2, F6, edge cases 1-2,
## AC 1-5) on the Swamp library assets/data/room_templates_swamp.json.
extends GdUnitTestSuite

const SEEDS: Array[int] = [7007, 9001, 1234, 42, 555]

func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))

func _t() -> Dictionary:
	return LevelGen.tuning_for(_data())

func _lib() -> Dictionary:
	return LevelGen.prepare(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/room_templates_swamp.json")))

func _build(s: int, opts: Dictionary = {}) -> Dictionary:
	return LevelGen.build(s, 1, _lib(), _t(), opts)

func test_library_has_12_to_20_templates_of_every_kind() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/room_templates_swamp.json"))
	var kinds := {}
	for tp: Dictionary in raw.templates:
		kinds[tp.kind] = true
	assert_int((raw.templates as Array).size()).is_between(12, 20)
	for k in ["entry", "corr", "bridge", "arena", "hall", "shaft", "climb", "nook", "secret", "gauntlet", "fork", "altar", "junction", "lairgate"]:
		assert_bool(kinds.has(k)).override_failure_message("missing kind " + k).is_true()
	assert_bool(raw.has("legend")).is_true()

func test_templates_use_standard_sockets_and_solid_borders() -> void:
	for tp: Dictionary in _lib().templates:
		var g: PackedStringArray = tp.grid
		assert_int(g.size()).is_equal(int(tp.h) * 9)
		for row in g:
			assert_int(row.length()).is_equal(int(tp.w) * 16)
		var w := int(tp.w) * 16
		var h := int(tp.h) * 9
		for y in h:
			for x in w:
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					assert_bool(g[y][x] == "#" or g[y][x] == "D").override_failure_message("%s border %d,%d" % [tp.id, x, y]).is_true()
		for s: String in tp.socks:
			assert_bool((tp.reach as Dictionary).has(s)).is_true()

func test_jump_metrics_cover_the_authoring_limits() -> void:
	# F1, F2: the safe rise / gap the templates are checked with fit the hero's jump.
	var d := _data()
	var cell := float(d.cell)
	var rise := pow(float(d.jump_speed), 2.0) / (2.0 * float(d.gravity)) / cell
	var gap := float(d.run_speed) * 2.0 * float(d.jump_speed) / float(d.gravity) / cell
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/room_templates_swamp.json"))
	assert_float(rise).is_greater(float(raw.jump.rise_cells))
	assert_float(gap).is_greater(float(raw.jump.gap_cells))
	assert_int(int(_t().rise_cells)).is_equal(int(raw.jump.rise_cells))

func test_mirror_swaps_sides_and_reach() -> void:
	var tp: Dictionary = {}
	for x: Dictionary in _lib().templates:
		if x.id == "sw_altar_01":
			tp = x
	var m := LevelGen.mirror(tp)
	assert_array(m.socks).contains_exactly_in_any_order(["R0", "L0", "B0"])
	assert_array(m.reach["R0"]).contains_exactly_in_any_order(["L0", "B0"])
	assert_str(String(m.grid[0])).is_equal(String(tp.grid[0]).reverse())

func test_same_seed_builds_the_same_level() -> void:
	var a := _build(7007, { "knight": true })
	var b := _build(7007, { "knight": true })
	assert_bool(a.grid == b.grid).is_true()
	assert_str(LevelGen.main_signature(a)).is_equal(LevelGen.main_signature(b))
	assert_str(str(a.packs)).is_equal(str(b.packs))
	assert_str(str(a.chests)).is_equal(str(b.chests))
	assert_str(str(a.knight)).is_equal(str(b.knight))

func test_different_seeds_build_different_main_paths() -> void:
	var sigs := {}
	for s in SEEDS:
		sigs[LevelGen.main_signature(_build(s))] = true
	assert_int(sigs.size()).is_equal(SEEDS.size())

func test_levels_have_three_forks_with_two_or_three_trails() -> void:
	for s in SEEDS:
		var l := _build(s)
		assert_bool(bool(l.ok)).is_true()
		assert_bool(bool(l.fallback)).is_false()
		assert_int((l.forks as Array).size()).is_equal(3)
		for f: Dictionary in l.forks:
			assert_int((f.trails as Array).size()).is_between(2, 3)
			for tr: Dictionary in f.trails:
				assert_str(String(l.rooms[int(tr.shrine)].kind)).is_equal("altar")
		# Shrine 1 + one per trail.
		var n := 1
		for f: Dictionary in l.forks:
			n += (f.trails as Array).size()
		assert_int((l.shrines as Array).size()).is_equal(n)

func test_rooms_never_overlap_and_lie_inside_the_border() -> void:
	for s in SEEDS:
		var l := _build(s)
		var occ := {}
		for r: Dictionary in l.rooms:
			for a in int(r.w):
				for b in int(r.h):
					var c := Vector2i(int(r.x) + a, int(r.y) + b)
					assert_bool(occ.has(c)).override_failure_message("overlap at %s seed %d" % [c, s]).is_false()
					occ[c] = true
					assert_bool(c.x >= 1 and c.y >= 1 and c.x < int(l.mcols) - 1 and c.y < int(l.mrows) - 1).is_true()

func test_unused_sockets_are_sealed_and_used_ones_open() -> void:
	var l := _build(9001)
	var g: PackedStringArray = l.grid
	for row in g:
		assert_bool(row.contains("D")).is_false()
	# Every edge joins two used sockets.
	for e: Array in l.edges:
		assert_bool(String(e[3]) in (l.rooms[int(e[0])].used as Array)).is_true()
		assert_bool(String(e[4]) in (l.rooms[int(e[1])].used as Array)).is_true()

func test_lair_is_deep_and_reachable_from_the_entry() -> void:
	for s in SEEDS:
		var l := _build(s)
		var lg: Dictionary = l.rooms[int(l.lairgate)]
		var en: Dictionary = l.rooms[int(l.entry)]
		assert_str(String(lg.kind)).is_equal("lairgate")
		assert_int(int(lg.y) + int(lg.h) - int(en.y)).is_greater_equal(int(_t().depth_min))
		# Critical path: edges from the entry reach the lair gate.
		var nb := {}
		for e: Array in l.edges:
			if not nb.has(int(e[0])):
				nb[int(e[0])] = []
			(nb[int(e[0])] as Array).append(int(e[1]))
		var seen := { int(l.entry): true }
		var q: Array = [int(l.entry)]
		while not q.is_empty():
			var c: int = q.pop_front()
			for n: int in nb.get(c, []):
				if not seen.has(n):
					seen[n] = true
					q.append(n)
		assert_bool(seen.has(int(l.lairgate))).is_true()
		for sh: int in l.shrines:
			assert_bool(seen.has(sh)).is_true()

func test_depth_bands_grow_downwards() -> void:
	var l := _build(7007)
	assert_int(int(l.rooms[int(l.entry)].band)).is_equal(0)
	assert_int(int(l.rooms[int(l.lairgate)].band)).is_equal(2)

func test_impossible_depth_uses_the_fallback_level() -> void:
	# Edge case 1: every attempt fails -> the location's fallback (a known seed).
	var t := _t()
	t["gen_attempts"] = 2
	t["depth_min"] = 999
	var l := LevelGen.build(1234, 1, _lib(), t)
	assert_bool(bool(l.fallback)).is_true()

func test_level_seed_depends_on_run_and_tier() -> void:
	assert_int(LevelGen.level_seed(5, 1)).is_equal(LevelGen.level_seed(5, 1))
	assert_int(LevelGen.level_seed(5, 1)).is_not_equal(LevelGen.level_seed(5, 2))
	assert_int(LevelGen.level_seed(5, 1)).is_not_equal(LevelGen.level_seed(6, 1))

func test_trail_packs_respect_the_budget() -> void:
	# F5: trail budget 6 + 2·(tier − 1), the last pack not below 2.
	var l := _build(7007)
	var sums := {}
	for p: Dictionary in l.packs:
		if not (p.trail as Array).is_empty():
			sums[str(p.trail)] = int(sums.get(str(p.trail), 0)) + int(p.size)
		assert_int(int(p.size)).is_greater_equal(2)
	for k: String in sums:
		assert_int(int(sums[k])).is_less_equal(int(_t().trail_budget_base))
