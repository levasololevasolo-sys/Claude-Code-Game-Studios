## Scripted gods check (GDD gods-and-runes §3.5 «Удар», §3.7, §3.9, §3.14, AC 21).
## For each god: clears the room, gives the hero only that god's Удар rune, makes
## a real 3-swing combo on a straw dummy, logs every status word shown and the
## damage the dummy took in the 3 s after the first hit, saves
## <out_dir>/god-<id>.png. Stribog also slams a crawler into the wall
## (god-stribog-burst.png); the end opens the rune offer screen with «Широкий
## выбор» (rune-offer.png). Started by world.gd with `-- --god-check=<dir>`.
extends Node

const HERO_X: float = 1200.0
const STRIKE_DX: float = 60.0
## Physics ticks between combo taps (inside combo_window).
const TAP_GAP: int = 17
const GODS: Array[String] = ["kupala", "perun", "stribog", "veles", "zhiva", "mokosh", "dazhbog", "khors", "yarilo", "chernobog", "semargl", "svyatovit"]

var out_dir: String = "user://god_check"
var _main: World

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[god-check] ", s)

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _clear() -> void:
	for n in _main.get_children():
		if n is Enemy or n is EnemyShot or n is Flare:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()

func _set_build(arg: String) -> void:
	_main.build = RunBuild.from_arg(arg)
	_main.player.build = _main.build

func _place_hero(x: float) -> void:
	var p: Player = _main.player
	p.scripted = true
	p.position = Vector2(x, Tune.f("ground_y"))
	p.velocity = Vector2.ZERO
	p.face = 1
	p.hp = 1000.0
	p.shield = 0.0
	p.inv = 0.0
	_main.cam.reset_smoothing()

## Steps `n` hero ticks with `keys` held; records words shown on `watch`.
func _frames(n: int, keys: Dictionary, watch: Array, words: Dictionary) -> void:
	var p: Player = _main.player
	for i in n:
		p.fake = keys
		await p.stepped
		for e: Enemy in watch:
			if is_instance_valid(e):
				for w: Dictionary in e.status.words:
					words[String(w.text)] = true
	p.fake = {}

