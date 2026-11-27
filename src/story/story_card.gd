## A centred story card on black (prologue-and-endings §1.16-1.17, §2.14): a
## big line and a small one under it. Closes after `time` s or on confirm
## (Enter / E / pad A / click, after the ChoiceInput lockout). Pauses the tree.
class_name StoryCard
extends Control

## Emitted when the card closes.
signal closed

var text: String = ""
var sub: String = ""
var time: float = 3.0
var input: ChoiceInput
var _t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	get_tree().paused = true

func _process(dt: float) -> void:
	input.tick(dt)
	_t += dt
	queue_redraw()
	if _t >= time:
		close()

func _unhandled_input(ev: InputEvent) -> void:
	if input.read(ev, 1).act == ChoiceInput.Act.CONFIRM:
		get_viewport().set_input_as_handled()
		close()

func _gui_input(ev: InputEvent) -> void:
	if input.read(ev, 1, [Rect2(Vector2.ZERO, size)]).act == ChoiceInput.Act.PICK:
		accept_event()
		close()

## Closes the card and unpauses.
func close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	closed.emit()
	queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var a := clampf(minf(_t, time - _t) * 2.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#05070A"))
	var big := 120 if text.length() <= 8 else 52
	draw_string(font, Vector2(0, 520), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, big, Color(0.93, 0.9, 0.84, a))
	if sub != "":
		draw_string(font, Vector2(0, 620), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color(0.75, 0.72, 0.66, a))
