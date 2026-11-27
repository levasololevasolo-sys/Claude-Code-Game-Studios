## Sleeping packs and waking (GDD room-generation-and-doors §3.5, AC 6).
extends GdUnitTestSuite

func test_hero_inside_aggro_box_wakes() -> void:
	assert_bool(Enemy.should_wake(Vector2(519, 0), 10, 10, 520, 360)).is_true()

func test_hero_outside_aggro_range_x_stays_asleep() -> void:
	assert_bool(Enemy.should_wake(Vector2(520, 0), 10, 10, 520, 360)).is_false()

func test_hero_outside_aggro_range_y_stays_asleep() -> void:
	assert_bool(Enemy.should_wake(Vector2(0, -360), 10, 10, 520, 360)).is_false()

func test_hurt_enemy_wakes_wherever_hero_is() -> void:
	assert_bool(Enemy.should_wake(Vector2(5000, 0), 9, 10, 520, 360)).is_true()

func test_wake_pack_wakes_only_that_pack() -> void:
	var list: Array = []
	for i in 4:
		var e: Crawler = auto_free(EnemyFixtures.make(Crawler.new(), EnemyFixtures.crawler(), 1, Vector2.ZERO))
		e.asleep = true
		e.pack = 0 if i < 2 else 1
		list.append(e)
	Enemy.wake_pack(list, 0)
	assert_bool(list[0].asleep or list[1].asleep).is_false()
	assert_bool(list[2].asleep and list[3].asleep).is_true()
	assert_float(list[0].alert).is_greater(0.0)

func test_aggro_range_is_below_pack_gap() -> void:
	assert_float(Tune.f("aggro_range")).is_less(Tune.f("pack_gap"))

func test_hit_on_sleeper_without_world_wakes_it() -> void:
	var e: Crawler = auto_free(EnemyFixtures.make(Crawler.new(), EnemyFixtures.crawler(), 1, Vector2.ZERO))
	e.asleep = true
	e.hurt(Hit.make(Hit.Kind.STRIKE, 1.0, 10.0, 0.0))
	assert_bool(e.asleep).is_false()
