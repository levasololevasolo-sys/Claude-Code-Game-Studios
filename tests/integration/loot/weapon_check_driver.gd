## Scripted weapon check (GDD weapons-and-loot §3.2-3.4, §3.9, AC 9, 11). For each
## main weapon whose mechanic is implemented: clears the room, equips it ★, does
## a full side combo on a fresh straw dummy and logs the damage of every swing;
## mechanic probes (execute, after-dash, held, juggle, rage, wall boost...) log
## their numbers. Each secondary weapon fires at a dummy with Удар Сварога in the
## Strike slot and logs damage and burn (sub_god_k). Then a ★★★ drop lies by the
## hero (comparison card), E swaps (AC 11), and the HUD is shot. Screenshots go
## to <out_dir>/weapon-*.png. Started by world.gd with `-- --weapon-check=<dir>`.
extends Node

const HERO_X: float = 1200.0
const TAP_GAP: int = 4
const SHOTS: Dictionary = { "blade": 3, "staff": 4, "hammer": 2 }

var out_dir: String = "user://weapon_check"
var _w: World
var _fails: int = 0
var _lines: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_w = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	print("[weapon-check] ", s)
	_lines.append(s)

func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	_note(("OK   " if cond else "FAIL ") + what)

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _clear() -> void:
	for n in _w.get_children():
		if n is Enemy or n is EnemyShot or n is Flare or n is HeroShot or n is WeaponDrop:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()

func _frames(n: int, keys: Dictionary = {}) -> void:
	var p: Player = _w.player
	for i in n:
		p.fake = keys
		await p.stepped
	p.fake = {}

func _place(x: float = HERO_X) -> void:
	var p: Player = _w.player
	p.scripted = true
	p.position = Vector2(x, Tune.f("ground_y"))
	p.velocity = Vector2.ZERO
	p.face = 1
	p.hp = 1000.0
	p.inv = 0.0
	p.combo = 0
	p.combo_t = 0.0
	p.atk_t = 0.0
	p.rage = 0.0
	p.since_dash = 99.0
	_w.cam.reset_smoothing()

func _dummy(x: float, hp: float = 100000.0) -> Enemy:
	var d := _w.spawn_enemy(StrawDummy.new(), Vector2(x, Tune.f("ground_y")), -1, false, 1)
	await get_tree().physics_frame
	d.max_hp = hp
	d.hp = hp
	return d

func _crawler(x: float) -> Enemy:
	var c := _w.spawn_enemy(EnemyRoster.make("crawler"), Vector2(x, Tune.f("ground_y")), -1, false, 3)
	await get_tree().physics_frame
	c.max_hp = 100000.0
	c.hp = 100000.0
	c.stun = 99.0
	return c

func _set_build(arg: String) -> void:
	_w.build = RunBuild.from_arg(arg) if arg != "" else RunBuild.make()
	_w.player.build = _w.build

## One full side combo; returns the damage per swing (index = swing number - 1).
func _combo(p: Player, d: Enemy, shot_name: String = "") -> Array:
	var n := (p.weapon.body().mult as Array).size()
	var per: Array = []
	per.resize(n)
	per.fill(0.0)
	var cur := [0]
	var on := func(_e: Enemy, amount: float, h: Hit) -> void:
		if h.kind == Hit.Kind.STRIKE or h.kind == Hit.Kind.SLAM:
			per[cur[0]] = float(per[cur[0]]) + amount
	d.damaged.connect(on)
	for i in n:
		cur[0] = i
		# Knockback carries the dummy off; put it back in reach so each swing is logged.
		d.position.x = p.position.x + p.face * 46.0
		d.kb = 0.0
		await _frames(1, { "strike": true })
		var ticks := int(ceil(float(p.weapon.times()[i]) * 60.0))
		for k in ticks:
			await _frames(1)
			if shot_name != "" and i == n - 1 and k == int(ticks * 0.45):
				await _shot(shot_name)
		await _frames(TAP_GAP)
	d.damaged.disconnect(on)
	return per

