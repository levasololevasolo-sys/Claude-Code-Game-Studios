## Сосульник, the ceiling ambusher (GDD bestiary §3.4 card 5, mechanic
## ceiling_drop). Spawned on a `ceiling` spot (chunk marker I): its spawn point is
## the hang point under a platform, it hangs as an upside-down icicle with a
## magenta core. When the hero is in the lane (±40 px) below: it shakes 0.5 s
## (a shadow grows on the floor), then falls at 1200 px/s and hurts whoever is
## under it on landing (the hero ×1.5, enemies too; not parried). Then it stands
## on three needle legs and pokes (poke_wind 0.6 s, 70 px): the poke is parried
## (stun only, no arms). It dies by cracking into 3 shards. Stats: enemies.json "sosulnik".
class_name Sosulnik
extends Enemy

## True while it hangs or shakes (no gravity).
var hanging: bool = true
## Hang point (top of the icicle).
var hang_top: float = 0.0
var _anchored: bool = false
var poked: bool = false
var shatter_t: float = 0.0

func _load_stats() -> void:
	kind_id = "sosulnik"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "shake" or st == "poke_wind"

func contact_damage() -> float:
	return 0.0

## Hangs from its spawn point: the feet (tip) are h below the hang point.
func _anchor() -> void:
	if _anchored:
		return
	_anchored = true
	hang_top = position.y
	position.y = hang_top + h

## While hanging it holds its place; afterwards the usual gravity and floor.
func _move(dt: float) -> void:
	_anchor()
	if hanging:
		vel = Vector2.ZERO
		kb = 0.0
		return
	if st == "fall":
		position.y += stat("fall_speed") * dt
		if position.y >= ground():
			position.y = ground()
			land()
		return
	super._move(dt)

## Landing: hurts the hero and the enemies under it, then stands up.
func land() -> void:
	st = "land"
	t = stat("land")
	vel = Vector2.ZERO
	var zone := Rect2(position.x - stat("fall_hit_x"), position.y - h, stat("fall_hit_x") * 2.0, h)
	var p := hero()
	if p and not p.dead and zone.intersects(SwampRules.hero_rect(p.position)):
		hurt_hero(stat("fall_dmg"), Hit.Kind.PROJECTILE)
	for o in _around(stat("fall_hit_x") + 20.0):
		if o != self and not o.dead and zone.intersects(o.hurt_rect()):
			o.hurt(Hit.make(Hit.Kind.WALL, stat("fall_dmg") * dmg_mult(), position.x, 0.0))
	Audio.play_at(&"ice_shatter", position, -1, 1.3)
	if world:
		world.add_shake(7.0)

## One tick: hang -> shake -> fall -> land -> walk / poke_wind -> poke -> recover.
func think(dt: float, hp_pos: Vector2) -> void:
	_anchor()
	t -= dt
	cd -= dt
	var dx := hp_pos.x - position.x
	match st:
		"idle", "hang":
			st = "hang"
			if FrostRules.under_lane(Vector2(position.x, position.y), hp_pos, stat("lane")):
				st = "shake"
				t = stat("shake")
		"shake":
			if t <= 0.0:
				st = "fall"
				hanging = false
		"fall":
			pass
		"land":
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max") * 0.5
		"poke_wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "poke"
				t = stat("poke_time")
				poked = false
		"poke":
			vel.x = 0.0
			if not poked and SwampRules.swing_hits(position, face, w, stat("reach"), h * 0.7, hp_pos):
				poked = true
				hurt_hero(stat("poke_dmg"), Hit.Kind.CONTACT)
			if st == "poke" and t <= 0.0:
				st = "recover"
				t = stat("recover")
		"recover":
			vel.x = 0.0
			if t <= 0.0:
				st = "walk"
				cd = _stat_range("cd_min", "cd_max")
		_:
			st = "walk"
			face = int(signf(dx)) if dx != 0.0 else face
			vel.x = face * stat("speed") if absf(dx) > stat("poke_range") * 0.6 else 0.0
			if cd <= 0.0 and SwampRules.in_reach(dx, hp_pos.y - position.y, stat("poke_range"), stat("range_y")):
				st = "poke_wind"
				t = stat("poke_wind")
				vel.x = 0.0

## Cracks into three shards, then is removed.
func _dead_tick(dt: float) -> void:
	if shatter_t == 0.0:
		hanging = false
	shatter_t += dt
	if shatter_t >= stat("shatter_time"):
		super._dead_tick(dt)

