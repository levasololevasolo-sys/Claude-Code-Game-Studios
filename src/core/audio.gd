## Sound playback (first pass production/qa/evidence/audio-pass.md, second pass
## design/audio/sfx-coverage.md). Autoload name: Audio. Volumes, pitch spread,
## cooldowns, voice limits, pool sizes and every hook -> id map come from
## assets/data/audio.json; clips are assets/audio/sfx/<file>.wav.
##
## Hooks without touching gameplay logic: it listens to the Events bus and, as
## nodes enter the tree, connects to the signals they already have (hero, enemy,
## chest, breakable wall, run director, base, screens, buttons). Duck-typed by
## signal / property name or by the script's class_name string, so the core layer
## does not reference the player, enemy or UI classes. A few values are polled
## (amulet charge, enemy and trap states, door / station / weapon-drop `near`,
## the hero's run phase for footsteps, screen selection for hover ticks).
##
## Unknown ids are ignored silently: Audio.play with any id is always safe to call.
## Everything goes through the SFX / Music / UI buses, so the settings sliders
## (GameSettings.apply_volumes) govern all of it; ambient beds use Music.
extends Node

const CONFIG_PATH: String = "res://assets/data/audio.json"
const SFX_DIR: String = "res://assets/audio/sfx/"
const BUSES: Array[String] = ["SFX", "Music", "UI"]

## Parsed audio.json.
var config: Dictionary = {}
## id -> last play time, ms (cooldown book-keeping).
var _last_ms: Dictionary = {}
## file -> AudioStream (loaded on first use).
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _next: int = 0
var _next_2d: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Two ambient players, cross-faded on location change.
var _amb: Array[AudioStreamPlayer] = []
var _amb_id: String = ""
var _amb_cur: int = 0
## Background music (src/core/music.gd), fed by the same hooks as the beds.
var music: MusicPlayer
## Polled nodes (weak, so freed nodes drop out).
var _hero: WeakRef = null
var _amulet: Object = null
var _step_ph: int = 0
var _director: WeakRef = null
var _enemies: Array[WeakRef] = []
var _enemy_st: Dictionary = {}
var _charge: float = 0.0
var _embers: int = -1
## {ref: WeakRef, prop: String, last: Variant, kind: String} for polled `near` / phase props.
var _watch: Array[Dictionary] = []
## {ref: WeakRef, cfg: Dictionary, hover: Variant, tab: int} for open screens.
var _screens: Array[Dictionary] = []
## Current location key of the ambient / footsteps ("base", "swamp"...).
var surface: String = "base"

func _init() -> void:
	config = load_config(CONFIG_PATH)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	ensure_buses(config.get("buses", {}) as Dictionary)
	for i in int(config.get("pool", 16)):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in int(config.get("pool_2d", 16)):
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = float(config.get("max_distance", 4000.0))
		p2.attenuation = float(config.get("attenuation", 0.5))
		p2.panning_strength = float(config.get("panning", 0.6))
		add_child(p2)
		_pool_2d.append(p2)
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.bus = &"Music"
		add_child(a)
		_amb.append(a)
	music = MusicPlayer.new()
	music.cfg = config.get("music", {})
	add_child(music)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_hurt.connect(func(_a: float, _h: RefCounted) -> void: play(&"hero_hurt"))
	Events.flare_fired.connect(func(_s: String, _p: float) -> void: play(&"flare"))
	Events.rune_taken.connect(func(_i: String, _s: String, _r: String) -> void: play(&"rune_chime"))
	Events.hero_acted.connect(_on_hero_acted)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: play(&"ui_move"))

## Releases the cached streams on quit (no resources left in use at exit).
func _exit_tree() -> void:
	for p: Node in _pool + _pool_2d + _amb:
		p.call("stop")
		p.set("stream", null)
	_streams.clear()

# ---------------- pure helpers (unit-tested) ----------------

