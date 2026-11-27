## The element of the Flare: what lands on every enemy the shape touched (GDD
## amulet-and-flare §3.6, gods-and-runes §3.5 column «Вспышка»). The element is
## the god of the rune in the hero's Flare slot (RunBuild.flare_element(), set
## at each press); the shape comes from the amulet. The statuses come from
## RunBuild.payload("flare", P) so rune levels and Гнев богов apply.
class_name FlareElement
extends RefCounted

## Element ids known to the code.
const PURE: String = "pure"
const GODS: Array[String] = ["svarog", "perun", "stribog", "veles", "zhiva"]

## Puts the element's statuses on `hit` for one touched enemy at power `p`.
## Every god but Zhiva also gives the short stun `flare_god_stun`. God statuses
## land only at P >= flare_god_min_power (§3.5: «Эхо» 0.5 counts).
static func apply(element: String, hit: Hit, p: float, tune: Dictionary, build: RunBuild = null) -> void:
	if element in GODS:
		if element != "zhiva":
			hit.stun = float(tune.get("flare_god_stun", 0.4))
		if build and p >= float(tune.get("flare_god_min_power", 0.5)):
			hit.add_payload(build.payload("flare", p, tune))
			hit.mods.merge(build.damage_mods(false), true)
	else:
		hit.stun = float(tune.get("flare_stun", 1.4)) * p
	hit.mods["flare_element"] = element if element != "" else PURE

## Knockback multiplier: «Буйный ветер» ×1.5 (weight is applied later by
## DamageRules.knockback — «с учётом веса»).
static func kb_mult(element: String, build: RunBuild = null) -> float:
	if element == "stribog" and build:
		return build.kb_mult("flare")
	return 1.0

## Effects on the hero after the Flare: «Живая вода» +shield per touched enemy
## and a heal. `touched` = number of enemies the shape hit.
static func apply_to_hero(element: String, hero: Node, touched: int, tune: Dictionary, build: RunBuild = null) -> void:
	if element != "zhiva" or build == null or not hero is Player:
		return
	var pl := hero as Player
	pl.add_shield(build.value(build.slots.flare, "shield", 0.0) * touched)
	pl.hp = minf(float(tune.get("player_hp", 100.0)), pl.hp + build.value(build.slots.flare, "heal", 0.0))
