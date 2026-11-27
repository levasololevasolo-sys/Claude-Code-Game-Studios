## The element of the Flare: what lands on every enemy the shape touched (GDD
## amulet-and-flare §3.6). The element comes from the god of the rune in the hero's
## Flare slot; the shape comes from the amulet.
##
## HOOK FOR GODS (gods-and-runes.md, not ported yet): Player.flare_element holds
## the element id. When the build system exists, set it from
## `build.slot_god("flare")` ("" / "pure" when the slot is empty) and add a branch
## per god below: "svarog" burn 2 × burn_time × P, "perun" one discharge per enemy,
## "stribog" +2 cuts and kb × 1.5, "veles" curse 1.5 × curse_time × P, "zhiva"
## roots 1.5 × root_time × P plus hero shield/heal (see apply_to_hero()). Every god
## element also gives the short stun `flare_god_stun` (Zhiva: none).
class_name FlareElement
extends RefCounted

## Element ids known to the code. Only PURE is implemented.
const PURE: String = "pure"
const GODS: Array[String] = ["svarog", "perun", "stribog", "veles", "zhiva"]

## Puts the element's statuses on `hit` for one touched enemy at power `p`.
## Unknown or not-yet-ported gods fall back to pure light (with a warning once).
static func apply(element: String, hit: Hit, p: float, tune: Dictionary) -> void:
	match element:
		"", PURE:
			hit.stun = float(tune.get("flare_stun", 1.4)) * p
		_:
			# Gods are not ported: keep the Flare a breather (short stun) so the
			# hook is usable, the statuses come with gods-and-runes.
			if element in GODS and element != "zhiva":
				hit.stun = float(tune.get("flare_god_stun", 0.4))
			else:
				hit.stun = float(tune.get("flare_stun", 1.4)) * p
	hit.mods["flare_element"] = element if element != "" else PURE

## Knockback multiplier of the element (Stribog × 1.5 later).
static func kb_mult(_element: String) -> float:
	return 1.0

## Effects on the hero after the Flare (Zhiva heal and shield later). `touched` =
## number of enemies the shape hit.
static func apply_to_hero(_element: String, _hero: Node, _touched: int, _tune: Dictionary) -> void:
	pass