## Reads and parses an audio config; {} on failure.
static func load_config(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Audio: could not read %s" % path)
		return {}
	return parsed

## True if a sound last played at `last_ms` may play again at `now_ms` with a
## cooldown of `cd` s. `last_ms` < 0 = never played.
static func cooldown_ok(last_ms: int, now_ms: int, cd: float) -> bool:
	return last_ms < 0 or float(now_ms - last_ms) >= cd * 1000.0

## How many charge-tick steps of size `step` the amulet charge crossed going up
## from `before` to `after` (0 when it fell or stayed).
static func ticks_crossed(before: float, after: float, step: float) -> int:
	if step <= 0.0 or after <= before:
		return 0
	return maxi(0, int(floor(after / step)) - int(floor(before / step)))

## Res path of a sound file id.
static func file_path(file: String) -> String:
	return SFX_DIR + file + ".wav"

## Sound id mapped for `key` in the config table `table` ("" = none).
static func lookup(cfg: Dictionary, table: String, key: String) -> String:
	return String((cfg.get(table, {}) as Dictionary).get(key, ""))

## Enemy state -> sound id: the `states` row of `kind`, "" when the state is silent.
static func state_sound(cfg: Dictionary, kind: String, st: String) -> String:
	return String(((cfg.get("states", {}) as Dictionary).get(kind, {}) as Dictionary).get(st, ""))

## Death sound of an enemy kind: per-kind override, then the boss one, then enemy_death.
static func death_sound(cfg: Dictionary, kind: String, is_boss: bool) -> String:
	var d: Dictionary = cfg.get("deaths", {})
	if d.has(kind):
		return String(d[kind])
	return String(d.get("boss", "enemy_death")) if is_boss else "enemy_death"

## Footstep phase index: one step per half cycle of the run animation phase.
static func step_index(run_ph: float) -> int:
	return int(floor(run_ph / PI))

## True when `count` voices of an id are playing and the id's limit is reached.
static func voices_full(count: int, row: Dictionary, default_limit: int) -> bool:
	return count >= int(row.get("max", default_limit))

## Adds any missing bus (SFX/Music/UI) and applies the configured volumes.
static func ensure_buses(volumes: Dictionary) -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
	for b: String in volumes:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, float(volumes[b]))

## True if `id` has a row in the config.
func has_sound(id: StringName) -> bool:
	return (config.get("sounds", {}) as Dictionary).has(String(id))

## Cooldown gate for `id` at `now_ms`; records the play when it passes.
func gate(id: StringName, now_ms: int) -> bool:
	var row: Dictionary = (config.get("sounds", {}) as Dictionary).get(String(id), {})
	if row.is_empty():
		return false
	if not cooldown_ok(int(_last_ms.get(id, -1)), now_ms, float(row.get("cd", 0.0))):
		return false
	_last_ms[id] = now_ms
	return true

# ---------------- playback ----------------

## Plays sound `id` non-positionally. `variant` picks a file (-1 = random);
## `pitch_mul` scales the pitch on top of the random spread. Unknown ids: no-op.
func play(id: StringName, variant: int = -1, pitch_mul: float = 1.0) -> void:
	_play(id, variant, pitch_mul, false, Vector2.ZERO)

## Plays sound `id` at a world position (pooled AudioStreamPlayer2D).
func play_at(id: StringName, at: Vector2, variant: int = -1, pitch_mul: float = 1.0) -> void:
	_play(id, variant, pitch_mul, true, at)

## Plays `id` at `at` only if the hero is within audio.json `hear_radius` (or absent).
func play_near(id: StringName, at: Vector2, pitch_mul: float = 1.0) -> void:
	var h: Node2D = _hero.get_ref() as Node2D if _hero else null
	if h and h.global_position.distance_to(at) > float(config.get("hear_radius", 1400.0)):
		return
	play_at(id, at, -1, pitch_mul)

