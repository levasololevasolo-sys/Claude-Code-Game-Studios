## Choice-screen mouse/gamepad check (BUG-0002, BUG-0003), Integration, evidence
## for production/qa/evidence/. Loads main.tscn with `--rune-offer=<god>`, pushes
## real input through the viewport: Space and Enter inside the lockout (must not
## take), a mouse hover over card 3 (must select it), then saves the screenshot.
## Run: godot --path . res://tests/integration/ui/choice_hover.tscn
##        -- --rune-offer=svarog --hover-out=<file.png>
extends Node

var out_file: String = "res://production/qa/evidence/bugfix-choice-hover.png"
var _fail: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hover-out="):
			out_file = a.trim_prefix("--hover-out=")
	add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		get_viewport().push_input(e, true)

func _check(ok: bool, what: String) -> void:
	print("[choice-hover] ", "OK   " if ok else "FAIL ", what)
	if not ok:
		_fail += 1

func _run() -> void:
	await _frames(4)
	var scr: RuneOfferScreen = null
	for n in get_tree().root.find_children("*", "RuneOfferScreen", true, false):
		scr = n
	_check(scr != null, "rune offer is open")
	if scr == null:
		get_tree().quit(1)
		return
	var held := scr.build.held().size()
	_key(KEY_SPACE)
	_key(KEY_J)
	_key(KEY_ENTER)
	await _frames(2)
	_check(is_instance_valid(scr) and scr.build.held().size() == held, "Space / J / Enter inside the lockout take nothing")
	var r: Rect2 = scr.card_rects()[scr.ids.size() - 1]
	var m := InputEventMouseMotion.new()
	m.position = r.get_center()
	m.global_position = r.get_center()
	get_viewport().push_input(m, true)
	await _frames(3)
	_check(scr.selected == scr.ids.size() - 1, "mouse hover selects card %d (selected %d)" % [scr.ids.size(), scr.selected + 1])
	get_viewport().get_texture().get_image().save_png(out_file)
	print("[choice-hover] shot ", out_file)
	print("[choice-hover] DONE: %d failed checks" % _fail)
	get_tree().quit(_fail)
