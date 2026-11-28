## Procedural placeholder for one Backdrop layer (visual-upgrade-plan §2.1): sky,
## far hills with the broken Kalinov bridge, spruce / dead-tree / ice-spire
## silhouettes, fog bands, light shafts, swamp water and near trunks. Everything
## is drawn inside one tile [0, Backdrop.TILE) and wrapped, so Parallax2D's repeat
## is seamless. Colours fade toward the fog colour by spec.fog (atmospheric
## perspective). Drawn once; shaders animate fog, shafts and water.
class_name BackdropPainter
extends Node2D

const FOG_SHADER: String = "res://assets/shaders/fog_band.gdshader"
const SHAFT_SHADER: String = "res://assets/shaders/light_shaft.gdshader"
const WATER_SHADER: String = "res://assets/shaders/water_band.gdshader"

var spec: Dictionary = {}
var fog: Color = Color.GRAY
var ground: float = 640.0
var top: float = 0.0
var layer_seed: int = 1

func _ready() -> void:
	var kind := String(spec.get("kind", ""))
	var path := FOG_SHADER if kind == "fog" else (SHAFT_SHADER if kind == "rays" else (WATER_SHADER if kind == "water" else ""))
	if path != "":
		var m := ShaderMaterial.new()
		m.shader = load(path) as Shader
		if kind == "water":
			m.set_shader_parameter("glint", _col("glint", "#7d9a7f"))
		material = m

func _col(key: String, def: String) -> Color:
	return Color(String(spec.get(key, def)))

## Layer colour after atmospheric perspective.
func _tone() -> Color:
	return _col("col", "#1b2a44").lerp(fog, float(spec.get("fog", 0.0)))

func _h(i: int, salt: int) -> float:
	return Room._h(i + layer_seed * 977, salt)

func _draw() -> void:
	match String(spec.get("kind", "")):
		"sky": _sky()
		"hills": _hills()
		"spruce", "dead", "spires": _silhouettes()
		"fog": _fog()
		"rays": _rays()
		"water": _water()
		"trunks": _trunks()

## Draws `pts` three times (tile, tile left, tile right) so shapes crossing a
## tile edge wrap.
func _poly(pts: PackedVector2Array, c: Color) -> void:
	for k: int in [-1, 0, 1]:
		var o := Vector2(Backdrop.TILE * k, 0.0)
		var q := PackedVector2Array()
		for v in pts:
			q.append(v + o)
		draw_colored_polygon(q, c)

func _grad_rect(r: Rect2, c_top: Color, c_bot: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c_top, c_top, c_bot, c_bot]))

func _sky() -> void:
	var t := Backdrop.TILE
	var ct := _col("top", "#1e2e48")
	var cb := _col("bottom", "#2e4466")
	var hz := ground - 60.0
	draw_rect(Rect2(-t, -6000.0, t * 3.0, hz - 1000.0 + 6000.0), ct)
	_grad_rect(Rect2(-t, hz - 1000.0, t * 3.0, 1000.0), ct, cb)
	draw_rect(Rect2(-t, hz, t * 3.0, 1400.0), cb)
	for i in int(spec.get("stars", 0)):
		var p := Vector2(_h(i, 1) * t, hz - 380.0 - _h(i, 2) * 700.0)
		var a := 0.25 + 0.55 * _h(i, 3)
		draw_circle(p, 0.8 + _h(i, 4) * 1.4, Color(0.85, 0.9, 1.0, a))
	if bool(spec.get("moon", false)):
		var m := Vector2(t * 0.62, hz - 620.0)
		for k in 6:
			draw_circle(m, 70.0 + k * 34.0, Color(cb.lightened(0.35), 0.06))
		draw_circle(m, 46.0, Color("#d8e2f0"))
		draw_circle(m + Vector2(14, -8), 40.0, Color("#c4d0e2"))
	if bool(spec.get("sun", false)):
		var sp := Vector2(t * 0.6, hz - 520.0)
		for k in 7:
			draw_circle(sp, 60.0 + k * 40.0, Color(1, 1, 1, 0.07))
		draw_circle(sp, 54.0, Color(1, 1, 1, 0.85))

