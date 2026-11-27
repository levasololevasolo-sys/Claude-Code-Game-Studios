## Утопленник, the living bomb (GDD enemies-and-elites §3.2, §3.4, Edge Case 1-2).
## Drifts at the hero, swells for `fuse` s when close and bursts: the hero in
## `radius` takes `dmg`, other enemies take dmg x enemy_mult with a strong push.
## Killed, it bursts after `death_fuse` s. Bursting on its own gives no reward
## (no `died` signal). Stats: enemies.json "bloat".
class_name Bloat
extends Enemy

## True once the blast went off; the node lives on for the blast flash.
var exploded: bool = false
## Seconds left of the blast flash, then the node is freed.
var blast_t: float = 0.0
## Countdown of the delayed burst after being killed.
var death_t: float = -1.0

func _load_stats() -> void:
	kind_id = "bloat"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos())

func is_winding() -> bool:
	return st == "swell" and not exploded

## One tick: approach -> swell (fuse) -> burst.
func think(dt: float, hp_pos: Vector2) -> void:
	var dx := hp_pos.x - position.x
	face = int(signf(dx)) if dx != 0.0 else 1
	var d := Vector2(hp_pos.x, hp_pos.y - stat("target_dy")) - center()
	var dd := maxf(d.length(), 1.0)
	if st != "swell":
		st = "approach"
		vel = d / dd * stat("speed") + Vector2(0, sin(anim * stat("bob_freq")) * stat("bob"))
		if dd < stat("trigger"):
			st = "swell"
			t = stat("fuse")
	else:
		vel *= pow(stat("swell_damp"), dt * 60.0)
		t -= dt
		if t <= 0.0:
			dead = true
			burst()

## The blast: hurts the hero and every other living enemy in `radius`.
func burst() -> void:
	exploded = true
	blast_t = stat("blast_time")
	vel = Vector2.ZERO
	var at := center()
	var radius := stat("radius")
	var p := hero()
	if p and not p.dead and (p.position - Vector2(0, Player.H / 2.0)).distance_to(at) < radius:
		hurt_hero(stat("dmg"), Hit.Kind.PROJECTILE)
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("enemies"):
			var e := n as Enemy
			if e == null or e == self or e.dead or e.center().distance_to(at) >= radius:
				continue
			var hit := Hit.make(Hit.Kind.PROJECTILE, stat("dmg") * stat("enemy_mult"), at.x, stat("enemy_kb"))
			hit.source = self
			e.hurt(hit)
	if world:
		world.add_shake(stat("blast_shake"))

## Killed: swell for death_fuse, burst, show the flash, then go.
func _dead_tick(dt: float) -> void:
	remove_from_group("enemies")
	if not exploded:
		if death_t < 0.0:
			death_t = stat("death_fuse")
		death_t -= dt
		if death_t <= 0.0:
			burst()
		return
	blast_t -= dt
	if blast_t <= 0.0:
		queue_free()

func _draw() -> void:
	if exploded:
		var k := 1.0 - blast_t / maxf(stat("blast_time"), 0.01)
		var cc := center() - position
		draw_circle(cc, stat("radius") * (0.4 + 0.6 * k), Color(0.83, 0.42, 0.82, 0.45 * (1.0 - k)))
		draw_arc(cc, stat("radius") * k, 0, TAU, 40, Color(1, 0.82, 0.48, 1.0 - k), 5.0)
		return
	_draw_windup_glow()
	var swell := 1.0
	if st == "swell" or death_t >= 0.0:
		var left := t / stat("fuse") if death_t < 0.0 else death_t / stat("death_fuse")
		swell = 1.0 + (1.0 - clampf(left, 0.0, 1.0)) * 0.35 + sin(anim * 40.0) * 0.04
	var r := w / 2.0 * swell
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var cc := center() - position
	draw_circle(cc, r, c)
	draw_circle(cc + Vector2(0, r * 0.3), r * 0.55, c.darkened(0.25))
	if is_winding() or death_t >= 0.0:
		draw_arc(cc, r + 2.0, 0, TAU, 32, Color(1.0, 0.95, 0.8, 0.9), 3.0)
	_draw_eyes(cc + Vector2(-9 + face * 4, -6), cc + Vector2(9 + face * 4, -6), 3.5)
	_draw_overlay()
