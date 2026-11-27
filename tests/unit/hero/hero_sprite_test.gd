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
	# Default: project setting navi/art/hero_art = "drawn"; rig-inspecting checks keep the rig.
	assert_str(Player.visual_scene_path(PackedStringArray([]))).is_equal(Player.DRAWN_SCENE)
	assert_str(Player.visual_scene_path(PackedStringArray(["--hero-art=drawn"]))).is_equal(Player.DRAWN_SCENE)
	assert_str(Player.visual_scene_path(PackedStringArray(["--hero-shots=/tmp", "--hero-art=drawn"]))).is_equal(Player.DRAWN_SCENE)
	assert_str(Player.visual_scene_path(PackedStringArray(["--base-check=/tmp"]))).is_equal(Player.VISUAL_SCENE)
	assert_str(Player.visual_scene_path(PackedStringArray(["--hero-art=rig"]))).is_equal(Player.VISUAL_SCENE)

func test_every_chosen_animation_has_a_sheet() -> void:
	var meta := HeroSprite.load_meta(HeroSprite.SHEETS_JSON)
	var anims: Dictionary = meta.get("anims", {})
	for a in ["idle", "run", "jump", "fall", "roll", "dash", "strike_1", "strike_2", "strike_3",
			"strike_up", "strike_down", "hurt", "death", "flare"]:
		assert_bool(anims.has(a)).override_failure_message("no sheet for %s" % a).is_true()

func test_drawn_hero_has_every_animation_in_every_tier_with_hand_points() -> void:
	var meta := HeroSprite.load_meta("res://assets/art/sprites/hero_drawn/hero_drawn_sheets.json")
	var anims: Dictionary = meta.get("anims", {})
	for a in ["idle", "run", "jump", "fall", "roll", "dash", "strike_1", "strike_2", "strike_3",
			"strike_up", "strike_down", "hurt", "death", "flare",
			"parry_blade", "parry_hammer", "parry_spear", "parry_staff", "parry_sickles"]:
		assert_bool(anims.has(a)).override_failure_message("no drawn sheet for %s" % a).is_true()
		if not anims.has(a):
			continue
		assert_int((anims[a].hand as Array).size()).is_equal(int(anims[a].frames))
		for t in range(1, 6):
			var path := "res://assets/art/sprites/hero_drawn/t%d/hero_%s.png" % [t, a]
			assert_bool(ResourceLoader.exists(path)).override_failure_message("missing %s" % path).is_true()
	assert_int(int(anims.idle.frames)).is_greater_equal(8)
	assert_int(int(anims.run.frames)).is_equal(8)

func test_parry_pose_picks_parry_frames() -> void:
	var s := { "dead": false, "flare_t": 0.0, "flare_dur": 1.0, "dash_t": 0.0, "dash_dur": 1.0, "rolling": false,
		"atk_t": 0.0, "atk_dur": 1.0, "atk_dir": "side", "combo": 1, "on_floor": true, "vx": 0.0, "vy": 0.0,
		"parry": "parry", "parry_t": 0.18, "parry_window": 0.18 }
	var p := HeroVisual.choose(s)
	assert_str(String(p.anim)).is_equal("parry")
	assert_int(HeroSprite.frame_for_progress(p.k, 5)).is_equal(0)
	s.parry_t = 0.0001
	assert_int(HeroSprite.frame_for_progress(HeroVisual.choose(s).k, 5)).is_equal(2)
	s.parry = "parry_hit"
	assert_int(HeroSprite.frame_for_progress(HeroVisual.choose(s).k, 5)).is_equal(3)
	s.parry = "parry_open"
	assert_int(HeroSprite.frame_for_progress(HeroVisual.choose(s).k, 5)).is_equal(4)
	s.parry = ""
	assert_str(String(HeroVisual.choose(s).anim)).is_equal("idle")

func test_parry_sheet_follows_the_weapon_body() -> void:
	var anims := { "parry_blade": {}, "parry_hammer": {} }
	assert_str(HeroSprite.parry_anim("hammer", anims)).is_equal("parry_hammer")
	assert_str(HeroSprite.parry_anim("", anims)).is_equal("parry_blade")
	assert_str(HeroSprite.parry_anim("spear", {})).is_equal("parry")
