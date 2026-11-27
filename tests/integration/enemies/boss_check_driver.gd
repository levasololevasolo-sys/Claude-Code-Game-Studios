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
## Boss row id: `--boss=<id>` (kikimora default, likho = Лихо Одноглазое on tier 2).
var boss_id: String = "kikimora"
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			boss_id = a.trim_prefix("--boss=")
	if boss_id == "likho":
		await _run_likho()
		return
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
	_finish()

func _finish() -> void:
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("boss-check-log.txt" if boss_id == "kikimora" else "boss-check-%s-log.txt" % boss_id), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)

func _distinct(a: Array) -> int:
	var seen := {}
	for x: Variant in a:
		seen[x] = true
	return seen.size()

## Лихо Одноглазое (enemies-and-elites §3.10): tier 2 (forest look), intro line,
## the gaze beam and the woe zones seen, summons, rage below 50% and the
## darkness (hero light at light_min while the eye glows), 4 different attacks,
## death line and cleanup. Saves boss-likho-intro/-phase2/-dead.png.
func _run_likho() -> void:
	_w.tier = 2
	await _forest_rooms()
	var row := Tune.row("bosses", "likho")
	var lw := Tune.f("lair_room_w")
	var layout := { "w": lw, "plats": LairBoss.arena_plats("likho"), "packs": [], "portal": false, "lair": true }
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_w.start_room(layout, rng)
	await _frames(2)
	var p := _w.player
	p.scripted = true
	p.hp = 500.0
	_boss = LairBoss.make("likho")
	_boss.title = String(Tune.row("locations", "2").get("boss_name", "Лихо Одноглазое"))
	_w.spawn_enemy(_boss, Vector2(lw * 0.6, Tune.f("ground_y")), 0, true, 4242)
	await _frames(3)
	var lk := _boss as LikhoBoss
	_ok(lk != null and _boss.asleep and _boss.max_hp >= float(row.hp), "Лихо sleeps, hp %d, class %s" % [_boss.max_hp, _boss.get_script().resource_path.get_file()])
	p.position = Vector2(_boss.position.x - 420.0, Tune.f("ground_y"))
	_w.cam.reset_smoothing()
	var ok := await _fight(func() -> bool: return _boss.line_t > 0.0 and _boss.line != "", 120, 0.0)
	_ok(ok and _boss.line == String(row.lines.intro_first), "intro line: %s" % _boss.line)
	await _frames(20)
	await _shot("boss-likho-intro.png")
	ok = await _fight(func() -> bool: return _boss.st == "gaze", 2400, 0.0)
	_ok(ok, "gaze beam tracks: %s" % [_boss.attack_log])
	await _frames(25)
	await _shot("boss-likho-gaze.png")
	ok = await _fight(func() -> bool: return _boss.hazards.any(func(hz: Dictionary) -> bool: return hz.kind == "woe"), 2400, 0.0)
	_ok(ok, "woe zones: %d" % _boss.hazards.size())
	ok = await _fight(func() -> bool: return _boss.minions.size() > 0, 1800)
	_ok(ok, "summon at 65%%: %d minions (hp %d)" % [_boss.minions.size(), _boss.hp])
	ok = await _fight(func() -> bool: return _boss.phase >= 2, 1800)
	_ok(ok and _boss.st == "roar", "rage below 50%%: phase %d, line «%s»" % [_boss.phase, _boss.line])
	ok = await _fight(func() -> bool: return lk.dark_state == "dark" and lk.dark_left < float(row.dark_time) - float(row.dark_fade) - 0.1, 900, 0.0)
	await _frames(2)
	var lmin := AmuletRules.light_min(Tune.data)
	_ok(ok and absf(_w.darkness.light_r - lmin) < 1.0, "lights out: hero light %d (light_min %d)" % [_w.darkness.light_r, lmin])
	p.position.x = _boss.position.x - 320.0
	ok = await _fight(func() -> bool: return lk.dark_state == "dark" and (_boss.is_winding() or not _boss.hazards.is_empty()), 600, 0.0)
	await _shot("boss-likho-phase2.png")
	ok = await _fight(func() -> bool: return _distinct(_boss.attack_log) >= 4, 3000, 0.0)
	_ok(ok, "4 different attacks: %s" % [_boss.attack_log])
	ok = await _fight(func() -> bool: return _boss.summons_done >= 2, 1800)
	_ok(ok, "second summon at 30%%: summons %d" % _boss.summons_done)
	ok = await _fight(func() -> bool: return _boss.dead, 3000, BLOW * 2.0)
	_ok(ok, "Лихо dies")
	await _frames(30)
	await _shot("boss-likho-dead.png")
	_ok(_boss.line == String(row.lines.death_first) and _boss.line_t > 0.0, "death line: %s" % _boss.line)
	var left := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e as Enemy).dead:
			left += 1
	_ok(left == 0 and _boss.hazards.is_empty() and lk.light_cap() == 0.0, "minions and hazards vanished, light back: %d enemies left" % left)
	_finish()

## A forest chunk room of tier 2 (room-generation §3.3, library chunks_forest.json)
## and its roster awake: forest-room.png, then forest-enemies.png with Аука and
## Лешачонок mid-telegraph.
func _forest_rooms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var t := Tune.data
	var layout := RoomGen.generate(rng, 3, 2, t, true, { "loc": "forest" })
	layout["portal"] = false
	var forest_ids := (layout.chunks as Array).all(func(c: Dictionary) -> bool: return String(c.id).begins_with("forest_"))
	_w.start_room(layout, rng)
	await _frames(3)
	var p := _w.player
	p.scripted = true
	p.hp = 500.0
	var kinds := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		kinds[(e as Enemy).kind_id] = true
	_ok(forest_ids and not kinds.has("crawler"), "forest room: chunks %s, kinds %s" % [(layout.chunks as Array).map(func(c: Dictionary) -> String: return c.id), kinds.keys()])
	# Show the vertical part: put the hero on the first shaft.
	for c: Dictionary in layout.chunks:
		if c.kind == "shaft":
			p.position = Vector2(float(c.x) + 300.0, Tune.f("ground_y"))
			break
	_w.cam.reset_smoothing()
	await _frames(20)
	await _shot("forest-room.png")
	# Awake ringer + rootling next to the hero, caught in their wind-ups.
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Enemy).remove_from_group("enemies")
		e.queue_free()
	await _frames(1)
	p.position = Vector2(900.0, Tune.f("ground_y"))
	var r := Ringer.new()
	_w.spawn_enemy(r, Vector2(1250.0, Tune.f("ground_y")), -1, false, 5)
	var l := Rootling.new()
	_w.spawn_enemy(l, Vector2(560.0, Tune.f("ground_y")), -1, false, 6)
	var s := Sentry.new()
	_w.spawn_enemy(s, Vector2(1500.0, Tune.f("ground_y")), -1, false, 7)
	await _frames(2)
	r.cd = 0.0
	l.cd = 0.0
	var seen := {}
	for i in 240:
		p.hp = 500.0
		p.position.x = 900.0
		seen[r.st] = true
		seen[l.st] = true
		if r.st == "call" and l.st == "rise_w":
			break
		if l.st == "walk" and l.cd <= 0.0 and absf(l.position.x - p.position.x) > 200.0 and r.st == "call":
			pass
		await get_tree().physics_frame
	_w.cam.reset_smoothing()
	await _frames(1)
	await _shot("forest-enemies.png")
	_ok(seen.has("call") and (seen.has("under") or seen.has("rise_w")), "forest enemies telegraph: %s" % [seen.keys()])
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Enemy).remove_from_group("enemies")
		e.queue_free()
