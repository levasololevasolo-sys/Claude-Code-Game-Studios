## Schema of assets/data/enemies.json (ADR-0001: every JSON table has a test)
## and EnemyRoster pack rules (GDD enemies-and-elites §3.2-3.3, AC 4).
extends GdUnitTestSuite

const PATH := "res://assets/data/enemies.json"
const COMMON: Array[String] = ["name", "role", "w", "h", "hp", "flies", "weight", "embers", "contact", "color", "eye"]

func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))

func test_every_row_has_common_fields() -> void:
	var t := _table()
	for id: String in t:
		if id.begins_with("_"):
			continue
		for k in COMMON:
			assert_bool(t[id].has(k)).override_failure_message("%s lacks %s" % [id, k]).is_true()

func test_four_kinds_exist_with_gdd_hp() -> void:
	var t := _table()
	assert_float(float(t.crawler.hp)).is_equal(34.0)
	assert_float(float(t.bat.hp)).is_equal(20.0)
	assert_float(float(t.sentry.hp)).is_equal(50.0)
	assert_float(float(t.bloat.hp)).is_equal(26.0)

func test_every_row_has_a_script_in_roster() -> void:
	for id: String in _table():
		if not id.begins_with("_"):
			assert_bool(EnemyRoster.KINDS.has(id)).is_true()

func test_tune_row_returns_the_same_row() -> void:
	assert_dict(Tune.row("enemies", "bat")).is_equal(_table().bat)

func _kinds(seed_value: int, size: int, pack_i: int, k: int, tier: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return EnemyRoster.pack_kinds(rng, size, pack_i, k, tier, ["crawler", "sentry", "bat"], ["bloat"], _table(), Tune.data)

func test_no_pack_has_more_than_two_flyers_over_1000_seeds() -> void:
	var worst := 0
	for s in 1000:
		var n := 0
		for id in _kinds(s, 8, s % 3, 3 + s % 3, 1 + s % 5):
			if bool(_table()[id].flies):
				n += 1
		worst = maxi(worst, n)
	assert_int(worst).is_less_equal(2)

func test_first_room_is_two_of_first_roster_kind() -> void:
	assert_array(_kinds(1, 2, 0, 1, 1)).is_equal(["crawler", "crawler"])

func test_room2_tier1_has_no_late_kind() -> void:
	for s in 200:
		assert_bool("bloat" in _kinds(s, 4, 0, 2, 1)).is_false()

func test_room3_can_have_late_kind() -> void:
	var seen := false
	for s in 200:
		seen = seen or "bloat" in _kinds(s, 4, 0, 3, 1)
	assert_bool(seen).is_true()
