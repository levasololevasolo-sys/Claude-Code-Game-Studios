## The hero: run, variable jump, coyote time, jump buffer, ground roll / air dash,
## a three-swing blade combo, an up strike, and a down strike that pogos off foes
## and slams the ground. The origin sits at the feet. Ported from updatePlayer().
## Weapons (GDD weapons-and-loot §3.2-3.6): the combo, hit window, reach, lunge
## and charge come from the main Weapon's strike body (weapon_bodies.json) and
## row (weapons.json); its `mech` adds one mechanic (_mech_mult, _mech_on_hit,
## kill / hurt hooks). The secondary weapon fires on the `sub` action with its
## own cooldown (SubWeapons); its hits carry the Strike-slot god's status at
## sub_god_k (sub_hit). Without an injected weapon the hero holds Меч-кладенец ★
## (legacy checks keep the blade numbers of the port).
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
## Emitted when a Нить Мокоши token kept the hero up (GDD difficulty §3.5).
signal revived
## Emitted when the breath ends, just before the new Flare enters the world (an
## instant shape strikes in its _ready, so listeners connect to `struck` here).
signal flare_released(flare: Flare)
## Emitted when a weapon slot changes ("arm" or "sub").
signal weapon_changed(slot: String)
## Emitted when a secondary-weapon hit lands; dmg is what the enemy took.
signal sub_landed(enemy: Enemy, dmg: float)
## Emitted at the end of every physics tick, hitstop ticks included. Test drivers
## await it so the input they set is guaranteed to have been read.
signal stepped
## Parry (GDD parry): the window opened / a melee blow was caught (`result` of
## Enemy.parried: "arm", "nick", "stun") / the window ran out empty. The hero
## visual hooks its parry pose here (or uses parrying() / parry_pose()).
signal parry_started
signal parry_succeeded(enemy: Enemy, result: String)
signal parry_whiffed

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
## Нить Мокоши tokens left (GDD difficulty F5); set by RunDirector, 0 in checks.
var revives: int = 0
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
## Шишиги hanging on the hero now (bestiary §3.2, B7); each slows the run.
var cling_n: int = 0
var inv: float = 0.0
var atk_t: float = 0.0
var atk_dur: float = 0.0
var atk_dir: String = "side"
var combo: int = 0
var combo_t: float = 0.0
var slammed: bool = false
var hit_set: Array[Enemy] = []
## Parry (GDD parry): window left, cooldown, whiff lock, spark time, catches so far.
var parry_t: float = 0.0
var parry_cd: float = 0.0
var parry_lock: float = 0.0
var parry_fx: float = 0.0
var parry_count: int = 0
var _tap_parry: bool = false
var run_ph: float = 0.0
var land: float = 0.0
var ghosts: Array[Dictionary] = []
var was_on_floor: bool = false
var fall_v: float = 0.0
## The worn amulet (injected by World; a ring amulet is made if left null).
var amulet: Amulet
## The hero's runes (gods-and-runes). Injected by World; empty if left null.
var build: RunBuild
## Enemies the current dash already passed through (each once per dash).
var dash_set: Array[Enemy] = []
## Element of the Flare, set from build.flare_element() at each press. HOOK: set from the god of the Flare-slot rune when
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
var _tap_sub: bool = false
## Main weapon (weapons-and-loot §3.3). Injected by World; Меч-кладенец ★ if null.
var weapon: Weapon
## Secondary weapon (§3.4); null = empty slot (a new save has none).
var sub: Weapon
## Seconds until the secondary weapon can fire again; buffered press.
var sub_cd: float = 0.0
var sub_buf: float = 0.0
## «Двойное»: seconds until the second fire (< 0 = none pending).
var sub_twice_t: float = -1.0
## Ярый меч: current damage bonus (0 .. cap).
var rage: float = 0.0
## Seconds since the last dash ended (Сулица-стрела); 0 while dashing.
var since_dash: float = 99.0
## Rolls of affix chances (seeded by World).
var roll_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Chain lightning lines to draw: {a: Vector2, b: Vector2, t: float} (world).
var bolts: Array[Dictionary] = []
var _quaked: bool = false
var _blasts: int = 0
## The cutout rig (ADR-0005, HeroVisual); null if the scene is missing. Reads
## this node's state only; when present, _draw() keeps just the shield ring.
var visual: Node2D
const VISUAL_SCENE: String = "res://scenes/hero/hero_visual.tscn"
## Pre-rendered 3D-to-2D hero (art slice); chosen by visual_scene_path().
const SPRITE_SCENE: String = "res://scenes/hero/hero_sprite.tscn"
## Hand-drawn hero «Медвежья шкура» (tools/asset-pipeline/hero2d); the default.
const DRAWN_SCENE: String = "res://scenes/hero/hero_drawn.tscn"

## Check modes that inspect the cutout rig itself (HeroVisual tiers, rig poses):
## they get the rig unless `--hero-art=` is given explicitly.
const RIG_MODES: Array[String] = ["--hero-shots=", "--base-check="]

