## Icon contact sheets (art-bible §4.3, §7), Visual evidence for
## production/qa/evidence/. Draws the god signs, all rune icons with names, or
## the door icons through GodGlyph on a dark panel and saves a screenshot.
## Run: godot --path . res://tests/integration/ui/icon_sheet.tscn
##        -- --icon-sheet=gods|runes|doors|zoom|offer --icon-out=<file.png>
## (`offer` also needs `--rune-offer=<god>`; `zoom` takes `--icon-ids=rune:id,god:id`).
extends Node2D

var mode: String = "gods"
var out_file: String = ""
## `zoom` mode: icons to draw large, "rune:veles_s,god:perun".
var zoom_ids: PackedStringArray = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--icon-sheet="):
			mode = a.trim_prefix("--icon-sheet=")
		elif a.begins_with("--icon-out="):
			out_file = a.trim_prefix("--icon-out=")
		elif a.begins_with("--icon-ids="):
			zoom_ids = a.trim_prefix("--icon-ids=").split(",")
	if out_file == "":
		out_file = "res://production/qa/evidence/icons-%s.png" % mode
	if mode == "offer":  # the real rune offer screen; main.tscn reads --rune-offer=<god>
		process_mode = Node.PROCESS_MODE_ALWAYS
		add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	queue_redraw()
	_shoot.call_deferred()

func _ids(table: String) -> Array:
	return Tune.table(table).keys().filter(func(k: Variant) -> bool: return not String(k).begins_with("_"))

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var vs := get_viewport_rect().size
	if mode == "offer":
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color("#0d0b0a"))
	draw_rect(Rect2(Vector2(20, 20), vs - Vector2(40, 40)), Color("#1b1512"))
	draw_rect(Rect2(Vector2(20, 20), vs - Vector2(40, 40)), Color("#a8711f"), false, 3.0)
	match mode:
		"gods":
			var gods := _ids("gods")
			for i in gods.size():
				var c := Vector2(200 + (i % 3) * 760, 300 + (i / 3) * 480)
				c.x = 330 + (i % 3) * 630
				var g := String(gods[i])
				GodGlyph.draw(self, g, c, 160.0, Enemy.god_colour(g))
				draw_string(font, c + Vector2(-200, 230), String((Tune.table("gods")[g] as Dictionary).get("name", g)), HORIZONTAL_ALIGNMENT_CENTER, 400, 40, Color("#f4ecd8"))
		"runes":
			var ids := _ids("runes")
			var cols := 9
			for i in ids.size():
				var id := String(ids[i])
				var c := Vector2(130 + (i % cols) * 207, 115 + (i / cols) * 208)
				GodGlyph.draw_icon(self, "rune", id, c, 78.0)
				var nm := String((Tune.table("runes")[id] as Dictionary).get("name", id))
				draw_string(font, c + Vector2(-100, 98), nm, HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color("#e8dcc0"))
		"zoom":
			for i in zoom_ids.size():
				var kv := zoom_ids[i].split(":")
				GodGlyph.draw_icon(self, kv[0], kv[1], Vector2(280 + i * 450, 540), 210.0)
		"doors":
			var types := _ids("doors")
			for i in types.size():
				var t := String(types[i])
				var c := Vector2(200 + (i % 5) * 380, 300 + (i / 5) * 460)
				var row: Dictionary = Tune.table("doors")[t]
				var col := Color(String(row.get("colour", ""))) if String(row.get("colour", "")) != "" else Color.WHITE
				GodGlyph.door_icon(self, t, "perun", c, 130.0, col)
				draw_string(font, c + Vector2(-180, 190), t, HORIZONTAL_ALIGNMENT_CENTER, 360, 30, Color("#f4ecd8"))

func _shoot() -> void:
	for i in (30 if mode == "offer" else 6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_file)
	print("[icon-sheet] saved ", out_file)
	get_tree().quit()