func _run() -> void:
	var p: Player = _main.player
	var summary: PackedStringArray = []
	for god in GODS:
		_clear()
		await _frames(2, {}, [], {})
		_set_build("%s_s" % god)
		_place_hero(HERO_X)
		var dummy: Enemy = _main.spawn_enemy(StrawDummy.new(), Vector2(HERO_X + STRIKE_DX, Tune.f("ground_y")), -1, false, 3)
		var watch: Array = [dummy]
		var second: Enemy = null
		if god == "perun":
			second = _main.spawn_enemy(StrawDummy.new(), Vector2(HERO_X + STRIKE_DX + 250.0, Tune.f("ground_y")), -1, false, 4)
			watch.append(second)
		var dealt := [0.0, 0.0]
		var t0 := [-1]
		var tick := [0]
		var on_dmg := func(_e: Enemy, amount: float, _h: Hit) -> void:
			if t0[0] < 0:
				t0[0] = tick[0]
			if tick[0] - t0[0] <= 180:
				dealt[0 if _e == dummy else 1] += amount
		dummy.damaged.connect(on_dmg)
		if second:
			second.damaged.connect(on_dmg)
		var counter := func() -> void: tick[0] += 1
		p.stepped.connect(counter)
		var words := {}
		await _frames(2, {}, watch, words)
		for s in 3:
			await _frames(1, { &"strike": true }, watch, words)
			await _frames(TAP_GAP if s < 2 else 10, {}, watch, words)
		var st := dummy.status
		_note("%s: after 3 swings  burn %.2f s  shock %d  cuts %d  curse %.2f s  root %.2f s (immune %.2f)  hero shield %d" % [
			god, st.burn, st.shock, st.cuts, st.curse, st.root, st.immune, roundi(p.shield)])
		await _shot("god-%s.png" % god)
		while t0[0] >= 0 and tick[0] - t0[0] <= 180:
			await _frames(1, {}, watch, words)
		p.stepped.disconnect(counter)
		var line := "%s: words %s, dummy damage over 3 s = %.2f" % [god, ", ".join(PackedStringArray(words.keys())), dealt[0]]
		if second:
			line += ", second dummy at +250 px = %.2f" % dealt[1]
		_note(line)
		summary.append(line)
	# Stribog cut burst on a wall slam (§3.9): crawler next to the right wall.
	_clear()
	await _frames(2, {}, [], {})
	_set_build("stribog_s")
	var rw := float(_main.room.layout.w)
	var crawler: Enemy = EnemyRoster.make("crawler")
	_main.spawn_enemy(crawler, Vector2(rw - 58.0, Tune.f("ground_y")), -1, true, 5)
	crawler.max_hp = 500.0
	crawler.hp = 500.0
	_place_hero(rw - 118.0)
	var bursts: Array[String] = []
	crawler.damaged.connect(func(_e: Enemy, amount: float, h: Hit) -> void:
		bursts.append("%s %.1f" % [Hit.Kind.keys()[h.kind], amount]))
	var w2 := {}
	var shot_done := false
	for s in 3:
		await _frames(1, { &"strike": true }, [crawler], w2)
		for f in (TAP_GAP if s < 2 else 30):
			await _frames(1, {}, [crawler], w2)
			if not shot_done and w2.has("ВСКРЫТ"):
				shot_done = true
				await _frames(3, {}, [crawler], w2)
				await _shot("god-stribog-burst.png")
	if not shot_done:
		await _shot("god-stribog-burst.png")
	var bl := "stribog wall: hits on crawler [%s], words %s" % [", ".join(bursts), ", ".join(PackedStringArray(w2.keys()))]
	_note(bl)
	summary.append(bl)
	# Rune offer screen with «Широкий выбор».
	_clear()
	await _frames(2, {}, [], {})
	_set_build("kupala_s:2,perun_d")
	_place_hero(HERO_X)
	var scr := _main.open_rune_offer("perun", true)
	for i in 4:
		await get_tree().process_frame
	_note("offer perun wide: %s" % ", ".join(PackedStringArray(scr.ids)))
	for id in scr.ids:
		_note("  card %s [%s] %s" % [id, RunBuild.SLOT_LABEL.get(_main.build.slot_of(id), "?"), scr.replace_line(id)])
	await _shot("rune-offer.png")
	scr.take(0)
	_note("took %s -> %s" % [scr.ids[0], _main.build.hud_text()])
	await _new_powers(summary)
	await _forge(summary)
	await _prophet(summary)
	await _prophet_station(summary)
	await _god_choice(summary)
	await _doors(summary)
	var f := FileAccess.open(out_dir.path_join("god-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(summary) + "\n")
	f.close()
	_note("done")
	get_tree().quit()

## gods-expansion §3.3-3.11: Khors orbit disks on a dash, Dazhbog's sun, the
## Semargl dog and Mokosh's thread, all at once on three dummies.
func _new_powers(summary: PackedStringArray) -> void:
	_clear()
	await _frames(2, {}, [], {})
	_set_build("mokosh_s,khors_d,dazhbog_f,semargl_p")
	_place_hero(HERO_X)
	var dums: Array = []
	for k in 3:
		dums.append(_main.spawn_enemy(StrawDummy.new(), Vector2(HERO_X + 160.0 + k * 140.0, Tune.f("ground_y")), -1, false, 6 + k))
	var words := {}
	await _frames(4, {}, dums, words)
	await _frames(1, { &"dash": true }, dums, words)
	await _frames(14, {}, dums, words)
	_main.player.powers.add_sun(_main.player.position + Vector2(260, -220), 260.0, 4.0)
	_main.player.powers.dog_now()
	for s in 3:
		await _frames(1, { &"strike": true }, dums, words)
		await _frames(TAP_GAP, {}, dums, words)
	await _shot("gods-new-powers.png")
	var pw: GodPowers = _main.player.powers
	var line := "new powers: orbit %d, suns %d, dog %s, words %s" % [pw._orbit_count(), pw.suns.size(), pw.dog_state, ", ".join(PackedStringArray(words.keys()))]
	_note(line)
	summary.append(line)

## Горн Сварога (§3.12): the forge screen for the hero's weapon, then one taken.
func _forge(summary: PackedStringArray) -> void:
	_clear()
	await _frames(2, {}, [], {})
	_set_build("kupala_s")
	var fam := RunBuild.family_of(_main.player.weapon)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var scr := RuneOfferScreen.new()
	scr.mode = "forge"
	scr.build = _main.build
	scr.hero = _main.player
	scr.god = "svarog"
	scr.ids.assign(RunDirector.forge_ids(_main.build, fam, rng, int(Tune.f("forge_offer"))))
	_main.show_screen(scr)
	for i in 6:
		await get_tree().process_frame
	await _shot("forge-offer.png")
	scr.take(0)
	var line := "forge (%s): offer %s, took -> %s" % [fam, scr.ids, _main.build.forge]
	_note(line)
	summary.append(line)
	for i in 4:
		await get_tree().process_frame

## The Prophet (§3.13): the god grid after a first win, two gods sent away.
func _prophet(summary: PackedStringArray) -> void:
	var m := MetaState.new()
	m.runs = 6
	m.wins = 1
	m.bosses = { "likho": 2, "kikimora": 1 }
	var ps := ProphetScreen.new()
	ps.meta = m
	ps.min_on = int(Tune.f("gods_min_on"))
	ps.toggle_fn = func(g: String) -> bool: return ProphetRules.toggle(m, Tune.table("gods"), g, ps.min_on)
	_main.show_screen(ps)
	for i in 4:
		await get_tree().process_frame
	ps.pick(1)
	ps.pick(9)
	ps.sel = 4
	for i in 4:
		await get_tree().process_frame
	await _shot("prophet.png")
	var line := "prophet: gods %s, off %s, called %d" % [ps.ids, m.gods_off, ProphetRules.on_count(m, Tune.table("gods"))]
	_note(line)
	summary.append(line)
	ps.close()

## The Prophet stands in the yard only after the first win (§3.13).
func _prophet_station(summary: PackedStringArray) -> void:
	_clear()
	var m := MetaState.new()
	m.runs = 6
	m.wins = 1
	m.bosses = { "likho": 1 }
	var b := (load("res://scenes/base/base.tscn") as PackedScene).instantiate() as Base
	_main.add_child(b)
	b.setup(_main, m)
	_place_hero(1900.0)
	await _frames(30, {}, [], {})
	var ids: Array = b.stations.map(func(st: Station) -> String: return st.id())
	await _shot("prophet-station.png")
	var line := "base after a win: stations %s, prophet art %s, before a win: %s" % [ids, NpcSprite.has_art("prorok"),
		Base.station_open({ "needs": "win" }, MetaState.new())]
	_note(line)
	summary.append(line)
	b.queue_free()

## The god choice after a boss with the painted portraits (navart gods.py).
func _god_choice(summary: PackedStringArray) -> void:
	var gc := GodChoiceScreen.new()
	gc.gods = ["perun", "mokosh", "semargl"]
	gc.held = ["perun"]
	_main.show_screen(gc)
	for i in 4:
		await get_tree().process_frame
	await _shot("god-choice.png")
	var line := "god choice: portraits %s" % [gc.gods.map(func(g: String) -> bool: return GodGlyph.art("portrait_" + g) != null)]
	_note(line)
	summary.append(line)
	gc.take(0)

## A row of painted doors in the room: god doors, the forge (closed, open in
## front of the hero), loot, lair and a plain route door.
func _doors(summary: PackedStringArray) -> void:
	_clear()
	_place_hero(900.0)
	var row := [{ "type": "god", "god": "perun" }, { "type": "god", "god": "zhiva" }, { "type": "svarog" },
		{ "type": "loot" }, { "type": "lair", "arg": "Лихо" }, { "type": "heal" }]
	var made: Array[Door] = []
	for i in row.size():
		var d := Door.new()
		d.info = row[i]
		d.position = Vector2(560.0 + i * 230.0, Tune.f("ground_y"))
		d.near = i == 2
		_main.add_child(d)
		made.append(d)
	await _frames(20, {}, [], {})
	await _shot("doors.png")
	var line := "doors: art %s" % [row.map(func(r: Dictionary) -> bool: return GodGlyph.door_art(String(r.type), String(r.get("god", ""))) != null)]
	_note(line)
	summary.append(line)
	for d in made:
		d.queue_free()
