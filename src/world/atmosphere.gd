## Air of a room (visual-upgrade-plan §2.4, §2.5): ambient particles around the
## camera from visuals.json (fireflies, leaves, spores, snow, embers, low mist),
## landing and running dust at the hero's feet, and a warm additive glow around
## the hero that follows the amulet light radius (replaces the cold flat circle).
## CPUParticles2D, not GPUParticles2D: at these counts (under 200) the CPU cost is
## negligible and it renders the same on Forward+ and gl_compatibility.
## Visual only; reads the hero, never changes him.
class_name Atmosphere
extends Node2D

## Above the darkness (Darkness.Z = 50), so lights stay lit.
const Z_GLOW: int = 55
## Ambient particles live under the darkness except the self-lit ones.
const Z_AIR: int = 45
## Half size of the spawn box around the camera centre, world px.
const BOX: Vector2 = Vector2(820, 460)
## Fall speed that makes landing dust, px/s (≈ a 120 px drop).
const LAND_VY: float = 420.0
const STEP_TIME: float = 0.28

var world: World
## One visuals.json style.
var vis: Dictionary = {}
## Colour of the dust (terrain rim).
var dust: Color = Color("#8a7a60")
var _air: Array[CPUParticles2D] = []
var _glow: Sprite2D
var _was_floor: bool = true
var _fall_vy: float = 0.0
var _step_t: float = 0.0
## Game-feel VFX of the room (src/vfx/vfx.gd), made here so it lives and dies with the room.
var vfx: Vfx

static var _dot: Texture2D

## Soft round particle texture (64 px radial gradient), made once.
static func dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_dot = gt
	return _dot

func _ready() -> void:
	for spec: Dictionary in vis.get("particles", []):
		var e := _ambient(spec)
		add_child(e)
		_air.append(e)
	_glow = Sprite2D.new()
	_glow.texture = dot()
	_glow.z_index = Z_GLOW
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.modulate = Color(1.0, 0.79, 0.42, float((vis.get("post", {}) as Dictionary).get("hero_glow", 0.13)))
	add_child(_glow)
	if world:
		vfx = Vfx.new()
		vfx.world = world
		var lay: Dictionary = world.room.layout if world.room else {}
		vfx.style = "base" if bool(lay.get("base", false)) else (String(world.room.look.get("props", "ruins")) if world.room else "ruins")
		add_child(vfx)

func _ambient(spec: Dictionary) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	var kind := String(spec.get("kind", "dust"))
	# «Частицы» setting (vfx.json ambient_levels): fewer or no ambient particles.
	var lv := VfxRules.level_mult(GameSettings.particles_level, Tune.table("vfx"), "ambient_levels")
	e.amount = maxi(1, roundi(int(spec.get("amount", 10)) * lv))
	e.emitting = lv > 0.0
	e.lifetime = float(spec.get("life", 5.0))
	e.preprocess = e.lifetime
	e.local_coords = false
	e.texture = dot()
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var box := BOX
	if bool(spec.get("low", false)):
		box = Vector2(BOX.x, 120.0)
	e.emission_rect_extents = box
	e.set_meta("low", bool(spec.get("low", false)))
	e.direction = Vector2(1, 0)
	e.spread = 180.0
	var v: Array = spec.get("vel", [5, 20])
	e.initial_velocity_min = float(v[0])
	e.initial_velocity_max = float(v[1])
	var g: Array = spec.get("gravity", [0, 0])
	e.gravity = Vector2(float(g[0]), float(g[1]))
	e.set_meta("gx", float(g[0]))
	var s: Array = spec.get("size", [0.05, 0.1])
	e.scale_amount_min = float(s[0])
	e.scale_amount_max = float(s[1])
	var c := Color(String(spec.get("col", "#ffffff")))
	c.a = float(spec.get("alpha", 1.0))
	e.color = c
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	if kind == "firefly":
		# blinking: several bumps of light over the life
		ramp.add_point(0.15, Color(1, 1, 1, 1))
		ramp.add_point(0.3, Color(1, 1, 1, 0.15))
		ramp.add_point(0.5, Color(1, 1, 1, 1))
		ramp.add_point(0.65, Color(1, 1, 1, 0.2))
		ramp.add_point(0.82, Color(1, 1, 1, 0.9))
	else:
		ramp.add_point(0.15, Color(1, 1, 1, 1))
		ramp.add_point(0.8, Color(1, 1, 1, 1))
	e.color_ramp = ramp
	if kind == "leaf":
		e.angle_min = 0.0
		e.angle_max = 360.0
		e.angular_velocity_min = -float(spec.get("spin", 60))
		e.angular_velocity_max = float(spec.get("spin", 60))
	if bool(spec.get("add", false)):
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		e.material = m
		e.z_index = Z_GLOW
	else:
		e.z_index = Z_AIR + (3 if bool(spec.get("front", false)) else 0)
	return e

func _process(dt: float) -> void:
	if world == null:
		return
	var cam := get_viewport().get_camera_2d()
	var cc := cam.get_screen_center_position() if cam else Vector2.ZERO
	for e in _air:
		e.global_position = Vector2(cc.x, (World.floor_at(world, cc) if world.room is LevelRoom else Tune.f("ground_y")) - 40.0) if bool(e.get_meta("low", false)) else cc
	var p := world.player
	if p == null or not is_instance_valid(p):
		_glow.visible = false
		return
	_glow.visible = true
	_glow.global_position = p.global_position - Vector2(0, Player.H * 0.6)
	var r := world.darkness.light_r if world.darkness else 300.0
	_glow.scale = Vector2.ONE * maxf(r, 120.0) * 0.85 / 32.0
	# Landing and running dust.
	var on := p.is_on_floor()
	if not on:
		_fall_vy = maxf(_fall_vy, p.velocity.y)
	elif not _was_floor:
		if _fall_vy >= LAND_VY:
			_puff(p.global_position, 14, 1.0)
		_fall_vy = 0.0
	if on and absf(p.velocity.x) > 150.0:
		_step_t -= dt
		if _step_t <= 0.0:
			_step_t = STEP_TIME
			_puff(p.global_position, 3, 0.5)
	_was_floor = on

## Wind push on the ambient particles (frost gusts, Vfx): extra x gravity, px/s².
func push_air(x: float) -> void:
	for e in _air:
		e.gravity.x = float(e.get_meta("gx", 0.0)) + x

## One-shot dust burst at `at` (feet), `n` particles, size factor `k`.
func _puff(at: Vector2, n: int, k: float) -> void:
	var e := CPUParticles2D.new()
	e.one_shot = true
	e.amount = n
	e.lifetime = 0.45
	e.explosiveness = 0.95
	e.local_coords = false
	e.texture = dot()
	e.direction = Vector2(0, -1)
	e.spread = 80.0
	e.initial_velocity_min = 50.0 * k
	e.initial_velocity_max = 150.0 * k
	e.gravity = Vector2(0, 180)
	e.damping_min = 60.0
	e.damping_max = 120.0
	e.scale_amount_min = 0.22 * k
	e.scale_amount_max = 0.42 * k
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(16, 2)
	e.color = Color(dust, 0.55)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	e.color_ramp = ramp
	e.z_index = Z_AIR
	add_child(e)
	e.global_position = at
	e.emitting = true
	get_tree().create_timer(1.0).timeout.connect(e.queue_free)
