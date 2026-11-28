## The hero's god helpers that live in the world (GDD gods-expansion §3.4-3.10,
## §3.12): Khors's sun disks (orbit, boomerang, flare ring), Semargl's fire dog,
## Dazhbog's noon sun, Svyatovit's cross strike, Mokosh's thread lines, the
## kill heals of Dazhbog and Yarilo, and the Svarog forge projectiles (sparks,
## waves, javelins, thrown sickles) and echo hits. A child of the Player drawn in
## world space (top_level); every number comes from tuning.json, runes.json and
## svarog.json. Hits go through Enemy.hurt (ADR-0002).
class_name GodPowers
extends Node2D

var hero: Player
## Flying hero projectiles: {kind, pos, vel, r, dmg, life, age, grav, pierce,
## hit: {enemy id: true}, boom: {out, back, from} (boomerang), col, look, payload}.
var shots: Array[Dictionary] = []
## Seconds left of each temporary orbit disk (Солнцеворот).
var orbit_tmp: Array[float] = []
## Orbit disk phase and per-enemy hit cooldowns {id: s}.
var orbit_a: float = 0.0
var orbit_cd: Dictionary = {}
## Noon suns: {pos, r, t, tick}.
var suns: Array[Dictionary] = []
## Echo hits of Двойной след: {e, dmg, t, from_x}.
var echoes: Array[Dictionary] = []
## Cross flashes to draw: {pos, t}.
var crosses: Array[Dictionary] = []
## The dog: state idle | fly | back, position, target, timers, queued bites.
var dog_pos: Vector2 = Vector2.ZERO
var dog_state: String = "idle"
var dog_t: float = 0.0
var dog_cd: float = 0.0
var dog_target: Enemy
var dog_bites: int = 0
var dog_from: Vector2 = Vector2.ZERO
## Khors strike counter (every 3rd swing throws a disk).
var swings: int = 0
## Healing given in the current room by Dazhbog / Yarilo passives.
var healed: Dictionary = {}
var _room: int = -999
var _t: float = 0.0

func _ready() -> void:
	top_level = true
	z_index = 3
	add_to_group(&"vfx_lights")
	if hero:
		dog_pos = hero.position + Vector2(-50, -90)
	if not Events.enemy_killed.is_connected(_on_killed):
		Events.enemy_killed.connect(_on_killed)

func _exit_tree() -> void:
	if Events.enemy_killed.is_connected(_on_killed):
		Events.enemy_killed.disconnect(_on_killed)

func _b() -> RunBuild:
	return hero.build if hero else null

func _dt_mult() -> float:
	return hero.world.time_mult() if hero and hero.world else 1.0

func _enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and not e.dead and is_instance_valid(e):
			out.append(e)
	return out

func _physics_process(dt: float) -> void:
	if hero == null or not is_instance_valid(hero) or _b() == null:
		return
	if hero.world and hero.world.hitstop > 0.0:
		return
	dt *= _dt_mult()
	_t += dt
	_room_check()
	_tick_orbit(dt)
	_tick_shots(dt)
	_tick_dog(dt)
	_tick_suns(dt)
	_tick_echoes(dt)
	for c in crosses:
		c.t -= dt
	crosses.assign(crosses.filter(func(c: Dictionary) -> bool: return c.t > 0.0))
	queue_redraw()

func _room_check() -> void:
	var r := -1
	if hero.world and hero.world.level_room:
		r = hero.world.level_room.room_at(hero.position)
	if r != _room:
		_room = r
		healed.clear()

# ---------------- hits ----------------

## A god-helper hit on `e`: `kind` Hit kind, `dmg`, statuses `payload`
## (RunBuild payload form), knockback `kb` from x `from_x`.
func strike(e: Enemy, kind: Hit.Kind, dmg: float, payload: Dictionary, kb: float = 0.0, from_x: float = NAN) -> float:
	if e == null or e.dead:
		return 0.0
	var h := Hit.make(kind, dmg, hero.position.x if is_nan(from_x) else from_x, kb)
	h.source = hero
	h.mods = _b().damage_mods(false)
	h.add_payload(payload)
	return e.hurt(h)

