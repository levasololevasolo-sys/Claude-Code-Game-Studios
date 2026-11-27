## Builds the layout of a combat room: width, platforms, solids, enemy packs,
## chests, the breakable wall with its secret pocket, the knight spot and elites.
## Pure logic: same seed in, same room out.
## Run rooms glue hand-made chunks (GDD room-generation-and-doors §3.3-3.6, §3.10,
## §4.1-4.3; library assets/data/chunks_<loc>.json). The legacy single-room checks
## (safe_start = false) keep the prototype's flat genRoom() layout, so their
## recorded logs (--demo) stay byte-identical.
class_name RoomGen
extends RefCounted

const LIB_PATH: String = "res://assets/data/chunks_%s.json"

static var _libs: Dictionary = {}

## Returns {w, plats: Array[Vector3(x, y, width)], packs: Array[Array[float x]]}
## and, for chunk rooms, solids (Array[Rect2]), chunks ([{id, kind, x, w, h}]),
## chests ([{x, y, rich}]), traps ([{kind, x, y, w}]), wall ({} or {x, y, w, h}),
## knight_x (-1 = none), elites ([[pack, member]]), top (highest y), fallback,
## bogs (Array[Vector2] hummock tops of the G markers, Болотница spots).
## k is the room number in the location (1-based), tier the location number (1-based).
## `safe_start` false = the legacy flat layout without the BUG-0004 safe zone.
## `opts`: knight, elites_ok, elite_force (int), secret_ok, secret_force, lib
## (a library dictionary instead of the file), loc (default "swamp").
static func generate(rng: RandomNumberGenerator, k: int, tier: int, t: Dictionary, safe_start: bool = true, opts: Dictionary = {}) -> Dictionary:
	if not safe_start:
		return _legacy(rng, k, tier, t)
	var lib: Dictionary = opts.get("lib", {})
	if lib.is_empty():
		lib = library(String(opts.get("loc", "swamp")))
	return chunk_room(rng, k, tier, t, lib, opts)

## Parsed chunk library of a location (cached).
static func library(loc: String) -> Dictionary:
	if not _libs.has(loc):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIB_PATH % loc))
		_libs[loc] = parsed if parsed is Dictionary else {}
	return _libs[loc]

## F4.1: room length in modules.
static func budget(k: int, tier: int, t: Dictionary) -> int:
	if tier == 1 and k == 1:
		return int(t.get("L_first", 3))
	return mini(int(t.get("L_max", 9)), int(t.get("L_base", 4)) + (k - 1) + floori((tier - 1) * float(t.get("L_tier", 0.5))))

## F4.2: number of arenas.
static func arenas_for(l: int) -> int:
	return maxi(1, 1 + floori((l - 3) / 2.0))

## F4.3: base pack size.
static func pack_base(k: int, tier: int) -> int:
	if tier == 1 and k == 1:
		return 2
	return 3 + floori((k - 1) / 2.0) + floori((tier - 1) * 0.75)

## Elevation in cells of a side socket (0 = the floor).
static func elev(s: Dictionary, t: Dictionary) -> int:
	return int(s.module) * int(t.get("module_h", 9)) + (int(t.get("module_h", 9)) - 1 - int(s.offset))

static func socket(c: Dictionary, side: String) -> Dictionary:
	for s: Dictionary in c.get("sockets", []):
		if s.side == side:
			return s
	return {}

## True when chunk b can be glued to the right of chunk a (§3.3: same offset and size).
static func fits(a: Dictionary, b: Dictionary) -> bool:
	var r := socket(a, "R")
	var l := socket(b, "L")
	return not r.is_empty() and not l.is_empty() and int(r.module) == int(l.module) \
		and int(r.offset) == int(l.offset) and int(r.size) == int(l.size)