## The hero visual scene: the project setting navi/art/hero_art ("drawn" =
## hand-drawn hero sheets, the default; "sprite" = pre-rendered 3D hero; "rig" =
## cutout rig), forced to the rig in RIG_MODES; `-- --hero-art=drawn|sprite|rig`
## overrides both.
static func visual_scene_path(args: PackedStringArray) -> String:
	var art := String(ProjectSettings.get_setting("navi/art/hero_art", "rig"))
	for a in args:
		for m in RIG_MODES:
			if a.begins_with(m):
				art = "rig"
	for a in args:
		if a.begins_with("--hero-art="):
			art = a.trim_prefix("--hero-art=")
	if art == "drawn" and ResourceLoader.exists(DRAWN_SCENE):
		return DRAWN_SCENE
	return SPRITE_SCENE if art == "sprite" and ResourceLoader.exists(SPRITE_SCENE) else VISUAL_SCENE

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
	if build == null:
		build = RunBuild.make()
	if weapon == null:
		weapon = Weapon.make("blade")
	Events.enemy_killed.connect(_on_enemy_killed)
	# Input before damage in one tick (amulet-and-flare §5): the hero's tick runs
	# before the enemies', the World's (hitstop/slow clocks) before the hero's.
	process_physics_priority = -1
	var vis_path := visual_scene_path(OS.get_cmdline_user_args())
	if ResourceLoader.exists(vis_path):
		visual = (load(vis_path) as PackedScene).instantiate() as Node2D
		visual.set("player", self)
		add_child(visual)
		if visual.has_method("set_weapon_sprite"):
			visual.call("set_weapon_sprite", null)

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
	if _tapped(&"sub"):
		_tap_sub = true
	if _tapped(&"parry"):
		_tap_parry = true
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
	if _tap_sub:
		sub_buf = Tune.f("sub_buffer")
	_tap_sub = false
	_update_parry(dt)
	if parry_lock > 0.0:
		# A whiffed parry leaves the hero open: no strike, dash or parry (GDD parry §3.2).
		atk_buf = 0.0
		want_dash = false
	_blasts = 0
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
		dash_cd = build.dash_cd(Tune.data, dash_dur)
		dash_set.clear()
		dash_dir = mx if mx != 0 else face
		face = dash_dir
		inv = maxf(inv, dash_dur + 0.05 + build.value(build.slots.dash, "inv_bonus", 0.0))
		Events.hero_acted.emit(&"roll" if rolling else &"dash", 1.0)
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
		_dash_hits()
		since_dash = 0.0
		if dash_t <= 0.0:
			velocity.x = dash_dir * Tune.f("run_speed")
			_dash_end()
	else:
		var slow := Tune.f("attack_move_slow") if atk_t > 0.0 else 1.0
		slow *= SwampRules.cling_slow_mult(cling_n, Tune.f("cling_slow"), int(Tune.f("cling_max")))
		var target := mx * Tune.f("run_speed") * slow * build.value("stribog_p", "run", 1.0)
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
				Events.hero_acted.emit(&"jump", 1.0)
	_update_attack(dt, on_floor)
	_update_sub(dt)
	since_dash += dt
	combo_t -= dt; dash_cd -= dt; jump_buf -= dt; coyote_t -= dt; inv -= dt; atk_buf -= dt; drop_t -= dt
	set_collision_mask_value(PLATFORM_LAYER, drop_t <= 0.0)
	fall_v = velocity.y
	move_and_slide()
	on_floor = is_on_floor()
	if on_floor:
		coyote_t = Tune.f("coyote")
		if not was_on_floor:
			land = clampf(fall_v / Tune.f("land_ref_speed"), 0.2, 1.0)
			Events.hero_acted.emit(&"land", land)
			if atk_t > 0.0 and atk_dir == "down" and not slammed and fall_v > Tune.f("slam_min_fall"):
				_slam()
	was_on_floor = on_floor
	run_ph += dt * (absf(velocity.x) / 26.0 if on_floor else 0.0)
	land = maxf(0.0, land - dt * 5.0)
	for gh: Dictionary in ghosts:
		gh.t -= dt
	ghosts.assign(ghosts.filter(func(gh: Dictionary) -> bool: return gh.t > 0.0))
	for bl: Dictionary in bolts:
		bl.t -= dt
	bolts.assign(bolts.filter(func(bl: Dictionary) -> bool: return bl.t > 0.0))
	queue_redraw()

func _on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is CollisionObject2D and (col as CollisionObject2D).get_collision_layer_value(PLATFORM_LAYER):
			return true
	return position.y < Tune.f("ground_y") - 1.0

## The strike body row of the main weapon (weapon_bodies.json).
func _body() -> Dictionary:
	return weapon.body()

