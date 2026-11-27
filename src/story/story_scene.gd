## Plays a story scene as a list of steps (assets/data/scenes.json; design/
## narrative/prologue-and-endings.md §0: one event per step). Lines go through
## the base DialogueBox (mouse / gamepad / keyboard confirm), hero steps read
## dialogue.json hero_lines, cards are centred text on black. Used by Prologue
## for its spoken parts and on its own for the first-win scene (§2, minimal
## text version). Emits `finished` and frees itself; `sets` flags go to
## meta.story.flags at the end.
class_name StoryScene
extends Node

## The last step was played.
signal finished
## A step started (index, step) — the story check listens.
signal step_started(i: int, step: Dictionary)

var world: Node
var meta: MetaState
var steps: Array = []
var sets: Array = []
## Black backdrop behind the boxes (whole-scene cut, not over the game).
var black: bool = false
## Name of the hero in his lines (the prologue calls him «Страж»).
var hero_name: String = ""
## Open box or card, null when none.
var current: Control
var _back: CanvasLayer

## The first-win scene (§2) for `p_world`, black backdrop.
static func first_win(p_world: Node, p_meta: MetaState) -> StoryScene:
	var row: Dictionary = Tune.table("scenes").get("first_win", {})
	var s := StoryScene.new()
	s.world = p_world
	s.meta = p_meta
	s.steps = row.get("steps", [])
	s.sets = row.get("sets", [])
	s.black = true
	s.hero_name = "Нитка"
	return s

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if black:
		_back = CanvasLayer.new()
		_back.layer = 24
		var r := ColorRect.new()
		r.color = Color("#05070A")
		r.size = Vector2(1920, 1080)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back.add_child(r)
		add_child(_back)
	_run.call_deferred()

func _run() -> void:
	for i in steps.size():
		step_started.emit(i, steps[i])
		await play_step(steps[i])
	for f: String in sets:
		meta.story.flags[f] = true
	finished.emit()
	queue_free()

## Plays one step; returns when it is over.
func play_step(step: Dictionary) -> void:
	if step.has("wait"):
		await get_tree().create_timer(float(step.wait), false).timeout
		return
	if step.has("card"):
		var c := StoryCard.new()
		c.text = String(step.card)
		c.sub = String(step.get("sub", ""))
		c.time = float(step.get("t", 3.0))
		current = c
		_show(c, 27)
		await c.closed
		current = null
		return
	var speaker := ""
	var text := ""
	var col := Color("#FFC94A")
	if step.has("hero"):
		var l := StoryRules.hero_line(Tune.table("dialogue").get("hero_lines", []), String(step.hero), meta.story.said)
		if l.is_empty():
			return
		StoryRules.note_hero_line(meta, l)
		speaker = hero_name if hero_name != "" else ("Ждан" if meta.story.flags.has("hero_named") else "Нитка")
		text = String(l.get("ru", ""))
		col = Color("#9FC6E0")
	else:
		var who := String(step.get("who", ""))
		var t := Tune.table("scenes")
		speaker = String((t.get("names", {}) as Dictionary).get(who, who))
		text = String(step.get("ru", ""))
		var cs := String((t.get("colours", {}) as Dictionary).get(who, ""))
		if cs != "":
			col = Color(cs)
	var box := DialogueBox.new()
	box.speaker = speaker
	box.text = text
	box.speaker_colour = col
	current = box
	_show(box, 26)
	await box.closed
	current = null
	await get_tree().create_timer(0.05, false).timeout

func _show(c: Control, layer: int) -> void:
	if world and world.has_method("show_screen"):
		world.show_screen(c, layer)
	else:
		add_child(c)
