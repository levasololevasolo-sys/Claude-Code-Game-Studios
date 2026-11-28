## Placeholder signs of the artifacts (artifacts.json "icon"): simple drawn
## shapes until the art pass brings painted icons. Unknown words draw a rhombus.
class_name ArtifactIcon
extends RefCounted

## Icon words this helper draws.
const KNOWN: Array[String] = ["spindle", "rope", "hammer", "horn", "key", "feather", "mirror", "bell", "comb", "needle", "egg", "ring", "bowl", "flame", "eye", "branch", "rhombus", "thread", "lantern", "drum", "fang", "scroll", "candle", "sickle", "shield", "boot", "wing", "water", "stone", "tooth", "skull", "seed", "chain", "flute", "gusli", "pipe", "axe", "staff", "towel", "belt", "bread", "salt", "loop", "flower", "bolt", "flint", "bud", "ball"]

static func _poly(ci: CanvasItem, pts: Array, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), c)

## Draws icon `kind` centred at `p`, about `s` px in radius, colour `c`.
static func draw_icon(ci: CanvasItem, kind: String, p: Vector2, s: float, c: Color, t: float = 0.0) -> void:
	ci.draw_circle(p, s * 1.15, Color(c, c.a * 0.10))
	var d := c.darkened(0.35)
	match kind:
		"spindle", "thread", "needle":
			_poly(ci, [p + Vector2(0, -s), p + Vector2(s * 0.22, 0), p + Vector2(0, s), p + Vector2(-s * 0.22, 0)], c)
			for i in 4:
				var y := -s * 0.35 + i * s * 0.22
				ci.draw_line(p + Vector2(-s * 0.3, y), p + Vector2(s * 0.3, y + s * 0.08), d, 2.0)
			ci.draw_arc(p + Vector2(s * 0.5, s * 0.2), s * 0.4, -1.2, 1.5, 12, Color(c, c.a * 0.7), 1.5)
		"rope", "chain":
			ci.draw_arc(p, s * 0.55, 0.0, TAU, 24, c, 4.0)
			ci.draw_arc(p, s * 0.3, 0.0, TAU, 18, d, 3.0)
			ci.draw_line(p + Vector2(s * 0.5, s * 0.3), p + Vector2(s * 0.9, s * 0.9), c, 4.0)
			ci.draw_arc(p + Vector2(s * 0.9, s * 0.6), s * 0.25, -0.5, 2.2, 10, c, 3.0)
		"hammer", "axe":
			ci.draw_line(p + Vector2(-s * 0.6, s * 0.8), p + Vector2(s * 0.3, -s * 0.3), d, 5.0)
			_poly(ci, [p + Vector2(0, -s * 0.9), p + Vector2(s * 0.9, -s * 0.0), p + Vector2(s * 0.55, s * 0.35), p + Vector2(-s * 0.35, -s * 0.55)], c)
		"horn", "pipe", "flute":
			var pts: Array = []
			for i in 9:
				var k := i / 8.0
				pts.append(p + Vector2(-s * 0.9 + k * s * 1.6, s * 0.4 - sin(k * PI * 0.8) * s * 0.7 - k * s * 0.15))
			for i in range(8, -1, -1):
				var k := i / 8.0
				pts.append(p + Vector2(-s * 0.9 + k * s * 1.6, s * 0.4 - sin(k * PI * 0.8) * s * 0.7 - k * s * 0.15 + 4.0 + k * s * 0.5))
			_poly(ci, pts, c)
		"key":
			ci.draw_arc(p + Vector2(-s * 0.45, 0), s * 0.32, 0.0, TAU, 18, c, 4.0)
			ci.draw_line(p + Vector2(-s * 0.13, 0), p + Vector2(s * 0.9, 0), c, 4.0)
			ci.draw_line(p + Vector2(s * 0.6, 0), p + Vector2(s * 0.6, s * 0.35), c, 4.0)
			ci.draw_line(p + Vector2(s * 0.85, 0), p + Vector2(s * 0.85, s * 0.3), c, 4.0)
		"feather", "wing", "branch":
			ci.draw_line(p + Vector2(-s * 0.7, s * 0.8), p + Vector2(s * 0.6, -s * 0.8), d, 3.0)
			for i in 6:
				var q := p + Vector2(-s * 0.5 + i * s * 0.2, s * 0.55 - i * s * 0.25)
				ci.draw_line(q, q + Vector2(-s * 0.4, -s * 0.15), c, 3.0)
				ci.draw_line(q, q + Vector2(s * 0.15, s * 0.4), c, 3.0)
		"mirror", "ring", "egg", "water", "eye":
			ci.draw_circle(p, s * 0.6, d)
			ci.draw_circle(p, s * 0.45, c)
			ci.draw_circle(p + Vector2(-s * 0.15, -s * 0.15), s * 0.12, Color(1, 1, 1, c.a * 0.6))
			if kind == "eye":
				ci.draw_circle(p, s * 0.18, Color(0, 0, 0, c.a))
		"bell", "lantern", "candle", "flame":
			_poly(ci, [p + Vector2(-s * 0.15, -s * 0.8), p + Vector2(s * 0.15, -s * 0.8), p + Vector2(s * 0.7, s * 0.6), p + Vector2(-s * 0.7, s * 0.6)], c)
			ci.draw_circle(p + Vector2(0, s * 0.7), s * 0.15, d)
			ci.draw_circle(p + Vector2(0, -s * 0.2), s * (0.18 + 0.04 * sin(t * 4.0)), Color(1, 0.9, 0.6, c.a * 0.8))
		"comb", "fang", "tooth", "sickle":
			ci.draw_rect(Rect2(p + Vector2(-s * 0.8, -s * 0.5), Vector2(s * 1.6, s * 0.3)), c)
			for i in 8:
				ci.draw_line(p + Vector2(-s * 0.7 + i * s * 0.2, -s * 0.2), p + Vector2(-s * 0.7 + i * s * 0.2, s * 0.6), c, 3.0)
		"bowl", "drum", "gusli", "shield", "stone", "seed", "bread", "salt":
			ci.draw_arc(p + Vector2(0, -s * 0.1), s * 0.75, 0.15, PI - 0.15, 18, c, 6.0)
			ci.draw_line(p + Vector2(-s * 0.75, -s * 0.05), p + Vector2(s * 0.75, -s * 0.05), c, 4.0)
		"scroll", "towel", "belt":
			ci.draw_rect(Rect2(p + Vector2(-s * 0.6, -s * 0.7), Vector2(s * 1.2, s * 1.4)), d)
			for i in 4:
				ci.draw_line(p + Vector2(-s * 0.45, -s * 0.4 + i * s * 0.28), p + Vector2(s * 0.45, -s * 0.4 + i * s * 0.28), c, 3.0)
		"skull":
			ci.draw_circle(p + Vector2(0, -s * 0.1), s * 0.6, c)
			ci.draw_rect(Rect2(p + Vector2(-s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.4)), c)
			ci.draw_circle(p + Vector2(-s * 0.22, -s * 0.1), s * 0.14, Color(0, 0, 0, c.a))
			ci.draw_circle(p + Vector2(s * 0.22, -s * 0.1), s * 0.14, Color(0, 0, 0, c.a))
		"boot", "staff":
			ci.draw_line(p + Vector2(0, -s * 0.9), p + Vector2(0, s * 0.9), c, 5.0)
			ci.draw_circle(p + Vector2(0, -s * 0.9), s * 0.2, c)
		"loop":
			ci.draw_arc(p + Vector2(0, -s * 0.2), s * 0.5, 0.0, TAU, 24, c, 4.0)
			ci.draw_line(p + Vector2(-s * 0.1, s * 0.28), p + Vector2(-s * 0.5, s * 0.9), c, 4.0)
			ci.draw_line(p + Vector2(s * 0.1, s * 0.28), p + Vector2(s * 0.35, s * 0.9), d, 4.0)
		"flower", "bud":
			ci.draw_line(p + Vector2(0, s * 0.9), p + Vector2(0, -s * 0.1), d, 3.0)
			var n := 5 if kind == "flower" else 3
			for i in n:
				var a := -PI * 0.5 + (i - (n - 1) * 0.5) * (TAU / 5.0 if kind == "flower" else 0.6)
				ci.draw_circle(p + Vector2(0, -s * 0.3) + Vector2(cos(a), sin(a)) * s * 0.32, s * (0.24 if kind == "flower" else 0.2), c)
			ci.draw_circle(p + Vector2(0, -s * 0.3), s * 0.16, Color(1, 0.9, 0.6, c.a))
			ci.draw_line(p + Vector2(0, s * 0.4), p + Vector2(-s * 0.35, s * 0.2), d, 3.0)
		"bolt":
			_poly(ci, [p + Vector2(s * 0.2, -s * 0.9), p + Vector2(-s * 0.4, s * 0.1), p + Vector2(0, s * 0.1), p + Vector2(-s * 0.2, s * 0.9), p + Vector2(s * 0.5, -s * 0.2), p + Vector2(s * 0.05, -s * 0.2), p + Vector2(s * 0.35, -s * 0.9)], c)
		"flint":
			ci.draw_arc(p + Vector2(0, s * 0.1), s * 0.6, PI * 0.1, PI * 0.9, 14, c, 5.0)
			ci.draw_line(p + Vector2(-s * 0.6, s * 0.1), p + Vector2(s * 0.6, s * 0.1), c, 4.0)
			_poly(ci, [p + Vector2(-s * 0.3, -s * 0.2), p + Vector2(0, -s * 0.8), p + Vector2(s * 0.35, -s * 0.25)], d)
			for i in 3:
				ci.draw_circle(p + Vector2(-s * 0.4 + i * s * 0.4, -s * 0.7 - (i % 2) * s * 0.15), s * 0.07, Color(1, 0.8, 0.4, c.a))
		"ball":
			ci.draw_circle(p, s * 0.6, c)
			for i in 4:
				ci.draw_arc(p, s * (0.15 + i * 0.12), 0.4 * i, 0.4 * i + PI * 1.3, 14, d, 2.0)
			ci.draw_line(p + Vector2(s * 0.5, s * 0.35), p + Vector2(s * 0.95, s * 0.8), c, 2.0)
		_:
			_poly(ci, [p + Vector2(0, -s * 0.8), p + Vector2(s * 0.6, 0), p + Vector2(0, s * 0.8), p + Vector2(-s * 0.6, 0)], c)