func _update_attack(dt: float, on_floor: bool) -> void:
	var b := _body()
	var times: Array = weapon.times()
	if atk_buf > 0.0 and dash_t <= 0.0 and atk_t <= 0.0:
		atk_dir = "up" if _held(&"move_up") else ("down" if _held(&"move_down") and not on_floor else "side")
		combo = (combo % times.size()) + 1 if atk_dir == "side" and combo_t > 0.0 else 1
		atk_t = float(times[combo - 1]) * (1.0 if atk_dir == "side" else Tune.f("vertical_strike_time_mult")) \
			/ build.value("stribog_p", "swing", 1.0)
		atk_dur = atk_t
		combo_t = atk_t + Tune.f("combo_window")
		hit_set.clear()
		slammed = false
		_quaked = false
		atk_buf = 0.0
		Events.hero_acted.emit(&"swing", float(combo))
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

## Reach of the main weapon in px with the «Широкий взмах» rune.
func strike_reach() -> float:
	return weapon.reach() * (build.value("arc", "reach", 1.0) if build else 1.0)

## Every hit rectangle of the current swing: the front one (strike_rect) and,
## for a both-sides swing (Коромысло, the sickles' whirl finisher), its mirror.
func strike_rects() -> Array[Rect2]:
	var r := strike_rect()
	var out: Array[Rect2] = [r]
	if atk_dir == "side" and (weapon.mech() == "both_sides" or (bool(_body().get("fin_both", false)) \
			and DamageRules.is_finisher(combo, (_body().get("mult", [1]) as Array).size()))):
		out.append(Rect2(2.0 * position.x - r.end.x, r.position.y, r.size.x, r.size.y))
	return out

## The strike's hit rectangle in world space, for the current direction and the
## body's box (side, spear line, hammer high, staff 200° arc).
func strike_rect() -> Rect2:
	var reach := strike_reach()
	var vr := reach * 0.9 + 20.0
	match atk_dir:
		"up":
			return Rect2(position.x - 40.0 + face * 26.0, position.y - H - vr, 80.0, H + vr + 4.0)
		"down":
			return Rect2(position.x - 40.0, position.y - 20.0, 80.0, vr + 20.0)
	var x0 := position.x if face > 0 else position.x - reach - 12.0
	match String(_body().get("box", "side")):
		"line":
			return Rect2(x0, position.y - 56.0, reach + 12.0, 46.0)
		"high":
			return Rect2(x0, position.y - H - 54.0, reach + 12.0, H + 60.0)
		"arc":
			# 200° arc: the front half plus 10° past the vertical behind the hero.
			var back := reach * sin(deg_to_rad((float(_body().get("arc_deg", 200)) - 180.0) / 2.0))
			var left := position.x - back if face > 0 else position.x - reach - 12.0
			return Rect2(left, position.y - H - reach * 0.6, reach + 12.0 + back, H + reach * 0.6 + 6.0)
	return Rect2(x0, position.y - H - 14.0, reach + 12.0, H + 20.0)

func _strike_hits() -> void:
	var b := _body()
	var rects := strike_rects()
	var mult: Array = b.mult
	combo = clampi(combo, 1, mult.size())
	var fin := DamageRules.is_finisher(combo, mult.size())
	var fin_kb := float(b.fin_kb) if b.has("fin_kb") else Tune.f("finisher_knockback_mult")
	if fin and atk_dir == "side" and not _quaked:
		_quaked = true
		_finisher_extras()
	for e: Enemy in _enemies():
		if e in hit_set or e.dead:
			continue
		if not rects.any(func(r: Rect2) -> bool: return r.intersects(e.hurt_rect())):
			continue
		hit_set.append(e)
		var hit := Hit.make(Hit.Kind.STRIKE,
			DamageRules.strike_damage(Tune.f("strike_dmg"), mult, combo) * weapon.dmg_mult() * _mech_mult(e),
			position.x if atk_dir == "side" else e.position.x - face,
			DamageRules.strike_knockback(Tune.f("knockback"), fin, fin_kb) * float(b.get("kb_mult", 1.0)))
		hit.finisher = fin
		hit.source = self
		hit.pierce = bool(b.get("pierce", false))
		hit.stun = float(b.get("stun", 0.0))
		# Limb zones (limb-zones F1): which part the blade meets on this enemy.
		for r in rects:
			if r.intersects(e.hurt_rect()):
				hit.limb = e.limb_at(r, atk_dir, position.x, not is_on_floor())
				hit.zone = e.limb_zone_at(r, atk_dir, position.x)
				break
		var blocked := DamageRules.shield_blocks(hit, e.hit_view())
		_rune_strike(hit, fin)
		_mech_on_hit(e, hit, fin)
		var was_rooted := e.status.rooted()
		var dealt := e.hurt(hit)
		_rune_after_strike(blocked, was_rooted)
		_gain_hit(Tune.f("charge_f_shield") if blocked else 1.0)
		if weapon.mech() == "rage":
			rage = minf(float(weapon.row().get("cap", 0.6)), rage + float(weapon.row().get("per_hit", 0.04)))
		if atk_dir == "up":
			var lm := float(weapon.row().get("launch", 1.0)) if weapon.mech() == "juggle" else 1.0
			e.launch(Tune.f("launch_speed") * lm)
			if weapon.mech() == "juggle":
				e.set_meta(&"juggled", true)
		if atk_dir == "down":
			velocity.y = -Tune.f("pogo_speed") * (float(weapon.row().get("pogo", 1.0)) if weapon.mech() == "down_boost" else 1.0)
			atk_t = 0.0
			Events.hero_acted.emit(&"pogo", 1.0)
		if world:
			world.request_hitstop(Tune.f("hitstop"))
			world.add_shake(Tune.f("shake_finisher") if fin else Tune.f("shake_hit"))
		hit_landed.emit(e, dealt)

