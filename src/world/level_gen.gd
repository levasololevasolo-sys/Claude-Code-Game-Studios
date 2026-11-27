## Level generator of the new level structure (GDD design/gdd/level-structure.md
## §3.1-3.4, F5-F7; stage 1, the Swamp slice). Port of the prototype
## tools/level-proto/gen_map.py: one location is one big level glued from ASCII
## room templates (assets/data/room_templates_<loc>.json) on a module grid.
## Main path: entry → section 1 → shrine → fork; then `forks` times: 2-3 trails
## (combat room + shrine altar) → junction (trails fall in from above through
## generated 1x1 links) → descent → room → next fork, the last time the lair
## gate. Side branches (nook, secret, gauntlet + nook, climb + nook) hang off the
## main path; unused sockets are sealed. Every level is validated (§3.4 step 7);
## a failed attempt retries with seed·1000 + n, after `gen_attempts` the
## location's fallback level (a known-good seed) is built.
##
## Pure logic: build(seed, tier, lib, t) returns plain data (rooms, edges, forks,
## markers, packs); no scene nodes. Same seed in, same level out.
class_name LevelGen
extends RefCounted

const LIB_PATH: String = "res://assets/data/room_templates_%s.json"
const OPP: Dictionary = { "L": "R", "R": "L", "T": "B", "B": "T" }
const STEP: Dictionary = { "L": Vector2i(-1, 0), "R": Vector2i(1, 0), "T": Vector2i(0, -1), "B": Vector2i(0, 1) }
## Kinds that may repeat inside one section (§3.4 step 2).
const REPEATABLE: Array[String] = ["shaft", "climb"]
## Marker characters a template grid may hold; they become "." in the composed grid.
const MARKS: String = "EFCHPGLKI"

static var _libs: Dictionary = {}

## One placed room (template on the module grid).
class R:
	extends RefCounted
	var t: Dictionary
	var x: int
	var y: int
	var role: String
	var sec: int
	## "main", "trail", "branch" or "link".
	var path: String
	var used: Dictionary = {}
	var entry: String = ""
	var trail: Array = []
	var i: int = -1

	func _init(p_t: Dictionary, p_x: int, p_y: int, p_role: String, p_sec: int, p_path: String) -> void:
		t = p_t
		x = p_x
		y = p_y
		role = p_role
		sec = p_sec
		path = p_path

	func cells() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for a in int(t.w):
			for b in int(t.h):
				out.append(Vector2i(x + a, y + b))
		return out

	func sock_cell(s: String) -> Vector2i:
		var k := int(s.substr(1))
		match s[0]:
			"L":
				return Vector2i(x, y + k)
			"R":
				return Vector2i(x + int(t.w) - 1, y + k)
			"T":
				return Vector2i(x + k, y)
		return Vector2i(x + k, y + int(t.h) - 1)

	func free_socks() -> Array[String]:
		var out: Array[String] = []
		for s: String in t.socks:
			if not used.has(s):
				out.append(s)
		return out

## Generator state of one attempt.
class St:
	extends RefCounted
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var lib: Array = []
	var occ: Dictionary = {}
	var rooms: Array[R] = []
	## [R a, R b, String kind, String sock_a, String sock_b]
	var edges: Array = []
	var forks: Array = []
	var reward_rooms: Array[R] = []
	var lairgate: R
	var why: String = ""
	var t: Dictionary = {}

# ---------------------------------------------------------------- library

## Parsed and expanded template library of a location (cached): {cell, module_w,
## module_h, templates: [tpl]} where every tpl has socks (["L0", ...]), reach
## ({sock: [socks]}), grid (PackedStringArray) and, when `mirror`, a mirrored
## twin with id "<id>~m". {} when the file is missing.
static func library(loc: String) -> Dictionary:
	if not _libs.has(loc):
		var path := LIB_PATH % loc
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_libs[loc] = prepare(parsed) if parsed is Dictionary else {}
	return _libs[loc]

## True when location `loc` has a template library (the graph mode can run there).
static func has_library(loc: String) -> bool:
	return FileAccess.file_exists(LIB_PATH % loc)

## Expands a raw template file (see library()).
static func prepare(raw: Dictionary) -> Dictionary:
	var out := { "cell": int(raw.get("cell", 40)), "module_w": int(raw.get("module_w", 16)), "module_h": int(raw.get("module_h", 9)), "templates": [] }
	for src: Dictionary in raw.get("templates", []):
		var tp := { "id": String(src.id), "base": String(src.id), "name": String(src.get("name", "")), "kind": String(src.kind),
			"w": int(src.w), "h": int(src.h), "weight": float(src.get("weight", 1.0)), "tier_min": int(src.get("tier_min", 1)),
			"socks": [], "reach": {}, "grid": PackedStringArray(src.grid), "mirrored": false }
		for s: Dictionary in src.get("sockets", []):
			(tp.socks as Array).append("%s%d" % [s.side, int(s.module)])
		for k: String in src.get("reach", {}):
			tp.reach[k] = (src.reach[k] as Array).duplicate()
		(out.templates as Array).append(tp)
		if bool(src.get("mirror", false)) and String(src.kind) != "junction":
			(out.templates as Array).append(mirror(tp))
	return out

