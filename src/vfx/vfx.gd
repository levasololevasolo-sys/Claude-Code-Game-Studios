## Game-feel VFX of a room (design/art/vfx-spec.md): material hit bursts, the
## parry burst and shock ring, the hero's blood and red edge flash, enemy
## emerge / wake / death-dissolve, footstep bits, bog ripples and frost wind
## gusts; owns the living grass and the flickering lamps of the location.
## Listens only (enemy and hero signals, World.child_entered_tree): it never
## changes gameplay, never adds hit-stop or shake (those stay in their owners).
## Created by Atmosphere, so it is rebuilt with every room. Data: vfx.json.
class_name Vfx
extends Node2D

## Both layers sit above the darkness (Darkness.Z = 50): hit feedback must read
## in the dark. The plain layer is not additive (blood stays dark red); the
## additive layer glows (sparks, ichor, embers, rings).
const Z_NORM: int = 52
const Z_ADD: int = 56
const STEP_TIME: float = 0.28
const VIEW_MARGIN: float = 260.0

var world: World
## Style of the room: "ruins" (swamp), "forest", "frost" or "base".
var style: String = "ruins"
## vfx.json; injected by tests, else Tune.table("vfx").
var data: Dictionary = {}
## Extra bog points (Vector2) for ripples on top of the layout's "bogs".
var extra_bogs: Array = []
var rng := RandomNumberGenerator.new()
var norm: VfxPool
var addp: VfxPool
var grass: VfxGrass
var lamps: VfxLamps
var _layers: Array[VfxLayer] = []
var _vig: Control
var _vig_t: float = 0.0
var _step_t: float = 0.0
var _ripple_t: float = 0.0
var _gust_wait: float = 3.0
var _gust_t: float = -1.0
var _gust: float = 0.0
var _emerge_on: bool = true
## Rising enemies: [enemy, seconds since start].
var _risers: Array = []
## Fixed step for scripted checks (> 0 replaces the frame dt, so frame strips are
## 60 fps frames even on a slow software renderer).
var fixed_dt: float = 0.0
## Microseconds of CPU spent by the VFX (tick and drawing of every VFX node)
## since the last reset; the --vfx-check budget reads it.
static var cost_us: int = 0

func _ready() -> void:
	if data.is_empty():
		data = Tune.table("vfx")
	rng.seed = 7741
	norm = VfxPool.new(int(data.get("cap_norm", 700)), int(data.get("splat_cap", 48)))
	norm.splat_life = float(data.get("splat_life", 2.2))
	addp = VfxPool.new(int(data.get("cap_add", 400)))
	for spec: Array in [[norm, Z_NORM, false], [addp, Z_ADD, true]]:
		var l := VfxLayer.new()
		l.pool = spec[0]
		l.soft = Atmosphere.dot()
		l.z_index = int(spec[1])
		if bool(spec[2]):
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			l.material = m
		add_child(l)
		_layers.append(l)
	_emerge_on = bool(data.get("emerge_in_other_checks", false)) or not _other_check()
	var w: Dictionary = (data.get("world", {}) as Dictionary).get(style, {})
	var layout: Dictionary = world.room.layout if world and world.room else {}
	if not layout.is_empty() and not bool(layout.get("base", false)):
		if w.has("grass"):
			grass = VfxGrass.new()
			grass.spec = w.grass
			grass.build(layout, Tune.f("ground_y"))
			add_child(grass)
		if w.has("lamps"):
			lamps = VfxLamps.new()
			lamps.spec = w.lamps
			lamps.build(layout, Tune.f("ground_y"))
			add_child(lamps)
	_make_vignette()
	if world:
		world.child_entered_tree.connect(_on_child.bind(true))
		for c in world.get_children():
			_on_child(c, false)
	Events.hero_acted.connect(_on_hero_acted)

## True under a scripted check other than --vfx-check (their screenshots keep
## enemies unsquashed by the emerge animation).
static func _other_check() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.contains("-check=") and not a.begins_with("--vfx-check="):
			return true
	return false

## Current «Частицы» level (GameSettings.particles_level).
func level() -> int:
	return VfxRules.clamp_level(GameSettings.particles_level)

# ---------------- emitting ----------------

