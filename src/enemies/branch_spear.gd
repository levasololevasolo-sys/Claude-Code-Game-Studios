## Сучковик's branch-spear (GDD bestiary §3.3 card 5, mechanic spear_platform).
## Flies horizontally like any EnemyShot (hurts the hero, swatted by a strike,
## reflected by a parry), but at the wall it does not vanish: it sticks and
## for plat_time s is a one-way platform plat_w px long (Player.PLATFORM_LAYER,
## like the room's platforms), then breaks. A reflected spear flies back and
## stuns the Сучковик it hits for deflect_stun s.
class_name BranchSpear
extends EnemyShot

## Flight direction, -1 / 1.
var dir: int = -1
## X of the wall it sticks in (ForestRules.spear_stop_x).
var stop_x: float = 0.0
## Length of the step it leaves, px, and how long it stays, s.
var plat_w: float = 80.0
var plat_time: float = 4.0
## Stun on a Сучковик hit by the spear after a parry, s.
var deflect_stun: float = 1.0
## Shaft colour.
var wood: Color = Color("#8a7254")
## True once stuck in the wall; seconds left as a step.
var stuck: bool = false
var stuck_t: float = 0.0
## The one-way platform body while stuck (null otherwise).
var plat: StaticBody2D = null

## One tick: flight up to the wall, then the step's timer.
func step(dt: float) -> void:
	if stuck:
		stuck_t -= dt
		if ForestRules.step_gone(stuck_t):
			_break()
		return
	if not reflected:
		var nx := position.x + vel.x * dt
		if (dir < 0 and nx <= stop_x) or (dir > 0 and nx >= stop_x):
			position.x = stop_x
			stick()
			return
	super.step(dt)

## Sticks in the wall at stop_x: the step body appears (top at the spear's height).
func stick() -> void:
	stuck = true
	stuck_t = plat_time
	vel = Vector2.ZERO
	life = INF
	var r := ForestRules.step_rect(stop_x, dir, position.y, plat_w)
	plat = StaticBody2D.new()
	plat.collision_layer = Player.PLATFORM_LAYER
	plat.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	shape.one_way_collision = true
	shape.position = r.get_center() - position
	plat.add_child(shape)
	add_child(plat)
	Audio.play_at(&"spear_thunk", position)
	queue_redraw()

## The step's rect in world space (empty when flying).
func step_rect() -> Rect2:
	return ForestRules.step_rect(stop_x, dir, position.y, plat_w) if stuck else Rect2()

func _break() -> void:
	life = 0.0
	stuck = false
	if plat:
		plat.queue_free()
		plat = null
	Audio.play_at(&"wall_crack", position)

## A reflected spear: hurts the first enemy it touches; a Сучковик is stunned.
func _hit_enemies() -> void:
	var list: Array = targets
	if list.is_empty() and is_inside_tree():
		list = get_tree().get_nodes_in_group("enemies")
	for n in list:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		if e.hurt_rect().grow(r).has_point(position):
			var hit := Hit.make(Hit.Kind.PROJECTILE, dmg, position.x - signf(vel.x), Tune.f("parry_reflect_kb"))
			hit.source = source
			e.hurt(hit)
			var s := ForestRules.deflect_stun(e is Suchkovik, deflect_stun)
			if s > 0.0 and not e.dead:
				e.stun = maxf(e.stun, s)
			life = 0.0
			return

func light_spots() -> Array[Vector4]:
	if stuck or life <= 0.0:
		return []
	return super.light_spots()

## Drawn spear sprites (enemies_drawn_forest.json, kinds.suchkovik.projectile),
## loaded once: {ok, fly, stuck, tip}; ok false = the code shape below.
static var _art: Dictionary = {}

static func _load_art() -> Dictionary:
	if not _art.is_empty():
		return _art
	_art = { "ok": false }
	var kinds: Dictionary = DrawnEnemyVisual.registry().get("kinds", {})
	var pr: Dictionary = (kinds.get("suchkovik", {}) as Dictionary).get("projectile", {})
	var base := DrawnEnemyVisual.ROOT + "suchkovik/"
	if pr.is_empty() or DrawnEnemyVisual.art_mode(OS.get_cmdline_user_args()) != "drawn" \
			or not ResourceLoader.exists(base + String(pr.file)) or not ResourceLoader.exists(base + String(pr.stuck)):
		return _art
	var tip: Array = pr.get("tip", [0, 0])
	_art = { "ok": true, "fly": load(base + String(pr.file)), "stuck": load(base + String(pr.stuck)),
		"tip": Vector2(float(tip[0]), float(tip[1])),
		"scale": 1.0 / maxf(float(DrawnEnemyVisual.registry().get("px_per_world", 1.5)), 0.01) }
	return _art

## Paints the drawn sprite (tip at the origin, shaft behind); false = no art.
func _draw_art() -> bool:
	var art := _load_art()
	if not bool(art.ok):
		return false
	var s := float(dir)
	if reflected:
		s = signf(vel.x) if vel.x != 0.0 else -s
	var tint := Color.WHITE
	if reflected:
		tint = Color(1.0, 0.8, 0.6).lerp(color, 0.35)
	elif stuck and stuck_t < 1.0 and fmod(stuck_t * 8.0, 1.0) < 0.5:
		tint = Color(1.5, 1.4, 1.2)
	if not stuck:
		draw_line(Vector2(-s * plat_w, 0), Vector2(-s * plat_w * 1.6, 0), Color(Color("#ff8a3d"), 0.35), 2.0)
	var k := float(art.scale)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s * k, k))
	draw_texture(art.stuck if stuck else art.fly, -(art.tip as Vector2), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func _draw() -> void:
	if _draw_art():
		return
	var outline := Color("#120d12")
	var c := color if reflected else wood
	# The shaft trails behind the tip (flying) or juts from the wall (stuck).
	var back := float(-dir) * plat_w
	if reflected:
		back = -signf(vel.x) * plat_w * 0.8
	var tip := Vector2.ZERO
	var tail_p := Vector2(back, 0)
	if stuck and stuck_t < 1.0 and fmod(stuck_t * 8.0, 1.0) < 0.5:
		c = c.lightened(0.35)
	draw_line(tip, tail_p, outline, 9.0)
	draw_line(tip, tail_p, c, 6.0)
	draw_line(tip + Vector2(signf(back) * 4.0, -1), tail_p, c.lightened(0.2), 2.0)
	# Twigs and a leaf on the shaft; a sharp tip.
	for i in 2:
		var at := Vector2(back * (0.45 + 0.3 * i), 0)
		draw_line(at, at + Vector2(signf(back) * 8.0, -9.0 + 16.0 * i), c, 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(back * 0.8, -2), Vector2(back * 0.85 + signf(back) * 8.0, -9), Vector2(back * 0.9, -1)]), Color("#3e5a2e"))
	if not stuck:
		draw_colored_polygon(PackedVector2Array([Vector2(-signf(back) * 10.0, 0), Vector2(0, -4), Vector2(0, 4)]), c.lightened(0.3))
		draw_line(tail_p, tail_p + Vector2(back * 0.6, 0), Color(Color("#ff8a3d"), 0.35), 2.0)
	else:
		# Splinters where it went into the wall.
		for i in 3:
			draw_line(Vector2.ZERO, Vector2(signf(back) * 3.0, -8.0 + i * 8.0), c.darkened(0.3), 2.0)
