## What the hero knows of the level, for the minimap and the full map (GDD
## level-structure §3.6). Pure state over a LevelGen level: no nodes, so the
## reveal rules are unit-tested (tests/unit/level_gen/).
## Rules: a room opens whole when the hero enters it; the rooms its open sockets
## lead to become "seen" (outline with "?"); the trails a fork closed are
## crossed out; chests show in opened rooms until opened; a breakable wall shows
## only after its first hit; the lair shows ONLY after the hero has seen its
## door (entered the lair gate room or had the door on screen) — no arrow before
## (developer decision 27.11).
class_name LevelMap
extends RefCounted

var level: Dictionary = {}
var visited: Dictionary = {}
var seen: Dictionary = {}
var lair_seen: bool = false
## Room index -> true for rooms of trails closed by roots.
var closed: Dictionary = {}
## Shrine room index -> true once its reward was taken.
var taken: Dictionary = {}
## Fork room index -> the chosen gate's info ({type, god}).
var chosen: Dictionary = {}
## Chest index (level.chests) -> true once opened.
var opened: Dictionary = {}
## Wall index (level.walls) -> true once hit.
var hit_walls: Dictionary = {}
var _nbrs: Dictionary = {}

func _init(p_level: Dictionary = {}) -> void:
	level = p_level
	for e: Array in level.get("edges", []):
		var a := int(e[0])
		var b := int(e[1])
		if not _nbrs.has(a):
			_nbrs[a] = []
		if not _nbrs.has(b):
			_nbrs[b] = []
		(_nbrs[a] as Array).append(b)
		(_nbrs[b] as Array).append(a)

## The hero entered room `i`: it opens, its neighbours become seen.
func visit(i: int) -> void:
	if i < 0 or i >= (level.get("rooms", []) as Array).size():
		return
	visited[i] = true
	seen.erase(i)
	for n: int in _nbrs.get(i, []):
		if not visited.has(n):
			seen[n] = true
	if i == int(level.get("lairgate", -1)):
		lair_seen = true

## The lair door was on screen.
func see_lair() -> void:
	lair_seen = true

## "visited", "seen" or "hidden".
func state(i: int) -> String:
	if visited.has(i):
		return "visited"
	if seen.has(i):
		return "seen"
	return "hidden"

## The fork in room `fork_room` chose a gate: the other trails' rooms are closed.
func choose(fork_room: int, info: Dictionary, closed_rooms: Array) -> void:
	chosen[fork_room] = info
	for r: int in closed_rooms:
		closed[r] = true

## Icons to draw: [{kind, at (Vector2, module units from the level's top-left),
## room, grey (bool), info}]. Kinds: fork, shrine, chest, wall, spring, lair.
func icons() -> Array:
	var out: Array = []
	var mw := float(level.get("module_w", 16))
	var mh := float(level.get("module_h", 9))
	var rooms: Array = level.get("rooms", [])
	var shrines: Array = level.get("shrines", [])
	var lg := int(level.get("lairgate", -1))
	for m: Dictionary in level.get("marks", []):
		var ri := int(m.room)
		var c: Vector2i = m.c
		var at := Vector2((c.x + 0.5) / mw, (c.y + 0.5) / mh)
		var ch := String(m.ch)
		if ch == "L" and ri == lg and lair_seen:
			out.append({ "kind": "lair", "at": at, "room": ri, "grey": false, "info": {} })
		if not visited.has(ri):
			continue
		var kind := String((rooms[ri] as Dictionary).kind)
		if ch == "H":
			if kind == "fork":
				out.append({ "kind": "fork", "at": at, "room": ri, "grey": false, "info": chosen.get(ri, {}) })
			elif ri in shrines:
				out.append({ "kind": "shrine", "at": at, "room": ri, "grey": taken.has(ri), "info": {} })
			elif ri == lg:
				out.append({ "kind": "spring", "at": at, "room": ri, "grey": false, "info": {} })
	var chests: Array = level.get("chests", [])
	for i in chests.size():
		var ch: Dictionary = chests[i]
		if visited.has(int(ch.room)) and not opened.has(i):
			var c: Vector2i = ch.c
			out.append({ "kind": "chest", "at": Vector2((c.x + 0.5) / mw, (c.y + 0.5) / mh), "room": int(ch.room), "grey": false, "info": {} })
	var walls: Array = level.get("walls", [])
	for i in walls.size():
		if hit_walls.has(i):
			var c: Vector2i = (walls[i] as Dictionary).c0
			out.append({ "kind": "wall", "at": Vector2((c.x + 0.5) / mw, (c.y + 2.0) / mh), "room": int((walls[i] as Dictionary).room), "grey": false, "info": {} })
	return out

## True when the map shows the lair (an icon of kind "lair").
func shows_lair() -> bool:
	for ic: Dictionary in icons():
		if String(ic.kind) == "lair":
			return true
	return false
