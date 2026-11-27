## Pre-rendered hero (art slice, design/art/visual-upgrade-plan.md): sprite sheets
## rendered from a 3D model in Blender (tools/asset-pipeline/blender/build_hero.py)
## with a normal map per sheet, shown as one Sprite2D whose texture is a
## CanvasTexture, so Godot's 2D lights (the amulet PointLight2D) shade it.
## A drop-in alternative to HeroVisual, picked by `-- --hero-art=sprite` or the
## project setting `navi/art/hero_art = "sprite"` (Player.visual_scene_path()).
## Reads the Player's state every frame and never writes it; the animation choice
## is HeroVisual.choose(HeroVisual.state_of()), so both visuals agree. Attack,
## roll and dash frames are picked by the move's progress (k), like the rig.
class_name HeroSprite
extends Node2D

const SHEET_DIR: String = "res://assets/art/sprites/hero/"
const SHEETS_JSON: String = "res://assets/art/sprites/hero/hero_sheets.json"
const GLOW_COLOR: Color = Color("#FFC94A")
const HURT_TIME: float = 0.2
const FLASH_TIME: float = 1.0 / 30.0
## Run cycle length at full speed and the Player's run phase divisor (as HeroVisual).
const RUN_CYCLE_S: float = 0.5
const RUN_PH_DIV: float = 26.0
## Amulet position in the sheet cell (2x px), measured on the idle frames.
const AMULET_PX: Vector2 = Vector2(256, 238)

## Hero height on a 1080p screen, px (bible §5.1: 160).
@export var height_px: float = 160.0
## Sheet metadata and folder. A "%d" in sheet_dir is the armour tier (1..5):
## the drawn hero (tools/asset-pipeline/hero2d) has one sheet set per tier.
@export var sheets_json: String = SHEETS_JSON
@export var sheet_dir: String = SHEET_DIR
## The sheets have *_n.png normal maps (the 3D render) or not (the drawn hero).
@export var has_normals: bool = true
## The weapon is part of the rendered frames: Player skips its procedural blade.
## False for the drawn hero: Player draws the weapon at hand_point().
@export var bakes_weapon: bool = true
## Amulet light strength multiplier: the drawn sheets have no normal maps, so a
## full-strength light washes the whole flat-lit body out.
@export var light_k: float = 1.0
## The hero shown. Set before adding to the tree.
var player: Player
## Armour tier shown (1..5) when sheet_dir has a "%d"; the highest tier of any
## dressed part (set_tier), or `-- --hero-tier=N`.
var tier: int = 1
var _part_tiers: Dictionary = {}

var _meta: Dictionary = {}
var _tex: Dictionary = {}
var _sprite: Sprite2D
var _light: PointLight2D
var _cur: String = ""
var _frame_f: float = 0.0
var _hurt_t: float = 0.0
var _flash_t: float = 0.0
var _scale: float = 0.5
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_meta = load_meta(sheets_json)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero-tier="):
			tier = clampi(int(a.trim_prefix("--hero-tier=")), 1, 5)
	_sprite = $Sprite
	_light = $AmuletLight
	var zoom := Tune.f("camera_zoom") if Tune.data.has("camera_zoom") else 1.0
	_scale = height_px / zoom / float(_meta.get("height_px", 320))
	var origin: Array = _meta.get("origin", [230, 452])
	_origin = Vector2(float(origin[0]), float(origin[1]))
	_sprite.centered = false
	_sprite.offset = -Vector2(float(origin[0]), float(origin[1]))
	_sprite.scale = Vector2.ONE * _scale
	_light.position = (AMULET_PX - Vector2(float(origin[0]), float(origin[1]))) * _scale
	if player:
		player.hurt_taken.connect(_on_hurt)
		player.parry_succeeded.connect(_on_parry_succeeded)
	_show("idle")


## Parsed hero_sheets.json ({cell, origin, height_px, anims{name: frames, cols, rows, fps, loop}}).
static func load_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("HeroSprite: missing %s" % path)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## Sheet of the parry pose for a strike body ("parry_blade" for the stick and
## unknown bodies; plain "parry" if the sheets have no per-body poses).
static func parry_anim(body: String, anims: Dictionary) -> String:
	if anims.has("parry_" + body):
		return "parry_" + body
	return "parry_blade" if anims.has("parry_blade") else "parry"


## Frame index for progress k (0..1) of an n-frame move.
static func frame_for_progress(k: float, n: int) -> int:
	return clampi(int(k * float(n)), 0, maxi(n - 1, 0))


