## The hero: run, variable jump, coyote time, jump buffer, ground roll / air dash,
## a three-swing blade combo, an up strike, and a down strike that pogos off foes
## and slams the ground. The origin sits at the feet. Ported from updatePlayer().
class_name Player
extends CharacterBody2D

signal hit_landed(enemy: Node2D, dmg: float)

const W := 28.0
const H := 64.0
const PLATFORM_LAYER := 2

var world: Node  ## Needs `hitstop: float`, `shake: float` and enemies in group "enemies".
var hp := 100.0
var face := 1
var coyote_t := 0.0
var jump_buf := 0.0
var atk_buf := 0.0
var drop_t := 0.0
var dash_t := 0.0
var dash_dur := 0.0
var dash_cd := 0.0
var dash_dir := 1
var rolling := false
var inv := 0.0
var atk_t := 0.0
var atk_dur := 0.0
var atk_dir := "side"
var combo := 0
var combo_t := 0.0
var slammed := false
var hit_set: Array = []
var run_ph := 0.0
var land := 0.0
var ghosts: Array = []
var was_on_floor := false
var fall_v := 0.0
## Scripted input for automated runs: action name -> true. Empty means read the real Input.
## Set `scripted` to true and fill `fake` with action -> bool to drive the hero from a test.
var scripted := false
var fake: Dictionary = {}
var _fake_prev: Dictionary = {}

func _ready() -> void:
	hp = Tune.f("player_hp")
	collision_mask = 1 | PLATFORM_LAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	shape.shape = rect
	shape.position = Vector2(0, -H / 2.0)
	add_child(shape)
	floor_snap_length = 6.0

func _held(a: String) -> bool:
	return fake.get(a, false) if scripted else Input.is_action_pressed(a)

func _tapped(a: String) -> bool:
	if scripted:
		return fake.get(a, false) and not _fake_prev.get(a, false)
	return Input.is_action_just_pressed(a)

func _physics_process(dt: float) -> void:
	if world and world.hitstop > 0.0:
		return
	var mx := (1 if _held("move_right") else 0) - (1 if _held("move_left") else 0)
	if _tapped("jump"):
		jump_buf = Tune.f("jump_buffer")
	if _tapped("strike"):
		atk_buf = 0.2
	var on_floor := is_on_floor()
	if _tapped("dash") and dash_cd <= 0.0 and dash_t <= 0.0:
		rolling = on_floor
		dash_dur = Tune.f("roll_time") if rolling else Tune.f("dash_time")
		dash_t = dash_dur
		dash_cd = Tune.f("dash_cooldown")
		dash_dir = mx if mx != 0 else face
		face = dash_dir
		inv = maxf(inv, dash_dur + 0.05)
		atk_t = 0.0
	if dash_t > 0.0:
		dash_t -= dt
		if rolling:
			velocity.x = dash_dir * Tune.f("dash_speed") * Tune.f("dash_time") / Tune.f("roll_time") * 1.1
			velocity.y = minf(velocity.y + Tune.f("gravity") * dt, Tune.f("max_fall"))
		else:
			velocity.x = dash_dir * Tune.f("dash_speed")
			velocity.y = 0.0
			if int(dash_t / 0.025) != int((dash_t + dt) / 0.025):
				ghosts.append({ "p": position, "t": 0.28, "face": face })
		if dash_t <= 0.0:
			velocity.x = dash_dir * Tune.f("run_speed")
	else:
		var slow := 0.35 if atk_t > 0.0 else 1.0
		var target := mx * Tune.f("run_speed") * slow
		velocity.x += (target - velocity.x) * minf(1.0, dt * (16.0 if on_floor else 9.0))
		if mx != 0 and atk_t <= 0.0:
			face = mx
		var g := Tune.f("gravity")
		if not _held("jump") and velocity.y < 0.0:
			g *= Tune.f("jump_cut_gravity")
		velocity.y = minf(velocity.y + g * dt, Tune.f("max_fall"))
		if jump_buf > 0.0:
			if _held("move_down") and on_floor and _on_platform():
				drop_t = 0.22
				jump_buf = 0.0
			elif on_floor or coyote_t > 0.0:
				velocity.y = -Tune.f("jump_speed")
				coyote_t = 0.0
				jump_buf = 0.0
	_update_attack(dt, on_floor)
	combo_t -= dt; dash_cd -= dt; jump_buf -= dt; coyote_t -= dt; inv -= dt; atk_buf -= dt; drop_t -= dt
	set_collision_mask_value(PLATFORM_LAYER, drop_t <= 0.0)
	fall_v = velocity.y
	move_and_slide()
	on_floor = is_on_floor()
	if on_floor:
		coyote_t = Tune.f("coyote")
		if not was_on_floor:
			land = clampf(fall_v / 1100.0, 0.2, 1.0)
			if atk_t > 0.0 and atk_dir == "down" and not slammed and fall_v > 500.0:
				_slam()
	was_on_floor = on_floor
	run_ph += dt * (absf(velocity.x) / 26.0 if on_floor else 0.0)
	land = maxf(0.0, land - dt * 5.0)
	for gh: Dictionary in ghosts:
		gh.t -= dt
	ghosts = ghosts.filter(func(gh: Dictionary) -> bool: return gh.t > 0.0)
	_fake_prev = fake.duplicate()
	queue_redraw()