func _play(id: StringName, variant: int, pitch_mul: float, positional: bool, at: Vector2) -> void:
	if id == &"" or not is_inside_tree() or not has_sound(id):
		return
	var row: Dictionary = config.sounds[String(id)]
	var pool: Array = _pool_2d if positional and not _pool_2d.is_empty() else _pool
	if pool.is_empty() or voices_full(_voices(pool, id), row, int(config.get("voice_limit", 3))):
		return
	if not gate(id, Time.get_ticks_msec()):
		return
	var files: Array = row.get("files", [])
	if files.is_empty():
		return
	var file := String(files[clampi(variant, 0, files.size() - 1) if variant >= 0 else _rng.randi() % files.size()])
	var stream := _stream(file, false)
	if stream == null:
		return
	var spread := float(row.get("pitch", 0.0))
	var pitch := maxf(0.05, (1.0 + _rng.randf_range(-spread, spread)) * pitch_mul)
	var p: Node = _free_player(pool, positional)
	if positional:
		(p as Node2D).global_position = at
	p.set_meta(&"id", id)
	_start(p, stream, row, pitch)

func _voices(pool: Array, id: StringName) -> int:
	var n := 0
	for p: Node in pool:
		if bool(p.get("playing")) and p.get_meta(&"id", &"") == id:
			n += 1
	return n

## Next idle player of the pool (round robin), or the oldest one if all are busy.
func _free_player(pool: Array, positional: bool) -> Node:
	var start := _next_2d if positional else _next
	var pick := start
	for k in pool.size():
		var i := (start + k) % pool.size()
		if not bool(pool[i].get("playing")):
			pick = i
			break
	if positional:
		_next_2d = (pick + 1) % pool.size()
	else:
		_next = (pick + 1) % pool.size()
	return pool[pick]

func _start(p: Node, stream: AudioStream, row: Dictionary, pitch: float) -> void:
	p.set("stream", stream)
	p.set("bus", StringName(String(row.get("bus", "SFX"))))
	p.set("volume_db", float(row.get("db", 0.0)))
	p.set("pitch_scale", pitch)
	p.call("play")

func _stream(file: String, loop: bool) -> AudioStream:
	if not _streams.has(file):
		var path := file_path(file)
		var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
		var wav := s as AudioStreamWAV
		if loop and wav and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav = wav.duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
			s = wav
		_streams[file] = s
	return _streams[file]

## Cross-fades the ambient bed to location `key` (audio.json `ambient`; "" = silence).
func set_ambient(key: String) -> void:
	surface = key
	var id := lookup(config, "ambient", key)
	if id == _amb_id or _amb.is_empty():
		return
	_amb_id = id
	var fade := float(config.get("ambient_fade", 1.5))
	var old := _amb[_amb_cur]
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if id == "" or not has_sound(StringName(id)):
		return
	var row: Dictionary = config.sounds[id]
	var files: Array = row.get("files", [])
	var stream := _stream(String(files[0]), true) if not files.is_empty() else null
	if stream == null:
		return
	_amb_cur = 1 - _amb_cur
	var p := _amb[_amb_cur]
	p.stream = stream
	p.bus = StringName(String(row.get("bus", "Music")))
	p.volume_db = -60.0
	p.play()
	create_tween().tween_property(p, "volume_db", float(row.get("db", -14.0)), fade)

# ---------------- hooks ----------------

func _on_hero_acted(action: StringName, power: float) -> void:
	match action:
		&"swing":
			play(&"swing", clampi(int(power) - 1, 0, 2))
		&"land":
			if power >= float(config.get("land_min", 0.35)):
				play(&"land", -1, 1.1 - power * 0.2)
		_:
			play(action)

func _on_enemy_killed(e: Node2D, _h: RefCounted) -> void:
	if bool(e.get("boss")) and music != null:
		music.on_boss_killed()
	play_at(StringName(death_sound(config, String(e.get("kind_id")), bool(e.get("boss")))), e.global_position)

