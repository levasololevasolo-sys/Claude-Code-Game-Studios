## The whole location level as one Room (GDD level-structure §3.5, §3.9 stage 1):
## builds collision from the LevelGen grid (`#` merged into static rectangles,
## `=` and `B` one-way platforms, `~` bog water and `^` thorn strips are zones
## read by the hero and the thorn Traps), draws it with LevelArt per room, and
## answers grid questions (floor under a point, the floor span an enemy may walk,
## which room a point is in, bog water). The rest of the World treats it as a
## Room whose layout.w is the level width.
class_name LevelRoom
extends Room

## The LevelGen level dictionary.
var level: Dictionary = {}
var cell: float = 40.0
var cols: int = 0
var rows: int = 0
var grid: PackedStringArray = PackedStringArray()
var mw: int = 16
var mh: int = 9
## The level's backgrounds (surface backdrop, landmarks, caves).
var backdrop: LevelBackdrop

## Builds collision and art for `l` (LevelGen.build output).
func build_level(l: Dictionary) -> void:
	level = l
	cell = float(l.get("cell", 40))
	cols = int(l.cols)
	rows = int(l.rows)
	mw = int(l.module_w)
	mh = int(l.module_h)
	grid = l.grid
	var solids := merged_rects("#")
	var plats: Array = []
	for y in rows:
		var line := grid[y]
		var x := 0
		while x < cols:
			if _oneway(line[x]):
				var x0 := x
				while x < cols and _oneway(line[x]):
					x += 1
				plats.append(Vector3(x0 * cell, y * cell, (x - x0) * cell))
			else:
				x += 1
	layout = { "w": cols * cell, "h": rows * cell, "plats": plats, "packs": [], "solids": solids, "top": 0.0, "portal": false, "level": true, "surfaces": surfaces(grid) }
	var body := StaticBody2D.new()
	body.collision_layer = 1
	for r: Rect2 in solids:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
	add_child(body)
	var pb := StaticBody2D.new()
	pb.collision_layer = 2
	for p: Vector3 in plats:
		var shape := CollisionShape2D.new()
		var seg := RectangleShape2D.new()
		seg.size = Vector2(p.z, 16)
		shape.shape = seg
		shape.one_way_collision = true
		shape.position = Vector2(p.x + p.z / 2.0, p.y + 8)
		pb.add_child(shape)
	add_child(pb)
	# Backgrounds (LevelBackdrop): the surface sky and landmarks follow the hero
	# along the level; underground rooms get the cave wall shader.
	var bspec := LevelBackdrop.spec_for(String(look.get("props", "ruins")))
	backdrop = LevelBackdrop.new()
	add_child(backdrop)
	backdrop.build(self, vis, bspec)
	var fill := LevelArt.new()
	fill.lr = self
	fill.t = vis.get("terrain", {})
	fill.earth = bspec
	fill.mode = "fill"
	add_child(fill)
	for room: Dictionary in l.rooms:
		var a := LevelArt.new()
		a.lr = self
		a.t = vis.get("terrain", {})
		a.room = room
		a.mode = "room"
		add_child(a)
		if bspec.has("dress"):
			var dec := LevelDecor.new()
			dec.lr = self
			dec.room = room
			dec.spec = bspec
			add_child(dec)

## Rectangles (world px) covering every cell of `chars`, rows merged vertically.
func merged_rects(chars: String) -> Array:
	var out: Array = []
	var open := {}
	for y in rows + 1:
		var runs := {}
		if y < rows:
			var line := grid[y]
			var x := 0
			while x < cols:
				if chars.contains(line[x]):
					var x0 := x
					while x < cols and chars.contains(line[x]):
						x += 1
					runs[Vector2i(x0, x)] = true
				else:
					x += 1
		var nxt := {}
		for k: Vector2i in open:
			if runs.has(k):
				nxt[k] = open[k]
			else:
				out.append(Rect2(k.x * cell, int(open[k]) * cell, (k.y - k.x) * cell, (y - int(open[k])) * cell))
		for k: Vector2i in runs:
			if not nxt.has(k):
				nxt[k] = y
		open = nxt
	return out

## Floor tops a thing can stand on and see the sky from: Vector3(x0, x1, y) in
## world px for each run of `#` or one-way cells whose cell above is open air
## (not solid, not a platform, not bog water or thorns). The VFX grass and lamps
## stand only on these, so they never float or sit inside rock. Pure (tested).
static func surfaces(g: PackedStringArray, c: float = 40.0) -> Array:
	var out: Array = []
	for y in range(1, g.size()):
		var line := g[y]
		var up := g[y - 1]
		var x := 0
		var n := mini(line.length(), up.length())
		while x < n:
			if _floor_cell(line[x], up[x]):
				var x0 := x
				while x < n and _floor_cell(line[x], up[x]):
					x += 1
				out.append(Vector3(x0 * c, x * c, y * c))
			else:
				x += 1
	return out

