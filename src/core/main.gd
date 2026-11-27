## Entry scene: generates one combat room, places the hero and straw dummies,
## runs the camera, hitstop and screen shake. Run with `-- --demo=<dir>` to play
## a scripted check that saves screenshots into <dir>.
extends Node2D

var hitstop := 0.0
var shake := 0.0
var rings: Array = []
var room: Room
var player: Player
var cam: Camera2D
var hud: Label
var room_k := 2
var tier := 1
var seed_value := 1

func _ready() -> void:
	InputSetup.register()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
	RenderingServer.set_default_clear_color(Color("#0c1418"))
	start_room()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			var d: Node = load("res://tests/integration/core/demo_driver.gd").new()
			d.set("out_dir", a.trim_prefix("--demo="))
			add_child(d)

## Clears the level and builds room number room_k of location tier.
func start_room() -> void:
	for c in get_children():
		if c is Room or c is Player or c is StrawDummy or c is Camera2D or c is CanvasLayer:
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 1000 + tier * 100 + room_k
	var layout := RoomGen.generate(rng, room_k, tier, Tune.data)
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
	player.add_child(cam)
	cam.offset = Vector2(0, -120)
	var layer := CanvasLayer.new()
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud)
	add_child(layer)

## Adds a shock ring (down-strike slam) at a point.
func add_ring(at: Vector2, r: float) -> void:
	rings.append({ "p": at, "r": r, "t": 0.0 })

func _physics_process(dt: float) -> void:
	hitstop = maxf(0.0, hitstop - dt)
	shake = maxf(0.0, shake - dt * 30.0)
	if cam:
		cam.offset = Vector2(randf_range(-shake, shake), -120 + randf_range(-shake, shake))
	for r: Dictionary in rings:
		r.t += dt
	rings = rings.filter(func(r: Dictionary) -> bool: return r.t < 0.35)
	if hud and player:
		hud.text = "Навь — проверка основы (Godot)    Комната %d, ширина %d px\nA/D бег · Пробел прыжок · J удар (W вверх, S в воздухе вниз) · Shift перекат/рывок · S+Пробел спрыгнуть" % [room_k, int(room.layout.w)]
	queue_redraw()

func _draw() -> void:
	for r: Dictionary in rings:
		var k: float = r.t / 0.35
		draw_arc(r.p, r.r * k, PI, TAU, 32, Color(0.85, 0.75, 0.5, 1.0 - k), 6.0)