func _disk_hit(e: Enemy, dmg: float) -> void:
	var b := _b()
	var duos := b.duos
	var d := dmg * (Tune.f("halo_mult") if e.status.halo > StatusSet.EPS else 1.0)
	var p := {}
	var kb := 0.0
	if "duo_dawn" in duos:
		var r := b.row("duo_dawn")
		if e.status.blinded():
			d *= float(r.get("dmg_mult", 1.5))
		RunBuild._add_status(p, "blind", float(r.get("blind", 0.5)), Tune.data)
	if "duo_sun_wheel" in duos:
		var r2 := b.row("duo_sun_wheel")
		RunBuild._add_status(p, "cuts", float(r2.get("cuts", 1)), Tune.data)
		kb = float(r2.get("kb", 240))
	strike(e, Hit.Kind.PROJECTILE, d, p, kb, e.position.x - signf(e.position.x - hero.position.x))

# ---------------- Khors: disks ----------------

func _orbit_count() -> int:
	var b := _b()
	var n := int(b.value("khors_p", "orbit", 0.0)) + orbit_tmp.size()
	return mini(n, int(Tune.f("orbit_max")))

func _tick_orbit(dt: float) -> void:
	for i in orbit_tmp.size():
		orbit_tmp[i] -= dt
	orbit_tmp.assign(orbit_tmp.filter(func(t: float) -> bool: return t > 0.0))
	orbit_a += Tune.f("orbit_speed") * dt
	for k: int in orbit_cd.keys():
		orbit_cd[k] = float(orbit_cd[k]) - dt
	var n := _orbit_count()
	if n <= 0:
		return
	var dmg := Tune.f("disk_dmg_k") * Tune.f("strike_dmg")
	var shield := "duo_sun_shield" in _b().duos
	for i in n:
		var p := orbit_pos(i, n)
		for e in _enemies():
			var id := e.get_instance_id()
			if float(orbit_cd.get(id, 0.0)) > 0.0 or not e.hurt_rect().grow(Tune.f("disk_r")).has_point(p):
				continue
			orbit_cd[id] = Tune.f("disk_hit_cd")
			_disk_hit(e, dmg)
		if shield and hero.world:
			for ch in hero.world.get_children():
				var s := ch as EnemyShot
				if s and not s.reflected and s.life > 0.0 and s.position.distance_to(p) < s.r + Tune.f("disk_r") + 6.0:
					_reflect(s, float(_b().row("duo_sun_shield").get("reflect_k", 1.0)), 1)

## World position of orbit disk `i` of `n`.
func orbit_pos(i: int, n: int) -> Vector2:
	var a := orbit_a + i * TAU / maxf(n, 1)
	return hero.position - Vector2(0, Player.H * 0.5) + Vector2(cos(a), sin(a)) * Tune.f("orbit_r")

## Солнцеворот: `n` more orbit disks for `t` seconds (orbit_max holds).
func add_orbit(n: int, t: float) -> void:
	for i in n:
		if _orbit_count() >= int(Tune.f("orbit_max")):
			return
		orbit_tmp.append(t)

## Круг Хорса: a swing started; every `every`-th throws `count` boomerang disks.
func on_swing() -> void:
	var b := _b()
	if b.slot_god("strike") != "khors":
		return
	swings += 1
	var every := int(b.slot_value("strike", "every", 3.0))
	if swings % maxi(every, 1) != 0:
		return
	var count := int(b.slot_value("strike", "boom", 1.0))
	var k := b.slot_value("strike", "boom_k", 0.6)
	for i in count:
		var ang := deg_to_rad(12.0 * (i - (count - 1) / 2.0))
		var dir := Vector2(hero.face, 0).rotated(ang)
		shots.append({ "kind": "disk", "pos": hero.position - Vector2(0, Player.H * 0.55), "vel": dir * Tune.f("boom_range") / Tune.f("boom_time"),
			"r": Tune.f("disk_r"), "dmg": k * Tune.f("strike_dmg"), "life": Tune.f("boom_time") * 2.0 + 0.4, "age": 0.0,
			"boom": { "out": Tune.f("boom_time"), "back": Tune.f("boom_time") }, "hit": {}, "col": Enemy.god_colour("khors"), "pierce": 99, "look": "disk" })

