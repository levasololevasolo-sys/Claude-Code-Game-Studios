## Story memory and line picking outside the base (design/narrative/
## prologue-and-endings.md §1-2, §7; dialogue/bosses.md §0, gods.md §0, hero.md;
## living-world.md §1.2). Pure logic over MetaState / RunState dictionaries and
## the dialogue.json arrays boss_lines, god_lines, hero_lines:
## - run events (rune_first, duo_first, weapon_found, needle_found, win_no_needle)
##   collect in RunState.story_ev and become fresh base events at endRun;
## - base events (embers_spent) wait in meta.story.pending for the next visit;
## - death_streak lives in meta.story.death_streak (save field);
## - choices set one flag forever (§7 table);
## - every finished run leaves a short entry in meta.story.history.
class_name StoryRules
extends RefCounted

## §7: choice id -> option -> flag it sets for good.
const CHOICES: Dictionary = {
	"potap_confess": { "forgive": "potap_forgiven", "silent": "potap_silent" },
	"ofenya_confess": { "tell": "ofenya_told", "keep": "ofenya_kept" },
	"gor_choice": { "free": "gorynych_freed", "kill": "gorynych_killed" },
	"ending": { "cross": "ending_crossed", "stay": "ending_stayed" },
}

# ---------------- events ----------------

## A rune was taken in the run (Events.rune_taken). `god` "" for duos; `slot`
## "duo" counts a union. Appends rune_first (first rune of that god in the save)
## and duo_first (n = distinct unions taken so far) to `run_ev`.
static func note_rune(meta: MetaState, run_ev: Array, id: String, god: String, slot: String) -> void:
	var st := meta.story
	if god != "" and not (st.gods_seen as Dictionary).has(god):
		st.gods_seen[god] = true
		run_ev.append({ "event": "rune_first", "god": god })
	if slot == "duo" and not (st.duos_seen as Dictionary).has(id):
		st.duos_seen[id] = true
		run_ev.append({ "event": "duo_first", "n": (st.duos_seen as Dictionary).size() })

## A weapon dropped for the hero: weapon_found with n = weapons found in the save.
static func note_weapon(meta: MetaState, run_ev: Array, id: String) -> void:
	meta.story.weapons_found = int(meta.story.weapons_found) + 1
	run_ev.append({ "event": "weapon_found", "n": int(meta.story.weapons_found), "weapon": id })

## The needle of Кощей was found (stub: location 5 is not built, nothing calls it yet).
static func note_needle(meta: MetaState, run_ev: Array) -> void:
	meta.story.needles = int(meta.story.needles) + 1
	run_ev.append({ "event": "needle_found", "n": int(meta.story.needles) })

## Embers were spent at the base: the event waits for the next visit.
static func note_embers_spent(meta: MetaState, amount: int) -> void:
	if amount <= 0:
		return
	meta.story.embers_spent = int(meta.story.embers_spent) + 1
	meta.story.embers_spent_total = int(meta.story.embers_spent_total) + amount
	(meta.story.pending as Array).append({ "event": "embers_spent", "n": int(meta.story.embers_spent) })

## endRun part of the story (call after DialogueRules.record_run, which set
## fresh and counted the win): adds the run's events, the waiting base events,
## death_streak (deaths in a row with no boss beaten), win_no_needle and the
## history entry. `run` is RunState.to_dict(). Returns the fresh list.
static func record_run(meta: MetaState, outcome: String, run: Dictionary, max_history: int = 20) -> Array:
	var st := meta.story
	var ev: Array = st.fresh
	ev.append_array(run.get("story_ev", []))
	ev.append_array(st.pending)
	st.pending = []
	var beat := int(run.get("bosses", 0)) > 0
	if outcome == "dead" and not beat:
		st.death_streak = int(st.death_streak) + 1
		ev.append({ "event": "death_streak", "n": int(st.death_streak) })
	elif outcome != "quit":
		st.death_streak = 0
	if outcome == "win" and not bool(run.get("needle", false)):
		st.wins_no_needle = int(st.wins_no_needle) + 1
		ev.append({ "event": "win_no_needle", "n": int(st.wins_no_needle) })
	var hist: Array = st.history
	hist.append({ "run": meta.runs, "outcome": outcome, "tier": int(run.get("tier", 1)),
		"killer": String(run.get("killer_id", "")), "wins": meta.wins,
		"events": ev.map(func(e: Dictionary) -> String: return String(e.event)) })
	while hist.size() > max_history:
		hist.pop_front()
	st.fresh = ev
	return ev

## Sets the flag of `choice` / `option` (§7). False when the pair is unknown.
static func choose(meta: MetaState, choice: String, option: String) -> bool:
	var flag := String((CHOICES.get(choice, {}) as Dictionary).get(option, ""))
	if flag == "":
		return false
	meta.story.flags[flag] = true
	meta.story.said["choice:" + choice] = true
	return true

