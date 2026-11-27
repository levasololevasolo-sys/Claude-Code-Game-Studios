## Screenshots for the visual upgrade (design/art/visual-upgrade-plan.md §4):
## plays the hero through a room of each location and saves vis-*.png into
## out_dir. Started by world.gd with `-- --vis-shots=<dir>`; quits when done.
## `--vis-before=<png>` adds vis-before-after-forest.png (old shot left, new right).
extends Node

var out_dir: String = "user://vis"
var before_png: String = ""
var _w: World

func _ready() -> void:
	_w = get_parent() as World
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vis-before="):
			before_png = a.trim_prefix("--vis-before=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _frames(n: int, keys: Dictionary = {}) -> void:
	var p: Player = _w.player
	p.scripted = true
	for i in n:
		p.fake = keys
		await p.stepped
	p.fake = {}

func _shot(file: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("[vis] shot ", file)
	return img

func _room(tier: int, k: int) -> void:
	_w.tier = tier
	_w.room_k = k
	_w.start_room()
	await get_tree().process_frame
	await _frames(30)

## Highest platform within reach of x, or null.
func _plat_near(x: float) -> Variant:
	var best: Variant = null
	for p: Vector3 in _w.room.layout.plats:
		if p.x < x + 500.0 and p.x + p.z > x - 200.0 and p.y < Tune.f("ground_y") - 100.0:
			if best == null or absf(p.x - x) < absf((best as Vector3).x - x):
				best = p
	return best

func _run() -> void:
	# Forest (Тёмный бор) first.
	await _room(2, 2)
	await _frames(40, { "move_right": true })
	await _frames(20)
	var after := await _shot("vis-01-clean-screen.png")
	await _shot("vis-02-glow-forest.png")
	await _frames(120, { "move_right": true })
	await _frames(15)
	await _shot("vis-03-parallax-forest.png")
	var pl: Variant = _plat_near(_w.player.position.x)
	if pl != null:
		var p3 := pl as Vector3
		_w.player.position = Vector2(p3.x + p3.z * 0.5, p3.y - 2.0)
		_w.player.velocity = Vector2.ZERO
		await _frames(50)
	await _shot("vis-04-platforms.png")
	await _frames(60, { "move_left": true })
	await _shot("vis-08-camera.png")
	# Jump and land for the dust.
	_w.player.position = Vector2(_w.player.position.x, Tune.f("ground_y") - 300.0)
	_w.player.velocity = Vector2.ZERO
	for i in 90:
		await _frames(1, { "move_right": true })
		if _w.player.is_on_floor():
			break
	await _frames(3)
	await _shot("vis-09-particles-forest.png")
	if before_png != "" and FileAccess.file_exists(before_png):
		var b := Image.load_from_file(before_png)
		b.resize(after.get_width(), after.get_height())
		var pair := Image.create(after.get_width() * 2 + 16, after.get_height(), false, after.get_format())
		pair.fill(Color.BLACK)
		b.convert(after.get_format())
		pair.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i.ZERO)
		pair.blit_rect(after, Rect2i(Vector2i.ZERO, after.get_size()), Vector2i(after.get_width() + 16, 0))
		pair.save_png(out_dir.path_join("vis-before-after-forest.png"))
	# Swamp (Топь) and frost (Морена).
	await _room(1, 2)
	await _frames(80, { "move_right": true })
	await _frames(20)
	await _shot("vis-11-swamp.png")
	await _room(3, 2)
	await _frames(80, { "move_right": true })
	await _frames(20)
	await _shot("vis-12-frost.png")
	get_tree().quit()