## Колесо солнца: a ring of `n` disks from `at`.
func disk_ring(at: Vector2, n: int, dmg: float) -> void:
	for i in n:
		var dir := Vector2.RIGHT.rotated(i * TAU / maxf(n, 1))
		shots.append({ "kind": "disk", "pos": at, "vel": dir * Tune.f("ring_speed"), "r": Tune.f("disk_r"), "dmg": dmg,
			"life": Tune.f("ring_life"), "age": 0.0, "hit": {}, "col": Enemy.god_colour("khors"), "pierce": 99, "look": "disk" })

# ---------------- Svarog: forge projectiles ----------------

## Finisher projectiles of a forge upgrade `fs` (fin_shot) with base damage `base`.
func fin_shots(fs: Dictionary, base: float) -> void:
	var n := int(fs.get("count", 1))
	var spread := float(fs.get("spread", 0.0))
	for i in n:
		var ang := deg_to_rad(0.0 if n == 1 else -spread / 2.0 + spread * i / (n - 1.0))
		var grav := float(fs.get("grav", 0.0))
		var dir := Vector2(hero.face, 0).rotated(ang * hero.face)
		if grav > 0.0:
			dir = Vector2(hero.face * cos(ang), -0.55 - 0.35 * absf(sin(ang))).normalized()
		shots.append({ "kind": "spark", "pos": hero.position - Vector2(-hero.face * 30.0, Player.H * 0.5), "vel": dir * float(fs.get("speed", 700)),
			"r": 9.0 if String(fs.get("look", "")) == "" else 14.0, "dmg": base * float(fs.get("k", 0.5)), "life": float(fs.get("life", 0.5)), "age": 0.0,
			"grav": grav, "hit": {}, "col": Enemy.god_colour("svarog"), "pierce": 99, "look": String(fs.get("look", "spark")) })

## Бросок серпов: two sickles thrown as a boomerang (`th` = {dist, time, k}).
func throw_sickles(th: Dictionary, base: float) -> void:
	var t := float(th.get("time", 0.8)) / 2.0
	for i in 2:
		shots.append({ "kind": "sickle", "pos": hero.position - Vector2(0, Player.H * (0.4 + 0.2 * i)), "vel": Vector2(hero.face, 0) * float(th.get("dist", 360)) / t,
			"r": 18.0, "dmg": base * float(th.get("k", 1.2)), "life": t * 2.0 + 0.4, "age": 0.0, "boom": { "out": t, "back": t },
			"hit": {}, "col": Color("#e8e0d0"), "pierce": 99, "look": "sickle", "rune": true })

## Двойной след: repeats a hit of `dmg` on `e` after `gap` s, no statuses.
func echo(e: Enemy, dmg: float, gap: float) -> void:
	echoes.append({ "e": e, "dmg": dmg, "t": gap, "from_x": hero.position.x })

func _tick_echoes(dt: float) -> void:
	for ec in echoes:
		ec.t -= dt
		if ec.t <= 0.0:
			var e: Enemy = ec.e
			if is_instance_valid(e) and not e.dead:
				var h := Hit.make(Hit.Kind.STRIKE, float(ec.dmg), float(ec.from_x), 0.0)
				h.source = hero
				h.nested = true
				e.hurt(h)
	echoes.assign(echoes.filter(func(ec: Dictionary) -> bool: return ec.t > 0.0))

## Reflects an enemy shot toward its shooter with dmg × k (Наковальня, Солнечный щит).
func _reflect(s: EnemyShot, k: float, pierce: int) -> void:
	var shooter := s.source as Enemy
	var alive := shooter != null and is_instance_valid(shooter) and not shooter.dead
	var v := ParryRules.reflect_velocity(s.position, s.vel, alive, shooter.center() if alive else Vector2.ZERO, Tune.data)
	s.reflect(v, s.dmg * k, hero)
	s.set_meta(&"pierce", pierce)

