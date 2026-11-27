## The room's reward lying at the right edge near the doors (GDD room-generation
## §3.7). Shows the promised reward's sign; the director collects it when the
## hero touches it. Placeholder look.
class_name RewardOrb
extends Node2D

## {type, god} of the reward.
var info: Dictionary = {}
var _t: float = 0.0

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	var g := String(info.get("god", ""))
	var col := Enemy.god_colour(g) if info.get("type") == "god" else Color(String((Tune.table("doors").get(String(info.get("type", "")), {}) as Dictionary).get("colour", "#ffd27a")))
	var c := Vector2(0, -60 + sin(_t * 3.0) * 6.0)
	draw_circle(c, 46, Color(col, 0.15))
	GodGlyph.door_icon(self, String(info.get("type", "")), g, c, 28.0, col)
	draw_string(ThemeDB.fallback_font, Vector2(-80, -122), "награда", HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(1, 1, 1, 0.8))
