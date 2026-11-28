## Unique far silhouettes along a graph level (the developer: the background must
## change as the hero walks on). One landmark every `every` layer px, the kind
## picked from the location's list by a seeded hash and never the same kind twice
## in a row: stilt huts, dead oaks, idols, broken bridges, grave posts, sunken
## towers (Топь); giant pines, watchtowers, stone circles (Лес); ice spires,
## frozen idols (Мороз). Drawn once, no repeat: the layer is as wide as the strip
## the camera sees over the level (Backdrop.strip_width). Colour fades toward the
## fog; windows and eyes glow in the location's glow colour. Visual only.
class_name LandmarkPainter
extends Node2D

## Kinds this painter knows; others in the data are skipped.
const KINDS: Array[String] = ["stilt_hut", "dead_oak", "idol", "bridge", "grave_posts", "sunken_tower", "giant_pine", "watchtower", "stone_circle", "ice_spire", "frozen_idol"]

var kinds: Array = []
var every: float = 1700.0
var width: float = 4000.0
var ground: float = 0.0
var col: Color = Color("#16241d")
var glow: Color = Color("#8fe36b")
var seed_i: int = 1
## Soft fog glow behind each landmark so it reads against a dark sky.
var halo: Color = Color(0.5, 0.6, 0.7, 0.1)

func _h(i: int, salt: int) -> float:
	return Room._h(i + seed_i * 613, salt)

## Landmarks of a strip `w` px wide: [{x, kind}] in order. The first sits
## within the first screen; kinds never repeat back to back. Pure (tested).
static func plan(list: Array, w: float, step: float, s: int) -> Array:
	var known: Array = []
	for k: Variant in list:
		if String(k) in KINDS:
			known.append(String(k))
	var out: Array = []
	if known.is_empty() or step <= 0.0:
		return out
	var x := 500.0 + Room._h(s, 51) * 300.0
	var prev := ""
	var i := 0
	while x < w:
		var kind: String = known[int(Room._h(i + s * 7, 52) * known.size()) % known.size()]
		if kind == prev and known.size() > 1:
			kind = known[(known.find(kind) + 1) % known.size()]
		out.append({ "x": x, "kind": kind })
		prev = kind
		x += step * (0.8 + 0.4 * Room._h(i + s * 13, 53))
		i += 1
	return out

func _draw() -> void:
	var i := 0
	for lm: Dictionary in plan(kinds, width, every, seed_i):
		var b := Vector2(float(lm.x), ground + 40.0)
		var k := 0.85 + 0.35 * _h(i, 1)
		for j in 5:
			draw_circle(b + Vector2(0, -260.0 * k), (420.0 - j * 70.0) * k, Color(halo, halo.a * 0.35))
		match String(lm.kind):
			"stilt_hut": _stilt_hut(b, k, i)
			"dead_oak": _dead_oak(b, k, i)
			"idol": _idol(b, k, i, false)
			"frozen_idol": _idol(b, k, i, true)
			"bridge": _bridge(b, k, i)
			"grave_posts": _grave_posts(b, k, i)
			"sunken_tower": _sunken_tower(b, k, i)
			"giant_pine": _giant_pine(b, k, i)
			"watchtower": _watchtower(b, k, i)
			"stone_circle": _stone_circle(b, k, i)
			"ice_spire": _ice_spire(b, k, i)
		i += 1

func _poly(pts: Array, c: Color = col) -> void:
	draw_colored_polygon(PackedVector2Array(pts), c)

func _glow_dot(p: Vector2, r: float) -> void:
	for j in 4:
		draw_circle(p, r * (4.0 - j), Color(glow, 0.05 + 0.05 * j))
	draw_circle(p, r, Color(glow, 0.9))

## Ground mound so a landmark never floats over the horizon.
func _mound(b: Vector2, w: float) -> void:
	var pts: Array = []
	for j in 9:
		var t := j / 8.0
		pts.append(b + Vector2((t - 0.5) * w, -sin(t * PI) * 40.0))
	pts.append(b + Vector2(w * 0.5, 300.0))
	pts.append(b + Vector2(-w * 0.5, 300.0))
	_poly(pts)