func _tick_shots(dt: float) -> void:
	var list := _enemies()
	for s in shots:
		s.age += dt
		s.life -= dt
		var boom: Dictionary = s.get("boom", {})
		if not boom.is_empty() and s.age >= float(boom.out):
			# Coming back: steer to the hero; the hit list clears once at the turn.
			if not bool(s.get("turned", false)):
				s.turned = true
				s.hit = {}
			var to := hero.position - Vector2(0, Player.H * 0.5) - (s.pos as Vector2)
			var speed := (s.vel as Vector2).length()
			s.vel = to.normalized() * speed
			if to.length() < 24.0:
				s.life = 0.0
		elif String(s.kind) == "disk":
			_seek_halo(s, list, dt)
		s.vel = (s.vel as Vector2) + Vector2(0, float(s.get("grav", 0.0)) * dt)
		s.pos = (s.pos as Vector2) + (s.vel as Vector2) * dt
		if hero.world and World.shot_blocked(hero.world, s.pos, Tune.f("shot_floor")) and boom.is_empty():
			s.life = 0.0
		for e in list:
			var id := e.get_instance_id()
			if (s.hit as Dictionary).has(id) or not e.hurt_rect().grow(float(s.r)).has_point(s.pos):
				continue
			s.hit[id] = true
			if String(s.kind) == "disk":
				_disk_hit(e, float(s.dmg))
			else:
				var p := _b().payload("strike", 1.0, Tune.data) if bool(s.get("rune", false)) else {}
				strike(e, Hit.Kind.PROJECTILE, float(s.dmg), p, Tune.f("knockback") * 0.5, (s.pos as Vector2).x - signf((s.vel as Vector2).x))
	shots.assign(shots.filter(func(s: Dictionary) -> bool: return s.life > 0.0))

func _seek_halo(s: Dictionary, list: Array[Enemy], dt: float) -> void:
	var best: Enemy = null
	var bd := 300.0
	for e in list:
		if e.status.halo <= StatusSet.EPS or (s.hit as Dictionary).has(e.get_instance_id()):
			continue
		var d := e.center().distance_to(s.pos)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	var v: Vector2 = s.vel
	var want := (best.center() - (s.pos as Vector2)).angle()
	var a := rotate_toward(v.angle(), want, 6.0 * dt)
	s.vel = Vector2.RIGHT.rotated(a) * v.length()

# ---------------- Semargl: the dog ----------------

func _dog_on() -> bool:
	return _b().has_god("semargl")

func _dog_home() -> Vector2:
	return hero.position + Vector2(-50.0 * hero.face, -90.0)

## Огненные крылья: the dog may jump at once.
func dog_now() -> void:
	dog_cd = 0.0

## Стая: `n` bites in a row on the next prey.
func dog_pack(n: int) -> void:
	dog_bites = maxi(dog_bites, n)
	dog_cd = 0.0

func _tick_dog(dt: float) -> void:
	if not _dog_on():
		dog_state = "idle"
		return
	dog_cd -= dt
	match dog_state:
		"idle":
			dog_pos = dog_pos.lerp(_dog_home() + Vector2(0, sin(_t * 3.0) * 6.0), clampf(dt * 8.0, 0.0, 1.0))
			if dog_cd <= 0.0:
				dog_target = _dog_pick()
				if dog_target:
					dog_state = "fly"
					dog_t = 0.0
					dog_from = dog_pos
		"fly":
			dog_t += dt
			if dog_target == null or not is_instance_valid(dog_target) or dog_target.dead:
				dog_state = "back"
				dog_t = 0.0
				dog_from = dog_pos
				return
			var k := clampf(dog_t / Tune.f("dog_fly"), 0.0, 1.0)
			dog_pos = dog_from.lerp(dog_target.center(), k * k * (3.0 - 2.0 * k))
			if k >= 1.0:
				_bite(dog_target)
				if dog_bites > 1 and not dog_target.dead:
					dog_bites -= 1
					dog_state = "fly"
					dog_t = Tune.f("dog_fly") - Tune.f("dog_bite_gap")
					dog_from = dog_target.center() + Vector2(-hero.face * 40.0, -40.0)
				else:
					dog_bites = 0
					dog_state = "back"
					dog_t = 0.0
					dog_from = dog_pos
		"back":
			dog_t += dt
			var k2 := clampf(dog_t / Tune.f("dog_back"), 0.0, 1.0)
			dog_pos = dog_from.lerp(_dog_home(), k2)
			if k2 >= 1.0:
				dog_state = "idle"
				dog_cd = Tune.f("dog_cd") * _b().value("semargl_p", "dog_cd", 1.0)

