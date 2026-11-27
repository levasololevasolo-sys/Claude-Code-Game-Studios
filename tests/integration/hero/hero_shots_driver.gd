## Scripted look check of the hero rig (ADR-0005 Validation): plays idle, run, a
## side swing, a roll and a down strike on open ground and saves a 1080p crop
## around the hero for each: hero-t<tier>-<pose>.png in out_dir. Started by
## world.gd with `-- --hero-shots=<dir> --hero-tier=<1..5>`; quits when done.
extends Node

var out_dir: String = "user://hero"
## Crop around the hero, screen px.
const CROP: Vector2i = Vector2i(520, 440)
var _main: World
var _tier: int = 1

func _ready() -> void:
	_main = get_parent() as World
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero-tier="):
			_tier = int(a.trim_prefix("--hero-tier="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()

func _frames(n: int, keys: Dictionary = {}) -> void:
	var p: Player = _main.player
	p.scripted = true
	for i in n:
		p.fake = keys
		await p.stepped
	p.fake = {}

func _shot(pose_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p: Player = _main.player
	var sp: Vector2 = get_viewport().get_canvas_transform() * p.global_position
	var sz := img.get_size()
	var x := clampi(int(sp.x) - CROP.x / 2, 0, sz.x - CROP.x)
	var y := clampi(int(sp.y) - CROP.y + 90, 0, sz.y - CROP.y)
	var crop := img.get_region(Rect2i(x, y, CROP.x, CROP.y))
	crop.save_png(out_dir.path_join("hero-t%d-%s.png" % [_tier, pose_name]))
	print("[hero] shot t%d %s at %s" % [_tier, pose_name, str(sp)])

func _run() -> void:
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	var p: Player = _main.player
	# a calm room: no darkness over the hero, so the art is judged as drawn
	if _main.darkness:
		_main.darkness.visible = false
	await _frames(40)
	await _shot("idle")
	await _frames(24, { "move_right": true })
	await _shot("run")
	await _frames(30)
	await _frames(1, { "strike": true })
	await _frames(5)
	await _shot("swing")
	await _frames(40)
	await _frames(1, { "dash": true, "move_right": true })
	await _frames(7, { "move_right": true })
	await _shot("roll")
	await _frames(40)
	p.position = Vector2(p.position.x + 200, Tune.f("ground_y") - 260)
	p.velocity = Vector2.ZERO
	await _frames(2)
	await _frames(1, { "strike": true, "move_down": true })
	await _frames(9, { "move_down": true })
	await _shot("down")
	get_tree().quit()
