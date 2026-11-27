## Scripted settings check (GDD difficulty, design/ux/settings.md): waits for
## the run, opens the pause menu with Esc, opens Настройки, rebinds jump to K
## through the controls tab (dash had K: they swap), checks the InputMap and the
## file, sets the difficulty to «Навь» on its tab, checks the Difficulty helper
## and the save, then shows the new-save difficulty choice and takes «Навь».
## Saves <out_dir>/pause-menu.png, settings-controls.png, settings-difficulty.png,
## difficulty-choice.png, pause-quit-confirm.png and settings-check-log.txt. Started by world.gd with
## `-- --settings-check=<dir>`; run it with `--fresh --save=user://settings_save.json`.
## The settings file goes to user://settings_check.cfg (never the player's).
extends Node

const CHECK_CFG: String = "user://settings_check.cfg"

var out_dir: String = "user://settings_check"
var _w: World
var _log: PackedStringArray = []
var _fail: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	_log.append(s)
	print("[settings-check] ", s)

func _check(ok: bool, what: String) -> void:
	_note(("OK   " if ok else "FAIL ") + what)
	if not ok:
		_fail += 1

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame

func _find(cls: Variant) -> Node:
	for n in get_tree().root.find_children("*", "", true, false):
		if is_instance_of(n, cls):
			return n
	return null

func _run() -> void:
	var st := get_node("/root/Settings") as GameSettings
	var game := get_node("/root/Game")
	st.path = CHECK_CFG
	st.reset_all()
	st.apply()
	for i in 600:
		if _w.director and _w.director.phase == "fight" and _w.player:
			break
		await get_tree().process_frame
	await _frames(30)
	# The run opens with its own screens (god / rune offer): take the first card.
	for i in 20:
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "Control", true, false):
			if n.has_method("take") and n.is_inside_tree():
				_note("closing start screen %s" % n.get_class() if n.get_script() == null else "closing start screen %s" % (n.get_script() as Script).get_global_name())
				n.call("take", 0)
				break
		await _frames(30)
	_check(Difficulty.current == "bylina", "check runs at «Былина» (no choice screen under a check flag)")
	_check(_find(DifficultyChoiceScreen) == null, "no difficulty choice under a check flag")
	_note("before Esc: phase %s, paused %s, can_pause %s, focus %s" % [_w.director.phase, get_tree().paused, _w.can_pause(), get_viewport().gui_get_focus_owner()])
	await _key(KEY_ESCAPE)
	await _frames(5)
	var pm := _find(PauseMenu) as PauseMenu
	_check(pm != null and get_tree().paused, "Esc opens the pause menu and pauses")
	if pm == null:
		_finish()
		return
	await _frames(10)
	await _shot("pause-menu.png")
	pm.ask_quit()
	await _frames(5)
	_check(pm.confirm_box != null and pm.can_quit, "«На заставу» asks first")
	await _shot("pause-quit-confirm.png")
	pm.cancel_quit()
	await _frames(3)
	_check(pm.confirm_box == null and _w.director.run != null, "«Остаться» keeps the run")
	var ss := pm.open_settings()
	await _frames(5)
	ss.show_tab(0)
	ss.begin_capture("jump", "kbm", 0)
	await _key(KEY_K)
	await _frames(5)
	_check(st.code_at("jump", "kbm", 0) == "key:%d" % KEY_K, "jump slot 1 is K")
	_check(st.code_at("dash", "kbm", 1) == "key:%d" % KEY_SPACE, "conflict swapped: dash got Space")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	_check(InputMap.event_is_action(k, "jump") and not InputMap.event_is_action(k, "dash"), "InputMap: K is jump, not dash")
	var sp := InputEventKey.new()
	sp.physical_keycode = KEY_SPACE
	_check(InputMap.event_is_action(sp, "dash") and not InputMap.event_is_action(sp, "jump"), "InputMap: Space is dash, not jump")
	var re := GameSettings.new()
	_check(re.load_file(CHECK_CFG) and re.code_at("jump", "kbm", 0) == "key:%d" % KEY_K, "settings file holds jump = K")
	re.free()
	await _frames(10)
	await _shot("settings-controls.png")
	ss.show_tab(3)
	await _frames(3)
	ss.set_difficulty("nav")
	await _frames(10)
	_check(Difficulty.current == "nav" and String(game.get("meta").difficulty) == "nav", "difficulty is «Навь» in the helper and the meta")
	_check(is_equal_approx(Difficulty.f("enemy_dmg"), 1.3) and is_equal_approx(Difficulty.f("heal"), 0.75), "«Навь» numbers in force")
	var sv := SaveFile.read(String(game.get("save_path")))
	_check(int(sv.get("version", 0)) == SaveFile.VERSION and String((sv.get("meta", {}) as Dictionary).get("difficulty", "")) == "nav", "save v%d holds difficulty nav" % SaveFile.VERSION)
	await _shot("settings-difficulty.png")
	ss.close()
	await _frames(3)
	pm.close()
	await _frames(3)
	_check(not get_tree().paused, "closing the pause menu unpauses")
	var dc := DifficultyChoiceScreen.new()
	var got := [""]
	dc.chosen.connect(func(id: String) -> void: got[0] = id)
	_w.show_screen(dc, 40)
	await _frames(5)
	_check(dc.ids[dc.selected] == "bylina", "choice screen preselects «Былина»")
	await _key(KEY_RIGHT)
	await _frames(5)
	await _shot("difficulty-choice.png")
	await get_tree().create_timer(Tune.f("screen_input_lock") + 0.1).timeout
	await _key(KEY_ENTER)
	await _frames(3)
	_check(got[0] == "nav", "choice screen: → then Enter takes «Навь»")
	# «На заставу» for real: the run ends as "quit", its embers go to the bank.
	var bank0: int = game.get("meta").embers
	_w.director.run.embers = 7
	var pm2 := _w.open_pause()
	await _frames(3)
	pm2.ask_quit()
	await _frames(3)
	pm2._quit()
	await _frames(10)
	_check(_w.director.phase == "summary" and game.get("meta").embers == bank0 + 7, "quit ends the run and banks its 7 embers")
	st.reset_controls()
	st.apply()
	_check(InputMap.event_is_action(sp, "jump") and st.code_at("jump", "kbm", 0) == "key:%d" % KEY_SPACE, "reset gives jump back Space")
	_finish()

func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECK_CFG))
	_note("DONE: %d failed checks" % _fail)
	var f := FileAccess.open(out_dir.path_join("settings-check-log.txt"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_log) + "\n")
		f.close()
	get_tree().quit(1 if _fail > 0 else 0)
