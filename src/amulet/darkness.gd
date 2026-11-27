## The darkness layer of a combat room (GDD amulet-and-flare §3.9, F4, F5): one
## world-space rectangle with assets/shaders/darkness.gdshader, drawn above the
## room, enemies and hero (z_index Z) and below the Flare's light (Flare.Z).
## Each tick it sends the shader the hero's light radius (from the amulet charge,
## never below light_min) and the self-lit spots: every enemy's eyes, wind-ups and
## every enemy shot (Enemy.light_spots(), EnemyShot.light_spots()), which stay
## readable through any darkness. Pure maths in AmuletRules.
class_name Darkness
extends Node2D

const Z: int = 50
## Must match MAX_SPOTS in the shader.
const MAX_SPOTS: int = 64
const SHADER_PATH: String = "res://assets/shaders/darkness.gdshader"
## How far past the room edges the rectangle reaches, px (camera limits are inside).
const MARGIN: float = 1600.0

var world: World
## Calm room (base, rest stop): darkness × darkness_calm.
var calm: bool = false
## Base darkness of the location (locations.json "darkness"; < 0 = tuning "darkness").
var base: float = -1.0
## Night tint the darkness multiplies toward (visuals.json dark_tint); alpha 0 =
## the tuning "darkness_color".
var tint: Color = Color(0, 0, 0, 0)
## Ash level "Навь темнее" open (0/1).
var ash_level: int = 0
## Last values sent to the shader (read by checks and the HUD).
var light_r: float = 0.0
var dk: float = 0.0
var spot_count: int = 0
var _mat: ShaderMaterial

func _ready() -> void:
	z_index = Z
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	material = _mat
	var c: Variant = Tune.get_value("darkness_color")
	if c is String:
		_mat.set_shader_parameter("dark_color", Color(String(c)))
	if tint.a > 0.0:
		_mat.set_shader_parameter("dark_color", tint)
	_mat.set_shader_parameter("full_frac", Tune.f("light_full_frac"))
	_mat.set_shader_parameter("mid_frac", Tune.f("light_mid_frac"))
	_mat.set_shader_parameter("mid_level", Tune.f("light_mid_level"))

func _process(_dt: float) -> void:
	if world == null or world.player == null:
		return
	var p := world.player
	var c := p.amulet.charge if p.amulet else 0.0
	light_r = AmuletRules.light_radius(c, Tune.data)
	dk = AmuletRules.darkness(Tune.data, calm, ash_level, world.flash, base)
	if p.flare_t > 0.0:
		dk = minf(Tune.f("darkness_max"), dk + Tune.f("windup_dim"))
	var spots: Array[Vector4] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and not e.dead:
			spots.append_array(e.light_spots())
			var cap := e.light_cap()
			if cap > 0.0:
				light_r = minf(light_r, cap)
				dk = Tune.f("darkness_max")
	for ch in world.get_children():
		if ch is EnemyShot:
			spots.append_array((ch as EnemyShot).light_spots())
	if spots.size() > MAX_SPOTS:
		spots.resize(MAX_SPOTS)
	spot_count = spots.size()
	var arr: Array = []
	arr.resize(MAX_SPOTS)
	for i in MAX_SPOTS:
		arr[i] = spots[i] if i < spots.size() else Vector4.ZERO
	_mat.set_shader_parameter("dk", dk)
	_mat.set_shader_parameter("hero_pos", p.position - Vector2(0, Player.H / 2.0))
	_mat.set_shader_parameter("light_r", light_r)
	_mat.set_shader_parameter("spots", arr)
	_mat.set_shader_parameter("spot_count", spot_count)
	queue_redraw()

func _draw() -> void:
	var w: float = float(world.room.layout.w) if world and world.room else 4000.0
	draw_rect(Rect2(-MARGIN, -MARGIN - 1000.0, w + MARGIN * 2.0, MARGIN * 2.0 + 2000.0), Color.WHITE)