# ---------------- weapon mechanics (weapons-and-loot §3.3, §3.6) ----------------

## Damage multiplier of the weapon's mechanic and the «Богатырское» affix on `e`.
func _mech_mult(e: Enemy) -> float:
	var r := weapon.row()
	var m := 1.0
	match weapon.mech():
		"rage":
			m *= 1.0 + rage
		"execute":
			if e.hp < float(r.get("below", 0.25)) * e.max_hp:
				m *= float(r.get("mult", 2.5))
		"after_dash":
			if since_dash <= float(r.get("window", 0.4)):
				m *= float(r.get("mult", 1.8))
		"vs_held":
			if e.stun > 0.0 or e.status.rooted():
				m *= float(r.get("mult", 1.6))
		"down_boost":
			if atk_dir == "down":
				m *= float(r.get("mult", 2.0))
		"juggle":
			if e.has_meta(&"juggled") and DamageRules.is_airborne(e.position.y, Tune.f("ground_y"), Tune.f("air_target_margin")):
				e.remove_meta(&"juggled")
				m *= float(r.get("mult", 1.5))
	if e.boss:
		m *= float(weapon.affix_row().get("boss", 1.0))
	return m

## Statuses and marks the weapon adds to a strike `hit` on `e` before it lands.
func _mech_on_hit(e: Enemy, hit: Hit, fin: bool) -> void:
	var r := weapon.row()
	match weapon.mech():
		"perun_fin":
			if fin and e.status.shock >= 1:
				hit.discharge = true
		"all_gods":
			for g: String in build.gods_taken():
				hit.add_payload(RunBuild.status_payload(_god_status(g), float(r.get("power", 0.4)), Tune.data))
		"stun_cd":
			var now := float(e.anim)
			if now >= float(e.get_meta(&"flail_next", -1.0)):
				e.set_meta(&"flail_next", now + float(r.get("cd", 1.5)))
				hit.stun = maxf(hit.stun, float(r.get("stun", 0.25)))
		"wall_boost":
			e.slam_boost = { "mult": float(r.get("mult", 2.0)), "r": float(r.get("wave_r", 140)) }
	var a := weapon.affix_row()
	if a.has("god") and roll_rng.randf() < float(a.get("chance", 0.0)):
		hit.add_payload(RunBuild.status_payload(String(a.get("status", "")), float(a.get("amount", 1.0)), Tune.data))

## Once per finisher swing: hammer quake / Чекан wave (on the ground), Вихрь-серпы pull.
func _finisher_extras() -> void:
	var r := weapon.row()
	if weapon.mech() == "pull":
		var pr := float(r.get("pull_r", 220))
		var stop := float(r.get("pull_stop", 40))
		for e: Enemy in living_enemies():
			var dx := position.x - e.position.x
			if absf(dx) <= pr and not e.boss and absf(dx) > stop:
				e.kb = signf(dx) * (absf(dx) - stop) * float(r.get("pull_k", 6.2))
	var q: Dictionary = _body().get("quake", {})
	if q.is_empty() or not is_on_floor():
		return
	var wave := weapon.mech() == "wave"
	var qr := float(r.get("wave_r", 260)) if wave else float(q.get("r", 200))
	if world:
		world.add_ring(position, qr)
		world.add_shake(Tune.f("shake_slam"))
	var base := DamageRules.strike_damage(Tune.f("strike_dmg"), _body().mult, combo) * weapon.dmg_mult()
	for e: Enemy in living_enemies():
		if e.flies or absf(e.position.x - position.x) > qr or not e.on_ground():
			continue
		var hit := Hit.make(Hit.Kind.SLAM, base * float(q.get("k", 0.6)), position.x, Tune.f("knockback") * 0.5)
		hit.source = self
		hit.stun = float(q.get("stun", 0.7))
		if wave:
			# «и удар о землю» (gods-and-runes §3.5): the Strike rune rides the wave.
			_rune_strike(hit, false)
		e.hurt(hit)

## The status id a god puts (gods.json wrath_status), "" for Rod / none.
static func _god_status(god: String) -> String:
	if god == "" or god == "rod":
		return ""
	return String((Tune.table("gods").get(god, {}) as Dictionary).get("wrath_status", ""))

