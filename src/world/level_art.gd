## Look of a LevelRoom (GDD level-structure §3.3, §3.8; stage 1 "без красоты"):
## reuses TerrainArt's rim, platform and grain shader on the level grid.
## mode "fill": every solid cell of the level, flat earth darkening with depth;
## "room": one room's lit rims on exposed tops, dark lips with hanging roots
## under overhangs, one-way platforms and bog water; "wall": the back wall of a
## room below the surface (roots under the roots band, black with Navi cracks in
## the deep band). Visual only; LevelRoom owns collision.
class_name LevelArt
extends TerrainArt

var lr: LevelRoom
## LevelGen room dictionary ("room" / "wall" modes).
var room: Dictionary = {}
var mode: String = "room"

## Back wall colour per depth band (surface, under the roots, the deep).
const WALL: Array = ["#00000000", "#1a1d16", "#0d0b12"]
const CRACK: Color = Color("#c03cff")

func _ready() -> void:
	super._ready()
	if mode == "wall":
		z_index = -60
		material = null

func _depth_k(y: float) -> float:
	return clampf(y / maxf(1.0, lr.rows * lr.cell), 0.0, 1.0)

func _draw() -> void:
	if lr == null:
		return
	match mode:
		"fill":
			_draw_fill()
		"wall":
			_draw_wall()
		_:
			_draw_room()

func _draw_fill() -> void:
	var top := _c("solid", "#2a3530")
	var deep := _c("body_bottom", "#0e1512")
	for r: Rect2 in lr.layout.get("solids", []):
		var k := _depth_k(r.position.y) * 0.8
		draw_rect(r, top.lerp(deep, k))

func _room_cells() -> Rect2i:
	return Rect2i(int(room.x) * lr.mw, int(room.y) * lr.mh, int(room.w) * lr.mw, int(room.h) * lr.mh)

func _draw_room() -> void:
	var rc := _room_cells()
	var c := lr.cell
	var seed_i := int(room.i) * 977
	# Lit rims on exposed tops and dark lips under overhangs.
	for y in range(rc.position.y, rc.end.y):
		var x := rc.position.x
		while x < rc.end.x:
			var ch := lr.at(Vector2i(x, y))
			var top_open := (ch == "#") and not lr.solid(Vector2i(x, y - 1)) and lr.at(Vector2i(x, y - 1)) != "S"
			if top_open:
				var x0 := x
				while x < rc.end.x and lr.at(Vector2i(x, y)) == "#" and not lr.solid(Vector2i(x, y - 1)) and lr.at(Vector2i(x, y - 1)) != "S":
					x += 1
				_rim(x0 * c - 2.0, x * c + 2.0, y * c, seed_i + y * 131 + x0)
			else:
				x += 1
		x = rc.position.x
		while x < rc.end.x:
			var under := lr.at(Vector2i(x, y)) == "#" and y + 1 < lr.rows and not lr.solid(Vector2i(x, y + 1))
			if under:
				var x0 := x
				while x < rc.end.x and lr.at(Vector2i(x, y)) == "#" and not lr.solid(Vector2i(x, y + 1)):
					x += 1
				_lip(x0 * c, x * c, (y + 1) * c, seed_i + y * 17 + x0)
			else:
				x += 1
	# Side shading of exposed walls.
	for y in range(rc.position.y, rc.end.y):
		for x in range(rc.position.x, rc.end.x):
			if lr.at(Vector2i(x, y)) != "#":
				continue
			if not lr.solid(Vector2i(x + 1, y)):
				draw_rect(Rect2((x + 1) * c - 6.0, y * c, 6.0, c), Color(0, 0, 0, 0.3))
			if not lr.solid(Vector2i(x - 1, y)):
				draw_rect(Rect2(x * c, y * c, 5.0, c), Color(1, 1, 1, 0.04))
	# One-way platforms (mostki and bog hummocks) and bog water.
	var k := 0
	for y in range(rc.position.y, rc.end.y):
		var x := rc.position.x
		while x < rc.end.x:
			var ch := lr.at(Vector2i(x, y))
			if ch == "=" or ch == "B":
				var x0 := x
				while x < rc.end.x and lr.at(Vector2i(x, y)) == ch:
					x += 1
				if ch == "B":
					_hummock(Vector2((x0 + x) * 0.5 * c, y * c), (x - x0) * c)
				else:
					_plat(Vector3(x0 * c, y * c, (x - x0) * c), seed_i + k)
				k += 1
			elif ch == "~":
				var x0 := x
				while x < rc.end.x and lr.at(Vector2i(x, y)) == "~":
					x += 1
				_water(Rect2(x0 * c, y * c + 6.0, (x - x0) * c, c - 6.0), seed_i + x0)
			else:
				x += 1

