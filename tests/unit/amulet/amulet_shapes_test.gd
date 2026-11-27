## Shape hit tests of the Flare (GDD amulet-and-flare §3.5, AC 7, 10-12) and the
## pure-light element hook (§3.6). Boxes are Enemy-style hurt rects (origin at feet).
extends GdUnitTestSuite

const GROUND: float = 640.0
## Hero chest: feet at (1000, 640), half the 64 px body up.
const CHEST := Vector2(1000.0, 608.0)

## Hurt rect of a w×h target standing with its feet at (x, y).
func _box(x: float, y: float = GROUND, w: float = 40.0, h: float = 70.0) -> Rect2:
	return Rect2(x - w / 2.0, y - h, w, h)

func test_ring_at_150_hits_500_not_560() -> void:
	var r := 430.0 * AmuletRules.size_mult(1.5, {})
	assert_bool(AmuletRules.ring_hits(CHEST, _box(1500.0), r)).is_true()
	assert_bool(AmuletRules.ring_hits(CHEST, _box(1560.0), r)).is_false()

func test_ring_at_100_misses_500() -> void:
	assert_bool(AmuletRules.ring_hits(CHEST, _box(1500.0), 430.0)).is_false()

func test_ring_reaches_air() -> void:
	assert_bool(AmuletRules.ring_hits(CHEST, _box(1150.0, GROUND - 260.0, 50.0, 30.0), 430.0)).is_true()

func test_beam_hits_900_ahead_not_50_behind() -> void:
	var b := AmuletRules.beam_rect(CHEST, 1, 1000.0, 140.0, 4000.0)
	assert_bool(AmuletRules.beam_hits(b, _box(1900.0))).is_true()
	assert_bool(AmuletRules.beam_hits(b, _box(950.0))).is_false()

func test_beam_faces_left() -> void:
	var b := AmuletRules.beam_rect(CHEST, -1, 1000.0, 140.0, 4000.0)
	assert_bool(AmuletRules.beam_hits(b, _box(300.0))).is_true()
	assert_bool(AmuletRules.beam_hits(b, _box(1100.0))).is_false()

func test_beam_is_cut_at_the_wall() -> void:
	var b := AmuletRules.beam_rect(CHEST, 1, 1000.0, 140.0, 1300.0)
	assert_float(b.end.x).is_equal(1300.0)

func test_beam_misses_high_flyer() -> void:
	var b := AmuletRules.beam_rect(CHEST, 1, 1000.0, 140.0, 4000.0)
	assert_bool(AmuletRules.beam_hits(b, _box(1300.0, GROUND - 200.0, 50.0, 30.0))).is_false()

func test_wave_band_hits_ground_crawler_not_bat_200_up() -> void:
	var front := AmuletRules.wave_front(1000.0, 1, 900.0, 0.8, 0.0, 4000.0)
	var band := AmuletRules.wave_band(1600.0, front, GROUND, 110.0)
	assert_bool(band.intersects(_box(1700.0, GROUND, 58.0, 32.0))).is_true()
	var high := AmuletRules.wave_band(1000.0, 1300.0, GROUND, 110.0)
	assert_bool(high.intersects(_box(1200.0, GROUND - 200.0, 50.0, 30.0))).is_false()

func test_wave_front_stops_at_surface_edge() -> void:
	assert_float(AmuletRules.wave_front(500.0, 1, 900.0, 0.9, 300.0, 700.0)).is_equal(700.0)
	assert_float(AmuletRules.wave_front(500.0, -1, 900.0, 0.9, 300.0, 700.0)).is_equal(300.0)

func test_surface_under_prefers_nearest_platform_below() -> void:
	var plats := [Vector3(400.0, 530.0, 300.0), Vector3(400.0, 440.0, 300.0)]
	assert_vector(AmuletRules.surface_under(500.0, 400.0, plats, GROUND, 3000.0)).is_equal(Vector3(400.0, 440.0, 700.0))
	assert_vector(AmuletRules.surface_under(500.0, 500.0, plats, GROUND, 3000.0)).is_equal(Vector3(400.0, 530.0, 700.0))
	assert_vector(AmuletRules.surface_under(900.0, 400.0, plats, GROUND, 3000.0)).is_equal(Vector3(0.0, GROUND, 3000.0))

func test_knot_triggers_at_140_px() -> void:
	var k := Vector2(1000.0, GROUND)
	assert_bool(AmuletRules.knot_triggered(k, [_box(1150.0)], 140.0)).is_true()
	assert_bool(AmuletRules.knot_triggered(k, [_box(1170.0)], 140.0)).is_false()
	assert_bool(AmuletRules.knot_triggered(k, [], 140.0)).is_false()

func test_pull_velocity_divides_by_weight() -> void:
	var v := AmuletRules.pull_velocity(Vector2(1200.0, 600.0), Vector2(1000.0, 600.0), 500.0, 2.0)
	assert_vector(v).is_equal_approx(Vector2(-250.0, 0.0), Vector2(0.01, 0.01))
	assert_vector(AmuletRules.pull_velocity(Vector2(1000.0, 600.0), Vector2(1000.0, 600.0), 500.0, 1.0)).is_equal(Vector2.ZERO)

func test_pure_light_stuns_by_power() -> void:
	var h := Hit.make(Hit.Kind.FLARE, 57.0, 0.0, 0.0)
	FlareElement.apply(FlareElement.PURE, h, 1.5, { "flare_stun": 1.4, "flare_god_stun": 0.4 })
	assert_float(h.stun).is_equal_approx(2.1, 0.001)

func test_god_element_hook_gives_short_stun() -> void:
	var h := Hit.make(Hit.Kind.FLARE, 57.0, 0.0, 0.0)
	FlareElement.apply("svarog", h, 1.5, { "flare_stun": 1.4, "flare_god_stun": 0.4 })
	assert_float(h.stun).is_equal_approx(0.4, 0.001)