## Thorns of Шипастая булава (when hurt, shield included).
func _thorns() -> void:
	var r := weapon.row()
	for e: Enemy in living_enemies():
		if e.center().distance_to(position - Vector2(0, H / 2.0)) > float(r.get("r", 120)):
			continue
		var hit := Hit.make(Hit.Kind.STRIKE, Tune.f("strike_dmg") * float(r.get("k", 1.2)), position.x, Tune.f("knockback"))
		hit.source = self
		hit.add_payload(build.payload("strike", 1.0, Tune.data))
		e.hurt(hit)
	if world:
		world.add_ring(position, float(r.get("r", 120)))

## Копьё Велеса: a cursed enemy that dies blows up once (edge case 13, depth cap).
func _curse_blast(e: Enemy) -> void:
	var r := weapon.row()
	if e.has_meta(&"blasted") or _blasts >= int(r.get("depth", 4)):
		return
	e.set_meta(&"blasted", true)
	_blasts += 1
	var br := float(r.get("blast_r", 140))
	if world:
		world.add_ring(e.position, br)
	for o: Enemy in living_enemies():
		if o == e or o.center().distance_to(e.center()) > br:
			continue
		var hit := Hit.make(Hit.Kind.STATUS, Tune.f("strike_dmg") * float(r.get("blast_k", 1.5)), e.position.x, 0.0)
		hit.source = self
		hit.nested = true
		hit.curse = Tune.f("curse_time") * float(r.get("curse_k", 0.5))
		o.hurt(hit)

# ---------------- weapon slots (weapons-and-loot §3.9) ----------------

## Puts `w` into its slot and returns what was there (null if empty). Main:
## the combo resets; sub: the cooldown is cleared.
func equip(w: Weapon) -> Weapon:
	var old: Weapon
	if w.kind == Weapon.SUB:
		old = sub
		sub = w
		sub_cd = 0.0
		sub_twice_t = -1.0
	else:
		old = weapon
		weapon = w
		combo = 0
		combo_t = 0.0
		atk_t = 0.0
		rage = 0.0
	weapon_changed.emit(w.kind)
	queue_redraw()
	return old

func _update_sub(dt: float) -> void:
	sub_cd -= dt
	sub_buf -= dt
	if sub == null:
		return
	if sub_twice_t >= 0.0:
		sub_twice_t -= dt
		if sub_twice_t < 0.0:
			SubWeapons.fire(self, sub)
	if sub_buf > 0.0 and sub_cd <= 0.0 and dash_t <= 0.0:
		sub_buf = 0.0
		fire_sub()

## Fires the secondary weapon now (cooldown and «Двойное» included). False if
## the slot is empty or cooling down.
func fire_sub() -> bool:
	if sub == null or sub_cd > 0.0:
		return false
	SubWeapons.fire(self, sub)
	sub_cd = sub.cooldown()
	var twice := float(sub.affix_row().get("twice", 0.0))
	if twice > 0.0:
		sub_twice_t = twice
	return true

## Status payload of a secondary-weapon hit: the Strike-slot god at sub_god_k
## (§3.4); {} when the slot is empty or Rod (edge case 8).
func sub_payload() -> Dictionary:
	var st := _god_status(build.slot_god("strike"))
	if st == "":
		return {}
	return RunBuild.status_payload(st, Tune.f("sub_god_k"), Tune.data)

## One secondary-weapon hit on `e`. `with_status` = put the Strike god status
## (spikes: once per placement). Its knockback counts as the hero's (Ослоп).
func sub_hit(e: Enemy, dmg: float, from_x: float, kb: float, stun: float, with_status: bool = true) -> float:
	if e == null or e.dead:
		return 0.0
	var hit := Hit.make(Hit.Kind.PROJECTILE, dmg, from_x, kb)
	hit.stun = stun
	hit.source = self
	hit.mods = build.damage_mods(false)
	if with_status:
		hit.add_payload(sub_payload())
	if kb > 0.0 and weapon.mech() == "wall_boost":
		e.slam_boost = { "mult": float(weapon.row().get("mult", 2.0)), "r": float(weapon.row().get("wave_r", 140)) }
	var d := e.hurt(hit)
	sub_landed.emit(e, d)
	return d

## Living enemies of the room.
func living_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if not is_inside_tree():
		return out
	for e in _enemies():
		if not e.dead:
			out.append(e)
	return out

## A chain-lightning line from `a` to `b` (world), drawn for a moment.
func add_bolt(a: Vector2, b: Vector2) -> void:
	bolts.append({ "a": a, "b": b, "t": Tune.f("status_fx_time") })

func _slam() -> void:
	slammed = true
	Events.hero_acted.emit(&"ground_slam", 1.0)
	if world:
		world.add_shake(Tune.f("shake_slam"))
		world.add_ring(position, Tune.f("slam_r"))
	for e: Enemy in _enemies():
		if e.dead:
			continue
		if absf(e.position.x - position.x) < Tune.f("slam_r") and absf(e.position.y - position.y) < Tune.f("slam_reach_y"):
			var hit := Hit.make(Hit.Kind.SLAM, Tune.f("slam_dmg"), position.x, Tune.f("slam_knockback"))
			hit.source = self
			# The ground slam counts as a strike for the Удар slot (gods-and-runes §3.5).
			_rune_strike(hit, false)
			var was_rooted := e.status.rooted()
			e.hurt(hit)
			_rune_after_strike(false, was_rooted)
			_gain_hit(amulet.slam_f())

