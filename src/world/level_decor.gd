## Set dressing of a level room (approved art drop, tools/asset-pipeline/navart/
## dress.py): painted props from assets/art/dress/dress.json stood on the
## room's open floor runs, behind the hero and the terrain rim. Picks and
## places are a hash of the room, so a seed always dresses the same.
## Surface rooms take the location's "surface" pieces, underground rooms
## (band > 0) the "cave" ones. Visual only: no collision.
class_name LevelDecor
extends Node2D

const DRESS_JSON: String = "res://assets/art/dress/dress.json"
static var _meta: Dictionary = {}
static var _tex: Dictionary = {}

var lr: LevelRoom
var room: Dictionary = {}
## level_backdrop.json block: dress (location), dress_every (cells per piece),
## dress_h ([min, max] px tall), dress_mod (tint).
var spec: Dictionary = {}

## The dress rows of `loc` / `kind` ("surface" | "cave"), [] when missing.
static func pieces(loc: String, kind: String) -> Array:
	if _meta.is_empty() and FileAccess.file_exists(DRESS_JSON):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DRESS_JSON))
		_meta = d if d is Dictionary else { "_": {} }
	return ((_meta.get(loc, {}) as Dictionary).get(kind, [])) as Array

static func _texture(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[path]

func _ready() -> void:
	z_index = -2
	modulate = Color(String(spec.get("dress_mod", "#ffffff")))
	queue_redraw()

## Floor runs of the room: [x0 cell, x1 cell, y cell of the floor] where the
## two cells above are open air.
func floor_runs() -> Array:
	var out: Array = []
	var x0 := int(room.x) * lr.mw
	var y0 := int(room.y) * lr.mh
	for y in range(y0 + 2, y0 + int(room.h) * lr.mh):
		var x := x0
		while x < x0 + int(room.w) * lr.mw:
			if _spot(x, y):
				var s := x
				while x < x0 + int(room.w) * lr.mw and _spot(x, y):
					x += 1
				out.append([s, x, y])
			else:
				x += 1
	return out

func _spot(x: int, y: int) -> bool:
	return lr.at(Vector2i(x, y)) == "#" and lr.at(Vector2i(x, y - 1)) == "." and lr.at(Vector2i(x, y - 2)) == "."

func _draw() -> void:
	if lr == null:
		return
	var loc := String(spec.get("dress", ""))
	var list := pieces(loc, "cave" if int(room.get("band", 0)) > 0 else "surface")
	if list.is_empty():
		return
	var every := maxi(3, int(spec.get("dress_every", 7)))
	var hr: Array = spec.get("dress_h", [70, 150])
	var c := lr.cell
	var s := int(room.get("i", 0)) * 7919 + 17
	for run: Array in floor_runs():
		var n := int(run[1]) - int(run[0])
		if n < 3:
			continue
		var count := maxi(0, int(floor(float(n) / every + Room._h(s + int(run[0]), 3))))
		for k in count:
			var hs := s + int(run[0]) * 31 + int(run[2]) * 97 + k * 13
			var row: Dictionary = list[int(Room._h(hs, 1) * list.size()) % list.size()]
			var tex := _texture(String(row.file))
			if tex == null:
				continue
			var hgt := lerpf(float(hr[0]), float(hr[1]), Room._h(hs, 2))
			var sz := tex.get_size() * (hgt / tex.get_height())
			sz = sz * minf(1.0, (n * c * 0.8) / maxf(sz.x, 1.0))
			var cx := (float(run[0]) + (float(k) + 0.25 + 0.5 * Room._h(hs, 4)) * n / float(count)) * c
			var flip := Room._h(hs, 5) < 0.5
			var rect := Rect2(Vector2(cx - sz.x * 0.5, float(run[2]) * c - sz.y + 6.0), sz)
			if flip:
				rect = Rect2(rect.position + Vector2(rect.size.x, 0), Vector2(-rect.size.x, rect.size.y))
			draw_texture_rect(tex, rect, false)
