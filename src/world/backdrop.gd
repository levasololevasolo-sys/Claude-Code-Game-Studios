## Background of a combat room (visual-upgrade-plan §2.1, art-bible §6): one
## Parallax2D per layer of assets/data/visuals.json, back to front. A layer with a
## "tex" image shows that image (the slot for painted or 3D-rendered backgrounds,
## e.g. the Blender Топь layers), scaled by "tex_scale" and repeated every
## texture width x tex_scale px, tinted by "tex_mod"; without one, or when the
## file is missing, a BackdropPainter draws the "kind" procedural
## placeholder once (static draw list, not redrawn per frame). Visual only.
##
## Parallax2D places itself at screen_offset × (1 − scroll_scale), where
## screen_offset = camera centre − half the unzoomed viewport (checked in Godot
## 4.7.2). Each layer's holder is shifted so that, with the camera centred at
## CAM_REF above the floor, layer coordinates equal world coordinates: painters
## and images are authored against ground_y like the rest of the room.
class_name Backdrop
extends Node2D

## Width of one repeating tile of every layer, px (also the image width to author).
const TILE: float = 2048.0
## Half of the 1920x1080 base viewport: Parallax2D's screen_offset origin.
const HALF_VIEW: Vector2 = Vector2(960, 540)
## Camera centre height above ground_y when the hero stands on the floor (World.CAM_OFFSET).
const CAM_REF_DY: float = -120.0
## Vertical parallax is softer than horizontal: sy = lerp(scale, 1, Y_SOFT).
const Y_SOFT: float = 0.55

## Floor height the layers were built for (build's `ground`).
var built_ground: float = 0.0
## Per layer: {par: Parallax2D, holder: Node2D, base_y: float, sy: float, scale: float}.
var layer_info: Array = []

## Builds the layers of `vis` (one visuals.json style) for a room whose floor is
## at `ground` and whose highest point is `top`.
func build(vis: Dictionary, ground: float, top: float) -> void:
	z_index = -100
	built_ground = ground
	var fog := Color(String(vis.get("fog", "#3e5878")))
	var layers: Array = vis.get("layers", [])
	for i in layers.size():
		var spec: Dictionary = layers[i]
		var s := float(spec.get("scale", 0.5))
		var par := Parallax2D.new()
		par.scroll_scale = Vector2(s, lerpf(s, 1.0, Y_SOFT))
		par.repeat_size = Vector2(TILE, 0.0)
		par.repeat_times = 3
		par.z_index = i
		var holder := Node2D.new()
		var cref := Vector2(HALF_VIEW.x, ground + CAM_REF_DY)
		holder.position = -(cref - HALF_VIEW) * (Vector2.ONE - par.scroll_scale)
		par.add_child(holder)
		var tex_path := String(spec.get("tex", ""))
		var variants := _existing(spec.get("tex_list", []))
		if not variants.is_empty():
			_variants(par, holder, spec, variants, ground, i)
		elif tex_path != "" and ResourceLoader.exists(tex_path):
			var spr := Sprite2D.new()
			spr.texture = load(tex_path) as Texture2D
			spr.centered = false
			var k := float(spec.get("tex_scale", 1.0))
			spr.scale = Vector2.ONE * k
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			spr.modulate = Color(String(spec.get("tex_mod", "#ffffff")))
			spr.position = Vector2(0.0, ground + float(spec.get("tex_y", -900.0)))
			par.repeat_size = Vector2(spr.texture.get_width() * k, 0.0)
			holder.add_child(spr)
			_caps(holder, spr, spec)
		else:
			var p := BackdropPainter.new()
			p.spec = spec
			p.fog = fog
			p.ground = ground
			p.top = top
			p.layer_seed = i * 101 + 7
			holder.add_child(p)
		add_child(par)
		layer_info.append({ "par": par, "holder": holder, "base_y": holder.position.y, "sy": par.scroll_scale.y, "scale": s })

## Moves every layer as if it had been built for a floor at `g`: the layer's
## content follows the floor by g - built_ground scaled by its vertical scroll,
## so the horizon stays at the floor of the room the camera is in.
func set_ground(g: float) -> void:
	for li: Dictionary in layer_info:
		(li.holder as Node2D).position.y = float(li.base_y) + (g - built_ground) * float(li.sy)

