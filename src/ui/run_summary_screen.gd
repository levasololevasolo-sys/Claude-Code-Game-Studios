## Run summary (GDD economy-and-meta §3.8, first cut): outcome, where and by
## whom the hero fell, rooms cleared, the build, the run's loot and the bank
## «было → стало». Enter / E / pad A / a click on the button starts a new run
## (emits `closed`) after the ChoiceInput lockout; J / Space never close it (BUG-0003). The
## «На что хватает» line waits for the sink catalogues (base). 1920x1080 layout.
class_name RunSummaryScreen
extends Control

## Emitted when the player leaves the screen.
signal closed

## The «новый забег» button, local px (mouse hit test and hover highlight).
const BUTTON: Rect2 = Rect2(Vector2(710, 960), Vector2(500, 60))
const OUTCOME: Dictionary = { "dead": "Пал", "home": "Вернулся с добычей", "win": "Победа", "quit": "Ушёл" }

## Game.end_run() result.
var summary: Dictionary = {}
## Build of the finished run (for rune names).
var build: RunBuild
## Keyboard / gamepad / mouse reader with the confirm lockout (BUG-0002, BUG-0003).
var input: ChoiceInput
## Mouse is over the button.
var hover: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	input = ChoiceInput.make(Tune.f("screen_input_lock"))
	get_tree().paused = true

func _process(dt: float) -> void:
	input.tick(dt)

func _unhandled_input(ev: InputEvent) -> void:
	if input.read(ev, 1).act == ChoiceInput.Act.CONFIRM:
		get_viewport().set_input_as_handled()
		close()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := BUTTON.has_point((ev as InputEventMouseMotion).position)
		if h != hover:
			hover = h
			queue_redraw()
	if input.read(ev, 1, [BUTTON]).act == ChoiceInput.Act.PICK:
		accept_event()
		close()

## Closes the screen and unpauses.
func close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

## Text lines of the summary (also logged by the run check).
func lines() -> PackedStringArray:
	var run: Dictionary = summary.get("run", {})
	var out: PackedStringArray = []
	var loc: Dictionary = Tune.table("locations").get(str(int(run.get("tier", 1))), {})
	var where := "%s, %s" % [loc.get("name", "?"), "логово" if run.get("stage") == "lair" else ("привал" if run.get("stage") == "haven" else "комната %d" % int(run.get("room_k", 1)))]
	out.append("Где: " + where)
	out.append("Сложность: " + Difficulty.name_of(String(summary.get("difficulty", Difficulty.DEFAULT)), Difficulty.table()))
	if String(run.get("killed_by", "")) != "":
		out.append("Кто убил: " + String(run.killed_by))
	out.append("Комнат пройдено: %d   Убито врагов: %d   Хозяев: %d" % [int(run.get("rooms_cleared", 0)), int(run.get("kills", 0)), int(run.get("bosses", 0))])
	if build:
		for id in build.held():
			var lvl := build.level(id)
			out.append("  %s — %s%s" % [RunBuild.SLOT_LABEL.get(build.slot_of(id), ""), build.row(id).get("name", id), " (ур. %d)" % lvl if lvl > 0 else ""])
	var res: Dictionary = run.get("res", {})
	var res_txt: PackedStringArray = []
	for k: String in res:
		res_txt.append("%s %d" % [RunDirector.res_name(k), int(res[k])])
	out.append("Добыча забега: угли %d   %s" % [int(run.get("embers", 0)), ", ".join(res_txt)])
	var b0: Dictionary = summary.get("bank_before", {})
	var b1: Dictionary = summary.get("bank_after", {})
	out.append("Банк углей: %d → %d   (забегов всего: %d)" % [int(b0.get("embers", 0)), int(b1.get("embers", 0)), int(b1.get("runs", 0))])
	if not bool(summary.get("saved", false)):
		out.append("Сохранение НЕ записано — см. журнал")
	return out

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.92))
	var outcome := String(OUTCOME.get(summary.get("outcome", "dead"), "Конец забега"))
	draw_string(font, Vector2(0, 170), outcome, HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, Color("#e8c48a"))
	draw_string(font, Vector2(0, 225), "Итоги забега", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(0.7, 0.7, 0.65))
	var y := 320.0
	for l in lines():
		draw_string(font, Vector2(560, y), l, HORIZONTAL_ALIGNMENT_LEFT, 900, 30, Color("#f0ead8"))
		y += 46.0
	draw_rect(BUTTON, Color(1.0, 0.82, 0.48, 0.22 if hover else 0.08))
	draw_rect(BUTTON, Color("#ffd27a") if hover else Color(1.0, 0.82, 0.48, 0.45), false, 4.0 if hover else 2.0)
	draw_string(font, Vector2(0, 1000), "Enter / E / A — новый забег", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color("#ffd27a"))
