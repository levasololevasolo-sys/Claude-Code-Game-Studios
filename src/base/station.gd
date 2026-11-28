## One point of the base (economy-and-meta §3.6): an NPC or the gate, drawn as
## placeholder shapes in the art bible palette (3 px warm-black outline, warm
## light around, the name above, an «E» badge when the hero is near, the gold
## spark when the NPC has a new line, living-world §1.3 step 6). The NPC turns
## to the hero and breathes (references-and-feel rule 18, first cut).
## NPCs with hand-drawn art (NpcSprite, tools/asset-pipeline/npc2d) show it
## instead of the shapes: idle, talk while their line is open, a reaction after;
## the shapes stay as the fallback (`-- --npc-art=shapes`).
class_name Station
extends Node2D

const C_LINE: Color = Color("#120D12")
const C_GOLD: Color = Color("#FFC94A")
const C_LINEN: Color = Color("#F2EAD8")

## Row of base.json `stations`.
var row: Dictionary = {}
var near: bool = false
var spark: bool = false
## -1 = faces left, 1 = right (towards the hero).
var face: float = 1.0
var _t: float = 0.0
## The drawn NPC, null when it falls back to shapes.
var sprite: NpcSprite

func _ready() -> void:
	if row.get("kind", "") != "gate" and NpcSprite.has_art(id()):
		sprite = NpcSprite.new()
		sprite.npc = id()
		sprite.lit = float(Tune.table("base").get("npc_lit", 0.55))
		add_child(sprite)

## The NPC talks (dialogue box open) or stops talking and reacts.
func set_talking(on: bool) -> void:
	if sprite == null:
		return
	if on:
		sprite.set_talking(true)
	else:
		sprite.set_talking(false)
		sprite.react()

## Station id ("potap", "gate", ...).
func id() -> String:
	return String(row.get("id", ""))