# ---------------- runes (gods-and-runes §3.5, §3.6) ----------------

## Puts the Удар-slot rune on a strike/slam hit: statuses, Stribog knockback,
## build damage mods (edge, reaper, heat).
func _rune_strike(hit: Hit, fin: bool) -> void:
	hit.mods.merge(build.damage_mods(true), true)
	hit.add_payload(build.payload("strike", 1.0, Tune.data, fin))
	hit.kb *= build.kb_mult("strike")

## After a strike landed: Zhiva shield, «Глубокие корни», «Жаждущий клинок».
func _rune_after_strike(blocked: bool, was_rooted: bool) -> void:
	if build.slot_god("strike") == "zhiva":
		add_shield(build.value(build.slots.strike, "shield", 0.0))
	if was_rooted:
		add_shield(build.value("zhiva_p", "shield_on_rooted", 0.0))
	if not blocked and build.has("thirst"):
		hp = minf(Tune.f("player_hp"), hp + Difficulty.heal(build.value("thirst", "heal", 0.0)))

## Shield (F5): sums up to shield_max, the rest is lost.
func add_shield(v: float) -> void:
	if v > 0.0:
		shield = minf(Tune.f("shield_max"), shield + v)

## Rune dash (§3.5 "Общее для слота Рывок"): each enemy passed through once
## takes rune_dash_dmg, the god's status and gives 1 amulet charge.
func _dash_hits() -> void:
	var id: String = build.slots.dash
	if id == "" or not is_inside_tree():
		return
	var me := Rect2(position.x - W / 2.0, position.y - H, W, H)
	for e: Enemy in _enemies():
		if e.dead or e in dash_set or not me.intersects(e.hurt_rect()):
			continue
		dash_set.append(e)
		var hit := Hit.make(Hit.Kind.DASH, Tune.f("rune_dash_dmg"), position.x - dash_dir, float(build.row(id).get("dash_kb", 0.0)))
		hit.source = self
		hit.mods = build.damage_mods(false)
		hit.add_payload(build.payload("dash", 1.0, Tune.data))
		e.hurt(hit)
		_gain_hit(1.0)

## «Живая отдача» (F8): at the end of a dash, a shield of zhiva_wave_min+ is
## spent in a wave: shield × k_wave damage and roots within zhiva_wave_r.
func _dash_end() -> void:
	if build.slots.dash != "zhiva_d" or shield < Tune.f("zhiva_wave_min"):
		return
	var dmg := shield * build.value("zhiva_d", "wave", 0.0)
	shield = 0.0
	if world:
		world.add_ring(position, Tune.f("zhiva_wave_r"))
	for e: Enemy in _enemies():
		if e.dead or e.center().distance_to(position - Vector2(0, H / 2.0)) > Tune.f("zhiva_wave_r"):
			continue
		var hit := Hit.make(Hit.Kind.DASH, dmg, position.x, 0.0)
		hit.source = self
		hit.root = Tune.f("root_time")
		e.hurt(hit)

# ---------------- amulet and Flare (GDD amulet-and-flare §3.1-3.3) ----------------

## F1 for one landed hit of source factor `f` with the blade's charge multiplier.
## No charge during the breath.
func _gain_hit(f: float) -> void:
	if flare_t > 0.0 or amulet == null:
		return
	amulet.add_hit(f * (build.value("kindling", "charge", 1.0) if build else 1.0), weapon.charge())

func _on_enemy_killed(enemy: Node2D, hit: RefCounted) -> void:
	if amulet and amulet.kill_charge() > 0.0 and flare_t <= 0.0:
		amulet.add_flat(amulet.kill_charge())
	if not is_inside_tree() or not enemy is Enemy:
		return
	var e := enemy as Enemy
	match weapon.mech():
		"mara":
			if hit is Hit and (hit as Hit).source == self:
				if dash_t > 0.0:
					hp = minf(Tune.f("player_hp"), hp + Difficulty.heal(float(weapon.row().get("heal", 3))))
				dash_cd = 0.0
		"curse_blast":
			if e.status.cursed():
				_curse_blast(e)