## Emits a list of emitter specs at `at` flying along `dir` (unit). ctx keys:
## floor_y, body (Rect2, world), eyes (Array[Vector2]), body_col (Color),
## feet_w (float), extra (count multiplier). Returns particles made.
func emit_specs(specs: Array, at: Vector2, dir: Vector2, heavy: bool = false, ctx: Dictionary = {}) -> int:
	var made := 0
	for spec: Dictionary in specs:
		made += _emit(spec, at, dir, heavy, ctx)
	return made

func _emit(spec: Dictionary, at: Vector2, dir: Vector2, heavy: bool, ctx: Dictionary) -> int:
	var n := VfxRules.count(spec, level(), heavy, data, float(ctx.get("extra", 1.0)))
	if n <= 0:
		return 0
	var pool := addp if String(spec.get("layer", "norm")) == "add" else norm
	var shp := _shape_of(String(spec.get("shape", "mist")))
	var cols: Array = spec.get("col", ["#ffffff", "#ffffff"])
	var c0 := Color(String(cols[0]))
	var c1 := Color(String(cols[1 if cols.size() > 1 else 0]))
	var sp: Array = spec.get("speed", [0, 0])
	var lf: Array = spec.get("life", [0.3, 0.3])
	var sz: Array = spec.get("size", [4, 4])
	var spread := deg_to_rad(float(spec.get("spread", 30.0)))
	var up := deg_to_rad(float(spec.get("up", 0.0)))
	var d := Vector2.UP if bool(spec.get("dir_up", false)) else dir
	var base := d.angle() - (signf(d.x) if d.x != 0.0 else 0.0) * up
	var heavy_k := 1.25 if heavy else 1.0
	var area := String(spec.get("area", ""))
	var eyes: Array = ctx.get("eyes", []) if bool(spec.get("eye", false)) else []
	var floor_y := float(ctx.get("floor_y", INF))
	var body: Rect2 = ctx.get("body", Rect2(at, Vector2.ZERO))
	var body_k := float(spec.get("body_col", 0.0))
	var has_end := spec.has("col_end")
	var cend := Color(String(spec.get("col_end", "#000000")))
	var opts := { "grav": float(spec.get("grav", 0.0)), "drag": float(spec.get("drag", 0.0)), "floor_y": floor_y,
		"bounce": float(spec.get("bounce", 0.0)), "len": float(spec.get("len", 1.0)), "splat": bool(spec.get("splat", false)),
		"size_end": float(spec.get("size_end", 1.0)) }
	var total := n * maxi(eyes.size(), 1)
	for i in total:
		var p := at
		if not eyes.is_empty():
			p = eyes[i % eyes.size()]
		elif area == "body":
			p = body.position + Vector2(rng.randf() * body.size.x, rng.randf() * body.size.y)
		elif area == "feet":
			var fw := float(ctx.get("feet_w", 40.0))
			p = Vector2(at.x + rng.randf_range(-fw, fw) * 0.5, floor_y - 2.0)
		var a := base + rng.randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * rng.randf_range(float(sp[0]), float(sp[1])) * heavy_k
		var c := c0.lerp(c1, rng.randf())
		if body_k > 0.0 and ctx.has("body_col"):
			c = c.lerp(ctx.body_col as Color, body_k)
		opts.col_end = cend if has_end else Color(c, 0.0)
		opts.rot = rng.randf() * TAU
		opts.spin = rng.randf_range(-14.0, 14.0) if shp == VfxPool.Shape.SHARD else 0.0
		pool.add(shp, p, v, rng.randf_range(float(lf[0]), float(lf[1])), rng.randf_range(float(sz[0]), float(sz[1])) * heavy_k, c, opts)
	return total

static func _shape_of(s: String) -> int:
	var i := VfxPool.Shape.keys().find(s.to_upper())
	return i if i >= 0 else VfxPool.Shape.MIST

# ---------------- public effects ----------------

## The hit burst of `material` at `at` along `dir` (vfx-spec §3.1).
func hit_fx(material: String, at: Vector2, dir: Vector2, heavy: bool, floor_y: float) -> int:
	var m: Dictionary = (data.get("materials", {}) as Dictionary).get(material, {})
	return emit_specs(m.get("hit", []), at, dir, heavy, { "floor_y": floor_y })

