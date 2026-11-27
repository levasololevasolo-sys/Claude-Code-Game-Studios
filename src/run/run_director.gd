## Plays one run on the World scene (GDD room-generation-and-doors §3.2, §3.7-3.9,
## §3.14, §3.16; economy-and-meta §3.2-3.3, §3.7; ADR-0003). Flow: start rune
## offer → combat rooms 1..rooms_per_loc (packs sleep, all dead → reward at the
## right edge → doors) → lair (stand-in boss, choice of 3 gods) → haven (heal,
## save, next location or base) → death / base → summary → the base «Застава»
## (src/base/base.gd, economy-and-meta §3.6) → its gate → new run.
## Owns no rules of its own: forks and pacing are DoorRules, state is RunState,
## files are the injected Game autoload. Phases: "fight" → "reward" → "busy"
## (a screen is open) → "doors"; "dead" → "summary" → "base".
class_name RunDirector
extends Node

## A room was built (stage "room"/"lair"/"haven", room number).
signal room_started(stage: String, k: int)
## The doors of the room are open.
signal doors_opened(doors: Array[Door])
## A choice screen opened (RuneOfferScreen, GodChoiceScreen, RunSummaryScreen).
signal screen_opened(screen: Control)
## One line of what happened (the run check logs these).
signal noted(text: String)

var world: World
## The Game autoload (meta, run, rng, save), injected by World.
var game: Node
var run: RunState
var build: RunBuild
var phase: String = "fight"
var orb: RewardOrb
var doors: Array[Door] = []
## Open screen, null when none.
var screen: Control
var _clear_t: float = 0.0
var _dead_t: float = 0.0
var _confirm_t: float = 0.0
var _toast: String = ""
var _toast_t: float = 0.0
var _unl: Dictionary = {}
## Tier whose Навий витязь has already stood in a room (one per location, §3.6).
var knight_tier: int = -1
## The base between runs (null during a run).
var base: Base
const BASE_SCENE: String = "res://scenes/base/base.tscn"

## Story scene playing (first win), null when none.
var scene: Node
## Called instead of finish("win") when the last built boss falls (checks hook it).
var win_hook: Callable

func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.rune_taken.connect(_on_rune_taken)

## Story events of a taken rune (StoryRules.note_rune: rune_first, duo_first).
func _on_rune_taken(id: String, slot: String, _replaced: String) -> void:
	if run == null or build == null:
		return
	StoryRules.note_rune(game.meta, run.story_ev, id, build.god_of(id), slot)

## The god voice over a rune offer (gods.md §0; StoryRules.god_line): first
## offer of the god = its first line, a union card = the partner god answers,
## else a random line not among the last god_line_recent.
func god_voice(scr: RuneOfferScreen) -> void:
	if scr == null or scr.god == "" or scr.mode != "take":
		return
	var union := ""
	for id in scr.ids:
		var gs: Array = build.row(id).get("gods", []) if build else []
		if String(build.slot_of(id)) == "duo" and gs.size() == 2:
			union = String(gs[1]) if String(gs[0]) == scr.god else String(gs[0])
			break
	var st: Dictionary = game.meta.story
	var ctx := { "seen": int((st.god_seen as Dictionary).get(scr.god, 0)), "union": union,
		"recent": st.god_recent, "roll": game.rng.stream("story").randf() if game.rng else randf() }
	var l := StoryRules.god_line(Tune.table("dialogue").get("god_lines", []), scr.god, ctx)
	StoryRules.note_god_line(game.meta, scr.god, l, int(Tune.f("god_line_recent")))
	if l.is_empty():
		return
	scr.voice_god = String(l.god)
	scr.voice_text = String(l.get("ru", ""))
	scr.queue_redraw()
	_note("god voice %s: %s" % [scr.voice_god, scr.voice_text])

## True when tier `t` is the last location with a built lair (the next row is a stub).
static func last_built(t: int) -> bool:
	var nxt: Dictionary = Tune.table("locations").get(str(t + 1), {})
	return t >= 5 or nxt.is_empty() or bool(nxt.get("stub", false))

