## Fires the hero's secondary weapon (GDD weapons-and-loot §3.4). Instant kinds
## (chain lightning, gust, bell ring) hit here; the rest spawn a HeroShot. Each
## hit goes through Player.sub_hit(). Static: no state of its own.
class_name SubWeapons
extends RefCounted

## Fires `w` from `hero` once. Returns the number of things made / enemies hit.
static func fire(hero: Player, w: Weapon) -> int:
	var row := w.row()
	var at := hero.position - Vector2(0, Player.H * 0.55)
	match String(row.get("type", "shot")):
		"shot":
			_spawn(hero, w, "shot", at, Vector2(hero.face * float(row.get("speed", 1000)), 0.0), float(row.get("r", 8)), float(row.get("life", 1.0)))
			return 1
		"bomb":
			var b := _spawn(hero, w, "bomb", at, Vector2(hero.face * float(row.get("speed", 520)), -float(row.get("up", 560))), float(row.get("r", 10)), float(row.get("life", 2.0)))
			b.gravity = float(row.get("gravity", 1600))
			return 1
		"axes":
			var n := int(row.get("count", 2))
			for i in n:
				var dy := (i - (n - 1) / 2.0) * float(row.get("spread", 40))
				_spawn(hero, w, "axe", at + Vector2(0, dy * 0.3), Vector2(hero.face * float(row.get("speed", 820)), dy), float(row.get("r", 12)), float(row.get("life", 1.4)))
			return n
		"trap":
			_spawn(hero, w, "trap", Vector2(hero.position.x + hero.face * float(row.get("ahead", 50)), Tune.f("ground_y")), Vector2.ZERO, float(row.get("w", 44)) / 2.0, float(row.get("life", 12)))
			return 1
		"spikes":
			_spawn(hero, w, "spikes", Vector2(hero.position.x + hero.face * float(row.get("len", 260)) / 2.0, Tune.f("ground_y")), Vector2.ZERO, 0.0, float(row.get("life", 3.0)))
			return 1
		"totem":
			_spawn(hero, w, "totem", Vector2(hero.position.x + hero.face * 40.0, Tune.f("ground_y")), Vector2.ZERO, 0.0, float(row.get("life", 6.0)))
			return 1
		"chain":
			return _chain(hero, w, row)
		"gust":
			return _around(hero, w, float(row.get("r", 300)), float(row.get("kb", 500)), 0.0)
		"ring":
			return _around(hero, w, float(row.get("r", 220)), 0.0, float(row.get("stun", 0.8)))
	return 0

static func _spawn(hero: Player, w: Weapon, mode: String, at: Vector2, v: Vector2, r: float, life: float) -> HeroShot:
	var s := HeroShot.new()
	s.hero = hero
	s.weapon = w
	s.mode = mode
	s.position = at
	s.vel = v
	s.r = r
	s.life = life
	s.face = hero.face
	var parent: Node = hero.world if hero.world else hero.get_parent()
	parent.add_child(s)
	return s

## Жезл-перескок: nearest enemy in jump_r ahead-or-around, then the nearest
## unhit one within jump_r of the last, `jumps` enemies in all.
static func _chain(hero: Player, w: Weapon, row: Dictionary) -> int:
	var jr := float(row.get("jump_r", 260))
	var from := hero.position - Vector2(0, Player.H / 2.0)
	var done: Array[Enemy] = []
	for i in int(row.get("jumps", 3)):
		var best: Enemy = null
		for e in hero.living_enemies():
			if e in done:
				continue
			var d := e.center().distance_to(from)
			if d <= jr and (best == null or d < best.center().distance_to(from)):
				best = e
		if best == null:
			break
		done.append(best)
		hero.add_bolt(from, best.center())
		hero.sub_hit(best, w.sub_dmg(), best.position.x - hero.face, 0.0, 0.0)
		from = best.center()
	return done.size()

## Свирель (knockback `kb` / weight away from the hero) and Навий колокол (stun).
static func _around(hero: Player, w: Weapon, r: float, kb: float, stun: float) -> int:
	var c := hero.position - Vector2(0, Player.H / 2.0)
	if hero.world:
		hero.world.add_ring(hero.position, r)
	var n := 0
	for e in hero.living_enemies():
		if e.center().distance_to(c) > r:
			continue
		hero.sub_hit(e, w.sub_dmg(), hero.position.x, kb, stun, true)
		n += 1
	return n
