## Door forks (GDD room-generation-and-doors §3.8, §3.9, §3.14, §3.16, F4.6,
## edge cases 2, 3; AC 9, 10, 14). Reads the shipped tuning for the weights.
extends GdUnitTestSuite

const GODS: Array[String] = ["svarog", "perun", "stribog", "veles", "zhiva"]
const ALL_TYPES: Array[String] = ["god", "loot", "heal", "rod", "arms", "surica"]

func _t() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _ctx(god_time: bool, can_surica: bool = true) -> Dictionary:
	return { "god_time": god_time, "gods": GODS, "types": ALL_TYPES, "can_surica": can_surica }

func test_fork_has_two_or_three_doors_three_near_fork_three() -> void:
	var t := _t()
	var r := _rng(11)
	var threes := 0
	for i in 1000:
		var f := DoorRules.make_fork(r, _ctx(i % 2 == 0), t)
		assert_int(f.size()).is_between(2, 3)
		if f.size() == 3:
			threes += 1
	assert_int(threes).is_between(380, 520)

func test_god_time_first_door_is_god_and_gods_never_repeat() -> void:
	var t := _t()
	var r := _rng(5)
	for i in 500:
		var f := DoorRules.make_fork(r, _ctx(true), t)
		assert_str(String(f[0].type)).is_equal("god")
		var seen := {}
		for d in f:
			if d.type == "god":
				assert_bool(seen.has(d.god)).is_false()
				seen[d.god] = true

func test_not_god_time_only_ordinary_doors_without_repeats() -> void:
	var t := _t()
	var r := _rng(9)
	for i in 500:
		var f := DoorRules.make_fork(r, _ctx(false), t)
		var seen := {}
		for d in f:
			assert_bool(String(d.type) in DoorRules.ORDINARY).is_true()
			assert_bool(seen.has(d.type)).is_false()
			seen[d.type] = true

func test_at_most_one_surica_and_one_rod_per_fork() -> void:
	var t := _t()
	var r := _rng(13)
	var surica_seen := 0
	for i in 1000:
		var f := DoorRules.make_fork(r, _ctx(true), t)
		var s := f.filter(func(d: Dictionary) -> bool: return d.type == "surica").size()
		assert_int(s).is_less_equal(1)
		assert_int(f.filter(func(d: Dictionary) -> bool: return d.type == "rod").size()).is_less_equal(1)
		surica_seen += s
	assert_int(surica_seen).is_greater(0)

func test_no_surica_without_a_rune_to_raise() -> void:
	var t := _t()
	var r := _rng(17)
	for i in 1000:
		for d in DoorRules.make_fork(r, _ctx(true, false), t):
			assert_str(String(d.type)).is_not_equal("surica")

func test_empty_ordinary_pool_gives_loot() -> void:
	var t := _t()
	var doors: Array[Dictionary] = [{ "type": "loot", "god": "" }]
	var d := DoorRules.ordinary(_rng(1), doors, ["god"], t)
	assert_str(String(d.type)).is_equal("loot")

func test_ordinary_weights_follow_f46() -> void:
	var t := _t()
	var r := _rng(21)
	var n := { "arms": 0, "loot": 0, "heal": 0 }
	for i in 4000:
		n[DoorRules.ordinary(r, [], ALL_TYPES, t).type] += 1
	# loot 0.40/0.83 = 48%, arms 30%, heal 22%.
	assert_int(n.loot).is_between(1780, 2060)
	assert_int(n.arms).is_between(1080, 1330)
	assert_int(n.heal).is_between(770, 1000)

func test_first_run_opens_one_god_loot_and_heal_only() -> void:
	var t := _t()
	var u := DoorRules.unlocks(0, 0, GODS, t)
	assert_array(u.gods).is_equal(["svarog"])
	assert_array(u.types).contains_exactly_in_any_order(["god", "loot", "heal"])
	var r := _rng(3)
	for i in 500:
		for d in DoorRules.make_fork(r, { "god_time": i % 2 == 0, "gods": u.gods, "types": u.types, "can_surica": true }, t):
			assert_bool(String(d.type) in ["god", "loot", "heal"]).is_true()
			if d.type == "god":
				assert_str(String(d.god)).is_equal("svarog")

func test_second_run_opens_all_gods_rod_arms_and_surica_after_a_boss() -> void:
	var t := _t()
	var u := DoorRules.unlocks(1, 0, GODS, t)
	assert_array(u.gods).is_equal(GODS)
	assert_array(u.types).contains(["rod", "arms"])
	assert_array(u.types).not_contains(["surica"])
	assert_array(DoorRules.unlocks(1, 1, GODS, t).types).contains(["surica"])

func test_lair_offers_three_different_gods_with_a_new_one() -> void:
	var r := _rng(31)
	var count := {}
	for i in 1000:
		var g := DoorRules.lair_gods(r, GODS, ["svarog", "perun", "stribog", "veles"], 3)
		assert_int(g.size()).is_equal(3)
		var seen := {}
		for x in g:
			seen[x] = true
			count[x] = int(count.get(x, 0)) + 1
		assert_int(seen.size()).is_equal(3)
		assert_bool("zhiva" in g).is_true()
	assert_int(int(count.get("svarog", 0))).is_between(300, 800)

func test_lair_every_god_appears_in_50_to_70_percent_when_hero_has_none() -> void:
	var r := _rng(37)
	var count := {}
	for i in 1000:
		for x in DoorRules.lair_gods(r, GODS, [], 3):
			count[x] = int(count.get(x, 0)) + 1
	for g in GODS:
		assert_int(int(count.get(g, 0))).is_between(500, 700)

func test_same_seed_same_forks() -> void:
	var t := _t()
	var a := RunRng.new(42)
	var b := RunRng.new(42)
	for i in 20:
		assert_array(DoorRules.make_fork(a.stream("doors"), _ctx(i % 3 == 0), t)).is_equal(DoorRules.make_fork(b.stream("doors"), _ctx(i % 3 == 0), t))
	assert_int(a.for_room(1, 2).randi()).is_equal(b.for_room(1, 2).randi())
