## Look of the room's ground, solid earth and one-way platforms
## (visual-upgrade-plan §2.2, art-bible §6): thick bodies with a darker-down
## gradient, a ragged lighter top rim with drips, a soft shadow under the rim,
## hanging roots / moss / icicles under platforms, and world-space grain from
## assets/shaders/terrain.gdshader. Visual only: Room.build() owns collision and
## this node never changes it (a platform's collider stays 16 px at its top).
class_name TerrainArt
extends Node2D

const SHADER_PATH: String = "res://assets/shaders/terrain.gdshader"
## Visual thickness of a one-way platform, px (plan §2.2: 32-48).
const PLAT_THICK: float = 38.0
## Rim (lit top edge) thickness, px (plan §2.2: 6-10).
const RIM: float = 8.0

var layout: Dictionary = {}
## The "terrain" block of a visuals.json style.
var t: Dictionary = {}
var ground: float = 640.0
## Painted ground tiles (terrain "tiles" = a location of
## assets/art/backgrounds/tiles.json): {top, top_surface, top_size, plat,
## plat_cap, plat_surface, plat_size, top_scale, plat_scale}; empty = the
## procedural rim and platform.
var tiles: Dictionary = {}

const TILES_JSON: String = "res://assets/art/backgrounds/tiles.json"

## The painted tile set of a terrain block (its "tiles" location name), with the
## textures loaded; {} when unset or the files are missing.
static func tile_set(terrain: Dictionary) -> Dictionary:
	var loc := String(terrain.get("tiles", ""))
	if loc == "" or not FileAccess.file_exists(TILES_JSON):
		return {}
	var all: Variant = JSON.parse_string(FileAccess.get_file_as_string(TILES_JSON))
	if not (all is Dictionary) or not (all as Dictionary).has(loc):
		return {}
	var m: Dictionary = (all as Dictionary)[loc]
	var dir := "res://assets/art/backgrounds/%s/" % loc
	if not ResourceLoader.exists(dir + "top.webp") or not ResourceLoader.exists(dir + "plat.webp"):
		return {}
	return {
		"top": load(dir + "top.webp") as Texture2D, "top_surface": float(m.get("top_surface", 0)),
		"plat": load(dir + "plat.webp") as Texture2D, "plat_cap": float(m.get("plat_cap", 0)),
		"plat_surface": float(m.get("plat_surface", 0)),
		"top_scale": float(terrain.get("tiles_top_scale", 0.6)), "plat_scale": float(terrain.get("tiles_plat_scale", 0.5)),
	}

func _ready() -> void:
	z_index = -1
	if tiles.is_empty():
		tiles = tile_set(t)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH) as Shader
	m.set_shader_parameter("grain", float(t.get("grain", 0.2)) * (0.25 if not tiles.is_empty() else 1.0))
	m.set_shader_parameter("streak", float(t.get("streak", 0.3)))
	material = m

func _c(key: String, def: String) -> Color:
	return Color(String(t.get(key, def)))

func _h(i: int, salt: int) -> float:
	return Room._h(i, salt)

func _draw() -> void:
	var w: float = float(layout.get("w", 2000.0))
	_body(Rect2(-200.0, ground, w + 400.0, 420.0), _c("body", "#2c2530"), _c("body_bottom", "#120f18"), 260.0)
	_rim(-200.0, w + 200.0, ground, 1)
	for r: Rect2 in layout.get("solids", []):
		_body(r, _c("solid", "#3a2e30"), _c("body_bottom", "#120f18"), r.size.y)
		# darker sides so columns read as volume
		draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(r.end.x - 5.0, r.position.y, 5.0, r.size.y), Color(0, 0, 0, 0.35))
		_rim(r.position.x - 3.0, r.end.x + 3.0, r.position.y, int(r.position.x))
	var k := 0
	for p: Vector3 in layout.get("plats", []):
		_plat(p, k)
		k += 1

## Body: vertical gradient from `top_c` to `bot_c` over `fade` px.
func _body(r: Rect2, top_c: Color, bot_c: Color, fade: float) -> void:
	var mid_y := minf(r.position.y + fade, r.end.y)
	var mid_c := top_c.lerp(bot_c, clampf(fade / maxf(fade, 1.0), 0.0, 1.0))
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, mid_y), Vector2(r.position.x, mid_y)]),
		PackedColorArray([top_c, top_c, mid_c, mid_c]))
	if mid_y < r.end.y:
		draw_rect(Rect2(r.position.x, mid_y, r.size.x, r.end.y - mid_y), bot_c)