## Starts: resumes a run saved at the haven (edge case 16), else a new run.
func begin() -> void:
	var saved: RunState = game.run
	if saved != null and saved.stage == "haven":
		run = saved
		build = RunBuild.from_dict(run.build)
		_bind_build()
		world.arm = Weapon.from_dict(run.arm)
		world.sub_arm = Weapon.from_dict(run.sub)
		if world.arm == null:
			_start_weapons()
		_note("resume run seed %d at haven of tier %d" % [run.run_seed, run.tier])
		enter_room()
	else:
		new_run()

## A new run on `run_seed` (-1 = --seed= or a fresh random seed).
func new_run(run_seed: int = -1) -> void:
	if run_seed < 0:
		run_seed = randi() % 2147483647
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--seed=") and game.meta.runs == 0:
				run_seed = int(a.trim_prefix("--seed="))
	run = game.start_run(run_seed)
	build = RunBuild.make()
	# Сова's amulet (economy §3.10 `lantern`) unless --amulet= picks one for a check.
	var amulet_arg := false
	for a in OS.get_cmdline_user_args():
		amulet_arg = amulet_arg or a.begins_with("--amulet=")
	if not amulet_arg and Tune.table("amulets").has(game.meta.lantern):
		world.amulet_id = game.meta.lantern
	run.amulet = world.amulet_id
	_bind_build()
	_start_weapons()
	run.stage = "room"
	run.room_k = 1
	run.tier = 1
	_note("new run seed %d, finished runs %d, gods open %s, door types %s" % [run.run_seed, game.meta.runs, _unl.gods, _unl.types])
	# The start offer is a god reward (gods-and-runes §3.3): pacing first, then room 1's reward.
	DoorRules.apply_pacing(run, "god", _doors_rng(), Tune.data)
	run.reward = DoorRules.first_room_reward(_doors_rng(), _ctx(), Tune.data)
	enter_room()
	var gods: Array = _unl.gods
	var god := String(gods[game.rng.stream("boons").randi_range(0, gods.size() - 1)])
	_note("start offer: %s" % god)
	_offer(god, func() -> void: _save_build())

func _bind_build() -> void:
	world.hero_armor = game.meta.armor
	world.build = build
	world.offer_rng = game.rng.stream("boons")
	_unl = DoorRules.unlocks(game.meta.runs, game.meta.bosses_beaten(), _all_gods(), Tune.data)

## Builds the room of run.stage and puts the hero in with the run's hp.
func enter_room() -> void:
	orb = null
	doors.clear()
	world.tier = run.tier
	world.room_k = run.room_k
	world.first_run = game.meta.runs == 0
	var rng: RandomNumberGenerator = game.rng.for_room(run.tier, run.room_k if run.stage == "room" else (10 if run.stage == "lair" else 11))
	var layout: Dictionary
	match run.stage:
		"lair":
			layout = { "w": Tune.f("lair_room_w"), "plats": LairBoss.arena_plats(String(_loc().get("boss", LairBoss.FALLBACK_ID))), "packs": [], "portal": false, "lair": true }
		"haven":
			layout = { "w": Tune.f("haven_room_w"), "plats": [], "packs": [], "portal": false, "haven": true }
		_:
			layout = RoomGen.generate(rng, run.room_k, run.tier, Tune.data, true, room_opts())
			layout["portal"] = false
	world.start_room(layout, rng)
	world.player.hp = run.hp
	world.player.died.connect(_on_died)
	# GDD difficulty F5: Нить Мокоши tokens left this run.
	world.player.revives = maxi(0, Difficulty.revives_for(Difficulty.current, Difficulty.table()) - run.revives_used)
	world.player.revived.connect(_on_revived)
	if run.stage == "lair":
		var boss := LairBoss.make(String(_loc().get("boss", LairBoss.FALLBACK_ID)))
		boss.title = String(_loc().get("boss_name", "Хозяин"))
		world.spawn_enemy(boss, Vector2(layout.w * 0.6, Tune.f("ground_y")), 0, true, rng.randi())
	phase = "fight"
	_clear_t = Tune.f("clear_delay")
	_note("enter %s tier %d room %d (w %d, packs %d), reward %s, hp %d" % [run.stage, run.tier, run.room_k, int(layout.w), (layout.packs as Array).size(), run.reward, roundi(run.hp)])
	room_started.emit(run.stage, run.room_k)
	if run.stage == "haven":
		_enter_haven()

