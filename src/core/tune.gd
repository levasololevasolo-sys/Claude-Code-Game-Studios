## Reads gameplay values from assets/data/tuning.json. Autoload name: Tune.
extends Node

const PATH: String = "res://assets/data/tuning.json"

## The parsed tuning file.
var data: Dictionary = {}

func _init() -> void:
	reload()

## Reloads the tuning file from disk.
func reload() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	data = parsed if parsed is Dictionary else {}
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
