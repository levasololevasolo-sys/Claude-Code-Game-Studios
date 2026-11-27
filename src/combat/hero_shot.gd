## Things the hero's secondary weapons put into the world (GDD weapons-and-loot
## §3.4): flying shots (bow, javelin, sling, crossbow), the powder pot (arc, then
## a blast), returning axes, the bear trap, the spike strip and the shooter idol.
## Every hit goes through Player.sub_hit() (damage + Strike-slot god status).
## Numbers come from the weapon's subweapons.json row. Placeholder look.
class_name HeroShot
extends Node2D

var hero: Player
var weapon: Weapon
## shot | bomb | axe | trap | spikes | totem
var mode: String = "shot"
var vel: Vector2 = Vector2.ZERO
var gravity: float = 0.0
var r: float = 8.0
var life: float = 1.0
var age: float = 0.0
var face: int = 1
## Enemies already hit (per flight; the axe clears it when it turns back).
var hit_set: Array[Enemy] = []
## Enemies that already got the status from this placement (spikes, §5 p.10).
var status_set: Array[Enemy] = []
var _tick_t: float = 0.0
var _turned: bool = false
var _done: bool = false

func _row() -> Dictionary:
	return weapon.row()

func _physics_process(dt: float) -> void:
	if hero == null or not is_instance_valid(hero):
		queue_free()
		return
	var w := hero.world
	if w and w.hitstop > 0.0:
		return
	if w:
		dt *= w.time_mult()
	age += dt
	life -= dt
	match mode:
		"shot", "axe":
			_fly(dt)
		"bomb":
			_bomb(dt)
		"trap":
			_trap()
		"spikes":
			_spikes(dt)
		"totem":
			_totem(dt)
	if life <= 0.0 and not _done:
		_done = true
		if mode == "bomb":
			_blast()
		queue_free()
	queue_redraw()

func _enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and not e.dead:
			out.append(e)
	return out

func _fly(dt: float) -> void:
	if mode == "axe" and not _turned and age >= float(_row().get("out", 0.4)):
		_turned = true
		hit_set.clear()
	if mode == "axe" and _turned:
		var to := hero.position - Vector2(0, Player.H / 2.0) - position
		vel = to.normalized() * float(_row().get("speed", 800))
		if to.length() < 24.0:
			life = 0.0
	vel.y += gravity * dt
	position += vel * dt
	var room_w := float(hero.world.room.layout.w) if hero.world and hero.world.room else 1.0e9
	if position.x < 0.0 or position.x > room_w or position.y > Tune.f("ground_y"):
		life = 0.0
		return
	for e in _enemies():
		if e in hit_set or not e.hurt_rect().grow(r).has_point(position):
			continue
		hit_set.append(e)
		var row := _row()
		hero.sub_hit(e, weapon.sub_dmg(), position.x - signf(vel.x), Tune.f("knockback") * float(row.get("kb_k", 0.5)),
			float(row.get("stun", 0.0)))
		if mode == "shot" and not bool(row.get("pierce", false)):
			life = 0.0
			return

func _bomb(dt: float) -> void:
	vel.y += gravity * dt
	position += vel * dt
	if position.y >= Tune.f("ground_y"):
		position.y = Tune.f("ground_y")
		life = 0.0
		return
	for e in _enemies():
		if e.hurt_rect().grow(r).has_point(position):
			life = 0.0
			return

func _blast() -> void:
	var br := float(_row().get("blast_r", 110))
	if hero.world:
		hero.world.add_ring(position, br)
		hero.world.add_shake(Tune.f("shake_finisher"))
	for e in _enemies():
		if e.center().distance_to(position) <= br + e.w / 2.0:
			hero.sub_hit(e, weapon.sub_dmg(), position.x, Tune.f("knockback"), 0.0)

func _trap() -> void:
	for e in _enemies():
		if e.flies or not e.hurt_rect().grow(4.0).intersects(Rect2(position.x - r, position.y - 10.0, r * 2.0, 10.0)):
			continue
		hero.sub_hit(e, weapon.sub_dmg(), e.position.x, 0.0, float(_row().get("hold", 1.5)))
		e.kb = 0.0
		life = 0.0
		return

func _spikes(dt: float) -> void:
	_tick_t -= dt
	if _tick_t > 0.0:
		return
	_tick_t = float(_row().get("tick", 0.5))
	var length := float(_row().get("len", 260))
	var strip := Rect2(position.x - length / 2.0, position.y - 16.0, length, 16.0)
	for e in _enemies():
		if e.flies or not e.hurt_rect().intersects(strip):
			continue
		var first := not e in status_set
		if first:
			status_set.append(e)
		hero.sub_hit(e, weapon.sub_dmg(), e.position.x, 0.0, 0.0, first)

func _totem(dt: float) -> void:
	_tick_t -= dt
	if _tick_t > 0.0:
		return
	var best: Enemy = null
	var rng := float(_row().get("range", 520))
	var eye := position - Vector2(0, 50)
	for e in _enemies():
		var d := e.center().distance_to(eye)
		if d <= rng and (best == null or d < best.center().distance_to(eye)):
			best = e
	if best == null:
		return
	_tick_t = float(_row().get("every", 0.6))
	var s := HeroShot.new()
	s.hero = hero
	s.weapon = weapon
	s.mode = "shot"
	s.r = 6.0
	s.life = 1.0
	s.position = eye
	s.vel = (best.center() - eye).normalized() * float(_row().get("speed", 900))
	get_parent().add_child(s)

func _draw() -> void:
	var c := Color("#e8dcc0")
	match mode:
		"shot":
			var d := vel.normalized() if vel.length() > 0.0 else Vector2(face, 0)
			draw_line(-d * (r * 3.0), d * r, c, 3.0)
			draw_circle(d * r, r * 0.5, Color.WHITE)
		"axe":
			draw_set_transform(Vector2.ZERO, age * 18.0, Vector2.ONE)
			draw_line(Vector2(-r, 0), Vector2(r, 0), Color("#6b4a2b"), 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(r * 0.3, -r), Vector2(r, -r * 0.2), Vector2(r * 0.3, r * 0.3)]), c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bomb":
			draw_circle(Vector2.ZERO, r, Color("#5b4026"))
			draw_circle(Vector2(0, -r), 3.0, Color("#ffb347"))
		"trap":
			draw_line(Vector2(-r, -2), Vector2(r, -2), Color("#9aa3a8"), 4.0)
			for i in 5:
				var x := -r + i * r / 2.0
				draw_line(Vector2(x, -2), Vector2(x, -12), Color("#c8d0d4"), 2.0)
		"spikes":
			var length := float(_row().get("len", 260))
			for i in int(length / 20.0) + 1:
				var x := -length / 2.0 + i * 20.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 0), Vector2(x, -18), Vector2(x + 6, 0)]), Color("#b09a70"))
		"totem":
			draw_rect(Rect2(-12, -70, 24, 70), Color("#7a5a36"))
			draw_circle(Vector2(0, -50), 7.0, Color("#ffd27a"))
