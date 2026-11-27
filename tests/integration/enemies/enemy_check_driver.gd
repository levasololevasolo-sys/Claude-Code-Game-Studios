## Scripted enemy check (code task 3): for each of the four kinds, clears the
## room, puts one sleeping enemy near a standing hero, lets it wake and act for
## up to `MAX_TICKS`, logs the hero's damage taken from that enemy (contact,
## bash, shot or blast) and saves one screenshot during its wind-up to
## <out_dir>/enemy-<kind>.png. The bloat gets a dummy next to the hero to show
## that its blast hurts enemies too. Started by world.gd with
## `-- --enemy-check=<dir>`; quits when done.
extends Node

## Kinds and where each spawns relative to the hero (x, height above the floor).
const CASES: Array[Dictionary] = [
	{ "kind": "crawler", "dx": 330.0, "up": 0.0 },
	{ "kind": "bat", "dx": 240.0, "up": 260.0 },
	{ "kind": "sentry", "dx": 360.0, "up": 0.0 },
	{ "kind": "bloat", "dx": 300.0, "up": 180.0 },
]
## Ticks per kind before giving up (8 s at 60 Hz).
const MAX_TICKS: int = 480
## Ticks into the wind-up when the screenshot is taken.
const SHOT_AT_WIND_TICK: int = 14
## Hero x for every case (open floor of the room).
const HERO_X: float = 700.0

var out_dir: String = "user://enemy_check"
var log_lines: PackedStringArray = []
var _main: World

func _ready() -> void:
	_main = get_parent() as World
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _note(s: String) -> void:
	log_lines.append(s)
	print("[enemy-check] ", s)

func _tick() -> void:
	var p: Player = _main.player
	p.scripted = true
	p.fake = {}
	await p.stepped

func _clear() -> void:
	for n in _main.get_children():
		if n is Enemy or n is EnemyShot:
			if n is Enemy:
				n.remove_from_group("enemies")
			n.queue_free()

func _run() -> void:
	var p: Player = _main.player
	_clear()
	await _tick()
	var summary: PackedStringArray = []
	for c: Dictionary in CASES:
		_clear()
		await _tick()
		var g := Tune.f("ground_y")
		p.position = Vector2(HERO_X, g)
		p.velocity = Vector2.ZERO
		p.hp = 1000.0
		p.inv = 0.0
		p.face = 1
		var e := _main.spawn_enemy(EnemyRoster.make(c.kind), Vector2(HERO_X + float(c.dx), g - float(c.up)), 0, true, 7)
		e.show_state = true
		var dummy: Enemy = null
		var dummy_took := [0.0]
		if c.kind == "bloat":
			dummy = _main.spawn_enemy(StrawDummy.new(), Vector2(HERO_X + 70.0, g), -1, false, 1)
			dummy.damaged.connect(func(_e: Enemy, amount: float, hit: Hit) -> void:
				if hit.source == e:
					dummy_took[0] += amount)
		var took: Array[float] = []
		var kinds: Array[String] = []
		var on_hurt := func(amount: float, hit: Hit) -> void:
			if hit.source == e:
				took.append(amount)
				kinds.append(Hit.Kind.keys()[hit.kind])
		p.hurt_taken.connect(on_hurt)
		var woke_at := -1
		var wind_ticks := 0
		var shot_taken := false
		var states: PackedStringArray = []
		for i in MAX_TICKS:
			await _tick()
			if not is_instance_valid(e):
				break
			if woke_at < 0 and not e.asleep:
				woke_at = i
			if states.is_empty() or states[states.size() - 1] != e.st:
				states.append(e.st)
			wind_ticks = wind_ticks + 1 if e.is_winding() else 0
			if not shot_taken and wind_ticks == SHOT_AT_WIND_TICK:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("enemy-%s.png" % c.kind))
				shot_taken = true
				_note("%s: screenshot in state '%s' (t=%.2f)" % [c.kind, e.st, e.t])
			if not took.is_empty() and shot_taken and (c.kind != "bloat" or not is_instance_valid(e) or (e as Bloat).exploded):
				break
		p.hurt_taken.disconnect(on_hurt)
		_note("%s: woke at tick %d, states %s, hero hits %d %s kinds %s, hero hp %.0f%s" % [
			c.kind, woke_at, " > ".join(states), took.size(), str(took), str(kinds), p.hp,
			(", dummy took %.0f from the blast" % dummy_took[0]) if dummy else ""])
		summary.append("%s=%s" % [c.kind, "DAMAGED" if not took.is_empty() else "NO_DAMAGE"])
		for k in 40:
			await _tick()
	_note("summary: " + " ".join(summary))
	var f := FileAccess.open(out_dir.path_join("enemy-check-log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	f.close()
	get_tree().quit()
