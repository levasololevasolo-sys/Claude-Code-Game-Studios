## QA play driver (Integration, tests/integration/qa/, gate: BLOCKING evidence for
## the first-play QA pass, qa-report-2026-11-27). Plays the DEFAULT game (the
## real main.tscn with no check flags, so the RunDirector run mode) by injecting
## real InputEventKey events (keycode + physical_keycode) — the same path a
## keyboard takes: InputMap actions for the hero, _unhandled_input for screens.
## Holds right, chases and strikes enemies, jumps, dashes, uses the Flare, walks
## to the reward and through doors, picks cards on screens, survives death.
## Logs anomalies as "ANOMALY <kind>": STUCK (hero x moved < 4 px in 10 s of
## game time outside screens), NO_DOORS (room clear but no doors 8 s later),
## ENEMY_OOB, HERO_FALL, HERO_OOB, HP_NAN, UNREACHABLE (target enemy took no
## damage for 30 s), ROOM_SLOW (fight > 60 s; after 90 s the rest is killed and
## ASSIST is logged), SCREEN_SNAP (a choice screen closed < 0.3 s after opening).
## Run: godot --path . --fixed-fps 60 res://tests/integration/qa/qa_play.tscn
##        -- --fresh --save=user://qa_play_save.json --seed=<n> --qa-out=<dir>
## Writes <dir>/qa-play-log.txt and screenshots; quits after --qa-seconds=
## (default 180) of unpaused game time.
extends Node

var out_dir: String = "/tmp/claude-0/qa/play"
var game_seconds: float = 180.0
var world: World
var d: RunDirector
var rng := RandomNumberGenerator.new()
var _log: PackedStringArray = []
var _held: Dictionary = {}
var _queue: Array = []  # [frame, keycode, pressed]
var _frame: int = 0
var _game_frames: int = 0
var _anom: Dictionary = {}
var _shots: int = 0
var _last_x: float = 0.0
var _last_x_frame: int = 0
var _phase_frame: int = 0
var _last_phase: String = ""
var _clear_seen_frame: int = -1
var _room_frame: int = 0
var _room_name: String = ""
var _target: Enemy = null
var _target_hp: float = 0.0
var _target_frame: int = 0
var _door_pick: int = -1
var _screen: Control = null
var _screen_frame: int = 0
var _screen_acted: bool = false
var _next_dash: int = 120
var _rooms: int = 0
var _deaths: int = 0
var _runs: int = 1
var _assist_done: bool = false
var _block_frame: int = 0
var _counts: Dictionary = {}
var _done: bool = false
## --qa-mash: tap J every 9 frames even while a screen is open (a player mashing attack).
var mash: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var s := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="):
			out_dir = a.trim_prefix("--qa-out=")
		elif a.begins_with("--seed="):
			s = int(a.trim_prefix("--seed="))
		elif a == "--qa-mash":
			mash = true
		elif a.begins_with("--qa-seconds="):
			game_seconds = float(a.trim_prefix("--qa-seconds="))
	rng.seed = s * 31 + 7
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	d = world.director
	if d == null:
		_note("FATAL no RunDirector: the default game did not start run mode")
		_finish()
		return
	d.noted.connect(func(t: String) -> void: _log.append("  [run] " + t))
	d.room_started.connect(_on_room)
	_note("qa play seed %d, %d s of game time" % [s, int(game_seconds)])

func _note(t: String) -> void:
	_log.append("[%6.1fs] %s" % [_game_frames / 60.0, t])
	print("[qa-play] ", t)

func _anomaly(kind: String, t: String, shot: bool = true) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	_note("ANOMALY %s: %s" % [kind, t])
	if shot and int(_anom.get(kind, 0)) < 3:
		_anom[kind] = int(_anom.get(kind, 0)) + 1
		_shot("anom-%s-%d.png" % [kind.to_lower(), _anom[kind]])

func _shot(file: String) -> void:
	if _shots > 40:
		return
	_shots += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot " + file)

func _key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code as Key
	e.physical_keycode = code as Key
	e.pressed = pressed
	Input.parse_input_event(e)