## Horizontal mirror of a template: L↔R, T/B modules counted from the other side.
static func mirror(tp: Dictionary) -> Dictionary:
	var m := tp.duplicate(true)
	m.id = String(tp.id) + "~m"
	m.mirrored = true
	var g := PackedStringArray()
	for row: String in tp.grid:
		g.append(row.reverse())
	m.grid = g
	var w := int(tp.w)
	var socks: Array = []
	for s: String in tp.socks:
		socks.append(_mirror_sock(s, w))
	m.socks = socks
	var reach := {}
	for k: String in tp.reach:
		var list: Array = []
		for s: String in tp.reach[k]:
			list.append(_mirror_sock(s, w))
		reach[_mirror_sock(k, w)] = list
	m.reach = reach
	return m

static func _mirror_sock(s: String, w: int) -> String:
	var side := s[0]
	var k := int(s.substr(1))
	match side:
		"L":
			return "R%d" % k
		"R":
			return "L%d" % k
	return "%s%d" % [side, w - 1 - k]

# ---------------------------------------------------------------- build

## The level seed of a run's location (§3.4): seed_level = hash(seed_run, tier).
static func level_seed(run_seed: int, tier: int) -> int:
	return absi(run_seed * 7919 + tier * 104729 + 17) % 2147483647

