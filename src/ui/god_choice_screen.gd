## Lair reward (GDD room-generation §3.16, gods-and-runes §3.3): cards of up to
## 3 different gods; the chosen god then opens its usual rune offer. Arrows / d-pad /
## stick / hover / 1-3 choose; Enter / E / pad A / click take (ChoiceInput). Pauses the tree while open. 1920x1080 layout (ADR-0004).
## Placeholder look until the UI theme exists.
class_name GodChoiceScreen
extends Control

## Emitted with the chosen god id.
signal chosen(god: String)

const CARD: Vector2 = Vector2(380, 480)
const GAP: float = 48.0
const TOP: float = 290.0

## God ids on the cards (DoorRules.lair_gods()).
var gods: Array[String] = []
## Gods the hero already holds (the card says «новый бог» for the others).
var held: Array[String] = []
## Title line, e.g. the beaten boss.
var title: String = "Хозяин повержен — выбери бога"
var selected: int = 0
## Keyboard / gamepad / mouse reader with the confirm lockout (BUG-0002, BUG-0003).
var input: ChoiceInput

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	get_tree().paused = true

func _process(dt: float) -> void:
	input.tick(dt)

func _unhandled_input(ev: InputEvent) -> void:
	if _apply(input.read(ev, gods.size())):
		get_viewport().set_input_as_handled()

func _gui_input(ev: InputEvent) -> void:
	if _apply(input.read(ev, gods.size(), card_rects())):
		accept_event()

## Applies a ChoiceInput intent; true if it was used.
func _apply(r: Dictionary) -> bool:
	if gods.is_empty():
		return false
	match r.act:
		ChoiceInput.Act.PREV:
			selected = posmod(selected - 1, gods.size())
		ChoiceInput.Act.NEXT:
			selected = posmod(selected + 1, gods.size())
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

## Unraised card rects in local px (drawing and mouse hit tests).
func card_rects() -> Array:
	var out: Array = []
	var total := gods.size() * CARD.x + (gods.size() - 1) * GAP
	var x0 := (size.x - total) / 2.0
	for i in gods.size():
		out.append(Rect2(Vector2(x0 + i * (CARD.x + GAP), TOP), CARD))
	return out

## Chooses card `i` and closes.
func take(i: int) -> void:
	get_tree().paused = false
	chosen.emit(gods[i])
	queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.85))
	draw_string(font, Vector2(0, 160), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color("#f0e2c0"))
	draw_string(font, Vector2(0, 215), "Выбранный бог даст выбор своих рун · ← → / крестовина или 1–%d · Enter / E / A / щелчок" % gods.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.7, 0.7, 0.65))
	var rects := card_rects()
	for i in gods.size():
		var g := gods[i]
		var row: Dictionary = Tune.table("gods").get(g, {})
		var col := Enemy.god_colour(g)
		var r := Rect2((rects[i] as Rect2).position - Vector2(0, 16.0 if i == selected else 0.0), CARD)
		draw_rect(r, Color(0.07, 0.09, 0.1, 0.96))
		draw_rect(r, col if i == selected else Color(col, 0.55), false, 6.0 if i == selected else 3.0)
		draw_string(font, r.position + Vector2(0, 46), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, col)
		if not GodGlyph.draw_portrait(self, g, r.position + Vector2(r.size.x / 2.0, 180), 108.0):
			GodGlyph.draw(self, g, r.position + Vector2(r.size.x / 2.0, 190), 80.0, col)
		draw_string(font, r.position + Vector2(0, 340), String(row.get("name", g)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 44, Color("#f4ecd8"))
		draw_string(font, r.position + Vector2(0, 390), String(row.get("word", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, col)
		var tag := "у тебя уже есть" if g in held else "новый бог"
		draw_string(font, r.position + Vector2(0, r.size.y - 30), tag, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(0.75, 0.8, 0.75))