func _hold(code: int, on: bool) -> void:
	if bool(_held.get(code, false)) == on:
		return
	_held[code] = on
	_key(code, on)

func _release_all() -> void:
	for c: int in _held.keys():
		_hold(c, false)

func _tap(code: int, at: int = 0) -> void:
	_queue.append([_frame + at, code, true])
	_queue.append([_frame + at + 3, code, false])

func _on_room(stage: String, k: int) -> void:
	_rooms += 1
	_room_frame = _game_frames
	_room_name = "%s t%d k%d" % [stage, d.run.tier, k]
	_assist_done = false
	_clear_seen_frame = -1
	_door_pick = -1
	_target = null
	if _rooms <= 6 or stage != "room":
		_shot("room-%02d-%s.png" % [_rooms, stage])

func _physics_process(_dt: float) -> void:
	if _done:
		return
	_frame += 1
	for q in _queue.duplicate():
		if int(q[0]) <= _frame:
			_key(int(q[1]), bool(q[2]))
			_queue.erase(q)
	if d == null:
		return
	var paused := get_tree().paused
	_track_screen()
	if paused or d.screen != null:
		if mash and _frame % 9 == 0:
			_tap(KEY_J)
			return
		_drive_screen()
		return
	_game_frames += 1
	if _game_frames >= int(game_seconds * 60.0):
		_finish()
		return
	var p := world.player
	if p == null or not is_instance_valid(p):
		return
	_checks(p)
	match d.phase:
		"fight":
			_fight(p)
		"reward":
			_release_all()
			if d.orb:
				_walk_to(p, d.orb.position.x)
		"doors":
			_doors(p)
		"dead", "summary":
			_release_all()

func _track_screen() -> void:
	var s: Control = d.screen
	if s == null:
		for c in world.get_children():
			if c is CanvasLayer:
				for g in c.get_children():
					if g is RunSummaryScreen:
						s = g
	if s != _screen:
		if _screen != null and _frame - _screen_frame < 18:
			_anomaly("SCREEN_SNAP", "%s closed %d frames after opening" % [_screen.get_class(), _frame - _screen_frame], false)
		if s != null:
			_note("screen opened: %s" % _screen_name(s))
			_release_all()
			if int(_counts.get("screen_" + _screen_name(s), 0)) < 1:
				_counts["screen_" + _screen_name(s)] = 1
				_shot("screen-%s.png" % _screen_name(s).to_lower())
		_screen = s
		_screen_frame = _frame
		_screen_acted = false

func _screen_name(s: Control) -> String:
	if s is RuneOfferScreen:
		return "RuneOffer_" + (s as RuneOfferScreen).mode
	if s is GodChoiceScreen:
		return "GodChoice"
	if s is RunSummaryScreen:
		return "RunSummary"
	return s.get_class()

func _drive_screen() -> void:
	if _screen == null or _screen_acted or _frame - _screen_frame < 40:
		if _screen != null and _frame - _screen_frame > 600:
			_anomaly("SCREEN_HANG", "%s did not close after 10 s of input" % _screen_name(_screen))
			_screen_frame = _frame
			_screen_acted = false
		return
	_screen_acted = true
	if _screen is RunSummaryScreen:
		_deaths += 1
		_note("summary: " + " | ".join((_screen as RunSummaryScreen).lines()))
		_tap(KEY_ENTER)
		_runs += 1
		return
	match rng.randi_range(0, 3):
		0:
			_tap(KEY_1 + rng.randi_range(0, 2))
		1:
			_tap(KEY_RIGHT)
			_tap(KEY_ENTER, 6)
		2:
			_tap(KEY_A)
			_tap(KEY_J, 6)
		_:
			_tap(KEY_SPACE)
	# Retry if the first input did nothing (e.g. a digit above the card count).
	_queue.append([_frame + 120, KEY_ENTER, true])
	_queue.append([_frame + 123, KEY_ENTER, false])