func _stilt_hut(b: Vector2, k: float, i: int) -> void:
	_mound(b, 520.0 * k)
	var w := 220.0 * k
	var floor_y := b.y - 160.0 * k
	for j in 4:
		var x := b.x - w * 0.45 + j * w * 0.3
		draw_line(Vector2(x, b.y - 20.0), Vector2(x + (_h(i * 4 + j, 2) - 0.5) * 20.0, floor_y), col, 10.0 * k)
	_poly([Vector2(b.x - w * 0.5, floor_y), Vector2(b.x + w * 0.5, floor_y), Vector2(b.x + w * 0.5, floor_y - 120.0 * k), Vector2(b.x - w * 0.5, floor_y - 120.0 * k)])
	_poly([Vector2(b.x - w * 0.65, floor_y - 110.0 * k), Vector2(b.x + w * 0.1, floor_y - 250.0 * k), Vector2(b.x + w * 0.7, floor_y - 100.0 * k)])
	draw_line(Vector2(b.x + w * 0.1, floor_y - 250.0 * k), Vector2(b.x + w * 0.2, floor_y - 290.0 * k), col, 6.0)
	_glow_dot(Vector2(b.x - w * 0.15, floor_y - 60.0 * k), 6.0 * k)

func _branch(a: Vector2, ang: float, l: float, w: float, depth: int, s: int) -> void:
	var e := a + Vector2(cos(ang), sin(ang)) * l
	draw_line(a, e, col, w)
	if depth <= 0:
		return
	for j in 2:
		var da := (0.35 + 0.4 * _h(s * 3 + j, 4)) * (1.0 if j == 0 else -1.0)
		_branch(e, ang + da, l * (0.55 + 0.2 * _h(s * 5 + j, 5)), w * 0.62, depth - 1, s * 2 + j + 1)

func _dead_oak(b: Vector2, k: float, i: int) -> void:
	_mound(b, 600.0 * k)
	var h := 420.0 * k
	_poly([b + Vector2(-55.0 * k, 0), b + Vector2(-30.0 * k, -h), b + Vector2(30.0 * k, -h), b + Vector2(60.0 * k, 0)])
	_branch(b + Vector2(0, -h), -PI / 2.0 - 0.5, 200.0 * k, 34.0 * k, 3, i * 7 + 1)
	_branch(b + Vector2(0, -h), -PI / 2.0 + 0.5, 220.0 * k, 34.0 * k, 3, i * 7 + 2)
	_branch(b + Vector2(0, -h * 0.7), -0.25, 160.0 * k, 22.0 * k, 2, i * 7 + 3)
	if _h(i, 6) < 0.5:
		# a hanged lantern
		var lp := b + Vector2(150.0 * k, -h * 0.7 + 40.0)
		draw_line(lp + Vector2(0, -40.0), lp, col, 2.0)
		_glow_dot(lp + Vector2(0, 8.0), 5.0 * k)

func _idol(b: Vector2, k: float, i: int, ice: bool) -> void:
	_mound(b, 420.0 * k)
	var h := 460.0 * k
	var w := 56.0 * k
	_poly([b + Vector2(-w, 0), b + Vector2(-w * 0.8, -h), b + Vector2(0, -h - 60.0 * k), b + Vector2(w * 0.8, -h), b + Vector2(w, 0)])
	# carved tiers (four faces of the pole)
	for j in 3:
		var y := b.y - h * (0.35 + 0.22 * j)
		_poly([Vector2(b.x - w * 1.3, y), Vector2(b.x + w * 1.3, y), Vector2(b.x + w, y - 26.0 * k), Vector2(b.x - w, y - 26.0 * k)])
	var ey := b.y - h * 0.86
	_glow_dot(Vector2(b.x - w * 0.35, ey), 4.0 * k)
	_glow_dot(Vector2(b.x + w * 0.35, ey), 4.0 * k)
	if ice:
		var ic := col.lightened(0.25)
		_poly([b + Vector2(-w * 1.6, 0), b + Vector2(-w * 1.1, -h * 0.55), b + Vector2(-w * 0.4, -h * 0.3), b + Vector2(-w * 0.2, 0)], ic)
		_poly([b + Vector2(w * 0.3, 0), b + Vector2(w * 1.2, -h * 0.75), b + Vector2(w * 1.5, -h * 0.2), b + Vector2(w * 1.8, 0)], ic)

