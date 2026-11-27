## Audio autoload (first sound pass, production/qa/evidence/audio-pass.md):
## config loads, every sound id maps to shipped wav files, cooldown and
## charge-tick logic.
extends GdUnitTestSuite

const AudioScript := preload("res://src/core/audio.gd")

const FIXTURE := { "sounds": { "hit": { "files": ["hit_flesh_1"], "cd": 0.05 }, "free": { "files": ["ui_move"], "cd": 0.0 } } }

func test_config_loads_with_buses_and_sounds() -> void:
	var cfg := AudioScript.load_config(AudioScript.CONFIG_PATH)
	assert_bool(cfg.is_empty()).is_false()
	assert_bool(cfg.has("sounds")).is_true()
	for b: String in ["Master", "SFX", "Music", "UI"]:
		assert_bool((cfg.buses as Dictionary).has(b)).is_true()

func test_every_sound_id_has_its_files() -> void:
	var cfg := AudioScript.load_config(AudioScript.CONFIG_PATH)
	var sounds: Dictionary = cfg.sounds
	assert_int(sounds.size()).is_greater_equal(20)
	for id: String in sounds:
		var files: Array = (sounds[id] as Dictionary).get("files", [])
		assert_bool(files.is_empty()).override_failure_message("%s has no files" % id).is_false()
		for f: String in files:
			assert_bool(FileAccess.file_exists(AudioScript.file_path(f))) \
				.override_failure_message("%s: missing %s" % [id, AudioScript.file_path(f)]).is_true()

func test_every_sound_bus_exists_in_the_layout() -> void:
	var cfg := AudioScript.load_config(AudioScript.CONFIG_PATH)
	for id: String in cfg.sounds:
		assert_array(["SFX", "Music", "UI"]).contains([String((cfg.sounds[id] as Dictionary).get("bus", "SFX"))])

func test_cooldown_ok_boundaries() -> void:
	assert_bool(AudioScript.cooldown_ok(-1, 0, 1.0)).is_true()
	assert_bool(AudioScript.cooldown_ok(1000, 1049, 0.05)).is_false()
	assert_bool(AudioScript.cooldown_ok(1000, 1050, 0.05)).is_true()
	assert_bool(AudioScript.cooldown_ok(1000, 1000, 0.0)).is_true()

func test_gate_blocks_stacking_within_cooldown() -> void:
	var a: Node = auto_free(AudioScript.new())
	a.config = FIXTURE
	assert_bool(a.gate(&"hit", 1000)).is_true()
	assert_bool(a.gate(&"hit", 1020)).is_false()
	assert_bool(a.gate(&"hit", 1049)).is_false()
	assert_bool(a.gate(&"hit", 1050)).is_true()
	assert_bool(a.gate(&"free", 1050)).is_true()
	assert_bool(a.gate(&"free", 1050)).is_true()

func test_gate_rejects_unknown_id() -> void:
	var a: Node = auto_free(AudioScript.new())
	a.config = FIXTURE
	assert_bool(a.gate(&"nope", 0)).is_false()

func test_ticks_crossed_counts_steps_upward_only() -> void:
	assert_int(AudioScript.ticks_crossed(0.0, 9.9, 10.0)).is_equal(0)
	assert_int(AudioScript.ticks_crossed(9.0, 10.0, 10.0)).is_equal(1)
	assert_int(AudioScript.ticks_crossed(5.0, 35.0, 10.0)).is_equal(3)
	assert_int(AudioScript.ticks_crossed(100.0, 0.0, 10.0)).is_equal(0)
	assert_int(AudioScript.ticks_crossed(0.0, 50.0, 0.0)).is_equal(0)