func _walk_to(p: Player, x: float) -> void:
	var dx := x - p.position.x
	_hold(KEY_D, dx > 12.0)
	_hold(KEY_A, dx < -12.0)
	_unstick(p)

func _unstick(p: Player) -> void:
	if (_held.get(KEY_D, false) or _held.get(KEY_A, false)) and absf(p.velocity.x) < 5.0 and _frame - _block_frame > 30:
		_block_frame = _frame
		_tap(KEY_SPACE)

func _nearest(p: Player) -> Enemy:
	var best: Enemy = null
	var bd := INF
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not is_instance_valid(e):
			continue
		var dd := e.center().distance_to(p.position)
		if dd < bd:
			bd = dd
			best = e
	return best

func _fight(p: Player) -> void:
	var e := _nearest(p)
	var fight_s := (_game_frames - _room_frame) / 60.0
	if fight_s > 90.0 and not _assist_done:
		_assist_done = true
		_note("ASSIST: killing the rest after 90 s in %s (%d alive)" % [_room_name, d.alive_enemies()])
		for x: Enemy in get_tree().get_nodes_in_group("enemies"):
			if not x.dead:
				_note("  alive: %s st=%s asleep=%s pos=(%d,%d) hp=%d" % [x.kind_id, x.st, x.asleep, x.position.x, x.position.y, x.hp])
				x.hurt(Hit.make(Hit.Kind.STRIKE, 1.0e6, x.position.x, 0.0))  # from its own x: no front shield
		return
	if fight_s > 60.0 and int(_anom.get("ROOM_SLOW_" + _room_name, 0)) == 0:
		_anom["ROOM_SLOW_" + _room_name] = 1
		_anomaly("ROOM_SLOW", "%s fight > 60 s, %d alive" % [_room_name, d.alive_enemies()])
	if e == null:
		_walk_to(p, float(world.room.layout.w) - 200.0)
		return
	if e != _target:
		_target = e
		_target_hp = e.hp
		_target_frame = _game_frames
	elif e.hp < _target_hp:
		_target_hp = e.hp
		_target_frame = _game_frames
	elif _game_frames - _target_frame > 1800:
		_anomaly("UNREACHABLE", "%s in %s at (%d,%d) st=%s asleep=%s took no damage for 30 s; hero (%d,%d)" % [e.kind_id, _room_name, e.position.x, e.position.y, e.st, e.asleep, p.position.x, p.position.y])
		_target_frame = _game_frames
	var c := e.center()
	var dx := c.x - p.position.x
	var dy := c.y - (p.position.y - 40.0)
	var close := absf(dx) < 95.0
	# Retreat a little now and then when low.
	var low := p.hp < 30.0 and rng.randf() < 0.3
	_hold(KEY_D, (dx > 60.0) != low and absf(dx) > 60.0)
	_hold(KEY_A, (dx < -60.0) != low and absf(dx) > 60.0)
	if close and absf(dx) <= 60.0:
		_hold(KEY_D, dx > 4.0 and p.face < 0)
		_hold(KEY_A, dx < -4.0 and p.face > 0)
	_hold(KEY_W, dy < -90.0 and close)
	if close and _frame % 9 == 0:
		_tap(KEY_J)
	if dy < -110.0 and absf(dx) < 160.0 and _frame % 40 == 0:
		_tap(KEY_SPACE)
	if _frame >= _next_dash:
		_next_dash = _frame + rng.randi_range(70, 200)
		_tap(KEY_SHIFT)
	if rng.randf() < 1.0 / 150.0:
		_tap(KEY_SPACE)
	if p.amulet and p.amulet.charge >= p.amulet.cap * 0.99 and absf(dx) < 300.0 and rng.randf() < 0.05:
		_note("flare at charge %.0f" % p.amulet.charge)
		_tap(KEY_L)
	_unstick(p)

