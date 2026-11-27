## Headless check of RoomGen until gdUnit4 is installed (/test-setup).
## Run: godot --headless --path . -s res://tests/unit/room_gen/test_room_gen.gd
extends SceneTree

var fails := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _gen(s: int, k: int, tier: int, t: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return RoomGen.generate(rng, k, tier, t)

func _initialize() -> void:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tuning.json"))
	var a := _gen(5, 3, 1, t)
	var b := _gen(5, 3, 1, t)
	_check(a == b, "same seed gives the same room")
	_check(_gen(1, 1, 1, t).w == t.room_w_first, "first room uses room_w_first")
	_check(_gen(1, 1, 1, t).packs.size() <= 2, "first room has at most 2 packs")
	_check(_gen(1, 2, 1, t).w == t.room_w_base + t.room_w_step, "room 2 width = base + step")
	_check(_gen(1, 9, 3, t).w == t.room_w_max, "width is capped at room_w_max")
	var ok := true
	for s in 50:
		var r := _gen(s, 4, 2, t)
		for p: Vector3 in r.plats:
			if p.x < 0 or p.x + p.z > r.w or not (p.y in t.plat_levels):
				ok = false
		for pack: Array in r.packs:
			for x: float in pack:
				if x < 400 or x > r.w - 200:
					ok = false
	_check(ok, "platforms and enemies stay inside the room over 50 seeds")
	print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
