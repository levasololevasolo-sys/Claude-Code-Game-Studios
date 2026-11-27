## Run summary (GDD economy-and-meta §3.8, first cut): outcome, where and by
## whom the hero fell, rooms cleared, the build, the run's loot and the bank
## «было → стало». Enter / E / J starts a new run (emits `closed`). The
## «На что хватает» line waits for the sink catalogues (base). 1920x1080 layout.
class_name RunSummaryScreen
extends Control

## Emitted when the player leaves the screen.
signal closed

const OUTCOME: Dictionary = { "dead": "Пал", "home": "Вернулся с добычей", "win": "Победа", "quit": "Ушёл" }

## Game.end_run() result.
var summary: Dictionary = {}
## Build of the finished run (for rune names).
var build: RunBuild

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1920, 1080)
	get_tree().paused = true

func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k and k.pressed and not k.echo and k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_J, KEY_SPACE]:
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
	draw_string(font, Vector2(0, 1000), "Enter — новый забег", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color("#ffd27a"))