func _on_node_added(n: Node) -> void:
	var cls := _class_of(n)
	var screens: Dictionary = config.get("screens", {})
	if screens.has(cls):
		_add_screen.call_deferred(n, screens[cls])
		return
	if n is BaseButton:
		_hook_button(n as BaseButton)
		return
	if n is Slider:
		(n as Slider).value_changed.connect(func(_v: float) -> void: play(&"ui_hover_wood"))
		return
	match cls:
		"Trap":
			_watch.append({ "ref": weakref(n), "prop": "phase", "last": "idle", "kind": "trap" })
			return
		"Door", "Station", "WeaponDrop":
			_watch.append({ "ref": weakref(n), "prop": "near", "last": false, "kind": cls })
			if n.has_signal("taken"):
				n.connect("taken", func(_a: Variant, _b: Variant) -> void: play(&"weapon_pickup"))
			return
		"EnemyShot":
			_at_node.call_deferred(&"shot_fire", n)
			return
		"FireTrail":
			_at_node.call_deferred(&"fire_whoosh", n)
			return
		"Base":
			n.connect("gate_used", func() -> void: play(&"gate_whoosh"))
			set_ambient("base")
			if music != null:
				music.on_base()
			return
		"MainMenu":
			if music != null:
				music.on_title()
			return
	if n.has_signal("hit_landed") and n.has_signal("hurt_taken"):
		_hook_hero(n)
	elif n.has_signal("damaged") and n.has_signal("woke"):
		n.connect("damaged", _on_enemy_damaged)
		n.connect("woke", _on_enemy_woke)
		# limb_severed: no hook here, the limb code calls Audio by limb_sever / limb_head_pop itself.
		if n.has_signal("broke"):
			n.connect("broke", func(w: Node) -> void: play_at(&"wall_slam", (w as Node2D).global_position))
		# `boss` / states change after the node enters the tree: track every enemy, filter when polling.
		if _enemies.size() > 64:
			_enemies = _enemies.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)
		_enemies.append(weakref(n))
	elif n.has_signal("opened"):
		n.connect("opened", func(c: Node) -> void: play_at(&"chest_open", (c as Node2D).global_position if c is Node2D else Vector2.ZERO))
	elif n.has_signal("doors_opened"):
		_director = weakref(n)
		_embers = -1
		n.connect("doors_opened", func(_d: Array) -> void: play(&"door_open"))
		if n.has_signal("room_started"):
			n.connect("room_started", _on_room_started.bind(n))

static func _class_of(n: Node) -> String:
	var s: Script = n.get_script() as Script
	while s != null:
		var g := String(s.get_global_name())
		if g != "":
			return g
		s = s.get_base_script()
	return ""

func _at_node(id: StringName, n: Node) -> void:
	if is_instance_valid(n) and n is Node2D:
		play_near(id, (n as Node2D).global_position)

func _hook_button(b: BaseButton) -> void:
	b.mouse_entered.connect(func() -> void: play(&"ui_hover_wood"))
	b.pressed.connect(func() -> void:
		var txt := String(b.get("text")) if "text" in b else ""
		play(&"ui_cancel_wood" if (config.get("cancel_words", []) as Array).has(txt.strip_edges()) else &"ui_confirm_gold"))

func _hook_hero(n: Node) -> void:
	_hero = weakref(n)
	_amulet = null
	_charge = _amulet_charge(n)
	n.connect("hit_landed", _on_hero_hit.bind(n))
	if n.has_signal("died"):
		n.connect("died", func(_h: Variant) -> void: play(&"hero_death"))
	if n.has_signal("revived"):
		n.connect("revived", func() -> void: play(&"hero_revive"))
	if n.has_signal("weapon_changed"):
		n.connect("weapon_changed", func(_s: String) -> void: play(&"weapon_swap"))
	if n.has_signal("sub_landed"):
		n.connect("sub_landed", func(e: Node, _d: float) -> void: play_at(&"hit", (e as Node2D).global_position, -1, 1.15))

func _hook_amulet(a: Object) -> void:
	_amulet = a
	if a == null or a.has_meta(&"audio_hooked"):
		return
	a.set_meta(&"audio_hooked", true)
	var sigs := { "became_ready": &"amulet_ready", "capped": &"amulet_overcharge", "spilled": &"amulet_crack", "fizzled": &"flare_fizzle" }
	for s: String in sigs:
		if a.has_signal(s):
			var cb := _play_ui.bind(sigs[s])
			a.connect(s, cb.unbind(2) if s == "spilled" else cb)

