## LevelBackdrop / Backdrop / LandmarkPainter pure helpers (the developer 28.11:
## the background must change along the level; underground rooms get a cave).
extends GdUnitTestSuite

func _level() -> Dictionary:
	# Two surface rooms side by side at different heights, one underground room.
	return { "rooms": [
		{ "x": 0, "y": 0, "w": 2, "h": 1, "band": 0, "i": 0 },
		{ "x": 2, "y": 1, "w": 1, "h": 1, "band": 0, "i": 1 },
		{ "x": 0, "y": 2, "w": 3, "h": 1, "band": 2, "i": 2 },
	] }

func test_variant_order_never_repeats_back_to_back() -> void:
	var order := Backdrop.variant_order(3, 40, 5)
	assert_int(order.size()).is_equal(40)
	for k in range(1, order.size()):
		assert_int(order[k]).is_not_equal(order[k - 1])

func test_variant_order_uses_every_variant_over_a_long_strip() -> void:
	var seen := {}
	for v in Backdrop.variant_order(4, 60, 2):
		seen[v] = true
	assert_int(seen.size()).is_equal(4)

func test_strip_width_grows_with_level_and_scroll() -> void:
	assert_float(Backdrop.strip_width(20000.0, 0.5)).is_greater(Backdrop.strip_width(10000.0, 0.5))
	assert_float(Backdrop.strip_width(20000.0, 0.6)).is_greater(Backdrop.strip_width(20000.0, 0.3))
	# A one-screen level still covers the screen.
	assert_float(Backdrop.strip_width(1920.0, 0.5)).is_greater_equal(1920.0)

func test_landmark_plan_covers_strip_without_same_kind_twice() -> void:
	var p := LandmarkPainter.plan(["idol", "dead_oak", "bridge"], 12000.0, 1500.0, 9)
	assert_int(p.size()).is_greater(5)
	assert_float(float(p[p.size() - 1].x)).is_less(12000.0)
	for k in range(1, p.size()):
		assert_str(String(p[k].kind)).is_not_equal(String(p[k - 1].kind))
		assert_float(float(p[k].x)).is_greater(float(p[k - 1].x))

func test_landmark_plan_skips_unknown_kinds() -> void:
	assert_array(LandmarkPainter.plan(["no_such_thing"], 8000.0, 1000.0, 1)).is_empty()

func test_surface_grounds_takes_lowest_surface_in_room() -> void:
	var surf := [Vector3(40, 400, 200), Vector3(600, 900, 320), Vector3(1400, 1600, 600)]
	var g := LevelBackdrop.surface_grounds(_level(), surf, 16, 9, 40.0)
	assert_int(g.size()).is_equal(2)
	assert_float(float(g[0].ground)).is_equal(320.0)
	# Room 1 (x 1280..1920, y 360..720) holds the 600 surface.
	assert_float(float(g[1].ground)).is_equal(600.0)

func test_ground_at_follows_the_room_over_the_camera_column() -> void:
	var g := LevelBackdrop.surface_grounds(_level(), [Vector3(40, 400, 320), Vector3(1400, 1600, 680)], 16, 9, 40.0)
	assert_float(LevelBackdrop.ground_at(g, 300.0, 200.0, -1.0)).is_equal(320.0)
	assert_float(LevelBackdrop.ground_at(g, 1500.0, 500.0, -1.0)).is_equal(680.0)
	# No surface room over the column: keep the last value.
	assert_float(LevelBackdrop.ground_at(g, 5000.0, 500.0, 123.0)).is_equal(123.0)

func test_progress_runs_from_start_to_end() -> void:
	assert_float(LevelBackdrop.progress(960.0, 10000.0)).is_equal(0.0)
	assert_float(LevelBackdrop.progress(10000.0 - 960.0, 10000.0)).is_equal(1.0)
	assert_float(LevelBackdrop.progress(5000.0, 10000.0)).is_between(0.4, 0.6)

func test_room_image_marks_bands_and_empty_modules() -> void:
	var img := LevelBackdrop.room_image(_level(), 3, 3, 9, 40.0)
	assert_float(img.get_pixel(0, 2).r).is_equal(2.0)
	assert_float(img.get_pixel(0, 2).a).is_equal(1.0)
	assert_float(img.get_pixel(0, 0).r).is_equal(0.0)
	# Module (2, 0) holds no room.
	assert_float(img.get_pixel(2, 0).a).is_equal(0.0)
	# g = the room's top y in px.
	assert_float(img.get_pixel(2, 1).g).is_equal(360.0)