func _process(dt: float) -> void:
	_t += dt
	if sprite:
		sprite.face = face
	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var h := float(row.get("h", 160))
	if sprite:
		h = NpcSprite.height_of(id()) - 40.0
	var body := Color(String(row.get("body", "#5B3A24")))
	var trim := Color(String(row.get("trim", "#C8902E")))
	var warm := Color("#FF9A3C")
	for k in 4:
		draw_circle(Vector2(0, -h * 0.5), h * (1.6 - k * 0.3), Color(warm, 0.035 + k * 0.012))
	var breathe := sin(_t * TAU / 2.4) * 2.0
	match "drawn" if sprite else String(row.get("kind", "talk")):
		"drawn":
			pass
		"gate":
			for sx: float in [-70.0, 70.0]:
				_box(Rect2(sx - 14, -h, 28, h), Color("#2A1A12"))
			_box(Rect2(-95, -h - 26, 190, 30), Color("#5B3A24"))
			_box(Rect2(-56, -h + 30, 112, h - 30), Color("#1D2433"))
			draw_line(Vector2(0, -h + 30), Vector2(0, 0), Color("#7A5232"), 3.0)
			for k in 5:
				draw_colored_polygon(PackedVector2Array([Vector2(-90 + k * 45, -h - 26), Vector2(-68 + k * 45, -h - 52), Vector2(-46 + k * 45, -h - 26)]), trim)
		"kapishe":
			_box(Rect2(-18, -h, 36, h), body)
			draw_circle(Vector2(0, -h - 14), 26, C_LINE)
			draw_circle(Vector2(0, -h - 14), 23, body.lightened(0.15))
			draw_circle(Vector2(-8 * face, -h - 18), 4, C_GOLD)
			for k in 3:
				draw_line(Vector2(-18, -h + 30 + k * 40), Vector2(18, -h + 50 + k * 40), trim, 3.0)
			_box(Rect2(46, -36, 60, 36), Color("#2A1A12"))
			for k in 3:
				var fx := 58.0 + k * 18.0
				var fl := 34.0 + sin(_t * 9.0 + k) * 6.0
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 9, -34), Vector2(fx, -34 - fl), Vector2(fx + 9, -34)]), Color(warm, 0.9))
		_:
			var wide := 1.6 if id() == "potap" else 1.0
			var w := h * 0.34 * wide
			var top := -h * 0.72 + breathe
			var robe := PackedVector2Array([Vector2(-w, 0), Vector2(-w * 0.55, top), Vector2(w * 0.55, top), Vector2(w, 0)])
			draw_colored_polygon(robe, C_LINE)
			var inner := PackedVector2Array([Vector2(-w + 4, -3), Vector2(-w * 0.55 + 3, top + 3), Vector2(w * 0.55 - 3, top + 3), Vector2(w - 4, -3)])
			draw_colored_polygon(inner, body)
			draw_line(Vector2(-w * 0.8, -h * 0.2), Vector2(w * 0.8, -h * 0.2), trim, 5.0)
			var hr := h * 0.15 * (1.25 if id() == "potap" else 1.0)
			var head := Vector2(4 * face, top - hr * 0.9)
			if id() in ["potap", "bayun"]:
				for ex: float in [-0.7, 0.7]:
					draw_circle(head + Vector2(hr * ex, -hr * 0.8), hr * 0.38, C_LINE)
					draw_circle(head + Vector2(hr * ex, -hr * 0.8), hr * 0.3, body.lightened(0.1))
			draw_circle(head, hr + 3, C_LINE)
			draw_circle(head, hr, body.lightened(0.18) if id() != "dolya" else Color("#E9DFC9"))
			draw_circle(head + Vector2(hr * 0.45 * face, -hr * 0.1), 3.5, C_GOLD)
			if id() == "dolya":
				var c := Vector2(-w - 40, -h * 0.45)
				draw_arc(c, 38, 0, TAU, 28, Color("#7A5232"), 5.0)
				for k in 4:
					var a := _t * 1.5 + k * PI / 4.0
					draw_line(c - Vector2(cos(a), sin(a)) * 36, c + Vector2(cos(a), sin(a)) * 36, Color("#7A5232"), 2.0)
				draw_line(c, head + Vector2(-hr, hr), Color("#EDE6F2"), 1.5)
			elif id() == "potap":
				_box(Rect2(w + 20, -60, 80, 26), Color("#3A3A40"))
				_box(Rect2(w + 44, -34, 32, 34), Color("#2A2A30"))
				draw_circle(Vector2(w + 60, -70), 10 + sin(_t * 7.0) * 2.0, Color(warm, 0.6))
			elif id() == "sova":
				for k in 3:
					var p := Vector2(w + 30 + k * 26, -h * 0.55 + sin(_t * 2.0 + k) * 4.0)
					draw_line(Vector2(p.x, -h * 0.8), p, Color("#A99C86"), 1.5)
					draw_circle(p, 9, C_LINE)
					draw_circle(p, 7, [C_GOLD, Color("#4F8FE0"), Color("#6FBF5A")][k])
			elif id() == "prorok":
				# Blindfold, a tall staff with an eye, the gods' colours circling it.
				draw_line(head + Vector2(-hr, -hr * 0.15), head + Vector2(hr, -hr * 0.15), trim, 5.0)
				var sx := w + 26.0
				draw_line(Vector2(sx, 0), Vector2(sx, -h - 20), C_LINE, 7.0)
				draw_line(Vector2(sx, 0), Vector2(sx, -h - 20), Color("#7A5232"), 4.0)
				var eye := Vector2(sx, -h - 34)
				draw_circle(eye, 22, Color(trim, 0.35))
				draw_circle(eye, 13, C_LINE)
				draw_circle(eye, 10, C_LINEN)
				draw_circle(eye, 5, trim)
				var cols: Array = []
				for g: String in Tune.table("gods"):
					var r: Variant = Tune.table("gods")[g]
					if r is Dictionary and (r as Dictionary).has("colour") and bool((r as Dictionary).get("toggle", true)):
						cols.append(Color(String((r as Dictionary).colour)))
				for k in cols.size():
					var a := _t * 0.8 + k * TAU / maxf(cols.size(), 1.0)
					draw_circle(eye + Vector2(cos(a) * 48, sin(a) * 18), 5, Color(cols[k], 0.85))
	var label := String(row.get("name", ""))
	draw_string(font, Vector2(-200, -h - 70), label, HORIZONTAL_ALIGNMENT_CENTER, 400, 26, C_LINEN)
	if spark:
		var sp := Vector2(0, -h - 112 + sin(_t * 4.0) * 5.0)
		draw_circle(sp, 14, Color(C_GOLD, 0.25))
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -12), sp + Vector2(4, -4), sp + Vector2(12, 0), sp + Vector2(4, 4), sp + Vector2(0, 12), sp + Vector2(-4, 4), sp + Vector2(-12, 0), sp + Vector2(-4, -4)]), C_GOLD)
	if near:
		var b := Rect2(-22, -h - 150 if spark else -h - 120, 44, 40)
		draw_rect(b, Color("#21170F", 0.9))
		draw_rect(b, C_GOLD, false, 2.5)
		draw_string(font, b.position + Vector2(0, 30), "E", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 28, C_GOLD)

func _box(r: Rect2, c: Color) -> void:
	draw_rect(r.grow(3), C_LINE)
	draw_rect(r, c)
