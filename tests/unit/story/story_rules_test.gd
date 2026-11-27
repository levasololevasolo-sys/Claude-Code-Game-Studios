## StoryRules (prologue-and-endings §7, dialogue/bosses.md §0, gods.md §0,
## hero.md): event recording, choice flags, god line selection, boss line
## variants, hero lines, save migration 2 -> 3.
extends GdUnitTestSuite

const GODS: Array = [
	{ "id": "svarog_1", "god": "svarog", "ru": "s1" },
	{ "id": "svarog_2", "god": "svarog", "ru": "s2" },
	{ "id": "svarog_3", "god": "svarog", "ru": "s3" },
	{ "id": "svarog_4", "god": "svarog", "ru": "s4" },
	{ "id": "perun_1", "god": "perun", "ru": "p1" },
	{ "id": "perun_2", "god": "perun", "ru": "p2" },
]

const BOSS: Array = [
	{ "id": "k_intro_1", "boss": "kik", "moment": "intro", "ru": "first", "once": true, "when": { "kills_max": 0, "deaths_max": 0 } },
	{ "id": "k_intro_alive", "boss": "kik", "moment": "intro", "ru": "alive", "once": true, "when": { "kills_min": 1, "kills_max": 1 } },
	{ "id": "k_intro_3", "boss": "kik", "moment": "intro", "ru": "deaths3", "once": false, "when": { "deaths_min": 3 } },
	{ "id": "k_intro_2b", "boss": "kik", "moment": "intro", "ru": "kills2", "once": false, "when": { "kills_min": 2 } },
	{ "id": "k_intro_2", "boss": "kik", "moment": "intro", "ru": "plain", "once": false, "when": {} },
	{ "id": "k_def_1", "boss": "kik", "moment": "defeat", "ru": "def1", "once": false, "when": { "kills_max": 0 } },
	{ "id": "k_def_2", "boss": "kik", "moment": "defeat", "ru": "def2", "once": false, "when": {} },
	{ "id": "k_freed", "boss": "kik", "moment": "intro", "ru": "freed", "once": false, "when": { "flags_all": ["gorynych_freed"] } },
]

func _ctx(kills: int, deaths: int, said: Dictionary = {}, flags: Dictionary = {}) -> Dictionary:
	return { "kills": kills, "deaths": deaths, "ash": 0, "needle": false, "flags": flags, "said": said }

# ---------------- events ----------------

func test_first_rune_of_a_god_records_rune_first_once() -> void:
	var m := MetaState.new()
	var ev: Array = []
	StoryRules.note_rune(m, ev, "svarog_s", "svarog", "strike")
	StoryRules.note_rune(m, ev, "svarog_d", "svarog", "dash")
	assert_int(ev.size()).is_equal(1)
	assert_str(String(ev[0].event)).is_equal("rune_first")
	assert_str(String(ev[0].god)).is_equal("svarog")

func test_new_duos_count_up_and_a_repeat_duo_is_silent() -> void:
	var m := MetaState.new()
	var ev: Array = []
	StoryRules.note_rune(m, ev, "duo_storm", "", "duo")
	StoryRules.note_rune(m, ev, "duo_storm", "", "duo")
	StoryRules.note_rune(m, ev, "duo_fire", "", "duo")
	assert_array(ev.map(func(e: Dictionary) -> int: return int(e.n))).is_equal([1, 2])

func test_weapon_found_counts_across_runs() -> void:
	var m := MetaState.new()
	m.story.weapons_found = 9
	var ev: Array = []
	StoryRules.note_weapon(m, ev, "blade")
	assert_int(int(ev[0].n)).is_equal(10)

func test_death_streak_grows_on_deaths_and_resets_on_a_boss_kill() -> void:
	var m := MetaState.new()
	for i in 3:
		m.story.fresh = []
		StoryRules.record_run(m, "dead", { "bosses": 0 })
	assert_int(int(m.story.death_streak)).is_equal(3)
	var names: Array = (m.story.fresh as Array).map(func(e: Dictionary) -> String: return String(e.event))
	assert_array(names).contains(["death_streak"])
	m.story.fresh = []
	StoryRules.record_run(m, "dead", { "bosses": 1 })
	assert_int(int(m.story.death_streak)).is_equal(0)

