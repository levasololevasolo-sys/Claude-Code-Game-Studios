## A station menu of the base (Потап's armor, Сова's amulets, Капище Рода):
## a list of rows, the bank on top (economy-and-meta §3.6), the last row leaves.
## Rows come from `rows_fn` (re-read after every pick): {text, sub, enabled,
## note}. Up/down/left/right, d-pad, stick, number keys and the mouse move the
## highlight; Enter / E / pad A / B / a click picks (ChoiceInput, BUG-0002,
## BUG-0003); Esc leaves. Pauses the tree while open. 1920x1080 layout.
class_name ShopScreen
extends Control

## Emitted when the player leaves.
signal closed
## Emitted when the highlight moves to row `i` (armor try-on).
signal hovered(i: int)

const ROW_H: float = 92.0
const TOP: float = 250.0
const LEFT: float = 360.0
const WIDTH: float = 1200.0
const C_PANEL: Color = Color("#21170F", 0.92)
const C_RED: Color = Color("#B3262E")
const C_LINEN: Color = Color("#F2EAD8")
const C_DIM: Color = Color("#A99C86")
const C_GOLD: Color = Color("#FFC94A")

## Menu title, e.g. "Кузнец Потап — Доспех".
var title: String = ""
## () -> Array[Dictionary] of rows.
var rows_fn: Callable
## (i) -> void, called when row i is picked (not for the leave row).
var pick_fn: Callable
## () -> String, the bank line.
var bank_fn: Callable
var sel: int = 0
var input: ChoiceInput
var rows: Array = []
## Last result line ("Куплено", reason).
var status: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	get_tree().paused = true
	refresh()

func _process(dt: float) -> void:
	input.tick(dt)

## Re-reads the rows.
func refresh() -> void:
	rows = rows_fn.call() if rows_fn.is_valid() else []
	sel = clampi(sel, 0, rows.size())
	queue_redraw()

func _rects() -> Array:
	var out: Array = []
	for i in rows.size() + 1:
		out.append(Rect2(LEFT, TOP + i * ROW_H, WIDTH, ROW_H - 10.0))
	return out

func _move(d: int) -> void:
	sel = posmod(sel + d, rows.size() + 1)
	hovered.emit(sel)
	queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k and k.pressed and not k.echo:
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
			return
		if code == KEY_UP or code == KEY_W:
			_move(-1)
			return
		if code == KEY_DOWN or code == KEY_S:
			_move(1)
			return
	var b := ev as InputEventJoypadButton
	if b and b.pressed and (b.button_index == JOY_BUTTON_DPAD_UP or b.button_index == JOY_BUTTON_DPAD_DOWN):
		_move(-1 if b.button_index == JOY_BUTTON_DPAD_UP else 1)
		return
	var r := input.read(ev, rows.size() + 1)
	match r.act:
		ChoiceInput.Act.PREV:
			_move(-1)
		ChoiceInput.Act.NEXT:
			_move(1)
		ChoiceInput.Act.CONFIRM:
			get_viewport().set_input_as_handled()
			pick(sel)
		ChoiceInput.Act.PICK:
			get_viewport().set_input_as_handled()
			pick(int(r.i))

func _gui_input(ev: InputEvent) -> void:
	var r := input.read(ev, rows.size() + 1, _rects())
	if r.act == ChoiceInput.Act.HOVER and int(r.i) != sel:
		sel = int(r.i)
		hovered.emit(sel)
		queue_redraw()
	elif r.act == ChoiceInput.Act.PICK:
		accept_event()
		pick(int(r.i))

## Picks row `i` (the row after the last one leaves).
func pick(i: int) -> void:
	sel = i
	if i >= rows.size():
		close()
		return
	var row: Dictionary = rows[i]
	if not bool(row.get("enabled", true)):
		status = String(row.get("note", ""))
	else:
		status = ""
		if pick_fn.is_valid():
			pick_fn.call(i)
	refresh()

## Leaves the menu and unpauses.
func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.55))
	var h := TOP + (rows.size() + 1) * ROW_H + 40.0
	var panel := Rect2(LEFT - 40, 110, WIDTH + 80, h - 70)
	draw_rect(panel, C_PANEL)
	draw_rect(panel, C_RED, false, 4.0)
	draw_rect(panel.grow(-8), Color("#E9DFC9", 0.5), false, 1.5)
	draw_string(font, Vector2(LEFT, 170), title, HORIZONTAL_ALIGNMENT_LEFT, WIDTH, 44, C_GOLD)
	if bank_fn.is_valid():
		draw_string(font, Vector2(LEFT, 218), String(bank_fn.call()), HORIZONTAL_ALIGNMENT_LEFT, WIDTH, 26, C_DIM)
	var rects := _rects()
	for i in rows.size() + 1:
		var r: Rect2 = rects[i]
		var on := i == sel
		var row: Dictionary = rows[i] if i < rows.size() else { "text": "Уйти", "sub": "Esc", "enabled": true }
		var en := bool(row.get("enabled", true))
		if on:
			draw_rect(r, Color(1.0, 0.79, 0.29, 0.14))
			draw_rect(r, C_GOLD, false, 3.0)
		draw_string(font, r.position + Vector2(20, 38), String(row.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 40, 30, C_LINEN if en else C_DIM)
		var sub := String(row.get("sub", ""))
		if not en and String(row.get("note", "")) != "":
			sub += "   — " + String(row.note)
		draw_string(font, r.position + Vector2(20, 70), sub, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 40, 22, C_DIM if en else Color("#C2502A"))
	if status != "":
		draw_string(font, Vector2(LEFT, h + 20), status, HORIZONTAL_ALIGNMENT_LEFT, WIDTH, 26, Color("#C2502A"))
	draw_string(font, Vector2(0, 1040), "↑↓ / ←→ выбрать · Enter / E / A — взять · Esc — уйти", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, C_DIM)
