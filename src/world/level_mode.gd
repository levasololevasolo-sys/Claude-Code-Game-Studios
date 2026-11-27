## Which level structure a location uses (GDD level-structure §3.9): "graph" =
## one big generated level (LevelGen, templates room_templates_<lib>.json), "rooms"
## = the old chain of chunk rooms with doors (RoomGen). Project setting
## `navi/levels/mode` (default "graph"), overridden by `--levels=graph|rooms`.
## Graph mode applies only to locations whose template library exists (stage 1:
## the Swamp); Forest and Frost stay on rooms until their templates are drawn.
class_name LevelMode
extends RefCounted

const SETTING: String = "navi/levels/mode"

## The configured mode: --levels= wins over the project setting.
static func mode(args: PackedStringArray = OS.get_cmdline_user_args()) -> String:
	for a in args:
		if a.begins_with("--levels="):
			return a.trim_prefix("--levels=")
	# The run check plays the old door flow (lair → haven → next location → death →
	# base); the graph level has its own --level2-check.
	for a in args:
		if a.begins_with("--run-check="):
			return "rooms"
	return String(ProjectSettings.get_setting(SETTING, "graph"))

## True when location `lib` (locations.json "lib") is played as one graph level.
static func graph_for(lib: String, args: PackedStringArray = OS.get_cmdline_user_args()) -> bool:
	return mode(args) == "graph" and LevelGen.has_library(lib)
