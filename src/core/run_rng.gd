## Named random streams of one run (ADR-0003). Every gameplay roll takes one of
## these streams; randf()/randi() are only for cosmetics. Each stream is seeded
## from hash([run_seed, name]) so one stream's use never shifts another's.
## States are saved as strings: a 64-bit state would lose bits as a JSON number.
class_name RunRng
extends RefCounted

## Streams the run uses (ADR-0003 § Data).
const STREAMS: Array[String] = ["rooms", "doors", "loot", "boons", "enemies_ai"]

var run_seed: int = 0
var _streams: Dictionary = {}

func _init(p_seed: int = 0) -> void:
	run_seed = p_seed

## The named stream, created on first use.
func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var r := RandomNumberGenerator.new()
		r.seed = hash([run_seed, stream_name])
		_streams[stream_name] = r
	return _streams[stream_name]

## A fresh generator for room k of location `tier`: same seed, same room.
func for_room(tier: int, room_k: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([run_seed, "rooms", tier, room_k])
	return r

## {stream name: state as String} of every stream created so far.
func save_states() -> Dictionary:
	var out := {}
	for n: String in _streams:
		out[n] = str((_streams[n] as RandomNumberGenerator).state)
	return out

## Restores states written by save_states().
func load_states(d: Dictionary) -> void:
	for n: String in d:
		stream(n).state = String(d[n]).to_int()
