## The base «Застава» between runs (GDD economy-and-meta §3.4-3.6, armor-and-
## hero-progression §3.5, living-world §1). Lives inside World (its Room gives
## the floor, its Player walks): draws the yard, places the stations of
## base.json, picks this visit's lines (DialogueRules) once on entry, and on E
## (or use() from a check) shows the NPC's line, then opens the NPC's menu:
## Потап — armor tiers (the hero's look changes at once), Сова — amulets,
## Чур — Капище Рода rules, Доля — the line. The gate emits gate_used; the
## RunDirector starts the next run. Scene: scenes/base/base.tscn.
class_name Base
extends Node2D

## The hero used the gate.
signal gate_used
## A dialogue box or a menu opened.
signal screen_opened(screen: Control)

var world: World
var meta: MetaState
var rules: DialogueRules
## npc -> line chosen for this visit.
var picked: Dictionary = {}
## npc -> true once its line was shown this visit.
var heard: Dictionary = {}
var stations: Array[Station] = []
## Open box or menu, null when none.
var screen: Control
## Called after a purchase (the RunDirector writes the save).
var on_change: Callable

## Builds the yard for `p_world` and `p_meta`; picks and records this visit's lines.
func setup(p_world: World, p_meta: MetaState) -> void:
	world = p_world
	meta = p_meta
	z_index = -1
	rules = DialogueRules.make(Tune.table("dialogue"))
	picked = rules.pick_visit(Tune.table("base").get("order", []), meta)
	rules.apply_visit(picked, meta)
	for row: Dictionary in Tune.table("base").get("stations", []):
		var s := Station.new()
		s.row = row
		s.position = Vector2(float(row.x), Tune.f("ground_y"))
		s.spark = rules.spark(picked.get(row.id, {}))
		add_child(s)
		stations.append(s)
	dress_hero()

## Dresses the hero in the bought armor (or `armor` for a try-on).
func dress_hero(armor: Dictionary = {}) -> void:
	if world and world.player and world.player.visual:
		ShopRules.dress(world.player.visual, armor if not armor.is_empty() else meta.armor, Tune.table("armor"))

## The station the hero stands at, null if none.
func nearest() -> Station:
	if world == null or world.player == null:
		return null
	var reach := float(Tune.table("base").get("reach", 120))
	for s in stations:
		if absf(world.player.position.x - s.position.x) < reach:
			return s
	return null

func _physics_process(_dt: float) -> void:
	var n := nearest()
	for s in stations:
		s.near = s == n
		if world and world.player:
			s.face = signf(world.player.position.x - s.position.x) if world.player.position.x != s.position.x else 1.0
	if n and screen == null and not world.player.scripted and Input.is_action_just_pressed(&"interact"):
		use(n.id())

## Uses station `id`: the gate, or the NPC's line (once per visit) and then its menu.
func use(id: String) -> void:
	if screen != null:
		return
	var st := _station(id)
	if st == null:
		return
	if id == "gate":
		gate_used.emit()
		return
	var line: Dictionary = picked.get(id, {})
	var kind := String(st.row.get("kind", "talk"))
	if not line.is_empty() and (not heard.has(id) or kind == "talk"):
		heard[id] = true
		st.spark = false
		var box := DialogueBox.new()
		box.speaker = String(st.row.get("name", id))
		box.text = DialogueRules.text_of(line, meta, Tune.table("armor").get("titles", []))
		if kind != "talk":
			box.closed.connect(func() -> void:
				screen = null
				_open_menu.call_deferred(kind))
		else:
			box.closed.connect(func() -> void: screen = null)
		_show(box)
	elif kind != "talk":
		_open_menu(kind)

func _station(id: String) -> Station:
	for s in stations:
		if s.id() == id:
			return s
	return null

func _show(scr: Control) -> void:
	screen = scr
	world.show_screen(scr, 25)
	screen_opened.emit(scr)

