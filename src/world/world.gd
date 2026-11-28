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
## `--aim-check=<dir>` the secondary-weapon aim check,
## `--boss-check=<dir>` the scripted lair boss fight (Кикимора, enemies-and-elites §3.9),
## `--limb-check=<dir>` the limb zones check (arm cut, head pop; GDD limb-zones).
## `--parry-check=<dir>` the parry reflect / shield-bearer / thrower check (GDD parry §3.5).
## `--bestiary-check=<dir>` the Топь roster check, each kind vs the hero (GDD bestiary §3.2).
## `--vfx-check=<dir>` the game-feel VFX check (design/art/vfx-spec.md).
## `--story-check=<dir>` plays the prologue with scripted input and a god line
## (tests/integration/story); a new save starts with the Prologue otherwise.
## `--hero-shots=<dir>` saves hero rig poses (with `--hero-tier=1..5`, HeroVisual).
## Run mode (default when none of the legacy check flags above is given): a
## RunDirector child plays the run of GDD room-generation-and-doors (rooms, doors,
## lair, haven, summary) on the Game autoload's RunState. `--run-check=<dir>`
## plays it scripted and saves screenshots. The Swamp is one graph level
## (GDD level-structure, LevelMode, `--levels=rooms` for the old chain);
## `--level2-check=<dir>` walks it scripted.
## Esc / pad Start opens the pause menu (PauseMenu: Продолжить, Настройки, На
## заставу). A new save asks for the difficulty first (DifficultyChoiceScreen,
## GDD difficulty §3.2), never under a check flag. `--settings-check=<dir>` runs
## the scripted settings check (tests/integration/core).
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
## Bought armor (MetaState.armor) the hero wears in every room; empty in the
## legacy check modes (their --hero-tier stays in charge). Set by RunDirector.
var hero_armor: Dictionary = {}

## Flags that start the old single-room checks instead of a run.
const LEGACY_FLAGS: Array[String] = ["--level-check=", "--demo=", "--enemy-check=", "--flare-check=", "--god-check=", "--rune-offer=", "--room=", "--weapon-check=", "--hero-shots=", "--boss-check=", "--limb-check=", "--parry-check=", "--vis-shots=", "--base-view", "--aim-check=", "--bestiary-check=", "--frost-check=", "--vfx-check="]

## Camera framing offset in world units (prototype px): the hero sits below centre.
const CAM_OFFSET: Vector2 = Vector2(0, -120)
## HUD text size in 1080p screen px (ADR-0004: HUD is laid out for 1920x1080, not
## scaled by the camera). Moves to assets/ui/theme.tres when the theme exists.
const HUD_FONT_SIZE: int = 27
## HUD margin from the top-left corner, 1080p screen px.
## The debug text sits under the amulet and weapon panel and shows only after F3
## (visual-upgrade-plan §2.8).
const HUD_MARGIN: Vector2 = Vector2(24, 190)
## Top-left of the amulet charge ring, 1080p screen px (top-left, art-bible §7).
const HUD_RING_POS: Vector2 = Vector2(28, 24)
## Top-left of the weapon panel (weapons-and-loot §6 HUD), next to the amulet, 1080p screen px.
const HUD_WEAPON_POS: Vector2 = Vector2(360, 30)
## Debug text shown (F3 toggles; kept across rooms). `--debug-hud` starts with it on.
static var debug_hud: bool = false
## Current camera look-ahead, world px (visual-upgrade-plan §2.7).
var _look: float = 0.0
## Air of the room (particles, dust, hero glow).
var atmosphere: Atmosphere
## The whole-location level in graph mode (GDD level-structure), null in a single room.
var level_room: LevelRoom
## Extra vertical camera offset while falling fast (level-structure §3.5), world px.
var _fall_look: float = 0.0

