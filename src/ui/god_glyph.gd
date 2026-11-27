## Placeholder signs drawn with CanvasItem calls (art-bible §4.3 shapes): god
## signs (gods.json "glyph") and door reward icons (room-generation §3.8-3.9).
## Shared by the rune offer, god choice, doors and reward orbs.
class_name GodGlyph
extends RefCounted

## God sign of `g` centred at `c`, radius `s`.
static func draw(ci: CanvasItem, g: String, c: Vector2, s: float, col: Color) -> void:
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

## Icon of a door / reward type (god doors use draw()).
static func door_icon(ci: CanvasItem, type: String, god: String, c: Vector2, s: float, col: Color) -> void:
	match type:
		"god":
			draw(ci, god, c, s, col)
			return
		"rod":
			draw(ci, "rod", c, s, col)
			ci.draw_arc(c, s * 0.55, 0.0, TAU, 24, col, 3.0)
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
