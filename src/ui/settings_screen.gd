## Settings screen (design/ux/settings.md, first functional cut): tabs
## Управление (rebinding, two keyboard / mouse slots and one pad slot per
## action, swap on conflict, reset), Звук (bus volumes), Экран (shake and flash
## toggles), Сложность (GDD difficulty §3.3). Every change is applied and saved
## at once (Settings autoload; difficulty through the Game autoload). Esc / pad B
## closes it (or cancels a capture); LB / RB or Q / R switch tabs.
## Placeholder look until the UI art pass. 1920x1080 layout (ADR-0004).
class_name SettingsScreen
extends Control

## Emitted when the screen closes.
signal closed

const TABS: Array[String] = ["Управление", "Звук", "Экран", "Сложность"]

## The settings model (the Settings autoload by default; tests may inject one).
var settings: GameSettings
## The Game autoload (difficulty); null hides nothing, the tab just does nothing.
var game: Node
var tabs: TabContainer
## Capture in progress: {action, device, slot} or {} (waiting for a key).
var capture: Dictionary = {}
## Last message under the controls (swap, refusal, unbound warning).
var status: Label
var _slot_buttons: Dictionary = {}
var _diff_buttons: Dictionary = {}
var _diff_desc: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	theme = PauseMenu.make_theme()
	if settings == null:
		settings = get_node_or_null("/root/Settings") as GameSettings
	if game == null:
		game = get_node_or_null("/root/Game")
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.05, 0.96)
	bg.size = size
	add_child(bg)
	var title := Label.new()
	title.text = "Настройки"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("#f0e2c0"))
	title.position = Vector2(160, 60)
	add_child(title)
	tabs = TabContainer.new()
	tabs.position = Vector2(160, 150)
	tabs.size = Vector2(1600, 780)
	add_child(tabs)
	tabs.add_child(_controls_tab())
	tabs.add_child(_sound_tab())
	tabs.add_child(_screen_tab())
	tabs.add_child(_difficulty_tab())
	for i in TABS.size():
		tabs.set_tab_title(i, TABS[i])
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(260, 64)
	back.position = Vector2(1500, 960)
	back.pressed.connect(close)
	add_child(back)
	var hint := Label.new()
	hint.text = "LB / RB или Q / R: вкладки · Esc / B: назад"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	hint.position = Vector2(160, 975)
	add_child(hint)
	refresh()
	(_slot_buttons.get("move_left:kbm:0") as Button).grab_focus.call_deferred()

# ---------------- tabs ----------------

func _controls_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "controls"
	v.add_theme_constant_override("separation", 10)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for h: String in ["Действие", "Клавиша", "Вторая", "Геймпад"]:
		var l := Label.new()
		l.text = h
		l.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
		grid.add_child(l)
	for a: String in GameSettings.ACTIONS:
		var l := Label.new()
		l.text = String(GameSettings.LABELS[a])
		l.custom_minimum_size = Vector2(420, 0)
		grid.add_child(l)
		for spec: Array in [["kbm", 0], ["kbm", 1], ["pad", 0]]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(300, 50)
			b.pressed.connect(begin_capture.bind(a, String(spec[0]), int(spec[1])))
			grid.add_child(b)
			_slot_buttons["%s:%s:%d" % [a, spec[0], spec[1]]] = b
	v.add_child(grid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var reset := Button.new()
	reset.text = "Сбросить управление"
	reset.pressed.connect(reset_controls)
	row.add_child(reset)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("#e0c27a"))
	row.add_child(status)
	v.add_child(row)
	return v

