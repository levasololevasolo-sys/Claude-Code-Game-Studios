## Водяница, the singer (GDD bestiary §3.2 card 6, mechanic ward_song, §4 B4).
## Keeps keep_dx from the hero behind her pack. Sings (0.8 s wind-up, arms up,
## green rings): every ally within song_r gets a tina shield of ward_frac of its
## max HP for ward_time s (Enemy.give_tina; damage goes into it first). Song
## cooldown song_cd. Any hit or stun breaks the song (cooldown song_break_cd).
## A hero closer than push_range gets a water shove: push_wind -> push, which is
## parried and the parry cuts the arm (limb_zones.json "vodyanitsa"); one-armed
## her song wind-up is x1.5. Stats: enemies.json "vodyanitsa".
class_name Vodyanitsa
extends Enemy

## Shove cooldown, s.
var push_cd: float = 0.0
## True once the current shove has hit.
var pushed: bool = false
## Allies shielded by the last finished song (for checks and the HUD).
var last_warded: int = 0

func _load_stats() -> void:
	kind_id = "vodyanitsa"
	_apply_row()

func _behave(dt: float) -> void:
	think(dt, hero_pos(), _around(stat("song_r")))

func is_winding() -> bool:
	return st == "song" or st == "push_wind"

func contact_damage() -> float:
	return 0.0

## True when an ally in `allies` could take a shield now (alive, not shielded).
static func wants_song(allies: Array) -> bool:
	for a in allies:
		var e := a as Enemy
		if e and not e.dead and e.tina <= 0.0 and not e.boss:
			return true
	return false

## Gives the song's shield to every ally in `allies`; returns how many got it.
func sing_ward(allies: Array) -> int:
	var n := 0
	for a in allies:
		var e := a as Enemy
		if e == null or e.dead or e == self or e.boss:
			continue
		e.give_tina(SwampRules.tina_amount(e.max_hp, stat("ward_frac")), stat("ward_time"))
		n += 1
	if n > 0:
		Audio.play_at(&"ward_gain", position)
	return n

## One tick: walk (keep distance) -> song -> walk; hero close: push_wind ->
## push -> walk. `allies` = enemies within song_r.
func think(dt: float, hp_pos: Vector2, allies: Array = []) -> void:
	t -= dt
	cd -= dt
	push_cd -= dt
	var dx := hp_pos.x - position.x
	var adx := absf(dx)
	if st != "song" and st != "push_wind" and st != "push" and dx != 0.0:
		face = 1 if dx > 0.0 else -1
	match st:
		"song":
			vel.x = 0.0
			if t <= 0.0:
				last_warded = sing_ward(allies)
				st = "walk"
				cd = stat("song_cd")
		"push_wind":
			vel.x = 0.0
			if t <= 0.0:
				st = "push"
				t = stat("push_time")
				pushed = false
		"push":
			vel.x = 0.0
			if not pushed and SwampRules.swing_hits(position, face, w, stat("push_hit_x"), stat("push_hit_y"), hp_pos):
				pushed = true
				var dmg := hurt_hero(stat("push_dmg"), Hit.Kind.CONTACT)
				var p := hero()
				if dmg > 0.0 and p:
					p.velocity.x = face * stat("push_knock")
			if st == "push" and t <= 0.0:
				st = "walk"
				push_cd = stat("push_cd")
		_:
			st = "walk"
			var keep := stat("keep_dx")
			if adx < keep - 40.0:
				vel.x = -signf(dx) * stat("speed")
			elif adx > keep + 60.0:
				vel.x = signf(dx) * stat("speed")
			else:
				vel.x = 0.0
			if adx < stat("push_range") and push_cd <= 0.0 and absf(hp_pos.y - position.y) < stat("push_hit_y"):
				st = "push_wind"
				t = stat("push_wind")
				vel.x = 0.0
			elif cd <= 0.0 and wants_song(allies):
				st = "song"
				t = stat("song")
				vel.x = 0.0

