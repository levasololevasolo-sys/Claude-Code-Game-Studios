## The Prophet's screen (gods-expansion §3.13): a grid of god cards. Each card
## shows the god's sign, name, word and tip, lit when the god is called and
## dimmed and struck when sent away. Picking a card switches it
## (ProphetRules.toggle); at least gods_min_on stay called. Arrows, d-pad,
## stick and the mouse move; Enter / E / pad A / a click picks; Esc or the
## last card («Уйти») leaves. Pauses the tree while open. 1920x1080 layout.
class_name ProphetScreen
extends Control

## Emitted when the player leaves.
signal closed
## Emitted after a god was switched.
signal changed

const COLS: int = 4
const CARD: Vector2 = Vector2(380, 196)
const GAP: Vector2 = Vector2(24, 20)
const TOP: float = 250.0
const C_PANEL: Color = Color("#17121C", 0.94)
const C_VIOLET: Color = Color("#5A4A8A")
const C_LINEN: Color = Color("#F2EAD8")
const C_DIM: Color = Color("#A99C86")
const C_GOLD: Color = Color("#FFC94A")
const C_RED: Color = Color("#C2502A")

## Read-only view of the save (who is called); the screen never writes it.
var meta: MetaState
## (god) -> bool: asks the owner to switch `god` (Base calls ProphetRules.toggle).
var toggle_fn: Callable
var tbl: Dictionary = {}
var min_on: int = 4
var ids: Array[String] = []
var sel: int = 0
var input: ChoiceInput
## Last refusal line, "" when none.
var status: String = ""
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if tbl.is_empty():
		tbl = Tune.table("gods")
	ids = ProphetRules.gods(meta, tbl)
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	get_tree().paused = true
	queue_redraw()

func _process(dt: float) -> void:
	input.tick(dt)
	_t += dt
	queue_redraw()

func _left() -> float:
	return (size.x - (COLS * CARD.x + (COLS - 1) * GAP.x)) * 0.5

## Card rects; the last one is the leave button.
func _rects() -> Array:
	var out: Array = []
	var l := _left()
	for i in ids.size():
		out.append(Rect2(Vector2(l + (i % COLS) * (CARD.x + GAP.x), TOP + floorf(float(i) / COLS) * (CARD.y + GAP.y)), CARD))
	var rows := ceili(float(ids.size()) / COLS)
	out.append(Rect2(Vector2(size.x * 0.5 - 160, TOP + rows * (CARD.y + GAP.y) + 6), Vector2(320, 64)))
	return out

func _move(d: int) -> void:
	sel = clampi(sel + d, 0, ids.size())
	queue_redraw()

## Moves a row up (-1) or down (1); below the last row is the leave button.
func _vert(d: int) -> void:
	if d > 0:
		sel = sel + COLS if sel + COLS < ids.size() else ids.size()
	elif sel >= ids.size():
		sel = maxi(ids.size() - 1, 0)
	else:
		sel = maxi(sel - COLS, sel % COLS)
	queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k and k.pressed and not k.echo:
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		match code:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				close()
				return
			KEY_UP, KEY_W:
				_vert(-1)
				return
			KEY_DOWN, KEY_S:
				_vert(1)
				return
	var b := ev as InputEventJoypadButton
	if b and b.pressed:
		if b.button_index == JOY_BUTTON_DPAD_UP or b.button_index == JOY_BUTTON_DPAD_DOWN:
			_vert(-1 if b.button_index == JOY_BUTTON_DPAD_UP else 1)
			return
		if b.button_index == JOY_BUTTON_B:
			close()
			return
	var r := input.read(ev, 0)
	match r.act:
		ChoiceInput.Act.PREV:
			_move(-1)
		ChoiceInput.Act.NEXT:
			_move(1)
		ChoiceInput.Act.CONFIRM:
			get_viewport().set_input_as_handled()
			pick(sel)

func _gui_input(ev: InputEvent) -> void:
	var r := input.read(ev, ids.size() + 1, _rects())
	if r.act == ChoiceInput.Act.HOVER and int(r.i) != sel:
		sel = int(r.i)
		queue_redraw()
	elif r.act == ChoiceInput.Act.PICK:
		accept_event()
		pick(int(r.i))

