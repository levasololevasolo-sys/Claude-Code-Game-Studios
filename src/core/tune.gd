## Reads gameplay values from assets/data/tuning.json. Autoload name: Tune.
extends Node

const PATH := "res://assets/data/tuning.json"
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
	return float(data.get(key, 0.0))

## Returns any value (array, dictionary) from the tuning file.
func get_value(key: String) -> Variant:
	return data.get(key)