func _ready() -> void:
	# Hit-feel clocks tick before the hero and the enemies (Player sets -1).
	process_physics_priority = -2
	InputSetup.register()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
		elif a.begins_with("--room="):
			room_k = maxi(1, int(a.trim_prefix("--room=")))
		elif a.begins_with("--tier="):
			tier = clampi(int(a.trim_prefix("--tier=")), 1, 5)
		elif a == "--ai-debug":
			ai_debug = true
		elif a == "--debug-hud":
			debug_hud = true
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
	var fps_layer := CanvasLayer.new()
	fps_layer.layer = 100
	fps_layer.name = "FpsLayer"
	fps_layer.add_child(FpsLabel.new())
	add_child(fps_layer)
	var legacy := false
	for a in OS.get_cmdline_user_args():
		for f in LEGACY_FLAGS:
			if a.begins_with(f):
				legacy = true
	if legacy and OS.get_cmdline_user_args().has("--base-view"):
		_base_view()
	elif legacy:
		start_room()
	elif wants_main_menu(OS.get_cmdline_user_args(), bool(get_node("/root/Game").get("save_from_args"))):
		var mm := MainMenu.new()
		mm.start.connect(func(slot: int, new_game: bool) -> void:
			get_node("/root/Game").call("use_slot", slot, new_game)
			_launch())
		show_screen.call_deferred(mm, 40)
	else:
		_launch()
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
		elif a.begins_with("--limb-check="):
			var lmc: Node = (load("res://tests/integration/enemies/limb_check_driver.gd") as GDScript).new()
			lmc.set("out_dir", a.trim_prefix("--limb-check="))
			add_child(lmc)
		elif a.begins_with("--parry-check="):
			var pcc: Node = (load("res://tests/integration/enemies/parry_check_driver.gd") as GDScript).new()
			pcc.set("out_dir", a.trim_prefix("--parry-check="))
			add_child(pcc)
		elif a.begins_with("--bestiary-check="):
			var bsc: Node = (load("res://tests/integration/enemies/bestiary_check_driver.gd") as GDScript).new()
			bsc.set("out_dir", a.trim_prefix("--bestiary-check="))
			add_child(bsc)
		elif a.begins_with("--frost-check="):
			var fsc: Node = (load("res://tests/integration/enemies/frost_check_driver.gd") as GDScript).new()
			fsc.set("out_dir", a.trim_prefix("--frost-check="))
			add_child(fsc)
		elif a.begins_with("--hero-shots="):
			var hs: Node = (load("res://tests/integration/hero/hero_shots_driver.gd") as GDScript).new()
			hs.set("out_dir", a.trim_prefix("--hero-shots="))
			add_child(hs)
		elif a.begins_with("--level-check="):
			var lc: Node = (load("res://tests/integration/run/level_check_driver.gd") as GDScript).new()
			lc.set("out_dir", a.trim_prefix("--level-check="))
			add_child(lc)
		elif a.begins_with("--base-check="):
			var bc: Node = (load("res://tests/integration/base/base_check_driver.gd") as GDScript).new()
			bc.set("out_dir", a.trim_prefix("--base-check="))
			add_child(bc)
		elif a.begins_with("--vis-shots="):
			var vs: Node = (load("res://tests/integration/visual/vis_shots_driver.gd") as GDScript).new()
			vs.set("out_dir", a.trim_prefix("--vis-shots="))
			add_child(vs)
		elif a.begins_with("--story-check="):
			var sc: Node = (load("res://tests/integration/story/story_check_driver.gd") as GDScript).new()
			sc.set("out_dir", a.trim_prefix("--story-check="))
			add_child(sc)
		elif a.begins_with("--run-check="):
			var rc: Node = (load("res://tests/integration/run/run_check_driver.gd") as GDScript).new()
			rc.set("out_dir", a.trim_prefix("--run-check="))
			add_child(rc)
		elif a.begins_with("--level2-check="):
			var l2: Node = (load("res://tests/integration/run/level2_check_driver.gd") as GDScript).new()
			l2.set("out_dir", a.trim_prefix("--level2-check="))
			add_child(l2)
		elif a.begins_with("--aim-check="):
			var ac: Node = (load("res://tests/integration/loot/aim_check_driver.gd") as GDScript).new()
			ac.set("out_dir", a.trim_prefix("--aim-check="))
			add_child(ac)
		elif a.begins_with("--vfx-check="):
			var vxc: Node = (load("res://tests/integration/vfx/vfx_check_driver.gd") as GDScript).new()
			vxc.set("out_dir", a.trim_prefix("--vfx-check="))
			add_child(vxc)
		elif a.begins_with("--perf-check="):
			var pfc: Node = (load("res://tests/integration/perf/perf_check_driver.gd") as GDScript).new()
			pfc.set("out_dir", a.trim_prefix("--perf-check="))
			add_child(pfc)
		elif a.begins_with("--bg-check="):
			var bgc: Node = (load("res://tests/integration/visual/bg_check_driver.gd") as GDScript).new()
			bgc.set("out_dir", a.trim_prefix("--bg-check="))
			add_child(bgc)
		elif a.begins_with("--seal-check="):
			var slc: Node = (load("res://tests/integration/visual/seal_check_driver.gd") as GDScript).new()
			slc.set("out_dir", a.trim_prefix("--seal-check="))
			add_child(slc)
		elif a.begins_with("--menu-check="):
			var mc: Node = (load("res://tests/integration/core/menu_check_driver.gd") as GDScript).new()
			mc.set("out_dir", a.trim_prefix("--menu-check="))
			add_child(mc)
		elif a.begins_with("--settings-check="):
			var stc: Node = (load("res://tests/integration/core/settings_check_driver.gd") as GDScript).new()
			stc.set("out_dir", a.trim_prefix("--settings-check="))
			add_child(stc)