static func _floor_cell(ch: String, above: String) -> bool:
	return (ch == "#" or _oneway(ch)) and not (above == "#" or _oneway(above) or above == "~" or above == "^")

static func _oneway(ch: String) -> bool:
	return ch == "=" or ch == "B"

## Grid character at cell `c` ("#" outside the level).
func at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return "#"
	return grid[c.y][c.x]

## Cell of a world point.
func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))

## True when the cell blocks (solid earth or an unbroken breakable wall cell).
func solid(c: Vector2i) -> bool:
	var ch := at(c)
	return ch == "#"

## True when a hero or an enemy can stand on top of cell `c`.
func floor_cell(c: Vector2i) -> bool:
	var ch := at(c)
	return ch == "#" or _oneway(ch) or ch == "S"

## Height (world y) of the first floor at or below `p` in its column; the level
## bottom when none.
func floor_below(p: Vector2) -> float:
	var c := cell_of(p - Vector2(0, 1))
	for y in range(maxi(c.y, 0), rows):
		if floor_cell(Vector2i(c.x, y)) and not floor_cell(Vector2i(c.x, y - 1)):
			return y * cell
	return rows * cell

## The walkable span [x0, x1] (world px) of the floor under the feet at `p`, and
## whether each end is a wall (true) or a drop / thorns (false):
## {x0, x1, y, wall_l, wall_r}. Enemies patrol inside it (level-structure §3.9).
func span_at(p: Vector2) -> Dictionary:
	var y := floor_below(p)
	var fy := roundi(y / cell)
	var c := cell_of(Vector2(p.x, y - cell * 0.5))
	var l := c.x
	var wall_l := false
	while true:
		var n := Vector2i(l - 1, c.y)
		if solid(n) or at(n) == "S" or at(n) == "A":
			wall_l = true
			break
		if not floor_cell(Vector2i(l - 1, fy)) or at(n) == "^":
			break
		l -= 1
	var r := c.x
	var wall_r := false
	while true:
		var n := Vector2i(r + 1, c.y)
		if solid(n) or at(n) == "S" or at(n) == "A":
			wall_r = true
			break
		if not floor_cell(Vector2i(r + 1, fy)) or at(n) == "^":
			break
		r += 1
	return { "x0": l * cell, "x1": (r + 1) * cell, "y": y, "wall_l": wall_l, "wall_r": wall_r }

## True when `p` (feet) stands in bog water `~`.
func in_bog(p: Vector2) -> bool:
	return at(cell_of(p - Vector2(0, 4))) == "~"

## Index of the room holding world point `p`, -1 outside every room.
func room_at(p: Vector2) -> int:
	var m := Vector2i(floori(p.x / (cell * mw)), floori(p.y / (cell * mh)))
	return LevelGen.room_at_module(level, m)

## World rect of room `i`.
func room_rect(i: int) -> Rect2:
	var r: Dictionary = level.rooms[i]
	return Rect2(float(r.x) * mw * cell, float(r.y) * mh * cell, float(r.w) * mw * cell, float(r.h) * mh * cell)

## World position of a marker cell's floor point (bottom-centre of the cell).
func cell_floor(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * cell, (c.y + 1) * cell)

## True when the feet at `p` stand on a one-way platform (drop-through).
func oneway_under(p: Vector2) -> bool:
	return _oneway(at(cell_of(p + Vector2(0, 4))))

## The standing cell of room `ri` nearest to cell `o` (an empty cell with an
## empty cell above and a floor below): where the hook pulls the hero.
func stand_near(o: Vector2i, ri: int) -> Vector2i:
	var rc := room_rect(ri)
	var best := o
	var best_d := INF
	for y in range(int(rc.position.y / cell), int(rc.end.y / cell)):
		for x in range(int(rc.position.x / cell), int(rc.end.x / cell)):
			var c := Vector2i(x, y)
			if solid(c) or solid(c + Vector2i(0, -1)) or not floor_cell(c + Vector2i(0, 1)) or floor_cell(c):
				continue
			var d := Vector2(c).distance_to(Vector2(o))
			if d < best_d:
				best_d = d
				best = c
	return best

## Fits an enemy to the level before it enters the tree: a walker gets its own
## floor height and the floor span it may walk (never off a ledge), a flyer the
## frame of its room (edge case 6).
func fit_enemy(e: Enemy) -> void:
	var ri := room_at(e.position)
	if e.flies:
		if ri >= 0:
			e.fly_box = room_rect(ri).grow(-cell)
		return
	var sp := span_at(e.position)
	e.floor_y = float(sp.y)
	e.position.y = e.floor_y
	e.span = Vector2(float(sp.x0), float(sp.x1))
	e.span_wall = Vector2i(1 if bool(sp.wall_l) else 0, 1 if bool(sp.wall_r) else 0)

func _draw() -> void:
	pass
