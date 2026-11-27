## Player settings (GDD difficulty §3.6, design/ux/settings.md): key bindings,
## bus volumes and the screen-shake / flash toggles, kept in user://settings.cfg
## (ConfigFile), not in the save. Autoload name: Settings (after Audio, whose
## buses it sets). The model is plain data so tests drive it without a tree:
##   bindings: action -> { "kbm": [code, code], "pad": [code] }
##   code: "key:<physical keycode>", "mouse:<button>", "pad:<button>",
##   "padaxis:<trigger axis>" (LT / RT pressed past half), "" = empty.
## Left-stick motions are not rebindable and always stay in the InputMap.
## Difficulty is NOT here: it belongs to the save (MetaState.difficulty).
## `--settings=<path>` points the file elsewhere (checks never touch the player's).
class_name GameSettings
extends Node

## Emitted after any change was applied (UI refresh).
signal changed

const DEFAULT_PATH: String = "user://settings.cfg"
## Format of settings.cfg; a newer file is ignored (defaults), an older one migrates.
const FORMAT: int = 1
## Rebindable actions in menu order with their labels.
const ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down", "jump", "strike", "dash", "flare", "sub", "parry", "aim", "interact", "map"]
const LABELS: Dictionary = { "move_left": "Влево", "move_right": "Вправо", "move_up": "Вверх / удар вверх",
	"move_down": "Вниз / удар вниз", "jump": "Прыжок", "strike": "Удар", "dash": "Рывок / перекат",
	"flare": "Вспышка", "sub": "Доп. оружие", "parry": "Парирование", "aim": "Прицел", "interact": "Взять / говорить", "map": "Карта" }
## Slots per device kind.
const SLOTS: Dictionary = { "kbm": 2, "pad": 1 }
## Keys and buttons owned by the menus (pause, debug); binding them is refused.
const RESERVED: Array[String] = ["key:%d" % KEY_ESCAPE, "key:%d" % KEY_F3, "pad:%d" % JOY_BUTTON_START]
const BUSES: Array[String] = ["Master", "SFX", "Music", "UI"]
const BUS_LABELS: Dictionary = { "Master": "Общая громкость", "SFX": "Звуки", "Music": "Музыка", "UI": "Интерфейс" }

## Screen shake on (World.add_shake reads it); off = no shake at all.
static var shake_on: bool = true
## Full screen flashes on (World.add_flash reads it); off = flash × flash_off_mult.
static var flash_on: bool = true

var path: String = DEFAULT_PATH
var bindings: Dictionary = {}
## Bus -> volume 0..1 over the audio.json level (1 = as configured, 0 = muted).
var volumes: Dictionary = {}
var shake: bool = true
var flash: bool = true

func _init() -> void:
	reset_all()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--settings="):
			path = a.trim_prefix("--settings=")
	InputSetup.register()
	load_file(path)
	apply()

# ---------------- model ----------------

## Default bindings from InputSetup (keys, then mouse; one pad button).
static func default_bindings() -> Dictionary:
	var out := {}
	for action: String in ACTIONS:
		var kbm: Array = []
		for code: int in InputSetup.KEYS.get(action, []):
			kbm.append("key:%d" % code)
		if InputSetup.MOUSE.has(action):
			kbm.append("mouse:%d" % int(InputSetup.MOUSE[action]))
		kbm.resize(SLOTS.kbm)
		for i in kbm.size():
			if kbm[i] == null:
				kbm[i] = ""
		var pad: Array = ["pad:%d" % int(InputSetup.PADS[action])] if InputSetup.PADS.has(action) else [""]
		if InputSetup.PAD_AXES.has(action):
			pad = ["padaxis:%d" % int(InputSetup.PAD_AXES[action])]
		out[action] = { "kbm": kbm, "pad": pad }
	return out

## Every setting back to its default.
func reset_all() -> void:
	reset_controls()
	volumes = {}
	for b in BUSES:
		volumes[b] = 1.0
	shake = true
	flash = true

## Key bindings back to the defaults (the «Сбросить» button).
func reset_controls() -> void:
	bindings = default_bindings()

## "kbm" for keyboard and mouse codes, "pad" for gamepad codes, "" if unknown.
static func device_of(code: String) -> String:
	if code.begins_with("key:") or code.begins_with("mouse:"):
		return "kbm"
	if code.begins_with("pad:") or code.begins_with("padaxis:"):
		return "pad"
	return ""

