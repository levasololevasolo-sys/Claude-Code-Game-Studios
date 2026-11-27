## Unit tests for EnemySprite: the state -> animation map of the bat, sentry and
## bloat skins, and that every animation it can pick has a rendered sheet.
extends GdUnitTestSuite

func test_bat_states_map_to_animations() -> void:
	assert_str(EnemySprite.choose("bat", "hover", false, 0.0, true, 0.0).anim).is_equal("fly")
	assert_str(EnemySprite.choose("bat", "swoop", false, 0.0, true, 0.0).anim).is_equal("swoop")
	var w := EnemySprite.choose("bat", "wind", false, 0.0, false, 0.3)
	assert_str(w.anim).is_equal("wind")
	assert_float(w.k).is_equal_approx(0.3, 0.0001)
	assert_str(EnemySprite.choose("bat", "spitwind", false, 0.0, false, 0.5).anim).is_equal("spit")
	assert_str(EnemySprite.choose("bat", "swoop", true, 1.0, true, 0.0).anim).is_equal("death")

func test_sentry_windups_are_seeked_by_progress() -> void:
	var a := EnemySprite.choose("sentry", "aim", false, 0.0, false, 0.6)
	assert_str(a.anim).is_equal("aim")
	assert_float(a.k).is_equal_approx(0.6, 0.0001)
	assert_str(EnemySprite.choose("sentry", "bash", false, 0.0, false, 0.2).anim).is_equal("bash")
	assert_str(EnemySprite.choose("sentry", "walk", false, 0.0, true, 0.0).anim).is_equal("walk")
	assert_str(EnemySprite.choose("sentry", "walk", false, 0.0, false, 0.0).anim).is_equal("idle")
	assert_str(EnemySprite.choose("sentry", "walk", false, 0.1, true, 0.0).anim).is_equal("hurt")

func test_bloat_swells_on_fuse_and_when_killed() -> void:
	assert_str(EnemySprite.choose("bloat", "approach", false, 0.0, true, 0.0).anim).is_equal("idle")
	assert_str(EnemySprite.choose("bloat", "swell", false, 0.0, false, 0.4).anim).is_equal("swell")
	assert_str(EnemySprite.choose("bloat", "approach", true, 0.0, false, 0.7).anim).is_equal("swell")

func test_every_chosen_animation_has_a_sheet() -> void:
	var want := { "bat": ["fly", "wind", "swoop", "spit", "hurt", "death"],
		"sentry": ["idle", "walk", "aim", "bash", "hurt", "death"], "bloat": ["idle", "swell", "hurt"] }
	for k: String in want:
		assert_bool(EnemySprite.has_kind(k)).is_true()
		var anims: Dictionary = HeroSprite.load_meta(EnemySprite.sheets_json(k)).get("anims", {})
		for a: String in want[k]:
			assert_bool(anims.has(a)).override_failure_message("%s has no sheet %s" % [k, a]).is_true()
