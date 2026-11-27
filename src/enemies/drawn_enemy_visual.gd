## Hand-drawn enemy skin (art bible style of the drawn hero): sheets from
## tools/asset-pipeline/enemies2d/build.py, listed in the registry
## assets/art/sprites/enemies_drawn/enemies_drawn.json. Attached by ArtSlice to
## any enemy whose kind has drawn art while `navi/art/enemy_art` is "drawn"
## (the default; "sprite" keeps the Blender EnemySprite / CrawlerSprite path).
## Maps the enemy state machine to animations through the registry "states"
## map; sets Enemy.art_skin so the kind's _draw() paints only the overlay.
## Reads the enemy, never writes gameplay state: hit boxes are unchanged.
## Cut limbs: one-armed / headless sheet variants, and the flying LimbPart gets
## the real cut-out sprite (limb_severed signal).
class_name DrawnEnemyVisual
extends Node2D

const ROOT: String = "res://assets/art/sprites/enemies_drawn/"
const REGISTRY: String = ROOT + "enemies_drawn.json"
const HURT_TIME: float = 0.22
## |vel.x| above which the "moving" sheet of a state is shown, px/s.
const MOVING_SPEED: float = 5.0

static var _reg: Dictionary = {}

## The enemy shown and its kind id. Set before adding to the tree.
var enemy: Enemy
var kind: String = ""
var _meta: Dictionary = {}
var _tex: Dictionary = {}
var _sprite: Sprite2D
var _cur: String = ""
var _frame_f: float = 0.0
var _hurt_t: float = 0.0
var _last_flash: float = 0.0
var _prev_st: String = ""
## One-shot animation playing after a state (the thrower's throw), "" = none.
var _oneshot: String = ""


## The registry (loaded once).
static func registry() -> Dictionary:
	if _reg.is_empty() and FileAccess.file_exists(REGISTRY):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
		_reg = d if d is Dictionary else {}
	return _reg


## Enemy art mode: project setting navi/art/enemy_art ("drawn" | "sprite"),
## `-- --enemy-art=...` overrides it.
static func art_mode(args: PackedStringArray) -> String:
	var m := String(ProjectSettings.get_setting("navi/art/enemy_art", "drawn"))
	for a in args:
		if a.begins_with("--enemy-art="):
			m = a.trim_prefix("--enemy-art=")
	return m


## True when the kind has drawn sheets.
static func has_kind(kind_id: String) -> bool:
	return (registry().get("kinds", {}) as Dictionary).has(kind_id)


## Sheet for a state. Pure (tested): returns {anim, k_stat, variant}.
## states: the kind's registry map; anims: its anims; part: death_severed.
static func choose(states: Dictionary, anims: Dictionary, st: String, dead: bool, hurt_t: float, moving: bool,
		winding: bool, part: String, arm_off: bool, head_off: bool, oneshot: String) -> Dictionary:
	var anim := "idle"
	var k_stat := ""
	if dead:
		anim = "death"
		var p := part
		if p == "":
			p = "head" if head_off else ("arm" if arm_off else "")
		if p != "" and anims.has("death_sever_" + p):
			anim = "death_sever_" + p
		return { "anim": anim, "k_stat": "", "variant": "" }
	if oneshot != "" and anims.has(oneshot):
		anim = oneshot
	else:
		var e: Dictionary = states.get(st, {})
		anim = String(e.get("anim", "idle"))
		k_stat = String(e.get("k", ""))
		if moving and e.has("moving"):
			anim = String(e.moving)
		if hurt_t > 0.0 and not winding and k_stat == "" and anims.has("hurt") and anim in ["idle", "move"]:
			anim = "hurt"
	if not anims.has(anim):
		anim = "idle"
		k_stat = ""
	var vars: Array = (anims[anim] as Dictionary).get("variants", []) if anims.has(anim) else []
	var variant := ""
	if head_off and vars.has("nohead"):
		variant = "nohead"
	elif arm_off and vars.has("noarm"):
		variant = "noarm"
	return { "anim": anim, "k_stat": k_stat, "variant": variant }


func _ready() -> void:
	_meta = (registry().get("kinds", {}) as Dictionary).get(kind, {})
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var origin: Array = _meta.get("origin", [0, 0])
	_sprite.offset = -Vector2(float(origin[0]), float(origin[1]))
	_sprite.scale = Vector2.ONE / maxf(float(registry().get("px_per_world", 1.5)), 0.01)
	add_child(_sprite)
	if enemy:
		enemy.art_skin = true
		enemy.queue_redraw()
		enemy.limb_severed.connect(_on_limb_severed)
		_prev_st = enemy.st
	_show("idle")


func _exit_tree() -> void:
	if enemy and is_instance_valid(enemy):
		enemy.art_skin = false


