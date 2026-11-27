## BUG-0001: World.start_room builds the hero's amulet with the first-run cap
## (amulet-and-flare §3.10, AC 3): c_cap_first_run in run 1, c_cap after.
extends GdUnitTestSuite

const LAYOUT := { "w": 2000.0, "plats": [], "packs": [] }

func _cap(first: bool) -> float:
	var w: World = auto_free(World.new())
	w.build = RunBuild.make()
	w.first_run = first
	w.start_room(LAYOUT.duplicate(true))
	return w.player.amulet.cap

func test_first_run_world_caps_amulet_at_c_cap_first_run() -> void:
	assert_float(_cap(true)).is_equal(Tune.f("c_cap_first_run"))

func test_later_run_world_caps_amulet_at_c_cap() -> void:
	assert_float(_cap(false)).is_equal(Tune.f("c_cap"))
