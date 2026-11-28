## Backgrounds of a graph level (the developer, 28.11: the background must change
## as the hero walks on, and underground rooms need their own look in every
## location). Built by LevelRoom from assets/data/level_backdrop.json (one block
## per visuals.json style: ruins = Топь, forest = Лес, frost = Мороз):
## - the surface Backdrop (visuals.json layers) with a non-repeating landmark
##   layer (LandmarkPainter) laid across the whole level, so walking on passes
##   huts, idols, towers and bridges that never come back;
## - the horizon follows the floor of the surface room the camera is over
##   (smoothly, anchor_tween s) instead of staying at the entry's height;
## - the far layers drift toward progress_tint as the hero nears the level's end;
## - underground rooms get the cave_backdrop shader (far wall with parallax,
##   stones, stalactites, roots, glowing dots, Navi cracks in the deep band),
##   optional seamless art in cave_tex.
## Visual only.
class_name LevelBackdrop
extends Node2D

const CAVE_SHADER: String = "res://assets/shaders/cave_backdrop.gdshader"

var lr: LevelRoom
## The level_backdrop.json block of this location's style.
var spec: Dictionary = {}
var backdrop: Backdrop
var cave: Node2D
var _cave_mat: ShaderMaterial
var _ground: float = 0.0
## Per surface room column span: [{x0, x1, y_top, y_bot, ground}] (world px).
var _surf: Array = []
var _tinted: Array = []

## The level_backdrop.json block for a visuals.json style key ({} when absent).
static func spec_for(style: String) -> Dictionary:
	var t := Tune.table("level_backdrop")
	return t.get(style, t.get("ruins", {}))

## Builds everything for LevelRoom `l` with the visuals.json style `vis`.
func build(l: LevelRoom, vis: Dictionary, s: Dictionary) -> void:
	lr = l
	spec = s
	_surf = surface_grounds(lr.level, lr.layout.get("surfaces", []), lr.mw, lr.mh, lr.cell)
	var entry: Dictionary = lr.level.rooms[int(lr.level.entry)]
	var g0 := (float(entry.y) * lr.mh + lr.mh - 1) * lr.cell
	_ground = ground_at(_surf, (float(entry.x) + 0.5) * lr.mw * lr.cell, g0, g0)
	backdrop = Backdrop.new()
	backdrop.level_width = lr.cols * lr.cell
	add_child(backdrop)
	backdrop.build(vis, _ground, _ground - 1200.0)
	_add_landmarks(vis)
	for li: Dictionary in backdrop.layer_info:
		if float(li.scale) <= 0.4:
			_tinted.append(li.par)
	_build_cave()

func _col(key: String, def: String) -> Color:
	return Color(String(spec.get(key, def)))

func _add_landmarks(vis: Dictionary) -> void:
	var kinds: Array = spec.get("landmarks", [])
	if kinds.is_empty():
		return
	var s := float(spec.get("landmark_scale", 0.45))
	var lp := LandmarkPainter.new()
	lp.kinds = kinds
	lp.every = float(spec.get("landmark_every", 1700.0))
	lp.width = Backdrop.strip_width(backdrop.level_width, s)
	lp.ground = _ground
	var fog := Color(String(vis.get("fog", "#3e5878")))
	lp.col = _col("landmark_col", "#16241d").lerp(fog, float(spec.get("landmark_fog", 0.3)))
	lp.glow = _col("glow", "#8fe36b")
	lp.halo = Color(fog.lightened(0.25), float(spec.get("landmark_halo", 0.22)))
	lp.seed_i = int(lr.level.get("seed", 1)) % 100000 + 17
	# In front of every layer slower than the landmarks.
	var z := 0
	for li: Dictionary in backdrop.layer_info:
		if float(li.scale) <= s:
			z = maxi(z, (li.par as Parallax2D).z_index + 1)
	backdrop.add_layer(lp, s, z, _ground)

## Floor of each surface (band 0) room: the lowest standing surface inside it,
## else its top module's bottom row. Pure (tested).
static func surface_grounds(level: Dictionary, surfaces: Array, mw: int, mh: int, cell: float) -> Array:
	var out: Array = []
	for r: Dictionary in level.get("rooms", []):
		if int(r.get("band", 0)) != 0:
			continue
		var rect := Rect2(float(r.x) * mw * cell, float(r.y) * mh * cell, float(r.w) * mw * cell, float(r.h) * mh * cell)
		var g := -INF
		for sf: Vector3 in surfaces:
			var mid := (sf.x + sf.y) * 0.5
			if mid >= rect.position.x and mid < rect.end.x and sf.z > rect.position.y and sf.z <= rect.end.y:
				g = maxf(g, sf.z)
		if g == -INF:
			g = (float(r.y) * mh + mh - 1) * cell
		out.append({ "x0": rect.position.x, "x1": rect.end.x, "y0": rect.position.y, "y1": rect.end.y, "ground": g })
	return out