## Starts the game proper: the run director, then (new save) the difficulty
## choice and the prologue, then RunDirector.begin (the base, or a run under a check).
func _launch() -> void:
	director = RunDirector.new()
	director.world = self
	director.game = get_node("/root/Game")
	add_child(director)
	var args := OS.get_cmdline_user_args()
	var has_run: bool = director.game.run != null
	var go := func() -> void:
		if wants_prologue(args, director.game.meta, has_run):
			start_prologue()
		else:
			director.begin.call_deferred()
	if wants_difficulty_choice(args, director.game.meta, has_run):
		var dc := DifficultyChoiceScreen.new()
		dc.chosen.connect(func(id: String) -> void:
			director.game.set_difficulty(id)
			go.call())
		show_screen.call_deferred(dc, 40)
	else:
		go.call()

## True when a launch opens the main menu first: a normal start (no --save=,
## no check, demo or --skip-menu flag). Pure (tested).
static func wants_main_menu(args: PackedStringArray, save_from_args: bool) -> bool:
	if save_from_args and not args.has("--menu-slots"):
		return false
	for a in args:
		if a.begins_with("--menu-check="):
			continue
		if a.contains("-check=") or a.begins_with("--demo=") or a == "--skip-menu":
			return false
	return true

## `--base-view`: the base yard «Застава» alone (stations, no run, no save
## written), for art screenshots (production/qa/evidence/art3d-pipeline.md).
func _base_view() -> void:
	var w := float(Tune.table("base").get("width", 2700))
	start_room({ "w": w, "plats": [], "packs": [], "portal": false, "base": true })
	var b := (load("res://scenes/base/base.tscn") as PackedScene).instantiate() as Base
	add_child(b)
	b.setup(self, get_node("/root/Game").get("meta") as MetaState)

## True when the run mode starts with the prologue (prologue-and-endings §1):
## a new save (no prologue_seen, no finished run, no saved run) and no check
## flag — checks never wait on it — except --story-check, which plays it.
static func wants_prologue(args: PackedStringArray, meta: MetaState, has_run: bool) -> bool:
	for a in args:
		if a.begins_with("--story-check="):
			return true
		if a.contains("-check=") and not a.begins_with("--menu-check="):
			return false
	return not meta.story.flags.has("prologue_seen") and meta.runs == 0 and not has_run

