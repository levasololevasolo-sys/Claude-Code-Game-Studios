## Background music (src/core/music.gd, design/audio/music.md): every theme in
## audio.json has its files, every location and boss has a theme, the room ->
## theme rules and the underground check.
extends GdUnitTestSuite

const MusicScript := preload("res://src/core/music.gd")
const AudioScript := preload("res://src/core/audio.gd")

const CFG := { "haven": "base", "tracks": { "swamp": { "file": "a", "cave": "b" }, "boss_kikimora": { "file": "c" } } }

func _music() -> Dictionary:
	return AudioScript.load_config(AudioScript.CONFIG_PATH).get("music", {})

func test_every_music_file_is_shipped() -> void:
	var files := MusicScript.files_of(_music())
	assert_int(files.size()).is_greater_equal(11)
	for f: String in files:
		assert_bool(ResourceLoader.exists(MusicScript.file_path(f))) \
			.override_failure_message("missing %s" % MusicScript.file_path(f)).is_true()

func test_every_location_and_boss_has_a_theme() -> void:
	var tracks: Dictionary = _music().get("tracks", {})
	for k: String in ["title", "base"]:
		assert_bool(tracks.has(k)).override_failure_message("no theme %s" % k).is_true()
	var locs: Dictionary = Tune.table("locations")
	for tier: String in locs:
		if not locs[tier] is Dictionary:
			continue
		var loc: Dictionary = locs[tier]
		var lib := String(loc.get("lib", ""))
		if lib == "" or int(tier) > 3:
			continue
		assert_bool(tracks.has(lib)).override_failure_message("no theme for %s" % lib).is_true()
		assert_bool((tracks[lib] as Dictionary).has("cave")).override_failure_message("no cave stem for %s" % lib).is_true()
		assert_bool(tracks.has("boss_" + String(loc.get("boss", "")))).override_failure_message("no boss theme in tier %s" % tier).is_true()

func test_cave_stems_match_their_surface_length() -> void:
	var tracks: Dictionary = _music().get("tracks", {})
	for k: String in tracks:
		var row: Dictionary = tracks[k]
		if not row.has("cave"):
			continue
		var a := load(MusicScript.file_path(String(row.file))) as AudioStream
		var b := load(MusicScript.file_path(String(row.cave))) as AudioStream
		assert_float(absf(a.get_length() - b.get_length())).override_failure_message(k).is_less(0.05)

func test_theme_for_stages() -> void:
	assert_str(MusicScript.theme_for("room", "swamp", "kikimora", false, CFG)).is_equal("swamp")
	assert_str(MusicScript.theme_for("level", "swamp", "kikimora", false, CFG)).is_equal("swamp")
	assert_str(MusicScript.theme_for("lair", "swamp", "kikimora", false, CFG)).is_equal("boss_kikimora")
	assert_str(MusicScript.theme_for("lair", "swamp", "kikimora", true, CFG)).is_equal("swamp")
	assert_str(MusicScript.theme_for("lair", "swamp", "nobody", false, CFG)).is_equal("swamp")
	assert_str(MusicScript.theme_for("haven", "swamp", "kikimora", false, CFG)).is_equal("base")
	assert_str(MusicScript.theme_for("base", "swamp", "kikimora", false, CFG)).is_equal("base")

func test_is_under_reads_the_depth_band() -> void:
	var level := { "rooms": [{ "band": 0 }, { "band": 1 }, {}] }
	assert_bool(MusicScript.is_under(level, 0)).is_false()
	assert_bool(MusicScript.is_under(level, 1)).is_true()
	assert_bool(MusicScript.is_under(level, 2)).is_false()
	assert_bool(MusicScript.is_under(level, -1)).is_false()
	assert_bool(MusicScript.is_under(level, 9)).is_false()

func test_play_theme_switches_and_ignores_unknown() -> void:
	var m: MusicPlayer = auto_free(MusicScript.new())
	add_child(m)
	m.cfg = _music()
	m.play_theme("swamp")
	assert_str(m.current).is_equal("swamp")
	m.play_theme("no_such_theme")
	assert_str(m.current).is_equal("no_such_theme")
	m.play_theme("title")
	assert_str(m.current).is_equal("title")
