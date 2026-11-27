## Scripted Flare check (GDD amulet-and-flare §3.3-3.5, §3.9, AC 7, 9-12, 15-16).
## For each amulet shape: clears the room, sets targets around the hero, charges
## the amulet to 100 with real blade strikes on a straw dummy, presses `flare`,
## checks the breath (world slowed, hero invulnerable), logs every enemy the shape
## hit (damage, stun, launch, pull) and saves <out_dir>/flare-<shape>.png at the
## burst. Then a dark room at 0% charge with all four enemy kinds, a crawler
## wind-up 600 px away and a shot in flight: flare-dark-0.png (and -ash with the
## Ash level "Навь темнее"). Started by world.gd with `-- --flare-check=<dir>`.
extends Node

## Hero x for every case.
const HERO_X: float = 1200.0
## Targets per shape: kind, dx from the hero, height above the floor.
const CASES: Dictionary = {
	"ring": [["dummy", 400.0, 0.0], ["dummy", -520.0, 0.0], ["bat", 150.0, 260.0]],
	"beam": [["dummy", 900.0, 0.0], ["dummy", -50.0, 0.0], ["sentry", 600.0, 0.0], ["bat", 300.0, 200.0]],
	"wave": [["dummy", -700.0, 0.0], ["crawler", 500.0, 0.0], ["bat", 200.0, 200.0]],
	"knot": [["dummy", 250.0, 0.0], ["dummy", -330.0, 0.0], ["dummy", -600.0, 0.0]],
}
## The dummy the hero strikes to charge the amulet, px in front of him.
const STRIKE_DX: float = 60.0
const MAX_SWINGS: int = 40

var out_dir: String = "user://flare_check"
var log_lines: PackedStringArray = []
var _main: World

func _ready() -> void:
	_main = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	log_lines.append(s)
	print("[flare-check] ", s)

func _frames(n: int, keys: Dictionary = {}) -> void:
	var p: Player = _main.player
	p.scripted = true
	for i in n:
		p.fake = keys
		await p.stepped
	p.fake = {}

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	_note("screenshot %s" % file)

func _clear() -> void:
	for n in _main.get_children():
		if n is Enemy or n is EnemyShot or n is Flare:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()

func _spawn(kind: String, dx: float, up: float, asleep: bool) -> Enemy:
	var e: Enemy = StrawDummy.new() if kind == "dummy" else EnemyRoster.make(kind)
	return _main.spawn_enemy(e, Vector2(HERO_X + dx, Tune.f("ground_y") - up), -1, asleep, 3)

func _place_hero() -> void:
	var p: Player = _main.player
	p.position = Vector2(HERO_X, Tune.f("ground_y"))
	p.velocity = Vector2.ZERO
	p.face = 1
	p.hp = 1000.0
	p.inv = 0.0
	_main.cam.reset_smoothing()

