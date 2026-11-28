## Main menu (design/ux/main-menu.md): the first screen of a normal launch.
## «Продолжить» (when a slot has a save; focused by default, loads the last
## slot), «Новая игра» (pick one of 5 slots, overwriting asks first),
## «Настройки», «Выйти». The slot list shows runs, embers and difficulty, and
## Delete / pad Y on a slot erases it after a confirmation. Emits `start` with
## the slot and whether it is a new game; World then runs the usual flow
## (difficulty choice and prologue on a new save, then the base «Застава»).
## Placeholder look until the art pass. 1920x1080 layout (ADR-0004).
class_name MainMenu
extends Control

## The player picked slot `slot` (1..Game.SLOTS); `new_game` wipes it first.
signal start(slot: int, new_game: bool)

## Slot facts, injectable for tests: Callable(i) -> Dictionary ({} = empty).
var summary_of: Callable = SaveSlots.slot_summary
## Last used slot (0 = none), injectable for tests.
var last: int = -1
var _box: VBoxContainer
var _title: Label
var _hint: Label
var _page: String = "main"
var _mode: String = ""
var _confirm_slot: int = 0
var settings_screen: SettingsScreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	theme = PauseMenu.make_theme()
	if last < 0:
		last = SaveSlots.last_slot()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 1.0)
	bg.size = size
	add_child(bg)
	var logo := Label.new()
	logo.text = "Н А В Ь"
	logo.add_theme_font_size_override("font_size", 140)
	logo.add_theme_color_override("font_color", Color("#e0c27a"))
	logo.position = Vector2(160, 150)
	add_child(logo)
	var sub := Label.new()
	sub.text = "сказ о павшем богатыре"
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	sub.position = Vector2(170, 330)
	add_child(sub)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color("#f0e2c0"))
	_title.position = Vector2(160, 430)
	add_child(_title)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.position = Vector2(160, 500)
	_box.custom_minimum_size = Vector2(760, 0)
	add_child(_box)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	_hint.position = Vector2(160, 1000)
	add_child(_hint)
	show_main()

## True when any slot holds a save.
func any_save() -> bool:
	for i in range(1, SaveSlots.SLOTS + 1):
		if not (summary_of.call(i) as Dictionary).is_empty():
			return true
	return false

## Slot to continue: the last used one if it has a save, else the first with one (0 = none).
func continue_slot() -> int:
	if last >= 1 and not (summary_of.call(last) as Dictionary).is_empty():
		return last
	for i in range(1, SaveSlots.SLOTS + 1):
		if not (summary_of.call(i) as Dictionary).is_empty():
			return i
	return 0

## One line about a slot: «Слот 2 · 12 забегов · угли 340 · Былина» or «Слот 2 · Пусто».
static func slot_line(i: int, s: Dictionary) -> String:
	if s.is_empty():
		return "Слот %d · Пусто" % i
	var diff := String(s.get("difficulty", ""))
	var levels: Dictionary = Difficulty.table().get("levels", {})
	var dname := String((levels.get(diff, {}) as Dictionary).get("name", "")) if diff != "" else ""
	var parts := PackedStringArray(["Слот %d" % i, "забегов %d" % int(s.get("runs", 0)), "угли %d" % int(s.get("embers", 0))])
	if dname != "":
		parts.append(dname)
	return " · ".join(parts)

func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()

func _add(text: String, cb: Callable, small: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(760 if small else 480, 64)
	b.pressed.connect(func() -> void:
		_sound(&"ui_confirm")
		cb.call())
	b.focus_entered.connect(_sound.bind(&"ui_move"))
	_box.add_child(b)
	return b

func _sound(id: StringName) -> void:
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("play"):
		au.call("play", id)

## The first page: Продолжить / Новая игра / Настройки / Выйти.
func show_main() -> void:
	_page = "main"
	_clear()
	_title.text = ""
	var cs := continue_slot()
	var first: Button = null
	if cs > 0:
		first = _add("Продолжить", func() -> void: _go(cs, false))
		first.tooltip_text = slot_line(cs, summary_of.call(cs))
		var info := Label.new()
		info.text = "   " + slot_line(cs, summary_of.call(cs))
		info.add_theme_font_size_override("font_size", 20)
		info.add_theme_color_override("font_color", Color(0.65, 0.63, 0.56))
		_box.add_child(info)
	var ng := _add("Новая игра", func() -> void: show_slots("new"))
	if any_save():
		_add("Загрузить", func() -> void: show_slots("load"))
	_add("Настройки", open_settings)
	_add("Выйти", func() -> void: get_tree().quit())
	_hint.text = "↑ ↓ / мышь / крестовина · Enter / A — выбрать"
	_focus.call_deferred(first if first else ng)

## The slot list: `mode` "new" (any slot; a full one asks to overwrite) or "load" (full slots).
func show_slots(mode: String) -> void:
	_page = "slots"
	_mode = mode
	_clear()
	_title.text = "Новая игра: выбери слот" if mode == "new" else "Загрузить: выбери слот"
	var first: Button = null
	for i in range(1, SaveSlots.SLOTS + 1):
		var s: Dictionary = summary_of.call(i)
		var b := _add(slot_line(i, s), _pick.bind(i), true)
		b.set_meta("slot", i)
		if mode == "load" and s.is_empty():
			b.disabled = true
		elif first == null:
			first = b
	_hint.text = "Enter / A — выбрать · Delete / Y — удалить слот · Esc / B — назад"
	if first:
		_focus.call_deferred(first)

func _pick(i: int) -> void:
	var full := not (summary_of.call(i) as Dictionary).is_empty()
	if _mode == "new" and full:
		_ask("Перезаписать слот %d? Прогресс в нём пропадёт." % i, "Перезаписать", func() -> void: _go(i, true))
	else:
		_go(i, _mode == "new")

## A yes / no question on the page.
func _ask(question: String, yes: String, cb: Callable) -> void:
	_page = "confirm"
	_clear()
	_title.text = question
	_add(yes, cb)
	var no := _add("Отмена", func() -> void: show_slots(_mode))
	_focus.call_deferred(no)
	_hint.text = "Esc / B — отмена"

func _focus(b: Button) -> void:
	if is_instance_valid(b) and b.is_inside_tree():
		b.grab_focus()

func _go(slot: int, new_game: bool) -> void:
	start.emit(slot, new_game)
	queue_free()

## Settings over the menu; closing returns here.
func open_settings() -> SettingsScreen:
	settings_screen = SettingsScreen.new()
	_box.visible = false
	settings_screen.closed.connect(func() -> void:
		settings_screen = null
		_box.visible = true
		show_main())
	add_child(settings_screen)
	return settings_screen

func _unhandled_input(ev: InputEvent) -> void:
	if settings_screen != null:
		return
	var back := (ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_ESCAPE) \
		or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	var del := (ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_DELETE) \
		or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).pressed and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_Y)
	if back and _page != "main":
		get_viewport().set_input_as_handled()
		_sound(&"ui_close")
		if _page == "confirm":
			show_slots(_mode)
		else:
			show_main()
	elif del and _page == "slots":
		var f := get_viewport().gui_get_focus_owner()
		if f and f.has_meta("slot") and not (summary_of.call(int(f.get_meta("slot"))) as Dictionary).is_empty():
			get_viewport().set_input_as_handled()
			var i := int(f.get_meta("slot"))
			_ask("Удалить слот %d навсегда?" % i, "Удалить", func() -> void:
				SaveSlots.delete_slot(i)
				show_slots(_mode))
