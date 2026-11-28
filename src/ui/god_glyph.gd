## God signs (gods.json "glyph"), rune icons and door reward icons
## (room-generation §3.8-3.9, art-bible §4.3, §7). Draws the SVG icons of
## assets/art/icons/ (tools/asset-pipeline/icons/build_icons.py) when they
## exist, loaded once and cached; otherwise the old CanvasItem shapes.
## Shared by the rune offer, god choice, doors and reward orbs.
class_name GodGlyph
extends RefCounted

const ICON_DIR: String = "res://assets/art/icons/"
## Icon half-size per unit of sign radius `s` (the medallion rim is r=114 of a
## 256 px canvas, its glow reaches the edge).
const SIGN_SCALE: float = 1.12

static var _cache: Dictionary = {}

## Painted god art of the approved drop (tools/asset-pipeline/navart/gods.py).
const ART_DIR: String = "res://assets/art/gods/"

## Path of an icon: kind = "god" | "rune" | "door".
static func icon_path(kind: String, id: String) -> String:
	return ICON_DIR + "ui_icon_%s_%s.svg" % [kind, id]

## A texture by path (cached), or null when the file does not exist.
static func _tex(p: String) -> Texture2D:
	if not _cache.has(p):
		_cache[p] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _cache[p]

## A painted god-art file (assets/art/gods/<name>.webp), or null.
static func art(name: String) -> Texture2D:
	return _tex(ART_DIR + name + ".webp")

## The icon texture (cached), or null when the file does not exist. A rune
## takes its painted card picture (boon_<rune>.webp) when there is one.
static func icon(kind: String, id: String) -> Texture2D:
	if kind == "rune":
		var b := art("boon_" + id)
		if b:
			return b
	return _tex(icon_path(kind, id))

## The god's framed portrait centred at `c`, fitted into a `half`-radius box
## (aspect kept); false when there is no portrait.
static func draw_portrait(ci: CanvasItem, g: String, c: Vector2, half: float, col: Color = Color.WHITE) -> bool:
	var t := art("portrait_" + g)
	if t == null:
		return false
	var sz := t.get_size() * (2.0 * half / maxf(t.get_width(), t.get_height()))
	ci.draw_texture_rect(t, Rect2(c - sz * 0.5, sz), false, col)
	return true

## The painted door of a door `type` / `god` (door_<god>, door_svarog_<state>,
## door_loot / shop / lair / plain), or null.
static func door_art(type: String, god: String, state: int = 1) -> Texture2D:
	match type:
		"god":
			return art("door_" + god)
		"svarog":
			return art("door_svarog_%d" % clampi(state, 0, 2))
		"loot", "lair":
			return art("door_" + type)
		"surica":
			return art("door_shop")
	return art("door_plain")

## Draws the icon centred at `c` with half-size `half`; false if it is missing.
static func draw_icon(ci: CanvasItem, kind: String, id: String, c: Vector2, half: float, alpha: float = 1.0) -> bool:
	var t := icon(kind, id)
	if t == null:
		return false
	ci.draw_texture_rect(t, Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), false, Color(1, 1, 1, alpha))
	return true

## God sign of `g` centred at `c`, radius `s`.
static func draw(ci: CanvasItem, g: String, c: Vector2, s: float, col: Color) -> void:
	if draw_icon(ci, "god", g, c, s * SIGN_SCALE, col.a):
		return
	ci.draw_circle(c, s, Color(col, 0.12))
	ci.draw_arc(c, s, 0.0, TAU, 48, col, 3.0)
	match String((Tune.table("gods").get(g, {}) as Dictionary).get("glyph", "circle")):
		"flames":
			for k in 3:
				var x := (k - 1) * s * 0.4
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 10, s * 0.45), c + Vector2(x, -s * 0.55 + abs(k - 1) * 12), c + Vector2(x + 10, s * 0.45)]), col)
		"rosette":
			for k in 6:
				var a := k * TAU / 6.0
				ci.draw_arc(c + Vector2(cos(a), sin(a)) * s * 0.33, s * 0.33, a + PI * 0.66, a + PI * 1.34, 12, col, 3.0)
		"wind":
			for k in 3:
				var y := (k - 1) * s * 0.35
				ci.draw_arc(c + Vector2(s * 0.15, y), s * 0.22, -PI * 0.5, PI * 1.0, 12, col, 3.0)
				ci.draw_line(c + Vector2(-s * 0.6, y - s * 0.22), c + Vector2(s * 0.15, y - s * 0.22), col, 3.0)
		"horns":
			ci.draw_arc(c + Vector2(-s * 0.25, 0), s * 0.45, PI * 0.6, PI * 1.5, 16, col, 4.0)
			ci.draw_arc(c + Vector2(s * 0.25, 0), s * 0.45, -PI * 0.5, PI * 0.4, 16, col, 4.0)
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.18, col)
		"sprout":
			ci.draw_line(c + Vector2(0, s * 0.6), c + Vector2(0, -s * 0.5), col, 4.0)
			for k in 3:
				var y := -s * 0.3 + k * s * 0.3
				ci.draw_line(c + Vector2(0, y), c + Vector2(-s * 0.3, y - s * 0.2), col, 3.0)
				ci.draw_line(c + Vector2(0, y), c + Vector2(s * 0.3, y - s * 0.2), col, 3.0)
		_:
			ci.draw_circle(c, s * 0.3, col)

