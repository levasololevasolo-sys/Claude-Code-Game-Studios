## Regression (BUG: grass floating in the air / under the ground in the graph
## levels): VfxGrass on a whole level stands only on open floor tops, and
## LevelRoom.surfaces finds those tops from the grid.
extends GdUnitTestSuite

const G: Array[String] = [
	"##########",
	"#........#",
	"#...==...#",
	"#........#",
	"#..####..#",
	"#~~####..#",
	"##########",
]

func _grid() -> PackedStringArray:
	return PackedStringArray(G)

func test_surfaces_open_tops_only() -> void:
	# Arrange / Act
	var s := LevelRoom.surfaces(_grid(), 40.0)
	# Assert: the platform top (row 2), the block top (row 4), the floor right of
	# the block (row 6, x 6..8); not under the bog water, not inside rock.
	assert_bool(s.has(Vector3(160, 240, 80))).is_true()
	assert_bool(s.has(Vector3(120, 280, 160))).is_true()
	assert_bool(s.has(Vector3(280, 360, 240))).is_true()
	for v: Vector3 in s:
		assert_bool(v.y > v.x).is_true()
		# never the row-6 cells under the "~" water (x 40..120)
		assert_bool(v.z == 240.0 and v.x < 120.0).is_false()

func test_grass_on_level_stands_on_surfaces() -> void:
	# Arrange
	var g: VfxGrass = auto_free(VfxGrass.new())
	g.spec = { "every": [10, 12], "h": [10, 12], "blades": [3, 3] }
	var sf := LevelRoom.surfaces(_grid(), 40.0)
	var layout := { "w": 400.0, "solids": [Rect2(0, 0, 400, 40)], "plats": [], "surfaces": sf }
	# Act: ground_y far below the level, like a level deeper than one screen
	g.build(layout, 1000.0)
	# Assert: every tuft's root is on some surface (y = top + 1)
	assert_int(g.x.size()).is_greater(0)
	for i in g.x.size():
		var on := false
		for v: Vector3 in sf:
			if is_equal_approx(g.y[i], v.z + 1.0) and g.x[i] >= v.x and g.x[i] <= v.y:
				on = true
		assert_bool(on).override_failure_message("tuft %d at (%s, %s) floats" % [i, g.x[i], g.y[i]]).is_true()
