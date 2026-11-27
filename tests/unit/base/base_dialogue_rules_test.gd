## Dialogue selection (living-world §1.3): priority, specificity, say-once, the
## one-event rule, chains, repeat cooldowns and ambient fallback.
extends GdUnitTestSuite

func _line(id: String, npc: String, pr: int, when: Dictionary, once: bool = true, extra: Dictionary = {}) -> Dictionary:
	var l := { "id": id, "npc": npc, "ru": id, "priority": pr, "once": once, "chorus": false, "when": when, "after": [], "sets": [] }
	l.merge(extra, true)
	return l

func _rules(lines: Array) -> DialogueRules:
	return DialogueRules.make({ "lines": lines, "chorus_penalty": 30, "spark_min": 40, "ambient_memory": 3 })

func _meta() -> MetaState:
	var m := MetaState.new()
	m.runs = 3
	m.story.visits = 2
	return m

func test_higher_priority_wins() -> void:
	var m := _meta()
	m.story.fresh = [{ "event": "death", "location": "swamp" }]
	var r := _rules([_line("amb", "dolya", 10, { "event": "ambient" }, false),
		_line("loc", "dolya", 45, { "event": "death", "location": "swamp" }, false),
		_line("main", "dolya", 100, { "event": "title", "title_min": 0 })])
	assert_str(String(r.pick_visit(["dolya"], m).dolya.id)).is_equal("main")

func test_once_line_is_not_said_twice() -> void:
	var m := _meta()
	var r := _rules([_line("amb", "potap", 10, { "event": "ambient" }, false),
		_line("t", "potap", 100, { "event": "title" })])
	var first := r.pick_visit(["potap"], m)
	r.apply_visit(first, m)
	assert_str(String(first.potap.id)).is_equal("t")
	assert_bool(m.story.said.has("t")).is_true()
	assert_str(String(r.pick_visit(["potap"], m).potap.id)).is_equal("amb")

func test_more_specific_line_wins_a_tie() -> void:
	var m := _meta()
	m.story.fresh = [{ "event": "death", "location": "swamp" }]
	var r := _rules([_line("any", "dolya", 45, { "event": "death" }), _line("swamp", "dolya", 45, { "event": "death", "location": "swamp" })])
	assert_str(String(r.pick_visit(["dolya"], m).dolya.id)).is_equal("swamp")

func test_one_event_rule_moves_the_second_npc_on() -> void:
	var m := _meta()
	m.story.fresh = [{ "event": "killed_by", "enemy": "crawler", "n": 1 }]
	var r := _rules([_line("a", "dolya", 60, { "event": "killed_by", "enemy": "crawler" }),
		_line("b", "bayun", 60, { "event": "killed_by", "enemy": "crawler" }),
		_line("b_runs", "bayun", 40, { "event": "runs", "n_min": 3, "n_max": 3 })])
	var p := r.pick_visit(["dolya", "bayun"], m)
	assert_str(String(p.dolya.id)).is_equal("a")
	assert_str(String(p.bayun.id)).is_equal("b_runs")

func test_after_chain_waits_for_its_line() -> void:
	var m := _meta()
	var r := _rules([_line("t1", "potap", 100, { "event": "title" }), _line("t1b", "potap", 100, { "event": "title" }, true, { "after": ["t1"] })])
	var p := r.pick_visit(["potap"], m)
	assert_str(String(p.potap.id)).is_equal("t1")
	r.apply_visit(p, m)
	assert_str(String(r.pick_visit(["potap"], m).potap.id)).is_equal("t1b")

func test_repeat_line_rests_every_visits() -> void:
	var m := _meta()
	var r := _rules([_line("amb", "dolya", 10, { "event": "ambient" }, false), _line("loc", "dolya", 45, { "event": "death", "every": 3 }, false)])
	m.story.fresh = [{ "event": "death" }]
	var p := r.pick_visit(["dolya"], m)
	r.apply_visit(p, m)
	m.story.fresh = [{ "event": "death" }]
	assert_str(String(p.dolya.id)).is_equal("loc")
	assert_str(String(r.pick_visit(["dolya"], m).dolya.id)).is_equal("amb")

func test_apply_visit_burns_fresh_events_and_counts_the_visit() -> void:
	var m := _meta()
	m.story.fresh = [{ "event": "death" }]
	var r := _rules([_line("amb", "dolya", 10, { "event": "ambient" }, false)])
	r.apply_visit(r.pick_visit(["dolya"], m), m)
	assert_array(m.story.fresh).is_empty()
	assert_int(int(m.story.visits)).is_equal(3)

func test_first_visit_only_on_visit_zero() -> void:
	var m := MetaState.new()
	var r := _rules([_line("f", "chur", 80, { "event": "first_visit" })])
	assert_str(String(r.pick_visit(["chur"], m).chur.id)).is_equal("f")
	m.story.visits = 1
	assert_bool(r.pick_visit(["chur"], m).has("chur")).is_false()

func test_starter_bank_has_no_unknown_fields_and_short_lines() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dialogue.json"))
	for l: Dictionary in d.lines:
		assert_int(String(l.ru).length()).is_less_equal(120)
		for k: String in l.when:
			assert_bool(k in DialogueRules.WHEN_KEYS).is_true()
