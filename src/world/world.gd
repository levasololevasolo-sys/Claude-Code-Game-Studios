## Root of the combat scene (formerly Main, ADR-0002): generates one combat room,
## places the hero and straw dummies, runs the camera and is the only owner of
## hit feel: hitstop, screen shake and slam rings. Actors read `hitstop` but
## change these only through request_hitstop(), add_shake() and add_ring().
## Run with `-- --demo=<dir>` to play a scripted check that saves screenshots.
class_name World
extends Node2D

## Seconds of freeze left after a hit; actors skip their update while above 0.
## Read-only for actors: use request_hitstop().
var hitstop: float = 0.0
## Current screen shake strength in px. Read-only for actors: use add_shake().
var shake: float = 0.0
## Active slam shock rings: {p: Vector2, r: float, t: float}.
var rings: Array[Dictionary] = []
var room: Room
var player: Player
var cam: Camera2D
var hud: Label
var room_k: int = 2
var tier: int = 1
var seed_value: int = 1

## Camera framing offset in world units (prototype px): the hero sits below centre.
const CAM_OFFSET: Vector2 = Vector2(0, -120)
## HUD text size in 1080p screen px (ADR-0004: HUD is laid out for 1920x1080, not
## scaled by the camera). Moves to assets/ui/theme.tres when the theme exists.
const HUD_FONT_SIZE: int = 27
## HUD margin from the top-left corner, 1080p screen px.
const HUD_MARGIN: Vector2 = Vector2(24, 18)

func _ready() -> void:
	InputSetup.register()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
	RenderingServer.set_default_clear_color(Color("#0c1418"))
	start_room()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			var d: Node = (load("res://tests/integration/core/demo_driver.gd") as GDScript).new()
			d.set("out_dir", a.trim_prefix("--demo="))
			add_child(d)

## Clears the level and builds room number room_k of location tier.
func start_room() -> void:
	for c in get_children():
		if c is Room or c is Player or c is Enemy or c is Camera2D or c is CanvasLayer:
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 1000 + tier * 100 + room_k
	var layout: Dictionary = RoomGen.generate(rng, room_k, tier, Tune.data)
	room = Room.new()
	add_child(room)
	room.build(layout)
	for pack: Array in layout.packs:
		for x: float in pack:
			var d := StrawDummy.new()
			d.world = self
			d.position = Vector2(x, Tune.f("ground_y"))
			add_child(d)
	player = Player.new()
	player.world = self
	player.position = Vector2(160, Tune.f("ground_y"))
	add_child(player)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(layout.w)
	cam.limit_bottom = int(Tune.f("ground_y") + 220)
	cam.limit_top = -400
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	# ADR-0004: the screen is 1920x1080 but the world stays in prototype units;
	# zoom maps them, so the view shows 1280x720 units on 16:9 (more width on 21:9).
	cam.zoom = Vector2.ONE * Tune.f("camera_zoom")
	player.add_child(cam)
	cam.offset = CAM_OFFSET
	var layer := CanvasLayer.new()
	hud = Label.new()
	hud.position = HUD_MARGIN
	hud.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	layer.add_child(hud)
	add_child(layer)

## Freezes the action for `t` seconds. A running hitstop is extended to the
## larger of the two, never summed (GDD movement-and-combat §3.10, F13).
func request_hitstop(t: float) -> void:
	hitstop = maxf(hitstop, t)

## Shakes the screen with strength `s` px; the stronger shake wins.
func add_shake(s: float) -> void:
	shake = maxf(shake, s)

## Adds a shock ring (down-strike slam) at a point.
func add_ring(at: Vector2, r: float) -> void:
	rings.append({ "p": at, "r": r, "t": 0.0 })

func _physics_process(dt: float) -> void:
	hitstop = maxf(0.0, hitstop - dt)
	shake = maxf(0.0, shake - dt * Tune.f("shake_decay"))
	if cam:
		# Shake moves the offset, never the zoom (ADR-0004).
		cam.offset = CAM_OFFSET + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	for r: Dictionary in rings:
		r.t += dt
	var ring_time := Tune.f("ring_time")
	rings.assign(rings.filter(func(r: Dictionary) -> bool: return r.t < ring_time))
	if hud and player:
		hud.text = "Навь — проверка основы (Godot)    Комната %d, ширина %d px\nA/D бег · Пробел прыжок · J удар (W вверх, S в воздухе вниз) · Shift перекат/рывок · S+Пробел спрыгнуть" % [room_k, int(room.layout.w)]
	queue_redraw()

func _draw() -> void:
	for r: Dictionary in rings:
		var k: float = r.t / Tune.f("ring_time")
		draw_arc(r.p, r.r * k, PI, TAU, 32, Color(0.85, 0.75, 0.5, 1.0 - k), 6.0)