func _dog_pick() -> Enemy:
	var best: Enemy = null
	var bd := Tune.f("dog_range")
	for e in _enemies():
		if e.status.prey <= StatusSet.EPS:
			continue
		var d := e.center().distance_to(hero.position)
		if d < bd:
			bd = d
			best = e
	return best

func _bite(e: Enemy) -> void:
	var b := _b()
	var p := {}
	if "duo_fire_dog" in b.duos:
		RunBuild._add_status(p, "burn", float(b.row("duo_fire_dog").get("burn", 1.0)), Tune.data)
	if "duo_hunt" in b.duos:
		RunBuild._add_status(p, "shock", float(b.row("duo_hunt").get("shock", 1)), Tune.data)
	strike(e, Hit.Kind.PROJECTILE, Tune.f("dog_dmg"), p, Tune.f("dog_kb"), dog_pos.x - signf(e.position.x - dog_pos.x))
	if hero.world:
		hero.world.add_ring(e.center(), 40.0)

# ---------------- Dazhbog: noon sun ----------------

## Полдень: a sun of radius `r` at `at` for `t` s.
func add_sun(at: Vector2, r: float, t: float) -> void:
	suns.append({ "pos": at, "r": r, "t": t, "tick": 0.0 })

func _tick_suns(dt: float) -> void:
	for s in suns:
		s.t -= dt
		s.tick -= dt
		if s.tick <= 0.0:
			s.tick = Tune.f("sun_tick")
			for e in _enemies():
				if e.center().distance_to(s.pos) <= float(s.r):
					if e.status.add_timer("blind", Tune.f("sun_blind")):
						e._say("СЛЕП", "dazhbog")
	suns.assign(suns.filter(func(s: Dictionary) -> bool: return s.t > 0.0))

## Light of the suns, disks and the dog for the darkness (Darkness, vfx_lights).
func light_spots() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for s in suns:
		out.append(Vector4((s.pos as Vector2).x, (s.pos as Vector2).y, float(s.r), 0.75))
	if hero and _b():
		var n := _orbit_count()
		if n > 0:
			out.append(Vector4(hero.position.x, hero.position.y - Player.H * 0.5, Tune.f("orbit_r") + 40.0, 0.4))
		if _dog_on():
			out.append(Vector4(dog_pos.x, dog_pos.y, 70.0, 0.5))
	return out

# ---------------- Svyatovit: the cross ----------------

## Крестовый удар: 4 boxes cross_w × cross_h up, down, left and right of the
## hero's centre; each enemy once, dmg = k × strike_dmg with `payload`.
func cross(k: float, payload: Dictionary) -> void:
	var c := hero.position - Vector2(0, Player.H * 0.5)
	var cw := Tune.f("cross_w")
	var ch := Tune.f("cross_h")
	var boxes: Array[Rect2] = [Rect2(c + Vector2(0, -ch / 2.0), Vector2(cw, ch)), Rect2(c + Vector2(-cw, -ch / 2.0), Vector2(cw, ch)),
		Rect2(c + Vector2(-ch / 2.0, -cw), Vector2(ch, cw)), Rect2(c + Vector2(-ch / 2.0, 0), Vector2(ch, cw))]
	var p := payload.duplicate()
	if "duo_four_winds" in _b().duos:
		RunBuild._add_status(p, "cuts", float(_b().row("duo_four_winds").get("cuts", 1)), Tune.data)
	for e in _enemies():
		if boxes.any(func(r: Rect2) -> bool: return r.intersects(e.hurt_rect())):
			strike(e, Hit.Kind.STRIKE, k * Tune.f("strike_dmg"), p, Tune.f("knockback"))
	crosses.append({ "pos": c, "t": 0.25 })
	if hero.world:
		hero.world.add_shake(2.0)