## Death burst of `material` plus the Nav-mist / ember dissolve over `body`.
func death_fx(material: String, at: Vector2, dir: Vector2, body: Rect2, body_col: Color, floor_y: float) -> int:
	var m: Dictionary = (data.get("materials", {}) as Dictionary).get(material, {})
	var ctx := { "floor_y": floor_y, "body": body, "body_col": body_col, "extra": float(data.get("death_mult", 1.6)) }
	var made := emit_specs(m.get("death", []), at, dir, true, ctx)
	ctx.extra = maxf(1.0, body.size.x * body.size.y / 2600.0)
	return made + emit_specs(data.get("dissolve", []), at, Vector2.UP, false, ctx)

## The parry burst and shock ring at `at`, sparks flying along `dir`.
func parry_fx(at: Vector2, dir: Vector2) -> int:
	return emit_specs(data.get("parry", []), at, dir, false, {})

## The hero's own blood and the red edge flash.
func hero_hurt_fx(at: Vector2, dir: Vector2, floor_y: float) -> int:
	_vig_t = float((data.get("hurt_vignette", {}) as Dictionary).get("time", 0.3))
	return emit_specs(data.get("hero_hurt", []), at, dir, false, { "floor_y": floor_y })

## Rise from the ground (or fade in, flyers) with the location's burst.
func emerge_fx(e: Enemy) -> int:
	if e == null or not is_instance_valid(e) or e.dead:
		return 0
	var floor_y := e.position.y if not e.flies else e.center().y + e.h * 0.5
	var made := emit_specs((data.get("emerge", {}) as Dictionary).get(style, []), e.position, Vector2.UP, false,
		{ "floor_y": floor_y, "feet_w": e.w * 1.4, "body": Rect2(e.position - Vector2(e.w / 2.0, e.h), Vector2(e.w, e.h)) })
	_risers.append([e, 0.0])
	_tick_risers(0.0)
	return made

## Emerge animation, on the VFX clock (pauses with hit-stop like the rest):
## ground kinds grow from the floor with a small overshoot, flyers fade in.
func _tick_risers(dt: float) -> void:
	var dur := maxf(float(data.get("emerge_time", 0.42)), 0.01)
	for r: Array in _risers.duplicate():
		if not is_instance_valid(r[0]):
			_risers.erase(r)
			continue
		var e := r[0] as Enemy
		r[1] = float(r[1]) + dt
		var u := clampf(float(r[1]) / dur, 0.0, 1.0)
		if e.flies:
			e.modulate.a = u
		else:
			var b := 1.0 + 2.70158 * pow(u - 1.0, 3.0) + 1.70158 * pow(u - 1.0, 2.0)
			e.scale = Vector2(lerpf(1.15, 1.0, u), lerpf(0.12, 1.0, b))
		if u >= 1.0:
			e.scale = Vector2.ONE
			e.modulate.a = 1.0
			_risers.erase(r)

## Eyes ignite and a small puff of the location at the feet.
func wake_fx(e: Enemy) -> int:
	var eyes: Array = []
	for p: Vector2 in e.eye_pts:
		eyes.append(e.position + p)
	if eyes.is_empty():
		eyes.append(e.position + Vector2(e.face * e.w * 0.2, -e.h * 0.8))
	var made := 0
	var ec := Color(String(e.stats.get("eye", "#ffffff")))
	for spec: Dictionary in data.get("wake", []):
		var s := spec.duplicate()
		s.col = [ec.to_html(), ec.lightened(0.5).to_html()]
		made += _emit(s, e.position, Vector2.UP, false, { "eyes": eyes })
	var step: Dictionary = (data.get("steps", {}) as Dictionary).get(style, {})
	if not step.is_empty() and not e.flies:
		made += _emit(step, e.position, Vector2.UP, false, { "floor_y": e.position.y, "feet_w": e.w, "extra": 2.0 })
	return made

# ---------------- signal hooks ----------------

func _on_child(n: Node, live: bool) -> void:
	if n is Enemy:
		var e := n as Enemy
		if not e.damaged.is_connected(_on_damaged):
			e.damaged.connect(_on_damaged)
			e.died.connect(_on_died)
			e.woke.connect(wake_fx)
		if live and _emerge_on and not e.asleep and not e.boss:
			emerge_fx.call_deferred(e)
	elif n is Player:
		var p := n as Player
		if not p.hurt_taken.is_connected(_on_hero_hurt):
			p.hurt_taken.connect(_on_hero_hurt)
			p.parry_succeeded.connect(_on_parry)