## Dark lip and hanging roots under an overhang at height y.
func _lip(x0: float, x1: float, y: float, s: int) -> void:
	draw_rect(Rect2(x0, y - 6.0, x1 - x0, 6.0), Color(0, 0, 0, 0.35))
	var hang := _c("hang", "#3f5a32")
	var n := int((x1 - x0) / 26.0)
	for i in n:
		if _h(s + i, 11) < 0.45:
			var hx := x0 + 10.0 + i * 26.0 + _h(s + i, 12) * 10.0
			var hl := 10.0 + pow(_h(s + i, 13), 1.5) * 46.0
			draw_line(Vector2(hx, y - 2.0), Vector2(hx + (_h(s + i, 14) - 0.5) * 8.0, y + hl), Color(hang, 0.85), 2.0 + _h(s + i, 15) * 2.0)

func _water(r: Rect2, s: int) -> void:
	draw_rect(Rect2(r.position + Vector2(0, 14.0), r.size - Vector2(0, 14.0)), Color("#0f2622", 0.7))
	draw_rect(Rect2(r.position + Vector2(0, 12.0), Vector2(r.size.x, 3.0)), Color("#6f9a6a", 0.45))
	for i in int(r.size.x / 30.0):
		if _h(s + i, 21) < 0.4:
			var px := r.position.x + i * 30.0 + _h(s + i, 22) * 20.0
			draw_line(Vector2(px, r.position.y + 8.0), Vector2(px + 12.0, r.position.y + 8.0), Color("#9ac08a", 0.3), 1.5)

## A bog hummock (Болотница's spot): a mossy mound that holds like mostki.
func _hummock(top: Vector2, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(top + Vector2(cos(a) * w * 0.55, -sin(a) * 26.0 + 4.0))
	draw_colored_polygon(pts, _c("plat", "#4a4a38").darkened(0.1))
	draw_polyline(PackedVector2Array([top + Vector2(-w * 0.5, 2), top + Vector2(0, -3), top + Vector2(w * 0.5, 2)]), _c("rim_light", "#7d9a5a"), 3.0)

func _draw_wall() -> void:
	var band := int(room.band)
	if band <= 0:
		return
	var rc := _room_cells()
	var c := lr.cell
	var rect := Rect2(rc.position.x * c, rc.position.y * c, rc.size.x * c, rc.size.y * c)
	var col := Color(String(WALL[band]))
	draw_rect(rect, col)
	var s := int(room.i) * 53
	if band == 1:
		# Earth strata and roots of the vault.
		for i in 7:
			var y := rect.position.y + rect.size.y * (0.12 + 0.13 * i) + _h(s + i, 1) * 20.0
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y + (_h(s + i, 2) - 0.5) * 30.0), Color("#2a2a1c", 0.6), 3.0 + _h(s + i, 3) * 4.0)
		for i in int(rect.size.x / 70.0):
			if _h(s + i, 4) < 0.5:
				var x := rect.position.x + i * 70.0 + _h(s + i, 5) * 40.0
				var l := 60.0 + _h(s + i, 6) * 200.0
				draw_line(Vector2(x, rect.position.y), Vector2(x + (_h(s + i, 7) - 0.5) * 40.0, rect.position.y + l), Color("#3a3422", 0.7), 2.0 + _h(s + i, 8) * 3.0)
		for i in 6:
			var p := rect.position + Vector2(_h(s + i, 9) * rect.size.x, _h(s + i, 10) * rect.size.y)
			draw_circle(p, 3.0 + _h(s + i, 11) * 3.0, Color("#b6e36b", 0.35))
	else:
		# The deep: black water stains and magenta Navi cracks.
		for i in 5:
			var p := rect.position + Vector2(_h(s + i, 12) * rect.size.x, (0.2 + 0.6 * _h(s + i, 13)) * rect.size.y)
			var pts := PackedVector2Array([p])
			for j in 5:
				p += Vector2((_h(s + i * 7 + j, 14) - 0.5) * 60.0, 20.0 + _h(s + i * 7 + j, 15) * 30.0)
				pts.append(p)
			draw_polyline(pts, Color(CRACK, 0.45), 2.0)
			draw_polyline(pts, Color(CRACK, 0.12), 8.0)
		for i in 4:
			var bx := rect.position.x + _h(s + i, 16) * rect.size.x
			var by := rect.end.y - c * 1.0
			draw_line(Vector2(bx, by), Vector2(bx, by - 90.0), Color("#3a2e26"), 4.0)
			draw_circle(Vector2(bx, by - 96.0), 9.0, Color("#c8bca0", 0.8))
