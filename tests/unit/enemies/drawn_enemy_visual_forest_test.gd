## Unit tests for the hand-drawn Тёмный бор enemies (enemies_drawn_forest.json):
## the registry merge, each kind's state -> sheet map (specials: Аука's
## vanish / appear, the Лешачонок's burrow and mound, the bat's dive and spit,
## the Сучковик's throw, the Лесавка's whistle and flee), cut-head variants,
## the shield block one-shot and that every listed sheet / part / spear exists.
extends GdUnitTestSuite

const FOREST: Array[String] = ["ringer", "rootling", "bat", "sentry", "suchkovik", "lesavka"]


func _kind(k: String) -> Dictionary:
	return (DrawnEnemyVisual.registry().get("kinds", {}) as Dictionary).get(k, {})


func _pick(k: String, st: String, moving: bool = false, arm: bool = false, head: bool = false, dead: bool = false, part: String = "") -> Dictionary:
	var m := _kind(k)
	return DrawnEnemyVisual.choose(m.states, m.anims, st, dead, 0.0, moving, false, part, arm, head, "")


func test_registry_merges_swamp_and_forest_files() -> void:
	assert_bool(DrawnEnemyVisual.has_kind("balvan")).is_true()
	for k in FOREST:
		assert_bool(DrawnEnemyVisual.has_kind(k)).override_failure_message(k).is_true()


func test_ringer_call_vanish_appear_swipe() -> void:
	assert_str(String(_pick("ringer", "call").anim)).is_equal("call")
	var g := _pick("ringer", "gone")
	assert_str(String(g.anim)).is_equal("vanish")
	assert_str(String(g.k_stat)).is_equal("gone")
	assert_str(String(_pick("ringer", "appear").anim)).is_equal("appear")
	assert_str(String(_pick("ringer", "swipe").anim)).is_equal("attack")
	assert_str(String(_pick("ringer", "appear", false, true).variant)).is_equal("noarm")


func test_rootling_burrow_under_mound_emerge() -> void:
	assert_str(String(_pick("rootling", "dig").anim)).is_equal("burrow")
	assert_str(String(_pick("rootling", "under").anim)).is_equal("under")
	assert_str(String(_pick("rootling", "rise_w").anim)).is_equal("windup")
	assert_str(String(_pick("rootling", "burst").anim)).is_equal("attack")
	# The mound has no headless frames.
	assert_str(String(_pick("rootling", "under", false, false, true).variant)).is_equal("")


func test_bat_dive_and_spit() -> void:
	assert_str(String(_pick("bat", "hover").anim)).is_equal("idle")
	assert_str(String(_pick("bat", "swoop").anim)).is_equal("dive")
	assert_str(String(_pick("bat", "spitwind").anim)).is_equal("spit")
	assert_str(String(_pick("bat", "wind").k_stat)).is_equal("wind")


func test_sentry_bash_and_block() -> void:
	assert_str(String(_pick("sentry", "bash").anim)).is_equal("windup")
	assert_str(String(_pick("sentry", "recover").anim)).is_equal("attack")
	assert_str(String(_kind("sentry").get("block", ""))).is_equal("block")
	var m := _kind("sentry")
	var b := DrawnEnemyVisual.choose(m.states, m.anims, "walk", false, 0.0, false, false, "", false, true, "block")
	assert_str(String(b.anim)).is_equal("block")
	assert_str(String(b.variant)).is_equal("nohead")


func test_suchkovik_throw_and_spear() -> void:
	assert_str(String(_pick("suchkovik", "wind").anim)).is_equal("windup")
	assert_str(String(_pick("suchkovik", "recover").anim)).is_equal("throw")
	var pr: Dictionary = _kind("suchkovik").get("projectile", {})
	assert_bool(pr.is_empty()).is_false()
	assert_bool(ResourceLoader.exists(DrawnEnemyVisual.ROOT + "suchkovik/" + String(pr.file))).is_true()
	assert_bool(ResourceLoader.exists(DrawnEnemyVisual.ROOT + "suchkovik/" + String(pr.stuck))).is_true()


func test_lesavka_whistle_flee_bite() -> void:
	assert_str(String(_pick("lesavka", "whistle").anim)).is_equal("whistle")
	assert_str(String(_pick("lesavka", "run", true).anim)).is_equal("flee")
	assert_str(String(_pick("lesavka", "run", false).anim)).is_equal("idle")
	assert_str(String(_pick("lesavka", "bite").anim)).is_equal("attack")
	assert_str(String(_pick("lesavka", "bite", false, false, false, true, "head").anim)).is_equal("death_sever_head")


func test_every_forest_sheet_and_part_exists() -> void:
	for k in FOREST:
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
