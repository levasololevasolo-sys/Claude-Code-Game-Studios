## Pre-rendered Трясинник (art slice): sheets from tools/asset-pipeline/blender/
## build_crawler.py with normal maps, laid over a Crawler whose own _draw() is
## hidden (self_modulate alpha 0). Reads the enemy state, never writes it.
## A second copy of the frame (Rim) draws only an outline and a back light with
## assets/shaders/enemy_rim.gdshader above the Darkness layer, so the dark crawler
## reads against the swamp (visuals.json "enemy_rim").
class_name CrawlerSprite
extends Node2D

const SHEET_DIR: String = "res://assets/art/sprites/crawler/"
const SHEETS_JSON: String = "res://assets/art/sprites/crawler/crawler_sheets.json"
## Same world scale as the hero: hero sheet px per 160 px on a 1080p screen.
const HERO_SHEET_PX: float = 320.0
const HERO_HEIGHT_PX: float = 160.0
const HURT_TIME: float = 0.25
const RIM_SHADER: String = "res://assets/shaders/enemy_rim.gdshader"

## The crawler shown. Set before adding to the tree.
var enemy: Crawler
var _meta: Dictionary = {}
var _tex: Dictionary = {}
var _sprite: Sprite2D
var _rim: Sprite2D
var _rim_mat: ShaderMaterial
var _cur: String = ""
var _frame_f: float = 0.0
var _hurt_t: float = 0.0
var _last_flash: float = 0.0


func _ready() -> void:
	_meta = HeroSprite.load_meta(SHEETS_JSON)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	var zoom := Tune.f("camera_zoom") if Tune.data.has("camera_zoom") else 1.0
	var origin: Array = _meta.get("origin", [300, 372])
	_sprite.centered = false
	_sprite.offset = -Vector2(float(origin[0]), float(origin[1]))
	_sprite.scale = Vector2.ONE * HERO_HEIGHT_PX / zoom / HERO_SHEET_PX
	_make_rim()
	if enemy:
		enemy.self_modulate.a = 0.0
	_show("idle")


## The rim copy: same frame and transform, drawn just above the Darkness.
func _make_rim() -> void:
	var rim: Dictionary = Tune.table("visuals").get("enemy_rim", {})
	if rim.is_empty() or not ResourceLoader.exists(RIM_SHADER):
		return
	_rim = Sprite2D.new()
	_rim.name = "Rim"
	_rim.centered = false
	_rim.offset = _sprite.offset
	_rim.scale = _sprite.scale
	_rim.z_as_relative = false
	_rim.z_index = Darkness.Z + 1
	_rim_mat = ShaderMaterial.new()
	_rim_mat.shader = load(RIM_SHADER) as Shader
	_rim_mat.set_shader_parameter("rim_col", Color(String(rim.get("col", "#b8e0c4"))))
	_rim_mat.set_shader_parameter("rim_alpha", float(rim.get("alpha", 0.5)))
	_rim_mat.set_shader_parameter("width", float(rim.get("width", 5.0)))
	_rim_mat.set_shader_parameter("back_col", Color(String(rim.get("back", "#e8f4c8"))))
	_rim_mat.set_shader_parameter("back_alpha", float(rim.get("back_alpha", 0.55)))
	_rim.material = _rim_mat
	_rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_rim)


## Animation for a crawler state: {anim, k} (k = progress 0..1, or -1 = by time).
static func choose(st: String, dead: bool, hurt_t: float, moving: bool, wind_k: float) -> Dictionary:
	if dead:
		return { "anim": "death", "k": -1.0 }
	if st == "wind" or st == "crouch":
		return { "anim": "windup", "k": wind_k }
	if st == "charge" or st == "leap":
		return { "anim": "attack", "k": -1.0 }
	if hurt_t > 0.0:
		return { "anim": "hurt", "k": -1.0 }
	if st == "walk" and moving:
		return { "anim": "walk", "k": -1.0 }
	return { "anim": "idle", "k": -1.0 }


func _show(anim_name: String) -> void:
	var anims: Dictionary = _meta.get("anims", {})
	if not anims.has(anim_name) or anim_name == _cur:
		return
	_cur = anim_name
	_frame_f = 0.0
	if not _tex.has(anim_name):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load(SHEET_DIR + "crawler_%s.png" % anim_name) as Texture2D
		ct.normal_texture = load(SHEET_DIR + "crawler_%s_n.png" % anim_name) as Texture2D
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_tex[anim_name] = ct
	var a: Dictionary = anims[anim_name]
	_sprite.texture = _tex[anim_name]
	_sprite.hframes = int(a.cols)
	_sprite.vframes = int(a.rows)
	_sprite.frame = 0
	if _rim:
		_rim.texture = (_tex[anim_name] as CanvasTexture).diffuse_texture
		_rim.hframes = _sprite.hframes
		_rim.vframes = _sprite.vframes


func _process(dt: float) -> void:
	if enemy == null or _meta.is_empty():
		return
	if enemy.flash > _last_flash:
		_hurt_t = HURT_TIME
	_last_flash = enemy.flash
	_hurt_t -= dt
	var wind := maxf(enemy.stat("wind"), 0.001)
	var pick := choose(enemy.st, enemy.dead, _hurt_t, absf(enemy.vel.x) > 5.0, clampf(1.0 - enemy.t / wind, 0.0, 1.0))
	_show(String(pick.anim))
	var a: Dictionary = _meta.anims[_cur]
	var n := int(a.frames)
	if float(pick.k) >= 0.0:
		_sprite.frame = HeroSprite.frame_for_progress(float(pick.k), n)
	else:
		_frame_f += dt * float(a.fps)
		var fi := int(_frame_f)
		_sprite.frame = fi % n if bool(a.loop) else mini(fi, n - 1)
	scale.x = float(enemy.face)
	modulate = Color(2.5, 2.5, 2.5) if enemy.flash > 0.0 else Color.WHITE
	if _rim:
		_rim.frame = _sprite.frame
		# The rim fades out with the death animation.
		_rim_mat.set_shader_parameter("fade", 0.0 if enemy.dead else 1.0)
