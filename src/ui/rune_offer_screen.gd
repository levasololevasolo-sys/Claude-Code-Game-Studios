## The rune offer screen (GDD gods-and-runes §3.3-3.4, §3.14): 3 cards (4 with
## «Широкий выбор»), each with the god's colour and sign, the slot label and
## what it replaces ("Заменит: …"). Arrows / d-pad / stick / mouse hover / 1-4
## choose; Enter / E / pad A / click take (ChoiceInput: lockout, never J/Space). Pauses the
## tree while open (architecture §4 «Пауза»). Laid out for 1920x1080 (ADR-0004).
## Cards are procedural until the UI theme exists; the rune icon (GodGlyph) is drawn large.
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
## "take" = take a new rune; "surica" = raise the level of a held rune (§3.10).
var mode: String = "take"
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

## Unraised card rects in local px (drawing and mouse hit tests).
func card_rects() -> Array:
	var out: Array = []
	var total := ids.size() * CARD.x + (ids.size() - 1) * GAP
	var x0 := (size.x - total) / 2.0
	for i in ids.size():
		out.append(Rect2(Vector2(x0 + i * (CARD.x + GAP), TOP), CARD))
	return out

## Takes card `i`: the rune goes into the build, the screen closes.
func take(i: int) -> void:
	var id := ids[i]
	if mode == "surica":
		build.level_up(id)
		get_tree().paused = false
		chosen.emit(id)
		queue_free()
		return
	var replaced := build.take(id)
	if id == "rest" and hero:
		hero.hp = minf(Tune.f("player_hp"), hero.hp + float(build.row(id).get("heal", Tune.f("rest_heal"))))
	Events.rune_taken.emit(id, build.slot_of(id), replaced)
	get_tree().paused = false
	chosen.emit(id)
	queue_free()

## Text of the "what happens to the slot" line of a card.
func replace_line(id: String) -> String:
	if mode == "surica":
		return "Уровень %d → %d" % [build.level(id), build.level(id) + 1]
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
	if mode == "surica":
		title = "Сурица — подними уровень своей руны"
	draw_string(font, Vector2(0, 150), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color("#f0e2c0"))
	draw_string(font, Vector2(0, 200), "← → / крестовина или 1–%d · Enter / E / A / щелчок — взять" % ids.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.7, 0.7, 0.65))
	var rects := card_rects()
	for i in ids.size():
		var r: Rect2 = rects[i]
		_draw_card(font, Rect2(r.position - Vector2(0, 16.0 if i == selected else 0.0), CARD), ids[i], i)

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
	var dy := 0.0
	if GodGlyph.draw_icon(self, "rune", id, r.position + Vector2(r.size.x / 2.0, 150), 100.0):
		dy = 40.0  # the large rune icon carries the god sign(s)
	else:
		for k in gr.size():
			var gc := r.position + Vector2(r.size.x / 2.0 + (k - (gr.size() - 1) / 2.0) * 120.0, 150)
			GodGlyph.draw(self, String(gr[k]), gc, 52.0, Enemy.god_colour(String(gr[k])))
	var gods_txt := " + ".join(PackedStringArray(gr.map(func(x: Variant) -> String: return _god_name(String(x)))))
	draw_string(font, r.position + Vector2(0, 240 + dy), gods_txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(col, 0.9))
	draw_string(font, r.position + Vector2(0, 290 + dy * 0.8), String(row.get("name", id)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color("#f4ecd8"))
	draw_multiline_string(font, r.position + Vector2(24, 345 + dy * 0.6), String(row.get("desc", "")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 48, 24, 4, Color(0.85, 0.85, 0.8))
	var line := replace_line(id)
	var lc := Color("#ffb070") if line.begins_with("Заменит") or line.begins_with("Уровень") else Color(0.7, 0.8, 0.7)
	draw_string(font, r.position + Vector2(0, r.size.y - 30), line, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, lc)

