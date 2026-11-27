## The playable prologue «Ночь на мосту» (design/narrative/prologue-and-endings.md
## §1). Plays once per save before the first run (flag prologue_seen): the hero
## is the bridge guard at his post, Потап calls from the chain tower, the old man
## walks up with his lantern, the hero presses interact on «[E] Пропустить», the
## old man walks into the fog and stops at the middle, the blow, the chain goes,
## the Змей rises, the fall, the thread, the title — then the Навь start.
## Staging is placeholder shapes over a plain room (the art team replaces it).
## Spoken parts are StoryScene steps from assets/data/scenes.json "prologue".
## Deviation (noted for the designer): step 1.13, the short unwinnable fight with
## the Змей, is a scripted beat here (shake, fire, silhouette), not a fight.
## Esc / pad Start («Дальше») skips the scene once this machine has seen it
## through (user://story.cfg), never on the very first play.
class_name Prologue
extends Node2D

## The scene is over (played or skipped); World starts the run.
signal finished
## Beat reached: "watch", "meet", "ask", "pass", "fall", "after" (the check listens).
signal beat(name: String)

const CFG_PATH: String = "user://story.cfg"

var world: World
var meta: MetaState
## Current beat name.
var stage: String = ""
## Running StoryScene, null between spoken parts.
var scene: StoryScene
var old_x: float = 0.0
var old_target: float = 0.0
var old_visible: bool = false
var serpent: float = 0.0
var crack: float = 0.0
var fire: float = 0.0
var _ask_t: float = 0.0
var _nudged: int = 0
var _old_say: String = ""
var _old_say_t: float = 0.0
var _passed: bool = false
var _done: bool = false
var _row: Dictionary = {}

## True when this machine saw the prologue through once (the skip is offered).
static func skip_allowed() -> bool:
	if not FileAccess.file_exists(CFG_PATH):
		return false
	var c := ConfigFile.new()
	return c.load(CFG_PATH) == OK and bool(c.get_value("story", "prologue_done", false))

static func _remember_done() -> void:
	var c := ConfigFile.new()
	if FileAccess.file_exists(CFG_PATH):
		c.load(CFG_PATH)
	c.set_value("story", "prologue_done", true)
	c.save(CFG_PATH)

func _ready() -> void:
	_row = Tune.table("scenes").get("prologue", {})
	world.start_room({ "w": float(_row.get("layout_w", 2600)), "plats": [], "packs": [], "portal": false, "haven": true })
	world.player.position.x = float(_row.get("guard_x", 1250))
	# Above the room's backdrop, under the hero.
	world.move_child.call_deferred(self, world.room.get_index() + 1)
	old_x = float(_row.get("old_start_x", 120))
	_play.call_deferred()

func _play() -> void:
	await _speak("watch")
	stage = "meet"
	old_visible = true
	beat.emit("meet")
	old_target = world.player.position.x - 130.0
	while absf(old_x - old_target) > 4.0:
		await get_tree().process_frame
		old_target = world.player.position.x - 130.0
	await _speak("meet")
	stage = "ask"
	beat.emit("ask")
	while not _passed:
		await get_tree().process_frame
	await _speak("pass")
	stage = "walk"
	old_target = float(_row.get("old_mid_x", 2150))
	while absf(old_x - old_target) > 4.0:
		await get_tree().process_frame
	await get_tree().create_timer(1.2, false).timeout
	stage = "fall"
	beat.emit("fall")
	world.add_shake(Tune.f("prologue_shake"))
	world.add_flash(0.6)
	var tw := create_tween()
	tw.tween_property(self, "crack", 1.0, 1.2)
	tw.parallel().tween_property(self, "fire", 1.0, 1.5)
	tw.tween_property(self, "serpent", 1.0, 1.0)
	await _speak("fall")
	world.add_shake(Tune.f("prologue_shake") * 1.5)
	await _speak("after", true)
	_finish()

