## A door of the fork (GDD room-generation §3.8): frame, reward sign above it
## and the line «за следующей комнатой: …». Inert while `active` is false. The
## RunDirector decides what entering it does; the door only shows and reports
## whether the hero stands in front of it. Placeholder look.
class_name Door
extends Node2D

## {type, god} (DoorRules), or a route door type: lair, haven, next_loc, base.
var info: Dictionary = {}
var active: bool = true
## Hero is in front (set by the director each tick; shows the E hint).
var near: bool = false
## Extra text line (e.g. confirm prompt).
var note: String = ""

const W: float = 96.0
const H: float = 170.0

## Text under the sign (doors.json label).
func label() -> String:
	var type := String(info.get("type", ""))
	var row: Dictionary = Tune.table("doors").get(type, {})
	var text := String(row.get("label", type))
	if text.contains("%s"):
		text = text % String(info.get("arg", _god_name(String(info.get("god", "")))))
	return text

## Colour of the sign: the god's colour, else doors.json.
func colour() -> Color:
	var g := String(info.get("god", ""))
	if info.get("type") == "god" and g != "":
		return Enemy.god_colour(g)
	var c := String((Tune.table("doors").get(String(info.get("type", "")), {}) as Dictionary).get("colour", "#cccccc"))
	return Color(c if c != "" else "#cccccc")

## True when it is a reward door (the line starts «за следующей комнатой:»).
func is_reward_door() -> bool:
	return String(info.get("type", "")) in ["god", "rod", "surica", "loot", "heal", "arms", "svarog"]

## Горн Сварога (gods-expansion §3.12): a stone forge mouth around the door,
## coals glowing inside, sparks rising. Drawn under the frame.
func _draw_forge(col: Color, a: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	for i in 6:
		draw_circle(Vector2(0, -H * 0.45), 150.0 - i * 20.0, Color(col, 0.035 * (i + 1) * a))
	var stone := Color("#4a3a30")
	var pts := PackedVector2Array()
	for k in 13:
		var ang := PI + k * PI / 12.0
		pts.append(Vector2(cos(ang) * (W / 2.0 + 26.0), -H + 10.0 + sin(ang) * 34.0))
	pts.append(Vector2(W / 2.0 + 26.0, 0))
	pts.append(Vector2(-W / 2.0 - 26.0, 0))
	draw_colored_polygon(pts, Color(stone, a))
	for k in 6:
		var y := -H + 30.0 + k * 26.0
		draw_line(Vector2(-W / 2.0 - 26.0, y), Vector2(-W / 2.0 - 2.0, y), Color(0.15, 0.1, 0.08, a), 2.0)
		draw_line(Vector2(W / 2.0 + 2.0, y + 13.0), Vector2(W / 2.0 + 26.0, y + 13.0), Color(0.15, 0.1, 0.08, a), 2.0)
	for k in 7:
		var sx := sin(t * 1.7 + k * 2.1) * 30.0
		var sy := -fmod(t * 60.0 + k * 37.0, 200.0)
		draw_circle(Vector2(sx, -H * 0.2 + sy), 2.5, Color(1.0, 0.75, 0.3, (1.0 + sy / 200.0) * a))
	queue_redraw()

func _god_name(g: String) -> String:
	return String((Tune.table("gods").get(g, {}) as Dictionary).get("name", g))

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var col := colour()
	var a := 1.0 if active else 0.35
	if String(info.get("type", "")) == "svarog":
		_draw_forge(col, a)
	draw_rect(Rect2(-W / 2.0, -H, W, H), Color(0.05, 0.06, 0.07, 0.95 * a))
	draw_rect(Rect2(-W / 2.0, -H, W, H), Color(col, a), false, 4.0 if near else 2.5)
	draw_rect(Rect2(-W / 2.0 + 10, -H + 12, W - 20, H - 12), Color(col, 0.18 * a))
	GodGlyph.door_icon(self, String(info.get("type", "")), String(info.get("god", "")), Vector2(0, -H - 52), 30.0, Color(col, a))
	var lines: PackedStringArray = []
	if is_reward_door():
		lines.append("за следующей комнатой:")
	lines.append(label())
	if note != "":
		lines.append(note)
	elif near and active:
		lines.append("E — войти")
	for i in lines.size():
		var fs := 13 if i == 0 and is_reward_door() else 15
		draw_string(font, Vector2(-90, -H - 100 - (lines.size() - 1 - i) * 18), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 180, fs, Color(1, 1, 1, a) if i > 0 or not is_reward_door() else Color(0.8, 0.8, 0.75, a))