func _physics_process(dt: float) -> void:
	_toast_t -= dt
	_confirm_t -= dt
	var p := world.player if world else null
	if p == null or not is_instance_valid(p) or (run == null and phase != "base"):
		return
	match phase:
		"fight":
			if alive_enemies() == 0:
				_clear_t -= dt
				if _clear_t <= 0.0:
					_on_cleared()
		"reward":
			if orb and absf(p.position.x - orb.position.x) < Tune.f("door_reach"):
				_collect()
		"doors":
			for i in doors.size():
				var d := doors[i]
				var n := absf(p.position.x - d.position.x) < Tune.f("door_reach")
				if n != d.near:
					d.near = n
					d.queue_redraw()
			if not p.scripted and Input.is_action_just_pressed(&"interact"):
				for i in doors.size():
					if doors[i].near and doors[i].active:
						enter_door(i)
						break
		"dead":
			_dead_t -= dt
			if _dead_t <= 0.0:
				finish("dead")

## Chunk-room options of this room (room-generation §3.6, §3.10; enemies-and-elites
## §3.6). The knight: rooms 2-4 with chance knight_door, surely in the last room;
## rolled here on the doors stream (door helmets are not drawn yet). Elites: from
## elite_from_tier after the first boss win. Breakable wall: not in tier 1 room 1,
## only once the cache door type is open.
func room_opts() -> Dictionary:
	var per_loc := int(Tune.f("rooms_per_loc"))
	var knight := false
	if knight_tier != run.tier and run.room_k >= 2:
		knight = run.room_k >= per_loc or _doors_rng().randf() < Tune.f("knight_door")
	if knight:
		knight_tier = run.tier
	var types: Array = _unl.get("types", [])
	return { "knight": knight,
		"elites_ok": run.tier >= int(Tune.f("elite_from_tier")) and game.meta.bosses_beaten() > 0,
		"secret_ok": not (run.tier == 1 and run.room_k == 1) and "cache" in types,
		"loc": String(_loc().get("lib", "swamp")) }

## A chest was opened (§3.13): ordinary 18 embers, 3 resource, drop_from("chest");
## secret pocket 40 embers, 6 resource, drop_from("cache"), 50% heal 20.
func open_chest(c: Chest) -> void:
	var res_id := String(_loc().get("res", "gears"))
	var at := c.position + Vector2(0, 0)
	if c.rich:
		var e := roundi(Tune.f("cache_embers") * Difficulty.embers_mult())
		run.embers += e
		run.add_res(res_id, int(Tune.f("cache_res")))
		var healed := 0.0
		if game.rng.stream("loot").randf() < Tune.f("cache_heal_chance") and world.player:
			healed = minf(run.max_hp - world.player.hp, Difficulty.heal(Tune.f("cache_heal")))
			world.player.hp += healed
		var it := drop_from("cache", at)
		_say("Тайник: +%d углей, +%d %s%s" % [e, int(Tune.f("cache_res")), _loc().get("res_name", ""), (", +%d здоровья" % int(healed)) if healed > 0.0 else ""])
		_note("cache chest opened: +%d embers, heal %d, weapon %s" % [e, int(healed), it.id if it else "-"])
	else:
		var e := roundi(Tune.f("chest_embers") * Difficulty.embers_mult())
		run.embers += e
		run.add_res(res_id, int(Tune.f("chest_res")))
		var it := drop_from("chest", at)
		_say("Сундук: +%d углей" % e)
		_note("chest opened: +%d embers, weapon %s" % [e, it.id if it else "-"])