func _main_check() -> void:
	var ids: Array = ["stick", "blade", "ringsword", "ragesword", "perunsword", "spear", "berdysh", "arrowspear",
		"velesspear", "thunderpike", "sickles", "frostscythe", "marascythe", "whirlsickles", "hammer", "flail",
		"chekan", "jumphammer", "thornmace", "staff", "koromyslo", "batog", "oslop"]
	for id: String in ids:
		_clear()
		_set_build("")
		await _frames(2)
		var p: Player = _w.player
		p.equip(Weapon.make(id))
		_place()
		var d := await _dummy(HERO_X + 60.0)
		var shot := "weapon-%s-swing.png" % id if SHOTS.has(id) else ""
		var per := await _combo(p, d, shot)
		var rounded := per.map(func(v: float) -> float: return snappedf(v, 0.01))
		_note("%s (%s, %s): per swing %s, charge x%.2f, reach %d" % [id, p.weapon.body_id(), p.weapon.title(), rounded, p.weapon.charge(), int(p.weapon.reach())])
		_ok(per.all(func(v: float) -> bool: return v > 0.0), "%s: every swing of the combo hit the dummy" % id)
		if id == "blade":
			_ok(rounded == [11.0, 11.0, 19.8], "blade combo is 11 / 11 / 19.8 (identical to the old port)")
		await _frames(30)

func _probe(id: String, build: String, setup: Callable, keys_first: Dictionary = {}) -> float:
	_clear()
	_set_build(build)
	await _frames(2)
	var p: Player = _w.player
	p.equip(Weapon.make(id))
	_place()
	var d := await _dummy(HERO_X + 60.0)
	await setup.call(p, d)
	var got := [0.0]
	var on := func(_e: Enemy, amount: float, h: Hit) -> void:
		if h.kind == Hit.Kind.STRIKE:
			got[0] += amount
	d.damaged.connect(on)
	await _frames(1, keys_first.merged({ "strike": true }))
	await _frames(int(ceil(float(p.weapon.times()[0]) * 60.0)) + 2, keys_first)
	d.damaged.disconnect(on)
	return got[0]

## One side strike of `id` on an enemy already placed (`e`); strike damage.
func _probe_on(id: String, e: Enemy) -> float:
	var p: Player = _w.player
	p.equip(Weapon.make(id))
	_place()
	var got := [0.0]
	e.damaged.connect(func(_e: Enemy, amount: float, h: Hit) -> void:
		if h.kind == Hit.Kind.STRIKE: got[0] += amount)
	await _frames(1, { "strike": true })
	await _frames(int(ceil(float(p.weapon.times()[0]) * 60.0)) + 2)
	return got[0]

