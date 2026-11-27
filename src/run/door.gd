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
	return String(info.get("type", "")) in ["god", "rod", "surica", "loot", "heal", "arms"]

func _god_name(g: String) -> String:
	return String((Tune.table("gods").get(g, {}) as Dictionary).get("name", g))

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var col := colour()
	var a := 1.0 if active else 0.35
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