func _doors(p: Player) -> void:
	if d.doors.is_empty():
		return
	if _door_pick < 0 or _door_pick >= d.doors.size():
		var n := d.doors.size()
		_door_pick = rng.randi_range(0, n - 1)
		if String(d.doors[_door_pick].info.type) == "base" and n > 1:
			_door_pick = (_door_pick + 1) % n
		_note("doors: %s -> pick %d" % [", ".join(PackedStringArray(d.doors.map(func(x: Door) -> String: return x.label()))), _door_pick])
		if int(_counts.get("door_shot", 0)) < 3:
			_counts["door_shot"] = int(_counts.get("door_shot", 0)) + 1
			_shot("doors-%d.png" % _counts.door_shot)
	var door := d.doors[_door_pick]
	_walk_to(p, door.position.x)
	if door.near and _frame % 30 == 0:
		_release_all()
		_tap(KEY_E)

func _checks(p: Player) -> void:
	var w := float(world.room.layout.w) if world.room else 0.0
	var gy := Tune.f("ground_y")
	if is_nan(p.hp) or is_inf(p.hp):
		_anomaly("HP_NAN", "hero hp %s" % p.hp)
	if p.position.y > gy + 4.0:
		_anomaly("HERO_FALL", "hero y %.1f below ground %d in %s" % [p.position.y, gy, _room_name])
		p.position.y = gy
	if p.position.x < -8.0 or p.position.x > w + 8.0:
		_anomaly("HERO_OOB", "hero x %.1f outside 0..%d in %s" % [p.position.x, w, _room_name])
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not is_instance_valid(e):
			continue
		if is_nan(e.hp) or is_nan(e.position.x) or is_nan(e.position.y):
			_anomaly("HP_NAN", "enemy %s hp %s pos %s" % [e.kind_id, e.hp, e.position])
		if e.position.x < -20.0 or e.position.x > w + 20.0 or e.position.y > gy + 20.0 or e.position.y < -700.0:
			if not e.has_meta("qa_oob"):
				e.set_meta("qa_oob", true)
				_anomaly("ENEMY_OOB", "%s at (%d,%d) st=%s in %s (room w %d)" % [e.kind_id, e.position.x, e.position.y, e.st, _room_name, w])
	if d.phase != _last_phase:
		_last_phase = d.phase
		_phase_frame = _game_frames
	if d.phase == "fight" and d.alive_enemies() == 0:
		if _clear_seen_frame < 0:
			_clear_seen_frame = _game_frames
		elif _game_frames - _clear_seen_frame == 480:
			_anomaly("NO_DOORS", "%s: 0 enemies for 8 s, phase still fight" % _room_name)
	if d.phase == "reward" and _game_frames - _phase_frame == 900:
		_anomaly("NO_DOORS", "%s: reward phase for 15 s (orb %s, hero x %d)" % [_room_name, d.orb.position.x if d.orb else -1.0, p.position.x])
	if d.phase == "doors" and _game_frames - _phase_frame == 1200:
		_anomaly("STUCK", "%s: doors open 20 s but no door entered (hero x %d, door %d)" % [_room_name, p.position.x, _door_pick])
	if d.phase in ["fight", "reward", "doors"]:
		if absf(p.position.x - _last_x) >= 4.0:
			_last_x = p.position.x
			_last_x_frame = _game_frames
		elif _game_frames - _last_x_frame >= 600:
			_anomaly("STUCK", "hero x %d did not move 10 s in %s phase %s (held %s, vx %.0f, on_floor %s)" % [p.position.x, _room_name, d.phase, _held, p.velocity.x, p.is_on_floor()])
			_last_x_frame = _game_frames
	else:
		_last_x_frame = _game_frames

func _finish() -> void:
	if _done:
		return
	_done = true
	_release_all()
	_note("END rooms entered %d, deaths %d, runs %d, anomalies %s" % [_rooms, _deaths, _runs, _counts])
	if d and d.run:
		_note("last run: seed %d tier %d stage %s room %d hp %s embers %d kills %d" % [d.run.run_seed, d.run.tier, d.run.stage, d.run.room_k, d.run.hp, d.run.embers, d.run.kills])
	var f := FileAccess.open(out_dir.path_join("qa-play-log.txt"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_log) + "\n")
		f.close()
	_shot("end.png")
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()
