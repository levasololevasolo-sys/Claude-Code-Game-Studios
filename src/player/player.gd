## The hero: run, variable jump, coyote time, jump buffer, ground roll / air dash,
## a three-swing blade combo, an up strike, and a down strike that pogos off foes
## and slams the ground. The origin sits at the feet. Ported from updatePlayer().
## Wears an Amulet (GDD amulet-and-flare): landed hits charge it, a health hit in
## overcharge spills it, the `flare` action starts the 0.12 s breath (world slow,
## hero frozen and invulnerable) and then releases a Flare of the amulet's shape.
class_name Player
extends CharacterBody2D

## Emitted when a strike connects with an enemy; dmg is what the enemy took.
signal hit_landed(enemy: Enemy, dmg: float)
## Emitted when the hero loses hp (shield-absorbed damage excluded).
signal hurt_taken(amount: float, hit: Hit)
## Emitted once when hp reaches 0.
signal died(hit: Hit)
## Emitted when the breath ends, just before the new Flare enters the world (an
## instant shape strikes in its _ready, so listeners connect to `struck` here).
signal flare_released(flare: Flare)
## Emitted at the end of every physics tick, hitstop ticks included. Test drivers
## await it so the input they set is guaranteed to have been read.
signal stepped

const W: float = 28.0
const H: float = 64.0
const PLATFORM_LAYER: int = 2

## The combat scene root: hit feel goes through request_hitstop(), add_shake(),
## add_ring(). Null in isolated tests.
var world: World
var hp: float = 100.0
## Shield points (from Zhiva); absorbs damage before hp (GDD §3.11).
var shield: float = 0.0
var dead: bool = false
var face: int = 1
var coyote_t: float = 0.0
var jump_buf: float = 0.0
var atk_buf: float = 0.0
var drop_t: float = 0.0
var dash_t: float = 0.0
var dash_dur: float = 0.0
var dash_cd: float = 0.0
var dash_dir: int = 1
var rolling: bool = false
var inv: float = 0.0
var atk_t: float = 0.0
var atk_dur: float = 0.0
var atk_dir: String = "side"
var combo: int = 0
var combo_t: float = 0.0
var slammed: bool = false
var hit_set: Array[Enemy] = []
var run_ph: float = 0.0
var land: float = 0.0
var ghosts: Array[Dictionary] = []
var was_on_floor: bool = false
var fall_v: float = 0.0
## The worn amulet (injected by World; a ring amulet is made if left null).
var amulet: Amulet
## Element of the Flare. HOOK: set from the god of the Flare-slot rune when
## gods-and-runes is ported (FlareElement documents the ids); "pure" = no rune.
var flare_element: String = FlareElement.PURE
## Seconds of the breath left (frozen, invulnerable, world slowed); 0 = none.
var flare_t: float = 0.0
## Power P captured at the press (F3).
var flare_p: float = 0.0
## Buffered Flare press (during a dash), s.
var flare_buf: float = 0.0
## Scripted input for automated runs. Set `scripted` to true and fill `fake` with
## action -> bool to drive the hero instead of the real Input.
var scripted: bool = false
var fake: Dictionary = {}
var _fake_prev: Dictionary = {}
var _tap_jump: bool = false
var _tap_strike: bool = false
var _tap_dash: bool = false
var _tap_flare: bool = false

func _ready() -> void:
	hp = Tune.f("player_hp")
	collision_mask = 1 | PLATFORM_LAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	shape.shape = rect
	shape.position = Vector2(0, -H / 2.0)
	add_child(shape)
	floor_snap_length = Tune.f("floor_snap")
	if amulet == null:
		amulet = Amulet.make("ring", Tune.data)
	Events.enemy_killed.connect(_on_enemy_killed)
	# Input before damage in one tick (amulet-and-flare §5): the hero's tick runs
	# before the enemies', the World's (hitstop/slow clocks) before the hero's.
	process_physics_priority = -1

func _held(a: StringName) -> bool:
	return bool(fake.get(a, false)) if scripted else Input.is_action_pressed(a)

func _tapped(a: StringName) -> bool:
	if scripted:
		return bool(fake.get(a, false)) and not bool(_fake_prev.get(a, false))
	return Input.is_action_just_pressed(a)

func _physics_process(dt: float) -> void:
	# Read taps before the hitstop freeze: just_pressed lasts one tick and would be lost.
	if _tapped(&"jump"):
		_tap_jump = true
	if _tapped(&"strike"):
		_tap_strike = true
	if _tapped(&"dash"):
		_tap_dash = true
	if _tapped(&"flare"):
		_tap_flare = true
	if world and world.hitstop > 0.0:
		_end_tick()
		return
	_step(dt)
	_end_tick()

func _end_tick() -> void:
	_fake_prev = fake.duplicate()
	stepped.emit()

