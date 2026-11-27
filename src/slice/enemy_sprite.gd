## Generic pre-rendered enemy skin (art slice, design/art/visual-upgrade-plan.md):
## sheets from tools/asset-pipeline/blender/build_swamp_enemies.py with normal
## maps, laid over an Enemy whose own _draw() is hidden (self_modulate alpha 0).
## Reads the enemy state, never writes it, so gameplay and hitboxes are unchanged.
## Like CrawlerSprite, a Rim copy draws an outline and back light above the
## Darkness layer (visuals.json "enemy_rim"). One script for every kind in KINDS.
class_name EnemySprite
extends Node2D

const SHEET_ROOT: String = "res://assets/art/sprites/"
## Same world scale as the hero: hero sheet px per 160 px on a 1080p screen.
const HERO_SHEET_PX: float = 320.0
const HERO_HEIGHT_PX: float = 160.0
const HURT_TIME: float = 0.25
const RIM_SHADER: String = "res://assets/shaders/enemy_rim.gdshader"
## Kind -> wind-up state -> stat holding that state's duration (progress k = 1 - t / stat).
const WIND_STATS: Dictionary = {
	"bat": { "wind": "wind", "spitwind": "wind" },
	"sentry": { "aim": "aim", "bash": "bash_wind" },
	"bloat": { "swell": "fuse" },
}

## The enemy shown and its kind id (enemies.json row). Set before adding to the tree.
var enemy: Enemy
var kind: String = ""
var _meta: Dictionary = {}
var _tex: Dictionary = {}
var _sprite: Sprite2D
var _rim: Sprite2D
var _rim_mat: ShaderMaterial
var _cur: String = ""
var _frame_f: float = 0.0
var _hurt_t: float = 0.0
var _last_flash: float = 0.0


## True when a rendered sheet set exists for this enemy kind.
static func has_kind(kind_id: String) -> bool:
	return WIND_STATS.has(kind_id) and FileAccess.file_exists(sheets_json(kind_id))


## Path of a kind's sheet metadata.
static func sheets_json(kind_id: String) -> String:
	return SHEET_ROOT + "%s/%s_sheets.json" % [kind_id, kind_id]


## Animation for a state: {anim, k} (k = progress 0..1, or -1 = by time).
## swell_k: bloat fuse progress (also while its killed body counts down).
static func choose(kind_id: String, st: String, dead: bool, hurt_t: float, moving: bool, wind_k: float) -> Dictionary:
	match kind_id:
		"bat":
			if dead:
				return { "anim": "death", "k": -1.0 }
			if st == "wind":
				return { "anim": "wind", "k": wind_k }
			if st == "spitwind":
				return { "anim": "spit", "k": wind_k }
			if st == "swoop":
				return { "anim": "swoop", "k": -1.0 }
			if hurt_t > 0.0:
				return { "anim": "hurt", "k": -1.0 }
			return { "anim": "fly", "k": -1.0 }
		"sentry":
			if dead:
				return { "anim": "death", "k": -1.0 }
			if st == "aim":
				return { "anim": "aim", "k": wind_k }
			if st == "bash":
				return { "anim": "bash", "k": wind_k }
			if hurt_t > 0.0:
				return { "anim": "hurt", "k": -1.0 }
			return { "anim": "walk" if moving else "idle", "k": -1.0 }
		"bloat":
			if dead or st == "swell":
				return { "anim": "swell", "k": wind_k }
			if hurt_t > 0.0:
				return { "anim": "hurt", "k": -1.0 }
			return { "anim": "idle", "k": -1.0 }
	return { "anim": "idle", "k": -1.0 }


func _ready() -> void:
	_meta = HeroSprite.load_meta(sheets_json(kind))
	_sprite = Sprite2D.new()
	add_child(_sprite)
	var zoom := Tune.f("camera_zoom") if Tune.data.has("camera_zoom") else 1.0
	var origin: Array = _meta.get("origin", [0, 0])
	_sprite.centered = false
	_sprite.offset = -Vector2(float(origin[0]), float(origin[1]))
	_sprite.scale = Vector2.ONE * HERO_HEIGHT_PX / zoom / HERO_SHEET_PX
	_make_rim()
	if enemy:
		enemy.self_modulate.a = 0.0
	_show("idle" if (_meta.get("anims", {}) as Dictionary).has("idle") else "fly")


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


func _show(anim_name: String) -> void:
	var anims: Dictionary = _meta.get("anims", {})
	if not anims.has(anim_name) or anim_name == _cur:
		return
	_cur = anim_name
	_frame_f = 0.0
	if not _tex.has(anim_name):
		var dir := SHEET_ROOT + kind + "/"
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load(dir + "%s_%s.png" % [kind, anim_name]) as Texture2D
		ct.normal_texture = load(dir + "%s_%s_n.png" % [kind, anim_name]) as Texture2D
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


## Wind-up progress 0..1 of the enemy's current state.
func _wind_k() -> float:
	if kind == "bloat":
		var b := enemy as Bloat
		if b and b.death_t >= 0.0:
			return clampf(1.0 - b.death_t / maxf(enemy.stat("death_fuse"), 0.001), 0.0, 1.0)
	var key := String((WIND_STATS.get(kind, {}) as Dictionary).get(enemy.st, ""))
	if key == "":
		return 0.0
	return clampf(1.0 - enemy.t / maxf(enemy.stat(key), 0.001), 0.0, 1.0)


func _process(dt: float) -> void:
	if enemy == null or _meta.is_empty():
		return
	# The bloat's blast flash is its own _draw(): show it, hide the body.
	if enemy is Bloat and (enemy as Bloat).exploded:
		enemy.self_modulate.a = 1.0
		visible = false
		return
	if enemy.flash > _last_flash:
		_hurt_t = HURT_TIME
	_last_flash = enemy.flash
	_hurt_t -= dt
	var pick := choose(kind, enemy.st, enemy.dead, _hurt_t, absf(enemy.vel.x) > 5.0, _wind_k())
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
		_rim_mat.set_shader_parameter("fade", 0.0 if enemy.dead else 1.0)
