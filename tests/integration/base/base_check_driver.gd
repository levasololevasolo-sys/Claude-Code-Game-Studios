## Scripted base check (GDD economy-and-meta §3.4-3.6, armor-and-hero-progression
## §3.2-3.5, living-world §1.3). Starts a run, ends it by death in the swamp,
## closes the summary, enters the base «Застава», walks the hero to each NPC,
## shows Доля's line, buys armor tiers at Потап (every slot to tier 4, in the
## order the even-growth rule allows) through the menu, an amulet at Сова, a
## rule at the Капище, checks the save (version 2, armor, said lines) and takes
## the gate to a new run in the bought armor. Saves <out_dir>/base-overview.png,
## base-dialogue.png, base-potap-shop.png, base-hero-armored.png and
## base-check-log.txt. Started by world.gd with `-- --base-check=<dir>`; run it
## with `--fresh --save=user://base_check_save.json`.
extends Node

var out_dir: String = "user://base_check"
var _w: World
var _d: RunDirector
var _log: PackedStringArray = []
var _fail: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	_log.append(s)
	print("[base-check] ", s)

func _check(ok: bool, what: String) -> void:
	_note(("OK   " if ok else "FAIL ") + what)
	if not ok:
		_fail += 1

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _wait(cond: Callable, max_frames: int = 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Walks the hero (scripted input) to x; teleports if it takes too long.
func _walk_to(x: float) -> void:
	var p := _w.player
	p.scripted = true
	for i in 400:
		var dx := x - p.position.x
		if absf(dx) < 30.0:
			break
		p.fake = { "move_right": dx > 0.0, "move_left": dx < 0.0 }
		await get_tree().physics_frame
	p.fake = {}
	if absf(x - p.position.x) >= 30.0:
		p.position.x = x
	await _frames(8)

func _station_x(id: String) -> float:
	for row: Dictionary in Tune.table("base").stations:
		if row.id == id:
			return float(row.x) - 60.0
	return 0.0

func _run() -> void:
	_d = _w.director
	_d.noted.connect(func(s: String) -> void: _log.append("  " + s))
	var game: Node = get_node("/root/Game")
	var ok := await _wait(func() -> bool: return _d.screen is RuneOfferScreen)
	(_d.screen as RuneOfferScreen).take(0)
	await _frames(5)
	_d.run.killer_id = "crawler"
	_d.finish("dead")
	ok = await _wait(func() -> bool: return _d.screen is RunSummaryScreen, 200)
	_check(ok, "summary after the run")
	await _frames(30)
	(_d.screen as RunSummaryScreen).close()
	ok = await _wait(func() -> bool: return _d.phase == "base" and _d.base != null, 200)
	_check(ok, "the base opens after the summary")
	var b := _d.base
	_check(b.stations.size() >= 5, "stations: %d" % b.stations.size())
	_check(b.picked.has("dolya") and String(b.picked.dolya.id) == "dolya_first_death", "Доля: first death (80) beats the swamp line (45): %s" % b.picked.get("dolya", {}).get("id", "-"))
	_check(b.picked.has("potap") and String(b.picked.potap.id) == "potap_first", "Потап greets the first visit: %s" % b.picked.get("potap", {}).get("id", "-"))
	_check(b.picked.has("bayun") and String(b.picked.bayun.id) == "bayun_crawler", "Баюн speaks of the crawler: %s" % b.picked.get("bayun", {}).get("id", "-"))
	# overview: zoom the camera out over the whole yard
	await _walk_to(1350.0)
	var zoom := _w.cam.zoom
	_w.cam.zoom = Vector2.ONE * 0.72
	_w.cam.limit_left = -200
	_w.cam.reset_smoothing()
	await _frames(6)
	await _shot("base-overview.png")
	_w.cam.zoom = zoom
	_w.cam.limit_left = 0
	# Доля
	await _walk_to(_station_x("dolya"))
	_check(b.nearest() != null and b.nearest().id() == "dolya", "hero stands at Доля")
	b.use("dolya")
	ok = await _wait(func() -> bool: return b.screen is DialogueBox, 60)
	_check(ok, "Доля's dialogue box opens")
	await _frames(4)
	await _shot("base-dialogue.png")
	_note("Доля: " + (b.screen as DialogueBox).text)
	await _frames(30)
	(b.screen as DialogueBox).close()
	await _frames(3)
	# Капище
	game.meta.embers = 20000
	game.meta.res = { "gears": 400, "bronze": 400, "pearls": 400, "cores": 20 }
	await _walk_to(_station_x("chur"))
	b.use("chur")
	await _wait(func() -> bool: return b.screen is DialogueBox, 60)
	await _frames(30)
	(b.screen as DialogueBox).close()
	ok = await _wait(func() -> bool: return b.screen is ShopScreen, 60)
	_check(ok, "Капище menu opens after Чур's line")
	(b.screen as ShopScreen).pick(0)
	_check(int(game.meta.up.reroll) == 1 and game.meta.embers == 20000 - 60, "Второй взгляд bought: reroll %d, embers %d" % [int(game.meta.up.reroll), game.meta.embers])
	(b.screen as ShopScreen).close()
	await _frames(3)
	# Сова
	await _walk_to(_station_x("sova"))
	b.use("sova")
	await _wait(func() -> bool: return b.screen is DialogueBox, 60)
	await _frames(30)
	(b.screen as DialogueBox).close()
	ok = await _wait(func() -> bool: return b.screen is ShopScreen, 60)
	var amulets: Array = (Tune.table("base").amulets as Dictionary).keys()
	(b.screen as ShopScreen).pick(amulets.find("beam"))
	_check(game.meta.lantern == "beam" and game.meta.lanterns.has("beam") and int(game.meta.res.cores) == 19, "Луч bought and worn at Сова")
	(b.screen as ShopScreen).close()
	await _frames(3)
	# Потап
	await _walk_to(_station_x("potap"))
	b.use("potap")
	await _wait(func() -> bool: return b.screen is DialogueBox, 60)
	await _frames(30)
	(b.screen as DialogueBox).close()
	ok = await _wait(func() -> bool: return b.screen is ShopScreen, 60)
	_check(ok, "Потап's armor menu opens")
	var shop := b.screen as ShopScreen
	var slots: Array = (Tune.table("armor").slots as Dictionary).keys()
	var before: int = game.meta.embers
	shop.pick(slots.find("torso"))
	_check(int(game.meta.armor.torso) == 1 and game.meta.embers == before - 150, "torso tier 1 for 150 embers")
	shop.pick(slots.find("torso"))
	shop.pick(slots.find("torso"))
	_check(int(game.meta.armor.torso) == 2 and shop.status.begins_with("Сначала"), "even growth blocks torso 3: «%s»" % shop.status)
	shop.sel = slots.find("torso")
	shop.queue_redraw()
	await _frames(4)
	await _shot("base-potap-shop.png")
	for t in range(1, 5):
		for s: String in slots:
			if int(game.meta.armor[s]) < t:
				shop.pick(slots.find(s))
	_check(DialogueRules.title_of(game.meta.armor) == 4, "every slot at tier 4: %s" % [game.meta.armor])
	shop.close()
	await _frames(5)
	var vis: HeroVisual = _w.player.visual as HeroVisual
	_check(int(vis.tiers.get("helmet", 0)) == 5 and int(vis.tiers.get("torso_armor", 0)) == 5, "hero look: helmet %s, torso %s" % [vis.tiers.get("helmet"), vis.tiers.get("torso_armor")])
	_w.player.position.x = _station_x("potap") - 260.0
	_w.player.face = 1
	_w.cam.zoom = Vector2.ONE * 2.2
	_w.cam.reset_smoothing()
	await _frames(6)
	await _shot("base-hero-armored.png")
	_w.cam.zoom = zoom
	var sd := SaveFile.read(game.save_path)
	_check(int(sd.get("version", 0)) == SaveFile.VERSION and int(sd.meta.armor.head) == 4 and (sd.meta.story.said as Dictionary).has("potap_first"),
		"save v%s holds armor %s and said lines" % [sd.get("version"), sd.meta.get("armor")])
	# gate
	await _walk_to(_station_x("gate") + 60.0)
	b.use("gate")
	ok = await _wait(func() -> bool: return _d.run != null and _d.screen is RuneOfferScreen, 300)
	_check(ok, "the gate starts a new run")
	await _frames(3)
	var v2: HeroVisual = _w.player.visual as HeroVisual
	_check(int(v2.tiers.get("helmet", 0)) == 5 and _w.amulet_id == "beam", "new run: armored hero (helmet %s), amulet %s" % [v2.tiers.get("helmet"), _w.amulet_id])
	_note("DONE: %d failed checks" % _fail)
	var f := FileAccess.open(out_dir.path_join("base-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().quit(1 if _fail > 0 else 0)
