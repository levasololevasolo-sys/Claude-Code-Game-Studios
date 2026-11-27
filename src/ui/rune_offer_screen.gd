## The rune offer screen (GDD gods-and-runes §3.3-3.4, §3.14): 3 cards (4 with
## «Широкий выбор»), each with the god's colour and sign, the slot label and
## what it replaces ("Заменит: …"). Arrows / 1-4 choose, Enter takes. Pauses the
## tree while open (architecture §4 «Пауза»). Laid out for 1920x1080 (ADR-0004).
## Placeholder look: procedural cards until the UI theme exists.
class_name RuneOfferScreen
extends Control

## Emitted after the hero took the rune `id`.
signal chosen(id: String)

const CARD: Vector2 = Vector2(400, 560)
const GAP: float = 36.0
const TOP: float = 250.0

## Build that receives the rune (injected).
var build: RunBuild
## The hero (for «Передышка» healing), may be null.
var hero: Player
## Rune ids on the cards (RuneOffer.build_offer()).
var ids: Array[String] = []
## Door god shown in the title.
var god: String = ""
var selected: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	get_tree().paused = true

func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_LEFT, KEY_A:
			selected = posmod(selected - 1, ids.size())
		KEY_RIGHT, KEY_D:
			selected = posmod(selected + 1, ids.size())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J:
			take(selected)
			return
		_:
			var n := k.keycode - KEY_1
			if n >= 0 and n < ids.size():
				take(n)
				return
	queue_redraw()
	get_viewport().set_input_as_handled()

## Takes card `i`: the rune goes into the build, the screen closes.
func take(i: int) -> void:
	var id := ids[i]
	var replaced := build.take(id)
	if id == "rest" and hero:
		hero.hp = minf(Tune.f("player_hp"), hero.hp + float(build.row(id).get("heal", Tune.f("rest_heal"))))
	Events.rune_taken.emit(id, build.slot_of(id), replaced)
	get_tree().paused = false
	chosen.emit(id)
	queue_free()

## Text of the "what happens to the slot" line of a card.
func replace_line(id: String) -> String:
	var slot := build.slot_of(id)
	match slot:
		"strike", "dash", "flare":
			var old: String = build.slots[slot]
			if old == "":
				return "Слот пуст"
			return "Заменит: %s (ур. %d)" % [build.row(old).get("name", old), build.level(old)]
		"duo":
			var gs: Array = build.row(id).get("gods", [])
			return "Союз: %s + %s" % [_god_name(String(gs[0])), _god_name(String(gs[1]))]
		"passive":
			return "Новое свойство"
	return ""

func _god_name(g: String) -> String:
	return String((Tune.table("gods").get(g, {}) as Dictionary).get("name", g))

func _card_god(id: String) -> String:
	var r := build.row(id)
	if r.has("god"):
		return String(r.god)
	var gs: Array = r.get("gods", [])
	return String(gs[0]) if not gs.is_empty() else "rod"

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.82))
	var title := "Дар бога: %s — выбери руну" % _god_name(god) if god != "" else "Выбери руну"
	draw_string(font, Vector2(0, 150), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color("#f0e2c0"))
	draw_string(font, Vector2(0, 200), "← → или 1–%d · Enter — взять" % ids.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.7, 0.7, 0.65))
	var total := ids.size() * CARD.x + (ids.size() - 1) * GAP
	var x0 := (size.x - total) / 2.0
	for i in ids.size():
		_draw_card(font, Rect2(Vector2(x0 + i * (CARD.x + GAP), TOP - (16.0 if i == selected else 0.0)), CARD), ids[i], i)

func _draw_card(font: Font, r: Rect2, id: String, i: int) -> void:
	var row := build.row(id)
	var g := _card_god(id)
	var col := Enemy.god_colour(g)
	var slot := build.slot_of(id)
	draw_rect(r, Color(0.07, 0.09, 0.1, 0.96))
	draw_rect(r, col if i == selected else Color(col, 0.55), false, 6.0 if i == selected else 3.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 48)), Color(col, 0.25))
	draw_string(font, r.position + Vector2(0, 34), "%d · %s" % [i + 1, RunBuild.SLOT_LABEL.get(slot, slot)], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, col)
	var gr := row.get("gods", [g]) as Array
	for k in gr.size():
		var gc := r.position + Vector2(r.size.x / 2.0 + (k - (gr.size() - 1) / 2.0) * 120.0, 150)
		_draw_glyph(String(gr[k]), gc, 52.0, Enemy.god_colour(String(gr[k])))
	var gods_txt := " + ".join(PackedStringArray(gr.map(func(x: Variant) -> String: return _god_name(String(x)))))
	draw_string(font, r.position + Vector2(0, 240), gods_txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(col, 0.9))
	draw_string(font, r.position + Vector2(0, 290), String(row.get("name", id)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color("#f4ecd8"))
	draw_multiline_string(font, r.position + Vector2(24, 345), String(row.get("desc", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 48, 24, 5, Color(0.85, 0.85, 0.8))
	var line := replace_line(id)
	var lc := Color("#ffb070") if line.begins_with("Заменит") else Color(0.7, 0.8, 0.7)
	draw_string(font, r.position + Vector2(0, r.size.y - 30), line, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, lc)

## Placeholder god signs (art-bible §4.3 shapes): drawn, not font glyphs.
func _draw_glyph(g: String, c: Vector2, s: float, col: Color) -> void:
	draw_circle(c, s, Color(col, 0.12))
	draw_arc(c, s, 0.0, TAU, 48, col, 3.0)
	match String((Tune.table("gods").get(g, {}) as Dictionary).get("glyph", "circle")):
		"flames":
			for k in 3:
				var x := (k - 1) * s * 0.4
				draw_colored_polygon(PackedVector2Array([c + Vector2(x - 10, s * 0.45), c + Vector2(x, -s * 0.55 + abs(k - 1) * 12), c + Vector2(x + 10, s * 0.45)]), col)
		"rosette":
			for k in 6:
				var a := k * TAU / 6.0
				draw_arc(c + Vector2(cos(a), sin(a)) * s * 0.33, s * 0.33, a + PI * 0.66, a + PI * 1.34, 12, col, 3.0)
		"wind":
			for k in 3:
				var y := (k - 1) * s * 0.35
				draw_arc(c + Vector2(s * 0.15, y), s * 0.22, -PI * 0.5, PI * 1.0, 12, col, 3.0)
				draw_line(c + Vector2(-s * 0.6, y - s * 0.22), c + Vector2(s * 0.15, y - s * 0.22), col, 3.0)
		"horns":
			draw_arc(c + Vector2(-s * 0.25, 0), s * 0.45, PI * 0.6, PI * 1.5, 16, col, 4.0)
			draw_arc(c + Vector2(s * 0.25, 0), s * 0.45, -PI * 0.5, PI * 0.4, 16, col, 4.0)
			draw_circle(c + Vector2(0, s * 0.3), s * 0.18, col)
		"sprout":
			draw_line(c + Vector2(0, s * 0.6), c + Vector2(0, -s * 0.5), col, 4.0)
			for k in 3:
				var y := -s * 0.3 + k * s * 0.3
				draw_line(c + Vector2(0, y), c + Vector2(-s * 0.3, y - s * 0.2), col, 3.0)
				draw_line(c + Vector2(0, y), c + Vector2(s * 0.3, y - s * 0.2), col, 3.0)
		_:
			draw_circle(c, s * 0.3, col)