func _hills() -> void:
	var t := Backdrop.TILE
	var c := _tone()
	var pts := PackedVector2Array([Vector2(0, ground + 900.0)])
	var n := 48
	for i in n + 1:
		var x := t * i / n
		var u := TAU * i / n
		var y := ground - 140.0 - 70.0 * sin(u * 2.0 + 0.7) - 40.0 * sin(u * 5.0 + 1.3) - 16.0 * sin(u * 11.0)
		pts.append(Vector2(x, y))
	pts.append(Vector2(t, ground + 900.0))
	draw_colored_polygon(pts, c)
	if bool(spec.get("snow", false)):
		for i in n:
			var a := pts[i + 1]
			var b := pts[i + 2]
			draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 8), a + Vector2(0, 8)]), c.lightened(0.25))
	if bool(spec.get("bridge", false)):
		# The broken Kalinov bridge (art-bible §6): arches that stop mid-air.
		var bc := c.darkened(0.12)
		var bx := t * 0.28
		var deck := ground - 300.0
		draw_rect(Rect2(bx, deck, 520.0, 14.0), bc)
		for k in 4:
			var ax := bx + 40.0 + k * 130.0
			draw_rect(Rect2(ax, deck, 16.0, 300.0), bc)
			draw_arc(Vector2(ax + 65.0, deck + 70.0), 58.0, PI, TAU, 16, bc, 8.0)
		draw_colored_polygon(PackedVector2Array([Vector2(bx + 520, deck), Vector2(bx + 590, deck - 22), Vector2(bx + 560, deck + 14), Vector2(bx + 520, deck + 14)]), bc)

func _silhouettes() -> void:
	var t := Backdrop.TILE
	var c := _tone()
	var gap := float(spec.get("gap", 120.0))
	var hr: Array = spec.get("h", [300, 600])
	var n := int(t / gap)
	var snow := String(spec.get("snow", ""))
	for i in n:
		var x := (i + _h(i, 5) * 0.8) * t / n
		var h := lerpf(float(hr[0]), float(hr[1]), _h(i, 6))
		var w := h * (0.2 + _h(i, 7) * 0.08)
		match String(spec.get("kind", "")):
			"spruce":
				_spruce(Vector2(x, ground + 40.0), h, w, c, i, snow)
			"dead":
				_dead_tree(Vector2(x, ground + 40.0), h, c, i)
			"spires":
				var lean := (_h(i, 8) - 0.5) * w * 0.6
				_poly(PackedVector2Array([Vector2(x - w * 0.6, ground + 40.0), Vector2(x - w * 0.15, ground - h * 0.6),
					Vector2(x + lean, ground - h), Vector2(x + w * 0.2, ground - h * 0.55), Vector2(x + w * 0.55, ground + 40.0)]), c)
				_poly(PackedVector2Array([Vector2(x + lean, ground - h), Vector2(x + w * 0.2, ground - h * 0.55), Vector2(x + w * 0.05, ground - h * 0.3)]), c.lightened(0.18))
	if bool(spec.get("reeds", false)):
		for i in int(t / 22.0):
			var rx := i * 22.0 + _h(i, 30) * 14.0
			var rh := 30.0 + _h(i, 31) * 70.0
			_poly(PackedVector2Array([Vector2(rx - 2, ground + 10), Vector2(rx + (_h(i, 32) - 0.5) * 16.0, ground - rh), Vector2(rx + 2, ground + 10)]), c)
	# Ground mass under the row, so it does not float.
	draw_rect(Rect2(-t, ground + 20.0, t * 3.0, 900.0), c)
	var eyes := String(spec.get("eyes", ""))
	if eyes != "":
		# Hollows with one watching eye (story-bible §2.2: the forest watches).
		var ec := Color(eyes)
		for i in n:
			if _h(i, 40) < 0.35:
				var x := (i + _h(i, 5) * 0.8) * t / n
				var y := ground - 140.0 - _h(i, 41) * 200.0
				for k: int in [-1, 0, 1]:
					var p := Vector2(x + Backdrop.TILE * k, y)
					draw_circle(p, 12.0, Color(ec, 0.12))
					draw_circle(p, 4.0, Color(ec, 0.85))

