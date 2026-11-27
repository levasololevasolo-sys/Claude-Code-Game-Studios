## Unit tests for DrawnEnemyVisual (hand-drawn Swamp enemies): the state ->
## sheet map from the registry, cut-limb variants, the two deaths, and that every
## sheet / part the registry lists is on disk. LimbPart takes the part sprite.
extends GdUnitTestSuite

const SWAMP: Array[String] = ["balvan", "crawler", "thrower", "bloat", "shishiga", "bognitsa", "vodyanitsa"]


func _kind(k: String) -> Dictionary:
	return (DrawnEnemyVisual.registry().get("kinds", {}) as Dictionary).get(k, {})


func _pick(k: String, st: String, moving: bool = false, arm: bool = false, head: bool = false, dead: bool = false, part: String = "") -> Dictionary:
	var m := _kind(k)
	return DrawnEnemyVisual.choose(m.states, m.anims, st, dead, 0.0, moving, false, part, arm, head, "")


func test_all_swamp_kinds_have_drawn_art() -> void:
	for k in SWAMP:
		assert_bool(DrawnEnemyVisual.has_kind(k)).override_failure_message(k).is_true()


func test_balvan_states_map_to_windup_and_attack_by_progress() -> void:
	var w := _pick("balvan", "wind")
	assert_str(String(w.anim)).is_equal("windup")
	assert_str(String(w.k_stat)).is_equal("wind")
	assert_str(String(_pick("balvan", "swing").anim)).is_equal("attack")
	assert_str(String(_pick("balvan", "walk", true).anim)).is_equal("move")
	assert_str(String(_pick("balvan", "walk", false).anim)).is_equal("idle")


func test_cut_limbs_pick_one_armed_and_headless_sheets() -> void:
	assert_str(String(_pick("balvan", "wind", false, true).variant)).is_equal("noarm")
	assert_str(String(_pick("vodyanitsa", "song", false, false, true).variant)).is_equal("nohead")
	# The crawler has no live headless frames (its head flies only in death).
	assert_str(String(_pick("crawler", "walk", true, false, true).variant)).is_equal("")


func test_two_deaths_plain_and_severed() -> void:
	assert_str(String(_pick("balvan", "swing", false, false, false, true).anim)).is_equal("death")
	assert_str(String(_pick("balvan", "swing", false, false, false, true, "head").anim)).is_equal("death_sever_head")
	assert_str(String(_pick("thrower", "aim", false, true, false, true).anim)).is_equal("death_sever_arm")


func test_special_states_have_their_own_sheets() -> void:
	assert_str(String(_pick("bognitsa", "hide").anim)).is_equal("hummock")
	assert_str(String(_pick("bognitsa", "rise").anim)).is_equal("surface")
	assert_str(String(_pick("shishiga", "cling").anim)).is_equal("cling")
	assert_str(String(_pick("crawler", "charge").anim)).is_equal("charge")
	assert_str(String(_pick("bloat", "swell").anim)).is_equal("inflate")


func test_every_sheet_and_part_in_the_registry_exists() -> void:
	for k in SWAMP:
		var m := _kind(k)
		for a: String in (m.anims as Dictionary).keys():
			var keys: Array[String] = [a]
			for v: String in m.anims[a].variants:
				keys.append(a + "_" + v)
			for key in keys:
				var path := DrawnEnemyVisual.ROOT + "%s/%s_%s.png" % [k, k, key]
				assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		for limb: String in (m.parts as Dictionary).keys():
			assert_bool(ResourceLoader.exists(DrawnEnemyVisual.ROOT + "%s/%s" % [k, m.parts[limb].file])).is_true()


func test_limb_part_uses_the_sprite_mirrored_by_face() -> void:
	var p: LimbPart = auto_free(LimbPart.new())
	var tex := PlaceholderTexture2D.new()
	p.use_sprite(tex, Vector2(4, 5), 0.5, -1)
	assert_object(p.tex).is_same(tex)
	assert_vector(p.tex_scale).is_equal(Vector2(-0.5, 0.5))
	assert_vector(p.tex_pivot).is_equal(Vector2(4, 5))


func test_every_weapon_body_has_a_drawn_sprite() -> void:
	for b in ["stick", "blade", "spear", "hammer", "staff", "sickles"]:
		assert_bool(Player.weapon_art(b).is_empty()).override_failure_message(b).is_false()
