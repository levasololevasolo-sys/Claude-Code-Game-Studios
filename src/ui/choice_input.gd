## Input of the choice screens (rune offer, god choice, run summary), BUG-0002 and
## BUG-0003. Turns keyboard, gamepad (d-pad, left stick, A, the interact button)
## and mouse events into one intent. Confirming is blocked for `lock` seconds after
## the screen opens (tuning "screen_input_lock"), and the strike / jump keys
## (J, Space) never confirm, so mashing attack cannot skip a screen.
## Pure logic: the screen feeds events and tick(dt), then applies the intent.
class_name ChoiceInput
extends RefCounted

enum Act { NONE, PREV, NEXT, HOVER, CONFIRM, PICK }

## Left stick X past this counts as a step; it must fall under STICK_OFF to step again.
const STICK_ON: float = 0.5
const STICK_OFF: float = 0.3

## Seconds after opening during which nothing confirms.
var lock: float = 0.4
var _t: float = 0.0
var _stick: int = 0

## A reader with a confirm lockout of `p_lock` seconds.
static func make(p_lock: float) -> ChoiceInput:
	var c := ChoiceInput.new()
	c.lock = p_lock
	return c

## Advances the lockout clock (unscaled screen time; the tree is paused).
func tick(dt: float) -> void:
	_t += dt

## True while confirms are still ignored.
func locked() -> bool:
	return _t < lock

## Index of the rect under `pos`, -1 if none.
static func hit(rects: Array, pos: Vector2) -> int:
	for i in rects.size():
		if (rects[i] as Rect2).has_point(pos):
			return i
	return -1

## Reads one event for a screen of `count` options laid out in `rects` (local
## coordinates; empty when the caller is not handling mouse events).
## Returns {act: Act, i: option index for HOVER / PICK}.
func read(ev: InputEvent, count: int, rects: Array = []) -> Dictionary:
	var none := { "act": Act.NONE, "i": -1 }
	if ev is InputEventMouse:
		var i := hit(rects, (ev as InputEventMouse).position)
		if i < 0:
			return none
		var mb := ev as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not locked():
			return { "act": Act.PICK, "i": i }
		if ev is InputEventMouseMotion or (mb and mb.pressed):
			return { "act": Act.HOVER, "i": i }
		return none
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		if m.axis != JOY_AXIS_LEFT_X:
			return none
		var dir := 0
		if m.axis_value <= -STICK_ON:
			dir = -1
		elif m.axis_value >= STICK_ON:
			dir = 1
		elif absf(m.axis_value) < STICK_OFF:
			_stick = 0
		if dir == 0 or dir == _stick:
			return none
		_stick = dir
		return { "act": Act.PREV if dir < 0 else Act.NEXT, "i": -1 }
	if ev is InputEventJoypadButton:
		var b := ev as InputEventJoypadButton
		if not b.pressed:
			return none
		match b.button_index:
			JOY_BUTTON_DPAD_LEFT:
				return { "act": Act.PREV, "i": -1 }
			JOY_BUTTON_DPAD_RIGHT:
				return { "act": Act.NEXT, "i": -1 }
			JOY_BUTTON_A:
				return _confirm()
		if _is_interact(ev):
			return _confirm()
		return none
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return none
	var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	match code:
		KEY_LEFT, KEY_A:
			return { "act": Act.PREV, "i": -1 }
		KEY_RIGHT, KEY_D:
			return { "act": Act.NEXT, "i": -1 }
		KEY_ENTER, KEY_KP_ENTER, KEY_E:
			return _confirm()
		KEY_J, KEY_SPACE:
			return none
	var n := code - KEY_1
	if n >= 0 and n < count and n < 9:
		return { "act": Act.NONE, "i": -1 } if locked() else { "act": Act.PICK, "i": n }
	if _is_interact(ev):
		return _confirm()
	return none

func _confirm() -> Dictionary:
	return { "act": Act.NONE if locked() else Act.CONFIRM, "i": -1 }

static func _is_interact(ev: InputEvent) -> bool:
	return InputMap.has_action("interact") and ev.is_action_pressed("interact")