## True when the choice was already made.
static func chosen(meta: MetaState, choice: String) -> bool:
	return meta.story.said.has("choice:" + choice)

# ---------------- boss lines ----------------

## Context of a boss line: kills (beaten before this fight), deaths to it, ash
## (Пепел level, 0 until it exists), needle, flags, said.
static func boss_ctx(meta: MetaState, boss: String, kills: int, needle: bool = false) -> Dictionary:
	return { "kills": kills, "deaths": int((meta.story.deaths_by as Dictionary).get(boss, 0)),
		"ash": int(meta.story.get("ash", 0)), "needle": needle, "flags": meta.story.flags, "said": meta.story.said }

## bosses.md §0: the line of `boss` for `moment` (intro, hero_death, defeat,
## choice): of the lines whose `when` holds, the most specific (most fields),
## then `once` before repeat, then file order. {} when none.
static func boss_line(bank: Array, boss: String, moment: String, ctx: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_key: Array = []
	for i in bank.size():
		var l: Dictionary = bank[i]
		if String(l.get("boss", "")) != boss or String(l.get("moment", "")) != moment:
			continue
		if not boss_when_ok(l, ctx):
			continue
		var key := [(l.get("when", {}) as Dictionary).size(), 1 if bool(l.get("once", false)) else 0, -i]
		if best_key.is_empty() or _greater(key, best_key):
			best = l
			best_key = key
	return best

## True when `line`'s `when` holds for `ctx` and a once line was not said.
static func boss_when_ok(line: Dictionary, ctx: Dictionary) -> bool:
	if bool(line.get("once", false)) and (ctx.get("said", {}) as Dictionary).has(line.id):
		return false
	var w: Dictionary = line.get("when", {})
	var kills := int(ctx.get("kills", 0))
	var deaths := int(ctx.get("deaths", 0))
	if kills < int(w.get("kills_min", 0)) or (w.has("kills_max") and kills > int(w.kills_max)):
		return false
	if deaths < int(w.get("deaths_min", 0)) or (w.has("deaths_max") and deaths > int(w.deaths_max)):
		return false
	if int(ctx.get("ash", 0)) < int(w.get("ash_min", 0)):
		return false
	if w.has("needle") and bool(w.needle) != bool(ctx.get("needle", false)):
		return false
	var flags: Dictionary = ctx.get("flags", {})
	for f: String in w.get("flags_all", []):
		if not flags.has(f):
			return false
	for f: String in w.get("flags_none", []):
		if flags.has(f):
			return false
	return true

# ---------------- god lines ----------------

## gods.md §0 and the offer: the line a god says over the rune offer.
## ctx: seen (offers of this god before), union (partner god of a union card in
## the offer, "" if none), recent (ids said lately), roll (0..1).
## First time: the god's first line (the bible sample). A union card: the
## partner god answers from its pool. Repeat: a random line of the pool that is
## not in `recent` (the last 3). {} when the pool is empty.
static func god_line(bank: Array, god: String, ctx: Dictionary) -> Dictionary:
	var speaker := god
	var union := String(ctx.get("union", ""))
	if union != "" and union != god:
		speaker = union
	var pool: Array = bank.filter(func(l: Dictionary) -> bool: return String(l.get("god", "")) == speaker)
	if pool.is_empty():
		return {}
	if speaker == god and int(ctx.get("seen", 0)) <= 0:
		return pool[0]
	var recent: Array = ctx.get("recent", [])
	var fresh: Array = pool.filter(func(l: Dictionary) -> bool: return not recent.has(l.id))
	if fresh.is_empty():
		fresh = pool
	var i := clampi(int(floorf(float(ctx.get("roll", 0.0)) * fresh.size())), 0, fresh.size() - 1)
	return fresh[i]

## Records a god line: offers seen per god and the last `keep` ids.
static func note_god_line(meta: MetaState, god: String, line: Dictionary, keep: int = 3) -> void:
	var st := meta.story
	st.god_seen[god] = int((st.god_seen as Dictionary).get(god, 0)) + 1
	if line.is_empty():
		return
	var rec: Array = st.god_recent
	rec.append(String(line.id))
	while rec.size() > keep:
		rec.pop_front()

# ---------------- hero lines ----------------

## hero.md: the hero's line after `key` (an NPC line id, "first_visit:dolya",
## "death_streak", "prologue:old_man", "scene:first_win:2.4"...). `after` may hold
## several keys split by "|". Each line once per save except death_streak.
static func hero_line(bank: Array, key: String, said: Dictionary) -> Dictionary:
	for l: Dictionary in bank:
		var keys := String(l.get("after", "")).split("|")
		if not key in keys:
			continue
		if key != "death_streak" and said.has("hero:" + String(l.id)):
			return {}
		return l
	return {}

## Remembers a hero line as said.
static func note_hero_line(meta: MetaState, line: Dictionary) -> void:
	if not line.is_empty():
		meta.story.said["hero:" + String(line.id)] = true

static func _greater(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false
