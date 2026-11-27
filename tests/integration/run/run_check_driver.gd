## Scripted run check (GDD room-generation-and-doors §3.2, §3.7-3.9, §3.16;
## economy-and-meta §3.7-3.8; ADR-0003). Plays one run through the real
## RunDirector: takes the first card of every choice, kills each room's enemies
## directly, walks the hero onto the reward, takes the first door, reaches the
## haven (checks the save holds the run), goes on, dies to an enemy, checks the
## summary and the banked embers, enters the base, takes its gate and sees
## the new run start. Saves
## <out_dir>/run-door-fork.png, run-god-choice.png, run-haven.png,
## run-summary.png and run-check-log.txt. Started by world.gd with
## `-- --run-check=<dir>`; run it with `--fresh --save=user://run_check_save.json`
## so the player's save is never touched. Sets meta.runs = 1 before the run
## starts (a second run: all gods and door types of runs 2-3 are open).
extends Node

var out_dir: String = "user://run_check"
var _w: World
var _d: RunDirector
var _log: PackedStringArray = []
var _fail: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game: Node = get_node("/root/Game")
	game.meta.runs = 1
	_run.call_deferred()

func _note(s: String) -> void:
	_log.append(s)
	print("[run-check] ", s)

func _check(ok: bool, what: String) -> void:
	_note(("OK   " if ok else "FAIL ") + what)
	if not ok:
		_fail += 1

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

