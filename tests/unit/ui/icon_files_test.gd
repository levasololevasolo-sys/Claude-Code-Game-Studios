## Every god and rune of the data tables has its SVG icon (art-bible §4.3, §7;
## tools/asset-pipeline/icons/build_icons.py), so GodGlyph never falls back to
## the placeholder shapes for shipped content.
extends GdUnitTestSuite

func _ids(table: String) -> Array:
	return Tune.table(table).keys().filter(func(k: Variant) -> bool: return not String(k).begins_with("_"))

func test_every_god_has_a_sign_icon() -> void:
	for g in _ids("gods"):
		assert_bool(ResourceLoader.exists(GodGlyph.icon_path("god", String(g)))).override_failure_message("no sign for god " + String(g)).is_true()

func test_every_rune_has_an_icon() -> void:
	for id in _ids("runes"):
		assert_bool(ResourceLoader.exists(GodGlyph.icon_path("rune", String(id)))).override_failure_message("no icon for rune " + String(id)).is_true()

func test_every_door_type_has_an_icon() -> void:
	for t in _ids("doors"):
		var kind := "god" if t in ["god", "rod"] else "door"
		var id := "rod" if t in ["god", "rod"] else String(t)
		assert_bool(ResourceLoader.exists(GodGlyph.icon_path(kind, id))).override_failure_message("no icon for door " + String(t)).is_true()

func test_icon_loads_as_texture_and_is_cached() -> void:
	var a := GodGlyph.icon("god", "perun")
	assert_object(a).is_not_null()
	assert_object(GodGlyph.icon("god", "perun")).is_same(a)
	assert_object(GodGlyph.icon("rune", "no_such_rune")).is_null()
