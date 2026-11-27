## Root of the combat scene (formerly Main, ADR-0002): generates one combat room,
## places the hero and sleeping enemy packs (EnemyRoster), wakes packs, runs the camera and is the only owner of
## hit feel: hitstop, screen shake and slam rings. Actors read `hitstop` but
## change these only through request_hitstop(), add_shake() and add_ring().
## Run with `-- --demo=<dir>` to play a scripted check that saves screenshots,
## `-- --enemy-check=<dir>` for the enemy check, `--room=<k>` / `--seed=<n>` to
## pick the room, `--ai-debug` to draw enemy state names, `--amulet=<id>` to pick
## the hero's amulet (ring, beam, wave, knot; amulets.json), `--flare-check=<dir>`
## for the scripted Flare check (GDD amulet-and-flare). Also owns the world slow
## of the Flare "breath" (request_slow, time_mult) and the screen flash.
## Runes (gods-and-runes): `--runes=svarog_s:2,perun_d,duo_storm` starts with
## those runes (id[:level]), `--rune-offer=<god>[:wide]` opens the rune offer
## screen at start, `--god-check=<dir>` runs the scripted per-god check.
## Weapons (weapons-and-loot): `--weapon=<id>` / `--sub=<id>` pick the hero's
## weapons in the legacy modes, `--weapon-check=<dir>` runs the weapon check,
## `--boss-check=<dir>` the scripted lair boss fight (Кикимора, enemies-and-elites §3.9).
## `--hero-shots=<dir>` saves hero rig poses (with `--hero-tier=1..5`, HeroVisual).
## Run mode (default when none of the legacy check flags above is given): a
## RunDirector child plays the run of GDD room-generation-and-doors (rooms, doors,
## lair, haven, summary) on the Game autoload's RunState. `--run-check=<dir>`
## plays it scripted and saves screenshots.
class_name World
extends Node2D

## Seconds of freeze left after a hit; actors skip their update while above 0.
## Read-only for actors: use request_hitstop().
var hitstop: float = 0.0
## Current screen shake strength in px. Read-only for actors: use add_shake().
var shake: float = 0.0
## Active slam shock rings: {p: Vector2, r: float, t: float}.
var rings: Array[Dictionary] = []
var room: Room
var player: Player
var cam: Camera2D
var hud: Label
var room_k: int = 2
var tier: int = 1
var seed_value: int = 1
## Draw each enemy's state name (AI debugging).
var ai_debug: bool = false
## Amulet id the hero wears (--amulet=, default from tuning "amulet_default").
var amulet_id: String = "ring"
## Screen flash 0..1 (Flare), decays by flash_decay per s; lightens the darkness (F5).
var flash: float = 0.0
## World time multiplier while slow_t > 0 (Flare breath, ×flare_slow).
var slow: float = 1.0
var slow_t: float = 0.0
var darkness: Darkness
var amulet_hud: AmuletHud
## The hero's runes for this run; kept across rooms (gods-and-runes §3.2).
var build: RunBuild
## Seeded stream of rune offers; in run mode the RunRng "boons" stream (ADR-0003).
var offer_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The run flow (null in the legacy check modes).
var director: RunDirector
## Weapons in hand, kept across rooms (weapons-and-loot §3.9). arm null = the
## Player default (Меч-кладенец ★, legacy checks); sub_arm null = empty slot.
var arm: Weapon
var sub_arm: Weapon
var weapon_hud: WeaponHud
## True in the first run of a save (meta.runs == 0): the amulet charge caps at
## c_cap_first_run (amulet-and-flare §3.10, AC 3). Set by RunDirector; false in
## the legacy check modes (BUG-0001).
var first_run: bool = false

## Flags that start the old single-room checks instead of a run.
const LEGACY_FLAGS: Array[String] = ["--demo=", "--enemy-check=", "--flare-check=", "--god-check=", "--rune-offer=", "--room=", "--weapon-check=", "--hero-shots=", "--boss-check="]