## The knight's stone i was taken (enemies-and-elites §3.7): 0 Род rune offer,
## 1 weapon (drop_from "knight", quality +1), 2 rich chest (knight_chest_*).
func knight_reward(i: int, at: Vector2) -> void:
	match i:
		0:
			_note("knight reward: rod rune")
			_offer("rod", func() -> void: pass)
		1:
			var it := drop_from("knight", at)
			_note("knight reward: weapon %s" % (it.id if it else "-"))
		_:
			var e := roundi(Tune.f("knight_chest_embers") * Difficulty.embers_mult())
			run.embers += e
			run.add_res(String(_loc().get("res", "gears")), int(Tune.f("knight_chest_res")))
			if world.player:
				world.player.hp = minf(run.max_hp, world.player.hp + Difficulty.heal(Tune.f("knight_chest_heal")))
			_say("Богатый сундук: +%d углей" % e)
			_note("knight reward: rich chest +%d embers" % e)

## Living enemies in the room, sleeping ones included (§3.7, AC 15). Props
## (breakable walls) do not count.
func alive_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e as Enemy).dead and not (e as Enemy).prop:
			n += 1
	return n

## Door slot x positions: index 0 is the leftmost, the last sits at the right edge.
func _door_x(i: int, n: int) -> float:
	return float(world.room.layout.w) - 120.0 - (n - 1 - i) * Tune.f("door_gap")

func _on_cleared() -> void:
	run.rooms_cleared += 1
	var w := float(world.room.layout.w)
	var info: Dictionary = run.reward if run.stage == "room" else { "type": "lair", "god": "" }
	orb = RewardOrb.new()
	orb.info = info
	orb.position = Vector2(_door_x(0, 3) - Tune.f("orb_gap"), Tune.f("ground_y"))
	world.add_child(orb)
	phase = "reward"
	_note("cleared %s %d -> reward %s at x %d (room w %d)" % [run.stage, run.room_k, info, int(orb.position.x), int(w)])

func _collect() -> void:
	orb.queue_free()
	orb = null
	phase = "busy"
	if run.stage == "lair":
		_lair_choice()
		return
	var type := String(run.reward.get("type", "loot"))
	match type:
		"god":
			_offer(String(run.reward.god), func() -> void: _reward_done("god"))
		"rod":
			_offer("rod", func() -> void: _reward_done("rod"))
		"surica":
			var ids := build.raisable()
			if ids.is_empty():
				_give_loot()
				_reward_done("loot")
				return
			_shuffle(ids, game.rng.stream("boons"))
			var scr := RuneOfferScreen.new()
			scr.mode = "surica"
			scr.build = build
			scr.hero = world.player
			scr.ids.assign(ids.slice(0, int(Tune.f("surica_count"))))
			scr.chosen.connect(func(id: String) -> void:
				_note("surica raised %s to %d" % [id, build.level(id)])
				_reward_done("surica"))
			_show(scr)
		"loot":
			_give_loot()
			_reward_done("loot")
		"heal":
			var p := world.player
			var add := roundf(Difficulty.heal(run.max_hp * Tune.f("heal_frac")))
			p.hp = minf(run.max_hp, p.hp + add)
			_say("Живой родник: +%d здоровья" % int(add))
			_reward_done("heal")
		"arms":
			# §3.8: 1 item in the centre of the room after the clear, quality bonus 1.
			var it := drop_from("door", Vector2(float(world.room.layout.w) / 2.0, Tune.f("ground_y")))
			_say("Оружие: %s" % (it.title() + " " + it.stars() if it else "ничего"))
			_reward_done("arms")

func _give_loot() -> void:
	var e := roundi(Tune.f("loot_embers") * Difficulty.embers_mult())
	var r := int(Tune.f("loot_res"))
	run.embers += e
	run.add_res(String(_loc().get("res", "gears")), r)
	_say("Добыча: +%d углей, +%d %s" % [e, r, _loc().get("res_name", "")])

