## Frost marks over the hero (GDD bestiary §3.4 Снежница, B5): up to
## frost_marks pips above his head fill ice blue as needles hit; while frozen an
## ice block covers him and a ring shows the time left. One per hero, added to
## the world by the first Снежница that sees him (FrostPips.ensure).
class_name FrostPips
extends Node2D

var hero: Player

## Adds the pips node for `p` once (no-op when it already exists or no world).
static func ensure(p: Player, world: Node) -> FrostPips:
	if world == null or p == null:
		return null
	for n in world.get_children():
		if n is FrostPips and (n as FrostPips).hero == p:
			return n
	var f := FrostPips.new()
	f.hero = p
	f.z_index = 40
	world.add_child(f)
	return f

func _process(_dt: float) -> void:
	if hero == null or not is_instance_valid(hero):
		queue_free()
		return
	position = hero.position
	queue_redraw()

func _draw() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var ice := Color("#8fd3f5")
	var dark := Color("#2c3b52")
	if hero.frozen_t > 0.0:
		var r := Rect2(-Player.W / 2.0 - 10, -Player.H - 12, Player.W + 20, Player.H + 14)
		draw_rect(r, Color(ice, 0.45), true)
		draw_rect(r, Color.WHITE, false, 3.0)
		draw_line(r.position + Vector2(6, 10), r.position + Vector2(r.size.x * 0.5, r.size.y * 0.4), Color(1, 1, 1, 0.8), 2.0)
		draw_line(r.position + Vector2(r.size.x - 6, 18), r.position + Vector2(r.size.x * 0.4, r.size.y * 0.7), Color(1, 1, 1, 0.6), 2.0)
		var k := clampf(hero.frozen_t / maxf(Tune.f("freeze_time"), 0.01), 0.0, 1.0)
		draw_arc(Vector2(0, -Player.H - 30), 10.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Color.WHITE, 3.0)
		return
	var n := int(Tune.f("frost_marks"))
	if hero.frost <= 0:
		return
	for i in n:
		var p := Vector2((i - (n - 1) / 2.0) * 26.0, -Player.H - 34)
		var pts := PackedVector2Array([p + Vector2(0, -13), p + Vector2(10, 0), p + Vector2(0, 13), p + Vector2(-10, 0)])
		draw_colored_polygon(pts, dark)
		if i < hero.frost:
			var inner := PackedVector2Array()
			for q in pts:
				inner.append(p + (q - p) * 0.72)
			draw_colored_polygon(inner, ice if i < n - 1 or hero.frost < n else Color.WHITE)
			draw_circle(p, 2.0, Color.WHITE)