## Camera framing offset in world units (prototype px): the hero sits below centre.
const CAM_OFFSET: Vector2 = Vector2(0, -120)
## HUD text size in 1080p screen px (ADR-0004: HUD is laid out for 1920x1080, not
## scaled by the camera). Moves to assets/ui/theme.tres when the theme exists.
const HUD_FONT_SIZE: int = 27
## HUD margin from the top-left corner, 1080p screen px.
const HUD_MARGIN: Vector2 = Vector2(24, 18)
## Top-left of the amulet charge ring, 1080p screen px.
const HUD_RING_POS: Vector2 = Vector2(28, 900)
## Top-left of the weapon panel (weapons-and-loot §6 HUD), 1080p screen px.
const HUD_WEAPON_POS: Vector2 = Vector2(360, 900)

func _ready() -> void:
	# Hit-feel clocks tick before the hero and the enemies (Player sets -1).
	process_physics_priority = -2
	InputSetup.register()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
		elif a.begins_with("--room="):
			room_k = maxi(1, int(a.trim_prefix("--room=")))
		elif a == "--ai-debug":
			ai_debug = true
		elif a.begins_with("--amulet="):
			amulet_id = a.trim_prefix("--amulet=")
		elif a.begins_with("--runes="):
			build = RunBuild.from_arg(a.trim_prefix("--runes="))
		elif a.begins_with("--weapon="):
			arm = Weapon.from_dict({ "id": a.trim_prefix("--weapon=") })
		elif a.begins_with("--sub="):
			sub_arm = Weapon.from_dict({ "id": a.trim_prefix("--sub="), "kind": Weapon.SUB })
	if build == null:
		build = RunBuild.make()
	offer_rng.seed = seed_value * 7919 + 17
	if not Tune.table("amulets").has(amulet_id) or amulet_id.begins_with("_"):
		push_error("World: unknown amulet '%s', using ring" % amulet_id)
		amulet_id = "ring"
	RenderingServer.set_default_clear_color(Color("#0c1418"))
	var legacy := false
	for a in OS.get_cmdline_user_args():
		for f in LEGACY_FLAGS:
			if a.begins_with(f):
				legacy = true
	if legacy:
		start_room()
	else:
		director = RunDirector.new()
		director.world = self
		director.game = get_node("/root/Game")
		add_child(director)
		director.begin.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			var d: Node = (load("res://tests/integration/core/demo_driver.gd") as GDScript).new()
			d.set("out_dir", a.trim_prefix("--demo="))
			add_child(d)
		elif a.begins_with("--enemy-check="):
			var c: Node = (load("res://tests/integration/enemies/enemy_check_driver.gd") as GDScript).new()
			c.set("out_dir", a.trim_prefix("--enemy-check="))
			add_child(c)
		elif a.begins_with("--rune-offer="):
			var bits := a.trim_prefix("--rune-offer=").split(":")
			open_rune_offer.call_deferred(bits[0], bits.size() > 1 and bits[1] == "wide")
		elif a.begins_with("--god-check="):
			var gc: Node = (load("res://tests/integration/gods/god_check_driver.gd") as GDScript).new()
			gc.set("out_dir", a.trim_prefix("--god-check="))
			add_child(gc)
		elif a.begins_with("--flare-check="):
			var fc: Node = (load("res://tests/integration/amulet/flare_check_driver.gd") as GDScript).new()
			fc.set("out_dir", a.trim_prefix("--flare-check="))
			add_child(fc)
		elif a.begins_with("--weapon-check="):
			var wc: Node = (load("res://tests/integration/loot/weapon_check_driver.gd") as GDScript).new()
			wc.set("out_dir", a.trim_prefix("--weapon-check="))
			add_child(wc)
		elif a.begins_with("--boss-check="):
			var bc: Node = (load("res://tests/integration/enemies/boss_check_driver.gd") as GDScript).new()
			bc.set("out_dir", a.trim_prefix("--boss-check="))
			add_child(bc)
		elif a.begins_with("--hero-shots="):
			var hs: Node = (load("res://tests/integration/hero/hero_shots_driver.gd") as GDScript).new()
			hs.set("out_dir", a.trim_prefix("--hero-shots="))
			add_child(hs)
		elif a.begins_with("--run-check="):
			var rc: Node = (load("res://tests/integration/run/run_check_driver.gd") as GDScript).new()
			rc.set("out_dir", a.trim_prefix("--run-check="))
			add_child(rc)

