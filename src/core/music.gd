## Background music (design/audio/music.md): one looping theme per location, an
## underground stem per location played in sync with it, a battle theme per boss
## and a title theme. Built by tools/asset-pipeline/audio/build_music.py, files in
## assets/audio/music/<file>.ogg, every value in assets/data/audio.json `music`.
##
## Created by the Audio autoload as its child, which tells it what is on screen:
## the main menu (title), the base / haven, the run director's rooms (location
## theme by `lib`, the boss theme in the lair until the boss falls). While a level
## is played it polls which room the hero stands in; a room with depth band != 0
## is underground and the cave stem fades in over the surface one. Both stems of a
## location sit in one AudioStreamSynchronized, so the swap never loses the beat.
## Two players cross-fade between themes. Everything plays on the Music bus.
class_name MusicPlayer
extends Node

const DIR: String = "res://assets/audio/music/"
const SILENT_DB: float = -60.0

## audio.json `music` block.
var cfg: Dictionary = {}
## Key of the theme playing now ("swamp", "boss_likho", "title"...), "" = none.
var current: String = ""
## True while the underground stem is the one heard.
var under: bool = false
var _players: Array[AudioStreamPlayer] = []
var _cur: int = 0
var _streams: Dictionary = {}
var _director: WeakRef = null
var _poll_t: float = 0.0
var _boss_down: bool = false
var _cave_tw: Tween
## One fade tween per player: a player reused before its fade-out ended must not
## be stopped by that old tween.
var _fades: Array[Tween] = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)

func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	_streams.clear()

# ---------------- pure helpers (unit-tested) ----------------

## Theme key for a room: lair = the location boss (until it falls), haven = the
## base theme, anything else = the location's `lib`.
static func theme_for(stage: String, lib: String, boss: String, boss_down: bool, c: Dictionary) -> String:
	match stage:
		"base":
			return "base"
		"haven":
			return String(c.get("haven", "base"))
		"lair":
			if not boss_down and (c.get("tracks", {}) as Dictionary).has("boss_" + boss):
				return "boss_" + boss
	return lib

## True when the room holding the hero is underground (LevelGen depth band != 0).
static func is_under(level: Dictionary, room_i: int) -> bool:
	var rooms: Array = level.get("rooms", [])
	if room_i < 0 or room_i >= rooms.size():
		return false
	return int((rooms[room_i] as Dictionary).get("band", 0)) != 0