func _mech_probes() -> void:
	var nop := func(_p: Player, _d: Enemy) -> void: pass
	var base_spear := await _probe("spear", "", nop)
	var low := await _probe("berdysh", "", func(_p: Player, d: Enemy) -> void: d.hp = d.max_hp * 0.2)
	_ok(is_equal_approx(low, base_spear * 2.5), "Бердыш below 25%%: %.2f = 2.5 × %.2f" % [low, base_spear])
	var dash := await _probe("arrowspear", "", func(p: Player, _d: Enemy) -> void: p.since_dash = 0.1)
	_ok(is_equal_approx(dash, base_spear * 1.8), "Сулица-стрела 0.1 s after a dash: %.2f = 1.8 × %.2f" % [dash, base_spear])
	var base_sick := await _probe("sickles", "", nop)
	var held := await _probe("frostscythe", "", func(_p: Player, d: Enemy) -> void: d.stun = 2.0)
	_ok(is_equal_approx(held, base_sick * 1.6), "Ледяная коса on a stunned dummy: %.2f = 1.6 × %.2f" % [held, base_sick])
	var rage := await _probe("ragesword", "", func(p: Player, _d: Enemy) -> void: p.rage = 0.6)
	_ok(is_equal_approx(rage, 11.0 * 1.6), "Ярый меч at full rage: %.2f = 11 × 1.6" % rage)
	var perun := [false]
	await _probe("perunsword", "", func(p: Player, d: Enemy) -> void:
		d.status.shock = 1
		p.combo = 2
		p.combo_t = 1.0
		d.damaged.connect(func(_e: Enemy, _a: float, h: Hit) -> void:
			if h.kind == Hit.Kind.STATUS:
				perun[0] = true))
	_ok(perun[0], "Меч Перуна finisher on a target with 1 charge -> discharge")
	var pike := [0.0, 0]
	await _probe("thunderpike", "kupala_s,perun_d", func(_p: Player, d: Enemy) -> void:
		d.damaged.connect(func(e: Enemy, _a: float, _h: Hit) -> void:
			(func() -> void:
				pike[0] = maxf(pike[0], e.status.burn)
				pike[1] = maxi(pike[1], e.status.shock)).call_deferred()))
	_ok(pike[0] > 0.0 and pike[1] >= 1, "Рогатина Громовника with Svarog + Perun: burn %.2f s, shock %d" % [pike[0], pike[1]])
	# Кистень: stun 0.25 once per 1.5 s.
	var fl := await _probe("flail", "", nop)
	_note("Кистень hit %.2f" % fl)
	# Батог: the up strike launches 1.6× higher; the next hit on the launched foe ×1.5.
	var vys := []
	for wid: String in ["staff", "batog"]:
		_clear()
		_set_build("")
		await _frames(2)
		var pb: Player = _w.player
		pb.equip(Weapon.make(wid))
		_place()
		var cb := await _crawler(HERO_X + 40.0)
		cb.stun = 0.0
		var top := [0.0]
		cb.damaged.connect(func(e: Enemy, _a: float, _h: Hit) -> void:
			(func() -> void: top[0] = minf(top[0], e.vel.y)).call_deferred())
		await _frames(1, { "strike": true, "move_up": true })
		await _frames(24, { "move_up": true })
		vys.append(top[0])
	_ok(vys[1] < vys[0] * 1.5, "Батог up-strike launch vy %.0f vs Шест %.0f (×%.2f)" % [vys[1], vys[0], vys[1] / vys[0]])
	_clear()
	await _frames(2)
	var p: Player = _w.player
	var cj := await _crawler(HERO_X + 60.0)
	cj.set_meta(&"juggled", true)
	cj.position.y = Tune.f("ground_y") - 30.0
	var jug := await _probe_on("batog", cj)
	_ok(is_equal_approx(jug, 11.0 * 0.9 * 1.5 * Tune.f("air_mult")), "Батог hit on a launched foe: %.2f = 11 × 0.9 × 1.5 × air_mult" % jug)
	# Ослоп: crawler near the wall, finisher knockback slams it ×2.
	for wid: String in ["staff", "oslop"]:
		_clear()
		_set_build("")
		await _frames(2)
		p = _w.player
		p.equip(Weapon.make(wid))
		var rw := float(_w.room.layout.w)
		_place(rw - 200.0)
		var cr := await _crawler(rw - 140.0)
		var walls := []
		cr.damaged.connect(func(_e: Enemy, a: float, h: Hit) -> void:
			if h.kind == Hit.Kind.WALL: walls.append(snappedf(a, 0.1)))
		await _combo(p, cr)
		await _frames(30)
		_note("%s near the wall: wall slam damage %s" % [wid, walls])
	# Копьё Велеса: a cursed dummy that dies blows up and curses the neighbour.
	_clear()
	_set_build("")
	await _frames(2)
	p = _w.player
	p.equip(Weapon.make("velesspear"))
	_place()
	var a := await _crawler(HERO_X + 60.0)
	var b := await _crawler(HERO_X + 140.0)
	a.hp = 5.0
	a.status.add_curse(3.0)
	var a_dead := [false]
	a.died.connect(func(_e: Enemy, _h: Hit) -> void: a_dead[0] = true)
	await _frames(1, { "strike": true })
	await _frames(20)
	_ok(a_dead[0] and b.status.cursed(), "Копьё Велеса: cursed target died (%s), neighbour cursed %.2f s" % [a_dead[0], b.status.curse])
	# Коса Мары: a kill returns the dash.
	_clear()
	await _frames(2)
	p = _w.player
	p.equip(Weapon.make("marascythe"))
	_place()
	var m := await _crawler(HERO_X + 50.0)
	m.hp = 3.0
	p.dash_cd = 0.5
	var m_dead := [false]
	m.died.connect(func(_e: Enemy, _h: Hit) -> void: m_dead[0] = true)
	await _frames(1, { "strike": true })
	await _frames(3)
	_ok(m_dead[0] and p.dash_cd <= 0.1, "Коса Мары: kill returned the dash (cd %.2f)" % p.dash_cd)