## Builds the level of `seed` for location `tier` from library `lib` (library())
## with the tuning `t` (tuning.json "level" plus the root keys it needs, see
## tuning_for()). `opts`: elites_ok (bool), knight (bool: a knight stands on one
## trail), secret_ok (bool). Returns the level dictionary (see _export) with
## ok, attempts, fallback.
static func build(seed_value: int, tier: int, lib: Dictionary, t: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var attempts := int(t.get("gen_attempts", 50))
	var last_why := ""
	for n in attempts:
		var st := St.new()
		st.t = t
		st.rng.seed = seed_value * 1000 + n
		st.lib = _lib_for(lib, tier)
		if _build(st, tier) and _validate(st, t):
			var out := _export(st, lib, tier, t, opts)
			out.attempts = n + 1
			out.fallback = false
			out.seed = seed_value
			return out
		last_why = st.why
	# Edge case 1: the location's fallback level (a known-good seed, checked by the tests).
	push_warning("LevelGen: seed %d failed %d attempts (%s), using the fallback level" % [seed_value, attempts, last_why])
	var fb := int(t.get("fallback_seed", 7007))
	if fb != seed_value:
		var out := build(fb, tier, lib, t, opts)
		out.fallback = true
		return out
	return { "ok": false, "why": last_why, "rooms": [], "fallback": true }

## The generator's tuning: tuning.json "level" with the root keys it reads.
static func tuning_for(data: Dictionary) -> Dictionary:
	var t: Dictionary = (data.get("level", {}) as Dictionary).duplicate()
	for k in ["fork_three", "knight_door", "elite_chance", "elite_max", "pack_gap"]:
		if data.has(k) and not t.has(k):
			t[k] = data[k]
	return t

static func _lib_for(lib: Dictionary, tier: int) -> Array:
	var out: Array = []
	for tp: Dictionary in lib.get("templates", []):
		if int(tp.tier_min) <= tier:
			out.append(tp)
	return out

static func _by_kind(st: St, kinds: Array) -> Array:
	var out: Array = []
	for tp: Dictionary in st.lib:
		if String(tp.kind) in kinds:
			out.append(tp)
	return out

static func _fits(st: St, tp: Dictionary, x: int, y: int) -> bool:
	for a in int(tp.w):
		for b in int(tp.h):
			if st.occ.has(Vector2i(x + a, y + b)):
				return false
	return true

static func _put(st: St, r: R) -> R:
	for c in r.cells():
		st.occ[c] = r
	st.rooms.append(r)
	return r

static func _remove(st: St, r: R) -> void:
	for c in r.cells():
		st.occ.erase(c)
	st.rooms.erase(r)

## All [tpl, x, y, sock] that dock onto free socket `s` of `room`.
static func _attach_options(st: St, room: R, s: String, kinds: Array) -> Array:
	var c := room.sock_cell(s)
	var nxt: Vector2i = c + STEP[s[0]]
	var want: String = OPP[s[0]]
	var opts: Array = []
	for tp: Dictionary in _by_kind(st, kinds):
		for ts: String in tp.socks:
			if ts[0] != want:
				continue
			var k := int(ts.substr(1))
			var x: int
			var y: int
			if want == "L" or want == "R":
				x = nxt.x if want == "L" else nxt.x - int(tp.w) + 1
				y = nxt.y - k
			else:
				x = nxt.x - k
				y = nxt.y if want == "T" else nxt.y - int(tp.h) + 1
			if _fits(st, tp, x, y):
				opts.append([tp, x, y, ts])
	return opts

static func _dock(st: St, room: R, s: String, tp: Dictionary, x: int, y: int, ts: String, role: String, sec: int, path: String) -> R:
	var r := _put(st, R.new(tp, x, y, role, sec, path))
	room.used[s] = true
	r.used[ts] = true
	r.entry = ts
	st.edges.append([room, r, path, s, ts])
	return r

static func _undock(st: St, parent: R, s: String, r: R) -> void:
	parent.used.erase(s)
	var keep: Array = []
	for e: Array in st.edges:
		if e[1] != r:
			keep.append(e)
	st.edges = keep
	_remove(st, r)

## Can a hero who came in through `ts` leave through `s`? (one-way drops allowed)
static func exit_ok(tp: Dictionary, ts: String, s: String) -> bool:
	return s in (tp.reach.get(ts, []) as Array)

## Shuffles `arr` in place with `rng` (Fisher-Yates).
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## Stable sort of `arr` by the float keys `keys` (same order), ascending.
static func _sort_by(arr: Array, keys: Array) -> Array:
	var idx: Array = range(arr.size())
	idx.sort_custom(func(a: int, b: int) -> bool:
		return keys[a] < keys[b] or (keys[a] == keys[b] and a < b))
	var out: Array = []
	for i: int in idx:
		out.append(arr[i])
	return out

## DFS: docks `roles` one by one onto `room`; dirs = preferred exit sides in order.
## Returns [room, ...docked] or [] when no layout fits.
static func _grow(st: St, room: R, roles: Array, sec: int, path: String, dirs: Array) -> Array:
	if roles.is_empty():
		return [room]
	var kinds: Array = roles[0]
	var frees: Array = []
	for s: String in room.free_socks():
		if s[0] in dirs and (room.entry == "" or exit_ok(room.t, room.entry, s)):
			frees.append(s)
	shuffle(frees, st.rng)
	var fk: Array = []
	for s: String in frees:
		fk.append(float(dirs.find(s[0])))
	frees = _sort_by(frees, fk)
	var used_ids := {}
	if path == "main":
		for r in st.rooms:
			if r.sec == sec and r.path == "main":
				used_ids[String(r.t.base)] = true
	for s: String in frees.slice(0, 3):
		var opts: Array = []
		for o: Array in _attach_options(st, room, s, kinds):
			var tp: Dictionary = o[0]
			if not used_ids.has(String(tp.base)) or String(tp.kind) in REPEATABLE:
				opts.append(o)
		shuffle(opts, st.rng)
		var ok: Array = []
		for o: Array in opts:
			ok.append(-float((o[0] as Dictionary).weight) * st.rng.randf())
		opts = _sort_by(opts, ok)
		for o: Array in opts.slice(0, 6):
			var r := _dock(st, room, s, o[0], o[1], o[2], o[3], String(kinds[0]), sec, path)
			var tail := _grow(st, r, roles.slice(1), sec, path, dirs)
			if not tail.is_empty():
				return [room] + tail
			_undock(st, room, s, r)
	return []

## BFS on free module cells, moves left/right/down only (a forward trail never
## needs climbing), at most `max_len` cells. Returns the cells or [].
static func _route(st: St, start: Vector2i, side: String, goal: Vector2i, blocked: Dictionary, max_len: int) -> Array:
	var first: Vector2i = start + STEP[side]
	if st.occ.has(first) or blocked.has(first):
		return []
	var prev := { first: null }
	var dist := { first: 1 }
	var q: Array[Vector2i] = [first]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		if c == goal:
			var out: Array = []
			var p: Variant = c
			while p != null:
				out.push_front(p)
				p = prev[p]
			return out
		if int(dist[c]) >= max_len:
			continue
		var moves: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]
		shuffle(moves, st.rng)
		for m: Vector2i in moves:
			var n: Vector2i = c + m
			if prev.has(n) or st.occ.has(n) or blocked.has(n):
				continue
			if absi(n.x - goal.x) > 14 or n.y > goal.y:
				continue
			prev[n] = c
			dist[n] = int(dist[c]) + 1
			q.append(n)
	return []

## 1x1 connector template with sockets `socks` (tunnel, drop with a ledge, bend);
## generated, never authored (§3.4 step 4).
static func link_template(socks: Array, mw: int = 16, mh: int = 9) -> Dictionary:
	var g: Array = []
	for r in mh:
		var row := ""
		for x in mw:
			row += "#" if r == 0 or r == mh - 1 or x == 0 or x == mw - 1 else "."
		g.append(row)
	var sides := {}
	for s: String in socks:
		sides[s[0]] = true
	for side: String in sides:
		match side:
			"L":
				for r in range(4, 8):
					g[r] = "D" + (g[r] as String).substr(1)
			"R":
				for r in range(4, 8):
					g[r] = (g[r] as String).substr(0, mw - 1) + "D"
			"T":
				g[0] = (g[0] as String).substr(0, 6) + "DDDD" + (g[0] as String).substr(10)
			"B":
				g[mh - 1] = (g[mh - 1] as String).substr(0, 6) + "DDDD" + (g[mh - 1] as String).substr(10)
	if sides.has("T") and sides.has("B"):
		g[4] = (g[4] as String).substr(0, 2) + "===" + (g[4] as String).substr(5)
	# Reach: in through a side or from the top, out through any other opening except up.
	var reach := {}
	for a: String in socks:
		var list: Array = []
		for b: String in socks:
			if b != a and b[0] != "T":
				list.append(b)
		reach[a] = list
	return { "id": "link", "base": "link", "name": "связка", "kind": "link", "w": 1, "h": 1, "weight": 0.0,
		"tier_min": 1, "socks": socks.duplicate(), "reach": reach, "grid": PackedStringArray(g), "mirrored": false }