func _on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is CollisionObject2D and (col as CollisionObject2D).get_collision_layer_value(PLATFORM_LAYER):
			return true
	return position.y < Tune.f("ground_y") - 1.0

func _blade() -> Dictionary:
	return Tune.get_value("blade")

func _update_attack(dt: float, on_floor: bool) -> void:
	var b := _blade()
	var times: Array = b.times
	if atk_buf > 0.0 and dash_t <= 0.0 and atk_t <= 0.0:
		atk_dir = "up" if _held("move_up") else ("down" if _held("move_down") and not on_floor else "side")
		combo = (combo % times.size()) + 1 if atk_dir == "side" and combo_t > 0.0 else 1
		atk_t = float(times[combo - 1]) * (1.0 if atk_dir == "side" else 1.1)
		atk_dur = atk_t
		combo_t = atk_t + 0.3
		hit_set.clear()
		slammed = false
		atk_buf = 0.0
		if atk_dir == "side":
			velocity.x += face * float(b.lunge)
	if atk_t > 0.0:
		atk_t -= dt
		var k := 1.0 - atk_t / atk_dur
		if atk_dir == "down":
			velocity.y = maxf(velocity.y, Tune.f("down_fall") * k)
		var win: Array = b.win
		if (k > win[0] and k < win[1]) or (atk_dir == "down" and k > win[0]):
			_strike_hits()

## The strike's hit rectangle in world space, for the current direction.
func strike_rect() -> Rect2:
	var reach := float(_blade().reach)
	var vr := reach * 0.9 + 20.0
	match atk_dir:
		"up":
			return Rect2(position.x - 40.0 + face * 26.0, position.y - H - vr, 80.0, H + vr + 4.0)
		"down":
			return Rect2(position.x - 40.0, position.y - 20.0, 80.0, vr + 20.0)
	var x0 := position.x if face > 0 else position.x - reach - 12.0
	return Rect2(x0, position.y - H - 14.0, reach + 12.0, H + 20.0)

func _strike_hits() -> void:
	var b := _blade()
	var r := strike_rect()
	var mult: Array = b.mult
	combo = clampi(combo, 1, mult.size())
	var fin := combo == mult.size()
	for e: Node2D in get_tree().get_nodes_in_group("enemies"):
		if e in hit_set or e.get("dead"):
			continue
		var er := Rect2(e.position.x - e.w / 2.0, e.position.y - e.h, e.w, e.h)
		if not r.intersects(er):
			continue
		hit_set.append(e)
		var dmg := Tune.f("strike_dmg") * float(mult[combo - 1])
		if e.position.y < Tune.f("ground_y") - 8.0 and not e.get("flies"):
			dmg *= Tune.f("air_mult")
		var kb := Tune.f("knockback") * (1.8 if fin else 1.0)
		var from_x := position.x if atk_dir == "side" else e.position.x - face
		e.hurt(dmg, from_x, kb)
		if atk_dir == "up" and not e.get("flies"):
			e.launch(Tune.f("launch_speed"))
		if atk_dir == "down":
			velocity.y = -Tune.f("pogo_speed")
			atk_t = 0.0
		if world:
			world.hitstop = Tune.f("hitstop")
			world.shake = maxf(world.shake, 4.0 if fin else 2.0)
		hit_landed.emit(e, dmg)