## Material an enemy shows (VfxRules.material_of over enemies.json / vfx.json).
func material_of(e: Enemy) -> String:
	var id := e.kind_id
	if e.boss and not (data.get("kind_material", {}) as Dictionary).has(id):
		id = "boss"
	return VfxRules.material_of(id, Tune.table("enemies"), data)

func _floor_of(e: Enemy) -> float:
	return Tune.f("ground_y") if e.flies else e.position.y

func _on_damaged(e: Enemy, amount: float, hit: Hit) -> void:
	if VfxRules.silent(hit.kind):
		return
	var blocked := e.front_shield and amount <= 0.01
	var mat := VfxRules.hit_material(material_of(e), blocked)
	var heavy := VfxRules.is_heavy(hit.kind, hit.finisher, hit.limb, amount, e.max_hp, data)
	var at := VfxRules.hit_point(e.position, e.w, e.h, hit.from_x)
	hit_fx(mat, at, VfxRules.hit_dir(e.position.x, hit.from_x, 0.0, -e.face), heavy, _floor_of(e))

func _on_died(e: Enemy, hit: Hit) -> void:
	var body := Rect2(e.position - Vector2(e.w / 2.0, e.h), Vector2(e.w, e.h))
	death_fx(material_of(e), e.center(), VfxRules.hit_dir(e.position.x, hit.from_x, 0.0, -e.face), body,
		Color(String(e.stats.get("color", "#3a2a4a"))), _floor_of(e))

func _on_parry(_e: Enemy, _result: String) -> void:
	var p := world.player if world else null
	if p == null:
		return
	parry_fx(p.position + Vector2(p.face * 30.0, -Player.H * 0.62), Vector2(p.face, 0.0))

func _on_hero_hurt(_amount: float, hit: Hit) -> void:
	var p := world.player if world else null
	if p == null:
		return
	hero_hurt_fx(p.position - Vector2(0, Player.H * 0.55), VfxRules.hit_dir(p.position.x, hit.from_x, 0.0, -p.face), p.position.y)

func _on_hero_acted(action: StringName, _power: float) -> void:
	if action == &"swing" and grass and world and world.player and is_instance_valid(world.player):
		grass.slash(world.player.strike_rect(), world.player.face)
	elif action == &"land" and world and world.player and is_instance_valid(world.player):
		_bog_ripple(world.player.position, 2)

# ---------------- tick ----------------

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_tick(dt)
	cost_us += Time.get_ticks_usec() - t0

func _tick(dt: float) -> void:
	if fixed_dt > 0.0:
		dt = fixed_dt
	var k := 1.0
	if world:
		k = float(data.get("hitstop_speed", 0.12)) if world.hitstop > 0.0 else world.time_mult()
	norm.step(dt * k)
	_tick_risers(dt * k)
	addp.step(dt * k)
	var cam := get_viewport().get_camera_2d()
	if cam:
		var half := get_viewport_rect().size / (2.0 * cam.zoom.x)
		var view := Rect2(cam.get_screen_center_position() - half, half * 2.0).grow(VIEW_MARGIN)
		for l in _layers:
			l.set_view(view)
		if grass:
			grass.view = view
		if lamps:
			lamps.view = view
	for l in _layers:
		l.queue_redraw()
	_tick_hero(dt)
	_tick_gust(dt)
	if grass and world:
		grass.actors = _actors()
	if _vig_t > 0.0:
		_vig_t = maxf(0.0, _vig_t - dt)
		_vig.queue_redraw()

func _actors() -> Array:
	var out: Array = []
	var p := world.player
	if p and is_instance_valid(p):
		out.append([p.position, p.velocity])
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and not e.dead and not e.flies:
			out.append([e.position, e.vel + Vector2(e.kb, 0.0)])
	return out

func _tick_hero(dt: float) -> void:
	var p := world.player if world else null
	if p == null or not is_instance_valid(p):
		return
	if p.is_on_floor() and absf(p.velocity.x) > 150.0:
		_step_t -= dt
		if _step_t <= 0.0:
			_step_t = STEP_TIME
			var step: Dictionary = (data.get("steps", {}) as Dictionary).get(style, {})
			if not step.is_empty():
				_emit(step, p.position, Vector2.UP, false, { "floor_y": p.position.y, "feet_w": 24.0 })
	if p.is_on_floor() and absf(p.velocity.x) > 40.0:
		_ripple_t -= dt
		if _ripple_t <= 0.0:
			var rs: Dictionary = (data.get("world", {}) as Dictionary).get(style, {}).get("ripples", {})
			_ripple_t = float(rs.get("every", 0.22))
			_bog_ripple(p.position, 1)

