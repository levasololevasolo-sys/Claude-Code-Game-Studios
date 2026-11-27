## Background of a combat room (visual-upgrade-plan §2.1, art-bible §6): one
## Parallax2D per layer of assets/data/visuals.json, back to front. A layer with a
## "tex" image shows that image tiled every TILE px (the slot for painted or
## 3D-rendered backgrounds); without one a BackdropPainter draws a procedural
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

## Builds the layers of `vis` (one visuals.json style) for a room whose floor is
## at `ground` and whose highest point is `top`.
func build(vis: Dictionary, ground: float, top: float) -> void:
	z_index = -100
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
		if tex_path != "" and ResourceLoader.exists(tex_path):
			var spr := Sprite2D.new()
			spr.texture = load(tex_path) as Texture2D
			spr.centered = false
			spr.position = Vector2(0.0, ground + float(spec.get("tex_y", -900.0)))
			holder.add_child(spr)
		else:
			var p := BackdropPainter.new()
			p.spec = spec
			p.fog = fog
			p.ground = ground
			p.top = top
			p.layer_seed = i * 101 + 7
			holder.add_child(p)
		add_child(par)
