## GameSettings (Settings autoload model): bindings, conflict swap, reset and
## the settings.cfg round trip (in memory through ConfigFile text).
extends GdUnitTestSuite

func _s() -> GameSettings:
	return auto_free(GameSettings.new())

func _key(k: Key) -> String:
	return "key:%d" % k

func test_defaults_come_from_input_setup() -> void:
	var s := _s()
	assert_str(s.code_at("jump", "kbm", 0)).is_equal(_key(KEY_SPACE))
	assert_str(s.code_at("dash", "kbm", 1)).is_equal(_key(KEY_K))
	assert_str(s.code_at("strike", "kbm", 1)).is_equal("mouse:%d" % MOUSE_BUTTON_LEFT)
	assert_str(s.code_at("jump", "pad", 0)).is_equal("pad:%d" % JOY_BUTTON_A)
	assert_str(s.code_at("jump", "kbm", 1)).is_equal("")

func test_bind_free_key() -> void:
	var s := _s()
	var r := s.bind("interact", 1, _key(KEY_F))
	assert_bool(r.ok).is_true()
	assert_bool((r.swapped as Dictionary).is_empty()).is_true()
	assert_str(s.code_at("interact", "kbm", 1)).is_equal(_key(KEY_F))

func test_conflict_is_detected_and_swapped() -> void:
	var s := _s()
	assert_dict(s.find_conflict("jump", 0, _key(KEY_K))).is_equal({ "action": "dash", "slot": 1 })
	var r := s.bind("jump", 0, _key(KEY_K))
	assert_bool(r.ok).is_true()
	assert_str(String(r.swapped.action)).is_equal("dash")
	assert_str(s.code_at("jump", "kbm", 0)).is_equal(_key(KEY_K))
	assert_str(s.code_at("dash", "kbm", 1)).is_equal(_key(KEY_SPACE))
	assert_dict(s.find_conflict("jump", 0, _key(KEY_K))).is_empty()

func test_conflict_with_empty_slot_leaves_other_unbound_and_warns() -> void:
	var s := _s()
	s.bind("jump", 1, _key(KEY_E))
	assert_str(s.code_at("interact", "kbm", 0)).is_equal("")
	assert_array(s.unbound_actions()).contains(["interact"])

func test_refuses_reserved_wrong_device_and_unknown() -> void:
	var s := _s()
	assert_str(String(s.bind("jump", 0, _key(KEY_ESCAPE)).reason)).is_equal("reserved")
	assert_str(String(s.bind("jump", 0, "pad:%d" % JOY_BUTTON_START).reason)).is_equal("reserved")
	assert_str(String(s.bind("jump", 0, "pad:%d" % JOY_BUTTON_B, "kbm").reason)).is_equal("device")
	assert_str(String(s.bind("fly", 0, _key(KEY_K)).reason)).is_equal("unknown")
	assert_str(String(s.bind("jump", 2, _key(KEY_Z)).reason)).is_equal("slot")
	assert_str(s.code_at("jump", "kbm", 0)).is_equal(_key(KEY_SPACE))

func test_mouse_and_pad_rebind() -> void:
	var s := _s()
	s.bind("flare", 1, "mouse:%d" % MOUSE_BUTTON_XBUTTON1)
	assert_str(s.code_at("flare", "kbm", 1)).is_equal("mouse:%d" % MOUSE_BUTTON_XBUTTON1)
	var r := s.bind("jump", 0, "pad:%d" % JOY_BUTTON_X)
	assert_str(String(r.swapped.action)).is_equal("strike")
	assert_str(s.code_at("strike", "pad", 0)).is_equal("pad:%d" % JOY_BUTTON_A)

func test_event_code_round_trip() -> void:
	for code: String in [_key(KEY_K), "mouse:%d" % MOUSE_BUTTON_RIGHT, "pad:%d" % JOY_BUTTON_Y]:
		assert_str(GameSettings.code_of(GameSettings.event_of(code))).is_equal(code)
	assert_str(GameSettings.label_of(_key(KEY_SPACE))).is_equal("Пробел")
	assert_str(GameSettings.label_of("")).is_equal("—")

func test_save_load_roundtrip() -> void:
	var s := _s()
	s.bind("jump", 0, _key(KEY_K))
	s.bind("sub", 1, "mouse:%d" % MOUSE_BUTTON_XBUTTON2)
	s.volumes["Music"] = 0.25
	s.volumes["SFX"] = 0.0
	s.shake = false
	var text := s.to_config().encode_to_text()
	var cfg := ConfigFile.new()
	assert_int(cfg.parse(text)).is_equal(OK)
	var t := _s()
	t.from_config(cfg)
	assert_dict(t.bindings).is_equal(s.bindings)
	assert_float(float(t.volumes.Music)).is_equal(0.25)
	assert_float(float(t.volumes.SFX)).is_equal(0.0)
	assert_bool(t.shake).is_false()
	assert_bool(t.flash).is_true()

func test_broken_values_and_newer_format_fall_back() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "jump.kbm", PackedStringArray(["pad:0", _key(KEY_Z)]))
	cfg.set_value("audio", "Master", 7.0)
	var t := _s()
	t.from_config(cfg)
	assert_str(t.code_at("jump", "kbm", 0)).is_equal("")
	assert_str(t.code_at("jump", "kbm", 1)).is_equal(_key(KEY_Z))
	assert_float(float(t.volumes.Master)).is_equal(1.0)
	cfg.set_value("meta", "format", GameSettings.FORMAT + 1)
	t.from_config(cfg)
	assert_dict(t.bindings).is_equal(GameSettings.default_bindings())

func test_reset_controls_restores_defaults() -> void:
	var s := _s()
	s.bind("jump", 0, _key(KEY_K))
	s.volumes["UI"] = 0.5
	s.reset_controls()
	assert_dict(s.bindings).is_equal(GameSettings.default_bindings())
	assert_float(float(s.volumes.UI)).is_equal(0.5)
	s.reset_all()
	assert_float(float(s.volumes.UI)).is_equal(1.0)
