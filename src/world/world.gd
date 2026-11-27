## Root of the combat scene (formerly Main, ADR-0002): generates one combat room,
## places the hero and sleeping enemy packs (EnemyRoster), wakes packs, runs the camera and is the only owner of
## hit feel: hitstop, screen shake and slam rings. Actors read `hitstop` but
## change these only through request_hitstop(), add_shake() and add_ring().
## Run with `-- --demo=<dir>` to play a scripted check that saves screenshots,
## `-- --enemy-check=<dir>` for the enemy check, `--room=<k>` / `--seed=<n>` to
## pick the room, `--ai-debug` to draw enemy state names.
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
## Draw each enemy's state name (AI debugging).
var ai_debug: bool = false

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
		elif a.begins_with("--room="):
			room_k = maxi(1, int(a.trim_prefix("--room=")))
		elif a == "--ai-debug":
			ai_debug = true
	RenderingServer.set_default_clear_color(Color("#0c1418"))
	start_room()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			var d: Node = (load("res://tests/integration/core/demo_driver.gd") as GDScript).new()
			d.set("out_dir", a.trim_prefix("--demo="))
			add_child(d)
		elif a.begins_with("--enemy-check="):
			var c: Node = (load("res://tests/integration/enemies/enemy_check_driver.gd") as GDScript).new()
			c.set("out_dir", a.trim_prefix("--enemy-check="))
			add_child(c)

## Clears the level and builds room number room_k of location tier.
func start_room() -> void:
	for c in get_children():
		if c is Room or c is Player or c is Enemy or c is EnemyShot or c is Camera2D or c is CanvasLayer:
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 1000 + tier * 100 + room_k
	var layout: Dictionary = RoomGen.generate(rng, room_k, tier, Tune.data)
	room = Room.new()
	add_child(room)
	room.build(layout)
	# Sleeping packs of the location roster (enemies-and-elites §3.3, room-generation §3.5).
	var table := Tune.table("enemies")
	var fly_y: Array = Tune.get_value("flyer_spawn_y")
	for i in layout.packs.size():
		var pack: Array = layout.packs[i]
		var kinds := EnemyRoster.pack_kinds(rng, pack.size(), i, room_k, tier,
			Tune.get_value("swamp_roster"), Tune.get_value("swamp_late"), table, Tune.data)
		for j in kinds.size():
			var e := EnemyRoster.make(kinds[j])
			var y := Tune.f("ground_y")
			if bool(table[kinds[j]].get("flies", false)):
				y = rng.randf_range(float(fly_y[0]), float(fly_y[1]))
			spawn_enemy(e, Vector2(pack[j], y), i, true, rng.randi())
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

## Adds an enemy to the room: injects world, tier and walls, seeds its random
## stream, and puts it to sleep in pack `pack_id` (-1 = no pack) if `sleeping`.
func spawn_enemy(e: Enemy, at: Vector2, pack_id: int, sleeping: bool, rng_seed: int) -> Enemy:
	e.world = self
	e.tier = tier
	e.room_w = float(room.layout.w) if room else 0.0
	e.pack = pack_id
	e.asleep = sleeping
	e.face = -1
	e.show_state = ai_debug
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = rng_seed
	e.position = at
	add_child(e)
	return e

## Wakes every sleeping enemy of one pack (room-generation §3.5: only that pack).
func wake_pack(pack_id: int) -> void:
	Enemy.wake_pack(get_tree().get_nodes_in_group("enemies"), pack_id)

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
		var awake := 0
		var total := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			total += 1
			if not (e as Enemy).asleep:
				awake += 1
		hud.text = "Навь — проверка основы (Godot)    Комната %d, ширина %d px    Враги: %d (не спят %d)    HP %d\nA/D бег · Пробел прыжок · J удар (W вверх, S в воздухе вниз) · Shift перекат/рывок · S+Пробел спрыгнуть" % [room_k, int(room.layout.w), total, awake, roundi(player.hp)]
	queue_redraw()

func _draw() -> void:
	for r: Dictionary in rings:
		var k: float = r.t / Tune.f("ring_time")
		draw_arc(r.p, r.r * k, PI, TAU, 32, Color(0.85, 0.75, 0.5, 1.0 - k), 6.0)