func _sound_tab() -> Control:
	var grid := GridContainer.new()
	grid.name = "sound"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 30)
	for b: String in GameSettings.BUSES:
		var l := Label.new()
		l.text = String(GameSettings.BUS_LABELS[b])
		l.custom_minimum_size = Vector2(380, 0)
		grid.add_child(l)
		var s := HSlider.new()
		s.name = b
		s.min_value = 0
		s.max_value = 100
		s.step = 5
		s.custom_minimum_size = Vector2(700, 40)
		s.value = roundf(float(settings.volumes.get(b, 1.0)) * 100.0) if settings else 100.0
		var pct := Label.new()
		pct.text = "%d%%" % int(s.value)
		s.value_changed.connect(func(val: float) -> void:
			pct.text = "%d%%" % int(val)
			set_volume(b, val / 100.0))
		grid.add_child(s)
		grid.add_child(pct)
	return grid

func _screen_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "screen"
	v.add_theme_constant_override("separation", 24)
	for spec: Array in [["shake", "Тряска экрана"], ["flash", "Яркие вспышки (выкл.: приглушены)"]]:
		var c := CheckButton.new()
		c.name = String(spec[0])
		c.text = String(spec[1])
		c.button_pressed = bool(settings.get(spec[0])) if settings else true
		c.toggled.connect(func(on: bool) -> void: set_toggle(String(spec[0]), on))
		v.add_child(c)
	# «Частицы: много / мало / выкл» (vfx-spec §5); ambient air changes from the next room.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var lab := Label.new()
	lab.text = "Частицы"
	row.add_child(lab)
	var ob := OptionButton.new()
	ob.name = "particles"
	for lv: int in [VfxRules.LEVEL_HIGH, VfxRules.LEVEL_LOW, VfxRules.LEVEL_OFF]:
		ob.add_item(VfxRules.LEVEL_NAMES[lv], lv)
	ob.select(ob.get_item_index(int(settings.particles) if settings else VfxRules.LEVEL_HIGH))
	ob.item_selected.connect(func(i: int) -> void: set_particles(ob.get_item_id(i)))
	row.add_child(ob)
	v.add_child(row)
	return v

func _difficulty_tab() -> Control:
	var v := VBoxContainer.new()
	v.name = "difficulty"
	v.add_theme_constant_override("separation", 20)
	var t := Difficulty.table()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var group := ButtonGroup.new()
	for id in Difficulty.order(t):
		var b := Button.new()
		b.text = Difficulty.name_of(id, t)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(320, 80)
		b.pressed.connect(set_difficulty.bind(id))
		row.add_child(b)
		_diff_buttons[id] = b
	v.add_child(row)
	_diff_desc = Label.new()
	_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc.custom_minimum_size = Vector2(1400, 0)
	v.add_child(_diff_desc)
	var note := Label.new()
	note.text = "Сменить можно в любой момент. Враги, что уже в комнате, сохраняют своё здоровье. Пепел после победы действует поверх сложности."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(1400, 0)
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	v.add_child(note)
	return v

# ---------------- actions ----------------

## Waits for the next key / mouse button (keyboard slots) or pad button.
func begin_capture(action: String, device: String, slot: int) -> void:
	capture = { "action": action, "device": device, "slot": slot }
	(_slot_buttons["%s:%s:%d" % [action, device, slot]] as Button).text = "Нажмите…"
	status.text = "«%s»: нажмите %s (Esc: отмена)" % [GameSettings.LABELS[action], "клавишу или кнопку мыши" if device == "kbm" else "кнопку геймпада"]