## Code of a pressed key / mouse button / pad button event, "" for anything else.
static func code_of(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var pk := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return "key:%d" % pk if pk != KEY_NONE else ""
	if ev is InputEventMouseButton:
		return "mouse:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return "pad:%d" % (ev as InputEventJoypadButton).button_index
	if is_trigger_press(ev):
		return "padaxis:%d" % (ev as InputEventJoypadMotion).axis
	return ""

## True for an LT / RT motion pressed past half (sticks are never bound here).
static func is_trigger_press(ev: InputEvent) -> bool:
	var m := ev as InputEventJoypadMotion
	return m != null and (m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT) and m.axis_value >= 0.5

## InputEvent of a code (null for "" or an unknown kind).
static func event_of(code: String) -> InputEvent:
	var n := int(code.get_slice(":", 1))
	if code.begins_with("key:"):
		var k := InputEventKey.new()
		k.physical_keycode = n as Key
		return k
	if code.begins_with("mouse:"):
		var m := InputEventMouseButton.new()
		m.button_index = n as MouseButton
		return m
	if code.begins_with("pad:"):
		var j := InputEventJoypadButton.new()
		j.button_index = n as JoyButton
		return j
	if code.begins_with("padaxis:"):
		var t := InputEventJoypadMotion.new()
		t.axis = n as JoyAxis
		t.axis_value = 1.0
		return t
	return null

## Player-facing name of a code («K», «Пробел», «ЛКМ», «A»); «—» when empty.
static func label_of(code: String) -> String:
	if code == "":
		return "—"
	var n := int(code.get_slice(":", 1))
	if code.begins_with("mouse:"):
		return { MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "СКМ",
			MOUSE_BUTTON_XBUTTON1: "Мышь 4", MOUSE_BUTTON_XBUTTON2: "Мышь 5" }.get(n, "Мышь %d" % n)
	if code.begins_with("padaxis:"):
		return { JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT" }.get(n, "Ось %d" % n)
	if code.begins_with("pad:"):
		return { JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "Крест ↑",
			JOY_BUTTON_DPAD_DOWN: "Крест ↓", JOY_BUTTON_DPAD_LEFT: "Крест ←", JOY_BUTTON_DPAD_RIGHT: "Крест →" }.get(n, "Кнопка %d" % n)
	var names := { KEY_SPACE: "Пробел", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_ENTER: "Enter",
		KEY_TAB: "Tab", KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓", KEY_BACKSPACE: "Backspace" }
	return names.get(n, OS.get_keycode_string(n as Key))

## Code in slot `slot` of `device` for `action` ("" when empty or unknown).
func code_at(action: String, device: String, slot: int) -> String:
	var row: Dictionary = bindings.get(action, {})
	var arr: Array = row.get(device, [])
	return String(arr[slot]) if slot >= 0 and slot < arr.size() else ""

## First other place holding `code`: {action, slot} or {} (conflict detection).
func find_conflict(action: String, slot: int, code: String) -> Dictionary:
	var dev := device_of(code)
	if code == "" or dev == "":
		return {}
	for a: String in ACTIONS:
		var arr: Array = (bindings.get(a, {}) as Dictionary).get(dev, [])
		for i in arr.size():
			if String(arr[i]) == code and not (a == action and i == slot):
				return { "action": a, "slot": i }
	return {}

## Binds `code` to slot `slot` of `action` (its device follows from the code).
## On a conflict the two places swap: the other action gets this slot's old
## code (possibly empty). Returns {ok, reason, swapped: {action, slot, code}}.
## Refused: unknown action or code, a pad code in a keyboard slot (and back),
## a reserved menu key.
func bind(action: String, slot: int, code: String, device: String = "") -> Dictionary:
	var dev := device_of(code)
	if not bindings.has(action) or dev == "":
		return { "ok": false, "reason": "unknown" }
	if device != "" and device != dev:
		return { "ok": false, "reason": "device" }
	if code in RESERVED:
		return { "ok": false, "reason": "reserved" }
	if slot < 0 or slot >= int(SLOTS[dev]):
		return { "ok": false, "reason": "slot" }
	var old := code_at(action, dev, slot)
	var out := { "ok": true, "reason": "", "swapped": {} }
	var c := find_conflict(action, slot, code)
	if not c.is_empty():
		bindings[c.action][dev][c.slot] = old
		out.swapped = { "action": c.action, "slot": c.slot, "code": old }
	bindings[action][dev][slot] = code
	return out

## Empties one slot (the player may leave a second key unused).
func clear_slot(action: String, device: String, slot: int) -> void:
	if bindings.has(action) and slot >= 0 and slot < int(SLOTS.get(device, 0)):
		bindings[action][device][slot] = ""

## Actions without any keyboard / mouse binding (warned about on the screen).
func unbound_actions() -> Array[String]:
	var out: Array[String] = []
	for a in ACTIONS:
		if code_at(a, "kbm", 0) == "" and code_at(a, "kbm", 1) == "":
			out.append(a)
	return out

# ---------------- file ----------------

## Everything as a ConfigFile (also the in-memory form tests round-trip).
func to_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "format", FORMAT)
	for a: String in ACTIONS:
		cfg.set_value("input", a + ".kbm", PackedStringArray(bindings[a].kbm))
		cfg.set_value("input", a + ".pad", PackedStringArray(bindings[a].pad))
	for b in BUSES:
		cfg.set_value("audio", b, float(volumes.get(b, 1.0)))
	cfg.set_value("screen", "shake", shake)
	cfg.set_value("screen", "flash", flash)
	return cfg

## Reads a ConfigFile over the defaults: missing or malformed values keep the
## default, unknown codes are dropped, a newer format is ignored entirely.
func from_config(cfg: ConfigFile) -> void:
	reset_all()
	if int(cfg.get_value("meta", "format", FORMAT)) > FORMAT:
		push_warning("Settings: settings file is from a newer version, using defaults")
		return
	for a: String in ACTIONS:
		for dev: String in ["kbm", "pad"]:
			var v: Variant = cfg.get_value("input", a + "." + dev, null)
			if not (v is PackedStringArray or v is Array):
				continue
			var arr: Array = []
			for i in int(SLOTS[dev]):
				var code := String(v[i]) if i < v.size() else ""
				arr.append(code if code == "" or device_of(code) == dev else "")
			bindings[a][dev] = arr
	for b in BUSES:
		volumes[b] = clampf(float(cfg.get_value("audio", b, 1.0)), 0.0, 1.0)
	shake = bool(cfg.get_value("screen", "shake", true))
	flash = bool(cfg.get_value("screen", "flash", true))

## Loads `p`; a missing or broken file leaves the defaults. True when read.
func load_file(p: String) -> bool:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(p):
		reset_all()
		return false
	if cfg.load(p) != OK:
		push_warning("Settings: %s is broken, using defaults" % p)
		reset_all()
		return false
	from_config(cfg)
	return true

## Writes the settings to `path`. False on failure.
func save() -> bool:
	var err := to_config().save(path)
	if err != OK:
		push_error("Settings: cannot write %s (%s)" % [path, error_string(err)])
	return err == OK

# ---------------- applying ----------------

## Applies everything to the engine (InputMap, buses, toggles) and saves nothing.
func apply() -> void:
	apply_input()
	apply_audio()
	shake_on = shake
	flash_on = flash
	changed.emit()

## Replaces the key, mouse, pad-button and trigger events of every action; stick motions stay.
func apply_input() -> void:
	for a: String in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for ev in InputMap.action_get_events(a):
			var m := ev as InputEventJoypadMotion
			if m == null or m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT:
				InputMap.action_erase_event(a, ev)
		for dev: String in ["kbm", "pad"]:
			for code: Variant in bindings[a][dev]:
				var ev := event_of(String(code))
				if ev:
					InputMap.action_add_event(a, ev)

## Bus volume = audio.json level + linear_to_db(volume); 0 mutes the bus.
func apply_audio() -> void:
	var base: Dictionary = Tune.table("audio").get("buses", {})
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var v := float(volumes.get(b, 1.0))
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, float(base.get(b, 0.0)) + linear_to_db(maxf(v, 0.001)))

## Sets one action's slot, applies and saves (the screen's single entry point).
func rebind(action: String, slot: int, code: String, device: String = "") -> Dictionary:
	var r := bind(action, slot, code, device)
	if r.ok:
		apply()
		save()
	return r