## §3.16: up to 3 different open gods; the chosen one opens its rune offer.
## Edge 15 (no god can give anything) is not reachable yet: every god has 4 runes.
func _lair_choice() -> void:
	var gods := DoorRules.lair_gods(game.rng.stream("boons"), _unl.gods, build.gods_taken(), int(Tune.f("lair_gods")))
	var scr := GodChoiceScreen.new()
	scr.gods = gods
	scr.held = build.gods_taken()
	scr.title = "%s %s — выбери бога" % [_loc().get("boss_name", "Хозяин"), _loc().beaten] if _loc().has("beaten") else "Хозяин повержен — выбери бога"
	scr.chosen.connect(func(g: String) -> void:
		_note("lair god chosen: %s (of %s)" % [g, gods])
		_offer.call_deferred(g, func() -> void: _reward_done("god")))
	_note("lair gods offered: %s" % [gods])
	_show(scr)

func _offer(god: String, done: Callable) -> void:
	var scr := world.open_rune_offer(god, false, { "duos_open": game.meta.runs >= int(Tune.f("unlock_all_gods_runs")) })
	screen = scr
	god_voice(scr)
	scr.chosen.connect(func(id: String) -> void:
		_note("rune taken: %s (offer %s)" % [id, scr.ids])
		screen = null
		done.call())
	screen_opened.emit(scr)

func _show(scr: Control, layer: int = 20) -> void:
	screen = scr
	scr.tree_exited.connect(func() -> void:
		if screen == scr:
			screen = null)
	world.show_screen(scr, layer)
	screen_opened.emit(scr)

func _save_build() -> void:
	run.build = build.to_dict()
	run.arm = world.arm.to_dict() if world.arm else {}
	run.sub = world.sub_arm.to_dict() if world.sub_arm else {}

## §3.9 p.6, AC 12, edge case 18: the run starts with the bought kinds at ★, no
## affix; a kind missing from the data falls back to blade (if bought) or stick.
func _start_weapons() -> void:
	var m: MetaState = game.meta
	var w := Weapon.from_dict({ "id": m.weapon })
	if w == null:
		w = Weapon.make("blade" if bool(m.weapons.get("blade", false)) else "stick")
	world.arm = w
	world.sub_arm = Weapon.from_dict({ "id": m.sub, "kind": Weapon.SUB }) if m.sub != "" else null
	if run:
		run.arms_auto = 0
		_save_build()

## Weapon drop hook (weapons-and-loot §3.8) for every source: "boss", "door",
## "knight", "chest", "cache", "elite" (arms_sources: chance, quality bonus,
## counts toward arms_auto_cap). Rolls with LootRoller on the "loot" stream
## (ADR-0003) and lays a WeaponDrop at `at`. Returns the weapon or null.
## `kind` / `rar` / `q` force the slot, rarity, quality (Yaga: "arm", "l", 2).
func drop_from(source: String, at: Vector2, kind: String = "", rar: String = "", q: int = 0) -> Weapon:
	var src: Dictionary = (Tune.get_value("arms_sources") as Dictionary).get(source, {})
	var rng: RandomNumberGenerator = game.rng.stream("loot")
	if src.is_empty() or rng.randf() >= float(src.get("chance", 1.0)):
		return null
	if bool(src.get("auto", false)):
		if run.arms_auto >= int(Tune.f("arms_auto_cap")):
			return null
		run.arms_auto += 1
	var floor_ids: Array = []
	for c in world.get_children():
		if c is WeaponDrop and (c as WeaponDrop).weapon:
			floor_ids.append((c as WeaponDrop).weapon.id)
	var m: MetaState = game.meta
	var ctx := { "kind": kind, "rar": rar, "tier": run.tier, "bonus": int(src.get("bonus", 0)), "luck": false,
		"gods": build.gods_taken(), "held_arm": world.arm.id if world.arm else "", "held_sub": world.sub_arm.id if world.sub_arm else "",
		"floor": floor_ids, "owned_arms": m.weapons, "owned_subs": m.subs, "pity": m.pity }
	if q > 0:
		ctx["q"] = q
	var d := LootRoller.roll(rng, ctx, { "weapons": Tune.table("weapons"), "subweapons": Tune.table("subweapons"),
		"affixes": Tune.table("affixes") }, Tune.data)
	if d.is_empty():
		return null
	var w := Weapon.from_dict(d)
	StoryRules.note_weapon(m, run.story_ev, w.id)
	var drop := WeaponDrop.new()
	drop.weapon = w
	drop.world = world
	drop.position = at
	world.add_child(drop)
	_note("arms drop (%s): %s %s %s [%s], pity %s" % [source, w.kind, w.id, w.stars(), w.affix, m.pity])
	return w