func _play_ui(id: StringName) -> void:
	play(id)

func _on_room_started(stage: String, _k: int, dir: Node) -> void:
	if music != null:
		music.on_room(stage, dir)
	if stage == "base":
		set_ambient("base")
		return
	var run: Object = dir.get("run")
	var tier := str(int(run.get("tier"))) if run != null else "1"
	set_ambient(String((Tune.table("locations").get(tier, {}) as Dictionary).get("lib", "swamp")))

func _add_screen(n: Node, cfg: Dictionary) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var open := String(cfg.get("open", ""))
	if cfg.has("open_outcome"):
		var summary: Variant = n.get("summary")
		var oc := String((summary as Dictionary).get("outcome", "dead")) if summary is Dictionary else "dead"
		open = String((cfg.open_outcome as Dictionary).get(oc, ""))
		_repeat(StringName(String(cfg.get("count", ""))), int(config.get("count_ticks", 8)), 0.35, 0.06)
	play(StringName(open))
	_repeat(StringName(String(cfg.get("deal", ""))), _card_count(n), 0.08, 0.07)
	var vg := String(n.get("voice_god")) if "voice_god" in n else ""
	if vg != "" and String(n.get("voice_text")) != "":
		play(&"god_voice", -1, float((config.get("god_pitch", {}) as Dictionary).get(vg, 1.0)))
	for s: Dictionary in n.get_signal_list():
		var sname := String(s.name)
		if cfg.has(sname) and cfg[sname] is String:
			var cb := _play_ui.bind(StringName(String(cfg[sname])))
			var argc := (s.args as Array).size()
			n.connect(sname, cb.unbind(argc) if argc > 0 else cb)
	var hp := String(cfg.get("hover", ""))
	var tabs: Variant = n.get("tabs") if "tabs" in n else null
	_screens.append({ "ref": weakref(n), "cfg": cfg, "hover": n.get(hp) if hp != "" and hp in n else null,
		"tab": (tabs as TabContainer).current_tab if tabs is TabContainer else -1 })

func _card_count(n: Node) -> int:
	for p: String in ["ids", "gods"]:
		if p in n and n.get(p) is Array:
			return (n.get(p) as Array).size()
	return 0

## Plays `id` `count` times, `gap` s apart after `delay` s (cards dealt, embers counted).
func _repeat(id: StringName, count: int, delay: float, gap: float) -> void:
	if id == &"" or count <= 0 or not is_inside_tree():
		return
	for i in count:
		get_tree().create_timer(delay + gap * i, true).timeout.connect(_play_ui.bind(id))

func _on_hero_hit(e: Node, _dmg: float, hero: Node) -> void:
	var at: Vector2 = (e as Node2D).global_position if e is Node2D else Vector2.ZERO
	if _is_finisher(hero):
		play_at(&"hit_heavy", at)
	else:
		play_at(&"hit", at)

## Last swing of the side combo = finisher (DamageRules.is_finisher: combo == length).
func _is_finisher(hero: Node) -> bool:
	var w: Object = hero.get("weapon")
	if w == null or not w.has_method("times"):
		return false
	return String(hero.get("atk_dir")) == "side" and int(hero.get("combo")) >= (w.call("times") as Array).size()

func _on_enemy_woke(e: Node) -> void:
	if bool(e.get("boss")):
		play(&"boss_roar")
	else:
		play_near(&"enemy_wake", (e as Node2D).global_position)

func _on_enemy_damaged(e: Node, amount: float, hit: RefCounted) -> void:
	var at: Vector2 = (e as Node2D).global_position if e is Node2D else Vector2.ZERO
	var kind := int(hit.get("kind")) if hit != null else -1
	if kind == 5:  # Hit.Kind.WALL
		play_at(&"wall_slam", at)
	elif String(e.get("kind_id")) == "wall":
		if not bool(e.get("dead")):
			play_at(&"wall_crack", at)
	elif amount <= 0.0 and kind == 0 and bool(e.get("front_shield")):  # Hit.Kind.STRIKE fully blocked
		play_at(&"shield_block", at)

