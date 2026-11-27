## Студёный дух, the zone flyer of Царство Морены (GDD enemies-and-elites §3.2:
## `jelly`, «зона: запрещает место»; frost roster §3.3, the one flyer kind there).
## Drifts above the hero; winds up for chill_w s (it swells, the core glows and a
## dashed frost ring marks the floor under it), then freezes that strip of floor
## for zone_time s: the hero standing in it moves ×zone_slow and takes zone_dmg
## every zone_tick s. At most zone_max zones per spirit. Stats: enemies.json "jelly".
class_name ColdSpirit
extends Enemy

## Live frost zones: {x, y, t} (y = floor height under the hero at the drop).
var zones: Array[Dictionary] = []
## Floor x and y the current wind-up marks.
var mark_x: float = 0.0
var mark_y: float = 0.0
var _tick: float = 0.0

func _load_stats() -> void:
	kind_id = "jelly"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())
	_zone_on_hero(dt)

func is_winding() -> bool:
	return st == "chill_w"

func _dead_tick(_dt: float) -> void:
	zones.clear()

## True when a hero at feet `p` stands in one of the zones.
func in_zone(p: Vector2) -> bool:
	for z: Dictionary in zones:
		if absf(p.x - float(z.x)) < stat("zone_w") / 2.0 and absf(p.y - float(z.y)) <= stat("zone_dy"):
			return true
	return false

## One tick: drift (to hover_dy above the hero) -> chill_w (floor ring) -> drift.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	for z: Dictionary in zones:
		z.t = float(z.t) - dt
	zones.assign(zones.filter(func(z: Dictionary) -> bool: return float(z.t) > 0.0))
	var dx := hp_pos.x - position.x
	face = int(signf(dx)) if dx != 0.0 else face
	match st:
		"idle", "drift":
			st = "drift"
			var tx := hp_pos.x - signf(dx) * stat("hover_dx")
			var ty := hp_pos.y - stat("hover_dy") + sin(anim * 1.6) * 14.0
			var to := Vector2(tx, ty) - position
			var want := to.limit_length(stat("drift"))
			vel += (want - vel) * minf(dt * stat("drift_resp"), 1.0)
			if cd <= 0.0 and zones.size() < int(stat("zone_max")) and absf(dx) < stat("range_x") and absf(hp_pos.y - position.y) < stat("range_y"):
				st = "chill_w"
				t = stat("chill_w")
				mark_x = hp_pos.x
				mark_y = hp_pos.y
		"chill_w":
			vel *= pow(0.05, dt)
			if t <= 0.0:
				zones.append({ "x": mark_x, "y": mark_y, "t": stat("zone_time") })
				st = "drift"
				cd = _stat_range("cd_min", "cd_max")

## Frozen floor on the hero: ×zone_slow of his own move and a tick of damage.
func _zone_on_hero(dt: float) -> void:
	var p := hero()
	if p == null or p.dead or not in_zone(p.position):
		_tick = 0.0
		return
	p.position.x -= p.velocity.x * dt * (1.0 - stat("zone_slow"))
	_tick += dt
	if _tick >= stat("zone_tick"):
		_tick -= stat("zone_tick")
		var keep := p.velocity
		hurt_hero(stat("zone_dmg"), Hit.Kind.TICK)
		p.velocity = keep

func _draw() -> void:
	var eye := Color(String(stats.eye))
	var core := Color(String(stats.get("core", "#a3206f")))
	# Zones and the wind-up ring are drawn in world space (local = world - position).
	for z: Dictionary in zones:
		var zp := Vector2(float(z.x), float(z.y)) - position
		var hw := stat("zone_w") / 2.0
		var a := clampf(float(z.t), 0.0, 1.0)
		draw_rect(Rect2(zp.x - hw, zp.y - 8.0, hw * 2.0, 8.0), Color(eye, 0.55 * a))
		for i in 6:
			var sx := zp.x - hw + 10.0 + i * (hw * 2.0 - 20.0) / 5.0
			draw_colored_polygon(PackedVector2Array([Vector2(sx - 6, zp.y - 6), Vector2(sx, zp.y - 22.0 - (i % 2) * 8.0), Vector2(sx + 6, zp.y - 6)]), Color(Color("#e8f6ff"), 0.85 * a))
	if st == "chill_w":
		var k := 1.0 - clampf(t / maxf(stat("chill_w"), 0.01), 0.0, 1.0)
		var mp := Vector2(mark_x, mark_y) - position
		var hw2 := stat("zone_w") / 2.0
		draw_dashed_line(Vector2(mp.x - hw2, mp.y - 3.0), Vector2(mp.x + hw2, mp.y - 3.0), Color(core, 0.5 + 0.5 * k), 4.0, 10.0)
		draw_dashed_line(Vector2(0, -h * 0.2), mp + Vector2(0, -6), Color(eye, 0.25 + 0.4 * k), 2.0, 12.0)
	_draw_windup_glow()
	var swell := 1.0 + (0.25 * (1.0 - clampf(t / maxf(stat("chill_w"), 0.01), 0.0, 1.0)) if st == "chill_w" else 0.06 * sin(anim * 3.0))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var cy := -h * 0.6
	var bell := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		bell.append(Vector2(cos(a) * w * 0.5 * swell, cy + sin(a) * h * 0.45 * swell))
	bell.append(Vector2(w * 0.5 * swell, cy + 6.0))
	bell.append(Vector2(-w * 0.5 * swell, cy + 6.0))
	draw_colored_polygon(bell, Color(c, 0.85))
	draw_circle(Vector2(0, cy - 4.0), 9.0 * swell, Color(core, 0.6 if st == "chill_w" else 0.35))
	# icy tendrils
	for i in 5:
		var tx := -w * 0.36 + i * w * 0.18
		draw_line(Vector2(tx, cy + 6.0), Vector2(tx + sin(anim * 3.0 + i) * 6.0, cy + 6.0 + h * 0.45), Color(eye, 0.6), 2.0)
	_draw_windup_outline(bell)
	_draw_eyes(Vector2(-7, cy - 8), Vector2(7, cy - 8), 2.6)
	_draw_overlay()