## A reward was given: pacing (F4.4), snapshot fields, then the doors.
func _reward_done(type: String) -> void:
	DoorRules.apply_pacing(run, type, _doors_rng(), Tune.data)
	_save_build()
	run.hp = world.player.hp
	_open_doors()

func _open_doors() -> void:
	var infos: Array[Dictionary] = []
	var per_loc := int(Tune.f("rooms_per_loc"))
	match run.stage:
		"room":
			if run.room_k < per_loc:
				infos = DoorRules.make_fork(_doors_rng(), _ctx(), Tune.data)
			else:
				infos = [{ "type": "lair", "god": "", "arg": String(_loc().get("boss_name", "")) }]
		"lair":
			infos = [{ "type": "haven", "god": "" }]
		"haven":
			if run.tier < 5:
				var nxt: Dictionary = Tune.table("locations").get(str(run.tier + 1), {})
				infos.append({ "type": "next_loc", "god": "", "arg": String(nxt.get("name", "?")) + (" (заглушка)" if bool(nxt.get("stub", false)) else "") })
			infos.append({ "type": "base", "god": "" })
	for i in infos.size():
		var d := Door.new()
		d.info = infos[i]
		d.position = Vector2(_door_x(i, infos.size()), Tune.f("ground_y"))
		world.add_child(d)
		doors.append(d)
	phase = "doors"
	_note("doors (since_god %d, gap_need %d): %s" % [run.since_god, run.gap_need, ", ".join(PackedStringArray(doors.map(func(d: Door) -> String: return d.label())))])
	doors_opened.emit(doors)

## Goes through door `i` (the hero pressed E in front of it, or the run check).
func enter_door(i: int) -> void:
	if phase != "doors" or i < 0 or i >= doors.size():
		return
	var info := doors[i].info
	run.hp = world.player.hp
	_note("enter door %d: %s" % [i, doors[i].label()])
	match String(info.type):
		"lair":
			run.stage = "lair"
			run.reward = {}
		"haven":
			# Locations 4-5 are not built: beating the last built lair boss is the win
			# for now (prologue-and-endings §2 trigger stand-in), the first one plays
			# the first-win scene instead of the haven.
			if last_built(run.tier) and run.bosses > 0:
				_win()
				return
			run.stage = "haven"
		"next_loc":
			# §3.7 step 3: choosing a door wipes the run snapshot from the file.
			var keep: RunState = game.run
			game.run = null
			game.write_save()
			game.run = keep
			run.tier += 1
			run.stage = "room"
			run.room_k = 1
			_unl = DoorRules.unlocks(game.meta.runs, game.meta.bosses_beaten(), _all_gods(), Tune.data)
			run.reward = DoorRules.first_room_reward(_doors_rng(), _ctx(), Tune.data)
		"base":
			if _confirm_t > 0.0:
				finish("home")
				return
			_confirm_t = Tune.f("base_confirm_time")
			doors[i].note = "E ещё раз — на заставу"
			doors[i].queue_redraw()
			return
		_:
			run.room_k += 1
			run.reward = { "type": info.type, "god": info.god }
	enter_room()