## Picks card `i`: switches that god, or leaves for the last card.
func pick(i: int) -> void:
	sel = i
	if i >= ids.size():
		close()
		return
	var why := ProphetRules.block(meta, tbl, ids[i], min_on)
	if why != "":
		status = why
		Audio.play(&"ui_error_clank")
	else:
		status = ""
		if toggle_fn.is_valid() and bool(toggle_fn.call(ids[i])):
			Audio.play(&"ui_forge_buy")
			changed.emit()
	queue_redraw()

## Leaves and unpauses.
func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05, 0.62))
	var rects := _rects()
	var last: Rect2 = rects[rects.size() - 1]
	var panel := Rect2(_left() - 40, 100, size.x - 2.0 * (_left() - 40), last.end.y + 70 - 100)
	draw_rect(panel, C_PANEL)
	draw_rect(panel, C_VIOLET, false, 4.0)
	draw_rect(panel.grow(-8), Color("#E9DFC9", 0.4), false, 1.5)
	draw_string(font, Vector2(panel.position.x + 40, 160), "Пророк — кого звать в забег", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, C_GOLD)
	var on := ProphetRules.on_count(meta, tbl)
	draw_string(font, Vector2(panel.position.x + 40, 206),
		"Призваны: %d из %d  ·  не меньше %d. Изгнанный бог не встретится в забеге." % [on, ids.size(), min_on],
		HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 80, 24, C_DIM)
	for i in ids.size():
		_card(font, rects[i], ids[i], i == sel)
	var hot := sel >= ids.size()
	draw_rect(last, Color(1.0, 0.79, 0.29, 0.14) if hot else Color("#2A2030"))
	draw_rect(last, C_GOLD if hot else C_DIM, false, 3.0 if hot else 1.5)
	draw_string(font, last.position + Vector2(0, 42), "Уйти", HORIZONTAL_ALIGNMENT_CENTER, last.size.x, 30, C_LINEN)
	if status != "":
		draw_string(font, Vector2(0, panel.end.y + 40), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, C_RED)
	draw_string(font, Vector2(0, 1050), "Стрелки — выбрать · Enter / E / A — призвать или изгнать · Esc — уйти", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, C_DIM)

func _card(font: Font, r: Rect2, g: String, hot: bool) -> void:
	var row: Dictionary = tbl.get(g, {})
	var col := Color(String(row.get("colour", "#E9DFC9")))
	var lit := ProphetRules.is_on(meta, g)
	var a := 1.0 if lit else 0.38
	draw_rect(r, Color(col.r * 0.16, col.g * 0.14, col.b * 0.18, 0.95) if lit else Color("#141016"))
	if lit:
		var pulse := 0.5 + 0.5 * sin(_t * 2.2 + float(r.position.x) * 0.01)
		draw_rect(r.grow(-3), Color(col, 0.18 + 0.12 * pulse), false, 2.0)
	draw_rect(r, C_GOLD if hot else Color(col, 0.6 * a + 0.2), false, 3.0 if hot else 1.5)
	var c := r.position + Vector2(74, r.size.y * 0.5 - 6)
	GodGlyph.draw(self, g, c, 48.0, Color(col, a))
	var tx := r.position.x + 140
	var tw := r.size.x - 150
	draw_string(font, Vector2(tx, r.position.y + 46), String(row.get("name", g)), HORIZONTAL_ALIGNMENT_LEFT, tw, 32, Color(C_LINEN, a))
	draw_string(font, Vector2(tx, r.position.y + 76), String(row.get("word", "")), HORIZONTAL_ALIGNMENT_LEFT, tw, 20, Color(col, a))
	var tip := String(row.get("tip", ""))
	var lines := _wrap(font, tip, tw, 18)
	for k in mini(lines.size(), 3):
		draw_string(font, Vector2(tx, r.position.y + 106 + k * 22), lines[k], HORIZONTAL_ALIGNMENT_LEFT, tw, 18, Color(C_DIM, a))
	var state := "призван" if lit else "изгнан"
	draw_string(font, Vector2(r.position.x, r.end.y - 14), state, HORIZONTAL_ALIGNMENT_CENTER, 148, 20, C_GOLD if lit else C_RED)
	if not lit:
		draw_line(c + Vector2(-40, -40), c + Vector2(40, 40), Color(C_RED, 0.8), 4.0)

## Splits `text` into lines no wider than `w` at font size `fs`.
static func _wrap(font: Font, text: String, w: float, fs: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	for word in text.split(" ", false):
		var t := word if cur == "" else cur + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out