func test_run_events_and_pending_embers_join_the_fresh_list() -> void:
	var m := MetaState.new()
	StoryRules.note_embers_spent(m, 30)
	m.story.fresh = [{ "event": "death" }]
	var ev := StoryRules.record_run(m, "dead", { "bosses": 0, "story_ev": [{ "event": "rune_first", "god": "perun" }] })
	var names: Array = ev.map(func(e: Dictionary) -> String: return String(e.event))
	assert_array(names).contains_exactly(["death", "rune_first", "embers_spent", "death_streak"])
	assert_array(m.story.pending).is_empty()
	assert_int(int(m.story.embers_spent_total)).is_equal(30)

func test_win_without_needle_records_win_no_needle_and_history() -> void:
	var m := MetaState.new()
	m.wins = 1
	m.story.fresh = [{ "event": "win", "n": 1 }]
	StoryRules.record_run(m, "win", { "bosses": 1, "needle": false, "tier": 3 })
	var hist: Array = m.story.history
	assert_int(int(m.story.wins_no_needle)).is_equal(1)
	assert_int(hist.size()).is_equal(1)
	assert_str(String(hist[0].outcome)).is_equal("win")
	assert_array(hist[0].events).contains(["win", "win_no_needle"])

func test_history_keeps_only_the_last_entries() -> void:
	var m := MetaState.new()
	for i in 5:
		m.story.fresh = []
		StoryRules.record_run(m, "home", {}, 3)
	assert_int((m.story.history as Array).size()).is_equal(3)

func test_choice_sets_its_flag_once_and_unknown_pairs_fail() -> void:
	var m := MetaState.new()
	assert_bool(StoryRules.choose(m, "potap_confess", "forgive")).is_true()
	assert_bool(m.story.flags.has("potap_forgiven")).is_true()
	assert_bool(StoryRules.chosen(m, "potap_confess")).is_true()
	assert_bool(StoryRules.choose(m, "potap_confess", "dance")).is_false()
	StoryRules.choose(m, "ending", "cross")
	assert_bool(m.story.flags.has("ending_crossed")).is_true()

# ---------------- god lines ----------------

func test_first_offer_of_a_god_says_its_first_line() -> void:
	var l := StoryRules.god_line(GODS, "svarog", { "seen": 0, "recent": [], "roll": 0.99 })
	assert_str(String(l.id)).is_equal("svarog_1")

func test_repeat_offer_skips_the_recent_lines() -> void:
	var recent := ["svarog_1", "svarog_2", "svarog_3"]
	for roll: float in [0.0, 0.5, 0.99]:
		var l := StoryRules.god_line(GODS, "svarog", { "seen": 4, "recent": recent, "roll": roll })
		assert_str(String(l.id)).is_equal("svarog_4")

func test_union_card_lets_the_partner_god_answer() -> void:
	var l := StoryRules.god_line(GODS, "svarog", { "seen": 0, "union": "perun", "recent": [], "roll": 0.0 })
	assert_str(String(l.god)).is_equal("perun")

func test_note_god_line_keeps_the_last_three() -> void:
	var m := MetaState.new()
	for i in 4:
		StoryRules.note_god_line(m, "svarog", GODS[i], 3)
	assert_array(m.story.god_recent).is_equal(["svarog_2", "svarog_3", "svarog_4"])
	assert_int(int(m.story.god_seen.svarog)).is_equal(4)

func test_unknown_god_has_no_line() -> void:
	assert_dict(StoryRules.god_line(GODS, "veles", { "seen": 0 })).is_empty()

# ---------------- boss lines ----------------

func test_first_meeting_takes_the_once_first_line() -> void:
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "intro", _ctx(0, 0)).ru)).is_equal("first")

func test_after_the_first_kill_the_boss_asks_why_alive_once() -> void:
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "intro", _ctx(1, 0)).ru)).is_equal("alive")
	var said := { "k_intro_alive": true }
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "intro", _ctx(1, 0, said)).ru)).is_equal("plain")

