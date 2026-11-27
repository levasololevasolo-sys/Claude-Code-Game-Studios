## A sparse floating line over the hero (design/narrative/dialogue/hero.md: Ждан
## speaks rarely, one phrase, after a main-line NPC line). Follows the hero for
## hero_line_time s and fades. Callers go through say(): it keeps the
## hero_line_cooldown between lines and refuses while enemies are awake, so a
## line never lands in combat.
class_name HeroBark
extends Node2D

## Text shown and its seconds left.
var text: String = ""
var t: float = 0.0
var target: Node2D
## Time (ms since start) of the last line, for the cooldown.
static var last_ms: int = -1000000

## True when a line may be said now: cooldown passed (`now_ms`, `last`, `cooldown_s`)
## and no fight is on (`fighting`). `force` (a scene step) skips the cooldown.
static func may_say(now_ms: int, last: int, cooldown_s: float, fighting: bool, force: bool = false) -> bool:
	if fighting:
		return false
	return force or now_ms - last >= int(cooldown_s * 1000.0)

## Shows `p_text` over `world`'s hero. Returns the bark or null when refused.
static func say(world: Node, p_text: String, force: bool = false) -> HeroBark:
	if world == null or p_text == "" or world.get("player") == null:
		return null
	var fighting := false
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not (e as Enemy).dead and not (e as Enemy).asleep:
			fighting = true
			break
	var now := Time.get_ticks_msec()
	if not may_say(now, last_ms, Tune.f("hero_line_cooldown"), fighting, force):
		return null
	last_ms = now
	for c in world.get_children():
		if c is HeroBark:
			c.queue_free()
	var b := HeroBark.new()
	b.text = p_text
	b.t = Tune.f("hero_line_time")
	b.target = world.player
	world.add_child(b)
	return b

func _ready() -> void:
	top_level = true
	z_index = Darkness.Z + 3
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(dt: float) -> void:
	t -= dt
	if t <= 0.0 or not is_instance_valid(target):
		queue_free()
		return
	position = target.global_position + Vector2(0, -Player.H - 70.0)
	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var a := clampf(t * 2.0, 0.0, 1.0)
	var s := "«%s»" % text
	draw_string_outline(font, Vector2(-360, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 720, 26, 6, Color(0, 0, 0, a))
	draw_string(font, Vector2(-360, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 720, 26, Color(0.93, 0.9, 0.82, a))