## The Flare key: below 100 a fizzle; at 100+ starts the breath. True if started.
func _press_flare() -> bool:
	var p := amulet.try_fire()
	if p <= 0.0:
		return false
	flare_p = p
	flare_element = build.flare_element()
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
	FlareElement.apply_to_hero(flare_element, self, f.touched(), Tune.data, build)
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
	if ParryRules.catches(parry_t, hit.kind, hit.source is Enemy):
		_parry_success(hit.source as Enemy)
		return 0.0
	var split := DamageRules.split_shield(hit.dmg, shield)
	shield -= split.x
	if weapon and weapon.mech() == "thorns":
		_thorns()
	if split.y <= 0.0:
		inv = Tune.f("hurt_iframes") * Tune.f("shield_iframes_mult")
		return 0.0
	hp -= split.y
	rage = 0.0
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
	if hp <= 0.0 and revives > 0:
		# GDD difficulty §3.5: a Нить Мокоши token keeps the hero up instead of dying.
		var dt := Difficulty.table()
		revives -= 1
		hp = Tune.f("player_hp") * float(dt.get("revive_hp_frac", 0.5))
		inv = float(dt.get("revive_iframes", 2.0))
		revived.emit()
		return split.y
	if hp <= 0.0:
		hp = 0.0
		dead = true
		if world:
			world.request_hitstop(Tune.f("hitstop_player_death"))
		died.emit(hit)
	return split.y

# ---------------- parry (GDD parry) ----------------

## True while the parry window is open.
func parrying() -> bool:
	return parry_t > 0.0

## Pose hint for the hero visual: "parry" (window open), "parry_hit" (just
## caught a blow), "parry_open" (whiff lock) or "" (none).
func parry_pose() -> String:
	if parry_fx > 0.0:
		return "parry_hit"
	if parry_t > 0.0:
		return "parry"
	if parry_lock > 0.0:
		return "parry_open"
	return ""

## Opens the parry window now if allowed (also called by scripted checks).
func start_parry() -> bool:
	if dead or not ParryRules.can_start(parry_cd, parry_lock, dash_t > 0.0, atk_t > 0.0):
		return false
	parry_t = Tune.f("parry_window")
	parry_cd = Tune.f("parry_cooldown")
	parry_started.emit()
	return true

func _update_parry(dt: float) -> void:
	parry_cd = maxf(0.0, parry_cd - dt)
	parry_lock = maxf(0.0, parry_lock - dt)
	parry_fx = maxf(0.0, parry_fx - dt)
	if _tap_parry:
		start_parry()
	_tap_parry = false
	var r := ParryRules.tick_window(parry_t, dt)
	parry_t = float(r.left)
	if bool(r.whiff):
		parry_lock = Tune.f("parry_whiff_lock")
		Audio.play_at(&"parry_whiff", position)
		parry_whiffed.emit()

## An enemy shot reached the hero (GDD parry §3.5, P5-P7): inside the window it
## is reflected back at its shooter (or straight back) and counts as a parry
## with result "reflect". Returns true when reflected (the shot does not hit).
func reflect_shot(s: EnemyShot) -> bool:
	if dead or not ParryRules.reflects(parry_t, s.reflected):
		return false
	var shooter := s.source as Enemy
	var alive := shooter != null and is_instance_valid(shooter) and not shooter.dead
	var v := ParryRules.reflect_velocity(s.position, s.vel, alive, shooter.center() if alive else Vector2.ZERO, Tune.data)
	s.reflect(v, ParryRules.reflect_damage(s.dmg, Tune.data), self)
	_parry_fx_common()
	parry_succeeded.emit(shooter if alive else null, "reflect")
	queue_redraw()
	return true

func _parry_success(e: Enemy) -> void:
	var res := e.parried(position.x)
	_parry_fx_common()
	parry_succeeded.emit(e, res)
	queue_redraw()

## The shared part of a caught blow and a reflected shot (parry §3.3 item 3).
func _parry_fx_common() -> void:
	parry_t = 0.0
	parry_cd = 0.0
	parry_fx = Tune.f("parry_fx_time")
	parry_count += 1
	inv = maxf(inv, Tune.f("parry_window"))
	if world:
		world.request_hitstop(Tune.f("parry_hitstop"))
		world.add_shake(Tune.f("parry_shake"))
	Audio.play_at(&"parry_clang", position)

## Parry placeholder: a bright arc in front while the window is open, sparks on a catch.
func _draw_parry() -> void:
	if parry_t <= 0.0 and parry_fx <= 0.0:
		return
	var at := Vector2(face * 22.0, -H * 0.55)
	if parry_t > 0.0:
		var k := parry_t / maxf(Tune.f("parry_window"), 0.01)
		draw_arc(at, 26.0, -PI * 0.5 * face - 1.0, -PI * 0.5 * face + 1.0, 14, Color(0.85, 0.95, 1.0, 0.5 + 0.5 * k), 4.0)
	if parry_fx > 0.0:
		var f := parry_fx / maxf(Tune.f("parry_fx_time"), 0.01)
		for i in 10:
			var a := TAU * float(i) / 10.0
			draw_line(at + Vector2(cos(a), sin(a)) * 8.0, at + Vector2(cos(a), sin(a)) * (14.0 + 30.0 * (1.0 - f)), Color(1.0, 0.9, 0.5, f), 2.5)
		draw_circle(at, 10.0 * f, Color(1, 1, 1, f))