func _run() -> void:
	var p: Player = _main.player
	var summary: PackedStringArray = []
	for shape: String in CASES:
		_clear()
		await _frames(2)
		p.amulet = Amulet.make(shape, Tune.data)
		_main.amulet_hud.amulet = p.amulet
		_place_hero()
		var striker := _spawn("dummy", STRIKE_DX, 0.0, false)
		var targets: Array[Enemy] = [striker]
		var labels: Array[String] = ["dummy@+%d" % STRIKE_DX]
		for c: Array in CASES[shape]:
			targets.append(_spawn(String(c[0]), float(c[1]), float(c[2]), true))
			labels.append("%s@%+d%s" % [c[0], int(c[1]), (" up%d" % int(c[2])) if float(c[2]) > 0.0 else ""])
		# Real enemies hold still (no AI) until the Flare: the check is about the
		# shape, not about the fight; they still take hits and statuses.
		for e in targets:
			if not e is StrawDummy:
				e.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(10)
		# 1. Charge to 100 with real strikes.
		var swings := 0
		while p.amulet.charge < p.amulet.ready_at() and swings < MAX_SWINGS:
			striker.position.x = HERO_X + STRIKE_DX
			striker.kb = 0.0
			p.position.x = HERO_X
			p.face = 1
			await _frames(1, { "strike": true })
			await _frames(22)
			swings += 1
		striker.position.x = HERO_X + STRIKE_DX
		striker.kb = 0.0
		_place_hero()
		await _frames(3)
		var before: Array = []
		for e in targets:
			before.append([e.position, e.hp])
		var c_press := p.amulet.charge
		var got: Array = [null]
		var struck: Dictionary = {}
		var on_rel := func(f: Flare) -> void:
			got[0] = f
			f.struck.connect(func(e: Enemy, dealt: float, hit: Hit) -> void:
				struck[e] = [dealt, hit.stun, e.stun])
		p.flare_released.connect(on_rel)
		# 2. Press: breath starts, world slowed, hero invulnerable.
		await _frames(1, { "flare": true })
		var wait := 0
		while p.flare_t <= 0.0 and wait < 10:
			await _frames(1)
			wait += 1
		var probe := Hit.make(Hit.Kind.CONTACT, 10.0, p.position.x + 10.0, 0.0)
		var hp0 := p.hp
		var took := p.hurt(probe)
		_note("%s: %d swings -> charge %.0f; press: breath t=%.3f world x%.2f, probe hit took %.0f (hp %.0f -> %.0f), charge after press %.0f" % [
			shape, swings, c_press, p.flare_t, _main.time_mult(), took, hp0, p.hp, p.amulet.charge])
		var ticks := 0
		while got[0] == null and ticks < 30:
			await _frames(1)
			ticks += 1
		var f: Flare = got[0]
		p.flare_released.disconnect(on_rel)
		for e in targets:
			if is_instance_valid(e):
				e.process_mode = Node.PROCESS_MODE_INHERIT
		_note("%s: released after %d ticks (press delayed %d by hitstop), P=%.2f S=%.2f D=%.1f, hero inv %.2f" % [shape, ticks + 1, wait, f.power, f.size, f.dmg, p.inv])
		# 3. Screenshot at the burst.
		match shape:
			"ring", "beam":
				await _frames(3)
			"wave":
				await _frames(18)
			"knot":
				var k := 0
				while is_instance_valid(f) and f.knot_state != "boom" and k < 400:
					await _frames(1)
					k += 1
				_note("knot: boom after %d ticks (armed at %.2f s, trigger %.0f px)" % [k, f.row.get("arm", 0.0), f.row.get("trigger", 0.0)])
				await _frames(2)
		await _shot("flare-%s.png" % shape)
		var w2 := 0
		while is_instance_valid(f) and w2 < 120:
			await _frames(1)
			w2 += 1
		await _frames(10)
		var hit_n := 0
		var stun_n := 0
		for i in targets.size():
			var e := targets[i]
			var line := "  %-16s" % labels[i]
			if not is_instance_valid(e):
				hit_n += 1
				var dv: Array = struck.get(e, [0.0, 0.0, 0.0])
				_note(line + " HIT dealt %.1f stun %.2f -> KILLED (hp was %.0f)" % [dv[0], dv[1], before[i][1]])
				continue
			if struck.has(e):
				hit_n += 1
				var sv: Array = struck[e]
				if float(sv[2]) > 0.0:
					stun_n += 1
				line += " HIT dealt %.1f stun %.2f" % [sv[0], sv[2]]
			else:
				line += " not hit"
			var p0: Vector2 = before[i][0]
			line += "  moved (%+.0f, %+.0f) now y %.0f vy %.0f" % [e.position.x - p0.x, e.position.y - p0.y, e.position.y, e.vel.y]
			_note(line)
		_note("%s: enemies hit %d, stunned %d, charge after %.0f" % [shape, hit_n, stun_n, p.amulet.charge])
		summary.append("%s=%d/%d" % [shape, hit_n, stun_n])
		await _frames(60)
	# 4. Dark room at 0%.
	_clear()
	await _frames(2)
	p.amulet = Amulet.make("ring", Tune.data)
	_main.amulet_hud.amulet = p.amulet
	_place_hero()
	var crawler := _spawn("crawler", 600.0, 0.0, false)
	var sentry := _spawn("sentry", -520.0, 0.0, false)
	var bat := _spawn("bat", 260.0, 270.0, false)
	var bloat := _spawn("bloat", -300.0, 200.0, false)
	sentry.face = 1
	await _frames(20)
	crawler.position.x = HERO_X + 600.0
	crawler.st = "wind"
	crawler.t = 0.5
	crawler.vel = Vector2.ZERO
	var shot := sentry.fire(sentry.position + Vector2(18, -58), Vector2(310, 0), 11.0, 0.0, 4.0)
	shot.position.x = HERO_X - 220.0
	await _frames(6)
	await RenderingServer.frame_post_draw
	var d := _main.darkness
	_note("dark: charge %.0f, light radius %.0f (light_min %.0f), darkness %.2f, glow spots %d, crawler state %s at dx %+.0f, shot at dx %+.0f" % [
		p.amulet.charge, d.light_r, AmuletRules.light_min(Tune.data), d.dk, d.spot_count, crawler.st,
		crawler.position.x - p.position.x, shot.position.x - p.position.x if is_instance_valid(shot) else NAN])
	await _shot("flare-dark-0.png")
	d.ash_level = 1
	crawler.st = "wind"
	crawler.t = 0.5
	await _frames(2)
	await RenderingServer.frame_post_draw
	_note("dark+ash: darkness %.2f, crawler %s" % [d.dk, crawler.st])
	await _shot("flare-dark-0-ash.png")
	_note("summary hit/stunned: " + " ".join(summary) + " (bat/bloat: %s %s)" % [bat.st, bloat.st])
	var file := FileAccess.open(out_dir.path_join("flare-check-log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines) + "\n")
	file.close()
	get_tree().quit()