func _slam() -> void:
	slammed = true
	if world:
		world.shake = maxf(world.shake, 9.0)
		world.add_ring(position, Tune.f("slam_r"))
	for e: Node2D in get_tree().get_nodes_in_group("enemies"):
		if e.get("dead"):
			continue
		if absf(e.position.x - position.x) < Tune.f("slam_r") and absf(e.position.y - position.y) < 90.0:
			e.hurt(Tune.f("slam_dmg"), position.x, 380.0)

# ---------------- drawing (placeholder art until the asset pass) ----------------
const CLOAK := Color("#2f4a52")
const CLOAK_DARK := Color("#1d3036")
const SKIN := Color("#d9c7a3")
const BLADE := Color("#e8f1f2")
const GLOW := Color("#ffd27a")

func _draw() -> void:
	for gh: Dictionary in ghosts:
		var gp: Vector2 = gh.p - position
		draw_rect(Rect2(gp.x - W / 2.0, gp.y - H, W, H), Color(0.6, 0.85, 0.9, gh.t * 1.4))
	var spin := 0.0
	if dash_t > 0.0 and rolling:
		spin = (1.0 - dash_t / dash_dur) * TAU * face
	var squash := 1.0 - land * 0.18
	draw_set_transform(Vector2(0, -H * 0.45 * squash), spin, Vector2(face * (2.0 - squash), squash))
	var bob := sin(run_ph) * 2.0 if is_on_floor() else 0.0
	var flash := inv > 0.0 and dash_t <= 0.0 and int(inv * 20.0) % 2 == 0
	var cl := CLOAK.lerp(Color.WHITE, 0.5) if flash else CLOAK
	# legs
	var stride := sin(run_ph) * 9.0 if is_on_floor() else 4.0
	draw_line(Vector2(-4, 14), Vector2(-4 + stride, 29), CLOAK_DARK, 6.0)
	draw_line(Vector2(4, 14), Vector2(4 - stride, 29), CLOAK_DARK, 6.0)
	# cloak body
	draw_colored_polygon(PackedVector2Array([Vector2(-13, 16), Vector2(-9, -14 + bob), Vector2(9, -14 + bob),
		Vector2(15, 16), Vector2(4, 12), Vector2(-4, 18)]), cl)
	# hood and face
	draw_circle(Vector2(1, -20 + bob), 11.0, cl)
	draw_circle(Vector2(5, -19 + bob), 6.0, SKIN.darkened(0.55))
	draw_circle(Vector2(7, -20 + bob), 1.8, GLOW)
	# lantern at the hip
	draw_line(Vector2(-8, 2), Vector2(-11, 10), CLOAK_DARK, 2.0)
	draw_circle(Vector2(-11, 13), 4.5, GLOW)
	draw_circle(Vector2(-11, 13), 9.0, Color(GLOW, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_blade()

func _blade_angle() -> float:
	if atk_t <= 0.0:
		return 2.2 if dash_t > 0.0 and rolling else 0.9
	var k := clampf(1.0 - atk_t / atk_dur, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	match atk_dir:
		"up": return lerpf(0.4, -2.6, k)
		"down": return lerpf(-0.6, 2.4, k)
	return lerpf(-2.0, 0.9, k) if combo % 2 == 1 else lerpf(1.2, -1.6, k)

func _draw_blade() -> void:
	var hand := Vector2(8.0 * face, -34.0)
	var a := _blade_angle()
	var dir := Vector2(cos(a) * face, sin(a))
	var length := float(_blade().reach) * 0.72
	if atk_t > 0.0:
		var steps := 8
		var k := clampf(1.0 - atk_t / atk_dur, 0.0, 1.0)
		for i in steps:
			var kk := maxf(0.0, k - i * 0.04)
			var saved := atk_t
			atk_t = atk_dur * (1.0 - kk)
			var aa := _blade_angle()
			atk_t = saved
			var dd := Vector2(cos(aa) * face, sin(aa))
			draw_line(hand + dd * 14.0, hand + dd * length, Color(1, 0.95, 0.8, 0.28 - i * 0.03), 10.0 - i)
	draw_line(hand, hand + dir * 12.0, Color("#6b4a2b"), 4.0)
	draw_line(hand + dir * 12.0, hand + dir * length, BLADE, 3.5)
