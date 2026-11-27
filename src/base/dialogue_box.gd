## The base dialogue box (living-world §1.1; art bible 4.6 panel colours): the
## speaker's name and one line. Enter / E / pad A / B or a click on the box
## closes it after the ChoiceInput lockout; J / Space never do (BUG-0003).
## With `options` (prologue-and-endings §7 choices) it shows buttons instead:
## ← → / d-pad / mouse pick one, confirm emits `picked` and closes.
## Pauses the tree while open (`pause` false: the scene behind keeps moving).
## 1920x1080 layout.
class_name DialogueBox
extends Control

## Emitted when the player closes the box.
signal closed
## Emitted with the chosen option index (boxes with options only), before closed.
signal picked(i: int)

const BOX: Rect2 = Rect2(Vector2(260, 730), Vector2(1400, 270))
const OPT: Vector2 = Vector2(360, 56)

## Speaker name and the line.
var speaker: String = ""
var text: String = ""
## Button labels of a choice; empty = a plain line.
var options: PackedStringArray = []
var selected: int = 0
## Pauses the tree while open.
var pause: bool = true
## Speaker name colour.
var speaker_colour: Color = Color("#FFC94A")
var input: ChoiceInput
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	if pause:
		get_tree().paused = true
	_label = Label.new()
	_label.position = BOX.position + Vector2(40, 90)
	_label.size = Vector2(BOX.size.x - 80, 130 if options.is_empty() else 80)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color("#F2EAD8"))
	_label.text = text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _process(dt: float) -> void:
	input.tick(dt)

func _unhandled_input(ev: InputEvent) -> void:
	var r := input.read(ev, maxi(options.size(), 1))
	match r.act:
		ChoiceInput.Act.CONFIRM:
			get_viewport().set_input_as_handled()
			confirm()
		ChoiceInput.Act.PREV, ChoiceInput.Act.NEXT:
			if not options.is_empty():
				selected = posmod(selected + (-1 if r.act == ChoiceInput.Act.PREV else 1), options.size())
				queue_redraw()
				get_viewport().set_input_as_handled()
		ChoiceInput.Act.PICK:
			if not options.is_empty() and int(r.i) >= 0:
				selected = int(r.i)
				get_viewport().set_input_as_handled()
				confirm()

func _gui_input(ev: InputEvent) -> void:
	var rects: Array = option_rects() if not options.is_empty() else [BOX]
	var r := input.read(ev, maxi(options.size(), 1), rects)
	if r.act == ChoiceInput.Act.PICK:
		accept_event()
		if not options.is_empty():
			selected = int(r.i)
		confirm()
	elif r.act == ChoiceInput.Act.HOVER and not options.is_empty() and int(r.i) != selected:
		selected = int(r.i)
		queue_redraw()

## Button rects of the options, screen px.
func option_rects() -> Array:
	var out: Array = []
	var total := options.size() * OPT.x + (options.size() - 1) * 40.0
	var x0 := BOX.position.x + (BOX.size.x - total) / 2.0
	for i in options.size():
		out.append(Rect2(Vector2(x0 + i * (OPT.x + 40.0), BOX.end.y - OPT.y - 44.0), OPT))
	return out

## Confirms: picks the selected option (if any) and closes.
func confirm() -> void:
	if not options.is_empty():
		picked.emit(selected)
	close()

## Closes the box and unpauses.
func close() -> void:
	if pause:
		get_tree().paused = false
	closed.emit()
	queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(BOX, Color("#21170F", 0.93))
	draw_rect(BOX, Color("#B3262E"), false, 4.0)
	draw_rect(BOX.grow(-8), Color("#E9DFC9", 0.5), false, 1.5)
	draw_string(font, BOX.position + Vector2(40, 62), speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, speaker_colour)
	if options.is_empty():
		draw_string(font, BOX.position + Vector2(0, BOX.size.y - 22), "Enter / E / A — дальше", HORIZONTAL_ALIGNMENT_RIGHT, BOX.size.x - 40, 22, Color("#A99C86"))
		return
	var rects := option_rects()
	for i in options.size():
		var r: Rect2 = rects[i]
		var on := i == selected
		draw_rect(r, Color("#3A2616") if on else Color("#21170F"))
		draw_rect(r, Color("#FFC94A") if on else Color("#A99C86", 0.6), false, 3.0 if on else 1.5)
		draw_string(font, r.position + Vector2(0, 38), options[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color("#F2EAD8"))
	draw_string(font, BOX.position + Vector2(0, BOX.size.y - 14), "← → выбрать · Enter / E / A — решить", HORIZONTAL_ALIGNMENT_RIGHT, BOX.size.x - 40, 20, Color("#A99C86"))