func test_repeat_visits_pick_by_kill_and_death_counts() -> void:
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "intro", _ctx(2, 0)).ru)).is_equal("kills2")
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "intro", _ctx(0, 3, { "k_intro_1": true })).ru)).is_equal("deaths3")

func test_defeat_line_differs_on_the_first_and_later_kills() -> void:
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "defeat", _ctx(0, 0)).ru)).is_equal("def1")
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "defeat", _ctx(3, 0)).ru)).is_equal("def2")

func test_flag_lines_need_their_flag() -> void:
	var said := { "k_intro_1": true }
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "intro", _ctx(0, 0, said)).ru)).is_equal("plain")
	assert_str(String(StoryRules.boss_line(BOSS, "kik", "intro", _ctx(0, 0, said, { "gorynych_freed": true })).ru)).is_equal("freed")

func test_unknown_moment_gives_no_line() -> void:
	assert_dict(StoryRules.boss_line(BOSS, "kik", "rage", _ctx(0, 0))).is_empty()

# ---------------- hero lines ----------------

func test_hero_line_matches_any_after_key_and_is_said_once() -> void:
	var bank := [{ "id": "h1", "after": "a|b", "ru": "x" }, { "id": "h2", "after": "death_streak", "ru": "y" }]
	assert_str(String(StoryRules.hero_line(bank, "b", {}).id)).is_equal("h1")
	assert_dict(StoryRules.hero_line(bank, "b", { "hero:h1": true })).is_empty()
	assert_str(String(StoryRules.hero_line(bank, "death_streak", { "hero:h2": true }).id)).is_equal("h2")

func test_hero_bark_waits_out_the_cooldown_and_never_speaks_in_a_fight() -> void:
	assert_bool(HeroBark.may_say(10000, 0, 20.0, false)).is_false()
	assert_bool(HeroBark.may_say(25000, 0, 20.0, false)).is_true()
	assert_bool(HeroBark.may_say(25000, 0, 20.0, true)).is_false()
	assert_bool(HeroBark.may_say(1000, 0, 20.0, false, true)).is_true()

# ---------------- save migration ----------------

func test_v2_save_gains_story_fields_and_counts_the_prologue_seen() -> void:
	var v2 := { "version": 2, "meta": { "runs": 3, "story": { "said": { "x": true }, "flags": {} } },
		"run": { "tier": 2 } }
	var d := SaveFile.migrate(v2)
	assert_int(int(d.version)).is_equal(3)
	assert_bool(d.meta.story.said.has("x")).is_true()
	assert_int(int(d.meta.story.death_streak)).is_equal(0)
	assert_array(d.meta.story.history).is_empty()
	assert_bool(d.meta.story.flags.has("prologue_seen")).is_true()
	assert_array(d.run.story_ev).is_empty()

func test_v2_save_without_runs_still_plays_the_prologue() -> void:
	var d := SaveFile.migrate({ "version": 2, "meta": { "runs": 0, "story": {} }, "run": null })
	assert_bool(d.meta.story.flags.has("prologue_seen")).is_false()

func test_story_fields_round_trip_through_json() -> void:
	var m := MetaState.new()
	m.story.death_streak = 4
	m.story.gods_seen = { "perun": true }
	m.story.history = [{ "run": 1, "outcome": "dead" }]
	var back := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_int(int(back.story.death_streak)).is_equal(4)
	assert_bool(back.story.gods_seen.has("perun")).is_true()
	assert_int((back.story.history as Array).size()).is_equal(1)

func test_run_story_fields_round_trip() -> void:
	var r := RunState.new()
	r.story_ev = [{ "event": "weapon_found", "n": 2 }]
	r.needle = true
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_bool(back.needle).is_true()
	assert_int(int(back.story_ev[0].n)).is_equal(2)

func test_real_bank_gives_every_built_boss_a_first_intro() -> void:
	var bank: Array = Tune.table("dialogue").get("boss_lines", [])
	for b: String in ["kikimora", "likho", "morena"]:
		assert_str(String(StoryRules.boss_line(bank, b, "intro", _ctx(0, 0)).get("ru", ""))).is_not_empty()