func _sub_check() -> void:
	var ids: Array = ["bow", "bomb", "beartrap", "javelin", "sling", "crossbow", "axes", "spikes", "totem", "boltwand", "windflute", "navbell"]
	for id: String in ids:
		_clear()
		_set_build("kupala_s")
		await _frames(2)
		var p: Player = _w.player
		p.equip(Weapon.make(id, Weapon.SUB))
		_place()
		var dx := 50.0 if id == "beartrap" else 380.0 if id == "bomb" else (150.0 if id in ["windflute", "navbell", "spikes", "boltwand"] else 260.0)
		var d := await _dummy(HERO_X + dx)
		var dmg := [0.0, 0]
		var burn := [0.0]
		d.damaged.connect(func(e: Enemy, a: float, h: Hit) -> void:
			if h.kind == Hit.Kind.PROJECTILE:
				dmg[0] += a
				dmg[1] += 1
				(func() -> void: burn[0] = maxf(burn[0], e.status.burn)).call_deferred())
		await _frames(1, { "sub": true })
		await _frames(150 if id in ["totem", "spikes"] else 60)
		var cd_ok := p.sub_cd > 0.0 or float(p.sub.row().cd) < 2.5
		_note("%s: hits %d, damage %.2f, burn on dummy %.2f s, cooldown %.2f s" % [id, dmg[1], dmg[0], burn[0], p.sub.cooldown()])
		_ok(dmg[1] > 0 and cd_ok, "%s hit the dummy" % id)
		if id == "bow":
			_ok(absf(burn[0] - Tune.f("burn_time") * Tune.f("sub_god_k")) < 0.1, "bow with Удар Сварога burns 0.5 × burn_time (%.2f)" % burn[0])
	# Edge 8: Strike slot empty -> no status; «Двойное» applies twice.
	_clear()
	_set_build("")
	await _frames(2)
	var p2: Player = _w.player
	p2.equip(Weapon.make("bow", Weapon.SUB, 3, "s_twice"))
	_place()
	var d2 := await _dummy(HERO_X + 200.0)
	var n := [0]
	d2.damaged.connect(func(_e: Enemy, _a: float, h: Hit) -> void:
		if h.kind == Hit.Kind.PROJECTILE: n[0] += 1)
	await _frames(1, { "sub": true })
	await _frames(50)
	_ok(n[0] == 2 and not d2.status.has_god_status(), "«Двойное» bow, empty Strike slot: %d hits, no status" % n[0])

func _drop_check() -> void:
	_clear()
	_set_build("perun_s,stribog_d")
	await _frames(2)
	var p: Player = _w.player
	p.equip(Weapon.make("blade"))
	p.equip(Weapon.make("bow", Weapon.SUB, 2))
	_place(HERO_X)
	await _dummy(HERO_X + 420.0)
	var drop := WeaponDrop.new()
	drop.world = _w
	drop.weapon = Weapon.make("flail", Weapon.ARM, 3, "a_perun")
	drop.position = Vector2(HERO_X + 30.0, Tune.f("ground_y"))
	_w.add_child(drop)
	await _frames(20)
	_ok(drop.near, "the hero stands by the drop")
	await _shot("weapon-compare-card.png")
	drop.take()
	_ok(p.weapon.id == "flail" and p.weapon.q == 3 and p.weapon.affix == "a_perun", "E took Громовое · Кистень ★★★")
	_ok(drop.weapon.id == "blade" and drop.weapon.q == 1, "the old Меч-кладенец ★ lies on the same spot")
	drop.take()
	_ok(p.weapon.id == "blade" and drop.weapon.id == "flail" and drop.weapon.affix == "a_perun", "taking again swaps back (AC 11)")
	drop.take()
	var sd := WeaponDrop.new()
	sd.world = _w
	sd.weapon = Weapon.make("navbell", Weapon.SUB, 3, "s_cd")
	sd.position = Vector2(HERO_X - 300.0, Tune.f("ground_y"))
	_w.add_child(sd)
	sd.take()
	_ok(p.sub.id == "navbell" and p.sub_cd == 0.0, "sub swap: Навий колокол in hand, cooldown cleared")
	drop.queue_free()
	sd.queue_free()
	p.sub_cd = 2.0
	await _frames(10)
	await _shot("weapon-hud.png")

## LootRoller from the RunDirector hook path is covered by the unit tests; here a
## seeded run of 40 rolls on a new save just logs what falls (sanity).
func _roll_log() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 2026
	var pity := { "e": 0, "l": 0 }
	var seen: PackedStringArray = []
	for i in 12:
		var d := LootRoller.roll(r, { "tier": 1 + i / 3, "bonus": i % 2, "gods": ["perun"], "owned_arms": { "stick": true }, "held_arm": "stick", "pity": pity },
			{ "weapons": Tune.table("weapons"), "subweapons": Tune.table("subweapons"), "affixes": Tune.table("affixes") }, Tune.data)
		seen.append("%s:%s:q%d:%s" % [d.kind, d.id, d.q, d.affix])
	_note("12 rolls on a new save: %s; pity %s" % [", ".join(seen), pity])

func _run() -> void:
	await _frames(10)
	await _main_check()
	await _mech_probes()
	await _sub_check()
	await _drop_check()
	_roll_log()
	_note("DONE: %d failed checks" % _fails)
	var f := FileAccess.open(out_dir.path_join("weapon-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	get_tree().quit(1 if _fails > 0 else 0)
