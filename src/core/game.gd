## Game autoload (ADR-0003 § Owner): holds MetaState, the current RunState (or
## null) and its RunRng; loads and writes user://save.json. Systems do not read
## this autoload: the run scene (World + RunDirector) passes state and streams
## to its children. `--fresh` skips reading the save; `--save=<path>` points the
## file elsewhere (checks use it so they never touch the player's save).
extends Node

## Emitted after a save was written (path, ok).
signal saved(path: String, ok: bool)

var save_path: String = "user://save.json"
var meta: MetaState = MetaState.new()
var run: RunState = null
var rng: RunRng = null
## Meta as it was when the run started (summary «было → стало»).
var meta_before: Dictionary = {}

func _ready() -> void:
	var fresh := false
	for a in OS.get_cmdline_user_args():
		if a == "--fresh":
			fresh = true
		elif a.begins_with("--save="):
			save_path = a.trim_prefix("--save=")
	if not fresh:
		load_save()

## Reads the save file into meta and run (missing/broken -> defaults).
func load_save() -> void:
	var d := SaveFile.read(save_path)
	meta = MetaState.from_dict(d.get("meta", {}) if d.get("meta") is Dictionary else {})
	run = null
	rng = null
	if d.get("run") is Dictionary:
		run = RunState.from_dict(d.run)
		rng = RunRng.new(run.run_seed)
		rng.load_states(run.rng_states)

## Writes meta and the run snapshot (with stream states). Points of writing:
## haven entry, end of run (ADR-0003); never mid-room.
func write_save() -> bool:
	if run and rng:
		run.rng_states = rng.save_states()
	var ok := SaveFile.write(save_path, { "meta": meta.to_dict(), "run": run.to_dict() if run else null })
	saved.emit(save_path, ok)
	return ok

## Starts a new run on `run_seed` (does not save: the first save is the haven).
func start_run(run_seed: int) -> RunState:
	run = RunState.new()
	run.run_seed = run_seed
	run.hp = Tune.f("player_hp")
	run.max_hp = Tune.f("player_hp")
	rng = RunRng.new(run_seed)
	run.gap_need = DoorRules.roll_gap(rng.stream("doors"), Tune.data)
	meta_before = meta.to_dict()
	return run

## economy-and-meta §3.7 endRun: banks the run's loot, counts the run, clears
## the run snapshot, writes the save. Returns the summary data.
func end_run(outcome: String) -> Dictionary:
	var before := meta_before if not meta_before.is_empty() else meta.to_dict()
	var summary := { "outcome": outcome, "run": run.to_dict() if run else {}, "bank_before": before }
	if run:
		meta.embers += run.embers
		for k: String in run.res:
			meta.res[k] = int(meta.res.get(k, 0)) + int(run.res[k])
		meta.best_rooms = maxi(meta.best_rooms, run.rooms_cleared)
	meta.runs += 1
	# living-world §1.2: the run's fresh events wait for the next base visit.
	var before_bosses: Dictionary = before.get("bosses", {}) if before.get("bosses") is Dictionary else {}
	DialogueRules.record_run(meta, outcome, summary.run, before_bosses, Tune.table("dialogue"))
	run = null
	rng = null
	summary["bank_after"] = meta.to_dict()
	summary["saved"] = write_save()
	return summary
