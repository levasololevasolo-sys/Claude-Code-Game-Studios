# Audio pass 1 — evidence (2026-11-27)

Branch `audio-pass`. Design: design/references-and-feel.md (combat must feel weighty).
Clips: `assets/audio/sfx/*.wav`, synthesised by `tools/asset-pipeline/audio/build_sfx.py`
(stdlib only, fixed seeds, mono 44.1 kHz 16-bit, -1 dBFS, 2 ms / 10 ms fades). Licence: in-house,
CC0-equivalent (`assets/provenance.yaml`). Playback: `Audio` autoload `src/core/audio.gd`; volumes,
pitch spread, cooldowns, pools in `assets/data/audio.json`; buses Master/SFX/Music/UI in
`default_bus_layout.tres`.

## Sounds and triggers

| audio.json id | File(s) | Trigger | Hook |
|---|---|---|---|
| swing | swing_1/2/3 (by combo step) | side/up/down strike starts | `Events.hero_acted(&"swing", combo)` — new emit in player `_update_attack` |
| hit | hit_flesh_1/2/3 (random), positional | strike lands, not finisher | existing `Player.hit_landed` |
| hit_heavy | hit_heavy, positional | strike lands on the last combo step (side) | `Player.hit_landed` + combo == weapon.times().size() |
| wall_slam | wall_slam, positional | enemy knocked into a wall (Hit.Kind.WALL); breakable wall broken | existing `Enemy.damaged`, `BreakableWall.broke` |
| ground_slam | wall_slam | down strike slams the ground | `hero_acted(&"ground_slam")` — new emit in `_slam` |
| pogo | pogo | down strike bounces off a foe | `hero_acted(&"pogo")` — new emit in `_strike_hits` |
| roll / dash | roll / dash | ground roll / air dash starts | `hero_acted(&"roll"/&"dash")` — new emit at dash start |
| jump | jump | jump leaves the ground | `hero_acted(&"jump")` — new emit |
| land | land (pitch by weight) | landing with weight >= land_min 0.35 | `hero_acted(&"land", land)` — new emit |
| hero_hurt | hero_hurt | hero loses hp | existing `Events.player_hurt` |
| enemy_death | enemy_death, positional | enemy hp reaches 0 | existing `Events.enemy_killed` |
| amulet_tick | amulet_tick (pitch rises with charge) | amulet charge crosses each 10 | polled `player.amulet.charge` |
| flare | flare | Flare released | existing `Events.flare_fired` |
| rune_chime | rune_chime | rune taken | existing `Events.rune_taken` |
| door_open | door_open | room doors open; chest opened (pitch x1.3) | existing `RunDirector.doors_opened`, `Chest.opened` |
| ember_pickup | ember_pickup | run embers increase | polled `RunDirector.run.embers` |
| boss_roar | boss_roar | boss wakes; boss enters "roar" state | existing `Enemy.woke` + polled `st` |
| ui_move | ui_move | focus change, shop hover, d-pad/arrows while a choice screen is open | `gui_focus_changed`, `hovered`, `_input` |
| ui_confirm | ui_confirm | choice screen `chosen` / `closed` | existing screen signals |

Gameplay edits: one new signal in `src/core/events.gd` (`hero_acted`) and six single
`Events.hero_acted.emit(...)` lines in `src/player/player.gd`; no logic changed.

## Check output (2026-11-27, Godot 4.7.2)

- `godot --headless --path . --import | grep -E "SCRIPT ERROR|Parse Error|Compile Error"`: empty.
- gdUnit: `Overall Summary: 306 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`, `Exit code: 0`
  (new `tests/unit/core/audio_test.gd`: 7 cases, all PASSED).
- run-check (xvfb, gl_compatibility): `[run-check] DONE: 0 failed checks`, 0 SCRIPT ERROR. Only
  `ERR_CANT_OPEN` from ALSA (no sound device in the cloud box). A first run showed
  "1 resources still in use at exit"; fixed by releasing cached streams in `Audio._exit_tree`.

Not verified: how the sounds actually sound in play. The cloud box has no audio device, so
mix levels in audio.json are starting values for the developer to tune by ear.