# ---------------- drawing (placeholder art until the asset pass) ----------------
const CLOAK := Color("#2f4a52")
const CLOAK_DARK := Color("#1d3036")
const SKIN := Color("#d9c7a3")
const BLADE := Color("#e8f1f2")
const GLOW := Color("#ffd27a")

func _draw() -> void:
	_draw_parry()
	if visual != null:
		# Until each weapon has its rig sprite, the weapon and chain bolts stay
		# procedural over the rig (the rig's own stick sprite is hidden).
		_draw_shield()
		if not visual.get("bakes_weapon"):
			_draw_blade()
		return
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
	_draw_shield()
	_draw_blade()

func _draw_shield() -> void:
	if shield > 0.0:
		# Zhiva shield (§3.14): green ring around the hero.
		draw_arc(Vector2(0, -H / 2.0), H * 0.75, 0.0, TAU, 40, Color("#9ff0b0", 0.4 + 0.5 * shield / maxf(Tune.f("shield_max"), 1.0)), 3.0)

func _blade_angle() -> float:
	if atk_t <= 0.0:
		return 2.2 if dash_t > 0.0 and rolling else 0.9
	var k := clampf(1.0 - atk_t / atk_dur, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	match atk_dir:
		"up": return lerpf(0.4, -2.6, k)
		"down": return lerpf(-0.6, 2.4, k)
	match weapon.body_id():
		"spear":
			return lerpf(-0.15, 0.1, k)
		"staff":
			return lerpf(-2.6, 0.9, k) if combo % 2 == 1 else lerpf(1.0, -2.4, k)
		"hammer":
			return lerpf(-2.4, 1.2, k)
	return lerpf(-2.0, 0.9, k) if combo % 2 == 1 else lerpf(1.2, -1.6, k)

func _draw_blade() -> void:
	var hand := Vector2(8.0 * face, -34.0)
	if visual != null and visual.has_method("hand_point"):
		hand = visual.call("hand_point")
	var a := _blade_angle()
	var dir := Vector2(cos(a) * face, sin(a))
	var body := weapon.body_id()
	var length := weapon.reach() * 0.72
	if body == "spear" and atk_t > 0.0 and atk_dir == "side":
		hand += Vector2(face * 22.0 * sin(clampf(1.0 - atk_t / atk_dur, 0.0, 1.0) * PI), 0)
	var tip := weapon.colour().lerp(BLADE, 0.45)
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
			draw_line(hand + dd * 14.0, hand + dd * length, Color(weapon.colour().lerp(Color(1, 0.95, 0.8), 0.5), 0.28 - i * 0.03), 10.0 - i)
			if body == "staff" or weapon.mech() == "both_sides":
				draw_line(hand - dd * 14.0, hand - dd * length * 0.5, Color(1, 0.95, 0.8, 0.2 - i * 0.02), 8.0 - i)
	match body:
		"spear":
			draw_line(hand - dir * 18.0, hand + dir * (length - 14.0), Color("#6b4a2b"), 4.0)
			draw_colored_polygon(PackedVector2Array([hand + dir * length, hand + dir * (length - 18.0) + dir.orthogonal() * 6.0,
				hand + dir * (length - 18.0) - dir.orthogonal() * 6.0]), tip)
		"staff":
			draw_line(hand - dir * length * 0.5, hand + dir * length, Color("#8a6a3e"), 5.0)
			draw_circle(hand + dir * length, 4.0, tip)
			draw_circle(hand - dir * length * 0.5, 4.0, tip)
		"hammer":
			draw_line(hand, hand + dir * length, Color("#6b4a2b"), 4.0)
			var hd := hand + dir * length
			var o := dir.orthogonal() * 12.0
			draw_colored_polygon(PackedVector2Array([hd - o - dir * 9.0, hd + o - dir * 9.0, hd + o + dir * 9.0, hd - o + dir * 9.0]), tip)
		"sickles":
			draw_line(hand, hand + dir * 10.0, Color("#6b4a2b"), 4.0)
			var c := hand + dir * length * 0.55
			draw_arc(c, length * 0.45, dir.angle() - 1.2, dir.angle() + 0.9, 10, tip, 3.0)
			draw_arc(Vector2(-6.0 * face, -30.0) + dir * length * 0.3, length * 0.32, dir.angle() + 2.0, dir.angle() + 3.6, 8, tip.darkened(0.3), 2.5)
		_:
			draw_line(hand, hand + dir * 12.0, Color("#6b4a2b"), 4.0)
			draw_line(hand + dir * 12.0, hand + dir * length, Color("#a07a4a") if weapon.id == "stick" else (BLADE if weapon.rarity() == "c" else tip), 3.5)
	for bl: Dictionary in bolts:
		var pa: Vector2 = bl.a - position
		var pb: Vector2 = bl.b - position
		var mid := (pa + pb) / 2.0 + Vector2(0, -14)
		draw_polyline(PackedVector2Array([pa, mid, pb]), Color("#bfe6ff", clampf(bl.t * 4.0, 0.0, 1.0)), 3.0)
