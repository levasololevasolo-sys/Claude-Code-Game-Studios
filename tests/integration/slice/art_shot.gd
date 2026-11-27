## Art slice screenshot at 1920x1080 (the project window override is 1280x720, so
## --write-movie captures 720p). Runs the main scene with the user args, resizes
## the window, saves frame `--shot-frame=` (default 70) to `--shot=<png>`, quits.
##   xvfb-run -a godot --path . -s res://tests/integration/slice/art_shot.gd -- --shot=/tmp/a.png --room=2 --seed=3 [--hero-art=sprite --art-slice --art-stage]
extends SceneTree

var _out: String = "user://art_shot.png"
var _at: int = 70
var _n: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_out = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-frame="):
			_at = int(a.trim_prefix("--shot-frame="))
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/main.tscn")


func _process(_dt: float) -> bool:
	_n += 1
	if _n == 2:
		root.size = Vector2i(1920, 1080)
	if _n == _at:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("art_shot: saved %s %dx%d" % [_out, img.get_width(), img.get_height()])
		return true
	return false
