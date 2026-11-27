## One released Flare in the room: the amulet's shape carrying the element
## (GDD amulet-and-flare §3.3 steps 4 and 8, §3.5). Built by Player after the
## "breath", added to the World. Geometry is AmuletRules; damage goes only through
## Enemy.hurt(hit) with Hit.Kind.FLARE (ADR-0002); hit feel only through World.
## Shapes: "ring" (instant circle), "beam" (instant line forward, cut at walls),
## "wave" (two travelling ground waves that launch), "knot" (a delayed trap that
## pulls and explodes; one at a time, group "flare_knots").
class_name Flare
extends Node2D

## Emitted for every enemy the shape touched: what it took and the hit.
signal struck(enemy: Enemy, dealt: float, hit: Hit)
## Emitted when the shape is done (knot: after its blast).
signal finished

## Draw order above the darkness layer (Darkness.Z), so the light shows.
const Z: int = 60

var shape: String = "ring"
## Power P (F3) and size multiplier S.
var power: float = 1.0
var size: float = 1.0
## Damage D (F3) per touched enemy.
var dmg: float = 0.0
## Element id (FlareElement); "pure" until gods are ported.
var element: String = FlareElement.PURE
## The amulet's row (amulets.json).
var row: Dictionary = {}
var world: World
var hero: Player
var face: int = 1
## The hero's chest at release (world space).
var chest: Vector2 = Vector2.ZERO
## Seconds since release (world-time, slowed with the world).
var t: float = 0.0
## Enemies already struck by this Flare (each once).
var hit_set: Array[Enemy] = []
## Surface the wave runs on / the knot lies on: Vector3(x0, y, x1).
var surf: Vector3 = Vector3.ZERO
## Wave fronts x: [left, right].
var fronts: Array[float] = []
## Knot state: "lie" -> "armed" -> "pull" -> "boom" -> "done".
var knot_state: String = "lie"
var pull_t: float = 0.0
var boom_t: float = 0.0
## The beam rectangle (for drawing).
var beam: Rect2 = Rect2()
var _done: bool = false

## Prepares a Flare of `p_shape` at power `p` for `p_hero`. Call before add_child.
func setup(p_hero: Player, p_row: Dictionary, p_shape: String, p: float, p_element: String) -> void:
	hero = p_hero
	world = p_hero.world
	row = p_row
	shape = p_shape
	power = p
	element = p_element
	face = p_hero.face
	chest = p_hero.position - Vector2(0, Player.H / 2.0)
	size = AmuletRules.size_mult(p, Tune.data)
	dmg = AmuletRules.flare_damage(Tune.f("flare_dmg"), float(row.get("shape_dmg", 1.0)), p, 0, Tune.f("bright_step"))
	z_index = Z

func _ready() -> void:
	var rw := _room_w()
	match shape:
		"ring":
			position = chest
			for e in _enemies():
				if AmuletRules.ring_hits(chest, e.hurt_rect(), _r("radius")):
					_strike(e, chest.x, _r_raw("kb") * power)
			_kill_shots(func(p: Vector2) -> bool: return p.distance_to(chest) < _r("radius"))
		"beam":
			beam = AmuletRules.beam_rect(chest, face, _r("len"), _r("h"), rw)
			for e in _enemies():
				if AmuletRules.beam_hits(beam, e.hurt_rect()):
					_strike(e, chest.x, _r_raw("kb") * power)
			_kill_shots(func(p: Vector2) -> bool: return beam.has_point(p))
		"wave":
			surf = _surface()
			fronts = [hero.position.x, hero.position.x]
		"knot":
			surf = _surface()
			position = Vector2(clampf(hero.position.x, surf.x, surf.z), surf.y)
			add_to_group("flare_knots")
	if world:
		world.add_shake(Tune.f("flare_shake"))
		world.request_hitstop(Tune.f("flare_hitstop"))
		world.add_flash(Tune.f("flare_flash"))

