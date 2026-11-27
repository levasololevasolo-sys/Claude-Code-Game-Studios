## Sound playback, first pass (production/qa/evidence/audio-pass.md). Autoload
## name: Audio. Volumes, pitch spread, cooldowns and pool sizes come from
## assets/data/audio.json; clips are assets/audio/sfx/<file>.wav.
##
## Hooks without touching gameplay logic: it listens to the Events bus and, as
## nodes enter the tree, connects to the signals they already have (hero, enemy,
## chest, breakable wall, run director, choice screens). Duck-typed by signal
## name, so the core layer does not reference the player or enemy classes.
## A few values (amulet charge, boss "roar" state, ember count) are polled.
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
## Polled nodes (weak, so freed nodes drop out).
var _hero: WeakRef = null
var _director: WeakRef = null
var _bosses: Array[WeakRef] = []
var _boss_st: Dictionary = {}
var _charge: float = 0.0
var _embers: int = -1
var _screens: Array[WeakRef] = []

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
	Events.enemy_killed.connect(func(e: Node2D, _h: RefCounted) -> void: play_at(&"enemy_death", e.global_position))
	Events.player_hurt.connect(func(_a: float, _h: RefCounted) -> void: play(&"hero_hurt"))
	Events.flare_fired.connect(func(_s: String, _p: float) -> void: play(&"flare"))
	Events.rune_taken.connect(func(_i: String, _s: String, _r: String) -> void: play(&"rune_chime"))
	Events.hero_acted.connect(_on_hero_acted)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: play(&"ui_move"))

## Releases the cached streams on quit (no resources left in use at exit).
func _exit_tree() -> void:
	for p: Node in _pool + _pool_2d:
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
## `pitch_mul` scales the pitch on top of the random spread.
func play(id: StringName, variant: int = -1, pitch_mul: float = 1.0) -> void:
	_play(id, variant, pitch_mul, false, Vector2.ZERO)

## Plays sound `id` at a world position (pooled AudioStreamPlayer2D).
func play_at(id: StringName, at: Vector2, variant: int = -1, pitch_mul: float = 1.0) -> void:
	_play(id, variant, pitch_mul, true, at)

func _play(id: StringName, variant: int, pitch_mul: float, positional: bool, at: Vector2) -> void:
	if not is_inside_tree() or not gate(id, Time.get_ticks_msec()):
		return
	var row: Dictionary = config.sounds[String(id)]
	var files: Array = row.get("files", [])
	if files.is_empty():
		return
	var file := String(files[clampi(variant, 0, files.size() - 1) if variant >= 0 else _rng.randi() % files.size()])
	var stream := _stream(file)
	if stream == null:
		return
	var spread := float(row.get("pitch", 0.0))
	var pitch := maxf(0.05, (1.0 + _rng.randf_range(-spread, spread)) * pitch_mul)
	if positional and not _pool_2d.is_empty():
		var p2 := _pool_2d[_next_2d]
		_next_2d = (_next_2d + 1) % _pool_2d.size()
		p2.global_position = at
		_start(p2, stream, row, pitch)
	elif not _pool.is_empty():
		var p := _pool[_next]
		_next = (_next + 1) % _pool.size()
		_start(p, stream, row, pitch)

func _start(p: Node, stream: AudioStream, row: Dictionary, pitch: float) -> void:
	p.set("stream", stream)
	p.set("bus", StringName(String(row.get("bus", "SFX"))))
	p.set("volume_db", float(row.get("db", 0.0)))
	p.set("pitch_scale", pitch)
	p.call("play")

func _stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var path := file_path(file)
		_streams[file] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[file]

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

func _on_node_added(n: Node) -> void:
	if n.has_signal("hit_landed") and n.has_signal("hurt_taken"):
		_hero = weakref(n)
		_charge = _amulet_charge(n)
		n.connect("hit_landed", _on_hero_hit.bind(n))
	elif n.has_signal("damaged") and n.has_signal("woke"):
		n.connect("damaged", _on_enemy_damaged)
		n.connect("woke", _on_enemy_woke)
		# `boss` may be set after the node enters the tree: track every enemy, filter when polling.
		if _bosses.size() > 64:
			_bosses = _bosses.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)
		_bosses.append(weakref(n))
	elif n.has_signal("opened"):
		n.connect("opened", func(_c: Node) -> void: play(&"door_open", -1, 1.3))
	elif n.has_signal("broke"):
		n.connect("broke", func(w: Node) -> void: play_at(&"wall_slam", (w as Node2D).global_position if w is Node2D else Vector2.ZERO))
	elif n.has_signal("doors_opened"):
		_director = weakref(n)
		_embers = -1
		n.connect("doors_opened", func(_d: Array) -> void: play(&"door_open"))
	elif n.has_signal("chosen") or n.has_signal("hovered") or n.has_signal("closed"):
		_screens.append(weakref(n))
		for s: String in ["chosen", "closed"]:
			if n.has_signal(s):
				n.connect(s, _on_screen_done.bind(s))
		if n.has_signal("hovered"):
			n.connect("hovered", func(_i: int) -> void: play(&"ui_move"))

func _on_screen_done(_a: Variant = null, _b: Variant = null) -> void:
	play(&"ui_confirm")

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

func _on_enemy_damaged(e: Node, _amount: float, hit: RefCounted) -> void:
	if hit != null and int(hit.get("kind")) == 5:  # Hit.Kind.WALL
		play_at(&"wall_slam", (e as Node2D).global_position if e is Node2D else Vector2.ZERO)

func _amulet_charge(hero: Node) -> float:
	var a: Object = hero.get("amulet")
	return float(a.get("charge")) if a != null else 0.0

func _input(event: InputEvent) -> void:
	if not _screen_open() or event.is_echo():
		return
	for a: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			play(&"ui_move")
			return

func _screen_open() -> bool:
	_screens = _screens.filter(func(w: WeakRef) -> bool: return w.get_ref() != null)
	return _screens.any(func(w: WeakRef) -> bool: return (w.get_ref() as Node).is_inside_tree() and (not w.get_ref() is CanvasItem or (w.get_ref() as CanvasItem).is_visible_in_tree()))

func _process(_dt: float) -> void:
	var hero: Node = _hero.get_ref() if _hero else null
	if hero:
		var c := _amulet_charge(hero)
		var step := float(config.get("charge_tick_step", 10.0))
		if ticks_crossed(_charge, c, step) > 0:
			play(&"amulet_tick", -1, 1.0 + float(config.get("charge_tick_pitch_per_100", 0.35)) * minf(c, 150.0) / 100.0)
		_charge = c
	var dir: Node = _director.get_ref() if _director else null
	if dir:
		var run: Object = dir.get("run")
		if run != null:
			var em := int(run.get("embers"))
			if _embers >= 0 and em > _embers:
				play(&"ember_pickup")
			_embers = em
	for w: WeakRef in _bosses:
		var b: Node = w.get_ref()
		if b == null or not bool(b.get("boss")):
			continue
		var st := String(b.get("st"))
		if st == "roar" and _boss_st.get(b.get_instance_id(), "") != "roar":
			play_at(&"boss_roar", (b as Node2D).global_position if b is Node2D else Vector2.ZERO)
		_boss_st[b.get_instance_id()] = st
