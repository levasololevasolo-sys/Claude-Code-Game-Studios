## The save file (ADR-0003 § File): one versioned JSON, written to a temp file
## and renamed over the real one. A missing, broken or newer file reads as
## defaults with a warning; a broken file is kept as save.bad.json.
class_name SaveFile
extends RefCounted

const VERSION: int = 1

## Writes `data` (version is added) to `path`. False on any failure.
static func write(path: String, data: Dictionary) -> bool:
	var d := data.duplicate(true)
	d["version"] = VERSION
	var tmp := path.get_basename() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveFile: cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	var ok := f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if not ok:
		push_error("SaveFile: store_string failed for %s" % tmp)
		return false
	var a := ProjectSettings.globalize_path(tmp)
	var b := ProjectSettings.globalize_path(path)
	var err := DirAccess.rename_absolute(a, b)
	if err != OK and FileAccess.file_exists(path):
		# Rename over an existing file is not verified on every platform: drop it and retry.
		DirAccess.remove_absolute(b)
		err = DirAccess.rename_absolute(a, b)
	if err != OK:
		push_error("SaveFile: rename failed (%s)" % error_string(err))
	return err == OK

## Reads `path`: {version, meta, run} or {} when there is nothing usable.
static func read(path: String) -> Dictionary:
	var src := path
	if not FileAccess.file_exists(src):
		src = path.get_basename() + ".tmp"
		if not FileAccess.file_exists(src):
			return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(src))
	if not parsed is Dictionary:
		push_warning("SaveFile: %s is broken, kept as save.bad.json" % src)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(src),
			ProjectSettings.globalize_path(path.get_base_dir().path_join("save.bad.json")))
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) > VERSION:
		push_warning("SaveFile: %s is from a newer version, using defaults" % src)
		return {}
	return migrate(d)

## Brings an older file up to VERSION (one step per version; none yet).
static func migrate(d: Dictionary) -> Dictionary:
	return d