## Haven (§3.16, economy-and-meta §3.7): heal haven_heal of max hp, save, doors.
func _enter_haven() -> void:
	var p := world.player
	var add := roundf(Difficulty.heal(run.max_hp * Tune.f("haven_heal")))
	p.hp = minf(run.max_hp, p.hp + add)
	run.hp = p.hp
	_save_build()
	var ok: bool = game.write_save()
	_say("Привал: +%d здоровья, забег сохранён" % int(add))
	_note("haven: healed +%d to %d, save written %s to %s" % [int(add), roundi(p.hp), ok, game.save_path])
	_open_doors()

## The hero spent a Нить Мокоши token (GDD difficulty §3.5).
func _on_revived() -> void:
	run.revives_used += 1
	_say("Нить Мокоши удержала тебя на этом свете")
	_note("revive: token spent (%d used)" % run.revives_used)

func _on_died(hit: Hit) -> void:
	var src: Node = hit.source if hit and is_instance_valid(hit.source) else null
	if src is Enemy:
		run.killed_by = String((src as Enemy).stats.get("name", (src as Enemy).kind_id))
		run.killer_id = String(_loc().get("boss", "boss")) if (src as Enemy).boss else (src as Enemy).kind_id
	else:
		run.killed_by = "неизвестно"
	run.hp = 0.0
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if e is LairBoss:
			(e as LairBoss).on_hero_died()
	phase = "dead"
	_dead_t = Tune.f("death_summary_delay")
	_note("hero died in %s %d, killed by %s" % [run.stage, run.room_k, run.killed_by])

## The run is won: the first win plays StoryScene "first_win" (a text sequence),
## then endRun with outcome "win".
func _win() -> void:
	phase = "busy"
	_note("win: last built boss of tier %d beaten (wins before %d)" % [run.tier, game.meta.wins])
	if win_hook.is_valid():
		win_hook.call()
		return
	if game.meta.wins == 0:
		scene = StoryScene.first_win(world, game.meta)
		scene.finished.connect(func() -> void:
			scene = null
			finish("win"))
		world.add_child(scene)
	else:
		finish("win")

## endRun (economy-and-meta §3.7) and the summary; closing it starts a new run.
func finish(outcome: String) -> void:
	phase = "summary"
	_save_build()
	var b := build
	var summary: Dictionary = game.end_run(outcome)
	var scr := RunSummaryScreen.new()
	scr.summary = summary
	scr.build = b
	scr.closed.connect(func() -> void: enter_base.call_deferred())
	_note("run ended (%s): %s" % [outcome, " | ".join(scr.lines())])
	_show(scr, 30)

## The base between runs (economy-and-meta §3.6): the yard is a room without
## enemies, the hero walks it; this visit's lines are picked and the save
## written. The gate (Base.gate_used) starts the next run.
func enter_base() -> void:
	phase = "base"
	run = null
	orb = null
	doors.clear()
	world.hero_armor = game.meta.armor
	world.first_run = false
	var w := float(Tune.table("base").get("width", 2700))
	world.start_room({ "w": w, "plats": [], "packs": [], "portal": false, "base": true })
	base = (load(BASE_SCENE) as PackedScene).instantiate() as Base
	world.add_child(base)
	base.setup(world, game.meta)
	base.gate_used.connect(leave_base)
	base.on_change = func() -> void: game.write_save()
	base.screen_opened.connect(func(scr: Control) -> void: screen_opened.emit(scr))
	var ok: bool = game.write_save()
	_note("enter base: visit %d, lines %s, save %s" % [int(game.meta.story.visits), base.picked.keys(), ok])
	room_started.emit("base", 0)

## Leaves the base through the gate: a new run.
func leave_base() -> void:
	if base == null:
		return
	base.queue_free()
	base = null
	_note("gate: new run")
	new_run.call_deferred()

