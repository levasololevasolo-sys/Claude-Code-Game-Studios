## Save slots (design/ux/main-menu.md §2): 5 files user://slot_1.json ..
## slot_5.json, the last used slot in user://slots.cfg, and the one-time move of
## the old single user://save.json into slot 1. Static helpers, no state.
class_name SaveSlots
extends RefCounted

## Number of save slots.
const SLOTS: int = 5
const SLOT_PATH: String = "user://slot_%d.json"
const SLOTS_CFG: String = "user://slots.cfg"
const OLD_SAVE: String = "user://save.json"

## Path of slot `i` (1..SLOTS).
static func slot_path(i: int) -> String:
	return SLOT_PATH % clampi(i, 1, SLOTS)

## Short facts of slot `i` for the menu, {} when the slot is empty:
## {runs, wins, embers, difficulty, run_on}.
static func slot_summary(i: int) -> Dictionary:
	var path := slot_path(i)
	if not FileAccess.file_exists(path):
		return {}
	var d := SaveFile.read(path)
	if not d.get("meta") is Dictionary:
		return {}
	var m := MetaState.from_dict(d.meta)
	return { "runs": m.runs, "wins": m.wins, "embers": m.embers, "difficulty": m.difficulty,
		"run_on": d.get("run") is Dictionary }

## The slot used last (0 = none yet).
static func last_slot() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SLOTS_CFG) != OK:
		return 0
	return int(cfg.get_value("slots", "last", 0))

## Moves the pre-slot user://save.json into slot 1 once.
static func migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE) and not FileAccess.file_exists(slot_path(1)):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(OLD_SAVE), ProjectSettings.globalize_path(slot_path(1)))
		remember(1)

static func remember(i: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SLOTS_CFG)
	cfg.set_value("slots", "last", i)
	cfg.save(SLOTS_CFG)

## Deletes slot `i`'s file.
static func delete_slot(i: int) -> void:
	var path := slot_path(i)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
