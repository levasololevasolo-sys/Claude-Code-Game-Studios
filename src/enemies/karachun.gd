## Карачун, the frost bruiser (GDD bestiary §3.4 card 3, mechanic ground_wave).
## An old snowdrift with a staff: walks slowly (60 px/s); in range it raises the
## staff (slam_wind 0.9 s, rime gathers on the knob in magenta, the floor lanes
## glow) and strikes the floor: an IceWave of spikes runs both ways (only forward
## once the staff arm is cut, wind ×1.3). Close in (110 px) it pokes with the
## staff (poke_wind 0.5 s): the poke is parried and the parry takes the staff arm
## (limb_zones.json "karachun", tough: several parries). Stats: enemies.json "karachun".
class_name Karachun
extends Enemy

## True once the current poke has hit.
var poked: bool = false
## Waves sent by the last slam (checks and tests read them).
var last_waves: Array[IceWave] = []
var slam_cd: float = 0.0

func _load_stats() -> void:
	kind_id = "karachun"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "slam_wind" or st == "poke_wind"

func contact_damage() -> float:
	return 0.0

## Ice walls standing on the floor as Vector2(x_left, x_right) spans.
func floor_walls() -> Array:
	var out: Array = []
	if world and world.room:
		var g := ground()
		for r: Rect2 in world.room.layout.get("solids", []):
			if r.end.y >= g - 2.0 and r.position.y < g - 10.0:
				out.append(Vector2(r.position.x, r.end.x))
	return out

## Sends the spikes (both ways, or forward only without the staff arm).
func slam() -> Array[IceWave]:
	var out: Array[IceWave] = []
	var lo := 0.0
	var hi := room_w if room_w > 0.0 else 1.0e6
	for d: int in FrostRules.wave_dirs(face, int(roundf(stat("wave_dirs")))):
		var wv := IceWave.new()
		wv.x0 = position.x + d * w * 0.4
		wv.dir = d
		wv.speed = stat("wave_speed")
		wv.end = FrostRules.wave_end(wv.x0, d, stat("wave_dist"), lo, hi, floor_walls())
		wv.spike_h = stat("wave_h")
		wv.half = stat("wave_half")
		wv.dmg = stat("wave_dmg") * dmg_mult()
		wv.linger = stat("wave_linger")
		wv.world = world
		wv.target = target
		wv.position = Vector2(wv.x0, ground())
		if world:
			world.add_child(wv)
		out.append(wv)
	Audio.play_at(&"ice_wave", position)
	if world:
		world.add_shake(6.0)
	last_waves = out
	return out

## One tick: walk -> slam_wind -> slam -> recover, or poke_wind -> poke -> recover.
func think(dt: float, hp_pos: Vector2) -> void:
	t -= dt
	cd -= dt
	slam_cd -= dt
	var dx := hp_pos.x - position.x
	var dy := hp_pos.y - position.y
	match st:
		"slam_wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "slam"
				t = stat("slam_time")
				slam()
		"slam":
			vel.x = 0.0
			if t <= 0.0:
				st = "recover"
				t = stat("slam_recover")
				slam_cd = stat("slam_cd")
		"poke_wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "poke"
				t = stat("poke_time")
				poked = false
		"poke":
			vel.x = 0.0
			if not poked and SwampRules.swing_hits(position, face, w, stat("poke_reach"), h * 0.8, hp_pos):
				poked = true
				hurt_hero(stat("poke_dmg"), Hit.Kind.CONTACT)
			if st == "poke" and t <= 0.0:
				st = "recover"
				t = stat("poke_recover")
		"recover":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")
		_:
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed") if absf(dx) > stat("poke_range") * 0.7 else 0.0
			if cd <= 0.0 and SwampRules.in_reach(dx, dy, stat("poke_range"), stat("range_y")):
				st = "poke_wind"
				t = stat("poke_wind")
				vel.x = 0.0
			elif cd <= 0.0 and slam_cd <= 0.0 and SwampRules.in_reach(dx, dy, stat("slam_range"), stat("range_y")):
				st = "slam_wind"
				t = stat("slam_wind")
				vel.x = 0.0

