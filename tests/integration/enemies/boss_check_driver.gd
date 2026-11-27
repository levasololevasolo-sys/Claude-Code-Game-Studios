## Scripted lair boss check (GDD enemies-and-elites §3.8-3.9): builds the lair
## with its platforms, wakes Кикимора, and a scripted hero (high hp, strikes
## with a heavy hit) fights her through phase 1, the 65% summon, the rage at 50%
## (water rises), the 30% summon, until she dies. Checks the intro / rage / death
## lines, at least 4 different attacks with wind-ups, summons, water, and that
## minions and hazards vanish with her. Saves <out_dir>/boss-kikimora-intro.png,
## -attack.png, -phase2.png, -dead.png and boss-check-log.txt.
## Started by world.gd with `-- --boss-check=<dir>`.
extends Node

## Damage of one scripted hero blow (the hero's own weapon is too weak to finish
## her inside the check's time budget).
const BLOW: float = 34.0
const BLOW_GAP: int = 30

var out_dir: String = "user://boss_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []
var _boss: LairBoss

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[boss-check] ", s)
	_lines.append(s)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	_note(("OK   " if cond else "FAIL ") + what)

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Keeps the hero alive and near her; strikes every BLOW_GAP frames until `cond`.
func _fight(cond: Callable, max_frames: int, blow: float = BLOW) -> bool:
	var p := _w.player
	for i in max_frames:
		if not is_instance_valid(_boss) or cond.call():
			return is_instance_valid(_boss) and cond.call() or not is_instance_valid(_boss)
		p.hp = maxf(p.hp, 500.0)
		var dx := _boss.position.x - p.position.x
		p.fake = { &"move_right": dx > 160.0, &"move_left": dx < -160.0, &"strike": false }
		if blow > 0.0 and i % BLOW_GAP == 0 and absf(dx) < 260.0 and not _boss.dead and _boss.summon_queue.is_empty() and _boss.st != "summon_w":
			var h := Hit.make(Hit.Kind.STRIKE, blow, p.position.x, 0.0)
			h.source = p
			_boss.hurt(h)
		await get_tree().physics_frame
	p.fake = {}
	return is_instance_valid(_boss) and cond.call()

func _run() -> void:
	var lw := Tune.f("lair_room_w")
	var layout := { "w": lw, "plats": LairBoss.arena_plats(), "packs": [], "portal": false, "lair": true }
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_w.start_room(layout, rng)
	await _frames(2)
	var p := _w.player
	p.scripted = true
	p.hp = 500.0
	_boss = LairBoss.new()
	_boss.title = String(Tune.row("locations", "1").get("boss_name", "Кикимора Болотная"))
	_w.spawn_enemy(_boss, Vector2(lw * 0.6, Tune.f("ground_y")), 0, true, 12345)
	await _frames(3)
	_ok(_boss.asleep and _boss.max_hp == float(Tune.row("bosses", "kikimora").hp), "she sleeps, hp %d" % _boss.max_hp)
	p.position = Vector2(_boss.position.x - 420.0, Tune.f("ground_y"))
	_w.cam.reset_smoothing()
	var ok := await _fight(func() -> bool: return _boss.line_t > 0.0 and _boss.line != "", 120, 0.0)
	_ok(ok, "intro line: %s" % _boss.line)
	await _frames(20)
	await _shot("boss-kikimora-intro.png")
	# The pendulums' warning: her wind-up glow, then glowing columns over the hero.
	ok = await _fight(func() -> bool: return _boss.hazards.any(func(hz: Dictionary) -> bool: return hz.kind == "pend" and float(hz.t) > 0.5), 1800, 0.0)
	await _shot("boss-kikimora-attack.png")
	_ok(ok, "attack wind-up seen: %s" % [_boss.attack_log])
	ok = await _fight(func() -> bool: return _boss.minions.size() > 0, 1800)
	_ok(ok, "summon at 65%%: %d minions (hp %d)" % [_boss.minions.size(), _boss.hp])
	ok = await _fight(func() -> bool: return _boss.phase >= 2, 1800)
	_ok(ok and _boss.st == "roar", "rage below 50%%: phase %d, line «%s»" % [_boss.phase, _boss.line])
	var marks := 0
	ok = await _fight(func() -> bool: return _boss.water >= float(Tune.row("bosses", "kikimora").water_h) - 0.5, 400, 0.0)
	_ok(ok, "water rose to %d px" % _boss.water)
	p.position.x = _boss.position.x - 300.0
	await _frames(2)
	await _shot("boss-kikimora-phase2.png")
	# Let her show the phase-2 pattern (the wave) before finishing her.
	ok = await _fight(func() -> bool: return _distinct(_boss.attack_log) >= 4, 2400, 0.0)
	_ok(ok, "4 different attacks: %s" % [_boss.attack_log])
	ok = await _fight(func() -> bool: return _boss.summons_done >= 2, 1800)
	_ok(ok, "second summon at 30%%: summons %d" % _boss.summons_done)
	for m in _boss.minions:
		if is_instance_valid(m) and not m.dead:
			marks += 1
	ok = await _fight(func() -> bool: return _boss.dead, 3000, BLOW * 2.0)
	_ok(ok, "she dies")
	await _frames(30)
	await _shot("boss-kikimora-dead.png")
	_ok(_boss.line != "" and _boss.line_t > 0.0, "death line: %s" % _boss.line)
	var left := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e as Enemy).dead:
			left += 1
	_ok(left == 0 and _boss.hazards.is_empty() and _boss.water == 0.0, "minions (%d alive before) and hazards vanished: %d enemies left" % [marks, left])
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("boss-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)

func _distinct(a: Array) -> int:
	var seen := {}
	for x: Variant in a:
		seen[x] = true
	return seen.size()
