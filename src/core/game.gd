## Game autoload (ADR-0003 § Owner): holds MetaState, the current RunState (or
## null) and its RunRng; loads and writes the current slot file (user://slot_N.json). Systems do not read
## this autoload: the run scene (World + RunDirector) passes state and streams
## to its children. `--fresh` skips reading the save; `--save=<path>` points the
## file elsewhere (checks use it so they never touch the player's save).
extends Node

## Emitted after a save was written (path, ok).
signal saved(path: String, ok: bool)

var save_path: String = "user://save.json"
## True when --save= named the file (checks): no slots, no main menu.
var save_from_args: bool = false
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
			save_from_args = true
	if not save_from_args:
		SaveSlots.migrate_old_save()
		save_path = SaveSlots.slot_path(maxi(1, SaveSlots.last_slot()))
	if not fresh:
		load_save()
	_sync_difficulty()

## Plays slot `i`: a new game wipes it (fresh meta, no run), otherwise its save
## is read. Remembers it as the last slot.
func use_slot(i: int, new_game: bool) -> void:
	save_path = SaveSlots.slot_path(i)
	SaveSlots.remember(i)
	if new_game:
		meta = MetaState.new()
		run = null
		rng = null
		meta_before = {}
		_sync_difficulty()
	else:
		load_save()

## Reads the save file into meta and run (missing/broken -> defaults).
func load_save() -> void:
	var d := SaveFile.read(save_path)
	meta = MetaState.from_dict(d.get("meta", {}) if d.get("meta") is Dictionary else {})
	# A save that won before artifacts existed gets them now (artifacts-and-secrets).
	Artifacts.grant_if_cleared(meta, Tune.table("artifacts"))
	run = null
	rng = null
	if d.get("run") is Dictionary:
		run = RunState.from_dict(d.run)
		rng = RunRng.new(run.run_seed)
		rng.load_states(run.rng_states)
	_sync_difficulty()

## Sets the difficulty (GDD difficulty §3.3): meta, the Difficulty helper and the
## save. Takes effect at once; enemies already spawned keep their hp.
func set_difficulty(id: String) -> void:
	meta.difficulty = Difficulty.normalize(id, Difficulty.table())
	_sync_difficulty()
	write_save()

func _sync_difficulty() -> void:
	Difficulty.current = Difficulty.normalize(meta.difficulty, Difficulty.table())

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
	var summary := { "outcome": outcome, "run": run.to_dict() if run else {}, "bank_before": before,
		"difficulty": Difficulty.current }
	if run:
		meta.embers += run.embers
		for k: String in run.res:
			meta.res[k] = int(meta.res.get(k, 0)) + int(run.res[k])
		meta.best_rooms = maxi(meta.best_rooms, run.rooms_cleared)
		# Горн Сварога pity (gods-expansion §3.12): runs in a row without a forge door.
		meta.svarog_dry = 0 if not run.forge_tiers.is_empty() else meta.svarog_dry + 1
	meta.runs += 1
	# living-world §1.2: the run's fresh events wait for the next base visit.
	var before_bosses: Dictionary = before.get("bosses", {}) if before.get("bosses") is Dictionary else {}
	DialogueRules.record_run(meta, outcome, summary.run, before_bosses, Tune.table("dialogue"))
	StoryRules.record_run(meta, outcome, summary.run, int(Tune.f("story_history_max")))
	# The first full clear grants every artifact (artifacts-and-secrets).
	summary["artifacts_new"] = Artifacts.grant_if_cleared(meta, Tune.table("artifacts"))
	run = null
	rng = null
	summary["bank_after"] = meta.to_dict()
	summary["saved"] = write_save()
	return summary