## A hit breaks the song (§3.2).
func _after_hurt(hit: Hit) -> void:
	if SwampRules.song_broken(st == "song", hit != null, stun > 0.0):
		break_song()

## Stops the song: no shield, cooldown song_break_cd.
func break_song() -> void:
	st = "walk"
	t = 0.0
	cd = stat("song_break_cd")
	_mark().say("Песня сорвана!", Tune.f("limb_word_time") * 0.6)

func _draw() -> void:
	if _skin_draw():
		return
	_draw_windup_glow()
	var ring := Color(String(stats.ring))
	if st == "song":
		# Song aura: rings spread to the reach of the song.
		var k := 1.0 - clampf(t / maxf(stat("song"), 0.01), 0.0, 1.0)
		draw_arc(center() - position, stat("song_r"), 0, TAU, 48, Color(ring, 0.25), 2.0)
		for i in 3:
			var ph := fmod(k + i / 3.0, 1.0)
			draw_arc(center() - position, 20.0 + ph * (stat("song_r") - 20.0), 0, TAU, 40, Color(ring, 0.8 * (1.0 - ph)), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var c := Color.WHITE if flash > 0.0 else Color(String(stats.color))
	var outline := Color("#120d12")
	var hair := Color(String(stats.hair))
	var top := 0.86 if head_off else 1.0
	# Tall thin figure, the hem dissolving into tina (wavy bottom).
	var body := PackedVector2Array()
	body.append(Vector2(-w * 0.25, -h * 0.82))
	body.append(Vector2(w * 0.25, -h * 0.82))
	body.append(Vector2(w * 0.5, -h * 0.3))
	for i in 7:
		var x := w * 0.6 - i * w * 1.2 / 6.0
		body.append(Vector2(x, -2.0 - (6.0 if i % 2 == 1 else 0.0) + sin(anim * 4.0 + i) * 2.0))
	body.append(Vector2(-w * 0.5, -h * 0.3))
	draw_colored_polygon(body, outline)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(Vector2(p.x * 0.88, p.y * 0.97 - 1.0))
	draw_colored_polygon(inner, c)
	if not head_off:
		draw_circle(Vector2(0, -h * 0.9 * top), 9.0, outline)
		draw_circle(Vector2(0, -h * 0.9 * top), 7.5, c.lightened(0.25))
	# Wet hair to the heels, behind.
	for i in 3:
		draw_line(Vector2(-4 - i * 3, -h * 0.95 * top), Vector2(-w * 0.45 - i * 3 + sin(anim * 2 + i) * 2, -4), hair, 3.0)
	# Arms: up in the song, palms forward in the shove.
	var sh := Vector2(w * 0.2, -h * 0.72)
	var hand := Vector2(w * 0.35, -h * 0.4)
	if st == "song":
		hand = Vector2(w * 0.3, -h * 1.12)
	elif st == "push_wind":
		hand = Vector2(-w * 0.1, -h * 0.62)
	elif st == "push":
		hand = Vector2(w * 0.5 + stat("push_hit_x") * 0.5, -h * 0.6)
	if not arm_off:
		draw_line(sh, hand, outline, 6.0)
		draw_line(sh, hand, c.lightened(0.15), 4.0)
		if st == "push_wind":
			_draw_glow(hand, 22.0, Color("#c2502a"), 0.9)
	var sh2 := Vector2(-w * 0.2, -h * 0.72)
	var hand2 := Vector2(-w * 0.3, -h * 1.12) if st == "song" else Vector2(-w * 0.3, -h * 0.4)
	draw_line(sh2, hand2, outline, 6.0)
	draw_line(sh2, hand2, c.darkened(0.1), 4.0)
	if st == "push":
		draw_arc(Vector2(w * 0.5 + stat("push_hit_x") * 0.6, -h * 0.6), 18.0, -1.2, 1.2, 10, Color(ring, 0.8), 3.0)
	_draw_windup_outline(body)
	_draw_eyes(Vector2(1, -h * 0.91 * top), Vector2(5, -h * 0.91 * top), 2.2, face)
	_draw_overlay()
