## Pause menu (design/ux/settings.md, first functional cut): Продолжить /
## Настройки / На заставу. Esc / pad Start opens it (World) and closes it;
## arrows / d-pad / stick move the focus, Enter / pad A press. Pauses the tree.
## «На заставу» asks first («Забег будет потерян. Угли сохранятся.», developer
## decision 2026-11-27), then ends the run with outcome "quit" (economy-and-meta
## §5.1, same as a death: the run's embers go to the bank); disabled outside a run.
## Placeholder look until the UI art pass. 1920x1080 layout (ADR-0004).
class_name PauseMenu
extends Control

## Emitted when the player leaves the run for the base.
signal quit_to_base
## Emitted when the menu closes (any way).
signal closed

## False in the base and in the legacy checks: the quit button is disabled.
var can_quit: bool = true
## The open settings screen (null when the buttons show).
var settings_screen: SettingsScreen
var _box: VBoxContainer
var _buttons: Array[Button] = []
## Opens the full level map (graph-mode levels, level-structure §3.6); invalid = no «Карта».
var on_map: Callable
## The «are you sure» panel of «На заставу» (null until asked).
var confirm_box: VBoxContainer

## Text of the quit confirmation.
const CONFIRM_TEXT: String = "Забег будет потерян. Угли сохранятся."

## True for the event that opens or closes the menu (Esc, pad Start).
static func is_open_event(ev: InputEvent) -> bool:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE)
	if ev is InputEventJoypadButton:
		var b := ev as InputEventJoypadButton
		return b.pressed and b.button_index == JOY_BUTTON_START
	return false

## Shared look of the functional menus: bigger default font, readable buttons.
static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 30
	return th

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	theme = make_theme()
	get_tree().paused = true
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.82)
	bg.size = size
	add_child(bg)
	var title := Label.new()
	title.text = "Пауза"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#f0e2c0"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 250)
	title.size = Vector2(1920, 90)
	add_child(title)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 18)
	_box.position = Vector2(760, 420)
	_box.custom_minimum_size = Vector2(400, 0)
	add_child(_box)
	_add("Продолжить", close)
	if on_map.is_valid():
		_add("Карта", func() -> void:
			close()
			on_map.call())
	_add("Настройки", open_settings)
	var q := _add("На заставу", ask_quit)
	q.disabled = not can_quit
	if not can_quit:
		q.tooltip_text = "Вы уже в заставе"
	var hint := Label.new()
	hint.text = "Esc / Start: вернуться в игру"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 760)
	hint.size = Vector2(1920, 40)
	add_child(hint)
	_buttons[0].grab_focus.call_deferred()

func _add(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 72)
	b.pressed.connect(cb)
	_box.add_child(b)
	_buttons.append(b)
	return b

func _unhandled_input(ev: InputEvent) -> void:
	if settings_screen == null and is_open_event(ev):
		get_viewport().set_input_as_handled()
		if confirm_box:
			cancel_quit()
		else:
			close()

## Shows the confirmation of «На заставу» (focus on «Остаться»).
func ask_quit() -> void:
	if not can_quit:
		return
	_box.visible = false
	confirm_box = VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 18)
	confirm_box.position = Vector2(660, 420)
	confirm_box.custom_minimum_size = Vector2(600, 0)
	var l := Label.new()
	l.text = CONFIRM_TEXT
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color("#e0c27a"))
	confirm_box.add_child(l)
	var yes := Button.new()
	yes.text = "Да, на заставу"
	yes.custom_minimum_size = Vector2(600, 72)
	yes.pressed.connect(_quit)
	confirm_box.add_child(yes)
	var no := Button.new()
	no.text = "Остаться"
	no.custom_minimum_size = Vector2(600, 72)
	no.pressed.connect(cancel_quit)
	confirm_box.add_child(no)
	add_child(confirm_box)
	no.grab_focus.call_deferred()

## Closes the confirmation, back to the buttons.
func cancel_quit() -> void:
	if confirm_box:
		confirm_box.queue_free()
		confirm_box = null
	_box.visible = true
	_buttons[2].grab_focus()

## Closes the menu and unpauses.
func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

## Shows the settings screen over the buttons; closing it returns here.
func open_settings() -> SettingsScreen:
	settings_screen = SettingsScreen.new()
	_box.visible = false
	settings_screen.closed.connect(func() -> void:
		settings_screen = null
		_box.visible = true
		_buttons[1].grab_focus())
	add_child(settings_screen)
	return settings_screen

func _quit() -> void:
	if not can_quit:
		return
	get_tree().paused = false
	quit_to_base.emit()
	closed.emit()
	queue_free()
