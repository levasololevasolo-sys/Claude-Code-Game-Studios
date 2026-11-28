## Starts the music check (music_check_driver.gd): loads the main scene and adds
## the driver. A SceneTree script cannot name autoloads, so the checks live there.
##   godot --headless -s res://tests/integration/core/music_check.gd
extends SceneTree

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	root.add_child.call_deferred((load("res://tests/integration/core/music_check_driver.gd") as GDScript).new())
