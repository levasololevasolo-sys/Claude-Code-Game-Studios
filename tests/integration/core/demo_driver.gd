## Scripted check of the core: plays a fixed input sequence on the main scene and
## saves screenshots plus a log of numbers into out_dir. Started by main.gd with
## `-- --demo=<dir>`; quits when done.
extends Node

var out_dir := "user://demo"
var log_lines: PackedStringArray = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _frames(n: int, keys: Dictionary = {}) -> void:
	var p: Player = get_parent().player
	p.scripted = true
	for i in n:
		p.fake = keys
		await get_tree().physics_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	log_lines.append("shot %s" % name)

func _note(s: String) -> void:
	log_lines.append(s)
	print("[demo] ", s)

func _nearest_dummy(p: Player) -> StrawDummy:
	var best: StrawDummy = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if best == null or absf(e.position.x - p.position.x) < absf(best.position.x - p.position.x):
			best = e
	return best

func _run() -> void:
	var main := get_parent()
	await _frames(20)
	var p: Player = main.player
	_note("start x=%.0f y=%.0f on_floor=%s room_w=%d dummies=%d plats=%d" % [p.position.x, p.position.y, p.is_on_floor(), main.room.layout.w, get_tree().get_nodes_in_group("enemies").size(), main.room.layout.plats.size()])
	await _shot("01_start")
	await _frames(40, { "move_right": true })
	_note("after run x=%.0f vx=%.0f" % [p.position.x, p.velocity.x])
	await _frames(1, { "move_right": true, "jump": true })
	await _frames(12, { "move_right": true, "jump": true })
	_note("jump apex-ish y=%.0f vy=%.0f" % [p.position.y, p.velocity.y])
	await _shot("02_jump")
	await _frames(40)
	# side combo next to a dummy
	var d := _nearest_dummy(p)
	p.position = Vector2(d.position.x - 70, d.position.y)
	p.face = 1
	await _frames(5)
	var hp0 := d.hp
	for i in 3:
		await _frames(1, { "strike": true })
		await _frames(i * 2 + 6)
		if i == 2:
			await _shot("03_combo_finisher")
		await _frames(14 - i * 2)
	_note("combo dummy hp %.0f -> %.0f" % [hp0, d.hp])
	await _frames(30)
	# up strike
	p.position = Vector2(d.position.x - 30, d.position.y)
	await _frames(3)
	await _frames(1, { "strike": true, "move_up": true })
	await _frames(8, { "move_up": true })
	await _shot("04_up_strike")
	_note("up strike: dummy vy=%.0f y=%.0f" % [d.vel.y, d.position.y])
	await _frames(60)
	# down strike pogo: put hero above the dummy
	p.position = Vector2(d.position.x, d.position.y - 200)
	p.velocity = Vector2.ZERO
	await _frames(2)
	await _frames(1, { "strike": true, "move_down": true })
	var pogo := false
	for i in 30:
		await _frames(1, { "move_down": true })
		if p.velocity.y < -300:
			pogo = true
			break
	await _shot("05_down_pogo")
	_note("down strike pogo=%s vy=%.0f" % [pogo, p.velocity.y])
	await _frames(60)
	# slam: down strike from high in the open
	p.position = Vector2(d.position.x - 400, d.position.y - 300)
	p.velocity = Vector2.ZERO
	await _frames(2)
	await _frames(1, { "strike": true, "move_down": true })
	await _frames(30, { "move_down": true })
	_note("slam done=%s rings=%d" % [p.slammed, main.rings.size()])
	await _frames(30)
	# ground roll and air dash
	var x0 := p.position.x
	await _frames(1, { "dash": true, "move_right": true })
	await _frames(8, { "move_right": true })
	await _shot("06_roll")
	await _frames(20)
	_note("roll moved %.0f px, rolling=%s" % [p.position.x - x0, p.rolling])
	await _frames(1, { "jump": true })
	await _frames(14, { "jump": true })
	await _frames(1, { "dash": true, "move_right": true, "jump": true })
	await _frames(5, { "move_right": true })
	await _shot("07_air_dash")
	_note("air dash rolling=%s ghosts=%d" % [p.rolling, p.ghosts.size()])
	await _frames(60)
	# platform: find one at the lowest level and jump onto it
	var plat: Vector3 = main.room.layout.plats[0]
	for q: Vector3 in main.room.layout.plats:
		if q.y >= 520.0:
			plat = q
			break
	p.position = Vector2(plat.x + plat.z / 2.0, plat.y - 80)
	p.velocity = Vector2.ZERO
	await _frames(40)
	_note("platform y=%.0f hero y=%.0f on_floor=%s" % [plat.y, p.position.y, p.is_on_floor()])
	await _shot("08_platform")
	await _frames(3, { "move_down": true, "jump": true })
	_note("drop frame: drop_t=%.2f mask2=%s jump_buf=%.2f" % [p.drop_t, p.get_collision_mask_value(2), p.jump_buf])
	await _frames(30, { "move_down": true })
	_note("drop through: hero y=%.0f (ground %.0f)" % [p.position.y, Tune.f("ground_y")])
	var f := FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	f.close()
	get_tree().quit()