## True when the run mode asks for the difficulty first (GDD difficulty §3.2):
## a new save (difficulty never picked, no finished run, no saved run) and no
## check or demo flag. Checks keep «Былина».
static func wants_difficulty_choice(args: PackedStringArray, meta: MetaState, has_run: bool) -> bool:
	for a in args:
		if (a.contains("-check=") and not a.begins_with("--menu-check=")) or a.begins_with("--demo="):
			return false
	return meta.difficulty == "" and meta.runs == 0 and not has_run

## Plays the Prologue, then writes the save and starts the run.
func start_prologue() -> Prologue:
	var pr := Prologue.new()
	pr.world = self
	pr.meta = director.game.meta
	pr.finished.connect(func() -> void:
		director.game.write_save()
		director.begin.call_deferred())
	add_child(pr)
	return pr

## Clears the level and builds room number room_k of location tier. The run
## passes its own `layout` and the room stream `p_rng` (RunRng.for_room, already
## used by the generator); without them the old seed formula is used.
func start_room(layout: Dictionary = {}, p_rng: RandomNumberGenerator = null) -> void:
	_clear_room()
	var rng := p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed_value * 1000 + tier * 100 + room_k
	if layout.is_empty():
		# Legacy check modes only (the run passes its layout): old layout without the
		# BUG-0004 safe start zone, so their recorded logs (--demo) stay comparable.
		layout = RoomGen.generate(rng, room_k, tier, Tune.data, false)
	# Location look (art-bible §4.1, locations.json "look" / "darkness").
	var loc: Dictionary = Tune.table("locations").get(str(tier), {})
	room = Room.new()
	room.look = loc.get("look", {})
	var vis := visuals_for(layout, room.look)
	room.vis = vis
	RenderingServer.set_default_clear_color(Color(String(room.look.get("sky", "#0c1418"))))
	add_child(room)
	room.build(layout)
	# Art slice (design/art/visual-upgrade-plan.md): pre-rendered enemy skins always;
	# the slice's own backdrop dressing only with --art-slice (the swamp's Blender
	# layers come through Backdrop / visuals.json "tex").
	for c in get_children():
		if c is ArtSlice:
			c.queue_free()
	var art := ArtSlice.new()
	art.room = room
	art.full = OS.get_cmdline_user_args().has("--art-slice")
	add_child(art)
	# Sleeping packs of the location roster (enemies-and-elites §3.3, room-generation §3.5).
	var table := Tune.table("enemies")
	var fly_y: Array = Tune.get_value("flyer_spawn_y")
	var ros := EnemyRoster.for_tier(tier, Tune.table("locations"), Tune.data)
	# Bestiary §3.6-3.7: a location with `intro` opens kinds by room and caps roles;
	# Болотница lies on the room's bog markers, in packs only when there are none.
	var intro: Dictionary = ros.intro
	var bogs: Array = layout.get("bogs", [])
	var bog_kind := EnemyRoster.spot_kind(intro, table, "bog")
	var bog_open := bog_kind != "" and int(intro[bog_kind]) <= room_k
	for i in layout.packs.size():
		var pack: Array = layout.packs[i]
		var kinds: Array[String] = EnemyRoster.pack_kinds_intro(rng, pack.size(), i, room_k, tier, intro, table, Tune.data, not bogs.is_empty()) \
			if not intro.is_empty() else EnemyRoster.pack_kinds(rng, pack.size(), i, room_k, tier, ros.roster, ros.late, table, Tune.data)
		for j in kinds.size():
			var e := EnemyRoster.make(kinds[j])
			# Elites (enemies-and-elites §3.6): the layout picks who, the mark fits the kind.
			if [i, j] in (layout.get("elites", []) as Array):
				e.mark = EliteMarks.pick(rng, kinds[j], Tune.data)
			var y := Tune.f("ground_y")
			if bool(table[kinds[j]].get("flies", false)):
				y = rng.randf_range(float(fly_y[0]), float(fly_y[1]))
			spawn_enemy(e, Vector2(pack[j], y), i, true, rng.randi())
	if bog_open:
		for bi in mini(bogs.size(), int(Tune.f("bog_max"))):
			var b := EnemyRoster.make(bog_kind)
			b.set("in_bog", true)
			spawn_enemy(b, bogs[bi], (layout.packs as Array).size() + 60 + bi, true, rng.randi())
	# Bestiary §3.4, §3.7 item 5, edge case 16: Сосульники hang on the ceiling markers only.
	var ceil_kind := EnemyRoster.spot_kind(intro, table, "ceiling")
	if ceil_kind != "" and int(intro[ceil_kind]) <= room_k:
		var ceils: Array = layout.get("ceilings", [])
		for ci in mini(ceils.size(), int(Tune.f("ceiling_max"))):
			spawn_enemy(EnemyRoster.make(ceil_kind), ceils[ci], (layout.packs as Array).size() + 70 + ci, true, rng.randi())
	_spawn_props(layout, rng)
	_add_hero(loc, vis, Vector2(Tune.f("hero_spawn_x"), Tune.f("ground_y")),
		Rect2i(0, mini(-400, int(float(layout.get("top", 0.0)) - 40.0)), int(layout.w), int(Tune.f("ground_y") + 220) - mini(-400, int(float(layout.get("top", 0.0)) - 40.0))))