func _step(dt: float) -> void:
	var mx: int = (1 if _held(&"move_right") else 0) - (1 if _held(&"move_left") else 0)
	if _tap_jump:
		jump_buf = Tune.f("jump_buffer")
	if _tap_strike:
		atk_buf = Tune.f("strike_buffer")
	var want_dash: bool = _tap_dash
	if _tap_flare:
		flare_buf = Tune.f("flare_buffer")
	_tap_jump = false
	_tap_strike = false
	_tap_dash = false
	_tap_flare = false
	if flare_t > 0.0:
		_breath(dt)
		return
	if flare_buf > 0.0 and dash_t <= 0.0:
		flare_buf = 0.0
		if _press_flare():
			_breath(0.0)
			return
	flare_buf -= dt
	var on_floor := is_on_floor()
	if want_dash and dash_cd <= 0.0 and dash_t <= 0.0:
		rolling = on_floor
		dash_dur = Tune.f("roll_time") if rolling else Tune.f("dash_time")
		dash_t = dash_dur
		dash_cd = Tune.f("dash_cooldown")
		dash_dir = mx if mx != 0 else face
		face = dash_dir
		inv = maxf(inv, dash_dur + 0.05)
		atk_t = 0.0
		if amulet.dash_charge() > 0.0:
			amulet.add_flat(amulet.dash_charge())
	if dash_t > 0.0:
		dash_t -= dt
		if rolling:
			velocity.x = dash_dir * Tune.f("dash_speed") * Tune.f("dash_time") / Tune.f("roll_time") * Tune.f("roll_speed_mult")
			velocity.y = minf(velocity.y + Tune.f("gravity") * dt, Tune.f("max_fall"))
		else:
			velocity.x = dash_dir * Tune.f("dash_speed")
			velocity.y = 0.0
			var gi := Tune.f("ghost_interval")
			if int(dash_t / gi) != int((dash_t + dt) / gi):
				ghosts.append({ "p": position, "t": Tune.f("ghost_life"), "face": face })
		if dash_t <= 0.0:
			velocity.x = dash_dir * Tune.f("run_speed")
	else:
		var slow := Tune.f("attack_move_slow") if atk_t > 0.0 else 1.0
		var target := mx * Tune.f("run_speed") * slow
		velocity.x += (target - velocity.x) * minf(1.0, dt * (Tune.f("accel_ground") if on_floor else Tune.f("accel_air")))
		if mx != 0 and atk_t <= 0.0:
			face = mx
		var g := Tune.f("gravity")
		if not _held(&"jump") and velocity.y < 0.0:
			g *= Tune.f("jump_cut_gravity")
		velocity.y = minf(velocity.y + g * dt, Tune.f("max_fall"))
		if jump_buf > 0.0:
			if _held(&"move_down") and on_floor and _on_platform():
				drop_t = Tune.f("drop_time")
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
			land = clampf(fall_v / Tune.f("land_ref_speed"), 0.2, 1.0)
			if atk_t > 0.0 and atk_dir == "down" and not slammed and fall_v > Tune.f("slam_min_fall"):
				_slam()
	was_on_floor = on_floor
	run_ph += dt * (absf(velocity.x) / 26.0 if on_floor else 0.0)
	land = maxf(0.0, land - dt * 5.0)
	for gh: Dictionary in ghosts:
		gh.t -= dt
	ghosts.assign(ghosts.filter(func(gh: Dictionary) -> bool: return gh.t > 0.0))
	queue_redraw()

func _on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is CollisionObject2D and (col as CollisionObject2D).get_collision_layer_value(PLATFORM_LAYER):
			return true
	return position.y < Tune.f("ground_y") - 1.0

func _blade() -> Dictionary:
	return Tune.get_value("blade") as Dictionary

func _update_attack(dt: float, on_floor: bool) -> void:
	var b := _blade()
	var times: Array = b.times
	if atk_buf > 0.0 and dash_t <= 0.0 and atk_t <= 0.0:
		atk_dir = "up" if _held(&"move_up") else ("down" if _held(&"move_down") and not on_floor else "side")
		combo = (combo % times.size()) + 1 if atk_dir == "side" and combo_t > 0.0 else 1
		atk_t = float(times[combo - 1]) * (1.0 if atk_dir == "side" else Tune.f("vertical_strike_time_mult"))
		atk_dur = atk_t
		combo_t = atk_t + Tune.f("combo_window")
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
	var fin := DamageRules.is_finisher(combo, mult.size())
	for e: Enemy in _enemies():
		if e in hit_set or e.dead:
			continue
		if not r.intersects(e.hurt_rect()):
			continue
		hit_set.append(e)
		var hit := Hit.make(Hit.Kind.STRIKE,
			DamageRules.strike_damage(Tune.f("strike_dmg"), mult, combo),
			position.x if atk_dir == "side" else e.position.x - face,
			DamageRules.strike_knockback(Tune.f("knockback"), fin, Tune.f("finisher_knockback_mult")))
		hit.finisher = fin
		hit.source = self
		var blocked := DamageRules.shield_blocks(hit, e.hit_view())
		var dealt := e.hurt(hit)
		_gain_hit(Tune.f("charge_f_shield") if blocked else 1.0)
		if atk_dir == "up":
			e.launch(Tune.f("launch_speed"))
		if atk_dir == "down":
			velocity.y = -Tune.f("pogo_speed")
			atk_t = 0.0
		if world:
			world.request_hitstop(Tune.f("hitstop"))
			world.add_shake(Tune.f("shake_finisher") if fin else Tune.f("shake_hit"))
		hit_landed.emit(e, dealt)

