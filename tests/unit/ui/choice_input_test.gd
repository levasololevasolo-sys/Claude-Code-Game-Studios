## ChoiceInput (BUG-0002 gamepad / mouse selection, BUG-0003 lockout and no
## confirm on strike / jump). Pure logic: events in, intents out.
extends GdUnitTestSuite

const LOCK := 0.4
const RECTS := [Rect2(0, 0, 100, 100), Rect2(200, 0, 100, 100)]

func _open(unlocked: bool) -> ChoiceInput:
	var c := ChoiceInput.make(LOCK)
	if unlocked:
		c.tick(LOCK + 0.01)
	return c

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e

func _pad(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e

func _stick(v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = v
	return e

func _click(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	return e

func test_strike_and_jump_keys_never_confirm() -> void:
	var c := _open(true)
	assert_int(c.read(_key(KEY_J), 3).act).is_equal(ChoiceInput.Act.NONE)
	assert_int(c.read(_key(KEY_SPACE), 3).act).is_equal(ChoiceInput.Act.NONE)

func test_enter_e_and_pad_a_confirm_after_lockout() -> void:
	var c := _open(true)
	assert_int(c.read(_key(KEY_ENTER), 3).act).is_equal(ChoiceInput.Act.CONFIRM)
	assert_int(c.read(_key(KEY_E), 3).act).is_equal(ChoiceInput.Act.CONFIRM)
	assert_int(c.read(_pad(JOY_BUTTON_A), 3).act).is_equal(ChoiceInput.Act.CONFIRM)

func test_confirms_and_picks_are_ignored_inside_lockout() -> void:
	var c := _open(false)
	c.tick(LOCK - 0.05)
	assert_bool(c.locked()).is_true()
	assert_int(c.read(_key(KEY_ENTER), 3).act).is_equal(ChoiceInput.Act.NONE)
	assert_int(c.read(_pad(JOY_BUTTON_A), 3).act).is_equal(ChoiceInput.Act.NONE)
	assert_int(c.read(_key(KEY_1), 3).act).is_equal(ChoiceInput.Act.NONE)
	assert_int(c.read(_click(Vector2(50, 50)), 2, RECTS).act).is_equal(ChoiceInput.Act.HOVER)
	c.tick(0.1)
	assert_bool(c.locked()).is_false()

func test_moves_work_inside_lockout() -> void:
	var c := _open(false)
	assert_int(c.read(_key(KEY_LEFT), 3).act).is_equal(ChoiceInput.Act.PREV)
	assert_int(c.read(_pad(JOY_BUTTON_DPAD_RIGHT), 3).act).is_equal(ChoiceInput.Act.NEXT)

func test_digit_picks_that_card_after_lockout() -> void:
	var r := _open(true).read(_key(KEY_2), 3)
	assert_int(r.act).is_equal(ChoiceInput.Act.PICK)
	assert_int(r.i).is_equal(1)
	assert_int(_open(true).read(_key(KEY_4), 3).act).is_equal(ChoiceInput.Act.NONE)

func test_stick_steps_once_until_it_returns_to_centre() -> void:
	var c := _open(true)
	assert_int(c.read(_stick(0.9), 3).act).is_equal(ChoiceInput.Act.NEXT)
	assert_int(c.read(_stick(1.0), 3).act).is_equal(ChoiceInput.Act.NONE)
	assert_int(c.read(_stick(0.1), 3).act).is_equal(ChoiceInput.Act.NONE)
	assert_int(c.read(_stick(0.8), 3).act).is_equal(ChoiceInput.Act.NEXT)
	assert_int(c.read(_stick(-0.8), 3).act).is_equal(ChoiceInput.Act.PREV)

func test_mouse_hover_and_click_hit_the_card_under_the_cursor() -> void:
	var c := _open(true)
	var m := InputEventMouseMotion.new()
	m.position = Vector2(250, 50)
	var h := c.read(m, 2, RECTS)
	assert_int(h.act).is_equal(ChoiceInput.Act.HOVER)
	assert_int(h.i).is_equal(1)
	var k := c.read(_click(Vector2(50, 50)), 2, RECTS)
	assert_int(k.act).is_equal(ChoiceInput.Act.PICK)
	assert_int(k.i).is_equal(0)
	assert_int(c.read(_click(Vector2(150, 50)), 2, RECTS).act).is_equal(ChoiceInput.Act.NONE)

func test_tuning_lockout_is_between_0_3_and_0_5_s() -> void:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))
	assert_float(float(t.screen_input_lock)).is_between(0.3, 0.5)