# ---------------- kill heals (Dazhbog, Yarilo) ----------------

func _on_killed(enemy: Node2D, _hit: RefCounted) -> void:
	var e := enemy as Enemy
	if e == null or hero == null or not is_instance_valid(hero) or hero.dead or _b() == null:
		return
	var b := _b()
	if e.status.blinded() and b.has("dazhbog_p"):
		_heal("dazhbog", b.value("dazhbog_p", "heal", 0.0), b.value("dazhbog_p", "room_cap", 15.0))
	if e.status.yar > StatusSet.EPS:
		if b.has("yarilo_p"):
			_heal("yarilo", b.value("yarilo_p", "heal", 0.0), b.value("yarilo_p", "room_cap", 20.0))
		if "duo_vesna" in b.duos:
			hero.add_shield(float(b.row("duo_vesna").get("shield", 4)))

func _heal(key: String, v: float, cap: float) -> void:
	var left := cap - float(healed.get(key, 0.0))
	var add := minf(Difficulty.heal(v), left)
	if add <= 0.0:
		return
	healed[key] = float(healed.get(key, 0.0)) + add
	hero.hp = minf(Tune.f("player_hp"), hero.hp + add)

# ---------------- look ----------------

func _draw() -> void:
	if hero == null or not is_instance_valid(hero) or _b() == null:
		return
	var b := _b()
	# Yarilo: a green-gold glow, brighter at low health.
	if b.has_god("yarilo"):
		var lost := clampf(1.0 - hero.hp / Tune.f("player_hp"), 0.0, 1.0)
		draw_circle(hero.position - Vector2(0, Player.H * 0.5), 46.0, Color(Enemy.god_colour("yarilo"), 0.06 + 0.22 * lost))
	# Mokosh: thin threads between linked enemies.
	var linked: Array[Enemy] = []
	for e in _enemies():
		if e.status.thread > StatusSet.EPS:
			linked.append(e)
	var mc := Enemy.god_colour("mokosh")
	for i in range(1, linked.size()):
		var a := linked[i - 1].center()
		var z := linked[i].center()
		var mid := (a + z) / 2.0 + Vector2(0, 18.0 + 6.0 * sin(_t * 2.0 + i))
		draw_polyline(PackedVector2Array([a, a.lerp(mid, 0.5) + Vector2(0, 6), mid, mid.lerp(z, 0.5) + Vector2(0, 6), z]), Color(mc, 0.75), 2.0)
	# Suns.
	var dc := Enemy.god_colour("dazhbog")
	for s in suns:
		var p: Vector2 = s.pos
		draw_circle(p, float(s.r), Color(dc, 0.07 + 0.03 * sin(_t * 4.0)))
		draw_arc(p, float(s.r), 0.0, TAU, 48, Color(dc, 0.45), 3.0)
		for k in 12:
			var a2 := _t * 0.6 + k * TAU / 12.0
			draw_line(p + Vector2(cos(a2), sin(a2)) * 30.0, p + Vector2(cos(a2), sin(a2)) * 52.0, Color(dc, 0.8), 3.0)
		draw_circle(p, 24.0, Color(1, 0.97, 0.75, 0.85))
	# Orbit disks.
	var kc := Enemy.god_colour("khors")
	var n := _orbit_count()
	for i in n:
		_draw_disk(orbit_pos(i, n), kc)
	# Shots.
	for s in shots:
		var p2: Vector2 = s.pos
		match String(s.look):
			"disk":
				_draw_disk(p2, s.col)
			"sickle":
				var a3 := float(s.age) * 18.0
				draw_arc(p2, 14.0, a3, a3 + PI * 1.3, 12, Color("#e8e0d0"), 4.0)
				draw_line(p2, p2 + Vector2(cos(a3), sin(a3)) * 10.0, Color("#6b4425"), 4.0)
			"wave":
				var dir := signf((s.vel as Vector2).x)
				draw_arc(p2, 26.0, -PI / 2.0 if dir > 0 else PI / 2.0, PI / 2.0 if dir > 0 else PI * 1.5, 14, Color(s.col, 0.9), 6.0)
				draw_arc(p2 - Vector2(dir * 8.0, 0), 22.0, -PI / 2.0 if dir > 0 else PI / 2.0, PI / 2.0 if dir > 0 else PI * 1.5, 14, Color(1, 0.9, 0.6, 0.7), 2.0)
			"spear":
				var v := (s.vel as Vector2).normalized()
				draw_line(p2 - v * 40.0, p2 + v * 14.0, Color(s.col, 0.85), 5.0)
				draw_colored_polygon(PackedVector2Array([p2 + v * 24.0, p2 + v * 8.0 + v.orthogonal() * 7.0, p2 + v * 8.0 - v.orthogonal() * 7.0]), Color(1, 0.9, 0.6))
			_:
				draw_circle(p2, float(s.r) * 1.8, Color(s.col, 0.25))
				draw_circle(p2, float(s.r) * 0.7, Color(1, 0.92, 0.6))
	# Cross flashes.
	var vc := Enemy.god_colour("svyatovit")
	for c in crosses:
		var cp: Vector2 = c.pos
		var al := float(c.t) / 0.25
		var cw := Tune.f("cross_w")
		draw_line(cp - Vector2(cw, 0), cp + Vector2(cw, 0), Color(vc, al), 10.0 * al + 2.0)
		draw_line(cp - Vector2(0, cw), cp + Vector2(0, cw), Color(vc, al), 10.0 * al + 2.0)
	# Горн Сварога: the charge ring.
	if hero.charging:
		var cg := hero.forge_hook("charged")
		var k5 := clampf(hero.charge_t / maxf(float(cg.get("hold", 0.5)), 0.01), 0.0, 1.0)
		var sc := Enemy.god_colour("svarog")
		var hc := hero.position - Vector2(0, Player.H * 0.5)
		draw_arc(hc, 52.0, -PI / 2.0, -PI / 2.0 + TAU * k5, 32, sc, 5.0)
		if k5 >= 1.0:
			draw_circle(hc, 58.0, Color(sc, 0.15 + 0.1 * sin(_t * 20.0)))
	# The dog.
	if _dog_on():
		_draw_dog()

