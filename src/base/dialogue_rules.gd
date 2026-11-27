## Picks what the base NPCs say (design/narrative/living-world.md §1.2-1.5):
## event keys from the last run (fresh) and the save (persistent), priority
## lanes, the one-event rule (-chorus_penalty for a fresh event another NPC
## already took, unless `chorus`), specificity and file order as tie breaks,
## `once` lines remembered in meta.story.said, `sets` flags, `after` chains,
## `every` cooldowns for repeat lines, and ambient lines resting ambient_memory
## visits. Pure logic over dictionaries: the base feeds MetaState and the data.
class_name DialogueRules
extends RefCounted

## Fields a `when` block may hold (living-world §1.5, plus `every`).
const WHEN_KEYS: Array[String] = ["event", "location", "boss", "enemy", "god", "n_min", "n_max",
	"title_min", "title_max", "ash_min", "needle", "kills_min", "kills_max", "deaths_min",
	"deaths_max", "flags_all", "flags_none", "every"]
## Events that only exist in the save, not in the last run.
const PERSISTENT: Array[String] = ["runs", "title", "ambient"]

## dialogue.json, parsed.
var data: Dictionary = {}
## The `lines` array, file order.
var lines: Array = []

## Rules over a parsed dialogue.json. Unknown `when` fields are logged errors.
static func make(p_data: Dictionary) -> DialogueRules:
	var r := DialogueRules.new()
	r.data = p_data
	r.lines = p_data.get("lines", [])
	for l: Dictionary in r.lines:
		for k: String in (l.get("when", {}) as Dictionary):
			if not k in WHEN_KEYS:
				push_error("DialogueRules: line %s has unknown when field '%s'" % [l.get("id", "?"), k])
	return r

## Lowest bought armor tier = the hero's title tier (armor §3.4).
static func title_of(armor: Dictionary) -> int:
	if armor.is_empty():
		return 0
	var t := 99
	for k: String in armor:
		t = mini(t, int(armor[k]))
	return t

## endRun hook: turns a finished run into fresh events in meta.story.fresh and
## updates the death counters (living-world §1.2). `run` is RunState.to_dict(),
## `bosses_before` the meta.bosses of the run's start.
static func record_run(meta: MetaState, outcome: String, run: Dictionary, bosses_before: Dictionary, p_data: Dictionary) -> Array:
	var st := meta.story
	var ev: Array = []
	var locs: Dictionary = p_data.get("locations", {})
	var loc := String(locs.get(str(int(run.get("tier", 1))), ""))
	if outcome == "dead":
		var killer := String(run.get("killer_id", ""))
		ev.append({ "event": "death", "location": loc, "killer": killer })
		if meta.runs == 1:
			ev.append({ "event": "first_death" })
		if killer != "":
			var boss_ids: Array = []
			for id: String in Tune.table("locations"):
				var row: Variant = Tune.table("locations")[id]
				if row is Dictionary:
					boss_ids.append(String(row.get("boss", "")))
			var key := "deaths_by" if killer in boss_ids else "killed_by_count"
			var counts: Dictionary = st[key]
			counts[killer] = int(counts.get(killer, 0)) + 1
			if key == "deaths_by":
				ev.append({ "event": "death_to_boss", "boss": killer, "n": counts[killer] })
			else:
				ev.append({ "event": "killed_by", "enemy": killer, "n": counts[killer] })
	elif outcome == "home":
		ev.append({ "event": "return_home", "location": loc })
	elif outcome == "win":
		meta.wins += 1
		ev.append({ "event": "win", "n": meta.wins })
	for b: String in meta.bosses:
		if int(meta.bosses[b]) > int(bosses_before.get(b, 0)):
			ev.append({ "event": "boss_beaten", "boss": b, "n": int(meta.bosses[b]) })
	st.fresh = ev
	return ev

## Every event of this visit: fresh ones, first_visit, then the persistent ones.
static func events_of(meta: MetaState) -> Array:
	var st := meta.story
	var ev: Array = []
	for e: Dictionary in st.get("fresh", []):
		var c := e.duplicate()
		c["fresh"] = true
		ev.append(c)
	if int(st.get("visits", 0)) == 0:
		ev.append({ "event": "first_visit", "fresh": true })
	ev.append({ "event": "runs", "n": meta.runs })
	ev.append({ "event": "title", "n": title_of(meta.armor) })
	ev.append({ "event": "ambient" })
	return ev

