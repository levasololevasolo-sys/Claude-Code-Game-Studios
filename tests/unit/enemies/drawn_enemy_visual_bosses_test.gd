## Unit tests for the hand-drawn bosses (enemies_drawn_bosses.json): every boss
## state of LairBoss / LikhoBoss / MorenaBoss maps to its own sheet (a wind-up
## sheet per attack, progress-driven by the wind-up stat), the follow-through
## one-shots, the phase-2 "rage" variant, the intro one-shot and that every
## listed sheet exists on disk.
extends GdUnitTestSuite

const BOSSES: Array[String] = ["kikimora", "likho", "morena"]
## Every state each boss script can be in (lair_boss.gd, likho_boss.gd, morena_boss.gd think()).
const STATES := {
	"kikimora": ["idle", "throw_w", "pend_w", "lunge_w", "lunge", "wave_w", "summon_w", "roar"],
	"likho": ["idle", "leap_w", "leap", "gaze_w", "gaze", "lunge_w", "lunge", "woe_w", "summon_w", "roar"],
	"morena": ["idle", "breath_w", "breath", "spears_w", "scythe_w", "scythe", "dive_w", "dive", "stuck", "summon_w",
		"mirror_w", "roar"],
}


func _kind(k: String) -> Dictionary:
	return (DrawnEnemyVisual.registry().get("kinds", {}) as Dictionary).get(k, {})


func _pick(k: String, st: String, dead: bool = false, oneshot: String = "") -> Dictionary:
	var m := _kind(k)
	return DrawnEnemyVisual.choose(m.states, m.anims, st, dead, 0.0, false, st.ends_with("_w"), "", false, false, oneshot)


func test_registry_has_the_three_bosses() -> void:
	for k in BOSSES:
		assert_bool(DrawnEnemyVisual.has_kind(k)).override_failure_message(k).is_true()


func test_every_boss_state_has_its_own_sheet() -> void:
	for k in BOSSES:
		var seen := {}
		for st: String in STATES[k]:
			var a := String(_pick(k, st).anim)
			assert_str(a).override_failure_message("%s %s" % [k, st]).is_not_equal("idle" if st != "idle" else "x")
			seen[a] = true
		assert_int(seen.size()).override_failure_message(k).is_equal((STATES[k] as Array).size())


func test_windups_follow_their_windup_stat() -> void:
	assert_str(String(_pick("kikimora", "pend_w").k_stat)).is_equal("pend_wind")
	assert_str(String(_pick("likho", "gaze_w").k_stat)).is_equal("gaze_wind")
	assert_str(String(_pick("morena", "scythe_w").k_stat)).is_equal("scythe_wind")
	for k in BOSSES:
		var stats: Dictionary = Tune.table("bosses").get(k, {})
		for st: String in STATES[k]:
			var ks := String(_pick(k, st).k_stat)
			if ks != "":
				assert_bool(stats.has(ks)).override_failure_message("%s %s" % [k, ks]).is_true()


func test_follow_through_and_death() -> void:
	assert_str(String(_kind("kikimora").states.throw_w.after)).is_equal("throw")
	assert_str(String(_kind("likho").states.leap.after)).is_equal("land")
	assert_str(String(_kind("morena").states.stuck.after)).is_equal("unstick")
	assert_str(String(_pick("likho", "idle", false, "land").anim)).is_equal("land")
	for k in BOSSES:
		assert_str(String(_pick(k, "lunge", true).anim)).is_equal("death")
		assert_int(int(_kind(k).anims.death.frames)).is_between(8, 12)


func test_rage_variant_only_in_phase_two() -> void:
	var anims: Dictionary = _kind("kikimora").anims
	assert_bool(DrawnEnemyVisual.rage_variant(anims, "pend_w", 2)).is_true()
	assert_bool(DrawnEnemyVisual.rage_variant(anims, "pend_w", 1)).is_false()
	assert_bool(DrawnEnemyVisual.rage_variant(anims, "death", 2)).is_false()
	assert_bool(DrawnEnemyVisual.rage_variant(_kind("balvan").anims, "idle", 2)).is_false()


func test_intro_and_every_sheet_exists() -> void:
	for k in BOSSES:
		var m := _kind(k)
		assert_bool((m.anims as Dictionary).has(String(m.intro))).override_failure_message(k).is_true()
		for a: String in m.anims:
			var p := DrawnEnemyVisual.ROOT + "%s/%s_%s.png" % [k, k, a]
			assert_bool(ResourceLoader.exists(p)).override_failure_message(p).is_true()
			for v: String in (m.anims[a] as Dictionary).get("variants", []):
				var pv := DrawnEnemyVisual.ROOT + "%s/%s_%s_%s.png" % [k, k, a, v]
				assert_bool(ResourceLoader.exists(pv)).override_failure_message(pv).is_true()
