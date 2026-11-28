## Flickering lights of a location (vfx-spec §4.4): a rotten-wood glow stump in
## the swamp, votive candles on a post in the forest, a pitch torch in the
## frost. Wooden Rus only (art-bible §6). The flame and a soft additive halo
## flicker by two sines; light_spots() lets the darkness shader open a lit
## spot around each one (group "vfx_lights"). Visual only.
class_name VfxLamps
extends Node2D

const GROUP: StringName = &"vfx_lights"
const SPAWN_CLEAR: float = 320.0

## The "lamps" block of a vfx.json world style.
var spec: Dictionary = {}
var view: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)
## Lamp feet positions.
var at: Array[Vector2] = []
var _t: float = 0.0
var _glow: Node2D

func _ready() -> void:
	z_index = -1
	add_to_group(GROUP)
	_glow = Node2D.new()
	_glow.z_index = 56
	_glow.z_as_relative = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.draw.connect(_draw_glow)
	add_child(_glow)

## Places lamps on the ground every `every` px (hash jitter), not on solids,
## not at the hero spawn and not at the room's far edge.
func build(layout: Dictionary, ground: float) -> void:
	if layout.has("surfaces"):
		_build_on_surfaces(layout.surfaces)
		return
	var w := float(layout.get("w", 2000.0))
	var every := float(spec.get("every", 1000.0))
	var cx := SPAWN_CLEAR + every * 0.4
	var k := 0
	while cx < w - 200.0:
		k += 1
		var px := cx + (Room._h(k, 31) - 0.5) * every * 0.4
		var free := true
		for r: Rect2 in layout.get("solids", []):
			if r.end.y >= ground - 1.0 and px > r.position.x - 30.0 and px < r.end.x + 30.0:
				free = false
		if free:
			at.append(Vector2(px, ground))
		cx += every

## A whole level (LevelRoom): lamps only on open floor tops at least 160 px
## wide, about one per `every` px of floor, never near the hero spawn.
func _build_on_surfaces(surfaces: Array) -> void:
	var every := float(spec.get("every", 1000.0))
	var walked := every * 0.6
	var k := 0
	for sf: Vector3 in surfaces:
		var span := sf.y - sf.x
		if span < 160.0:
			continue
		walked += span
		if walked >= every:
			walked = 0.0
			k += 1
			var px := lerpf(sf.x + 60.0, sf.y - 60.0, Room._h(k, 31))
			if px > SPAWN_CLEAR:
				at.append(Vector2(px, sf.z))

## Flicker factor of lamp i at time t, around 1.
func flick(i: int) -> float:
	var f := float(spec.get("flicker", 0.25))
	return 1.0 + f * (0.6 * sin(_t * 13.0 + i * 1.7) + 0.4 * sin(_t * 7.3 + i * 3.1)) * 0.5

## Light spots for the darkness: Vector4(x, y, radius, strength).
func light_spots() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for i in at.size():
		var f := _flame(i)
		out.append(Vector4(f.x, f.y, float(spec.get("light", 120.0)) * flick(i), float(spec.get("light_a", 0.8))))
	return out

func _flame(i: int) -> Vector2:
	return at[i] - Vector2(0, float(spec.get("post_h", 60.0)) + 8.0)

func _process(dt: float) -> void:
	var fx := get_parent() as Vfx
	if fx and fx.fixed_dt > 0.0:
		dt = fx.fixed_dt
	_t += dt
	queue_redraw()
	_glow.queue_redraw()

func _draw() -> void:
	var post := Color(String(spec.get("post", "#2a221c")))
	var ph := float(spec.get("post_h", 60.0))
	var kind := String(spec.get("kind", "candle"))
	var col := Color(String(spec.get("col", "#ff9a3c")))
	var core := Color(String(spec.get("core", "#ffe8b0")))
	for i in at.size():
		var p := at[i]
		if not view.has_point(p):
			continue
		var f := flick(i)
		match kind:
			"rotlight":
				# A rotten stump with glowing fungus caps (гнилушки).
				draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 0), p + Vector2(-11, -ph), p + Vector2(-3, -ph - 6), p + Vector2(9, -ph + 2), p + Vector2(15, 0)]), post)
				for j in 4:
					var q := p + Vector2(-9 + j * 6, -ph * (0.3 + 0.17 * j))
					draw_circle(q, 3.0 + j % 2, col.lerp(core, 0.3 * f))
			"torch":
				draw_rect(Rect2(p.x - 3, p.y - ph, 6, ph), post)
				draw_rect(Rect2(p.x - 6, p.y - ph - 4, 12, 9), post.darkened(0.3))
				_flame_shape(p - Vector2(0, ph + 4), 9.0, 22.0 * f, col, core, i)
			_:
				# Votive post with a little shelf and three candles.
				draw_rect(Rect2(p.x - 4, p.y - ph, 8, ph), post)
				draw_rect(Rect2(p.x - 15, p.y - ph, 30, 5), post.lightened(0.1))
				for j in 3:
					var cxp := p.x - 9 + j * 9
					var chh := 9.0 + (j % 2) * 4.0
					draw_rect(Rect2(cxp - 2, p.y - ph - chh, 4, chh), Color("#d8ccb0"))
					_flame_shape(Vector2(cxp, p.y - ph - chh), 3.0, 8.0 * (f + 0.1 * sin(_t * 17.0 + j)), col, core, i + j)

func _flame_shape(base: Vector2, w: float, hgt: float, col: Color, core: Color, i: int) -> void:
	var sway := sin(_t * 9.0 + i) * w * 0.3
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(sway, -hgt), base + Vector2(w, 0), base + Vector2(0, w * 0.5)]), col)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.45, 0), base + Vector2(sway * 0.6, -hgt * 0.55), base + Vector2(w * 0.45, 0)]), core)

func _draw_glow() -> void:
	var col := Color(String(spec.get("col", "#ff9a3c")))
	var g := float(spec.get("glow", 90.0))
	var tex := Atmosphere.dot()
	for i in at.size():
		var p := _flame(i)
		if not view.has_point(p):
			continue
		var r := g * flick(i)
		_glow.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, 0.32))
		_glow.draw_texture_rect(tex, Rect2(p - Vector2(r, r) * 0.3, Vector2(r, r) * 0.6), false, Color(col, 0.5))