func _amulet_charge(hero: Node) -> float:
	var a: Object = hero.get("amulet")
	return float(a.get("charge")) if a != null else 0.0

func _process(_dt: float) -> void:
	var hero: Node = _hero.get_ref() if _hero else null
	if hero:
		_poll_hero(hero)
	var dir: Node = _director.get_ref() if _director else null
	if dir:
		var run: Object = dir.get("run")
		if run != null:
			var em := int(run.get("embers"))
			if _embers >= 0 and em > _embers:
				play(&"ember_pickup")
			_embers = em
	_poll_enemies()
	_poll_watch()
	_poll_screens()

func _poll_hero(hero: Node) -> void:
	var a: Object = hero.get("amulet")
	if a != _amulet:
		_hook_amulet(a)
	var c := _amulet_charge(hero)
	var step := float(config.get("charge_tick_step", 10.0))
	if ticks_crossed(_charge, c, step) > 0:
		play(&"amulet_tick", -1, 1.0 + float(config.get("charge_tick_pitch_per_100", 0.35)) * minf(c, 150.0) / 100.0)
	_charge = c
	var si := step_index(float(hero.get("run_ph")))
	if si != _step_ph:
		_step_ph = si
		var body := hero as CharacterBody2D
		if body and body.is_on_floor() and absf(body.velocity.x) > 40.0 and not bool(hero.get("dead")):
			play(StringName(lookup(config, "surfaces", surface)))

func _poll_enemies() -> void:
	for w: WeakRef in _enemies:
		var b: Node = w.get_ref()
		if b == null or bool(b.get("dead")):
			continue
		var st := String(b.get("st"))
		var key := b.get_instance_id()
		if _enemy_st.get(key, "") != st:
			_enemy_st[key] = st
			var id := state_sound(config, String(b.get("kind_id")), st)
			if id != "":
				play_near(StringName(id), (b as Node2D).global_position)

func _poll_watch() -> void:
	for i in range(_watch.size() - 1, -1, -1):  # in place: no per-frame allocation
		if (_watch[i].ref as WeakRef).get_ref() == null:
			_watch.remove_at(i)
	for d: Dictionary in _watch:
		var n: Node2D = (d.ref as WeakRef).get_ref() as Node2D
		var v: Variant = n.get(String(d.prop))
		if v == d.last:
			continue
		d.last = v
		match String(d.kind):
			"trap":
				var id := lookup(config, "traps", "warn" if v == "warn" else String(n.get("kind"))) if v != "idle" else ""
				play_near(StringName(id), n.global_position)
			"Door":
				if v:
					play(&"ui_door_near", -1, 0.9 + float(hash(String((n.get("info") as Dictionary).get("type", ""))) % 5) * 0.05)
			"Station":
				if v:
					play(&"ui_door_near", -1, 0.8)
			"WeaponDrop":
				if v:
					play(&"ui_card_deal")

func _poll_screens() -> void:
	for i in range(_screens.size() - 1, -1, -1):
		if (_screens[i].ref as WeakRef).get_ref() == null:
			_screens.remove_at(i)
	for d: Dictionary in _screens:
		var n: Node = (d.ref as WeakRef).get_ref()
		var cfg: Dictionary = d.cfg
		var hp := String(cfg.get("hover", ""))
		if hp != "" and hp in n:
			var v: Variant = n.get(hp)
			if v != d.hover:
				d.hover = v
				if not (v is bool) or v:
					play(StringName(String(cfg.get("hover_id", "ui_hover_wood"))))
		var tabs: Variant = n.get("tabs") if "tabs" in n else null
		if tabs is TabContainer and (tabs as TabContainer).current_tab != int(d.tab):
			d.tab = (tabs as TabContainer).current_tab
			play(StringName(String(cfg.get("tab", ""))))
		if cfg.has("wait") and "capture" in n and not (n.get("capture") as Dictionary).is_empty():
			play(StringName(String(cfg.wait)))