func _draw() -> void:
	_draw_windup_glow()
	var g := ground() - position.y
	if st == "slam_wind":
		# Telegraph: the lanes the spikes will run along glow on the floor.
		var k := clampf(1.0 - t / maxf(stat("slam_wind"), 0.01), 0.0, 1.0)
		var lane := Color("#a3206f")
		for d: int in FrostRules.wave_dirs(face, int(roundf(stat("wave_dirs")))):
			var len := stat("wave_dist") * (0.3 + 0.7 * k)
			var x1 := d * w * 0.4
			draw_rect(Rect2(minf(x1, x1 + d * len), g - 18.0, len, 18.0), Color(lane, 0.12 + 0.25 * k), true)
			draw_rect(Rect2(minf(x1, x1 + d * len), g - 7.0, len, 7.0), Color(lane, 0.45 + 0.4 * k), true)
			draw_rect(Rect2(minf(x1, x1 + d * len), g - 3.0, len, 3.0), Color("#8fd3f5"), true)
			for i in 10:
				var sx := x1 + d * len * (i + 1) / 10.0
				draw_colored_polygon(PackedVector2Array([Vector2(sx - 7, g), Vector2(sx, g - 8.0 - 18.0 * k), Vector2(sx + 7, g)]), Color(lane, 0.9))
				draw_line(Vector2(sx, g - 4.0), Vector2(sx, g - 6.0 - 14.0 * k), Color("#8fd3f5"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var shade := Color(String(stats.shade))
	var outline := Color("#2c3b52")
	# Wide snowdrift triangle.
	var body := PackedVector2Array([Vector2(-w * 0.6, 0), Vector2(-w * 0.05, -h * 0.82), Vector2(w * 0.1, -h * 0.82), Vector2(w * 0.6, 0)])
	draw_colored_polygon(body, outline)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(p * 0.93 + Vector2(0, -2))
	draw_colored_polygon(inner, c)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.52, -3), Vector2(-w * 0.05, -h * 0.74), Vector2(-w * 0.15, -3)]), shade)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, outline, 3.0)
	# Small head with an icicle beard.
	if not head_off:
		draw_circle(Vector2(w * 0.05, -h * 0.88), 13.0, outline)
		draw_circle(Vector2(w * 0.05, -h * 0.88), 11.0, c)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -h * 0.84), Vector2(w * 0.05, -h * 0.84), Vector2(-2, -h * 0.84 + 26)]), Color(String(stats.beard)))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.05, -h * 0.84), Vector2(18, -h * 0.84), Vector2(10, -h * 0.84 + 20)]), Color(String(stats.beard)))
		# Snow cap: a sharp cone.
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -h * 0.92), Vector2(w * 0.05, -h * 1.1), Vector2(16, -h * 0.92)]), shade)
	# The staff, taller than the hero.
	var staff := Color(String(stats.staff))
	var hand := Vector2(w * 0.4, -h * 0.55)
	var top := hand + Vector2(4, -h * 0.7)
	var bot := hand + Vector2(-2, h * 0.5)
	if st == "slam_wind":
		var k2 := clampf(1.0 - t / maxf(stat("slam_wind"), 0.01), 0.0, 1.0)
		hand = Vector2(w * 0.3, -h * (0.85 + 0.25 * k2))
		top = hand + Vector2(6, -h * 0.75)
		bot = hand + Vector2(-2, h * 0.55)
	elif st == "slam":
		hand = Vector2(w * 0.55, -h * 0.4)
		top = hand + Vector2(10, -h * 0.75)
		bot = Vector2(w * 0.6, 0)
	elif st == "poke_wind":
		hand = Vector2(w * 0.2, -h * 0.5)
		top = hand + Vector2(-h * 0.5, -10)
		bot = hand + Vector2(h * 0.6, 6)
	elif st == "poke":
		hand = Vector2(w * 0.55, -h * 0.5)
		bot = hand + Vector2(stat("poke_reach") + 10, 4)
		top = hand + Vector2(-h * 0.5, -8)
	if not arm_off:
		draw_line(Vector2(w * 0.15, -h * 0.6), hand, outline, 10.0)
		draw_line(Vector2(w * 0.15, -h * 0.6), hand, shade, 7.0)
		draw_line(top, bot, outline, 9.0)
		draw_line(top, bot, staff, 6.0)
		var knob := top if st != "poke_wind" and st != "poke" else bot
		draw_circle(knob, 9.0, Color("#8fd3f5"))
		if st == "slam_wind" or st == "poke_wind":
			var k3 := clampf(1.0 - t / maxf(stat(st), 0.01), 0.0, 1.0)
			_draw_glow(knob, 22.0 + 18.0 * k3, Color(String(stats.rime)), 0.95)
			draw_circle(knob, 5.0 + 6.0 * k3, Color(String(stats.rime)))
	else:
		draw_line(Vector2(w * 0.15, -h * 0.6), Vector2(w * 0.25, -h * 0.5), shade.darkened(0.3), 8.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(w * 0.0, -h * 0.9), Vector2(w * 0.12, -h * 0.9), 3.0 if is_winding() else 2.2, face)
	_draw_overlay()