static func _add_links(st: St, path: Array, a: R, a_sock: String, b: R, b_sock: String) -> void:
	var cells: Array = [a.sock_cell(a_sock)] + path + [b.sock_cell(b_sock)]
	var chain: Array = [a]
	var socks_in: Array = [a_sock]
	var socks_out: Array = []
	for i in range(1, cells.size() - 1):
		var p: Vector2i = cells[i - 1]
		var c: Vector2i = cells[i]
		var n: Vector2i = cells[i + 1]
		var socks: Array = []
		for o: Vector2i in [p, n]:
			var d := o - c
			for side: String in STEP:
				if STEP[side] == d:
					socks.append(side + "0")
		var r := _put(st, R.new(link_template(socks), c.x, c.y, "link", a.sec, "link"))
		r.trail = a.trail.duplicate()
		for s: String in socks:
			r.used[s] = true
		r.entry = socks[0]
		socks_out.append(socks[0])
		socks_in.append(socks[1])
		chain.append(r)
	socks_out.append(b_sock)
	chain.append(b)
	for i in chain.size() - 1:
		st.edges.append([chain[i], chain[i + 1], "link", socks_in[i], socks_out[i]])
	a.used[a_sock] = true
	b.used[b_sock] = true

static func _pick_w(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k: String in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k: String in weights:
		r -= float(weights[k])
		if r < 0.0:
			return k
	return String(weights.keys()[-1])

static func _build(st: St, tier: int) -> bool:
	var rng := st.rng
	var t := st.t
	var entries: Array = []
	for tp: Dictionary in _by_kind(st, ["entry"]):
		if not bool(tp.mirrored):
			entries.append(tp)
	if entries.is_empty():
		st.why = "no entry"
		return false
	var entry := _put(st, R.new(entries[rng.randi_range(0, entries.size() - 1)], 0, 0, "entry", 0, "main"))
	# Section 1 (surface, heads east); tier 1 is one room shorter (§3.4 step 1).
	var sec0: Array = [["corr"], ["arena", "bridge"], ["corr", "hall"], ["altar"], ["fork"]]
	if int(t.get("sec1_rooms_t1", 2)) < 3 and tier == 1:
		sec0 = [["corr"], ["arena", "bridge", "hall"], ["altar"], ["fork"]]
	var chain := _grow(st, entry, sec0, 0, "main", ["R", "B"])
	if chain.is_empty():
		st.why = "section 1"
		return false
	st.reward_rooms = [chain[-2]]
	var fork: R = chain[-1]
	var stages := int(t.get("forks_per_loc", 3))
	var link_max := int(t.get("link_max", 6))
	for stage in range(1, stages + 1):
		var trails: Array = []
		var outs: Array = []
		for s: String in fork.free_socks():
			if s[0] in ["R", "B", "L"] and exit_ok(fork.t, fork.entry, s):
				outs.append(s)
		shuffle(outs, rng)
		var want := 3 if rng.randf() < float(t.get("fork_three", 0.45)) else 2
		var combat := int(t.get("trail_combat_t1", 1)) if tier == 1 else (2 if tier >= 4 else 1 + rng.randi_range(0, 1))
		for s: String in outs:
			if trails.size() == want:
				break
			var roles: Array = []
			for i in combat:
				roles.append([["arena", "hall", "bridge"][rng.randi_range(0, 2)]])
			roles.append(["altar"])
			var first_kinds: Array = ["shaft", "climb", "hall"] if s[0] in ["L", "R"] else ["shaft", "hall", "arena", "bridge"]
			var opts := _attach_options(st, fork, s, first_kinds)
			var keys: Array = []
			for o: Array in opts:
				keys.append(rng.randf())
			opts = _sort_by(opts, keys)
			var got: Array = []
			for o: Array in opts:
				var r := _dock(st, fork, s, o[0], o[1], o[2], o[3], "trail", stage, "trail")
				var tail := _grow(st, r, roles, stage, "trail", ["B", "R", "L"] if s[0] != "L" else ["B", "L", "R"])
				if not tail.is_empty():
					got = [r] + tail.slice(1)
					break
				_undock(st, fork, s, r)
			if not got.is_empty():
				for q: R in got:
					q.trail = [stage, trails.size()]
				trails.append({ "sock": s, "rooms": got })
		if trails.size() < 2:
			st.why = "trails st%d %d" % [stage, trails.size()]
			return false
		# Junction below all trails (§3.4 step 4, F7). Three trails may take longer
		# links (link_max_three); if they still do not meet, the third is dropped and
		# its gate sealed (edge case 2).
		var bestc: Array = _place_junction(st, trails, stage, int(t.get("link_max_three", link_max)) if trails.size() == 3 else link_max)
		if bestc.is_empty() and trails.size() == 3:
			_drop_trail(st, trails[2])
			trails.resize(2)
			bestc = _place_junction(st, trails, stage, link_max)
		if bestc.is_empty():
			st.why = "junction st%d" % stage
			return false
		var jn := _put(st, R.new(bestc[1], bestc[2], bestc[3], "junction", stage, "main"))
		for p: Array in bestc[4]:
			_add_links(st, p[0], p[1], p[2], jn, p[3])
		var tr_rooms: Array = []
		for tr: Dictionary in trails:
			st.reward_rooms.append((tr.rooms as Array)[-1])
			tr_rooms.append(tr)
		st.forks.append({ "fork": fork, "trails": tr_rooms, "junction": jn })
		# Common stretch after the junction: descend, then the next fork or the lair gate.
		var roles2: Array = [["shaft", "climb"], ["corr", "hall", "arena"], ["fork"]] if stage < stages else [["shaft"], ["arena", "hall"], ["lairgate"]]
		var lr: Array = ["R", "L"]
		shuffle(lr, rng)
		var nxt := _grow(st, jn, roles2, stage, "main", ["B"] + lr)
		if nxt.is_empty():
			st.why = "after st%d" % stage
			return false
		fork = nxt[-1]
	st.lairgate = fork
	# Side branches (§3.4 step 5): one per section, a second with branch_second.
	var bw: Dictionary = t.get("branch_w", { "nook": 0.35, "secret": 0.25, "gauntlet": 0.2, "climb": 0.2 })
	for sec in range(0, stages + 1):
		var want_b := 2 if rng.randf() < float(t.get("branch_second", 0.4)) else 1
		var done := 0
		var hosts: Array = []
		for r in st.rooms:
			if r.sec == sec and r.path == "main" and not r.role in ["fork", "junction", "lairgate", "link"]:
				hosts.append(r)
		shuffle(hosts, rng)
		for h: R in hosts:
			if done >= want_b:
				break
			for s: String in h.free_socks():
				if not s[0] in ["L", "R", "T"]:
					continue
				# Two-way only: the hero walks from the host's entry to the branch and back.
				if h.entry != "" and not exit_ok(h.t, h.entry, s):
					continue
				var pick := _pick_w(rng, bw)
				var kinds: Array = [["nook"]]
				match pick:
					"secret":
						kinds = [["secret"]]
					"gauntlet":
						kinds = [["gauntlet"], ["nook"]]
					"climb":
						kinds = [["climb"], ["nook"]]
				if not _grow_branch(st, h, s, kinds, sec).is_empty():
					done += 1
					break
	return true

## Junction below all `trails` (§3.4 step 4, F7): the cheapest place where every
## trail's shrine reaches its own top hole through at most `link_max` free
## modules. Returns [cost, tpl, x, y, plan] or [].
static func _place_junction(st: St, trails: Array, stage: int, link_max: int) -> Array:
	var rng := st.rng
	var bottom := -1000000
	var xmin := 1000000
	var xmax := -1000000
	for tr: Dictionary in trails:
		for r: R in tr.rooms:
			bottom = maxi(bottom, r.y + int(r.t.h))
		var alt: R = (tr.rooms as Array)[-1]
		xmin = mini(xmin, alt.x)
		xmax = maxi(xmax, alt.x)
	var cands: Array = []
	for jt: Dictionary in _by_kind(st, ["junction"]):
		for dy in [1, 2, 3, 4]:
			for jx in range(xmin - 6, xmax + 4):
				var jy: int = bottom + dy
				if not _fits(st, jt, jx, jy):
					continue
				var j := _put(st, R.new(jt, jx, jy, "junction", stage, "main"))
				var tops: Array = []
				for s: String in jt.socks:
					if s[0] == "T":
						tops.append(s)
				var blocked := {}
				var plan: Array = []
				var okj := true
				var taken := {}
				for tr: Dictionary in trails:
					var alt: R = (tr.rooms as Array)[-1]
					var best: Array = []
					for e: String in alt.free_socks():
						if not (e[0] in ["B", "R", "L"] and exit_ok(alt.t, alt.entry, e)):
							continue
						for ts: String in tops:
							if taken.has(ts):
								continue
							var gc := j.sock_cell(ts)
							var p := _route(st, alt.sock_cell(e), e[0], Vector2i(gc.x, gc.y - 1), blocked, link_max)
							if not p.is_empty() and (best.is_empty() or p.size() < (best[0] as Array).size()):
								best = [p, alt, e, ts]
					if best.is_empty():
						okj = false
						break
					plan.append(best)
					taken[best[3]] = true
					for c: Vector2i in best[0]:
						blocked[c] = true
				_remove(st, j)
				if okj:
					var cost := float(dy) + rng.randf()
					for p: Array in plan:
						cost += (p[0] as Array).size()
					cands.append([cost, jt, jx, jy, plan])
	if cands.is_empty():
		return []
	var bestc: Array = cands[0]
	for c: Array in cands:
		if float(c[0]) < float(bestc[0]):
			bestc = c
	return bestc

## Takes trail `tr` (its rooms, newest first) off the fork again.
static func _drop_trail(st: St, tr: Dictionary) -> void:
	var rooms: Array = (tr.rooms as Array).duplicate()
	rooms.reverse()
	for r: R in rooms:
		for e: Array in st.edges:
			if e[1] == r:
				_undock(st, e[0], e[3], r)
				break

static func _grow_branch(st: St, host: R, s: String, kinds: Array, sec: int) -> Array:
	var opts := _attach_options(st, host, s, kinds[0])
	shuffle(opts, st.rng)
	for o: Array in opts.slice(0, 6):
		var r := _dock(st, host, s, o[0], o[1], o[2], o[3], String((kinds[0] as Array)[0]), sec, "branch")
		# A branch must lead back: from its entry the hero can leave by the same socket
		# (side sockets) or by another one.
		if not _side(r.entry) and (r.t.reach.get(r.entry, []) as Array).is_empty():
			_undock(st, host, s, r)
			continue
		if kinds.size() == 1:
			return [r]
		var tail := _grow(st, r, kinds.slice(1), sec, "branch", ["R", "L", "T", "B"])
		if not tail.is_empty():
			for q: R in tail.slice(1):
				q.path = "branch"
			for e: Array in st.edges:
				if e[1] in tail:
					e[2] = "branch"
			return [r] + tail.slice(1)
		_undock(st, host, s, r)
	return []

static func _side(s: String) -> bool:
	return s != "" and (s[0] == "L" or s[0] == "R")

# ---------------------------------------------------------------- validation (§3.4 step 7)

## Movement graph over (room, socket-entered) states built from the reach tables.
## A side socket can always be walked back through; falling in from the top cannot.
static func _states_from(st: St, conn: Dictionary, start_room: R, start_sock: String) -> Dictionary:
	var seen := {}
	var q: Array = [[start_room, start_sock]]
	seen[_key(start_room, start_sock)] = true
	var qi := 0
	while qi < q.size():
		var cur: Array = q[qi]
		qi += 1
		var r: R = cur[0]
		var e: String = cur[1]
		var outs: Array = []
		for s: String in r.used:
			if e == "P" or s in (r.t.reach.get(e, []) as Array) or (s == e and e != "" and e[0] != "T"):
				outs.append(s)
		for s: String in outs:
			var k := "%d:%s" % [r.i, s]
			if not conn.has(k):
				continue
			var nb: Array = conn[k]
			var key := _key(nb[0], nb[1])
			if not seen.has(key):
				seen[key] = true
				q.append(nb)
	return seen

static func _key(r: R, s: String) -> String:
	return "%d:%s" % [r.i, s]

static func _conn(st: St) -> Dictionary:
	var conn := {}
	for e: Array in st.edges:
		var a: R = e[0]
		var b: R = e[1]
		conn["%d:%s" % [a.i, e[3]]] = [b, e[4]]
		conn["%d:%s" % [b.i, e[4]]] = [a, e[3]]
	return conn

static func _rooms_in(seen: Dictionary) -> Dictionary:
	var out := {}
	for k: String in seen:
		out[int(k.get_slice(":", 0))] = true
	return out

static func _validate(st: St, t: Dictionary) -> bool:
	for i in st.rooms.size():
		st.rooms[i].i = i
	if st.forks.size() != int(t.get("forks_per_loc", 3)):
		st.why = "forks %d" % st.forks.size()
		return false
	var conn := _conn(st)
	var entry: R = st.rooms[0]
	var seen := _states_from(st, conn, entry, "P")
	var reached := _rooms_in(seen)
	if st.lairgate == null or not reached.has(st.lairgate.i):
		st.why = "lair unreachable"
		return false
	for r: R in st.reward_rooms:
		if not reached.has(r.i):
			st.why = "shrine unreachable"
			return false
	# No softlock: from every reachable state the lair gate stays reachable.
	for k: String in seen:
		var r: R = st.rooms[int(k.get_slice(":", 0))]
		if r.path == "branch" or r == st.lairgate:
			continue
		var sub := _rooms_in(_states_from(st, conn, r, k.get_slice(":", 1)))
		if not sub.has(st.lairgate.i):
			st.why = "dead end at %s" % String(r.t.id)
			return false
	# Branches are two-way: from the branch's first room the hero gets back to its host.
	for e: Array in st.edges:
		var b: R = e[1]
		var a: R = e[0]
		if String(e[2]) == "branch" and a.path != "branch":
			var back := _rooms_in(_states_from(st, conn, b, String(e[4])))
			if not back.has(a.i):
				st.why = "one-way branch %s" % String(b.t.id)
				return false
	var top := 1000000
	var low := -1000000
	for r in st.rooms:
		top = mini(top, r.y)
	low = st.lairgate.y + int(st.lairgate.t.h)
	if low - entry.y < int(t.get("depth_min", 20)):
		st.why = "depth %d" % (low - entry.y)
		return false
	return true

# ---------------------------------------------------------------- export

static func band_of(r_sec: int, r_path: String) -> int:
	return clampi(r_sec - (1 if r_path == "trail" or (r_path == "link") else 0), 0, 2)

## Plain-data level: rooms [{i, id, kind, x, y, w, h (modules, origin at the
## level's top-left module), role, sec, path, band, used, entry, trail, sealed}],
## edges [[a, b, kind, sock_a, sock_b]], forks [{room, junction, trails: [{sock,
## rooms, shrine}]}], shrines (in order of the run: section 1, then fork trails),
## entry, lairgate, cols / rows (cells), grid (PackedStringArray of the whole
## level, markers removed, used sockets open, unused sealed), marks [{ch, c
## (Vector2i cell), room}], packs [{room, c, size, k, trail, elites}], chests
## [{c, rich, room}], walls [{c0, c1, room}] (S cells), knight {room, c} or {}.
static func _export(st: St, lib: Dictionary, tier: int, t: Dictionary, opts: Dictionary) -> Dictionary:
	var mw := int(lib.get("module_w", 16))
	var mh := int(lib.get("module_h", 9))
	var minx := 1000000
	var miny := 1000000
	var maxx := -1000000
	var maxy := -1000000
	for r in st.rooms:
		minx = mini(minx, r.x)
		miny = mini(miny, r.y)
		maxx = maxi(maxx, r.x + int(r.t.w))
		maxy = maxi(maxy, r.y + int(r.t.h))
	# One solid module of border all around (edge case 13: solid earth past the frame).
	var ox := -minx + 1
	var oy := -miny + 1
	var mcols := maxx - minx + 2
	var mrows := maxy - miny + 2
	var cols := mcols * mw
	var rows := mrows * mh
	var grid: Array[PackedByteArray] = []
	for y in rows:
		var row := PackedByteArray()
		row.resize(cols)
		row.fill(35)  # "#"
		grid.append(row)
	var rooms: Array = []
	var marks: Array = []
	for r in st.rooms:
		var rx := (r.x + ox) * mw
		var ry := (r.y + oy) * mh
		var g: PackedStringArray = r.t.grid
		for y in g.size():
			var line := g[y]
			for x in line.length():
				var ch := line[x]
				var c := Vector2i(rx + x, ry + y)
				if ch == "D":
					ch = "D"
				elif MARKS.contains(ch):
					marks.append({ "ch": ch, "c": c, "room": r.i })
					ch = "."
				elif ch == "B":
					marks.append({ "ch": "B", "c": c, "room": r.i })
				grid[c.y][c.x] = ch.unicode_at(0)
		# Open the used sockets, seal the rest (§3.2: sealed with solid earth).
		for s: String in r.t.socks:
			var open := r.used.has(s)
			for c in socket_cells(r, s, mw, mh, ox, oy):
				grid[c.y][c.x] = 46 if open else 35
		var sealed: Array = []
		for s: String in r.t.socks:
			if not r.used.has(s):
				sealed.append(s)
		rooms.append({ "i": r.i, "id": String(r.t.id), "name": String(r.t.get("name", "")), "kind": String(r.t.kind),
			"x": r.x + ox, "y": r.y + oy, "w": int(r.t.w), "h": int(r.t.h), "role": r.role, "sec": r.sec, "path": r.path,
			"band": band_of(r.sec, r.path), "used": r.used.keys(), "entry": r.entry, "trail": r.trail.duplicate(), "sealed": sealed })
	var out_grid := PackedStringArray()
	for row in grid:
		out_grid.append(row.get_string_from_ascii())
	var edges: Array = []
	for e: Array in st.edges:
		edges.append([(e[0] as R).i, (e[1] as R).i, e[2], e[3], e[4]])
	var forks: Array = []
	for f: Dictionary in st.forks:
		var trails: Array = []
		for tr: Dictionary in f.trails:
			var ids: Array = []
			for q: R in tr.rooms:
				ids.append(q.i)
			trails.append({ "sock": tr.sock, "rooms": ids, "shrine": ids[-1] })
		forks.append({ "room": (f.fork as R).i, "junction": (f.junction as R).i, "trails": trails })
	var shrines: Array = []
	for r: R in st.reward_rooms:
		shrines.append(r.i)
	var out := { "ok": true, "tier": tier, "cell": int(lib.get("cell", 40)), "module_w": mw, "module_h": mh,
		"cols": cols, "rows": rows, "mcols": mcols, "mrows": mrows, "grid": out_grid, "rooms": rooms, "edges": edges,
		"forks": forks, "shrines": shrines, "entry": 0, "lairgate": st.lairgate.i, "marks": marks }
	_fill(st, out, tier, t, opts)
	return out

## Cells of socket `s` of room `r` in level cells (the 4-cell opening).
static func socket_cells(r: R, s: String, mw: int, mh: int, ox: int, oy: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var k := int(s.substr(1))
	var rx := (r.x + ox) * mw
	var ry := (r.y + oy) * mh
	match s[0]:
		"L":
			for y in range(k * mh + 4, k * mh + 8):
				out.append(Vector2i(rx, ry + y))
		"R":
			for y in range(k * mh + 4, k * mh + 8):
				out.append(Vector2i(rx + int(r.t.w) * mw - 1, ry + y))
		"T":
			for x in range(k * mw + 6, k * mw + 10):
				out.append(Vector2i(rx + x, ry))
		"B":
			for x in range(k * mw + 6, k * mw + 10):
				out.append(Vector2i(rx + x, ry + int(r.t.h) * mh - 1))
	return out

## Step 6: packs on E by F4.3 / F5, chests on C, breakable walls on S, the knight.
static func _fill(st: St, out: Dictionary, tier: int, t: Dictionary, opts: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = st.rng.seed * 31 + 7
	var by_room := {}
	for m: Dictionary in out.marks:
		var ri := int(m.room)
		if not by_room.has(ri):
			by_room[ri] = []
		(by_room[ri] as Array).append(m)
	var packs: Array = []
	var chests: Array = []
	var budget_max := int(t.get("trail_budget_base", 6)) + int(t.get("trail_budget_tier", 2)) * (tier - 1)
	var trail_sum := {}
	for room: Dictionary in out.rooms:
		var ri := int(room.i)
		var k := 1 if int(room.sec) == 0 else int(room.sec) + 1
		var tkey := str(room.trail) if not (room.trail as Array).is_empty() else "room%d" % ri
		for m: Dictionary in by_room.get(ri, []):
			match String(m.ch):
				"E":
					var size := 2 if tier == 1 and k == 1 else clampi(RoomGen.pack_base(k, tier) + rng.randi_range(0, 1), 2, 8)
					var used := int(trail_sum.get(tkey, 0))
					if used + size > budget_max:
						size = maxi(2, budget_max - used)
					trail_sum[tkey] = used + size
					var elites: Array = []
					if bool(opts.get("elites_ok", false)):
						for j in size:
							if elites.size() < int(t.get("elite_max", 2)) and rng.randf() < float(t.get("elite_chance", 0.18)) * 0.5:
								elites.append(j)
					packs.append({ "room": ri, "c": m.c, "size": size, "k": k, "trail": room.trail, "elites": elites })
				"C":
					var rich := String(room.kind) == "secret"
					if rich or String(room.kind) == "nook" or rng.randf() < float(t.get("chest_chance", 0.5)):
						chests.append({ "c": m.c, "rich": rich, "room": ri })
	# Breakable walls: one per run of S cells (a column in the secret template).
	var walls: Array = []
	var grid: PackedStringArray = out.grid
	var seen := {}
	for y in grid.size():
		var line := grid[y]
		var x := line.find("S")
		while x >= 0:
			var c := Vector2i(x, y)
			if not seen.has(c):
				var y1 := y
				while y1 + 1 < grid.size() and grid[y1 + 1][x] == "S":
					y1 += 1
				for yy in range(y, y1 + 1):
					seen[Vector2i(x, yy)] = true
				walls.append({ "c0": c, "c1": Vector2i(x, y1), "room": _room_at(out, c) })
			x = line.find("S", x + 1)
	# Knight (room-generation §3.6, level-structure §3.1): one per location, on the K
	# of a trail arena (else on a trail pack spot) of fork f, rolled f = 1..n with
	# knight_door, surely on the last fork.
	var knight := {}
	if bool(opts.get("knight", false)) and not (out.forks as Array).is_empty():
		var nf := (out.forks as Array).size()
		for fi in nf:
			if fi < nf - 1 and rng.randf() >= float(t.get("knight_door", 0.35)):
				continue
			var f: Dictionary = out.forks[fi]
			var tr: Dictionary = f.trails[rng.randi_range(0, (f.trails as Array).size() - 1)]
			for ri: int in tr.rooms:
				for m: Dictionary in by_room.get(ri, []):
					if String(m.ch) == "K" and knight.is_empty():
						knight = { "room": ri, "c": m.c, "fork": fi, "trail": (f.trails as Array).find(tr) }
			if knight.is_empty():
				for p: Dictionary in packs:
					if int(p.room) in tr.rooms and knight.is_empty():
						knight = { "room": int(p.room), "c": p.c, "fork": fi, "trail": (f.trails as Array).find(tr) }
			if not knight.is_empty():
				break
	out.packs = packs
	out.chests = chests
	out.walls = walls
	out.knight = knight

## Index of the room holding level cell `c`, -1 when none.
static func _room_at(out: Dictionary, c: Vector2i) -> int:
	var mw := int(out.module_w)
	var mh := int(out.module_h)
	var m := Vector2i(floori(float(c.x) / mw), floori(float(c.y) / mh))
	for r: Dictionary in out.rooms:
		if m.x >= int(r.x) and m.x < int(r.x) + int(r.w) and m.y >= int(r.y) and m.y < int(r.y) + int(r.h):
			return int(r.i)
	return -1

## Index of the room holding module `m`, -1 when none (minimap, world).
static func room_at_module(level: Dictionary, m: Vector2i) -> int:
	for r: Dictionary in level.rooms:
		if m.x >= int(r.x) and m.x < int(r.x) + int(r.w) and m.y >= int(r.y) and m.y < int(r.y) + int(r.h):
			return int(r.i)
	return -1

## Signature of the main path (template ids and places) for comparing two seeds.
static func main_signature(level: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r: Dictionary in level.rooms:
		if String(r.path) == "main":
			parts.append("%s@%d,%d" % [r.id, int(r.x), int(r.y)])
	return "|".join(parts)
