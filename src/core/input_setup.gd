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
	"flare": [KEY_L],
	"interact": [KEY_E],
	"sub": [KEY_U],
}
const PADS := { "jump": JOY_BUTTON_A, "strike": JOY_BUTTON_X, "dash": JOY_BUTTON_RIGHT_SHOULDER, "flare": JOY_BUTTON_Y, "interact": JOY_BUTTON_B,
	"sub": JOY_BUTTON_LEFT_SHOULDER,
	"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN }

## Mouse buttons of the defaults (keyboard + mouse slots of GameSettings):
## strike LMB, Flare RMB, secondary weapon MMB (weapons-and-loot §3.4).
const MOUSE := { "strike": MOUSE_BUTTON_LEFT, "flare": MOUSE_BUTTON_RIGHT, "sub": MOUSE_BUTTON_MIDDLE }
## Left stick directions; never rebound (GameSettings keeps them).
const AXES := { "move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0] }

## True after the first register(); later calls do nothing, so the player's
## rebinds (GameSettings.apply_input) are never overwritten by the defaults.
static var registered: bool = false

## Adds every action with its default events, once per process.
static func register() -> void:
	if registered:
		return
	registered = true
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
		if MOUSE.has(action):
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE[action]
			InputMap.action_add_event(action, mb)
		if AXES.has(action):
			var ax := InputEventJoypadMotion.new()
			ax.axis = AXES[action][0]
			ax.axis_value = AXES[action][1]
			InputMap.action_add_event(action, ax)
