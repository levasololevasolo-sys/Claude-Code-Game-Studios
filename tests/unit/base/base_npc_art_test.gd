## Drawn Застава NPCs (design/narrative/characters.md §2-3): the registry lists
## every NPC station with idle/talk/react and a portrait, and Офеня's lоток
## appears only after the first boss win (characters.md 3.3).
extends GdUnitTestSuite

const NPCS: Array[String] = ["dolya", "potap", "sova", "bayun", "chur", "ofenya"]

func test_registry_has_every_npc_with_three_anims_and_portrait() -> void:
	var reg := NpcSprite.registry()
	assert_float(float(reg.get("px_per_world", 0.0))).is_equal(2.0)
	for id in NPCS:
		var row: Dictionary = (reg.npcs as Dictionary).get(id, {})
		assert_bool(row.is_empty()).override_failure_message("no art for " + id).is_false()
		for a in ["idle", "talk", "react"]:
			assert_bool((row.anims as Dictionary).has(a)).override_failure_message(id + " lacks " + a).is_true()
		assert_bool(bool(row.anims.idle.loop)).is_true()
		assert_bool(bool(row.anims.react.loop)).is_false()
		assert_bool(ResourceLoader.exists(NpcSprite.ROOT + String(row.portraits.calm))).is_true()
		assert_float(NpcSprite.height_of(id)).is_greater(40.0)

func test_every_talking_station_has_art() -> void:
	for row: Dictionary in Tune.table("base").stations:
		if String(row.kind) != "gate":
			assert_bool(NpcSprite.has_art(String(row.id))).override_failure_message(String(row.id)).is_true()

func test_ofenya_needs_a_boss_win() -> void:
	var row := { "id": "ofenya", "needs": "boss" }
	var m := MetaState.new()
	assert_bool(Base.station_open(row, m)).is_false()
	m.bosses = { "kikimora": 1 }
	assert_bool(Base.station_open(row, m)).is_true()
	assert_bool(Base.station_open({ "id": "potap" }, MetaState.new())).is_true()