## Bog water rings at the hero's feet when he stands in a bog (layout "bogs").
func _bog_ripple(at: Vector2, n: int) -> void:
	var rs: Dictionary = (data.get("world", {}) as Dictionary).get(style, {}).get("ripples", {})
	if rs.is_empty() or level() == VfxRules.LEVEL_OFF or not in_bog(at, float(rs.get("bog_r", 100.0))):
		return
	var c := Color(String(rs.get("col", "#9fc6a8")), 0.7)
	for i in n:
		addp.add(VfxPool.Shape.RIPPLE, at + Vector2(rng.randf_range(-8, 8), 0), Vector2.ZERO, float(rs.get("life", 0.9)) + i * 0.2,
			float(rs.get("size", 10.0)), c, { "size_end": float(rs.get("size_end", 5.0)) + i * 2.0 })

## True when `at` is within r px (along x, 40 px along y) of a bog point.
func in_bog(at: Vector2, r: float) -> bool:
	var bogs: Array = extra_bogs.duplicate()
	if world and world.room:
		bogs.append_array(world.room.layout.get("bogs", []))
	for b: Vector2 in bogs:
		if absf(b.x - at.x) <= r and absf(b.y - at.y) <= 60.0:
			return true
	return false

func _tick_gust(dt: float) -> void:
	var gs: Dictionary = (data.get("world", {}) as Dictionary).get(style, {}).get("gusts", {})
	if gs.is_empty():
		return
	if _gust_t < 0.0:
		_gust_wait -= dt
		if _gust_wait <= 0.0:
			_gust_t = 0.0
		return
	var dur := float(gs.get("time", 1.4))
	_gust_t += dt
	_gust = sin(clampf(_gust_t / dur, 0.0, 1.0) * PI)
	if _gust_t >= dur:
		_gust_t = -1.0
		_gust = 0.0
		var ev: Array = gs.get("every", [4.0, 8.0])
		_gust_wait = rng.randf_range(float(ev[0]), float(ev[1]))
	if grass:
		grass.gust = _gust * float(gs.get("power", 0.5))
	if world and world.atmosphere:
		world.atmosphere.push_air(_gust * float(gs.get("air_push", 160.0)))
	var per_s := float(gs.get("streaks", 26)) * VfxRules.level_mult(level(), data)
	if rng.randf() < per_s * dt * _gust:
		var cam := get_viewport().get_camera_2d()
		var cc := cam.get_screen_center_position() if cam else Vector2.ZERO
		var at := cc + Vector2(rng.randf_range(-700, 500), rng.randf_range(-320, 300))
		norm.add(VfxPool.Shape.STREAK, at, Vector2(rng.randf_range(700, 1000), rng.randf_range(20, 60)), 0.5, 1.2,
			Color(String(gs.get("col", "#ffffff")), 0.35), { "len": 0.07 })

# ---------------- hurt edge flash ----------------

func _make_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = PostFx.LAYER
	_vig = Control.new()
	_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.draw.connect(_draw_vignette)
	cl.add_child(_vig)
	add_child(cl)

func _draw_vignette() -> void:
	var vs: Dictionary = data.get("hurt_vignette", {})
	var t0 := float(vs.get("time", 0.3))
	if _vig_t <= 0.0 or t0 <= 0.0:
		return
	var a := float(vs.get("alpha", 0.4)) * (_vig_t / t0)
	if not GameSettings.flash_on:
		a *= Tune.f("flash_off_mult")
	var c := Color(String(vs.get("col", "#b3262e")), a)
	var z := Color(c, 0.0)
	var sz := _vig.size
	var d := minf(sz.x, sz.y) * float(vs.get("width", 0.16))
	var o := [Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]
	var i := [Vector2(d, d), Vector2(sz.x - d, d), sz - Vector2(d, d), Vector2(d, sz.y - d)]
	for k in 4:
		var k2 := (k + 1) % 4
		_vig.draw_polygon(PackedVector2Array([o[k], o[k2], i[k2], i[k]]), PackedColorArray([c, c, z, z]))
