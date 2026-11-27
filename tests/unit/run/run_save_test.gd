## Save round-trip (ADR-0003 § Validation Criteria): MetaState and RunState
## to_dict/from_dict, old files without new fields, RunRng states, RunBuild
## snapshot, and one write/read through SaveFile into user:// (temp + rename).
extends GdUnitTestSuite

const PATH := "user://test_run_save/save.json"

func after_test() -> void:
	for f in ["save.json", "save.tmp", "save.bad.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_run_save/" + f))

func _run() -> RunState:
	var r := RunState.new()
	r.run_seed = 12345
	r.tier = 2
	r.room_k = 3
	r.stage = "haven"
	r.hp = 61.5
	r.embers = 87
	r.res = { "gears": 6, "cores": 1 }
	r.since_god = 1
	r.gap_need = 2
	r.reward = { "type": "god", "god": "perun" }
	r.build = RunBuild.from_arg("svarog_s:2,edge").to_dict()
	r.killed_by = "Трясинник"
	return r

func test_run_state_round_trip() -> void:
	var r := _run()
	assert_dict(RunState.from_dict(r.to_dict()).to_dict()).is_equal(r.to_dict())

func test_run_state_round_trip_through_json() -> void:
	var r := _run()
	var back: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	assert_dict(RunState.from_dict(back).to_dict()).is_equal(r.to_dict())

func test_meta_round_trip_keeps_unknown_fields() -> void:
	var m := MetaState.from_dict({ "embers": 310, "runs": 4, "res": { "gears": 9 }, "bosses": { "kikimora": 2 }, "lanterns": { "brass": true } })
	var d := m.to_dict()
	assert_int(int(d.embers)).is_equal(310)
	assert_int(int(d.res.gears)).is_equal(9)
	assert_int(int(d.res.pearls)).is_equal(0)
	assert_dict(d.lanterns).is_equal({ "brass": true })
	assert_int(m.bosses_beaten()).is_equal(2)
	assert_dict(MetaState.from_dict(d).to_dict()).is_equal(d)

func test_old_file_without_fields_loads_defaults() -> void:
	var m := MetaState.from_dict({ "embers": 5 })
	assert_int(m.runs).is_equal(0)
	assert_dict(m.res).is_equal(MetaState.defaults().res)
	var r := RunState.from_dict({ "run_seed": 7 })
	assert_int(r.run_seed).is_equal(7)
	assert_int(r.gap_need).is_equal(1)
	assert_str(r.stage).is_equal("room")

func test_run_build_snapshot_round_trip() -> void:
	var b := RunBuild.from_arg("svarog_s:2,perun_d,edge:3,duo_storm")
	var c := RunBuild.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	assert_dict(c.to_dict()).is_equal(b.to_dict())
	assert_int(c.level("edge")).is_equal(3)
	assert_array(c.raisable()).is_equal(["perun_d", "svarog_s"])

func test_rng_states_continue_the_same_sequence() -> void:
	var a := RunRng.new(99)
	a.stream("doors").randi()
	a.stream("loot").randf()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.save_states()))
	var b := RunRng.new(99)
	b.load_states(saved)
	for i in 10:
		assert_int(b.stream("doors").randi()).is_equal(a.stream("doors").randi())
		assert_int(b.stream("loot").randi()).is_equal(a.stream("loot").randi())

func test_streams_are_independent() -> void:
	var a := RunRng.new(5)
	var b := RunRng.new(5)
	b.stream("loot").randi()
	assert_int(a.stream("doors").randi()).is_equal(b.stream("doors").randi())

func test_save_file_write_read_round_trip() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_run_save"))
	var data := { "meta": MetaState.from_dict({ "embers": 42 }).to_dict(), "run": _run().to_dict() }
	assert_bool(SaveFile.write(PATH, data)).is_true()
	assert_bool(SaveFile.write(PATH, data)).is_true()
	assert_bool(FileAccess.file_exists("user://test_run_save/save.tmp")).is_false()
	var d := SaveFile.read(PATH)
	assert_int(int(d.version)).is_equal(SaveFile.VERSION)
	assert_int(MetaState.from_dict(d.meta).embers).is_equal(42)
	assert_dict(RunState.from_dict(d.run).to_dict()).is_equal(_run().to_dict())

func test_broken_or_newer_file_reads_empty() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_run_save"))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	assert_dict(SaveFile.read(PATH)).is_empty()
	assert_bool(FileAccess.file_exists("user://test_run_save/save.bad.json")).is_true()
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": SaveFile.VERSION + 1, "meta": { "embers": 9 } }))
	f.close()
	assert_dict(SaveFile.read(PATH)).is_empty()