## The chunk ids of one room (§3.4 steps 1-5). Returns {ids, fallback}.
static func pick_chain(rng: RandomNumberGenerator, k: int, tier: int, t: Dictionary, lib: Dictionary) -> Dictionary:
	var l := budget(k, tier, t)
	var want_a := arenas_for(l)
	var need_shaft := k >= 2
	var by_kind := {}
	for c: Dictionary in lib.get("chunks", []):
		if int(c.get("tier_min", 1)) <= tier:
			if not by_kind.has(c.kind):
				by_kind[c.kind] = []
			by_kind[c.kind].append(c)
	for attempt in int(t.get("chunk_tries", 20)):
		var chain: Array = [_weighted(rng, by_kind.get("entry", []))]
		if chain[0] == null:
			break
		var used := { chain[0].id: true }
		var width := int(chain[0].w)
		var arenas := 0
		var shafts := 0
		var ok := true
		while true:
			var prev: Dictionary = chain[-1]
			var room_left := l + 1 - width - 1  # modules still free before a 1-wide exit (L + 1 allowed)
			if width + 1 >= l and elev(socket(prev, "R"), t) == 0 and arenas >= want_a and (shafts > 0 or not need_shaft):
				break
			var cands: Array = []
			var weights: Array = []
			for kind: String in ["arena", "pass", "shaft"]:
				for c: Dictionary in by_kind.get(kind, []):
					if used.has(c.id) or int(c.w) > room_left or not fits(prev, c):
						continue
					if kind == "arena" and (prev.kind == "arena" or arenas >= want_a):
						continue
					# Prune: the rest (arenas with a connector between, the shaft, a way
					# down from a high socket, the exit) must still fit in L + 1.
					var left := want_a - arenas - (1 if kind == "arena" else 0)
					var need := 2 * left - (0 if kind == "arena" or left == 0 else 1)
					var conn_left := left if kind == "arena" else left - 1
					if need_shaft and shafts == 0 and kind != "shaft" and conn_left <= 0:
						need += 1
					if elev(socket(c, "R"), t) != 0:
						need += 1
					if width + int(c.w) + need + 1 > l + 1:
						continue
					var wt := float(c.get("weight", 1.0))
					if kind == "arena":
						wt *= 3.0
					elif kind == "shaft" and need_shaft and shafts == 0:
						wt *= 2.0
					cands.append(c)
					weights.append(wt)
			if cands.is_empty():
				ok = false
				break
			var pick: Dictionary = cands[_weighted_i(rng, weights)]
			chain.append(pick)
			used[pick.id] = true
			width += int(pick.w)
			if pick.kind == "arena":
				arenas += 1
			elif pick.kind == "shaft":
				shafts += 1
		if not ok or arenas != want_a or (need_shaft and shafts == 0):
			continue
		var exits: Array = []
		for c: Dictionary in by_kind.get("exit", []):
			if fits(chain[-1], c) and width + int(c.w) <= l + 1:
				exits.append(c)
		if exits.is_empty():
			continue
		chain.append(_weighted(rng, exits))
		var ids: Array = []
		for c: Dictionary in chain:
			ids.append(c.id)
		return { "ids": ids, "fallback": false }
	return { "ids": (lib.get("fallback", []) as Array).duplicate(), "fallback": true }