## Every file named by the `tracks` table (surface and cave stems).
static func files_of(c: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: String in c.get("tracks", {}):
		var row: Dictionary = c.tracks[k]
		for f: String in ["file", "cave"]:
			if row.has(f) and not out.has(String(row[f])):
				out.append(String(row[f]))
	return out

static func file_path(file: String) -> String:
	return DIR + file + ".ogg"

# ---------------- what Audio tells us ----------------

## Main menu on screen.
func on_title() -> void:
	_director = null
	play_theme("title")

## The base (застава) entered.
func on_base() -> void:
	_director = null
	play_theme("base")

## RunDirector.room_started.
func on_room(stage: String, dir: Node) -> void:
	_director = weakref(dir) if stage != "base" else null
	_boss_down = false
	var run: Object = dir.get("run") if dir != null else null
	var tier := str(int(run.get("tier"))) if run != null else "1"
	var loc: Dictionary = Tune.table("locations").get(tier, {})
	play_theme(theme_for(stage, String(loc.get("lib", "swamp")), String(loc.get("boss", "")), false, cfg))
	_set_under(false, 0.01)

## A boss fell: the battle theme gives way to the location's underground stem.
func on_boss_killed() -> void:
	_boss_down = true
	if current.begins_with("boss_"):
		var d: Node = _director.get_ref() as Node if _director != null else null
		var run: Object = d.get("run") if d != null else null
		var tier := str(int(run.get("tier"))) if run != null else "1"
		var lib := String((Tune.table("locations").get(tier, {}) as Dictionary).get("lib", "swamp"))
		play_theme(lib, float(cfg.get("boss_out_fade", 4.0)))
		_set_under(bool(cfg.get("after_boss_under", true)), 0.01)

# ---------------- playback ----------------

## Cross-fades to theme `key` (audio.json music.tracks); unknown key = fade out.
func play_theme(key: String, fade: float = -1.0) -> void:
	if key == current or _players.is_empty():
		return
	current = key
	if fade < 0.0:
		fade = float(cfg.get("fade", 2.5))
	var old := _players[_cur]
	_kill_fade(_cur)
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", SILENT_DB, fade)
		tw.tween_callback(old.stop)
		_fades[_cur] = tw
	var row: Dictionary = (cfg.get("tracks", {}) as Dictionary).get(key, {})
	var s := _stream_for(row)
	if s == null:
		return
	_cur = 1 - _cur
	_kill_fade(_cur)
	var p := _players[_cur]
	p.stream = s
	p.volume_db = SILENT_DB
	p.play()
	_fades[_cur] = create_tween()
	_fades[_cur].tween_property(p, "volume_db", float(row.get("db", cfg.get("db", -10.0))), fade)

func _kill_fade(i: int) -> void:
	if _fades[i] != null and _fades[i].is_valid():
		_fades[i].kill()
	_fades[i] = null

## Loads a theme: a plain looping Ogg, or a synchronized pair [surface, cave].
func _stream_for(row: Dictionary) -> AudioStream:
	var file := String(row.get("file", ""))
	if file == "":
		return null
	var key := file + "|" + String(row.get("cave", ""))
	if _streams.has(key):
		return _streams[key]
	var a := _ogg(file)
	var s: AudioStream = a
	if a != null and row.has("cave"):
		var b := _ogg(String(row.cave))
		if b != null:
			var sync := AudioStreamSynchronized.new()
			sync.stream_count = 2
			sync.set_sync_stream(0, a)
			sync.set_sync_stream(1, b)
			sync.set_sync_stream_volume(0, 0.0)
			sync.set_sync_stream_volume(1, SILENT_DB)
			s = sync
	_streams[key] = s
	return s

func _ogg(file: String) -> AudioStream:
	var path := file_path(file)
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s

## Swaps the stems of the playing location theme: underground or surface.
func _set_under(v: bool, fade: float = -1.0) -> void:
	under = v
	var p := _players[_cur] if not _players.is_empty() else null
	var sync := p.stream as AudioStreamSynchronized if p != null else null
	if sync == null:
		return
	if fade < 0.0:
		fade = float(cfg.get("cave_fade", 3.0))
	if _cave_tw != null and _cave_tw.is_valid():
		_cave_tw.kill()
	var from := sync.get_sync_stream_volume(1)
	var to := 0.0 if v else SILENT_DB
	_cave_tw = create_tween()
	_cave_tw.tween_method(func(db: float) -> void:
		sync.set_sync_stream_volume(1, db)
		# surface stem mirrors the cave one on an equal-power curve
		var lin := db_to_linear(db)
		sync.set_sync_stream_volume(0, linear_to_db(maxf(sqrt(maxf(1.0 - lin * lin, 0.0)), 0.001))), from, to, fade)

func _process(dt: float) -> void:
	_poll_t -= dt
	if _poll_t > 0.0 or _director == null:
		return
	_poll_t = float(cfg.get("poll", 0.3))
	var d: Node = _director.get_ref() as Node
	if d == null or current.begins_with("boss_"):
		return
	var w: Object = d.get("world")
	var lr: Object = w.get("level_room") if w != null else null
	var hero: Node2D = w.get("player") as Node2D if w != null else null
	if lr == null or not is_instance_valid(lr) or hero == null or not is_instance_valid(hero):
		return
	var v := is_under(lr.get("level") as Dictionary, int(lr.call("room_at", hero.global_position)))
	if v != under:
		_set_under(v)
