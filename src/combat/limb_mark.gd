## Marks of cut parts on a living enemy (GDD limb-zones §3.4): the arm stump,
## the neck stump with rising Nav mist, and the word («Без руки!», «Голова с
## плеч!»). A child node of the enemy, so it shows over pre-rendered skins too
## (EnemySprite hides only the enemy's own drawing). Reads the enemy, never writes it.
class_name LimbMark
extends Node2D

var enemy: Enemy
## Word shown and its seconds left.
var word: String = ""
var word_t: float = 0.0

func _ready() -> void:
	z_index = 4

## Shows a word over the enemy for `time` s.
func say(text: String, time: float) -> void:
	word = text
	word_t = time

func _process(dt: float) -> void:
	word_t = maxf(0.0, word_t - dt)
	queue_redraw()

func _draw() -> void:
	if enemy == null or enemy.dead:
		return
	var row := enemy.limb_row()
	var f := enemy.face
	var w := enemy.w
	var h := enemy.h
	var blood := Color(0.62, 0.05, 0.09)
	if enemy.arm_off and row.has("arm_root"):
		var rt: Array = row.arm_root
		var p := Vector2(float(rt[0]) * w * f, -float(rt[1]) * h)
		draw_line(p, p + Vector2(8.0 * f, 4.0), Color(String(enemy.stats.get("color", "#444444"))).darkened(0.2), 6.0)
		draw_circle(p + Vector2(9.0 * f, 4.0), 4.0, blood)
		draw_circle(p + Vector2(9.0 * f, 10.0 + fmod(enemy.anim * 30.0, 14.0)), 1.8, blood)
	if enemy.head_off and row.has("head"):
		var hs: Array = row.head
		var neck := Vector2((float(hs[0]) + float(hs[1])) * 0.5 * w * f, -float(hs[2]) * h)
		draw_rect(Rect2(neck.x - 7.0, neck.y - 3.0, 14.0, 6.0), blood)
		for i in 4:
			var k := fmod(enemy.anim * 0.9 + float(i) * 0.25, 1.0)
			draw_circle(neck + Vector2(sin(enemy.anim * 3.0 + i) * 6.0, -6.0 - 34.0 * k), 4.0 + 6.0 * k, Color(0.55, 0.85, 0.78, 0.45 * (1.0 - k)))
	if word_t > 0.0:
		var font: Font = ThemeDB.fallback_font
		var a := clampf(word_t * 3.0, 0.0, 1.0)
		var y := -h - 104.0 - (1.0 - a) * 10.0
		draw_string_outline(font, Vector2(-120, y), word, HORIZONTAL_ALIGNMENT_CENTER, 240, 26, 6, Color(0, 0, 0, a))
		draw_string(font, Vector2(-120, y), word, HORIZONTAL_ALIGNMENT_CENTER, 240, 26, Color(1.0, 0.35, 0.3, a))