## Plays the spoken part `part` of the scene data.
func _speak(part: String, black: bool = false) -> void:
	stage = part
	beat.emit(part)
	scene = StoryScene.new()
	scene.world = world
	scene.meta = meta
	scene.steps = _row.get(part, [])
	scene.black = black
	scene.hero_name = String((Tune.table("scenes").get("names", {}) as Dictionary).get("guard", "Страж"))
	add_child(scene)
	await scene.finished
	scene = null

func _finish() -> void:
	if _done:
		return
	_done = true
	for f: String in _row.get("sets", ["prologue_seen"]):
		meta.story.flags[f] = true
	_remember_done()
	get_tree().paused = false
	finished.emit()
	queue_free()

## Presses «Пропустить» (the interact button while the prompt shows).
func press_pass() -> void:
	if stage == "ask" and not _passed:
		_passed = true

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed(&"ui_cancel") and skip_allowed() and not _done:
		get_viewport().set_input_as_handled()
		for c in world.get_children():
			if c is CanvasLayer:
				for s in c.get_children():
					if s is DialogueBox or s is StoryCard:
						s.queue_free()
		_finish()

func _physics_process(dt: float) -> void:
	var p := world.player
	if p:
		p.position.x = clampf(p.position.x, float(_row.get("hero_min_x", 520)), float(_row.get("hero_max_x", 1700)))
	if old_visible:
		old_x = move_toward(old_x, old_target, Tune.f("prologue_old_speed") * dt)
	if stage == "ask":
		_ask_t += dt
		if Input.is_action_just_pressed(&"interact"):
			press_pass()
		var nudges := [Tune.f("prologue_nudge_1"), Tune.f("prologue_nudge_2")]
		if _nudged < 2 and _ask_t >= float(nudges[_nudged]):
			_old_say = String(_row.get("nudge_%d" % (_nudged + 1), ""))
			_old_say_t = 4.0
			_nudged += 1
	_old_say_t -= dt
	queue_redraw()