## The hero (keeps the amulet charge), the camera with its limits `lim`, the HUD,
## darkness and the room air. Shared by start_room() and start_level().
func _add_hero(loc: Dictionary, vis: Dictionary, at: Vector2, lim: Rect2i) -> void:
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
	player.position = at
	add_child(player)
	if not hero_armor.is_empty():
		ShopRules.dress(player.visual, hero_armor, Tune.table("armor"))
	cam = Camera2D.new()
	cam.limit_left = lim.position.x
	cam.limit_right = lim.end.x
	cam.limit_bottom = lim.end.y
	cam.limit_top = lim.position.y
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	# Vertical dead zone (plan §2.7): margins are fractions of half the view height.
	var camv: Dictionary = Tune.table("visuals").get("camera", {})
	var half_h := 540.0 / Tune.f("camera_zoom")
	cam.drag_vertical_enabled = true
	cam.drag_top_margin = float(camv.get("drag_up", 80.0)) / half_h
	cam.drag_bottom_margin = float(camv.get("drag_down", 40.0)) / half_h
	_look = 0.0
	# ADR-0004: the screen is 1920x1080 but the world stays in prototype units;
	# zoom maps them, so the view shows 1280x720 units on 16:9 (more width on 21:9).
	cam.zoom = Vector2.ONE * Tune.f("camera_zoom")
	player.add_child(cam)
	cam.offset = CAM_OFFSET
	add_child(PostFx.make(vis.get("post", {})))
	var layer := CanvasLayer.new()
	layer.layer = PostFx.LAYER + 1
	hud = Label.new()
	hud.visible = debug_hud
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
	darkness.base = float(loc.get("darkness", -1.0))
	darkness.tint = Color(String(vis.get("dark_tint", "#00000000")))
	add_child(darkness)
	atmosphere = Atmosphere.new()
	atmosphere.world = self
	atmosphere.vis = vis
	atmosphere.dust = Color(String((vis.get("terrain", {}) as Dictionary).get("rim", "#8a7a60")))
	add_child(atmosphere)
	# Ambient light level (visuals.json "ambient"): a CanvasModulate so the amulet's
	# PointLight2D shades the normal-mapped sprites instead of blowing them out.
	if vis.has("ambient"):
		var cm := CanvasModulate.new()
		cm.color = Color(String(vis.ambient))
		atmosphere.add_child(cm)

## Frees everything of the current room (room, hero, enemies, props, HUD layers).
func _clear_room() -> void:
	for c in get_children():
		if c.name == "FpsLayer":
			continue
		if c is Room or c is Player or c is Enemy or c is EnemyShot or c is Camera2D or c is CanvasLayer \
				or c is Flare or c is Darkness or c is Door or c is RewardOrb or c is WeaponDrop or c is HeroShot \
				or c is Chest or c is Trap or c is FireTrail or c is KnightReward or c is Atmosphere or c is ArtSlice \
				or c is LevelFlow or c is Seal or c is BreakableWall:
			if c is Enemy:
				c.remove_from_group("enemies")
			c.queue_free()
	level_room = null

