## A straw idol that takes hits, flies back, falls and stands again. Stand-in for
## real enemies while the core is checked. Never dies: below `dummy_restore_below`
## of max hp it refills (GDD movement-and-combat §3.7 step 7). ADR-0002.
class_name StrawDummy
extends Enemy

func _load_stats() -> void:
	kind_id = "dummy"
	w = Tune.f("dummy_w")
	h = Tune.f("dummy_h")
	max_hp = Tune.f("dummy_hp")
	weight = Tune.f("dummy_weight")
	kb_scale = Tune.f("dummy_knockback_mult")
	drag = Tune.f("dummy_drag")

## The dummy stands still.
func _behave(_dt: float) -> void:
	pass

func _after_hurt(_hit: Hit) -> void:
	if hp < max_hp * Tune.f("dummy_restore_below"):
		hp = max_hp

func _draw() -> void:
	var c := Color("#c9a45a") if flash <= 0.0 else Color.WHITE
	draw_line(Vector2(0, 0), Vector2(0, -h), Color("#5b4026"), 5.0)
	draw_line(Vector2(-22, -h * 0.68), Vector2(22, -h * 0.68), Color("#5b4026"), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -h * 0.25), Vector2(-11, -h * 0.8), Vector2(11, -h * 0.8), Vector2(14, -h * 0.25)]), c)
	draw_circle(Vector2(0, -h * 0.88), 10.0, c)
	_draw_overlay()
