## Hand-drawn Застава NPC (art bible style of the drawn hero): sheets from
## tools/asset-pipeline/npc2d/build.py listed in the registry
## assets/art/sprites/npc_drawn/npc_drawn.json. A Station adds one when its id
## has drawn art and `navi/art/npc_art` is "drawn" (default; "shapes" or
## `-- --npc-art=shapes` keeps the old placeholder shapes).
## Animations: idle (loop, the NPC's signature gesture), talk (loop, while the
## dialogue box is open), react (one-shot nod / laugh after the line, then idle).
## A second copy of the frame is drawn above the Darkness layer at `lit` alpha
## (base.json "npc_lit"): the people of the yard stay readable at night, as if
## lit by their own hearths. Visual only: reads Station state, writes nothing.
class_name NpcSprite
extends Node2D

const ROOT: String = "res://assets/art/sprites/npc_drawn/"
const REGISTRY: String = ROOT + "npc_drawn.json"

static var _reg: Dictionary = {}

## NPC id ("potap", ...). Set before adding to the tree.
var npc: String = ""
## -1 faces left, 1 faces right (towards the hero). NPCs with flip = false ignore it.
var face: float = 1.0
## Alpha of the copy above the darkness, 0 = none.
var lit: float = 0.55
var _meta: Dictionary = {}
var _tex: Dictionary = {}
var _sprite: Sprite2D
var _lit: Sprite2D
var _cur: String = ""
var _frame_f: float = 0.0
var _talking: bool = false


## The registry (loaded once).
static func registry() -> Dictionary:
	if _reg.is_empty() and FileAccess.file_exists(REGISTRY):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
		if d is Dictionary:
			_reg = d
	return _reg


## NPC art mode: project setting navi/art/npc_art ("drawn" | "shapes"),
## `-- --npc-art=...` overrides it.
static func art_mode(args: PackedStringArray) -> String:
	var m := String(ProjectSettings.get_setting("navi/art/npc_art", "drawn"))
	for a in args:
		if a.begins_with("--npc-art="):
			m = a.trim_prefix("--npc-art=")
	return m


## True when `id` has drawn sheets and the art mode is "drawn".
static func has_art(id: String) -> bool:
	if art_mode(OS.get_cmdline_user_args()) != "drawn":
		return false
	var row: Dictionary = (registry().get("npcs", {}) as Dictionary).get(id, {})
	return not row.is_empty() and ResourceLoader.exists(ROOT + String((row.anims as Dictionary).idle.sheet))


## Height of the NPC above the ground, world px (0 when there is no art).
static func height_of(id: String) -> float:
	return float(((registry().get("npcs", {}) as Dictionary).get(id, {}) as Dictionary).get("height_world", 0.0))


## Portrait bust of `id` (variant "calm" | "warm"), null when there is none.
static func portrait(id: String, variant: String = "calm") -> Texture2D:
	if art_mode(OS.get_cmdline_user_args()) != "drawn":
		return null
	var row: Dictionary = (registry().get("npcs", {}) as Dictionary).get(id, {})
	var p := String((row.get("portraits", {}) as Dictionary).get(variant, ""))
	if p == "" or not ResourceLoader.exists(ROOT + p):
		return null
	return load(ROOT + p) as Texture2D


func _ready() -> void:
	_meta = (registry().get("npcs", {}) as Dictionary).get(npc, {})
	var k := 1.0 / float(registry().get("px_per_world", 2.0))
	var org: Array = _meta.get("origin", [0, 0])
	_sprite = _make(k, org)
	add_child(_sprite)
	if lit > 0.0:
		_lit = _make(k, org)
		_lit.z_as_relative = false
		_lit.z_index = Darkness.Z + 1
		_lit.modulate = Color(1, 1, 1, lit)
		add_child(_lit)
	_set_anim("idle")


func _make(k: float, org: Array) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.offset = Vector2(-float(org[0]), -float(org[1]))
	s.scale = Vector2(k, k)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return s


## Switches between the talk loop (true) and idle (false).
func set_talking(on: bool) -> void:
	_talking = on
	if on:
		_set_anim("talk")
	elif _cur == "talk":
		_set_anim("idle")


## Plays the one-shot reaction, then idle (or talk if talking again).
func react() -> void:
	_set_anim("react")


## The current animation name and frame (checks).
func current() -> String:
	return _cur


func _set_anim(a: String) -> void:
	var anims: Dictionary = _meta.get("anims", {})
	if not anims.has(a):
		a = "idle"
	if not anims.has(a):
		return
	_cur = a
	_frame_f = 0.0
	if not _tex.has(a):
		_tex[a] = load(ROOT + String(anims[a].sheet)) as Texture2D
	for s: Sprite2D in [_sprite, _lit]:
		if s:
			s.texture = _tex[a]
			s.hframes = int(anims[a].cols)
			s.vframes = int(anims[a].rows)
			s.frame = 0


func _process(dt: float) -> void:
	if _cur == "":
		return
	var an: Dictionary = (_meta.anims as Dictionary)[_cur]
	var n := int(an.frames)
	_frame_f += dt * float(an.fps)
	if _frame_f >= n:
		if bool(an.loop):
			_frame_f = fmod(_frame_f, n)
		else:
			_set_anim("talk" if _talking else "idle")
			return
	var fl := bool(_meta.get("flip", true)) and face < 0.0
	for s: Sprite2D in [_sprite, _lit]:
		if s:
			s.frame = mini(int(_frame_f), n - 1)
			s.flip_h = fl
			s.offset.x = -float(_meta.origin[0]) if not fl else -(float(_meta.cell[0]) - float(_meta.origin[0]))
