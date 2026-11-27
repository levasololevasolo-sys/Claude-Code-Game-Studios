## Chunk rooms (GDD room-generation-and-doors §3.3-3.4, §3.10, F4.1-4.3, AC 1-2,
## edge 1, 11) on the swamp library assets/data/chunks_swamp.json.
extends GdUnitTestSuite

const LIB := "res://assets/data/chunks_swamp.json"

func _t() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))

func _lib() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LIB))

func _room(s: int, k: int, tier: int, opts: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var o := opts.duplicate()
	o["lib"] = _lib()
	return RoomGen.generate(rng, k, tier, _t(), true, o)

func _kinds(r: Dictionary) -> Array:
	var out: Array = []
	for c: Dictionary in r.chunks:
		out.append(c.kind)
	return out

func test_library_has_15_to_20_chunks_with_all_roles() -> void:
	var count := {}
	var chunks: Array = _lib().chunks
	for c: Dictionary in chunks:
		count[c.kind] = int(count.get(c.kind, 0)) + 1
	assert_int(chunks.size()).is_between(15, 20)
	assert_int(int(count.get("entry", 0))).is_equal(2)
	assert_int(int(count.get("pass", 0))).is_between(4, 5)
	assert_int(int(count.get("arena", 0))).is_between(5, 6)
	assert_int(int(count.get("shaft", 0))).is_between(3, 4)
	assert_int(int(count.get("exit", 0))).is_equal(2)
	assert_int(int(count.get("secret", 0))).is_between(1, 2)

func test_every_chunk_passes_the_ac1_check() -> void:
	var bad: Array = []
	for c: Dictionary in _lib().chunks:
		var ok := int(c.w) >= 1 and int(c.w) <= 4 and int(c.h) >= 1 and int(c.h) <= 3
		for s: Dictionary in c.sockets:
			var span := int(c.h) if s.side in ["L", "R"] else int(c.w)
			ok = ok and int(s.module) < span and int(s.size) >= 3 and int(s.size) <= 4
		match String(c.kind):
			"arena":
				var per := {}
				for sp: Array in c.S:
					per[int(sp[1])] = int(per.get(int(sp[1]), 0)) + 1
				for n: int in per.values():
					ok = ok and n >= 8
			"exit":
				ok = ok and (c.D as Array).size() == 3 and c.has("W")
			"entry":
				ok = ok and c.has("P") and not c.has("C")
		if not ok:
			bad.append(c.id)
	assert_array(bad).is_empty()

func test_same_seed_same_room() -> void:
	assert_str(str(_room(9, 3, 2))).is_equal(str(_room(9, 3, 2)))

func test_length_arenas_rhythm_shaft_and_no_repeats_over_many_rooms() -> void:
	var t := _t()
	var bad: Array = []
	var fallbacks := 0
	var total := 0
	for s in 60:
		for tier in range(1, 6):
			for k in range(1, 5):
				var r := _room(s, k, tier)
				total += 1
				if r.fallback:
					fallbacks += 1
					continue
				var kinds := _kinds(r)
				var l := RoomGen.budget(k, tier, t)
				var mods := 0
				var ids := {}
				for c: Dictionary in r.chunks:
					mods += int(c.w)
					ids[c.id] = true
				var arenas := kinds.count("arena")
				var adjacent := false
				for i in range(1, kinds.size()):
					adjacent = adjacent or (kinds[i] == "arena" and kinds[i - 1] == "arena")
				if mods < l or mods > l + 1 or arenas != RoomGen.arenas_for(l) or adjacent \
						or (k >= 2 and not "shaft" in kinds) or ids.size() != kinds.size() \
						or kinds[0] != "entry" or kinds[-1] != "exit" or float(r.w) != mods * 640.0:
					bad.append([s, tier, k, kinds])
	assert_array(bad).is_empty()
	# Edge 1 / AC 8.3: the fallback chain is rare (the GDD target is < 1%).
	assert_float(float(fallbacks) / total).is_less(0.01)

func test_neighbours_always_fit_their_sockets() -> void:
	var lib := _lib()
	var by_id := {}
	for c: Dictionary in lib.chunks:
		by_id[c.id] = c
	var ok := true
	for s in 40:
		var r := _room(s, 3, 2)
		for i in range(1, (r.chunks as Array).size()):
			ok = ok and RoomGen.fits(by_id[r.chunks[i - 1].id], by_id[r.chunks[i].id])
	assert_bool(ok).is_true()

func test_budget_matches_the_f41_table() -> void:
	var t := _t()
	assert_int(RoomGen.budget(1, 1, t)).is_equal(3)
	assert_int(RoomGen.budget(2, 1, t)).is_equal(5)
	assert_int(RoomGen.budget(4, 1, t)).is_equal(7)
	assert_int(RoomGen.budget(1, 3, t)).is_equal(5)
	assert_int(RoomGen.budget(4, 5, t)).is_equal(9)
	assert_int(RoomGen.arenas_for(3)).is_equal(1)
	assert_int(RoomGen.arenas_for(6)).is_equal(2)
	assert_int(RoomGen.arenas_for(9)).is_equal(4)

func test_two_packs_are_further_apart_than_pack_gap() -> void:
	var gap := float(_t().pack_gap)
	var ok := true
	for s in 60:
		var packs: Array = _room(s, 4, 3).packs
		var centres: Array = []
		for p: Array in packs:
			var m := 0.0
			for x: float in p:
				m += x
			centres.append(m / p.size())
		centres.sort()
		for i in range(1, centres.size()):
			ok = ok and centres[i] - centres[i - 1] > gap * 0.5
	assert_bool(ok).is_true()

func test_knight_stands_in_an_arena_past_the_safe_zone() -> void:
	var t := _t()
	var safe := float(t.hero_spawn_x) + float(t.aggro_range) + float(t.start_safe_gap)
	for s in 20:
		var r := _room(s, 3, 1, { "knight": true })
		assert_float(float(r.knight_x)).is_greater_equal(safe)
		var inside := false
		for c: Dictionary in r.chunks:
			inside = inside or (c.kind == "arena" and r.knight_x >= c.x and r.knight_x <= c.x + c.w * 640.0)
		assert_bool(inside).is_true()
	assert_float(float(_room(1, 3, 1).knight_x)).is_equal(-1.0)

func test_elites_capped_at_elite_max_and_none_without_permission() -> void:
	var cap := int(_t().elite_max)
	var worst := 0
	var none := 0
	for s in 200:
		worst = maxi(worst, (_room(s, 4, 3, { "elites_ok": true }).elites as Array).size())
		none += (_room(s, 4, 3).elites as Array).size()
	assert_int(worst).is_less_equal(cap)
	assert_int(none).is_equal(0)

func test_forced_secret_puts_a_wall_rich_chest_and_traps_behind_a_b_mark() -> void:
	var found := false
	for s in 80:
		var r := _room(s, 3, 1, { "secret_ok": true, "secret_force": true })
		if r.wall.is_empty():
			continue
		found = true
		var rich: Array = (r.chests as Array).filter(func(c: Dictionary) -> bool: return c.rich)
		assert_int(rich.size()).is_equal(1)
		assert_float(float(rich[0].x)).is_greater(float(r.wall.x))
		assert_bool((r.traps as Array).size() >= 2).is_true()
		break
	assert_bool(found).is_true()

func test_no_wall_without_secret_ok_and_at_most_chest_max_plain_chests() -> void:
	var cap := int(_t().chest_max)
	for s in 60:
		var r := _room(s, 3, 2)
		assert_bool(r.wall.is_empty()).is_true()
		assert_int((r.chests as Array).size()).is_less_equal(cap)