## Clears the level and builds room number room_k of location tier. The run
## passes its own `layout` and the room stream `p_rng` (RunRng.for_room, already
## used by the generator); without them the old seed formula is used.
func start_room(layout: Dictionary = {}, p_rng: RandomNumberGenerator = null) -> void:
	for c in get_children():
		if c is Room or c is Player or c is Enemy or c is EnemyShot or c is Camera2D or c is CanvasLayer \
				or c is Flare or c is Darkness or c is Door or c is RewardOrb or c is WeaponDrop or c is HeroShot:
			if c is Enemy:
				c.remove_from_group("enemies")
			c.queue_free()
	var rng := p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed_value * 1000 + tier * 100 + room_k
	if layout.is_empty():
		# Legacy check modes only (the run passes its layout): old layout without the
		# BUG-0004 safe start zone, so their recorded logs (--demo) stay comparable.
		layout = RoomGen.generate(rng, room_k, tier, Tune.data, false)
	room = Room.new()
	add_child(room)
	room.build(layout)
	# Sleeping packs of the location roster (enemies-and-elites §3.3, room-generation §3.5).
	var table := Tune.table("enemies")
	var fly_y: Array = Tune.get_value("flyer_spawn_y")
	for i in layout.packs.size():
		var pack: Array = layout.packs[i]
		var kinds := EnemyRoster.pack_kinds(rng, pack.size(), i, room_k, tier,
			Tune.get_value("swamp_roster"), Tune.get_value("swamp_late"), table, Tune.data)
		for j in kinds.size():
			var e := EnemyRoster.make(kinds[j])
			var y := Tune.f("ground_y")
			if bool(table[kinds[j]].get("flies", false)):
				y = rng.randf_range(float(fly_y[0]), float(fly_y[1]))
			spawn_enemy(e, Vector2(pack[j], y), i, true, rng.randi())
	var keep_charge := player.amulet.charge if player and is_instance_valid(player) and player.amulet else 0.0
	player = Player.new()
	player.world = self
	player.amulet = Amulet.make(amulet_id, Tune.data, {}, 1, first_run)
	player.build = build
	player.weapon = arm
	player.sub = sub_arm
	player.roll_rng.seed = seed_value * 31 + tier * 7 + room_k
	player.weapon_changed.connect(func(slot: String) -> void:
		if slot == Weapon.SUB:
			sub_arm = player.sub
		else:
			arm = player.weapon)
	# The charge stays between rooms of one location (amulet-and-flare §3.1).
	player.amulet.charge = minf(keep_charge, player.amulet.cap)
	player.position = Vector2(Tune.f("hero_spawn_x"), Tune.f("ground_y"))
	add_child(player)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(layout.w)
	cam.limit_bottom = int(Tune.f("ground_y") + 220)
	cam.limit_top = -400
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	# ADR-0004: the screen is 1920x1080 but the world stays in prototype units;
	# zoom maps them, so the view shows 1280x720 units on 16:9 (more width on 21:9).
	cam.zoom = Vector2.ONE * Tune.f("camera_zoom")
	player.add_child(cam)
	cam.offset = CAM_OFFSET
	var layer := CanvasLayer.new()
	hud = Label.new()
	hud.position = HUD_MARGIN
	hud.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	layer.add_child(hud)
	amulet_hud = AmuletHud.new()
	amulet_hud.amulet = player.amulet
	amulet_hud.position = HUD_RING_POS
	layer.add_child(amulet_hud)
	weapon_hud = WeaponHud.new()
	weapon_hud.hero = player
	weapon_hud.position = HUD_WEAPON_POS
	layer.add_child(weapon_hud)
	add_child(layer)
	darkness = Darkness.new()
	darkness.world = self
	add_child(darkness)

## Opens the rune offer of `god` (§3.4). `wide` = «Широкий выбор» (4 cards).
## `opts` go to RuneOffer.build_offer (duos_open, legend_open).
func open_rune_offer(god: String, wide: bool = false, opts: Dictionary = {}) -> RuneOfferScreen:
	var scr := RuneOfferScreen.new()
	scr.build = build
	scr.hero = player
	scr.god = god
	scr.ids = RuneOffer.build_offer(god, build, offer_rng, Tune.data,
		int(Tune.f("offer_wide_count") if wide else Tune.f("offer_count")), opts)
	show_screen(scr)
	return scr