## Shows armour tier `t` for one body part (ShopRules.dress); the drawn hero
## has whole-body tier sheets, so the highest part tier is shown.
func set_tier(part: String, t: int) -> void:
	_part_tiers[part] = clampi(t, 1, 5)
	var best := 1
	for v: int in _part_tiers.values():
		best = maxi(best, v)
	set_all_tiers(best)


## Every part in tier `t` (QA lineup); no-op for single-tier sheets.
func set_all_tiers(t: int) -> void:
	if not sheet_dir.contains("%d") or clampi(t, 1, 5) == tier:
		return
	tier = clampi(t, 1, 5)
	_tex.clear()
	var keep := _cur
	_cur = ""
	if _sprite and keep != "":
		_show(keep)


## The weapon pivot (near fist) in the Player's local space, for the current
## frame; the fixed old anchor when the sheets carry no hand points.
func hand_point() -> Vector2:
	var face: float = float(player.face) if player else 1.0
	if _sprite == null or _cur == "" or not _meta.anims[_cur].has("hand"):
		return Vector2(8.0 * face, -34.0)
	var hp: Array = _meta.anims[_cur].hand[clampi(_sprite.frame, 0, _meta.anims[_cur].hand.size() - 1)]
	return transform * ((Vector2(float(hp[0]), float(hp[1])) - _origin) * _scale)


func _texture(anim_name: String) -> CanvasTexture:
	if not _tex.has(anim_name):
		var ct := CanvasTexture.new()
		var dir := sheet_dir % tier if sheet_dir.contains("%d") else sheet_dir
		ct.diffuse_texture = load(dir + "hero_%s.png" % anim_name) as Texture2D
		if has_normals:
			ct.normal_texture = load(dir + "hero_%s_n.png" % anim_name) as Texture2D
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_tex[anim_name] = ct
	return _tex[anim_name]


func _show(anim_name: String) -> void:
	var anims: Dictionary = _meta.get("anims", {})
	if not anims.has(anim_name):
		anim_name = "idle"
	if anim_name == _cur:
		return
	_cur = anim_name
	_frame_f = 0.0
	var a: Dictionary = anims[anim_name]
	_sprite.texture = _texture(anim_name)
	_sprite.hframes = int(a.cols)
	_sprite.vframes = int(a.rows)
	_sprite.frame = 0


func _process(dt: float) -> void:
	if player == null or _meta.is_empty():
		return
	var w := player.world
	var frozen := w != null and w.hitstop > 0.0
	var adt := 0.0 if frozen else dt * (w.time_mult() if w else 1.0)
	_hurt_t -= adt
	_flash_t -= dt
	var pick := HeroVisual.choose(HeroVisual.state_of(player), _hurt_t)
	var anim_name := String(pick.anim)
	if anim_name == "parry":
		anim_name = parry_anim(player.weapon.body_id() if player.weapon else "", _meta.get("anims", {}))
	_show(anim_name)
	var a: Dictionary = _meta.anims[_cur]
	var n := int(a.frames)
	var k: float = pick.k
	if k >= 0.0:
		_sprite.frame = frame_for_progress(k, n)
	else:
		var rate := 1.0
		if _cur == "run":
			rate = clampf(absf(player.velocity.x) / RUN_PH_DIV / TAU * RUN_CYCLE_S, 0.5, 1.6)
		_frame_f += adt * float(a.fps) * rate
		var fi := int(_frame_f)
		_sprite.frame = fi % n if bool(a.loop) else mini(fi, n - 1)
	var squash := 1.0 - player.land * 0.18
	scale = Vector2(float(player.face) * (2.0 - squash), squash)
	var blink := player.inv > 0.0 and player.dash_t <= 0.0 and not player.dead and int(player.inv * 20.0) % 2 == 0
	modulate = Color(3.0, 3.0, 3.0, 1.0) if _flash_t > 0.0 else Color(1, 1, 1, 0.55 if blink else 1.0)
	var fill := 0.0
	if player.amulet:
		fill = clampf(player.amulet.charge / maxf(player.amulet.ready_at(), 0.001), 0.0, 1.5)
	if a.has("amulet"):
		var ap: Array = a.amulet[_sprite.frame]
		_light.position = (Vector2(float(ap[0]), float(ap[1])) - _origin) * _scale
	_light.energy = (0.9 + 0.8 * fill) * light_k
	_light.texture_scale = (2.2 + 1.2 * fill) * (0.6 if light_k < 1.0 else 1.0)


func _on_hurt(_amount: float, _hit: Hit) -> void:
	_hurt_t = HURT_TIME
	_flash_t = FLASH_TIME


## A caught blow flashes the hero like a hit does (the recoil frame is chosen
## by HeroVisual.choose() from Player.parry_pose()).
func _on_parry_succeeded(_enemy: Enemy, _result: String) -> void:
	_flash_t = FLASH_TIME