func _bank() -> String:
	var parts: PackedStringArray = ["Угли %d" % meta.embers]
	for k: String in meta.res:
		parts.append("%s %d" % [RunDirector.res_name(k), int(meta.res[k])])
	return "   ".join(parts)

func _open_menu(kind: String) -> void:
	var scr := ShopScreen.new()
	scr.bank_fn = _bank
	match kind:
		"armor":
			var cfg := Tune.table("armor")
			var slots: Array = (cfg.slots as Dictionary).keys()
			scr.title = "Кузнец Потап — Доспех   (звание: %s)" % _title()
			scr.rows_fn = func() -> Array: return _armor_rows(cfg, slots)
			scr.pick_fn = func(i: int) -> void:
				if ShopRules.buy_armor(meta, slots[i], cfg):
					scr.title = "Кузнец Потап — Доспех   (звание: %s)" % _title()
					dress_hero()
					_changed()
			scr.hovered.connect(func(i: int) -> void:
				var a := meta.armor.duplicate()
				if i < slots.size() and int(a[slots[i]]) < int(cfg.max_tier):
					a[slots[i]] = int(a[slots[i]]) + 1
				dress_hero(a))
			scr.closed.connect(func() -> void: dress_hero())
		"amulet":
			var base := Tune.table("base")
			var ids: Array = (base.amulets as Dictionary).keys()
			scr.title = "Ведунья Сова — Обереги"
			scr.rows_fn = func() -> Array: return _amulet_rows(base, ids)
			scr.pick_fn = func(i: int) -> void:
				if ShopRules.take_amulet(meta, ids[i], base):
					_changed()
		"kapishe":
			var base := Tune.table("base")
			var ids: Array = (base.kapishe as Dictionary).keys()
			scr.title = "Капище Рода — правила забега"
			scr.rows_fn = func() -> Array: return _up_rows(base, ids)
			scr.pick_fn = func(i: int) -> void:
				if ShopRules.buy_up(meta, ids[i], base):
					_changed()
	scr.closed.connect(func() -> void: screen = null)
	_show(scr)

func _title() -> String:
	var titles: Array = Tune.table("armor").get("titles", [])
	return String(titles[DialogueRules.title_of(meta.armor)])

func _armor_rows(cfg: Dictionary, slots: Array) -> Array:
	var out: Array = []
	for s: String in slots:
		var row: Dictionary = cfg.slots[s]
		var t := int(meta.armor.get(s, 0))
		var looks: Array = row.looks
		var block := ShopRules.armor_block(meta, s, cfg)
		var next := "" if t >= int(cfg.max_tier) else " → %s (ярус %d)" % [looks[t + 1], t + 1]
		var price := "" if t >= int(cfg.max_tier) else ShopRules.cost_text(ShopRules.armor_price(s, t + 1, cfg))
		out.append({ "text": "%s: %s%s" % [row.name, looks[t], next],
			"sub": "%s · %s" % [row.bonus, price] if price != "" else String(row.bonus),
			"enabled": block == "", "note": block })
	return out

func _amulet_rows(base: Dictionary, ids: Array) -> Array:
	var out: Array = []
	for id: String in ids:
		var owned: bool = meta.lanterns.has(id) or (ShopRules.amulet_price(id, base).res as Dictionary).is_empty()
		var cost := ShopRules.amulet_price(id, base)
		var nm := String(Tune.table("amulets").get(id, {}).get("name", id))
		var sub := "надет" if meta.lantern == id else ("куплен — надеть" if owned else ShopRules.cost_text(cost))
		var ok: bool = owned or ShopRules.can_pay(meta, cost)
		out.append({ "text": nm, "sub": sub, "enabled": ok, "note": "" if ok else "Не хватает" })
	return out

