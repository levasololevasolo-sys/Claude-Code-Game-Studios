## Unit tests for the art-slice sprite visuals: frame picking by move progress,
## the Трясинник state -> animation map, the hero art switch, and that every
## animation HeroVisual.choose() can return has a rendered sheet.
extends GdUnitTestSuite

func test_frame_for_progress_maps_ends_to_first_and_last() -> void:
	assert_int(HeroSprite.frame_for_progress(0.0, 6)).is_equal(0)
	assert_int(HeroSprite.frame_for_progress(0.5, 6)).is_equal(3)
	assert_int(HeroSprite.frame_for_progress(1.0, 6)).is_equal(5)

func test_frame_for_progress_clamps_out_of_range() -> void:
	assert_int(HeroSprite.frame_for_progress(-0.2, 4)).is_equal(0)
	assert_int(HeroSprite.frame_for_progress(1.7, 4)).is_equal(3)

func test_crawler_wind_is_seeked_by_progress() -> void:
	var p := CrawlerSprite.choose("wind", false, 0.0, false, 0.4)
	assert_str(p.anim).is_equal("windup")
	assert_float(p.k).is_equal_approx(0.4, 0.0001)

func test_crawler_dead_beats_everything() -> void:
	assert_str(CrawlerSprite.choose("charge", true, 1.0, true, 0.0).anim).is_equal("death")

func test_crawler_charge_is_attack_and_standing_walk_is_idle() -> void:
	assert_str(CrawlerSprite.choose("charge", false, 0.0, true, 0.0).anim).is_equal("attack")
	assert_str(CrawlerSprite.choose("walk", false, 0.0, false, 0.0).anim).is_equal("idle")
	assert_str(CrawlerSprite.choose("walk", false, 0.0, true, 0.0).anim).is_equal("walk")

func test_hero_art_flag_picks_the_sprite_scene() -> void:
	assert_str(Player.visual_scene_path(PackedStringArray(["--hero-art=sprite"]))).is_equal(Player.SPRITE_SCENE)
	# Default: project setting navi/art/hero_art = "sprite"; rig-inspecting checks keep the rig.
	assert_str(Player.visual_scene_path(PackedStringArray([]))).is_equal(Player.SPRITE_SCENE)
	assert_str(Player.visual_scene_path(PackedStringArray(["--base-check=/tmp"]))).is_equal(Player.VISUAL_SCENE)
	assert_str(Player.visual_scene_path(PackedStringArray(["--hero-art=rig"]))).is_equal(Player.VISUAL_SCENE)

func test_every_chosen_animation_has_a_sheet() -> void:
	var meta := HeroSprite.load_meta(HeroSprite.SHEETS_JSON)
	var anims: Dictionary = meta.get("anims", {})
	for a in ["idle", "run", "jump", "fall", "roll", "dash", "strike_1", "strike_2", "strike_3",
			"strike_up", "strike_down", "hurt", "death", "flare"]:
		assert_bool(anims.has(a)).override_failure_message("no sheet for %s" % a).is_true()