## Adds `node` as an extra layer at scroll `s` drawn at depth `z` (layers at or
## above z move one step forward). Returns its holder's Parallax2D.
func add_layer(node: Node2D, s: float, z: int, ground: float, repeat: float = 0.0) -> Parallax2D:
	for li: Dictionary in layer_info:
		var p: Parallax2D = li.par
		if p.z_index >= z:
			p.z_index += 1
	var par := Parallax2D.new()
	par.scroll_scale = Vector2(s, lerpf(s, 1.0, Y_SOFT))
	par.repeat_size = Vector2(repeat, 0.0)
	par.z_index = z
	var holder := Node2D.new()
	var cref := Vector2(HALF_VIEW.x, ground + CAM_REF_DY)
	holder.position = -(cref - HALF_VIEW) * (Vector2.ONE - par.scroll_scale)
	holder.add_child(node)
	par.add_child(holder)
	add_child(par)
	layer_info.append({ "par": par, "holder": holder, "base_y": holder.position.y, "sy": par.scroll_scale.y, "scale": s })
	return par

## Stretches an image's top rows upward (tex_up px) and its bottom rows downward
## (tex_down px, default 900), so a tall room, a high or a low camera never sees
## the image's edge: sky stays sky above, the ground body goes on below.
func _caps(holder: Node2D, spr: Sprite2D, spec: Dictionary) -> void:
	var tex := spr.texture
	var k := spr.scale.x
	for side in 2:
		var ext := float(spec.get("tex_up", 0.0)) if side == 0 else float(spec.get("tex_down", 900.0))
		if ext <= 0.0:
			continue
		var cap := Sprite2D.new()
		cap.texture = tex
		cap.centered = false
		cap.region_enabled = true
		var ry := 0.0 if side == 0 else float(tex.get_height()) - 2.0
		cap.region_rect = Rect2(0.0, ry, tex.get_width(), 2.0)
		cap.scale = Vector2(k, ext / 2.0)
		cap.texture_filter = spr.texture_filter
		cap.modulate = spr.modulate
		cap.position = spr.position - Vector2(0.0, ext) if side == 0 else spr.position + Vector2(0.0, tex.get_height() * k)
		holder.add_child(cap)

## Paths of `list` that exist as resources.
static func _existing(list: Variant) -> Array:
	var out: Array = []
	if list is Array:
		for p: Variant in list:
			if ResourceLoader.exists(String(p)):
				out.append(String(p))
	return out

## Order of `n` variants along a strip of `count` tiles: seeded, never the same
## image twice in a row (when n > 1). Pure (tested).
static func variant_order(n: int, count: int, seed_i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var prev := -1
	for k in count:
		var v := int(Room._h(k + seed_i * 31, 41) * n) % maxi(n, 1)
		if n > 1 and v == prev:
			v = (v + 1) % n
		out.append(v)
		prev = v
	return out

## A layer made of several painted images (AI art "tex_list"): laid edge to edge
## in a seeded order without repeating one twice in a row, across the strip the
## camera can see over a level of LEVEL_STRIP px, so walking on shows new scenery.
func _variants(par: Parallax2D, holder: Node2D, spec: Dictionary, paths: Array, ground: float, layer_i: int) -> void:
	var k := float(spec.get("tex_scale", 1.0))
	var texs: Array = []
	for p: String in paths:
		texs.append(load(p) as Texture2D)
	var tw := float((texs[0] as Texture2D).get_width()) * k
	var span := strip_width(level_width, par.scroll_scale.x)
	var count := int(ceil(span / tw)) + 1
	par.repeat_size = Vector2(0.0, 0.0)
	var order := variant_order(texs.size(), count, layer_i + 3)
	var x := 0.0
	for j in count:
		var tex: Texture2D = texs[order[j]]
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.scale = Vector2.ONE * k
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spr.modulate = Color(String(spec.get("tex_mod", "#ffffff")))
		spr.position = Vector2(x, ground + float(spec.get("tex_y", -900.0)))
		holder.add_child(spr)
		_caps(holder, spr, spec)
		x += float(tex.get_width()) * k

## Width of a level the layers must cover (set before build; 0 = one room).
var level_width: float = 0.0

## Layer px a camera sweeping a level `w` px wide sees on a layer of scroll `s`
## (layer point = world − cam·(1 − s)). Pure (tested).
static func strip_width(w: float, s: float) -> float:
	return maxf(w - HALF_VIEW.x * 2.0, 0.0) * s + HALF_VIEW.x * 2.0 + 400.0
