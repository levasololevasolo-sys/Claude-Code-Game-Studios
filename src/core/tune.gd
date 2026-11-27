## Reads gameplay values from assets/data/ (ADR-0001). Autoload name: Tune.
## Scalars live in tuning.json (f(), get_value()); tables of rows by id live in
## assets/data/<name>.json (table(), row()), read once and cached.
extends Node

const PATH: String = "res://assets/data/tuning.json"
## Folder of the table files: table("enemies") reads <DATA_DIR>enemies.json.
const DATA_DIR: String = "res://assets/data/"

## The parsed tuning file.
var data: Dictionary = {}
## Parsed tables by name (cache of table()).
var _tables: Dictionary = {}

func _init() -> void:
	reload()

## Reloads the tuning file from disk and drops the table cache.
func reload() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	data = parsed if parsed is Dictionary else {}
	_tables.clear()
	if data.is_empty():
		push_error("Tune: could not read %s" % PATH)

## Returns a number from the tuning file.
func f(key: String) -> float:
	if not data.has(key):
		push_error("Tune: missing key '%s' in %s" % [key, PATH])
		return 0.0
	return float(data[key])

## Returns any value (array, dictionary) from the tuning file.
func get_value(key: String) -> Variant:
	return data.get(key)

## Returns every row of assets/data/<table_name>.json: {id: {...}}. Keys starting
## with "_" (notes) are kept; callers skip them. Read once, then cached.
func table(table_name: String) -> Dictionary:
	if not _tables.has(table_name):
		var path := DATA_DIR + table_name + ".json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			push_error("Tune: could not read table %s" % path)
			parsed = {}
		_tables[table_name] = parsed
	return _tables[table_name]

## Returns one row of a table by id, or {} with an error when it is missing.
func row(table_name: String, id: String) -> Dictionary:
	var t := table(table_name)
	if not t.has(id) or not t[id] is Dictionary:
		push_error("Tune: no row '%s' in table '%s'" % [id, table_name])
		return {}
	return t[id]
