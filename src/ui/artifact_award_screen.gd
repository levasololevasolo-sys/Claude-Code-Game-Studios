## The first-clear award (GDD artifacts-and-secrets): after the first full clear
## every artifact arrives at once; this screen lays them out in a grid (sign,
## name, what it opens) with one line about the seals and the bosses growing
## stronger with every clear. Enter / E / pad A / a click closes it (ChoiceInput
## lockout). Also the artifacts page of the base (`title` changes). 1920x1080.
class_name ArtifactAwardScreen
extends Control

signal closed

const BUTTON: Rect2 = Rect2(Vector2(710, 980), Vector2(500, 56))
const COLS: int = 4

## Artifact rows to show (artifacts.json rows).
var rows: Array = []
var title: String = "Наследие богатыря"
var subtitle: String = "Ты прошёл Навь до конца. Отныне эти вещи с тобой в каждом забеге, и смерть их не отнимет."
var foot: String = "Печати в локациях теперь откроются. А хозяева Нави запомнили тебя: с каждым новым прохождением у них появляются новые приёмы."
var input: ChoiceInput
var hover: bool = false
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

func _unhandled_input(ev: InputEvent) -> void:
	if input.read(ev, 1).act == ChoiceInput.Act.CONFIRM:
		get_viewport().set_input_as_handled()
		close()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		hover = BUTTON.has_point((ev as InputEventMouseMotion).position)
	if input.read(ev, 1, [BUTTON]).act == ChoiceInput.Act.PICK:
		accept_event()
		close()

func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

## Card rect of item `i` (grid of COLS, centred).
func card(i: int) -> Rect2:
	var n := rows.size()
	var rows_n := int(ceil(float(n) / COLS))
	var cw := 410.0
	var ch := 196.0
	var gap := 20.0
	var row := i / COLS
	var in_row := mini(COLS, n - row * COLS)
	var x0 := (1920.0 - (in_row * cw + (in_row - 1) * gap)) / 2.0
	var y0 := 250.0 + (680.0 - (rows_n * ch + (rows_n - 1) * gap)) / 2.0
	return Rect2(x0 + (i % COLS) * (cw + gap), y0 + row * (ch + gap), cw, ch)

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.94))
	draw_string(font, Vector2(0, 120), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#e8c48a"))
	draw_string(font, Vector2(0, 180), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.78, 0.76, 0.7))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var rc := card(i)
		var c := Color(String(r.get("color", "#e8c48a")))
		var k := clampf(_t * 3.0 - i * 0.25, 0.0, 1.0)
		draw_rect(rc, Color(0.08, 0.07, 0.06, 0.9 * k))
		draw_rect(rc, Color(c, 0.6 * k), false, 2.0)
		ArtifactIcon.draw_icon(self, String(r.get("icon", "rhombus")), rc.position + Vector2(64, 70), 40.0, Color(c, k), _t)
		draw_string(font, rc.position + Vector2(124, 46), String(r.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, rc.size.x - 136, 24, Color(1, 0.94, 0.8, k))
		var desc := String(r.get("desc", ""))
		draw_multiline_string(font, rc.position + Vector2(124, 78), desc, HORIZONTAL_ALIGNMENT_LEFT, rc.size.x - 136, 17, 5, Color(0.8, 0.78, 0.72, k))
	draw_multiline_string(font, Vector2(260, 935), foot, HORIZONTAL_ALIGNMENT_CENTER, 1400, 20, 2, Color(0.75, 0.72, 0.66))
	draw_rect(BUTTON, Color(1.0, 0.82, 0.48, 0.22 if hover else 0.08))
	draw_rect(BUTTON, Color("#ffd27a") if hover else Color(1.0, 0.82, 0.48, 0.45), false, 2.0)
	draw_string(font, Vector2(0, 1018), "Enter / E / A — дальше", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color("#ffd27a"))