## Index in `events` of the event `line` answers, -1 when its conditions fail.
static func match_event(line: Dictionary, events: Array, meta: MetaState) -> int:
	var w: Dictionary = line.get("when", {})
	var st := meta.story
	if bool(line.get("once", false)) and st.said.has(line.id):
		return -1
	for a: String in line.get("after", []):
		if not st.said.has(a):
			return -1
	var title := title_of(meta.armor)
	if title < int(w.get("title_min", -1)) or (w.has("title_max") and title > int(w.title_max)):
		return -1
	for f: String in w.get("flags_all", []):
		if not st.flags.has(f):
			return -1
	for f: String in w.get("flags_none", []):
		if st.flags.has(f):
			return -1
	if w.has("boss"):
		var kills := int(meta.bosses.get(w.boss, 0))
		var deaths := int((st.deaths_by as Dictionary).get(w.boss, 0))
		if kills < int(w.get("kills_min", 0)) or (w.has("kills_max") and kills > int(w.kills_max)):
			return -1
		if deaths < int(w.get("deaths_min", 0)) or (w.has("deaths_max") and deaths > int(w.deaths_max)):
			return -1
	if w.has("every") and (st.last as Dictionary).has(line.id):
		if int(st.visits) - int(st.last[line.id]) < int(w.every):
			return -1
	for i in events.size():
		var e: Dictionary = events[i]
		if String(e.event) != String(w.get("event", "ambient")):
			continue
		var ok := true
		for k: String in ["location", "boss", "enemy", "god"]:
			if w.has(k) and String(e.get(k, "")) != String(w[k]):
				ok = false
		var n := int(e.get("n", 0))
		if w.has("n_min") and n < int(w.n_min):
			ok = false
		if w.has("n_max") and n > int(w.n_max):
			ok = false
		if ok:
			return i
	return -1

## Chooses one line per NPC of `order` for this visit (§1.3 steps 1-5).
## Returns npc -> line (Dictionary; npcs without any line are left out). Does
## not change meta: apply_visit() records the choice.
func pick_visit(order: Array, meta: MetaState) -> Dictionary:
	var events := events_of(meta)
	var claimed: Dictionary = {}
	var out: Dictionary = {}
	var penalty := int(data.get("chorus_penalty", 30))
	var recent: Array = meta.story.get("ambient_recent", [])
	for npc: String in order:
		var best: Dictionary = {}
		var best_key: Array = []
		var best_ev := -1
		var ambient: Array = []
		for idx in lines.size():
			var l: Dictionary = lines[idx]
			if String(l.npc) != npc:
				continue
			var ei := match_event(l, events, meta)
			if ei < 0:
				continue
			if String(events[ei].event) == "ambient":
				ambient.append(l)
				continue
			var pr := int(l.get("priority", 0))
			if bool(events[ei].get("fresh", false)) and claimed.has(ei) and claimed[ei] != npc and not bool(l.get("chorus", false)):
				pr -= penalty
			var key := [pr, (l.get("when", {}) as Dictionary).size(), -idx]
			if best_key.is_empty() or _greater(key, best_key):
				best = l
				best_key = key
				best_ev = ei
		if best.is_empty() and not ambient.is_empty():
			best = ambient[0]
			for l: Dictionary in ambient:
				if not recent.has(l.id):
					best = l
					break
		if best.is_empty():
			continue
		if best_ev >= 0 and bool(events[best_ev].get("fresh", false)):
			claimed[best_ev] = npc
		out[npc] = best
	return out

## Records a visit's choice: once ids into said, flags, repeat cooldowns, the
## ambient memory; counts the visit and burns the fresh events (§1.3 steps 4, 7).
func apply_visit(picked: Dictionary, meta: MetaState) -> void:
	var st := meta.story
	var mem := int(data.get("ambient_memory", 3))
	for npc: String in picked:
		var l: Dictionary = picked[npc]
		if bool(l.get("once", false)):
			st.said[l.id] = true
		for f: String in l.get("sets", []):
			st.flags[f] = true
		if (l.get("when", {}) as Dictionary).has("every"):
			st.last[l.id] = int(st.visits)
		if String((l.get("when", {}) as Dictionary).get("event", "")) == "ambient":
			var rec: Array = st.ambient_recent
			rec.append(l.id)
			while rec.size() > mem:
				rec.pop_front()
	st.visits = int(st.visits) + 1
	st.fresh = []

## True when the NPC's line lights the spark (§1.3 step 6).
func spark(line: Dictionary) -> bool:
	return not line.is_empty() and int(line.get("priority", 0)) >= int(data.get("spark_min", 40))

## Russian text with the named substitutions {title}, {runs}, {hero}.
static func text_of(line: Dictionary, meta: MetaState, titles: Array) -> String:
	var t := title_of(meta.armor)
	var title := String(titles[t]) if t < titles.size() else ""
	var hero := "Ждан" if meta.story.flags.has("hero_named") else "Нитка"
	return String(line.get("ru", "")).format({ "title": title, "runs": meta.runs, "hero": hero })

static func _greater(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false
