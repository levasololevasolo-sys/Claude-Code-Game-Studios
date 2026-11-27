## The knight's reward (GDD enemies-and-elites §3.7, F4.4): three stones, the hero
## takes one — 0 Род rune offer, 1 weapon (quality +1, drop_from "knight"),
## 2 rich chest (knight_chest_*). The stones show only when no awake enemy is
## within knight_reward_clear_r; until then «награда ждёт» hangs over the spot.
class_name KnightReward
extends Node2D

const LABELS: Array[String] = ["Руна Рода", "Оружие", "Богатый сундук"]
const COLOURS: Array[String] = ["#e0c080", "#9fd0ff", "#ffd27a"]

var world: World
var director: RunDirector
var ready_now: bool = false
var taken: int = -1
var _t: float = 0.0

func _physics_process(dt: float) -> void:
	_t += dt
	if taken >= 0:
		return
	ready_now = true
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if not en.dead and not en.prop and not en.asleep and en.position.distance_to(position) < Tune.f("knight_reward_clear_r"):
			ready_now = false
	var p := world.player if world else null
	if ready_now and p and is_instance_valid(p) and not p.scripted and Input.is_action_just_pressed(&"interact"):
		var i := nearest(p.position.x)
		if i >= 0:
			take(i)
	queue_redraw()

## Index of the stone within reach of x, or -1.
func nearest(x: float) -> int:
	for i in 3:
		if absf(x - stone_x(i)) < Tune.f("door_reach"):
			return i
	return -1

func stone_x(i: int) -> float:
	return position.x + (i - 1) * Tune.f("knight_stone_gap")

## Takes stone i (once).
func take(i: int) -> void:
	if taken >= 0 or not ready_now:
		return
	taken = i
	if director:
		director.knight_reward(i, Vector2(stone_x(1), position.y))
	queue_free()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if not ready_now:
		draw_string(font, Vector2(-100, -110), "награда ждёт", HORIZONTAL_ALIGNMENT_CENTER, 200, 18, Color("#ff8a8a"))
		return
	for i in 3:
		var c := Color(COLOURS[i])
		var p := Vector2((i - 1) * Tune.f("knight_stone_gap"), -40 + sin(_t * 3.0 + i) * 5.0)
		draw_circle(p, 34, Color(c, 0.18))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -24), p + Vector2(18, 0), p + Vector2(0, 24), p + Vector2(-18, 0)]), c)
		draw_string(font, p + Vector2(-70, -40), LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color(1, 1, 1, 0.9))