## Horizon height for a camera at x `x`, height `y`: the floor of the surface
## room over that column nearest to `y`; `keep` when no surface room is there.
## Pure (tested).
static func ground_at(surf: Array, x: float, y: float, keep: float) -> float:
	var best := keep
	var best_d := INF
	for s: Dictionary in surf:
		if x < float(s.x0) or x >= float(s.x1):
			continue
		var d := 0.0 if (y >= float(s.y0) and y < float(s.y1)) else minf(absf(y - float(s.y0)), absf(y - float(s.y1)))
		if d < best_d:
			best_d = d
			best = float(s.ground)
	return best

## Room grid texture for the cave shader: one texel per module, r = depth band,
## g = room top y (px), b = room id, a = 1 inside a room.
static func room_image(level: Dictionary, gw: int, gh: int, mh: int, cell: float) -> Image:
	var img := Image.create(maxi(gw, 1), maxi(gh, 1), false, Image.FORMAT_RGBAF)
	img.fill(Color(0, 0, 0, 0))
	for r: Dictionary in level.get("rooms", []):
		for y in range(int(r.y), int(r.y) + int(r.h)):
			for x in range(int(r.x), int(r.x) + int(r.w)):
				if x >= 0 and y >= 0 and x < gw and y < gh:
					img.set_pixel(x, y, Color(float(int(r.get("band", 0))), float(r.y) * mh * cell, float(int(r.get("i", 0))) * 0.37, 1.0))
	return img

func _build_cave() -> void:
	var gw := ceili(float(lr.cols) / lr.mw)
	var gh := ceili(float(lr.rows) / lr.mh)
	var img := room_image(lr.level, gw, gh, lr.mh, lr.cell)
	cave = CaveRect.new()
	cave.size = Vector2(lr.cols * lr.cell, lr.rows * lr.cell)
	cave.z_index = -80
	_cave_mat = ShaderMaterial.new()
	_cave_mat.shader = load(CAVE_SHADER) as Shader
	_cave_mat.set_shader_parameter("rooms", ImageTexture.create_from_image(img))
	_cave_mat.set_shader_parameter("grid_size", Vector2(gw, gh))
	_cave_mat.set_shader_parameter("module_px", Vector2(lr.mw * lr.cell, lr.mh * lr.cell))
	for k: String in ["cave_back", "cave_rock", "cave_far", "glow", "crack", "roots"]:
		if spec.has(k):
			_cave_mat.set_shader_parameter(k, _col(k, "#000000"))
	_cave_mat.set_shader_parameter("glow_density", float(spec.get("glow_density", 0.1)))
	var tex_path := String(spec.get("cave_tex", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_cave_mat.set_shader_parameter("use_tex", true)
		_cave_mat.set_shader_parameter("cave_tex", load(tex_path) as Texture2D)
		_cave_mat.set_shader_parameter("tex_scale", float(spec.get("cave_tex_scale", 1.0)))
	cave.material = _cave_mat
	add_child(cave)

## Share of the level behind the camera at x `x` (0 at the start, 1 at the end).
static func progress(x: float, level_w: float) -> float:
	return clampf((x - 960.0) / maxf(level_w - 1920.0, 1.0), 0.0, 1.0)

func _process(delta: float) -> void:
	var c := get_viewport().get_camera_2d()
	if c == null or lr == null:
		return
	var at := c.get_screen_center_position()
	_cave_mat.set_shader_parameter("cam", at)
	var target := ground_at(_surf, at.x, at.y, _ground)
	var tw := maxf(float(spec.get("anchor_tween", 0.6)), 0.01)
	_ground = lerpf(_ground, target, 1.0 - exp(-delta * 3.0 / tw))
	if absf(_ground - target) < 0.5:
		_ground = target
	backdrop.set_ground(_ground)
	var p := progress(at.x, backdrop.level_width) * float(spec.get("progress_k", 0.45))
	var tint := Color.WHITE.lerp(_col("progress_tint", "#ffffff").lightened(0.45), p)
	for par: Parallax2D in _tinted:
		par.modulate = tint

## A plain rect for the cave shader to draw on (world coordinates = VERTEX).
class CaveRect:
	extends Node2D
	var size: Vector2 = Vector2.ZERO
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