## The visuals.json style of a room: "base" for the base yard, else the
## location's look.props ("ruins" = swamp, "forest", "frost").
static func visuals_for(layout: Dictionary, look: Dictionary) -> Dictionary:
	var key := "base" if bool(layout.get("base", false)) else String(look.get("props", "ruins"))
	var t := Tune.table("visuals")
	return t.get(key, t.get("ruins", {}))

## F3 shows or hides the debug text (visual-upgrade-plan §2.8); Esc / pad Start
## opens the pause menu.
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F3:
		debug_hud = not debug_hud
		if hud:
			hud.visible = debug_hud
	if PauseMenu.is_open_event(event) and can_pause():
		get_viewport().set_input_as_handled()
		open_pause()

## True when the pause menu may open: nothing else holds the paused tree, and
## the run is not between screens (summary, death, scripted scenes).
func can_pause() -> bool:
	if get_tree().paused:
		return false
	for c in get_children():
		if c is Prologue:
			return false
	if director and director.base and director.base.get("screen") != null:
		return false
	return director == null or director.phase in ["fight", "doors", "base", "reward", "clear", "level"]

## The LevelFlow of a graph-mode level, null otherwise.
func level_flow() -> LevelFlow:
	for c in get_children():
		if c is LevelFlow and not c.is_queued_for_deletion():
			return c
	return null

## Opens the pause menu (above every game screen).
func open_pause() -> PauseMenu:
	var pm := PauseMenu.new()
	pm.can_quit = director != null and director.phase != "base" and director.run != null
	var fl := level_flow()
	if fl:
		pm.on_map = func() -> void: fl.open_full_map.call_deferred()
	pm.quit_to_base.connect(func() -> void:
		if director and director.run:
			director.finish("quit"))
	show_screen(pm, 50)
	return pm

## Chunk-room props (room-generation §3.6, §3.10, §3.13): the knight on his
## own pack, chests, the breakable wall and the traps of its pocket.
func _spawn_props(layout: Dictionary, rng: RandomNumberGenerator) -> void:
	if float(layout.get("knight_x", -1.0)) >= 0.0:
		spawn_enemy(Knight.new(), Vector2(float(layout.knight_x), Tune.f("ground_y")), (layout.packs as Array).size() + 50, true, rng.randi())
	for c: Dictionary in layout.get("chests", []):
		var ch := Chest.new()
		ch.world = self
		ch.rich = bool(c.rich)
		ch.position = Vector2(float(c.x), float(c.y))
		add_child(ch)
	var wl: Dictionary = layout.get("wall", {})
	if not wl.is_empty():
		var bw := BreakableWall.new()
		bw.w = float(wl.w)
		bw.h = float(wl.h)
		bw.world = self
		bw.position = Vector2(float(wl.x) + float(wl.w) / 2.0, float(wl.y))
		bw.rng = RandomNumberGenerator.new()
		add_child(bw)
	var n := 0
	for tr: Dictionary in layout.get("traps", []):
		var trap := Trap.new()
		trap.world = self
		trap.kind = String(tr.kind)
		trap.width = float(tr.w)
		trap.offset = n * 0.7
		trap.position = Vector2(float(tr.x), float(tr.y))
		add_child(trap)
		n += 1

## Height of the floor under `p`: the level's floor in graph mode, else ground_y.
## Static so shots, parts and the Flare can ask without a level (tests: w null).
static func floor_at(w: World, p: Vector2) -> float:
	if w and w.level_room:
		return w.level_room.floor_below(p)
	return Tune.f("ground_y")

## True when a shot at `p` hits the ground (single room: below ground_y + `below`)
## or a solid cell of the level.
static func shot_blocked(w: World, p: Vector2, below: float) -> bool:
	if w and w.level_room:
		return w.level_room.solid(w.level_room.cell_of(p)) or p.y > w.level_room.rows * w.level_room.cell
	return p.y > Tune.f("ground_y") + below

