## Launch-flow check (BUG: the game started straight in location 1). Plays a
## normal launch: main menu -> «Новая игра» -> slot 1 -> difficulty -> prologue
## -> the base «Застава» -> its gate -> a run. Uses the real slot files
## (user://slot_N.json), so it first deletes all 5: run it only in the cloud
## workspace, never on a player's machine. Started by world.gd with
## `-- --menu-check=<dir>`; writes menu-check-log.txt and screenshots.
extends Node

var out_dir: String = "user://menu_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[menu-check] ", s)
	_lines.append(s)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	_note(("OK   " if cond else "FAIL ") + what)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot " + file)

func _find(cls: Variant) -> Node:
	for n in get_tree().root.find_children("*", "", true, false):
		if is_instance_of(n, cls):
			return n
	return null

func _wait(cond: Callable, frames: int = 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func _button(menu: Node, text: String) -> Button:
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(text):
			return b
	return null

func _run() -> void:
	var ok := await _wait(func() -> bool: return _find(MainMenu) != null)
	_ok(ok, "a normal launch opens the main menu")
	_ok(_w.director == null, "no run and no level behind the menu")
	var mm := _find(MainMenu) as MainMenu
	for i in range(1, SaveSlots.SLOTS + 1):
		SaveSlots.delete_slot(i)
	mm.last = 0
	mm.show_main()
	await _frames(5)
	_ok(_button(mm, "Продолжить") == null and _button(mm, "Новая игра") != null, "no save: no «Продолжить», «Новая игра» is there")
	await _shot("menu-main-empty.png")
	_button(mm, "Новая игра").pressed.emit()
	await _frames(5)
	var slots := 0
	for b in mm.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Слот"):
			slots += 1
	_ok(slots == SaveSlots.SLOTS, "«Новая игра» lists %d slots" % slots)
	await _shot("menu-slots.png")
	_button(mm, "Слот 1").pressed.emit()
	ok = await _wait(func() -> bool: return _find(DifficultyChoiceScreen) != null)
	_ok(ok, "a new slot asks for the difficulty")
	await _frames(10)
	await _shot("menu-difficulty.png")
	(_find(DifficultyChoiceScreen) as DifficultyChoiceScreen).take(1)
	ok = await _wait(func() -> bool: return _find(Prologue) != null)
	_ok(ok, "then the prologue plays")
	await _frames(60)
	await _shot("menu-prologue.png")
	(_find(Prologue) as Prologue).call("_finish")
	ok = await _wait(func() -> bool: return _w.director != null and _w.director.phase == "base")
	_ok(ok, "after the prologue the hero is in the base «Застава», not in location 1")
	var game: Node = get_node("/root/Game")
	_ok(game.run == null, "no run is going on in the base")
	await _frames(40)
	await _shot("menu-base.png")
	_ok(not SaveSlots.slot_summary(1).is_empty(), "slot 1 is saved")
	_ok(SaveSlots.last_slot() == 1, "slot 1 is remembered as the last one")
	var mm2 := MainMenu.new()
	_w.show_screen(mm2, 45)
	await _frames(5)
	_ok(_button(mm2, "Продолжить") != null, "with a save the menu offers «Продолжить»")
	await _shot("menu-main-continue.png")
	mm2.queue_free()
	await _frames(3)
	_w.director.base.use("gate")
	ok = await _wait(func() -> bool: return _w.director.run != null and _w.director.phase != "base")
	_ok(ok, "the base gate starts a run")
	await _frames(30)
	await _shot("menu-run.png")
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("menu-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
