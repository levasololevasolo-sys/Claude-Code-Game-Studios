## Art slice dressing (design/art/visual-upgrade-plan.md), on with `-- --art-slice`:
## three pre-rendered Топь parallax layers behind the room, a rendered ground
## strip and mossy-log platforms in place of the Room's own flat drawing (hidden
## with self_modulate), a CanvasModulate so the amulet light reads, and a
## CrawlerSprite on every Crawler. Added by World.start_room(); owns no gameplay.
class_name ArtSlice
extends Node2D

const DIR: String = "res://assets/art/sprites/swamp/"
## Parallax factor per layer (0 = fixed to the screen, 1 = moves with the world).
const LAYERS: Array = [["bg_far.png", 0.12, -300], ["bg_mid.png", 0.35, -290], ["bg_near.png", 0.6, -280]]
## Ground strip: px from the image top to the moss line (render: 120 px per m, centre at -0.75 m).
const GROUND_TOP_PX: float = 120.0
const AMBIENT: Color = Color("#B4C0B8")
## Layer centre above the ground line, world px (puts each layer's horizon just above it).
const LAYER_ABOVE_GROUND: float = 125.0
## Frame on which `--art-stage` places the enemies, and the crawler's distance.
const STAGE_FRAME: int = 10
const STAGE_DX: float = 520.0

## The room being dressed. Set before adding to the tree.
var room: Room
var _layers: Array[Sprite2D] = []
var _factors: Array[float] = []
var _zoom: float = 1.5
var _plat: Texture2D
var _frames: int = 0


func _ready() -> void:
	_zoom = Tune.f("camera_zoom") if Tune.data.has("camera_zoom") else 1.0
	z_index = -50
	for l: Array in LAYERS:
		var s := Sprite2D.new()
		s.texture = load(DIR + String(l[0])) as Texture2D
		s.scale = Vector2.ONE / _zoom
		s.z_index = int(l[2]) + 50
		s.z_as_relative = true
		add_child(s)
		_layers.append(s)
		_factors.append(float(l[1]))
	var g := Sprite2D.new()
	g.texture = load(DIR + "ground.png") as Texture2D
	g.centered = false
	g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_enabled = true
	var w: float = float(room.layout.get("w", 2000.0)) if room else 2000.0
	g.region_rect = Rect2(0, 0, (w + 400.0) * _zoom, g.texture.get_height())
	g.scale = Vector2.ONE / _zoom
	g.position = Vector2(-200.0, Tune.f("ground_y") - GROUND_TOP_PX / _zoom)
	g.z_index = 60
	add_child(g)
	_plat = load(DIR + "plat.png") as Texture2D
	var cm := CanvasModulate.new()
	cm.color = AMBIENT
	add_child(cm)
	if room:
		room.self_modulate.a = 0.0
	queue_redraw()


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	# Horizontal parallax only: each layer is centred when the camera frames the
	# room centre and drifts by its factor; vertically it is fixed to the ground.
	var w: float = float(room.layout.get("w", 2000.0)) if room else 2000.0
	var anchor := Vector2(w * 0.5, Tune.f("ground_y") - LAYER_ABOVE_GROUND)
	for i in _layers.size():
		var f := _factors[i]
		_layers[i].global_position = Vector2(c.x + (anchor.x - c.x) * f, anchor.y)
	_frames += 1
	if _frames == STAGE_FRAME and OS.get_cmdline_user_args().has("--art-stage"):
		_stage()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Crawler and not e.has_node("ArtSkin"):
			var cs := CrawlerSprite.new()
			cs.name = "ArtSkin"
			cs.enemy = e
			e.add_child(cs)


## Screenshot staging (`--art-stage`): the first crawler stands STAGE_DX in front
## of the hero, the other enemies are moved out of frame.
func _stage() -> void:
	var w := get_parent() as World
	if w == null or w.player == null:
		return
	var placed := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en is Crawler and not placed:
			en.position = Vector2(w.player.position.x + STAGE_DX, w.player.position.y)
			placed = true
		else:
			en.position.x = w.player.position.x + 2000.0


func _draw() -> void:
	if room == null or room.layout.is_empty():
		return
	for r: Rect2 in room.layout.get("solids", []):
		draw_rect(r, Color("#1A241D"))
		draw_texture_rect(_plat, Rect2(r.position.x - 6.0, r.position.y - 14.0, r.size.x + 12.0, 32.0), false)
	for p: Vector3 in room.layout.plats:
		draw_texture_rect(_plat, Rect2(p.x - 8.0, p.y - 12.0, p.z + 16.0, 36.0), false)
