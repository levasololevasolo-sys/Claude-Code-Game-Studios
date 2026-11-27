## Placeholder HUD charge ring of the amulet (GDD amulet-and-flare §6 HUD row:
## scale to the cap, a mark at 100, a second colour for overcharge, the shape
## glyph). Reads the injected Amulet (architecture §4 "injected reference"); never
## calls gameplay. Laid out in 1080p screen px (ADR-0004). Final art: design/ux/hud.md.
class_name AmuletHud
extends Control

const RADIUS: float = 52.0
const WIDTH: float = 12.0
const FILL := Color("#ffd27a")
const OVER := Color("#ff8a3c")
const EMPTY := Color(1, 1, 1, 0.12)
const MARK := Color(1, 1, 1, 0.9)

## The hero's amulet (null = draw nothing).
var amulet: Amulet
var _t: float = 0.0

func _process(dt: float) -> void:
	_t += dt
	if amulet:
		amulet.tick(dt)
	queue_redraw()

func _draw() -> void:
	if amulet == null:
		return
	var ready := amulet.ready_at()
	var c := amulet.charge
	var shake := Vector2(sin(_t * 90.0) * 5.0, 0.0) if amulet.fizzle_t > 0.0 else Vector2.ZERO
	var o := Vector2(RADIUS + WIDTH, RADIUS + WIDTH) + shake
	var top := -PI / 2.0
	# The ring spans 0..cap; the 0..100 part is gold, the overcharge part orange.
	var span := TAU * 0.9
	var cap := maxf(amulet.cap, ready)
	var a_ready := top + span * ready / cap
	draw_arc(o, RADIUS, top, top + span, 64, EMPTY, WIDTH)
	draw_arc(o, RADIUS, top, top + span * minf(c, ready) / cap, 64, FILL, WIDTH)
	if c > ready:
		draw_arc(o, RADIUS, a_ready, top + span * c / cap, 32, OVER, WIDTH)
	var m := Vector2(cos(a_ready), sin(a_ready))
	draw_line(o + m * (RADIUS - WIDTH), o + m * (RADIUS + WIDTH), MARK, 3.0)
	var core := Color(FILL, 0.25)
	if amulet.is_ready():
		core = Color(OVER if amulet.is_over() else FILL, 0.55 + 0.35 * sin(_t * (14.0 if amulet.is_over() else 6.0)))
	draw_circle(o, RADIUS - WIDTH, core)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, o + Vector2(-14, 12), String(amulet.row.get("glyph", "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_string(font, o + Vector2(RADIUS + WIDTH + 12, 10), "%s  %d%%" % [amulet.display_name(), roundi(c)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color.WHITE)