## Feeds one event to a running capture; true when it was used.
func feed_capture(ev: InputEvent) -> bool:
	if capture.is_empty():
		return false
	var pressed := (ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo) \
		or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) \
		or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed) \
		or GameSettings.is_trigger_press(ev)
	if not pressed:
		return false
	if PauseMenu.is_open_event(ev) or (ev is InputEventJoypadButton and capture.device == "kbm" and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		capture = {}
		status.text = "Отменено"
		refresh()
		return true
	var code := GameSettings.code_of(ev)
	if GameSettings.device_of(code) != capture.device:
		status.text = "Это не %s" % ("клавиатура или мышь" if capture.device == "kbm" else "геймпад")
		return true
	var c := capture
	capture = {}
	var r := settings.rebind(c.action, c.slot, code, c.device)
	if not r.ok:
		status.text = "Эта кнопка занята меню" if r.reason == "reserved" else "Не получилось назначить"
	elif not (r.swapped as Dictionary).is_empty():
		var sw: Dictionary = r.swapped
		status.text = "«%s» было у «%s» — теперь у него «%s»" % [GameSettings.label_of(code), GameSettings.LABELS[sw.action], GameSettings.label_of(String(sw.code))]
	else:
		status.text = "«%s»: %s" % [GameSettings.LABELS[c.action], GameSettings.label_of(code)]
	refresh()
	return true

## Back to the default keys.
func reset_controls() -> void:
	settings.reset_controls()
	settings.apply()
	settings.save()
	status.text = "Управление сброшено"
	refresh()

## Sets a bus volume (0..1), applies and saves.
func set_volume(bus: String, v: float) -> void:
	if settings:
		settings.volumes[bus] = clampf(v, 0.0, 1.0)
		settings.apply_audio()
		settings.save()

## Sets "shake" or "flash", applies and saves.
func set_toggle(key: String, on: bool) -> void:
	if settings:
		settings.set(key, on)
		settings.apply()
		settings.save()

## Sets the «Частицы» level (0..2), applies and saves.
func set_particles(lv: int) -> void:
	if settings:
		settings.particles = VfxRules.clamp_level(lv)
		settings.apply()
		settings.save()

## Sets the difficulty through the Game autoload (meta save).
func set_difficulty(id: String) -> void:
	if game and game.has_method("set_difficulty"):
		game.call("set_difficulty", id)
	else:
		Difficulty.current = id
	refresh()

## Redraws button texts from the model.
func refresh() -> void:
	if settings:
		for key: String in _slot_buttons:
			var p := key.split(":")
			(_slot_buttons[key] as Button).text = GameSettings.label_of(settings.code_at(p[0], p[1], int(p[2])))
		var un := settings.unbound_actions()
		if not un.is_empty() and status.text == "":
			status.text = "Без клавиши: " + ", ".join(un.map(func(a: String) -> String: return String(GameSettings.LABELS[a])))
	var t := Difficulty.table()
	for id: String in _diff_buttons:
		var b := _diff_buttons[id] as Button
		b.set_pressed_no_signal(id == Difficulty.current)
		b.text = ("● " if id == Difficulty.current else "") + Difficulty.name_of(id, t)
	if _diff_desc:
		var lv: Dictionary = (t.get("levels", {}) as Dictionary).get(Difficulty.current, {})
		_diff_desc.text = "Сейчас: %s. %s\n%s" % [Difficulty.name_of(Difficulty.current, t), String(lv.get("desc", "")),
			" · ".join(DifficultyChoiceScreen.stat_lines(Difficulty.current, t))]

## Switches to tab `i` (clamped).
func show_tab(i: int) -> void:
	tabs.current_tab = clampi(i, 0, TABS.size() - 1)

## Closes the screen.
func close() -> void:
	closed.emit()
	queue_free()

func _input(ev: InputEvent) -> void:
	# Capture runs before the GUI so the pressed key never also moves the focus.
	if feed_capture(ev):
		get_viewport().set_input_as_handled()

func _unhandled_input(ev: InputEvent) -> void:
	var back := PauseMenu.is_open_event(ev) or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	if back:
		get_viewport().set_input_as_handled()
		close()
		return
	var k := ev as InputEventKey
	var jb := ev as InputEventJoypadButton
	var step := 0
	if k and k.pressed and not k.echo:
		step = -1 if k.keycode == KEY_Q else (1 if k.keycode == KEY_R else 0)
	elif jb and jb.pressed:
		step = -1 if jb.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if jb.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
	if step != 0:
		show_tab(posmod(tabs.current_tab + step, TABS.size()))
		get_viewport().set_input_as_handled()
