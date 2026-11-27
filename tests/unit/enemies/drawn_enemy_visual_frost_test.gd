## Unit tests for the hand-drawn Царство Морены enemies (enemies_drawn_frost.json,
## merged into DrawnEnemyVisual.registry()): every frost kind is listed, each
## state machine maps to its sheets, the cut-limb variants and the fx sprites
## (puddle, wave spike, needle) are on disk.
extends GdUnitTestSuite

const FROST: Array[String] = ["wolf", "jelly", "karachun", "snezhnitsa", "sosulnik", "mara"]
const ROOT: String = "res://assets/art/sprites/enemies_drawn/"


func _kind(k: String) -> Dictionary:
	return (DrawnEnemyVisual.registry().get("kinds", {}) as Dictionary).get(k, {})


func _pick(k: String, st: String, moving: bool = false, arm: bool = false, head: bool = false, dead: bool = false, oneshot: String = "") -> Dictionary:
	var m := _kind(k)
	return DrawnEnemyVisual.choose(m.states, m.anims, st, dead, 0.0, moving, false, "", arm, head, oneshot)


func test_registry_merges_swamp_and_frost_files() -> void:
	assert_bool(DrawnEnemyVisual.has_kind("balvan")).is_true()
	for k in FROST:
		assert_bool(DrawnEnemyVisual.has_kind(k)).override_failure_message(k).is_true()


func test_wolf_crouch_bite_hop() -> void:
	assert_str(String(_pick("wolf", "crouch").anim)).is_equal("windup")
	assert_str(String(_pick("wolf", "crouch").k_stat)).is_equal("crouch")
	assert_str(String(_pick("wolf", "bite").anim)).is_equal("attack")
	assert_str(String(_pick("wolf", "hop").anim)).is_equal("hop")
	assert_str(String(_pick("wolf", "run", true).anim)).is_equal("move")


func test_spirit_and_karachun_specials() -> void:
	assert_str(String(_pick("jelly", "chill_w").anim)).is_equal("windup")
	assert_str(String(_pick("jelly", "drift", false, false, false, false, "attack").anim)).is_equal("attack")
	assert_str(String(_pick("karachun", "slam_wind").anim)).is_equal("windup")
	assert_str(String(_pick("karachun", "slam").anim)).is_equal("attack")
	assert_str(String(_pick("karachun", "poke_wind").anim)).is_equal("poke_wind")
	assert_str(String(_pick("karachun", "poke").anim)).is_equal("poke")
	assert_str(String(_pick("karachun", "recover", false, false, false, false, "slam_end").anim)).is_equal("slam_end")
	assert_str(String(_pick("karachun", "slam_wind", false, true).variant)).is_equal("noarm")


func test_snezhnitsa_sosulnik_mara_states() -> void:
	assert_str(String(_pick("snezhnitsa", "cast").anim)).is_equal("windup")
	assert_str(String(_pick("snezhnitsa", "cast", false, false, true).variant)).is_equal("nohead")
	assert_str(String(_pick("snezhnitsa", "volley").anim)).is_equal("attack")
	for st in ["idle", "hang"]:
		assert_str(String(_pick("sosulnik", st).anim)).is_equal("hang")
	assert_str(String(_pick("sosulnik", "shake").anim)).is_equal("shake")
	assert_str(String(_pick("sosulnik", "fall").anim)).is_equal("fall")
	assert_str(String(_pick("sosulnik", "land").anim)).is_equal("land")
	assert_str(String(_pick("sosulnik", "poke").anim)).is_equal("attack")
	assert_str(String(_pick("mara", "raise_w").anim)).is_equal("raise")
	assert_str(String(_pick("mara", "raise_w", false, true).variant)).is_equal("noarm")
	assert_str(String(_pick("mara", "scratch").anim)).is_equal("attack")
	assert_str(String(_pick("mara", "scratch", false, false, false, true).anim)).is_equal("death")


func test_every_frost_sheet_part_and_fx_exists() -> void:
	for k in FROST:
		var m := _kind(k)
		for a: String in (m.anims as Dictionary).keys():
			var keys: Array[String] = [a]
			for v: String in m.anims[a].variants:
				keys.append(a + "_" + v)
			for key in keys:
				var path := ROOT + "%s/%s_%s.png" % [k, k, key]
				assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		for limb: String in (m.get("parts", {}) as Dictionary).keys():
			assert_bool(ResourceLoader.exists(ROOT + k + "/" + String(m.parts[limb].file))).is_true()
		for fx_name: String in (m.get("fx", {}) as Dictionary).keys():
			assert_bool(ResourceLoader.exists(ROOT + k + "/" + String(m.fx[fx_name].file))).override_failure_message(fx_name).is_true()


func test_fx_lookup_returns_textures() -> void:
	for pair in [["jelly", "puddle"], ["karachun", "spike"], ["snezhnitsa", "needle"]]:
		var f := DrawnEnemyVisual.fx(pair[0], pair[1])
		assert_bool(f.has("tex") and f.tex is Texture2D).override_failure_message(str(pair)).is_true()
	assert_int(int(DrawnEnemyVisual.fx("karachun", "spike").frames)).is_equal(3)
	assert_bool(DrawnEnemyVisual.fx("wolf", "nothing").is_empty()).is_true()