func _up_rows(base: Dictionary, ids: Array) -> Array:
	var out: Array = []
	for id: String in ids:
		var row: Dictionary = base.kapishe[id]
		var p := ShopRules.up_price(meta, id, base)
		var lvl := int(meta.up.get(id, 0))
		var sub := "%s · ур. %d/%d" % [row.text, lvl, (row.prices as Array).size()]
		var note := "Уже на максимуме" if p < 0 else ("" if meta.embers >= p else "Не хватает углей")
		if p >= 0:
			sub += " · угли %d" % p
		out.append({ "text": String(row.name), "sub": sub, "enabled": note == "", "note": note })
	return out

func _changed() -> void:
	if on_change.is_valid():
		on_change.call()

func _draw() -> void:
	var g := Tune.f("ground_y")
	var w := float(Tune.table("base").get("width", 2700))
	# The rendered Застава backdrop (visuals.json "base" layers, Room's Backdrop)
	# replaces the sky, palisade and houses below; they stay as the fallback.
	if not has_backdrop_art():
		_draw_yard(g, w)
	# boards
	draw_rect(Rect2(-400, g, w + 800, 400), Color("#2A1A12"))
	var bx := -400.0
	while bx < w + 400:
		draw_rect(Rect2(bx, g, 118, 22), Color("#7A5232"))
		bx += 122.0
	draw_line(Vector2(-400, g), Vector2(w + 400, g), Color("#C8902E"), 3.0)

## True when every image layer of visuals.json "base" exists (the backdrop shows them).
static func has_backdrop_art() -> bool:
	var layers: Array = (Tune.table("visuals").get("base", {}) as Dictionary).get("layers", [])
	var n := 0
	for spec: Dictionary in layers:
		var t := String(spec.get("tex", ""))
		if t != "":
			if not ResourceLoader.exists(t):
				return false
			n += 1
	return n > 0

## The old procedural yard: night sky, palisade, log houses (fallback).
func _draw_yard(g: float, w: float) -> void:
	draw_rect(Rect2(-400, g - 1100, w + 800, 1100), Color("#1D2433"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 70:
		draw_circle(Vector2(rng.randf_range(-300, w + 300), g - rng.randf_range(420, 1080)), rng.randf_range(1.0, 2.4), Color("#EDE6F2", 0.5))
	# palisade
	var x := -300.0
	while x < w + 300:
		var ph := 300.0 + rng.randf_range(-20, 20)
		draw_colored_polygon(PackedVector2Array([Vector2(x, g), Vector2(x, g - ph), Vector2(x + 20, g - ph - 34), Vector2(x + 40, g - ph), Vector2(x + 40, g)]), Color("#2A1A12"))
		x += 44.0
	# log houses with lit windows
	for hx: float in [250.0, 1150.0, 2050.0]:
		var hw := 380.0
		draw_rect(Rect2(hx, g - 250, hw, 250), Color("#5B3A24"))
		for k in 8:
			draw_line(Vector2(hx, g - 250 + k * 31), Vector2(hx + hw, g - 250 + k * 31), Color("#2A1A12"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 30, g - 250), Vector2(hx + hw * 0.5, g - 400), Vector2(hx + hw + 30, g - 250)]), Color("#7A5232"))
		draw_polyline(PackedVector2Array([Vector2(hx - 30, g - 250), Vector2(hx + hw * 0.5, g - 400), Vector2(hx + hw + 30, g - 250)]), Color("#C8902E"), 4.0)
		for wx: float in [hx + 70, hx + hw - 130]:
			draw_circle(Vector2(wx + 30, g - 150), 90, Color("#FF9A3C", 0.06))
			draw_rect(Rect2(wx, g - 180, 60, 56), Color("#FF9A3C", 0.85))
			draw_rect(Rect2(wx, g - 180, 60, 56), Color("#2A1A12"), false, 5.0)
		# chimney smoke
		for k in 4:
			draw_circle(Vector2(hx + hw * 0.7 + k * 14, g - 430 - k * 40), 16 + k * 6, Color("#A99C86", 0.08))