func _bridge(b: Vector2, k: float, i: int) -> void:
	var w := 900.0 * k
	var h := 300.0 * k
	var deck := b.y - h
	# two piers and a broken deck with a gap
	for x: float in [b.x - w * 0.42, b.x + w * 0.1]:
		_poly([Vector2(x - 40.0 * k, b.y), Vector2(x - 30.0 * k, deck), Vector2(x + 30.0 * k, deck), Vector2(x + 40.0 * k, b.y)])
	var gap := b.x + w * (0.2 + 0.1 * _h(i, 7))
	_poly([Vector2(b.x - w * 0.6, deck), Vector2(gap, deck - 10.0), Vector2(gap - 30.0, deck + 34.0 * k), Vector2(b.x - w * 0.6, deck + 34.0 * k)])
	_poly([Vector2(gap + 120.0 * k, deck + 20.0), Vector2(b.x + w * 0.6, deck), Vector2(b.x + w * 0.6, deck + 34.0 * k), Vector2(gap + 150.0 * k, deck + 50.0 * k)])
	# arches under the deck
	for j in 2:
		var ax := b.x - w * 0.16 + j * w * 0.52
		draw_arc(Vector2(ax, deck + 120.0 * k), 120.0 * k, PI, TAU, 16, col, 16.0 * k)
	# railing posts
	for j in 10:
		var px := b.x - w * 0.58 + j * w * 0.09
		if absf(px - gap - 60.0) > 90.0:
			draw_line(Vector2(px, deck), Vector2(px, deck - 40.0 * k), col, 5.0)

func _grave_posts(b: Vector2, k: float, i: int) -> void:
	_mound(b, 700.0 * k)
	for j in 5:
		var x := b.x + (j - 2) * 110.0 * k + (_h(i * 5 + j, 8) - 0.5) * 40.0
		var h := (120.0 + 120.0 * _h(i * 5 + j, 9)) * k
		var lean := (_h(i * 5 + j, 10) - 0.5) * 24.0
		var top := Vector2(x + lean, b.y - h)
		draw_line(Vector2(x, b.y), top, col, 16.0 * k)
		# small gable roof of a голбец
		_poly([top + Vector2(-34.0 * k, 6.0), top + Vector2(0, -30.0 * k), top + Vector2(34.0 * k, 6.0)])
	if _h(i, 11) < 0.6:
		_glow_dot(Vector2(b.x + 40.0 * k, b.y - 70.0 * k), 4.0 * k)

func _sunken_tower(b: Vector2, k: float, i: int) -> void:
	_mound(b, 560.0 * k)
	var lean := 0.12 + 0.1 * _h(i, 12)
	var h := 560.0 * k
	var w := 90.0 * k
	var top := b + Vector2(h * lean, -h)
	_poly([b + Vector2(-w, 0), top + Vector2(-w * 0.85, 0), top + Vector2(w * 0.85, 0), b + Vector2(w, 0)])
	# broken crown
	_poly([top + Vector2(-w, 0), top + Vector2(-w * 0.6, -60.0 * k), top + Vector2(-w * 0.2, -20.0 * k), top + Vector2(w * 0.3, -80.0 * k), top + Vector2(w, 0)])
	var wy := b.lerp(top, 0.7)
	_glow_dot(wy + Vector2(10.0 * k, 0), 5.0 * k)