## A spruce: a thin trunk and 6-9 drooping tiers (one triangle each, so no
## polygon can self-intersect), widest at the bottom; optional snow on each tier.
func _spruce(base: Vector2, h: float, w: float, c: Color, i: int, snow: String) -> void:
	if bool(spec.get("trunk", false)):
		_poly(PackedVector2Array([base + Vector2(-w * 0.07, 0), base + Vector2(-w * 0.03, -h), base + Vector2(w * 0.03, -h), base + Vector2(w * 0.07, 0)]), c.darkened(0.15))
	var tiers := 6 + int(_h(i, 9) * 4.0)
	var sc := Color(snow).lerp(fog, float(spec.get("fog", 0.0)) * 0.5) if snow != "" else Color.WHITE
	for k in tiers:
		var f := float(k + 1) / tiers
		var y := base.y - h * 0.12 - (h * 0.88) * (1.0 - f)
		var ww := w * (0.18 + 0.82 * f) * (0.85 + _h(i * 13 + k, 11) * 0.3)
		var th := h * 0.2 + h * 0.06 * (1.0 - f)
		var cx := base.x + (_h(i * 7 + k, 12) - 0.5) * 6.0
		var droop := 6.0 + _h(k, i) * 8.0
		var tri := PackedVector2Array([Vector2(cx, y - th), Vector2(cx + ww, y + droop), Vector2(cx - ww * (0.9 + _h(i, k) * 0.2), y + droop * 0.7)])
		_poly(tri, c)
		if snow != "":
			_poly(PackedVector2Array([Vector2(cx, y - th), Vector2(cx + ww * 0.55, y - th * 0.35), Vector2(cx + ww * 0.1, y - th * 0.45), Vector2(cx - ww * 0.5, y - th * 0.4)]), sc)

## A dead swamp tree: leaning trunk and 2-4 crooked bare branches.
func _dead_tree(base: Vector2, h: float, c: Color, i: int) -> void:
	var lean := (_h(i, 13) - 0.5) * h * 0.25
	var tw := 6.0 + h * 0.035
	var top_p := base + Vector2(lean, -h)
	_poly(PackedVector2Array([base + Vector2(-tw * 1.6, 0), base + Vector2(-tw, -h * 0.15), top_p + Vector2(-2, 0), top_p + Vector2(2, 0), base + Vector2(tw, -h * 0.15), base + Vector2(tw * 1.8, 0)]), c)
	for b in 2 + int(_h(i, 14) * 3.0):
		var f := 0.35 + 0.55 * _h(i * 5 + b, 15)
		var root := base.lerp(top_p, f)
		var side := -1.0 if (i + b) % 2 == 0 else 1.0
		var len := h * (0.18 + 0.2 * _h(i, b + 16))
		var mid := root + Vector2(side * len * 0.55, -len * 0.25)
		var end := root + Vector2(side * len, -len * (0.1 + _h(b, i) * 0.6))
		var bw := tw * 0.55 * (1.0 - f * 0.5)
		_poly(PackedVector2Array([root + Vector2(0, -bw), mid + Vector2(0, -bw * 0.6), end, mid + Vector2(0, bw * 0.6), root + Vector2(0, bw)]), c)

