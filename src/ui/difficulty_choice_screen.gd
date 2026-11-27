## Difficulty choice on a new save (GDD difficulty §3.2): three cards «Сказка»,
## «Былина» (selected), «Навь» with their description and numbers. Arrows /
## d-pad / stick / hover / 1-3 choose; Enter / E / pad A / click take
## (ChoiceInput, with its confirm lockout). Pauses the tree while open.
## Placeholder look until the UI art pass. 1920x1080 layout (ADR-0004).
class_name DifficultyChoiceScreen
extends Control

## Emitted with the chosen level id.
signal chosen(id: String)

const CARD: Vector2 = Vector2(460, 640)
const GAP: float = 48.0
const TOP: float = 280.0

## Level ids in menu order (difficulty.json "order").
var ids: Array[String] = []
var selected: int = 0
## Keyboard / gamepad / mouse reader with the confirm lockout.
var input: ChoiceInput

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	var t := Difficulty.table()
	ids = Difficulty.order(t)
	selected = maxi(0, ids.find(String(t.get("default", Difficulty.DEFAULT))))
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	get_tree().paused = true

func _process(dt: float) -> void:
	input.tick(dt)

func _unhandled_input(ev: InputEvent) -> void:
	if _apply(input.read(ev, ids.size())):
		get_viewport().set_input_as_handled()

func _gui_input(ev: InputEvent) -> void:
	if _apply(input.read(ev, ids.size(), card_rects())):
		accept_event()

## Applies a ChoiceInput intent; true if it was used.
func _apply(r: Dictionary) -> bool:
	if ids.is_empty():
		return false
	match r.act:
		ChoiceInput.Act.PREV:
			selected = posmod(selected - 1, ids.size())
		ChoiceInput.Act.NEXT:
			selected = posmod(selected + 1, ids.size())
		ChoiceInput.Act.HOVER:
			if r.i == selected:
				return true
			selected = r.i
		ChoiceInput.Act.CONFIRM:
			take(selected)
			return true
		ChoiceInput.Act.PICK:
			take(r.i)
			return true
		_:
			return false
	queue_redraw()
	return true

## Card rects in local px (drawing and mouse hit tests).
func card_rects() -> Array:
	var out: Array = []
	var total := ids.size() * CARD.x + (ids.size() - 1) * GAP
	var x0 := (size.x - total) / 2.0
	for i in ids.size():
		out.append(Rect2(Vector2(x0 + i * (CARD.x + GAP), TOP), CARD))
	return out

## Takes level `i` and closes.
func take(i: int) -> void:
	get_tree().paused = false
	chosen.emit(ids[i])
	queue_free()

## Number lines of a card («Урон врагов ×0.6»), skipping identity values.
static func stat_lines(level: String, t: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var names := { "enemy_dmg": "Урон врагов", "enemy_hp": "Здоровье врагов", "heal": "Лечение",
		"embers": "Угли", "windup": "Время замаха врагов" }
	for k: String in names:
		var v := Difficulty.value(level, k, t)
		if not is_equal_approx(v, 1.0):
			out.append("%s ×%s" % [names[k], String.num(v, 2)])
	var rv := Difficulty.revives_for(level, t)
	if rv > 0:
		out.append("Нить Мокоши: %d за забег" % rv)
	if out.is_empty():
		out.append("Все числа как задумано")
	return out

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var t := Difficulty.table()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.92))
	draw_string(font, Vector2(0, 150), "Какой будет твоя сказка?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 52, Color("#f0e2c0"))
	draw_string(font, Vector2(0, 210), "Сложность можно сменить в любой момент: Esc, Настройки, Сложность · ← → или 1–3 · Enter / E / A / щелчок", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.7, 0.7, 0.65))
	var cols := [Color("#8fc0a0"), Color("#e0c27a"), Color("#c8503e")]
	var rects := card_rects()
	for i in ids.size():
		var id := ids[i]
		var row: Dictionary = (t.get("levels", {}) as Dictionary).get(id, {})
		var col: Color = cols[mini(i, cols.size() - 1)]
		var r := Rect2((rects[i] as Rect2).position - Vector2(0, 16.0 if i == selected else 0.0), CARD)
		draw_rect(r, Color(0.07, 0.09, 0.1, 0.96))
		draw_rect(r, col if i == selected else Color(col, 0.5), false, 6.0 if i == selected else 3.0)
		draw_string(font, r.position + Vector2(0, 46), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, col)
		draw_string(font, r.position + Vector2(0, 120), String(row.get("name", id)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 54, Color("#f4ecd8"))
		draw_multiline_string(font, r.position + Vector2(30, 190), String(row.get("desc", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 60, 24, -1, Color(0.82, 0.82, 0.76))
		var y := 450.0
		for line in stat_lines(id, t):
			draw_string(font, r.position + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, col)
			y += 34.0