## Puts a full-screen Control on its own CanvasLayer above the game; the layer
## goes away with the screen. `layer_index` orders screens (summary above offers).
func show_screen(scr: Control, layer_index: int = 20) -> void:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(scr)
	add_child(layer)
	scr.tree_exited.connect(layer.queue_free)

## Adds an enemy to the room: injects world, tier and walls, seeds its random
## stream, and puts it to sleep in pack `pack_id` (-1 = no pack) if `sleeping`.
func spawn_enemy(e: Enemy, at: Vector2, pack_id: int, sleeping: bool, rng_seed: int) -> Enemy:
	e.world = self
	e.tier = tier
	e.room_w = float(room.layout.w) if room else 0.0
	e.pack = pack_id
	e.asleep = sleeping
	e.face = -1
	e.show_state = ai_debug
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = rng_seed
	e.position = at
	add_child(e)
	return e

## Wakes every sleeping enemy of one pack (room-generation §3.5: only that pack).
func wake_pack(pack_id: int) -> void:
	Enemy.wake_pack(get_tree().get_nodes_in_group("enemies"), pack_id)

## Freezes the action for `t` seconds. A running hitstop is extended to the
## larger of the two, never summed (GDD movement-and-combat §3.10, F13).
func request_hitstop(t: float) -> void:
	hitstop = maxf(hitstop, t)

## Shakes the screen with strength `s` px; the stronger shake wins.
func add_shake(s: float) -> void:
	shake = maxf(shake, s)

## Slows the world to `scale` for `t` real seconds (Flare breath). The stronger
## (smaller) slow and the longer time win; never summed.
func request_slow(scale: float, t: float) -> void:
	slow = minf(slow, scale) if slow_t > 0.0 else scale
	slow_t = maxf(slow_t, t)

## Multiplier for actors' dt: `slow` while a slow runs, else 1.
func time_mult() -> float:
	return slow if slow_t > 0.0 else 1.0

## Flashes the screen (lightens the darkness, F5 `flash`); the stronger wins.
func add_flash(v: float) -> void:
	flash = clampf(maxf(flash, v), 0.0, 1.0)

## Adds a shock ring (down-strike slam) at a point.
func add_ring(at: Vector2, r: float) -> void:
	rings.append({ "p": at, "r": r, "t": 0.0 })

func _physics_process(dt: float) -> void:
	hitstop = maxf(0.0, hitstop - dt)
	slow_t = maxf(0.0, slow_t - dt)
	if slow_t <= 0.0:
		slow = 1.0
	flash = maxf(0.0, flash - dt * Tune.f("flash_decay"))
	shake = maxf(0.0, shake - dt * Tune.f("shake_decay"))
	if cam:
		# Shake moves the offset, never the zoom (ADR-0004).
		cam.offset = CAM_OFFSET + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	for r: Dictionary in rings:
		r.t += dt
	var ring_time := Tune.f("ring_time")
	rings.assign(rings.filter(func(r: Dictionary) -> bool: return r.t < ring_time))
	if hud and player and director:
		hud.text = director.hud_text()
	elif hud and player:
		var awake := 0
		var total := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			total += 1
			if not (e as Enemy).asleep:
				awake += 1
		hud.text = "Навь — проверка основы (Godot)    Комната %d, ширина %d px    Враги: %d (не спят %d)    HP %d  Щит %d\n%s\nA/D бег · Пробел прыжок · J удар (W вверх, S в воздухе вниз) · Shift перекат/рывок · L Вспышка · U доп. оружие · E взять" % [room_k, int(room.layout.w), total, awake, roundi(player.hp), roundi(player.shield), build.hud_text()]
	queue_redraw()

func _draw() -> void:
	for r: Dictionary in rings:
		var k: float = r.t / Tune.f("ring_time")
		draw_arc(r.p, r.r * k, PI, TAU, 32, Color(0.85, 0.75, 0.5, 1.0 - k), 6.0)
