## Stand-in boss of the lair placeholder (GDD room-generation §3.16 until the
## real bosses of enemies-and-elites §3.8-3.12): a Трясинник scaled up by
## `lair_scale`, with `lair_hp` hp, flagged `boss` (no launch, shorter stun).
class_name LairBoss
extends Crawler

## Name shown on the summary «кто убил» and the lair door.
var title: String = "Хозяин"

func _load_stats() -> void:
	kind_id = "crawler"
	_apply_row()
	var k := Tune.f("lair_scale")
	w *= k
	h *= k
	weight *= k
	max_hp = Tune.f("lair_hp")
	boss = true
	stats = stats.duplicate()
	stats["name"] = title
	stats["embers"] = Tune.f("lair_embers")
