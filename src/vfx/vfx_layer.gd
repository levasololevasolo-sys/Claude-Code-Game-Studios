## Draws one VfxPool in a single canvas item (vfx-spec §2): no node per
## particle. `additive` layers sit above the darkness and glow; the plain layer
## sits under it, so blood and mist are shaded by the night like the actors.
## Culls to the camera view.
class_name VfxLayer
extends Node2D

## Pool to draw; owned by Vfx.
var pool: VfxPool
## Soft round texture for mist, flash and embers (Atmosphere.dot()).
var soft: Texture2D
var _view: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

## Sets the world rect to draw (camera view plus a margin).
func set_view(r: Rect2) -> void:
	_view = r

func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_pool()
	Vfx.cost_us += Time.get_ticks_usec() - t0

func _draw_pool() -> void:
	if pool == null or pool.alive() <= 0:
		return
	var P := VfxPool.Shape
	for i in pool.cap:
		if pool.life[i] <= 0.0:
			continue
		var p := pool.pos[i]
		if not _view.has_point(p):
			continue
		var k := pool.age(i)
		var c := pool.col[i].lerp(pool.col_end[i], k)
		var s := pool.size[i] * lerpf(1.0, pool.size_end[i], k)
		match pool.shape[i]:
			P.DROP:
				var v := pool.vel[i]
				var tail := v * 0.018
				if tail.length() > s * 0.6:
					draw_line(p - tail, p, c, s, false)
				draw_circle(p, s * 0.55, c)
			P.STREAK:
				var tl := pool.vel[i] * pool.lenk[i]
				draw_line(p - tl, p, Color(c, c.a * 0.55), s * 1.6, false)
				draw_line(p - tl * 0.6, p, c, s, false)
			P.SHARD:
				var a := pool.rot[i]
				var asp := pool.lenk[i]
				var fx := Vector2(cos(a), sin(a)) * s * asp
				var fy := Vector2(-sin(a), cos(a)) * s * 0.6
				draw_colored_polygon(PackedVector2Array([p + fx, p + fy, p - fx, p - fy * 0.5]), c)
			P.MIST, P.FLASH, P.EMBER:
				var fade := 1.0 - k if pool.shape[i] != P.MIST else sin(k * PI)
				draw_texture_rect(soft, Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(c, c.a * fade))
				if pool.shape[i] == P.EMBER:
					draw_circle(p, maxf(s * 0.35, 0.8), Color(c, c.a * fade))
			P.RING:
				draw_arc(p, s, 0.0, TAU, 40, Color(c, c.a * (1.0 - k)), maxf(1.0, 5.0 * (1.0 - k)), false)
			P.SPLAT:
				var al := c.a * (1.0 - k * k)
				draw_set_transform(p, 0.0, Vector2(1.0, 0.28))
				draw_circle(Vector2.ZERO, s, Color(c, al))
				draw_circle(Vector2(s * 0.9, 0.0), s * 0.35, Color(c, al))
				draw_set_transform(Vector2.ZERO)
			P.RIPPLE:
				draw_set_transform(p, 0.0, Vector2(1.0, 0.25))
				draw_arc(Vector2.ZERO, s, 0.0, TAU, 28, Color(c, c.a * (1.0 - k)), 3.0, false)
				draw_set_transform(Vector2.ZERO)
