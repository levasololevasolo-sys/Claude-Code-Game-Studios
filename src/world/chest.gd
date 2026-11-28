## A chest on a C mark (GDD room-generation-and-doors §3.13). `rich` = a secret
## pocket chest. E by it opens it; RunDirector.open_chest gives the loot
## (drop_from "chest" / "cache"). Placeholder look.
class_name Chest
extends Node2D

signal opened(chest: Chest)

var world: World
var rich: bool = false
## A seal vault (artifacts-and-secrets §3.5) and its seal kind (for the lore line).
var vault: bool = false
var seal: String = ""
var is_open: bool = false
var near: bool = false

func _physics_process(_dt: float) -> void:
	var p := world.player if world else null
	near = p != null and is_instance_valid(p) and not p.dead and absf(p.position.x - position.x) < Tune.f("chest_reach") \
		and absf(p.position.y - position.y) < 60.0
	if near and not is_open and not p.scripted and Input.is_action_just_pressed(&"interact"):
		open()
	queue_redraw()

## Opens the chest once; the director gives what is inside.
func open() -> void:
	if is_open:
		return
	is_open = true
	if world and world.director:
		world.director.open_chest(self)
	opened.emit(self)

func _draw() -> void:
	var gold := Color("#9fe0ff") if vault else (Color("#e8c060") if rich else Color("#b08a4a"))
	draw_rect(Rect2(-26, -30, 52, 30), Color("#5b3a1e"))
	draw_rect(Rect2(-26, -30, 52, 30), gold, false, 3.0)
	if is_open:
		draw_colored_polygon(PackedVector2Array([Vector2(-26, -30), Vector2(-30, -56), Vector2(22, -60), Vector2(26, -30)]), Color("#6b4524"))
		draw_circle(Vector2(0, -34), 40, Color(gold, 0.25))
	else:
		draw_rect(Rect2(-26, -42, 52, 12), Color("#6b4524"))
		draw_rect(Rect2(-5, -36, 10, 10), gold)
	if near and not is_open:
		draw_string(ThemeDB.fallback_font, Vector2(-80, -70), "E — открыть", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(1, 1, 1, 0.9))
