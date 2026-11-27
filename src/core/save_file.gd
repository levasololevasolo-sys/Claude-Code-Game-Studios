## The save file (ADR-0003 § File): one versioned JSON, written to a temp file
## and renamed over the real one. A missing, broken or newer file reads as
## defaults with a warning; a broken file is kept as save.bad.json.
class_name SaveFile
extends RefCounted

## 2: armor, armor_pick, up, lanterns, lantern, story in meta (base hub).
## 3: story wiring fields in meta.story (StoryRules: gods_seen, death_streak,
## history...) and story_ev / needle in the run snapshot.
const VERSION: int = 3

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

## Brings an older file up to VERSION, one step per version. 1 -> 2 fills the
## base fields (armor at tier 0, no Капище rules, the free ring, empty story);
## 2 -> 3 the story wiring fields.
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var v := int(out.get("version", 1))
	if v < 2:
		var meta: Dictionary = out.get("meta", {}) if out.get("meta") is Dictionary else {}
		var base := MetaState.defaults()
		for k: String in ["armor", "armor_pick", "up", "lanterns", "lantern", "story"]:
			if not meta.has(k):
				meta[k] = base[k]
		out["meta"] = meta
		v = 2
	if v < 3:
		# 2 -> 3: the story wiring fields; a v2 file never had a prologue, so a
		# save with finished runs counts it as seen (no prologue mid-game).
		var meta3: Dictionary = out.get("meta", {}) if out.get("meta") is Dictionary else {}
		var st: Dictionary = meta3.get("story", {}) if meta3.get("story") is Dictionary else {}
		var sd := MetaState.story_defaults()
		for k: String in sd:
			if not st.has(k):
				st[k] = sd[k]
		if int(meta3.get("runs", 0)) > 0:
			var fl: Dictionary = st.get("flags", {}) if st.get("flags") is Dictionary else {}
			fl["prologue_seen"] = true
			st["flags"] = fl
		meta3["story"] = st
		out["meta"] = meta3
		if out.get("run") is Dictionary:
			var r: Dictionary = out.run
			if not r.has("story_ev"):
				r["story_ev"] = []
			if not r.has("needle"):
				r["needle"] = false
		v = 3
	out["version"] = v
	return out
