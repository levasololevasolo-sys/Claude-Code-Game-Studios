## Lair reward (GDD room-generation §3.16, gods-and-runes §3.3): cards of up to
## 3 different gods; the chosen god then opens its usual rune offer. Arrows /
## 1-3 choose, Enter takes. Pauses the tree while open. 1920x1080 layout (ADR-0004).
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	get_tree().paused = true

func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo or gods.is_empty():
		return
	match k.keycode:
		KEY_LEFT, KEY_A:
			selected = posmod(selected - 1, gods.size())
		KEY_RIGHT, KEY_D:
			selected = posmod(selected + 1, gods.size())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J:
			take(selected)
			return
		_:
			var n := k.keycode - KEY_1
			if n >= 0 and n < gods.size():
				take(n)
				return
	queue_redraw()
	get_viewport().set_input_as_handled()

## Chooses card `i` and closes.
func take(i: int) -> void:
	get_tree().paused = false
	chosen.emit(gods[i])
	queue_free()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.85))
	draw_string(font, Vector2(0, 160), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color("#f0e2c0"))
	draw_string(font, Vector2(0, 215), "Выбранный бог даст выбор своих рун · ← → или 1–%d · Enter" % gods.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.7, 0.7, 0.65))
	var total := gods.size() * CARD.x + (gods.size() - 1) * GAP
	var x0 := (size.x - total) / 2.0
	for i in gods.size():
		var g := gods[i]
		var row: Dictionary = Tune.table("gods").get(g, {})
		var col := Enemy.god_colour(g)
		var r := Rect2(Vector2(x0 + i * (CARD.x + GAP), TOP - (16.0 if i == selected else 0.0)), CARD)
		draw_rect(r, Color(0.07, 0.09, 0.1, 0.96))
		draw_rect(r, col if i == selected else Color(col, 0.55), false, 6.0 if i == selected else 3.0)
		draw_string(font, r.position + Vector2(0, 46), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, col)
		GodGlyph.draw(self, g, r.position + Vector2(r.size.x / 2.0, 190), 80.0, col)
		draw_string(font, r.position + Vector2(0, 340), String(row.get("name", g)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 44, Color("#f4ecd8"))
		draw_string(font, r.position + Vector2(0, 390), String(row.get("word", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, col)
		var tag := "у тебя уже есть" if g in held else "новый бог"
		draw_string(font, r.position + Vector2(0, r.size.y - 30), tag, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(0.75, 0.8, 0.75))