## The Горн Сварога sign (gods-expansion §3.12): an anvil, a hammer over it,
## three flame tongues behind, on a hot-iron medallion. Painted icon first.
static func svarog_icon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var sign := art("sign_svarog")
	if sign:
		ci.draw_texture_rect(sign, Rect2(c - Vector2(s, s) * SIGN_SCALE, Vector2(s, s) * 2.0 * SIGN_SCALE), false, Color(1, 1, 1, col.a))
		return
	if draw_icon(ci, "door", "svarog", c, s * SIGN_SCALE, col.a):
		return
	ci.draw_circle(c, s * 1.05, Color(0.25, 0.08, 0.02, 0.9 * col.a))
	ci.draw_arc(c, s, 0.0, TAU, 48, col, 3.0)
	ci.draw_arc(c, s * 0.86, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, 0.6 * col.a), 1.5)
	var fire := Color(1.0, 0.55, 0.15, col.a)
	for k in 3:
		var x := (k - 1) * s * 0.32
		var hgt := s * (0.75 if k == 1 else 0.55)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - s * 0.16, s * 0.05), c + Vector2(x, -hgt), c + Vector2(x + s * 0.16, s * 0.05)]), fire)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - s * 0.08, s * 0.05), c + Vector2(x, -hgt * 0.6), c + Vector2(x + s * 0.08, s * 0.05)]), Color(1, 0.9, 0.5, col.a))
	var iron := Color(0.16, 0.14, 0.14, col.a)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, s * 0.05), c + Vector2(s * 0.62, s * 0.05), c + Vector2(s * 0.42, s * 0.28),
		c + Vector2(s * 0.2, s * 0.3), c + Vector2(s * 0.28, s * 0.62), c + Vector2(-s * 0.36, s * 0.62), c + Vector2(-s * 0.26, s * 0.3), c + Vector2(-s * 0.5, s * 0.22)]), iron)
	ci.draw_line(c + Vector2(-s * 0.66, s * 0.06), c + Vector2(s * 0.6, s * 0.06), Color(col, 0.9), 2.0)
	ci.draw_line(c + Vector2(s * 0.1, -s * 0.05), c + Vector2(s * 0.62, -s * 0.62), Color(0.55, 0.36, 0.2, col.a), 5.0)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.42, -s * 0.78), c + Vector2(s * 0.78, -s * 0.42), c + Vector2(s * 0.62, -s * 0.28), c + Vector2(s * 0.28, -s * 0.62)]), iron)

## Icon of a door / reward type (god doors use draw()).
static func door_icon(ci: CanvasItem, type: String, god: String, c: Vector2, s: float, col: Color) -> void:
	match type:
		"god":
			draw(ci, god, c, s, col)
			return
		"rod":
			if draw_icon(ci, "god", "rod", c, s * SIGN_SCALE, col.a):
				return
			draw(ci, "rod", c, s, col)
			ci.draw_arc(c, s * 0.55, 0.0, TAU, 24, col, 3.0)
			return
	if type == "svarog":
		svarog_icon(ci, c, s, col)
		return
	if draw_icon(ci, "door", type, c, s * SIGN_SCALE, col.a):
		return
	ci.draw_circle(c, s, Color(col, 0.12))
	ci.draw_arc(c, s, 0.0, TAU, 48, col, 3.0)
	match type:
		"surica":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.35), c + Vector2(s * 0.5, -s * 0.35), c + Vector2(s * 0.2, s * 0.2), c + Vector2(-s * 0.2, s * 0.2)]), col)
			ci.draw_line(c + Vector2(0, s * 0.2), c + Vector2(0, s * 0.5), col, 4.0)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.55), c + Vector2(s * 0.3, s * 0.55), col, 4.0)
		"loot":
			ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.42, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.25), c + Vector2(0, -s * 0.6), c + Vector2(s * 0.2, -s * 0.25)]), col)
		"heal":
			ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.35, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.33, s * 0.05), c + Vector2(0, -s * 0.6), c + Vector2(s * 0.33, s * 0.05)]), col)
		"arms":
			ci.draw_line(c + Vector2(-s * 0.5, s * 0.5), c + Vector2(s * 0.5, -s * 0.5), col, 6.0)
			ci.draw_line(c + Vector2(-s * 0.45, s * 0.1), c + Vector2(-s * 0.1, s * 0.45), col, 5.0)
		"lair":
			ci.draw_circle(c + Vector2(0, -s * 0.1), s * 0.45, col)
			ci.draw_circle(c + Vector2(-s * 0.17, -s * 0.15), s * 0.12, Color.BLACK)
			ci.draw_circle(c + Vector2(s * 0.17, -s * 0.15), s * 0.12, Color.BLACK)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, s * 0.25), Vector2(s * 0.5, s * 0.25)), col)
		"haven", "next_loc":
			for k in 3:
				var x := (k - 1) * s * 0.3
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - s * 0.18, s * 0.45), c + Vector2(x, -s * 0.5 + absf(k - 1) * s * 0.25), c + Vector2(x + s * 0.18, s * 0.45)]), col)
		"base":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.55, 0), c + Vector2(0, -s * 0.55), c + Vector2(s * 0.55, 0)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, 0), Vector2(s * 0.8, s * 0.5)), col)
		_:
			ci.draw_circle(c, s * 0.3, col)