func _fog() -> void:
	var t := Backdrop.TILE
	var c := _col("col", "#3e5878")
	c.a = float(spec.get("alpha", 0.2))
	for b: Array in spec.get("bands", []):
		var y := ground + float(b[0])
		var hh := float(b[1])
		var r := Rect2(0.0, y - hh, t, hh * 2.0)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([c, c, c, c]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	# Low ground haze below the bands.
	var lc := Color(c, c.a * 0.8)
	_grad_rect(Rect2(-t, ground - 300.0, t * 3.0, 320.0), Color(lc, 0.0), lc)
	draw_rect(Rect2(-t, ground + 20.0, t * 3.0, 900.0), lc)

func _rays() -> void:
	var t := Backdrop.TILE
	var c := _col("col", "#9fb8e0")
	c.a = float(spec.get("alpha", 0.1))
	var n := int(spec.get("n", 3))
	for i in n:
		var x := (i + 0.2 + _h(i, 20) * 0.6) * t / n
		var y0 := ground - 1100.0
		var w0 := 50.0 + _h(i, 21) * 60.0
		var w1 := w0 * 2.6
		var slant := 260.0 + _h(i, 22) * 160.0
		var u := float(i)
		for k: int in [-1, 0, 1]:
			var o := Backdrop.TILE * k
			draw_polygon(PackedVector2Array([Vector2(x + o - w0, y0), Vector2(x + o + w0, y0), Vector2(x + o + slant + w1, ground), Vector2(x + o + slant - w1, ground)]),
				PackedColorArray([c, c, c, c]), PackedVector2Array([Vector2(u, 0), Vector2(u + 0.999, 0), Vector2(u + 0.999, 1), Vector2(u, 1)]))

func _water() -> void:
	var t := Backdrop.TILE
	var c := _col("col", "#1c3029")
	var r := Rect2(0.0, ground - 36.0, t, 260.0)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c.lightened(0.12), c.lightened(0.12), c, c]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	# Hummocks on the water line.
	for i in int(t / 160.0):
		var x := i * 160.0 + _h(i, 25) * 100.0
		var w := 40.0 + _h(i, 26) * 70.0
		draw_colored_polygon(Room._oval(Vector2(x, ground - 34.0), w, 9.0 + _h(i, 27) * 6.0), c.lightened(0.05))

## Near background trunks: 2-4 per screen, darkest, with a lit edge facing the
## middle of the screen (rim light, plan §2.1 L5).
func _trunks() -> void:
	var t := Backdrop.TILE
	var c := _tone()
	var rim := Color(_col("rim", "#5a6e92"), 0.55)
	var gap := float(spec.get("gap", 500.0))
	var n := int(t / gap)
	var snow := String(spec.get("snow", ""))
	for i in n:
		var x := (i + 0.15 + _h(i, 50) * 0.7) * t / n
		var w := 46.0 + _h(i, 51) * 40.0
		var lean := (_h(i, 52) - 0.5) * (90.0 if bool(spec.get("crooked", false)) else 24.0)
		var b := Vector2(x, ground + 60.0)
		var tp := Vector2(x + lean, ground - 1600.0)
		_poly(PackedVector2Array([b + Vector2(-w * 0.9, 0), b + Vector2(-w * 0.55, -60), tp + Vector2(-w * 0.45, 0), tp + Vector2(w * 0.45, 0), b + Vector2(w * 0.55, -60), b + Vector2(w * 0.95, 0)]), c)
		_poly(PackedVector2Array([b + Vector2(w * 0.5, -60), tp + Vector2(w * 0.42, 0), tp + Vector2(w * 0.32, 0), b + Vector2(w * 0.38, -60)]), rim)
		# Root flare and two stubs of branches.
		_poly(PackedVector2Array([b + Vector2(-w * 1.8, 0), b + Vector2(-w * 0.5, -70), b + Vector2(0, 0)]), c)
		_poly(PackedVector2Array([b + Vector2(w * 1.6, 0), b + Vector2(w * 0.5, -55), b + Vector2(0, 0)]), c)
		for k in 2:
			var by := ground - 380.0 - k * 300.0 - _h(i, 53 + k) * 120.0
			var bx := x + lean * (ground - by) / 1600.0
			var s := -1.0 if (i + k) % 2 == 0 else 1.0
			_poly(PackedVector2Array([Vector2(bx, by - 10), Vector2(bx + s * (90 + w), by + 18), Vector2(bx + s * (100 + w), by + 26), Vector2(bx, by + 12)]), c)
			if snow != "":
				_poly(PackedVector2Array([Vector2(bx, by - 14), Vector2(bx + s * (90 + w), by + 14), Vector2(bx, by - 6)]), Color(snow, 0.8))