func _draw() -> void:
	var g := Tune.f("ground_y")
	var w := float(_row.get("layout_w", 2600))
	var font: Font = ThemeDB.fallback_font
	var tm := Time.get_ticks_msec() / 1000.0
	# night sky and the river of fire under the bridge
	draw_rect(Rect2(-600, g - 1300, w + 1200, 1300), Color("#0B1020", 0.9))
	draw_rect(Rect2(-600, g + 40, w + 1200, 500), Color("#3A0E06"))
	for i in 18:
		var fx := -400.0 + i * 180.0
		draw_circle(Vector2(fx + sin(tm + i) * 30.0, g + 140 + (i % 3) * 40), 60 + (i % 4) * 10, Color("#FF6A1A", 0.18 + 0.1 * fire))
	# the bridge deck with posts and a broken span once it cracks
	var mid := float(_row.get("old_mid_x", 2150))
	draw_rect(Rect2(-600, g - 6, w + 1200, 34), Color("#4A3020"))
	var x := -600.0
	while x < w + 600:
		draw_line(Vector2(x, g - 6), Vector2(x, g + 28), Color("#2A1A10"), 3.0)
		draw_line(Vector2(x, g - 70), Vector2(x, g - 6), Color("#5B3A24"), 6.0)
		x += 90.0
	draw_line(Vector2(-600, g - 64), Vector2(w + 600, g - 64), Color("#6B4A2E"), 5.0)
	if crack > 0.0:
		var cx := lerpf(mid, world.player.position.x + 40.0, crack)
		draw_polyline(PackedVector2Array([Vector2(mid, g), Vector2((mid + cx) / 2.0, g + 10), Vector2(cx, g - 2)]), Color("#FFB040"), 4.0)
	# chain tower with its lantern and the big shadow on it
	var tx := float(_row.get("tower_x", 260))
	draw_rect(Rect2(tx - 70, g - 520, 140, 520), Color("#2E2218"))
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 95, g - 520), Vector2(tx, g - 640), Vector2(tx + 95, g - 520)]), Color("#3B2A1C"))
	draw_circle(Vector2(tx + 40, g - 450), 46, Color("#FFB040", 0.18))
	draw_circle(Vector2(tx + 40, g - 450), 12, Color("#FFC870"))
	draw_rect(Rect2(tx - 40, g - 480, 46, 90), Color("#140E0A"))
	if stage in ["watch", "meet", "ask", "pass", "walk"]:
		draw_line(Vector2(tx + 70, g - 300), Vector2(mid, g + 30), Color("#6E6A62"), 5.0)
	# the post with a carved face
	var px := float(_row.get("post_x", 1400))
	draw_rect(Rect2(px - 22, g - 210, 44, 210), Color("#5B3A24"))
	draw_circle(Vector2(px, g - 170), 16, Color("#3A2616"))
	draw_circle(Vector2(px - 6, g - 174), 3, Color("#FFC870", 0.6))
	draw_circle(Vector2(px + 6, g - 174), 3, Color("#FFC870", 0.6))
	# fog to the right, the white figure far away for a second
	for i in 10:
		draw_rect(Rect2(1800 + i * 90, g - 600, 90, 640), Color("#AFC0C8", 0.04 + i * 0.03))
	if stage == "meet" and fmod(tm, 9.0) < 1.0:
		draw_rect(Rect2(2400, g - 150, 26, 150), Color("#F4F6FF", 0.35))
	# the old man: round, stooped, coat too big, staff, beard, clay lantern
	if old_visible:
		var o := Vector2(old_x, g)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-34, 0), o + Vector2(-30, -70), o + Vector2(-10, -100), o + Vector2(20, -96), o + Vector2(34, -60), o + Vector2(30, 0)]), Color("#6A5440"))
		draw_circle(o + Vector2(12, -108), 18, Color("#D8C4A0"))
		draw_colored_polygon(PackedVector2Array([o + Vector2(0, -102), o + Vector2(24, -102), o + Vector2(14, -70)]), Color("#E8E2D4"))
		draw_line(o + Vector2(40, -90), o + Vector2(46, 0), Color("#8A6F48"), 5.0)
		var lamp := o + Vector2(-44, -50)
		draw_circle(lamp, 40, Color("#FFB040", 0.16))
		draw_circle(lamp, 10, Color("#FFC870"))
		if _old_say_t > 0.0 and _old_say != "":
			draw_string_outline(font, o + Vector2(-300, -150), "«%s»" % _old_say, HORIZONTAL_ALIGNMENT_CENTER, 600, 24, 6, Color.BLACK)
			draw_string(font, o + Vector2(-300, -150), "«%s»" % _old_say, HORIZONTAL_ALIGNMENT_CENTER, 600, 24, Color("#E8DCC0"))
	# the Змей: three heads rising out of the fire at the middle
	if serpent > 0.0:
		for k in 3:
			var hx := mid - 180.0 + k * 180.0
			var top := g + 60.0 - serpent * (380.0 + k % 2 * 80.0)
			draw_line(Vector2(hx, g + 80), Vector2(hx + sin(tm * 2.0 + k) * 30.0, top), Color("#1A0C08", 0.95), 46.0)
			draw_circle(Vector2(hx + sin(tm * 2.0 + k) * 30.0, top), 40, Color("#1A0C08"))
			draw_circle(Vector2(hx + sin(tm * 2.0 + k) * 30.0 + 14, top - 6), 6, Color("#FF6A1A"))
	# the «Пропустить» prompt over the hero
	if stage == "ask" and world.player:
		var hp := world.player.position + Vector2(0, -Player.H - 60.0)
		var s := String(_row.get("prompt", "[E] Пропустить"))
		draw_string_outline(font, hp + Vector2(-200, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 400, 30, 6, Color.BLACK)
		draw_string(font, hp + Vector2(-200, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 400, 30, Color("#FFC94A"))