func _on_enemy_killed(enemy: Node2D, _hit: RefCounted) -> void:
	if run == null or not enemy is Enemy:
		return
	var e := enemy as Enemy
	run.kills += 1
	var res_id := String(_loc().get("res", "gears"))
	if e.boss:
		run.bosses += 1
		run.embers += roundi(Tune.f("lair_embers") * Difficulty.embers_mult())
		run.add_res(res_id, int(Tune.f("lair_res")))
		run.add_res("cores", int(Tune.f("lair_hearts")))
		var id := String(_loc().get("boss", "boss"))
		game.meta.bosses[id] = int(game.meta.bosses.get(id, 0)) + 1
		# §3.8: bosses 1-4 drop a weapon; Koschei (tier 5) is the victory, no weapon.
		if run.tier < 5:
			drop_from("boss", e.position)
		_note("boss %s killed: +%d embers" % [id, int(Tune.f("lair_embers"))])
	else:
		if e is Knight:
			var kr := KnightReward.new()
			kr.world = world
			kr.director = self
			kr.position = Vector2(clampf(e.position.x, 200.0, float(world.room.layout.w) - 200.0), Tune.f("ground_y"))
			world.add_child(kr)
			_note("knight killed at x %d: reward stones laid" % int(e.position.x))
		elif e.mark != "":
			drop_from("elite", e.position)
		# Picked up at once for now: ground pickups (economy §3.2) come with the loot step.
		run.embers += maxi(1, roundi(float(e.stats.get("embers", 0)) * Difficulty.embers_mult()))
		if game.rng.stream("loot").randf() < Tune.f("res_drop"):
			run.add_res(res_id, 1)

## HUD text (World shows it): hp, embers and resources of this run (§3.2: no
## bank line), location and room x/4, rune slots with names and levels.
func hud_text() -> String:
	if phase == "base" and base:
		var n := base.nearest()
		return "Застава    %s    Звание: %s\n%s" % [base._bank(), base._title(),
			("E — " + String(n.row.get("name", ""))) if n else "Подойди к NPC и нажми E · Ворота — новый забег"]
	if run == null:
		return ""
	var p := world.player
	var res_txt: PackedStringArray = []
	for k: String in run.res:
		res_txt.append("%s %d" % [res_name(k), int(run.res[k])])
	var where := "логово" if run.stage == "lair" else ("привал" if run.stage == "haven" else "комната %d/%d" % [run.room_k, int(Tune.f("rooms_per_loc"))])
	var t := "HP %d/%d    Угли %d    %s\n%s — %s    seed %d\n%s" % [roundi(p.hp), roundi(run.max_hp), run.embers,
		"   ".join(res_txt), _loc().get("name", ""), where, run.run_seed, build.hud_text() if build else ""]
	if _toast_t > 0.0:
		t += "\n" + _toast
	elif phase == "doors":
		t += "\nВстань у двери и нажми E"
	return t

func _say(s: String) -> void:
	_toast = s
	_toast_t = 3.0

func _note(s: String) -> void:
	print("[run] ", s)
	noted.emit(s)

func _loc() -> Dictionary:
	return Tune.table("locations").get(str(run.tier if run else 1), {})

## Display name of a resource id (locations.json res_name; cores = сердца).
static func res_name(k: String) -> String:
	if k == "cores":
		return "сердца"
	for id: String in Tune.table("locations"):
		var row: Variant = Tune.table("locations")[id]
		if row is Dictionary and String(row.get("res", "")) == k:
			return String(row.get("res_name", k))
	return k

func _doors_rng() -> RandomNumberGenerator:
	return game.rng.stream("doors")

func _ctx() -> Dictionary:
	return { "god_time": DoorRules.god_time(run.since_god, run.gap_need), "gods": _unl.gods,
		"types": _unl.types, "can_surica": not build.raisable().is_empty() }

func _all_gods() -> Array[String]:
	var out: Array[String] = []
	for id: String in Tune.table("gods"):
		if not id.begins_with("_") and id != "rod":
			out.append(id)
	return out

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t
