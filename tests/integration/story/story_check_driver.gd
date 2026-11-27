## Scripted story check (design/narrative/prologue-and-endings.md §1;
## dialogue/gods.md): plays the Prologue with scripted input — Enter key events
## confirm every box and card, the interact action presses «Пропустить» — then
## sees the run start with a rune offer that shows a god line over the cards.
## Saves <out_dir>/story-prologue-1.png (Потап's first line), story-prologue-pass.png
## (the «[E] Пропустить» prompt), story-god-line.png and story-check-log.txt.
## Started by world.gd with `-- --story-check=<dir>`; run with `--fresh
## --save=user://story_check_save.json`.
extends Node

var out_dir: String = "user://story_check"
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
	print("[story-check] ", s)

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

func _prologue() -> Prologue:
	for c in _w.get_children():
		if c is Prologue:
			return c
	return null

## The open box or card of the prologue scene, null if none.
func _open() -> Control:
	var pr := _prologue()
	if pr and pr.scene and is_instance_valid(pr.scene.current):
		return pr.scene.current
	return null

func _press_enter() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_ENTER
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().process_frame
	var u := InputEventKey.new()
	u.keycode = KEY_ENTER
	u.pressed = false
	Input.parse_input_event(u)

func _run() -> void:
	var game: Node = get_node("/root/Game")
	await _frames(3)
	var pr := _prologue()
	_check(pr != null, "a new save starts with the prologue")
	if pr == null:
		return _finish()
	var beats: Array = []
	pr.beat.connect(func(b: String) -> void: beats.append(b))
	var shot1 := false
	var shot_pass := false
	var boxes := 0
	var speakers: Array = []
	for i in 6000:
		pr = _prologue()
		if pr == null:
			break
		var o := _open()
		if o != null:
			if o is DialogueBox and not speakers.has((o as DialogueBox).speaker + ": " + (o as DialogueBox).text):
				speakers.append((o as DialogueBox).speaker + ": " + (o as DialogueBox).text)
			if not shot1 and o is DialogueBox and pr.stage == "watch":
				await _frames(4)
				await _shot("story-prologue-1.png")
				shot1 = true
			await _frames(30)
			if is_instance_valid(o):
				await _press_enter()
				boxes += 1
			await _frames(2)
			continue
		if pr.stage == "ask":
			if not shot_pass:
				await _frames(20)
				await _shot("story-prologue-pass.png")
				shot_pass = true
				var a := InputEventAction.new()
				a.action = &"interact"
				a.pressed = true
				Input.parse_input_event(a)
				await _frames(3)
				var b := InputEventAction.new()
				b.action = &"interact"
				b.pressed = false
				Input.parse_input_event(b)
				await _frames(10)
				if pr.stage == "ask":
					_note("interact event did not reach the prologue, pressing directly")
					pr.press_pass()
		await get_tree().process_frame
	for s in speakers:
		_note("  line " + s)
	_check(_prologue() == null, "prologue finished after %d confirmed boxes/cards" % boxes)
	_check(beats.has("ask") and beats.has("pass") and beats.has("fall") and beats.has("after"), "beats played: %s" % [beats])
	_check(shot1 and shot_pass, "prologue screenshots taken")
	_check(speakers.any(func(s: String) -> bool: return s.contains("Не сплю.")), "the guard answers Потап with his hero line")
	_check(game.meta.story.flags.has("prologue_seen"), "prologue_seen flag set")
	var sd := SaveFile.read(game.save_path)
	_check(sd.get("meta") is Dictionary and (sd.meta.story.flags as Dictionary).has("prologue_seen") and int(sd.version) == SaveFile.VERSION,
		"save v%s holds prologue_seen" % sd.get("version"))
	var ok := false
	for i in 900:
		if _w.director and _w.director.screen is RuneOfferScreen:
			ok = true
			break
		await get_tree().process_frame
	_check(ok, "the Навь start: the run begins with a rune offer")
	if ok:
		var scr := _w.director.screen as RuneOfferScreen
		await _frames(20)
		var first: Dictionary = (Tune.table("dialogue").god_lines as Array).filter(func(l: Dictionary) -> bool: return String(l.god) == scr.god)[0]
		_check(scr.voice_text != "" and scr.voice_text == String(first.ru), "god line over the cards (%s, first offer = its first line): «%s»" % [scr.voice_god, scr.voice_text])
		await _shot("story-god-line.png")
	_finish()

func _finish() -> void:
	_note("DONE: %d failed checks" % _fail)
	var f := FileAccess.open(out_dir.path_join("story-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().quit(1 if _fail > 0 else 0)
