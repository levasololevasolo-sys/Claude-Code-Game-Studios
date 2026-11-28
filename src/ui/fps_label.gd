## Frame counter for the player (F3 toggles): «60 FPS» in the top right corner,
## so a slow PC can be checked without the editor. Off by default. Visual only.
class_name FpsLabel
extends Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	position = Vector2(1760, 8)
	size = Vector2(150, 40)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 26)
	add_theme_color_override("font_color", Color("#e0c27a"))
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 6)

func _process(_dt: float) -> void:
	if visible:
		text = "%d FPS" % Engine.get_frames_per_second()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo and (ev as InputEventKey).keycode == KEY_F3:
		visible = not visible