func _draw() -> void:
	_draw_windup_glow()
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var shade := Color(String(stats.shade))
	var core := Color(String(stats.core))
	var outline := Color("#2c3b52")
	if dead and art_skin:
		_draw_overlay()
		return
	if dead:
		var k := clampf(shatter_t / maxf(stat("shatter_time"), 0.01), 0.0, 1.0)
		for i in 3:
			var a := -PI / 2.0 + (i - 1) * 0.9
			var off := Vector2(cos(a), sin(a)) * 60.0 * k + Vector2(0, 120.0 * k * k)
			var base := Vector2(0, -h * 0.4) + off
			draw_colored_polygon(PackedVector2Array([base + Vector2(-7, -10), base + Vector2(7, -10), base + Vector2(0, 16)]), Color(c, 1.0 - k))
		return
	if st == "shake":
		# Shadow on the floor under it grows during the shake.
		var gy := ground() - position.y
		var r := FrostRules.shadow_r(t, stat("shake"), stat("shadow_r0"), stat("shadow_r1"))
		draw_set_transform(Vector2(0, gy), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, r, Color(0.05, 0.08, 0.15, 0.55))
		draw_circle(Vector2.ZERO, r * 0.6, Color(0.05, 0.08, 0.15, 0.5))
		draw_set_transform(Vector2.ZERO)
	elif hanging:
		var gy2 := ground() - position.y
		draw_set_transform(Vector2(0, gy2), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, stat("shadow_r0"), Color(0.05, 0.08, 0.15, 0.3))
		draw_set_transform(Vector2.ZERO)
	if art_skin:
		_draw_overlay()
		return
	var jit := Vector2(sin(anim * 70.0) * 3.0, 0) if st == "shake" else Vector2.ZERO
	if hanging or st == "fall":
		# Upside-down icicle triangle with the core.
		var tri := PackedVector2Array([Vector2(-w * 0.6, -h) + jit, Vector2(w * 0.6, -h) + jit, Vector2(0, 0) + jit])
		draw_colored_polygon(tri, outline)
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.5, -h + 3) + jit, Vector2(w * 0.5, -h + 3) + jit, Vector2(0, -5) + jit]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.5, -h + 3) + jit, Vector2(-w * 0.1, -h + 3) + jit, Vector2(0, -5) + jit]), shade)
		draw_circle(Vector2(0, -h * 0.68) + jit, 7.0, core)
		_draw_glow(Vector2(0, -h * 0.68) + jit, 16.0 if st != "shake" else 26.0, core, 0.8)
		if st == "shake":
			for i in 3:
				var sx := (i - 1) * 9.0
				draw_line(Vector2(sx, -h - 6), Vector2(sx + 3, -h - 14), Color.WHITE, 2.0)
		_draw_windup_outline(tri)
		_draw_eyes(Vector2(-5, -h * 0.8) + jit, Vector2(5, -h * 0.8) + jit, 2.2, 1.0)
		_draw_overlay()
		return
	# Standing: a triangle on three needle legs.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var legs := h * 0.3
	for i in 3:
		var lx := (i - 1) * w * 0.35
		var sw := sin(anim * 12.0 + i * 2.0) * 3.0 if absf(vel.x) > 1.0 else 0.0
		draw_line(Vector2(lx * 0.5, -legs), Vector2(lx + sw, 0), outline, 4.0)
		draw_line(Vector2(lx * 0.5, -legs), Vector2(lx + sw, 0), shade, 2.0)
	var lean := 10.0 if st == "poke" else (-6.0 if st == "poke_wind" else 0.0)
	var body := PackedVector2Array([Vector2(-w * 0.5, -legs), Vector2(w * 0.5, -legs), Vector2(lean, -h)])
	draw_colored_polygon(body, outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.4, -legs - 2), Vector2(w * 0.4, -legs - 2), Vector2(lean, -h + 6)]), c)
	draw_circle(Vector2(lean * 0.4, -h * 0.55), 6.0, core)
	if st == "poke_wind" or st == "poke":
		var tip := Vector2(w * 0.5 + (stat("reach") if st == "poke" else 10.0), -h * 0.45)
		draw_line(Vector2(w * 0.2, -h * 0.5), tip, outline, 5.0)
		draw_line(Vector2(w * 0.2, -h * 0.5), tip, Color.WHITE, 3.0)
		if st == "poke_wind":
			_draw_glow(tip, 18.0, core, 0.9)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(lean * 0.3 - 4, -h * 0.7), Vector2(lean * 0.3 + 4, -h * 0.7), 2.4, face)
	_draw_overlay()
