## Aim line and reticle of the secondary weapon (GDD weapons-and-loot §3.4
## «Прицел», design/ux/hud.md §4): while the hero holds `aim` with an aimable
## secondary weapon, a thin dotted line runs from the hand along the aim for the
## shot's reach and fades out, and a ring marks the cursor (mouse) or the line's
## end (gamepad). The OS cursor is hidden only then, and shown again on release,
## pause or when this node leaves the tree, so menus always keep it.
## Child of Player; draws in world space (top_level). Reads, never writes, the hero.
class_name AimReticle
extends Node2D

const COLOR := Color("#ffe2a8")
const DOT: float = 6.0
const GAP: float = 10.0

var hero: Player
var _hid_cursor: bool = false

func _ready() -> void:
	top_level = true
	z_index = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

## True when the line is shown this frame.
func showing() -> bool:
	return hero != null and is_instance_valid(hero) and not hero.dead and hero.sub != null \
		and hero.aiming_with(hero.sub.row()) and not get_tree().paused

func _process(_dt: float) -> void:
	var on := showing()
	_set_cursor_hidden(on and not hero.aim_pad and not hero.scripted)
	visible = on
	if on:
		queue_redraw()

func _exit_tree() -> void:
	_set_cursor_hidden(false)

func _set_cursor_hidden(h: bool) -> void:
	if h == _hid_cursor or DisplayServer.get_name() == "headless":
		return
	if h and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return
	_hid_cursor = h
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if h else Input.MOUSE_MODE_VISIBLE

func _draw() -> void:
	if not showing():
		return
	var from := hero.hand()
	var d := hero.aim_dir
	var length := AimRules.line_length(hero.sub.row(), Tune.f("aim_line_len"))
	var a0 := Tune.f("aim_line_alpha")
	var t := 0.0
	while t < length:
		var k := 1.0 - t / length
		var p := from + d * t
		draw_line(p, p + d * minf(DOT, length - t), Color(COLOR, a0 * k), 2.0)
		t += DOT + GAP
	var mark := from + d * length
	if not hero.aim_pad:
		mark = hero.fake_aim_point if hero.scripted else get_global_mouse_position()
	draw_arc(mark, 11.0, 0.0, TAU, 24, Color(COLOR, 0.9), 2.0)
	for q: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(mark + q * 6.0, mark + q * 16.0, Color(COLOR, 0.9), 2.0)
	draw_circle(mark, 1.5, Color(COLOR, 0.9))