func _show(key: String) -> void:
	if key == _cur:
		return
	if not _tex.has(key):
		var path := ROOT + "%s/%s_%s.png" % [kind, kind, key]
		if not ResourceLoader.exists(path):
			return
		_tex[key] = load(path) as Texture2D
	var anim := key.trim_suffix("_noarm").trim_suffix("_nohead")
	var a: Dictionary = (_meta.get("anims", {}) as Dictionary).get(anim, {})
	_cur = key
	_frame_f = 0.0
	_sprite.texture = _tex[key]
	_sprite.hframes = int(a.get("cols", 1))
	_sprite.vframes = int(a.get("rows", 1))
	_sprite.frame = 0


func _process(dt: float) -> void:
	if enemy == null or _meta.is_empty():
		return
	var anims: Dictionary = _meta.get("anims", {})
	var states: Dictionary = _meta.get("states", {})
	var bloat := enemy as Bloat
	if bloat and bloat.exploded:
		# The burst sheet once, then the bloat's own blast flash (its _draw()).
		if _oneshot != "explode":
			_oneshot = "explode"
			_show("explode")
		_advance(dt, anims.get("explode", {}), -1.0)
		if _sprite.frame >= int((anims.get("explode", {}) as Dictionary).get("frames", 1)) - 1 and _frame_f > 1.0:
			visible = false
		return
	if enemy.flash > _last_flash:
		_hurt_t = HURT_TIME
	_last_flash = enemy.flash
	_hurt_t -= dt
	if enemy.st != _prev_st:
		var after := String((states.get(_prev_st, {}) as Dictionary).get("after", ""))
		_oneshot = after if after != "" and not enemy.dead else ""
		_prev_st = enemy.st
	var pick := choose(states, anims, enemy.st, enemy.dead, _hurt_t, absf(enemy.vel.x) > MOVING_SPEED,
		enemy.is_winding(), enemy.death_severed, enemy.arm_off, enemy.head_off, _oneshot)
	var anim := String(pick.anim)
	if bloat and (enemy.st == "swell" or bloat.death_t >= 0.0) and anims.has("inflate"):
		anim = "inflate"
	var key := anim + ("_" + String(pick.variant) if String(pick.variant) != "" else "")
	_show(key)
	var k := -1.0
	if bloat and bloat.death_t >= 0.0:
		k = clampf(1.0 - bloat.death_t / maxf(enemy.stat("death_fuse"), 0.001), 0.0, 1.0)
	elif String(pick.k_stat) != "" and enemy.stats.has(String(pick.k_stat)):
		k = clampf(1.0 - enemy.t / maxf(enemy.stat(String(pick.k_stat)), 0.001), 0.0, 1.0)
	var a: Dictionary = anims.get(anim, {})
	var done := _advance(dt, a, k)
	if done and _oneshot == anim:
		_oneshot = ""
	scale.x = float(enemy.face)
	modulate = Color(2.2, 2.2, 2.2) if enemy.flash > 0.0 else Color.WHITE
	if kind == "vodyanitsa":
		queue_redraw()


## Advances the frame (by progress k >= 0, or by time); true when a one-shot ended.
func _advance(dt: float, a: Dictionary, k: float) -> bool:
	var n := maxi(1, int(a.get("frames", 1)))
	if k >= 0.0:
		_sprite.frame = HeroSprite.frame_for_progress(k, n)
		return false
	_frame_f += dt * float(a.get("fps", 8))
	var fi := int(_frame_f)
	if bool(a.get("loop", false)):
		_sprite.frame = fi % n
		return false
	_sprite.frame = mini(fi, n - 1)
	return fi >= n


## Song reach ring of the Водяница (the code-drawn telegraph of the ward song).
func _draw() -> void:
	if enemy == null or kind != "vodyanitsa" or enemy.st != "song" or enemy.dead:
		return
	var ring := Color(String(enemy.stats.get("ring", "#b6e36b")))
	var k := 1.0 - clampf(enemy.t / maxf(enemy.stat("song"), 0.01), 0.0, 1.0)
	var c := enemy.center() - enemy.position
	draw_arc(c, enemy.stat("song_r"), 0, TAU, 48, Color(ring, 0.25), 2.0)
	draw_arc(c, enemy.stat("song_r") * k, 0, TAU, 40, Color(ring, 0.6 * (1.0 - k)), 3.0)


## Cut-out part sprite for the flying piece (or null).
func part_texture(limb: String) -> Texture2D:
	var p: Dictionary = (_meta.get("parts", {}) as Dictionary).get(limb, {})
	if p.is_empty():
		return null
	var path := ROOT + "%s/%s" % [kind, String(p.file)]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _on_limb_severed(_e: Enemy, limb: String) -> void:
	var part := enemy.last_part
	if part == null or not is_instance_valid(part) or part.limb != limb:
		return
	var tex := part_texture(limb)
	if tex == null:
		return
	var p: Dictionary = (_meta.get("parts", {}) as Dictionary)[limb]
	var pv: Array = p.get("pivot", [0, 0])
	var pivot := Vector2(float(pv[0]), float(pv[1]))
	if limb == "head":
		# The head part flies about its centre (LimbPart puts the origin there).
		pivot = tex.get_size() * 0.5
	part.use_sprite(tex, pivot, 1.0 / maxf(float(registry().get("px_per_world", 1.5)), 0.01), enemy.face)
