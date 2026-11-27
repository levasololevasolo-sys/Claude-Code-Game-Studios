## Builds the layout of a combat room: width, platforms and enemy packs.
## Pure logic: same seed in, same room out. Ported from genRoom() in the prototype.
class_name RoomGen
extends RefCounted

## Returns {w, plats: Array[Vector3(x, y, width)], packs: Array[Array[float x]]}.
## k is the room number in the location (1-based), tier the location number (1-based).
static func generate(rng: RandomNumberGenerator, k: int, tier: int, t: Dictionary) -> Dictionary:
	var first := tier == 1 and k == 1
	var w: float = t.room_w_first if first else minf(t.room_w_max,
		t.room_w_base + (k - 1) * t.room_w_step + (tier - 1) * t.room_w_tier)
	var ys: Array = t.plat_levels
	var plats: Array = []
	var x := 300.0 + rng.randf() * 120.0
	while x < w - 420.0:
		var pw := 160.0 + float(rng.randi_range(0, 179))
		var lvl := rng.randi_range(0, 2)
		plats.append(Vector3(roundf(x), ys[lvl], pw))
		if lvl >= 1 and rng.randf() < 0.45:
			plats.append(Vector3(roundf(x + pw * 0.5 + 50.0), ys[lvl + 1], 140.0 + rng.randi_range(0, 89)))
		x += pw + 150.0 + rng.randf() * 260.0
	var packs: Array = []
	var base := 2 if first else 3 + int((k - 1) * 0.5) + (tier - 1)
	var px := 820.0
	while px < w - 260.0:
		var size := 2 if first else clampi(base + rng.randi_range(0, 1), 2, 8)
		var list: Array = []
		for i in size:
			list.append(clampf(px + (rng.randf() - 0.5) * 380.0, 400.0, w - 200.0))
		packs.append(list)
		if first and packs.size() >= 2:
			break
		px += t.pack_gap + rng.randf() * 260.0
	return { "w": w, "plats": plats, "packs": packs }
