## Minimap reveal rules (GDD level-structure §3.6, AC 9): rooms open on entry,
## neighbours are seen with "?", closed trails are crossed, chests show until
## opened, the lair shows ONLY after its door was seen (developer decision 27.11).
extends GdUnitTestSuite

func _level() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))
	var lib := LevelGen.prepare(JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/room_templates_swamp.json")))
	return LevelGen.build(7007, 1, lib, LevelGen.tuning_for(data))

func _kinds(m: LevelMap) -> Array:
	return m.icons().map(func(ic: Dictionary) -> String: return String(ic.kind))

func test_nothing_is_known_before_entry() -> void:
	var m := LevelMap.new(_level())
	assert_str(m.state(0)).is_equal("hidden")
	assert_array(m.icons()).is_empty()

func test_entering_a_room_opens_it_and_marks_neighbours_seen() -> void:
	var l := _level()
	var m := LevelMap.new(l)
	m.visit(int(l.entry))
	assert_str(m.state(int(l.entry))).is_equal("visited")
	var nb := -1
	for e: Array in l.edges:
		if int(e[0]) == int(l.entry):
			nb = int(e[1])
	assert_str(m.state(nb)).is_equal("seen")
	m.visit(nb)
	assert_str(m.state(nb)).is_equal("visited")

func test_lair_hidden_until_its_door_is_seen() -> void:
	var l := _level()
	var m := LevelMap.new(l)
	# Visit every room but the lair gate (the lair gate's neighbour becomes "seen").
	for r: Dictionary in l.rooms:
		if int(r.i) != int(l.lairgate):
			m.visit(int(r.i))
	assert_str(m.state(int(l.lairgate))).is_equal("seen")
	assert_bool(m.shows_lair()).is_false()
	m.visit(int(l.lairgate))
	assert_bool(m.shows_lair()).is_true()

func test_lair_shows_when_the_door_is_on_screen() -> void:
	var m := LevelMap.new(_level())
	assert_bool(m.shows_lair()).is_false()
	m.see_lair()
	assert_bool(m.shows_lair()).is_true()

func test_chest_icon_until_opened() -> void:
	var l := _level()
	var m := LevelMap.new(l)
	assert_bool((l.chests as Array).is_empty()).is_false()
	var ch: Dictionary = l.chests[0]
	m.visit(int(ch.room))
	assert_array(_kinds(m)).contains(["chest"])
	m.opened[0] = true
	var still := m.icons().filter(func(ic: Dictionary) -> bool: return String(ic.kind) == "chest" and int(ic.room) == int(ch.room) and (ic.at as Vector2).is_equal_approx(Vector2((ch.c.x + 0.5) / 16.0, (ch.c.y + 0.5) / 9.0)))
	assert_array(still).is_empty()

func test_breakable_wall_hidden_until_hit() -> void:
	var l := _level()
	var m := LevelMap.new(l)
	for r: Dictionary in l.rooms:
		m.visit(int(r.i))
	assert_array(_kinds(m)).not_contains(["wall"])
	if not (l.walls as Array).is_empty():
		m.hit_walls[0] = true
		assert_array(_kinds(m)).contains(["wall"])

func test_choosing_a_gate_closes_the_other_trails() -> void:
	var l := _level()
	var m := LevelMap.new(l)
	var f: Dictionary = l.forks[0]
	var other: Array = f.trails[1].rooms
	m.choose(int(f.room), { "type": "loot", "god": "" }, other)
	for r: int in other:
		assert_bool(m.closed.has(r)).is_true()
	m.visit(int(f.room))
	var forks := m.icons().filter(func(ic: Dictionary) -> bool: return String(ic.kind) == "fork")
	assert_str(String(forks[0].info.type)).is_equal("loot")
