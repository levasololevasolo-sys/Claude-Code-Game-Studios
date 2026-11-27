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

# ---------------- second pass (design/audio/sfx-coverage.md) ----------------

## Every `&"id"` passed to play / play_at / play_near / Audio.play anywhere in
## src/, and every id named by a config map, has a row and shipped wav files.
func test_every_id_referenced_in_code_and_maps_exists_with_files() -> void:
	var cfg := AudioScript.load_config(AudioScript.CONFIG_PATH)
	var ids := _code_ids("res://src")
	for table: String in ["ambient", "surfaces", "deaths", "traps"]:
		for k: String in cfg.get(table, {}):
			ids.append(String(cfg[table][k]))
	for kind: String in cfg.states:
		for st: String in cfg.states[kind]:
			ids.append(String(cfg.states[kind][st]))
	for scr: String in cfg.screens:
		for k: String in cfg.screens[scr]:
			var v: Variant = cfg.screens[scr][k]
			if v is Dictionary:
				for o: String in v:
					ids.append(String(v[o]))
			elif v is String and String(v).begins_with("ui_"):
				ids.append(String(v))
	assert_int(ids.size()).is_greater(60)
	for id: String in ids:
		if id == "":
			continue
		assert_bool((cfg.sounds as Dictionary).has(id)).override_failure_message("id '%s' used but not in audio.json" % id).is_true()
		for f: String in (cfg.sounds.get(id, {}) as Dictionary).get("files", []):
			assert_bool(FileAccess.file_exists(AudioScript.file_path(f))).override_failure_message("%s: no %s" % [id, f]).is_true()

func test_style_guide_ui_cues_and_limb_parry_ids_exist_on_their_buses() -> void:
	var cfg := AudioScript.load_config(AudioScript.CONFIG_PATH)
	for id: String in ["ui_hover_wood", "ui_open_wood", "ui_close", "ui_cancel_wood", "ui_confirm_gold", "ui_error_clank",
			"ui_open_god", "ui_card_deal", "ui_rune_select", "ui_thread_run", "ui_bark_unroll", "ui_text_tick", "ui_shop_knock",
			"ui_forge_buy", "ui_page_turn", "ui_tab_switch", "ui_count_tick", "ui_thread_snap", "ui_victory_swell",
			"ui_door_near", "ui_codex_new", "ui_rebind_wait", "ui_menu_start",
			"limb_sever", "limb_head_pop", "limb_part_thud", "parry_clang", "parry_whiff"]:
		assert_bool((cfg.sounds as Dictionary).has(id)).override_failure_message(id).is_true()
		if id.begins_with("ui_"):
			assert_str(String(cfg.sounds[id].bus)).is_equal("UI")
	assert_int((cfg.sounds.enemy_death.files as Array).size()).is_greater_equal(3)

func test_ambient_loops_are_long_and_on_music_bus() -> void:
	var cfg := AudioScript.load_config(AudioScript.CONFIG_PATH)
	for key: String in ["swamp", "forest", "frost", "base"]:
		var row: Dictionary = cfg.sounds[String(cfg.ambient[key])]
		assert_bool(bool(row.get("loop", false))).is_true()
		assert_str(String(row.bus)).is_equal("Music")
		var s := load(AudioScript.file_path(String(row.files[0]))) as AudioStream
		assert_float(s.get_length()).is_greater_equal(30.0)

func test_unknown_id_is_ignored_silently() -> void:
	var a: Node = auto_free(AudioScript.new())
	a.config = FIXTURE
	a.play(&"limb_from_another_agent")
	a.play_at(&"", Vector2.ZERO)
	assert_bool(a.has_sound(&"limb_from_another_agent")).is_false()

func test_state_and_death_lookup_returns_mapped_or_default() -> void:
	var cfg := { "states": { "wolf": { "bite": "bite_snap" } }, "deaths": { "bloat": "bloat_burst", "boss": "boss_death", "wall": "" } }
	assert_str(AudioScript.state_sound(cfg, "wolf", "bite")).is_equal("bite_snap")
	assert_str(AudioScript.state_sound(cfg, "wolf", "run")).is_equal("")
	assert_str(AudioScript.state_sound(cfg, "nobody", "bite")).is_equal("")
	assert_str(AudioScript.death_sound(cfg, "bloat", false)).is_equal("bloat_burst")
	assert_str(AudioScript.death_sound(cfg, "likho", true)).is_equal("boss_death")
	assert_str(AudioScript.death_sound(cfg, "wolf", false)).is_equal("enemy_death")
	assert_str(AudioScript.death_sound(cfg, "wall", false)).is_equal("")

func test_step_index_and_voice_limit_boundaries() -> void:
	assert_int(AudioScript.step_index(0.0)).is_equal(0)
	assert_int(AudioScript.step_index(PI - 0.01)).is_equal(0)
	assert_int(AudioScript.step_index(PI)).is_equal(1)
	assert_bool(AudioScript.voices_full(2, { "max": 2 }, 3)).is_true()
	assert_bool(AudioScript.voices_full(1, { "max": 2 }, 3)).is_false()
	assert_bool(AudioScript.voices_full(2, {}, 3)).is_false()

static func _code_ids(dir: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("(?:play|play_at|play_near)\\(\\s*&\"([a-z0-9_]+)\"")
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(dir + "/" + f)):
				out.append(m.get_string(1))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_code_ids(dir + "/" + d))
	return out