func _giant_pine(b: Vector2, k: float, i: int) -> void:
	_mound(b, 460.0 * k)
	var h := 820.0 * k
	draw_line(b, b + Vector2(0, -h), col, 30.0 * k)
	for j in 11:
		var t := float(j) / 10.0
		var y := b.y - h * (0.25 + 0.75 * t)
		var w := (260.0 * (1.0 - t) + 30.0) * k
		var droop := 50.0 * k * (1.0 - t)
		_poly([Vector2(b.x - w, y + droop), Vector2(b.x, y - 70.0 * k), Vector2(b.x + w, y + droop + (_h(i * 11 + j, 13) - 0.5) * 20.0)])

func _watchtower(b: Vector2, k: float, i: int) -> void:
	_mound(b, 420.0 * k)
	var h := 520.0 * k
	var w := 110.0 * k
	var deck := b.y - h
	draw_line(b + Vector2(-w, 0), Vector2(b.x - w * 0.6, deck), col, 12.0 * k)
	draw_line(b + Vector2(w, 0), Vector2(b.x + w * 0.6, deck), col, 12.0 * k)
	draw_line(b + Vector2(-w * 0.85, -h * 0.3), Vector2(b.x + w * 0.75, deck + h * 0.25), col, 6.0 * k)
	draw_line(b + Vector2(w * 0.85, -h * 0.3), Vector2(b.x - w * 0.75, deck + h * 0.25), col, 6.0 * k)
	_poly([Vector2(b.x - w * 0.8, deck), Vector2(b.x + w * 0.8, deck), Vector2(b.x + w * 0.8, deck - 70.0 * k), Vector2(b.x - w * 0.8, deck - 70.0 * k)])
	_poly([Vector2(b.x - w, deck - 66.0 * k), Vector2(b.x, deck - 170.0 * k), Vector2(b.x + w, deck - 66.0 * k)])
	_glow_dot(Vector2(b.x, deck - 36.0 * k), 6.0 * k)

func _stone_circle(b: Vector2, k: float, i: int) -> void:
	_mound(b, 760.0 * k)
	for j in 6:
		var x := b.x + (j - 2.5) * 120.0 * k
		var h := (150.0 + 130.0 * _h(i * 6 + j, 14)) * k * (0.7 if j == 0 or j == 5 else 1.0)
		var w := (36.0 + 20.0 * _h(i * 6 + j, 15)) * k
		_poly([Vector2(x - w, b.y), Vector2(x - w * 0.8, b.y - h), Vector2(x + w * 0.2, b.y - h - 18.0 * k), Vector2(x + w * 0.9, b.y - h * 0.94), Vector2(x + w, b.y)])
	# lintel over the middle pair
	_poly([Vector2(b.x - 130.0 * k, b.y - 260.0 * k), Vector2(b.x + 130.0 * k, b.y - 270.0 * k), Vector2(b.x + 130.0 * k, b.y - 230.0 * k), Vector2(b.x - 130.0 * k, b.y - 222.0 * k)])
	_glow_dot(Vector2(b.x, b.y - 120.0 * k), 5.0 * k)

func _ice_spire(b: Vector2, k: float, i: int) -> void:
	_mound(b, 520.0 * k)
	var ic := col.lightened(0.18)
	for j in 4:
		var x := b.x + (j - 1.5) * 70.0 * k
		var h := (300.0 + 420.0 * _h(i * 4 + j, 16)) * k * (1.0 if j == 1 or j == 2 else 0.6)
		var w := (40.0 + 26.0 * _h(i * 4 + j, 17)) * k
		var tip := Vector2(x + (_h(i * 4 + j, 18) - 0.5) * 60.0 * k, b.y - h)
		_poly([Vector2(x - w, b.y), tip, Vector2(x + w, b.y)], ic if j % 2 == 0 else col)
		draw_line(Vector2(x - w * 0.2, b.y - 20.0), tip.lerp(Vector2(x, b.y), 0.1), Color(glow, 0.25), 2.0)
