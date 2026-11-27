## HUD panel of the hero's two weapon slots (GDD weapons-and-loot §3.5 «В HUD»,
## §6 HUD): main weapon name in its rarity colour with the affix prefix and
## ★☆☆ stars; secondary weapon with stars, a cooldown bar, its key and the god
## whose status it carries (bog slota Udar, edge case 8). Drawn in 1080p screen px.
class_name WeaponHud
extends Control

var hero: Player

const W: float = 420.0

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, 132), Color(0.03, 0.05, 0.06, 0.72))
	var w := hero.weapon
	draw_string(font, Vector2(12, 30), "J", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.5))
	if w:
		draw_string(font, Vector2(40, 30), w.title(), HORIZONTAL_ALIGNMENT_LEFT, 300, 22, w.colour() if w.q < 3 else Color("#ffd27a"))
		WeaponDrop.draw_stars(self, Vector2(40, 46), w.q, 8.0)
		draw_string(font, Vector2(110, 54), String(w.body().get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.55))
	var s := hero.sub
	draw_string(font, Vector2(12, 92), "U", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.5))
	if s == null:
		draw_string(font, Vector2(40, 92), "доп. оружия нет", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.4))
		return
	draw_string(font, Vector2(40, 92), s.title(), HORIZONTAL_ALIGNMENT_LEFT, 260, 20, s.colour() if s.q < 3 else Color("#ffd27a"))
	WeaponDrop.draw_stars(self, Vector2(310, 86), s.q, 7.0)
	var k := clampf(1.0 - hero.sub_cd / maxf(s.cooldown(), 0.01), 0.0, 1.0)
	draw_rect(Rect2(40, 102, 360, 8), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(40, 102, 360 * k, 8), Color("#ffd27a") if k >= 1.0 else Color(0.8, 0.8, 0.8, 0.7))
	var g := hero.build.slot_god("strike") if hero.build else ""
	var gname := String((Tune.table("gods").get(g, {}) as Dictionary).get("name", "")) if g != "" and g != "rod" else "нет"
	draw_string(font, Vector2(40, 127), "состояние: бог слота Удар (%s)" % gname, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Enemy.god_colour(g) if gname != "нет" else Color(1, 1, 1, 0.45))
