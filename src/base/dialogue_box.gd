## The base dialogue box (living-world §1.1; art bible 4.6 panel colours): the
## speaker's name and one line. Enter / E / pad A / B or a click on the box
## closes it after the ChoiceInput lockout; J / Space never do (BUG-0003).
## Pauses the tree while open. 1920x1080 layout.
class_name DialogueBox
extends Control

## Emitted when the player closes the box.
signal closed

const BOX: Rect2 = Rect2(Vector2(260, 730), Vector2(1400, 270))

## Speaker name and the line.
var speaker: String = ""
var text: String = ""
var input: ChoiceInput
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	get_tree().paused = true
	_label = Label.new()
	_label.position = BOX.position + Vector2(40, 90)
	_label.size = Vector2(BOX.size.x - 80, 130)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color("#F2EAD8"))
	_label.text = text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _process(dt: float) -> void:
	input.tick(dt)

func _unhandled_input(ev: InputEvent) -> void:
	if input.read(ev, 1).act == ChoiceInput.Act.CONFIRM:
		get_viewport().set_input_as_handled()
		close()

func _gui_input(ev: InputEvent) -> void:
	if input.read(ev, 1, [BOX]).act == ChoiceInput.Act.PICK:
		accept_event()
		close()

## Closes the box and unpauses.
func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(BOX, Color("#21170F", 0.93))
	draw_rect(BOX, Color("#B3262E"), false, 4.0)
	draw_rect(BOX.grow(-8), Color("#E9DFC9", 0.5), false, 1.5)
	draw_string(font, BOX.position + Vector2(40, 62), speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#FFC94A"))
	draw_string(font, BOX.position + Vector2(0, BOX.size.y - 22), "Enter / E / A — дальше", HORIZONTAL_ALIGNMENT_RIGHT, BOX.size.x - 40, 22, Color("#A99C86"))
