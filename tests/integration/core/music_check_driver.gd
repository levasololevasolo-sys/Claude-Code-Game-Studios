## Music check (design/audio/music.md): a normal launch and run, watching which
## theme Audio.music plays. Main menu -> title; prologue -> base -> base theme;
## gate -> run -> swamp theme (surface stem); hero moved into an underground room
## -> the cave stem fades in, back on the surface -> it fades out; lair -> the
## Kikimora battle theme; the boss falls -> the swamp theme comes back.
## Uses the real slot files (deletes them): cloud workspace only. Run:
##   godot --headless -s res://tests/integration/core/music_check.gd
## (that stub loads the main scene and adds this node to the root).
## Writes user://music_check/music-check-log.txt; exit code = failed checks > 0.
extends Node

var out_dir: String = "user://music_check"
var _fails: int = 0
var _lines: PackedStringArray = []

var root: Window

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[music-check] ", s)
	_lines.append(s)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	_note(("OK   " if cond else "FAIL ") + what)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Real seconds (headless frames run faster than real time; fades are in seconds).
func _secs(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _wait(cond: Callable, frames: int = 900) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func _find(cls: Variant) -> Node:
	for n in root.find_children("*", "", true, false):
		if is_instance_of(n, cls):
			return n
	return null

func _music() -> MusicPlayer:
	return root.get_node("Audio").get("music") as MusicPlayer

func _state(m: MusicPlayer) -> String:
	var p := m._players[m._cur]
	var s := p.stream
	var stems := ""
	if s is AudioStreamSynchronized:
		var sy := s as AudioStreamSynchronized
		stems = ", stems surface %.0f dB / cave %.0f dB" % [sy.get_sync_stream_volume(0), sy.get_sync_stream_volume(1)]
	return "%s (playing %s, %.0f dB%s)" % [m.current, p.playing, p.volume_db, stems]

func _cave_db(m: MusicPlayer) -> float:
	var sy := m._players[m._cur].stream as AudioStreamSynchronized
	return sy.get_sync_stream_volume(1) if sy != null else -999.0

func _run() -> void:
	await _frames(2)
	var m := _music()
	_ok(m != null, "Audio has a music player")
	var ok := await _wait(func() -> bool: return _find(MainMenu) != null)
	_ok(ok, "the main menu opens")
	ok = await _wait(func() -> bool: return m.current == "title", 60)
	await _secs(3.0)
	_ok(ok and m._players[m._cur].playing, "main menu: " + _state(m))
	var mm := _find(MainMenu) as MainMenu
	for i in range(1, SaveSlots.SLOTS + 1):
		SaveSlots.delete_slot(i)
	mm.start.emit(1, true)
	ok = await _wait(func() -> bool: return _find(DifficultyChoiceScreen) != null)
	(_find(DifficultyChoiceScreen) as DifficultyChoiceScreen).take(1)
	ok = await _wait(func() -> bool: return _find(Prologue) != null)
	(_find(Prologue) as Prologue).call("_finish")
	var w := _find(World) as World
	ok = await _wait(func() -> bool: return w.director != null and w.director.phase == "base")
	_ok(ok, "the base opens")
	await _secs(3.0)
	_ok(m.current == "base" and m._players[m._cur].playing, "base: " + _state(m))
	var d := w.director
	d.base.use("gate")
	ok = await _wait(func() -> bool: return d.run != null and d.phase != "base")
	_ok(ok, "the gate starts a run")
	ok = await _wait(func() -> bool: return d.screen is RuneOfferScreen, 300)
	if ok:
		(d.screen as RuneOfferScreen).take(0)
	ok = await _wait(func() -> bool: return d.phase == "level" and d.flow != null, 600)
	_ok(ok, "the swamp level is on (phase %s)" % d.phase)
	await _secs(3.0)
	_ok(m.current == "swamp" and not m.under and _cave_db(m) < -50.0, "swamp, surface: " + _state(m))
	w.player.scripted = true
	w.player.inv = 1.0e6
	var lr := w.level_room
	var cave_i := -1
	var top_i := -1
	for r: Dictionary in lr.level.rooms:
		if int(r.get("band", 0)) != 0 and cave_i < 0:
			cave_i = int(r.i)
		if int(r.get("band", 0)) == 0 and top_i < 0:
			top_i = int(r.i)
	_ok(cave_i >= 0, "the level has an underground room (%d)" % cave_i)
	if cave_i >= 0:
		_tp(w, lr.room_rect(cave_i).get_center())
		await _frames(20)
		_note("  hero in room %d (band %d)" % [lr.room_at(w.player.global_position), int(lr.level.rooms[maxi(lr.room_at(w.player.global_position), 0)].get("band", 0))])
		await _secs(3.5)
		_ok(m.under and _cave_db(m) > -1.0, "swamp, underground: " + _state(m))
		_tp(w, lr.room_rect(top_i).get_center())
		await _secs(3.5)
		_ok(not m.under and _cave_db(m) < -50.0, "swamp, back on the surface: " + _state(m))
	_tp(w, d.flow.lair_pos)
	await _frames(4)
	d.flow.lair_used.emit()
	ok = await _wait(func() -> bool: return d.run.stage == "lair" and d.phase == "fight", 400)
	_ok(ok, "the lair door leads to the boss")
	await _secs(3.0)
	_ok(m.current == "boss_kikimora" and m._players[m._cur].playing, "lair: " + _state(m))
	var boss: Enemy = null
	for e: Enemy in root.get_tree().get_nodes_in_group("enemies"):
		if e.boss:
			boss = e
	_ok(boss != null, "the boss stands in the lair")
	if boss != null:
		boss.hurt(Hit.make(Hit.Kind.STRIKE, 1.0e7, boss.position.x, 0.0))
		await _secs(4.5)
		_ok(m.current == "swamp", "the boss fell: " + _state(m))
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("music-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().paused = false
	get_tree().quit(1 if _fails > 0 else 0)

func _tp(w: World, at: Vector2) -> void:
	w.player.position = at
	w.player.velocity = Vector2.ZERO