## Builds the whole level of a location (graph mode, GDD level-structure §3.9):
## the LevelRoom, its packs on E markers (EnemyRoster rules, room number k from
## the level section), flyers on F, Болотница on B, the knight on K, chests,
## breakable walls, thorns; the hero on P; the camera on both axes inside the level.
func start_level(level: Dictionary, rng: RandomNumberGenerator) -> void:
	_clear_room()
	var loc: Dictionary = Tune.table("locations").get(str(tier), {})
	var lr := LevelRoom.new()
	lr.look = loc.get("look", {})
	var vis := visuals_for({}, lr.look)
	lr.vis = vis
	RenderingServer.set_default_clear_color(Color(String(lr.look.get("sky", "#0c1418"))))
	room = lr
	level_room = lr
	add_child(lr)
	lr.build_level(level)
	var art := ArtSlice.new()
	art.room = lr
	add_child(art)
	var table := Tune.table("enemies")
	var ros := EnemyRoster.for_tier(tier, Tune.table("locations"), Tune.data)
	var intro: Dictionary = ros.intro
	var lv: Dictionary = Tune.data.get("level", {})
	var gap := float(lv.get("member_gap", 70.0))
	var room_pack := {}
	var bogs_by_room := {}
	for m: Dictionary in level.marks:
		if String(m.ch) == "B":
			if not bogs_by_room.has(int(m.room)):
				bogs_by_room[int(m.room)] = []
			(bogs_by_room[int(m.room)] as Array).append(m.c)
	for i in (level.packs as Array).size():
		var pk: Dictionary = level.packs[i]
		var k := int(pk.k)
		var at := lr.cell_floor(pk.c)
		var sp := lr.span_at(at)
		var n := int(pk.size)
		var kinds: Array[String] = EnemyRoster.pack_kinds_intro(rng, n, i, k, tier, intro, table, Tune.data, bogs_by_room.has(int(pk.room))) \
			if not intro.is_empty() else EnemyRoster.pack_kinds(rng, n, i, k, tier, ros.roster, ros.late, table, Tune.data)
		room_pack[int(pk.room)] = i
		for j in kinds.size():
			var e := EnemyRoster.make(kinds[j])
			if j in (pk.elites as Array):
				e.mark = EliteMarks.pick(rng, kinds[j], Tune.data)
			var x := clampf(at.x + (j - (kinds.size() - 1) / 2.0) * gap, float(sp.x0) + 30.0, float(sp.x1) - 30.0)
			var y := at.y
			if bool(table[kinds[j]].get("flies", false)):
				y = at.y - rng.randf_range(140.0, 220.0)
			spawn_enemy(e, Vector2(x, y), i, true, rng.randi())
	var npk := (level.packs as Array).size()
	# Flyers on F (only kinds already open at the room's k), Болотница on B.
	var fly_kinds: Array[String] = []
	for id: String in intro:
		if bool((table.get(id, {}) as Dictionary).get("flies", false)):
			fly_kinds.append(id)
	var bog_kind := EnemyRoster.spot_kind(intro, table, "bog")
	var rooms: Array = level.rooms
	var extra := 0
	for m: Dictionary in level.marks:
		var ri := int(m.room)
		var rr: Dictionary = rooms[ri]
		if String(rr.kind) in ["entry", "fork", "altar", "junction", "lairgate", "nook", "secret"]:
			continue
		var k := 1 if int(rr.sec) == 0 else int(rr.sec) + 1
		var pid := int(room_pack.get(ri, npk + 100 + ri))
		match String(m.ch):
			"F":
				var open: Array[String] = []
				for id in fly_kinds:
					if int(intro[id]) <= k:
						open.append(id)
				if not open.is_empty() and rng.randf() < float(lv.get("flyer_chance", 0.6)):
					spawn_enemy(EnemyRoster.make(open[rng.randi_range(0, open.size() - 1)]), lr.cell_floor(m.c) - Vector2(0, 20), pid, true, rng.randi())
			"B":
				if bog_kind != "" and int(intro[bog_kind]) <= k and extra < 60 and rng.randf() < float(lv.get("bog_chance", 0.5)):
					var b := EnemyRoster.make(bog_kind)
					b.set("in_bog", true)
					spawn_enemy(b, Vector2((m.c.x + 0.5) * lr.cell, m.c.y * lr.cell), pid, true, rng.randi())
					extra += 1
	var kn: Dictionary = level.get("knight", {})
	if not kn.is_empty():
		spawn_enemy(Knight.new(), lr.cell_floor(kn.c), npk + 50, true, rng.randi())
	for c: Dictionary in level.chests:
		var ch := Chest.new()
		ch.world = self
		ch.rich = bool(c.rich)
		ch.vault = bool(c.get("vault", false))
		if ch.vault:
			ch.seal = String((level.rooms[int(c.room)] as Dictionary).get("seal", ""))
		ch.position = lr.cell_floor(c.c)
		add_child(ch)
	for wl: Dictionary in level.walls:
		var bw := BreakableWall.new()
		var c0: Vector2i = wl.c0
		var c1: Vector2i = wl.c1
		bw.w = lr.cell
		bw.h = (c1.y - c0.y + 1) * lr.cell
		bw.world = self
		bw.position = Vector2((c0.x + 0.5) * lr.cell, (c1.y + 1) * lr.cell)
		bw.rng = RandomNumberGenerator.new()
		add_child(bw)
	var atbl := Tune.table("artifacts")
	var meta: MetaState = director.game.meta if director and director.game else null
	for sl: Dictionary in level.get("seals", []):
		var z: Vector2i = sl.z
		if z.x < 0:
			continue
		var se := Seal.new()
		se.world = self
		se.meta = meta
		se.tbl = atbl
		se.kind = String(sl.kind)
		se.cell = lr.cell
		se.position = lr.cell_floor(z)
		se.x_cells = sl.x
		se.w_cells = sl.wc
		var o: Vector2i = sl.o
		if o.x >= 0:
			se.hook = Vector2((o.x + 0.5) * lr.cell, (o.y + 0.5) * lr.cell)
			se.land = lr.cell_floor(lr.stand_near(o, int(sl.room)))
		add_child(se)
	var nt := 0
	for r: Rect2 in lr.merged_rects("^"):
		var trap := Trap.new()
		trap.world = self
		trap.kind = "thorns"
		trap.width = r.size.x
		trap.offset = nt * 0.7
		trap.position = Vector2(r.position.x, r.end.y)
		add_child(trap)
		nt += 1
	var start := lr.cell_floor(Vector2i(2, 2))
	for m: Dictionary in level.marks:
		if String(m.ch) == "P":
			start = lr.cell_floor(m.c)
	_add_hero(loc, vis, start, Rect2i(0, 0, int(lr.cols * lr.cell), int(lr.rows * lr.cell)))
	# Darkness grows with depth (level-structure §3.8 item 4) — LevelFlow updates it per band.
	cam.reset_smoothing()

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
	if level_room:
		level_room.fit_enemy(e)
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
	if GameSettings.shake_on:
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
	var m := 1.0 if GameSettings.flash_on else Tune.f("flash_off_mult")
	flash = clampf(maxf(flash, v * m), 0.0, 1.0)

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
		# Look-ahead in the facing direction (plan §2.7), eased over look_time.
		var camv: Dictionary = Tune.table("visuals").get("camera", {})
		if player and is_instance_valid(player):
			var want := float(player.face) * float(camv.get("look_ahead", 140.0))
			_look += (want - _look) * minf(1.0, dt / maxf(float(camv.get("look_time", 0.4)), 0.01))
		if level_room and player and is_instance_valid(player):
			var lv: Dictionary = Tune.data.get("level", {})
			var want_y := float(lv.get("cam_fall_lead", 120.0)) if player.velocity.y > float(lv.get("cam_fall_speed", 600.0)) else 0.0
			_fall_look += (want_y - _fall_look) * minf(1.0, dt / 0.25)
		cam.offset = CAM_OFFSET + Vector2(_look, _fall_look) + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
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