func _draw_disk(p: Vector2, c: Color) -> void:
	draw_circle(p, 16.0, Color(c, 0.22))
	draw_circle(p, Tune.f("disk_r"), c)
	draw_arc(p, Tune.f("disk_r") - 3.0, _t * 9.0, _t * 9.0 + PI, 8, Color(1, 1, 1, 0.8), 2.0)

func _draw_dog() -> void:
	var c := Enemy.god_colour("semargl")
	var fire := Color("#ffb04a")
	var p := dog_pos
	var f := float(hero.face) if dog_state == "idle" else signf((dog_target.center().x if dog_target and is_instance_valid(dog_target) else hero.position.x) - p.x + 0.001)
	draw_circle(p, 26.0, Color(fire, 0.12))
	for i in 3:
		draw_circle(p - Vector2(f * (14.0 + i * 10.0), -2.0 + i * 2.0), 6.0 - i * 1.5, Color(fire, 0.5 - i * 0.12))
	var flap := sin(_t * 14.0) * 8.0
	draw_colored_polygon(PackedVector2Array([p + Vector2(-4 * f, -4), p + Vector2(-18 * f, -22 - flap), p + Vector2(6 * f, -8)]), Color(c, 0.85))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-14 * f, 6), p + Vector2(10 * f, 4), p + Vector2(16 * f, -6), p + Vector2(-8 * f, -6)]), c)
	draw_colored_polygon(PackedVector2Array([p + Vector2(12 * f, -6), p + Vector2(24 * f, -2), p + Vector2(14 * f, 4)]), c)
	draw_circle(p + Vector2(16 * f, -5), 2.0, Color("#ff6a2a"))