## Ragged lit rim along [x0, x1] at height y: a shadow band under it, the rim
## body, a thin highlight on top, and drips hanging down.
func _rim(x0: float, x1: float, y: float, s: int) -> void:
	if not tiles.is_empty():
		_rim_tex(x0, x1, y)
		return
	var rim := _c("rim", "#5f6b3c")
	var light := _c("rim_light", "#8a9a52")
	var step := 12.0
	var n := maxi(2, ceili((x1 - x0) / step))
	var topl := PackedVector2Array()
	var botl := PackedVector2Array()
	for i in n + 1:
		var x := minf(x0 + i * step, x1)
		topl.append(Vector2(x, y - 1.0 - _h(i + s, 1) * 3.0))
		botl.append(Vector2(x, y + RIM + _h(i + s, 2) * 4.0))
	# shadow under the rim
	var sh := PackedVector2Array([Vector2(x0, y + RIM), Vector2(x1, y + RIM), Vector2(x1, y + RIM + 22.0), Vector2(x0, y + RIM + 22.0)])
	draw_polygon(sh, PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	var poly := topl.duplicate()
	var rb := botl.duplicate()
	rb.reverse()
	poly.append_array(rb)
	draw_colored_polygon(poly, rim)
	draw_polyline(topl, light, 2.0)
	# drips of moss / snow
	for i in n:
		if _h(i + s, 3) < 0.13:
			var dx := botl[i].x + _h(i + s, 8) * 10.0
			var dl := 3.0 + pow(_h(i + s, 4), 2.0) * 16.0
			var dw := 2.5 + _h(i + s, 9) * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(dx - dw, botl[i].y - 2.0), Vector2(dx + 0.5, botl[i].y + dl), Vector2(dx + dw, botl[i].y - 2.0)]), rim)

## A one-way platform: tapered thick body, rim on top, things hanging under it.
func _plat(p: Vector3, k: int) -> void:
	if not tiles.is_empty():
		_plat_tex(p)
		return
	var x0 := p.x
	var x1 := p.x + p.z
	var y := p.y
	var top_c := _c("plat", "#5a4a3a")
	var bot_c := _c("plat_bottom", "#2a2028")
	var th := PLAT_THICK
	var pts := PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1 - 4.0, y + th * 0.55), Vector2(x1 - 14.0, y + th * 0.9),
		Vector2((x0 + x1) * 0.5, y + th), Vector2(x0 + 14.0, y + th * 0.9), Vector2(x0 + 4.0, y + th * 0.55)])
	var cols := PackedColorArray([top_c, top_c, top_c.lerp(bot_c, 0.5), bot_c, bot_c, bot_c, top_c.lerp(bot_c, 0.5)])
	draw_polygon(pts, cols)
	var hang := _c("hang", "#3a4a2c")
	var ice := bool(t.get("icicles", false))
	var n := int(p.z / 34.0)
	for i in n:
		var hx := x0 + 18.0 + i * 34.0 + _h(k * 31 + i, 5) * 12.0
		if hx > x1 - 14.0:
			break
		var hy := y + th * 0.8
		var hl := (10.0 + _h(k * 31 + i, 6) * 26.0) * (0.6 if ice else 1.0)
		if _h(k * 31 + i, 7) < (0.7 if ice else 0.45):
			var sway := 0.0 if ice else (_h(i, k) - 0.5) * 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(hx - 3.0, hy - 4.0), Vector2(hx + sway, hy + hl), Vector2(hx + 3.0, hy - 4.0)]), Color(hang, 0.9))
	_rim(x0 - 2.0, x1 + 2.0, y, k * 17 + 3)

## Painted rim: the location's top.webp tiled along [x0, x1], its surface line
## on y (the art's grass / snow hangs over the edge of the earth below).
func _rim_tex(x0: float, x1: float, y: float) -> void:
	var tex: Texture2D = tiles.top
	var sc: float = tiles.top_scale
	var w := (x1 - x0) / sc
	draw_set_transform(Vector2(x0, y - float(tiles.top_surface) * sc), 0.0, Vector2(sc, sc))
	# texture x follows world x so neighbouring rims line up
	var off := fposmod(x0 / sc, float(tex.get_width()))
	draw_texture_rect_region(tex, Rect2(0, 0, w, tex.get_height()), Rect2(off, 0, w, tex.get_height()))
	draw_set_transform(Vector2.ZERO)

## Painted one-way platform: plat.webp's left cap, its middle repeated, its right
## cap, scaled so the plank top sits on the collider's top (p.y).
func _plat_tex(p: Vector3) -> void:
	var tex: Texture2D = tiles.plat
	var sc: float = tiles.plat_scale
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var cap: float = tiles.plat_cap
	var w := p.z / sc
	var c := minf(cap, w * 0.5)
	draw_set_transform(Vector2(p.x, p.y - float(tiles.plat_surface) * sc), 0.0, Vector2(sc, sc))
	draw_texture_rect_region(tex, Rect2(0, 0, c, th), Rect2(0, 0, c, th))
	draw_texture_rect_region(tex, Rect2(w - c, 0, c, th), Rect2(tw - c, 0, c, th))
	var mid := tw - 2.0 * cap
	var x := c
	while x < w - c - 0.5:
		var seg := minf(mid, w - c - x)
		draw_texture_rect_region(tex, Rect2(x, 0, seg, th), Rect2(cap, 0, seg, th))
		x += seg
	draw_set_transform(Vector2.ZERO)
