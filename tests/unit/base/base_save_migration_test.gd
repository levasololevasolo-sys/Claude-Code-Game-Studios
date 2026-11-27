## Save version 1 -> 2 (base fields) and the round trip of the new meta fields.
extends GdUnitTestSuite

func test_v1_file_gains_base_fields_and_keeps_old_ones() -> void:
	var v1 := { "version": 1, "meta": { "embers": 77, "runs": 4, "weapons": { "stick": true } }, "run": null }
	var d := SaveFile.migrate(v1)
	assert_int(int(d.version)).is_equal(2)
	assert_int(int(d.meta.embers)).is_equal(77)
	assert_int(int(d.meta.armor.head)).is_equal(0)
	assert_str(String(d.meta.lantern)).is_equal("ring")
	assert_dict(d.meta.story.said).is_empty()

func test_v1_meta_loads_with_armor_at_zero() -> void:
	var m := MetaState.from_dict(SaveFile.migrate({ "version": 1, "meta": { "embers": 5 } }).meta)
	assert_int(DialogueRules.title_of(m.armor)).is_equal(0)
	assert_int(int(m.up.reroll)).is_equal(0)

func test_base_fields_round_trip_through_json() -> void:
	var m := MetaState.new()
	m.armor.torso = 2
	m.armor_pick = { "torso": { "t2": "b" } }
	m.up.second = 1
	m.lanterns = { "ring": true, "beam": true }
	m.lantern = "beam"
	m.story.said["potap_first"] = true
	m.story.visits = 3
	var back := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_int(int(back.armor.torso)).is_equal(2)
	assert_str(String(back.armor_pick.torso.t2)).is_equal("b")
	assert_int(int(back.up.second)).is_equal(1)
	assert_str(back.lantern).is_equal("beam")
	assert_bool(back.story.said.has("potap_first")).is_true()
	assert_int(int(back.story.visits)).is_equal(3)

func test_record_run_counts_enemy_deaths_and_makes_events() -> void:
	var m := MetaState.new()
	m.runs = 1
	var ev := DialogueRules.record_run(m, "dead", { "tier": 1, "killer_id": "crawler" }, {}, { "locations": { "1": "swamp" } })
	var names: Array = ev.map(func(e: Dictionary) -> String: return String(e.event))
	assert_array(names).contains(["death", "first_death", "killed_by"])
	assert_int(int(m.story.killed_by_count.crawler)).is_equal(1)
	assert_str(String(ev[0].location)).is_equal("swamp")