## Lays out the chain of chunks and fills it (§3.4 step 6).
static func chunk_room(rng: RandomNumberGenerator, k: int, tier: int, t: Dictionary, lib: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var cell := float(t.get("cell", 40))
	var mod_w := cell * float(t.get("module_w", 16))
	var mod_h := cell * float(t.get("module_h", 9))
	var ground := float(t.get("ground_y", 640))
	var by_id := {}
	for c: Dictionary in lib.get("chunks", []):
		by_id[c.id] = c
	var chain := pick_chain(rng, k, tier, t, lib)
	var out := { "w": 0.0, "plats": [], "packs": [], "solids": [], "chunks": [], "chests": [], "traps": [],
		"wall": {}, "knight_x": -1.0, "elites": [], "top": ground, "fallback": chain.fallback, "bogs": [] }
	var x0 := 0.0
	var arenas: Array = []
	var c_slots: Array = []
	var b_slots: Array = []
	for id: String in chain.ids:
		var c: Dictionary = by_id[id]
		out.chunks.append({ "id": id, "kind": c.kind, "x": x0, "w": int(c.w), "h": int(c.h) })
		out.top = minf(out.top, ground - int(c.h) * mod_h)
		for p: Array in c.get("plats", []):
			out.plats.append(Vector3(x0 + p[0] * cell, ground - p[1] * cell, p[2] * cell))
		for s: Array in c.get("solids", []):
			out.solids.append(Rect2(x0 + s[0] * cell, ground - (s[1] + s[3]) * cell, s[2] * cell, s[3] * cell))
		for cs: Array in c.get("C", []):
			c_slots.append([x0 + (cs[0] + 0.5) * cell, ground - cs[1] * cell, float(cs[2])])
		for b: Array in c.get("B", []):
			b_slots.append([x0 + b[0] * cell, int(b[1])])
		# Bog spawn markers (bestiary §3.2 Болотница): hummock top, world space.
		for g: Array in c.get("G", []):
			out.bogs.append(Vector2(x0 + float(g[0]) * cell, ground - float(g[1]) * cell))
		if c.kind == "arena":
			arenas.append({ "c": c, "x": x0 })
		x0 += int(c.w) * mod_w
	out.w = x0
	# Packs (F4.3); BUG-0004 safe start zone: nobody within aggro_range + start_safe_gap of the spawn.
	var safe := float(t.get("hero_spawn_x", 160.0)) + float(t.get("aggro_range", 520.0)) + float(t.get("start_safe_gap", 200.0))
	var base := pack_base(k, tier)
	for a: Dictionary in arenas:
		var size := 2 if tier == 1 and k == 1 else clampi(base + rng.randi_range(0, 1), 2, 8)
		var slots: Array = a.c.get("S", [])
		var groups: Array = [[]]
		if int(a.c.w) >= 2 and size >= 5:
			groups = [[], []]
		for s: Array in slots:
			groups[mini(int(s[1]), groups.size() - 1)].append(s)
		var sizes: Array = [size] if groups.size() == 1 else [ceili(size / 2.0), size - ceili(size / 2.0)]
		var made: Array = []
		for gi in groups.size():
			var g: Array = groups[gi].duplicate()
			_shuffle(g, rng)
			var list: Array = []
			for i in int(sizes[gi]):
				var s: Array = g[i % g.size()]
				var ex: float = a.x + (s[0] + 0.5) * cell + (i / g.size()) * cell * 0.5
				if ex < safe:
					ex = safe + (safe - ex)
				list.append(clampf(ex, safe, out.w - 200.0))
			made.append(list)
		# Edge 11: two packs only when their centres are further apart than pack_gap.
		if made.size() == 2 and absf(_mean(made[0]) - _mean(made[1])) <= float(t.get("pack_gap", 640)):
			made = [made[0] + made[1]]
		out.packs.append_array(made)
	# Elites (enemies-and-elites §3.6): elite_chance x 0.5 per member, at most elite_max.
	var force := int(opts.get("elite_force", 0))
	if bool(opts.get("elites_ok", false)) or force > 0:
		var cap := maxi(int(t.get("elite_max", 2)), force)
		for pi in out.packs.size():
			for j in (out.packs[pi] as Array).size():
				if out.elites.size() >= cap:
					break
				if out.elites.size() < force or (bool(opts.get("elites_ok", false)) and rng.randf() < float(t.get("elite_chance", 0.18)) * 0.5):
					out.elites.append([pi, j])
	# Knight (§3.6): on the K mark of the widest arena, else its centre.
	if bool(opts.get("knight", false)) and not arenas.is_empty():
		var best: Dictionary = arenas[0]
		for a: Dictionary in arenas:
			if int(a.c.w) > int(best.c.w) or (int(a.c.w) == int(best.c.w) and a.c.has("K") and not best.c.has("K")):
				best = a
		var kx: float = best.x + (float(best.c.K) * cell if best.c.has("K") else int(best.c.w) * mod_w / 2.0)
		out.knight_x = clampf(maxf(kx, safe), safe, out.w - 200.0)
	# Chests on C marks with their chance, at most chest_max (§3.4 step 6).
	for cs: Array in c_slots:
		if out.chests.size() >= int(t.get("chest_max", 1)):
			break
		if rng.randf() < float(cs[2]):
			out.chests.append({ "x": cs[0], "y": cs[1], "rich": false })
	# Breakable wall with a secret pocket behind it (§3.10).
	if bool(opts.get("secret_ok", false)) and not b_slots.is_empty() and (bool(opts.get("secret_force", false)) or rng.randf() < float(t.get("secret_chance", 0.3))):
		var b: Array = b_slots[rng.randi_range(0, b_slots.size() - 1)]
		var secrets: Array = []
		for c: Dictionary in lib.get("chunks", []):
			if c.kind == "secret":
				secrets.append(c)
		var sc: Variant = _weighted(rng, secrets)
		if sc != null:
			var wx: float = b[0]
			var row: int = b[1]
			out.wall = { "x": wx, "y": ground - row * cell, "w": cell, "h": cell * 4.0, "secret": sc.id }
			var px := wx + cell
			for s: Array in sc.get("solids", []):
				out.solids.append(Rect2(px + s[0] * cell, ground - (row + s[1] + s[3]) * cell, s[2] * cell, s[3] * cell))
			for tr: Array in sc.get("traps", []):
				out.traps.append({ "kind": tr[0], "x": px + tr[1] * cell, "y": ground - (row + tr[2]) * cell, "w": tr[3] * cell })
			for cs: Array in sc.get("C", []):
				out.chests.append({ "x": px + (cs[0] + 0.5) * cell, "y": ground - (row + cs[1]) * cell, "rich": true })
	return out

static func _mean(a: Array) -> float:
	var s := 0.0
	for v: float in a:
		s += v
	return s / maxf(1.0, a.size())

static func _weighted(rng: RandomNumberGenerator, list: Array) -> Variant:
	if list.is_empty():
		return null
	var ws: Array = []
	for c: Dictionary in list:
		ws.append(float(c.get("weight", 1.0)))
	return list[_weighted_i(rng, ws)]

static func _weighted_i(rng: RandomNumberGenerator, ws: Array) -> int:
	var total := 0.0
	for w: float in ws:
		total += w
	var r := rng.randf() * total
	for i in ws.size():
		r -= float(ws[i])
		if r < 0.0:
			return i
	return ws.size() - 1

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## Prototype genRoom(): flat room, platforms on 4 levels, packs as x only. Kept
## for the legacy checks only (room-generation §5.5).
static func _legacy(rng: RandomNumberGenerator, k: int, tier: int, t: Dictionary) -> Dictionary:
	var first := tier == 1 and k == 1
	var w: float = t.room_w_first if first else minf(t.room_w_max,
		t.room_w_base + (k - 1) * t.room_w_step + (tier - 1) * t.room_w_tier)
	var ys: Array = t.plat_levels
	var plats: Array = []
	var x := 300.0 + rng.randf() * 120.0
	while x < w - 420.0:
		var pw := 160.0 + float(rng.randi_range(0, 179))
		var lvl := rng.randi_range(0, 2)
		plats.append(Vector3(roundf(x), ys[lvl], pw))
		if lvl >= 1 and rng.randf() < 0.45:
			plats.append(Vector3(roundf(x + pw * 0.5 + 50.0), ys[lvl + 1], 140.0 + rng.randi_range(0, 89)))
		x += pw + 150.0 + rng.randf() * 260.0
	var packs: Array = []
	var base := 2 if first else 3 + int((k - 1) * 0.5) + (tier - 1)
	var px := 820.0
	while px < w - 260.0:
		var size := 2 if first else clampi(base + rng.randi_range(0, 1), 2, 8)
		var list: Array = []
		for i in size:
			var ex := px + (rng.randf() - 0.5) * 380.0
			list.append(clampf(ex, 400.0, w - 200.0))
		packs.append(list)
		if first and packs.size() >= 2:
			break
		px += t.pack_gap + rng.randf() * 260.0
	return { "w": w, "plats": plats, "packs": packs }
