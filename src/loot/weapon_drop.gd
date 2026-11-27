## A weapon lying on the floor (GDD weapons-and-loot §3.9, spawnArmsDrop): the
## label «взять: [приставка ·] название ★★☆» in its rarity colour and, when the
## hero stands by it, a comparison card (in hand vs on the floor: damage, speed,
## reach with up/down arrows, stars, affix). E swaps: the old weapon of that slot
## lies down here with its quality and affix; an empty slot just takes it.
class_name WeaponDrop
extends Node2D

## Emitted after a swap: the weapon taken and the one left (null if none).
signal taken(new_weapon: Weapon, old_weapon: Weapon)

var weapon: Weapon
var world: World
var near: bool = false
var _t: float = 0.0

const CARD_W: float = 440.0

func _physics_process(dt: float) -> void:
	_t += dt
	var p := world.player if world else null
	near = p != null and is_instance_valid(p) and not p.dead and absf(p.position.x - position.x) < Tune.f("drop_reach")
	if near and not p.scripted and Input.is_action_just_pressed(&"interact"):
		take()
	queue_redraw()

## The weapon in the hero's hand in this drop's slot (null if empty).
func held() -> Weapon:
	var p := world.player if world else null
	if p == null or weapon == null:
		return null
	return p.sub if weapon.kind == Weapon.SUB else p.weapon

## Swaps with the hero's slot (§3.9 p.2-4).
func take() -> void:
	var p := world.player
	var new_w := weapon
	var old := p.equip(new_w)
	taken.emit(new_w, old)
	if old == null:
		queue_free()
	else:
		weapon = old

static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, 1.5)

## Draws q of 3 stars from `at` (left), gold at ★★★, silver at ★★.
static func draw_stars(ci: CanvasItem, at: Vector2, q: int, r: float = 7.0) -> void:
	var col := Color("#ffd27a") if q >= 3 else (Color("#d8dde0") if q == 2 else Color("#d8cfb8"))
	for i in 3:
		_star(ci, at + Vector2(i * r * 2.3 + r, 0), r, col, i < q)

static func _arrow(ci: CanvasItem, at: Vector2, up: bool) -> void:
	var col := Color("#8fe39a") if up else Color("#ff7a6a")
	var d := -1.0 if up else 1.0
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -d * 5), at + Vector2(6, -d * 5), at + Vector2(0, d * 6)]), col)

func _draw() -> void:
	if weapon == null:
		return
	var font := ThemeDB.fallback_font
	var col := weapon.colour()
	var y := -18.0 + sin(_t * 3.0) * 4.0
	draw_circle(Vector2(0, y), 30.0, Color(col, 0.16))
	draw_line(Vector2(-22, y + 10), Vector2(22, y - 12), col.darkened(0.2), 5.0)
	draw_line(Vector2(-22, y + 10), Vector2(-12, y + 5), Color("#6b4a2b"), 6.0)
	var label := "взять: " + weapon.title()
	draw_string(font, Vector2(-160, -60), label, HORIZONTAL_ALIGNMENT_CENTER, 320, 15, col)
	draw_stars(self, Vector2(-22, -48), weapon.q, 6.0)
	if near:
		_draw_card(font)

func _draw_card(font: Font) -> void:
	var cur := held()
	var x0 := -CARD_W / 2.0
	var top := -300.0
	draw_rect(Rect2(x0, top, CARD_W, 220), Color(0.04, 0.06, 0.07, 0.9))
	draw_rect(Rect2(x0, top, CARD_W, 220), Color(weapon.colour(), 0.8), false, 2.0)
	var cx := [x0 + 130.0, x0 + 300.0]
	draw_string(font, Vector2(x0 + 12, top + 22), "E — взять", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.75))
	draw_string(font, Vector2(cx[0], top + 22), "в руках", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(cx[1], top + 22), "на полу", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
	var ws: Array = [cur, weapon]
	for i in 2:
		var w: Weapon = ws[i]
		if w == null:
			draw_string(font, Vector2(cx[i], top + 46), "пусто", HORIZONTAL_ALIGNMENT_LEFT, 150, 14, Color(1, 1, 1, 0.5))
			continue
		draw_string(font, Vector2(cx[i], top + 46), String(w.row().get("name", w.id)), HORIZONTAL_ALIGNMENT_LEFT, 160, 15, w.colour())
		draw_stars(self, Vector2(cx[i], top + 60), w.q, 6.0)
		var af := String(w.affix_row().get("name", "—"))
		draw_string(font, Vector2(cx[i], top + 172), af, HORIZONTAL_ALIGNMENT_LEFT, 160, 13, Color("#ffd27a") if w.affix != "" else Color(1, 1, 1, 0.4))
	var a: Dictionary = cur.card_stats() if cur else { "dmg": 0.0, "speed": 0.0, "reach": 0.0 }
	var b: Dictionary = weapon.card_stats()
	var rows := [["Урон", "dmg", "%.1f"], ["Скорость", "speed", "%.2f/с"]]
	if weapon.kind == Weapon.ARM:
		rows.append(["Дальность", "reach", "%d px"])
	for j in rows.size():
		var ry := top + 92 + j * 24.0
		var key: String = rows[j][1]
		draw_string(font, Vector2(x0 + 12, ry), rows[j][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
		var fmt: String = rows[j][2]
		draw_string(font, Vector2(cx[0], ry), (fmt % (int(a[key]) if key == "reach" else a[key])) if cur else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(font, Vector2(cx[1], ry), fmt % (int(b[key]) if key == "reach" else b[key]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		if not is_equal_approx(float(a[key]), float(b[key])):
			_arrow(self, Vector2(cx[1] + 100, ry - 5), float(b[key]) > float(a[key]))
	var tip := String(weapon.row().get("tip", ""))
	if weapon.kind == Weapon.SUB and world and world.player:
		var g := world.player.build.slot_god("strike")
		var gname := String((Tune.table("gods").get(g, {}) as Dictionary).get("name", "")) if g != "" and g != "rod" else "нет"
		tip += " · состояние: бог слота Удар (%s)" % gname
	var need := String(weapon.row().get("needs_god", ""))
	var tcol := Color(1, 1, 1, 0.7)
	if need != "" and world and world.player and not need in world.player.build.gods_taken():
		tip += " · нужен " + String((Tune.table("gods").get(need, {}) as Dictionary).get("name", need))
		tcol = Color("#ff7a6a")
	draw_string(font, Vector2(x0 + 12, top + 200), tip, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 24, 12, tcol)