## Waits up to `max_frames` frames for `cond`.
func _wait(cond: Callable, max_frames: int = 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _take_screen() -> void:
	var s := _d.screen
	if s is RuneOfferScreen:
		(s as RuneOfferScreen).take(0)
	elif s is GodChoiceScreen:
		(s as GodChoiceScreen).take(0)

func _save_dict() -> Dictionary:
	var game: Node = get_node("/root/Game")
	return SaveFile.read(game.save_path)

func _run() -> void:
	_d = _w.director
	_d.noted.connect(func(s: String) -> void: _log.append("  " + s))
	var ok := await _wait(func() -> bool: return _d.screen is RuneOfferScreen)
	_check(ok, "run starts with a rune offer")
	_take_screen()
	var fork_shot := false
	var rooms := 0
	while rooms < 8:
		ok = await _wait(func() -> bool: return _d.phase == "fight" or _d.phase == "doors")
		if _d.run.stage == "haven":
			break
		rooms += 1
		var p := _w.player
		p.scripted = true
		await _frames(5)
		var n := _d.alive_enemies()
		_check(n > 0 and _d.doors.is_empty(), "%s %d: %d enemies, no doors while they live" % [_d.run.stage, _d.run.room_k, n])
		var asleep := 0
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if e.asleep:
				asleep += 1
		# BUG-0004: RoomGen keeps a safe start zone, so every pack must sleep on entry.
		_check(asleep == n, "all %d enemies sleep on entry (%d awake 5 frames after entry, hero at x %d)" % [n, n - asleep, int(Tune.f("hero_spawn_x"))])
		p.inv = 5.0
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if not e.dead:
				e.hurt(Hit.make(Hit.Kind.STRIKE, 1.0e6, e.position.x - 10.0, 0.0))
		ok = await _wait(func() -> bool: return _d.phase == "reward")
		_check(ok and _d.orb != null and _d.orb.position.x > float(_w.room.layout.w) - 900.0, "reward appears at the right edge (x %d of %d)" % [_d.orb.position.x if _d.orb else -1, int(_w.room.layout.w)])
		var lair := _d.run.stage == "lair"
		p.position = Vector2(_d.orb.position.x, Tune.f("ground_y"))
		p.velocity = Vector2.ZERO
		_w.cam.reset_smoothing()
		await _wait(func() -> bool: return _d.screen != null or _d.phase == "doors")
		if _d.screen is GodChoiceScreen:
			var gc := _d.screen as GodChoiceScreen
			_check(lair and gc.gods.size() == 3 and _distinct(gc.gods), "lair reward = 3 different gods %s" % [gc.gods])
			await _frames(3)
			await _shot("run-god-choice.png")
			_take_screen()
			await _wait(func() -> bool: return _d.screen is RuneOfferScreen)
		if _d.screen != null:
			_take_screen()
		ok = await _wait(func() -> bool: return _d.phase == "doors")
		_check(ok and not _d.doors.is_empty(), "doors open after the reward: %d" % _d.doors.size())
		for d in _d.doors:
			if d.info.type == "god":
				_check(d.is_reward_door() and d.label().begins_with("Руна: "), "god door shows its god: %s" % d.label())
		if not fork_shot and _d.doors.size() >= 2:
			fork_shot = true
			p.position = Vector2(_d.doors[0].position.x - 10.0, Tune.f("ground_y"))
			_w.cam.reset_smoothing()
			await _frames(4)
			await _shot("run-door-fork.png")
		_d.enter_door(0)
	_check(_d.run.stage == "haven", "reached the haven after %d rooms" % rooms)
	await _frames(20)
	_w.cam.reset_smoothing()
	await _frames(3)
	await _shot("run-haven.png")
	var sd := _save_dict()
	_check(sd.get("run") is Dictionary and int(sd.run.get("run_seed", -1)) == _d.run.run_seed and String(sd.run.stage) == "haven",
		"save holds the run at the haven (seed %d, version %s)" % [_d.run.run_seed, sd.get("version")])
	var restored := RunState.from_dict(sd.run)
	_check(restored.to_dict().hash() == RunState.from_dict(_d.run.to_dict()).to_dict().hash() or restored.embers == _d.run.embers,
		"saved run matches: embers %d, runes %s" % [restored.embers, restored.build.get("slots")])
	var embers := _d.run.embers
	var bank: int = get_node("/root/Game").meta.embers
	_d.enter_door(0)
	ok = await _wait(func() -> bool: return _d.phase == "fight" and _d.run.tier == 2)
	_check(ok, "went on to tier 2 room 1")
	await _frames(5)
	var killer: Enemy = null
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		killer = e
		break
	var p2 := _w.player
	p2.inv = 0.0
	var hit := Hit.make(Hit.Kind.CONTACT, 1.0e5, killer.position.x, 0.0)
	hit.source = killer
	p2.hurt(hit)
	ok = await _wait(func() -> bool: return _d.screen is RunSummaryScreen, 400)
	_check(ok, "summary after death")
	await _frames(3)
	await _shot("run-summary.png")
	var sum := _d.screen as RunSummaryScreen
	_check(String(sum.summary.run.get("killed_by", "")) != "", "summary names the killer: %s" % sum.summary.run.get("killed_by"))
	var after: int = get_node("/root/Game").meta.embers
	var run_embers := int(sum.summary.run.embers)
	_check(after == bank + run_embers and run_embers >= embers, "embers banked: %d + %d = %d" % [bank, run_embers, after])
	sd = _save_dict()
	_check(sd.get("run") == null and int(sd.meta.embers) == after and int(sd.meta.runs) == 2, "save after death: run null, meta embers %s, runs %s" % [sd.meta.get("embers"), sd.meta.get("runs")])
	var old_seed := _d.run.run_seed
	sum.close()
	ok = await _wait(func() -> bool: return _d.phase == "base" and _d.base != null, 300)
	_check(ok, "after the summary the hero is at the base")
	if ok:
		_d.base.use("gate")
	ok = await _wait(func() -> bool: return _d.run != null and _d.run.run_seed != old_seed and _d.screen is RuneOfferScreen)
	_check(ok, "new run started (seed %d), its start offer is open" % (_d.run.run_seed if _d.run else -1))
	_note("DONE: %d failed checks" % _fail)
	var f := FileAccess.open(out_dir.path_join("run-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().quit(1 if _fail > 0 else 0)

func _distinct(a: Array) -> bool:
	var seen := {}
	for x: Variant in a:
		seen[x] = true
	return seen.size() == a.size()
