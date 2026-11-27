## Registers the game's input actions (keyboard + gamepad) at start.
class_name InputSetup
extends RefCounted

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"strike": [KEY_J],
	"dash": [KEY_SHIFT, KEY_K],
}
const PADS := { "jump": JOY_BUTTON_A, "strike": JOY_BUTTON_X, "dash": JOY_BUTTON_RIGHT_SHOULDER,
	"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN }

## Adds every action that is not yet in the InputMap.
static func register() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for code: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
		if PADS.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PADS[action]
			InputMap.action_add_event(action, jb)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("strike", mouse)
	for pair: Array in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
			["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var ax := InputEventJoypadMotion.new()
		ax.axis = pair[1]
		ax.axis_value = pair[2]
		InputMap.action_add_event(pair[0], ax)