func _slam() -> void:
	slammed = true
	if world:
		world.add_shake(Tune.f("shake_slam"))
		world.add_ring(position, Tune.f("slam_r"))
	for e: Enemy in _enemies():
		if e.dead:
			continue
		if absf(e.position.x - position.x) < Tune.f("slam_r") and absf(e.position.y - position.y) < Tune.f("slam_reach_y"):
			var hit := Hit.make(Hit.Kind.SLAM, Tune.f("slam_dmg"), position.x, Tune.f("slam_knockback"))
			hit.source = self
			e.hurt(hit)
			_gain_hit(amulet.slam_f())

# ---------------- amulet and Flare (GDD amulet-and-flare §3.1-3.3) ----------------

## F1 for one landed hit of source factor `f` with the blade's charge multiplier.
## No charge during the breath.
func _gain_hit(f: float) -> void:
	if flare_t > 0.0 or amulet == null:
		return
	amulet.add_hit(f, float(_blade().get("charge", 1.0)))

func _on_enemy_killed(_enemy: Node2D, _hit: RefCounted) -> void:
	if amulet and amulet.kill_charge() > 0.0 and flare_t <= 0.0:
		amulet.add_flat(amulet.kill_charge())

## The Flare key: below 100 a fizzle; at 100+ starts the breath. True if started.
func _press_flare() -> bool:
	var p := amulet.try_fire()
	if p <= 0.0:
		return false
	flare_p = p
	flare_t = Tune.f("flare_windup")
	atk_t = 0.0
	atk_buf = 0.0
	if world:
		world.request_slow(Tune.f("flare_slow"), flare_t)
	return true

## One tick of the breath: frozen in place (real time, not the slowed world's).
func _breath(dt: float) -> void:
	velocity = Vector2.ZERO
	flare_t -= dt
	if flare_t <= 0.0:
		flare_t = 0.0
		_release_flare()
	queue_redraw()

func _release_flare() -> void:
	inv = maxf(inv, Tune.f("flare_iframes"))
	if amulet.shape() == "knot":
		Flare.detonate_knots(get_tree())
	var f := Flare.new()
	f.setup(self, amulet.row, amulet.shape(), flare_p, flare_element)
	flare_released.emit(f)
	if world:
		world.add_child(f)
	elif get_parent():
		get_parent().add_child(f)
	FlareElement.apply_to_hero(flare_element, self, f.touched(), Tune.data)
	Events.flare_fired.emit(amulet.shape(), flare_p)

func _enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy:
			out.append(n)
	return out

## The ONLY way to damage the hero (GDD movement-and-combat §3.11, ADR-0002).
## Ignored while dead, invulnerable or dashing. The shield absorbs first; a fully
## absorbed hit gives half the i-frames and nothing else. Returns the hp lost.
## Not yet applied (no source systems): F12 multipliers (ash, tier, armour,
## Iron Will), hub immunity and the "Last Ember" revive.
func hurt(hit: Hit) -> float:
	if dead or inv > 0.0 or dash_t > 0.0 or flare_t > 0.0:
		return 0.0
	var split := DamageRules.split_shield(hit.dmg, shield)
	shield -= split.x
	if split.y <= 0.0:
		inv = Tune.f("hurt_iframes") * Tune.f("shield_iframes_mult")
		return 0.0
	hp -= split.y
	if amulet:
		amulet.on_health_damage()
	inv = Tune.f("hurt_iframes")
	velocity.x = (signf(position.x - hit.from_x) if position.x != hit.from_x else 1.0) * Tune.f("hurt_knock_x")
	velocity.y = -Tune.f("hurt_knock_y")
	if world:
		world.add_shake(Tune.f("shake_hurt"))
		world.request_hitstop(Tune.f("hitstop_hurt"))
	hurt_taken.emit(split.y, hit)
	Events.player_hurt.emit(split.y, hit)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		if world:
			world.request_hitstop(Tune.f("hitstop_player_death"))
		died.emit(hit)
	return split.y

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
	var fill := clampf(amulet.charge / amulet.ready_at(), 0.0, 1.5) if amulet else 0.0
	draw_circle(Vector2(-11, 13), 9.0 + 6.0 * fill, Color(GLOW, 0.18 + 0.2 * fill))
	if flare_t > 0.0:
		var k := flare_t / maxf(Tune.f("flare_windup"), 0.01)
		draw_arc(Vector2(-11, 13), 12.0 + 80.0 * k, 0.0, TAU, 32, Color(GLOW, 0.9), 3.0)
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