## Blows up every knot already in the room at once, without pulling (§3.5:
## one knot; a new Flare sets the old one off).
static func detonate_knots(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group("flare_knots"):
		var k := n as Flare
		if k and k.knot_state != "boom" and k.knot_state != "done":
			k._boom()

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	if world:
		dt *= world.time_mult()
	step(dt)
	queue_redraw()

## One tick of the shape (travelling wave, knot timers, fade).
func step(dt: float) -> void:
	t += dt
	match shape:
		"wave":
			_wave_step()
		"knot":
			_knot_step(dt)
		_:
			if t >= _r_raw("fx_time"):
				_finish()

func _wave_step() -> void:
	var life := _r_raw("time") * size
	var tt := minf(t, life)
	var h := _r("h")
	for i in 2:
		var dir := -1 if i == 0 else 1
		var prev: float = fronts[i]
		var now := AmuletRules.wave_front(_wave_origin(), dir, _r_raw("speed"), tt, surf.x, surf.z)
		var band := AmuletRules.wave_band(prev, now, surf.y, h)
		# A band of zero width still catches the enemy standing on the origin.
		band = band.grow_individual(2.0, 0.0, 2.0, 0.0)
		for e in _enemies():
			if e in hit_set:
				continue
			if band.intersects(e.hurt_rect()):
				_strike(e, prev, 0.0)
				e.launch(Tune.f("launch_speed") * _r_raw("launch_mult"))
		_kill_shots(func(p: Vector2) -> bool: return band.has_point(p))
		fronts[i] = now
	if t >= life:
		_finish()

var _origin_x: float = NAN
func _wave_origin() -> float:
	if is_nan(_origin_x):
		_origin_x = clampf(hero.position.x, surf.x, surf.z)
	return _origin_x

func _knot_step(dt: float) -> void:
	match knot_state:
		"lie":
			if t >= _r_raw("arm"):
				knot_state = "armed"
		"armed":
			var rects: Array = []
			for e in _enemies():
				rects.append(e.hurt_rect())
			if AmuletRules.knot_triggered(position, rects, _r_raw("trigger")) or t >= _r_raw("life"):
				knot_state = "pull"
				pull_t = 0.0
		"pull":
			pull_t += dt
			for e in _enemies():
				if AmuletRules.dist_to_rect(position, e.hurt_rect()) < _r("pull_r"):
					var k := Tune.f("boss_pull_mult") if e.boss else 1.0
					var v := AmuletRules.pull_velocity(e.center(), position - Vector2(0, e.h / 2.0), _r_raw("pull_speed"), e.weight, k)
					if not e.flies:
						v.y = 0.0
					var step_v := v * dt
					var to_c := position.x - e.position.x
					# Never pull past the knot's centre.
					if absf(step_v.x) > absf(to_c):
						step_v.x = to_c
					e.position += step_v
			if pull_t >= _r_raw("pull_time"):
				_boom()
		"boom":
			boom_t += dt
			if boom_t >= _r_raw("fx_time"):
				_finish()

func _boom() -> void:
	knot_state = "boom"
	boom_t = 0.0
	remove_from_group("flare_knots")
	for e in _enemies():
		if AmuletRules.dist_to_rect(position, e.hurt_rect()) < _r("r"):
			_strike(e, position.x, _r_raw("kb") * power)
	_kill_shots(func(p: Vector2) -> bool: return p.distance_to(position) < _r("r"))
	if world:
		world.add_shake(Tune.f("flare_shake"))
		world.add_flash(Tune.f("flare_flash") * 0.6)

func _finish() -> void:
	if _done:
		return
	_done = true
	knot_state = "done"
	finished.emit()
	queue_free()

## Hits one enemy with the Flare: damage D, element statuses, knockback from `from_x`.
func _strike(e: Enemy, from_x: float, kb: float) -> void:
	if e in hit_set or e.dead:
		return
	hit_set.append(e)
	var k := kb * FlareElement.kb_mult(element) * (Tune.f("boss_flare_kb_mult") if e.boss else 1.0)
	var hit := Hit.make(Hit.Kind.FLARE, dmg, from_x, k)
	hit.source = hero
	FlareElement.apply(element, hit, power, Tune.data)
	var dealt := e.hurt(hit)
	struck.emit(e, dealt, hit)

## Number of enemies this Flare has touched so far.
func touched() -> int:
	return hit_set.size()

func _kill_shots(inside: Callable) -> void:
	if world == null:
		return
	for c in world.get_children():
		var s := c as EnemyShot
		if s and s.life > 0.0 and inside.call(s.position):
			s.life = 0.0

## A size of the shape scaled by S.
func _r(key: String) -> float:
	return float(row.get(key, 0.0)) * size

## A number of the shape, not scaled.
func _r_raw(key: String) -> float:
	return float(row.get(key, 0.0))

func _room_w() -> float:
	return float(world.room.layout.w) if world and world.room else 0.0

func _surface() -> Vector3:
	var plats: Array = world.room.layout.plats if world and world.room else []
	var feet := hero.position
	if hero.is_on_floor():
		feet.y -= 1.0
	return AmuletRules.surface_under(feet.x, feet.y, plats, Tune.f("ground_y"), _room_w())

func _enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and not e.dead:
			out.append(e)
	return out

# ---------------- drawing (placeholder light) ----------------
const LIGHT := Color(1.0, 0.93, 0.7)

func _draw() -> void:
	match shape:
		"ring":
			var k := clampf(t / maxf(_r_raw("fx_time"), 0.01), 0.0, 1.0)
			var r := _r("radius")
			draw_circle(Vector2.ZERO, r * (0.3 + 0.7 * k), Color(LIGHT, 0.35 * (1.0 - k)))
			draw_arc(Vector2.ZERO, r * (0.3 + 0.7 * k), 0.0, TAU, 64, Color(LIGHT, 1.0 - k), 10.0 * (1.0 - k) + 2.0)
		"beam":
			var k := clampf(t / maxf(_r_raw("fx_time"), 0.01), 0.0, 1.0)
			var b := Rect2(beam.position - position, beam.size)
			draw_rect(b, Color(LIGHT, 0.45 * (1.0 - k)))
			draw_rect(b.grow_individual(0, -b.size.y * 0.35, 0, -b.size.y * 0.35), Color(1, 1, 1, 0.9 * (1.0 - k)))
		"wave":
			var fade := clampf(1.0 - t / maxf(_r_raw("time") * size, 0.01), 0.0, 1.0)
			var h := _r("h")
			for i in fronts.size():
				var x: float = fronts[i] - position.x
				var dir := -1.0 if i == 0 else 1.0
				var y := surf.y - position.y
				draw_colored_polygon(PackedVector2Array([Vector2(x - dir * 70.0, y), Vector2(x, y - h), Vector2(x + dir * 12.0, y)]),
					Color(LIGHT, 0.85 * fade))
				draw_line(Vector2(_wave_origin() - position.x, y - 2), Vector2(x, y - 2), Color(LIGHT, 0.3 * fade), 4.0)
		"knot":
			var pulse := 0.5 + 0.5 * sin(t * 12.0)
			match knot_state:
				"lie", "armed":
					var a := 0.5 if knot_state == "lie" else 0.8 + 0.2 * pulse
					draw_arc(Vector2(0, -6), 26.0, 0.0, TAU, 24, Color(LIGHT, a), 4.0)
					draw_line(Vector2(-20, -26), Vector2(20, 14), Color(LIGHT, a), 3.0)
					draw_line(Vector2(20, -26), Vector2(-20, 14), Color(LIGHT, a), 3.0)
					draw_arc(Vector2(0, -6), _r_raw("trigger"), 0.0, TAU, 40, Color(LIGHT, 0.15), 2.0)
				"pull":
					var k := pull_t / maxf(_r_raw("pull_time"), 0.01)
					draw_arc(Vector2(0, -20), _r("pull_r") * (1.0 - k), 0.0, TAU, 48, Color(LIGHT, 0.7), 4.0)
					draw_circle(Vector2(0, -20), 30.0 + 20.0 * k, Color(LIGHT, 0.6))
				"boom":
					var k := clampf(boom_t / maxf(_r_raw("fx_time"), 0.01), 0.0, 1.0)
					draw_circle(Vector2(0, -20), _r("r") * (0.4 + 0.6 * k), Color(LIGHT, 0.4 * (1.0 - k)))
					draw_arc(Vector2(0, -20), _r("r") * k, 0.0, TAU, 64, Color(LIGHT, 1.0 - k), 8.0)
