# SFX coverage «Навь» (second sound pass)

Source of truth for ids: `assets/data/audio.json`. Files: `assets/audio/sfx/*.wav`, built by
`tools/asset-pipeline/audio/build_sfx.py` (first pass, stdlib) + `sfx_pass2.py` (numpy).
Rebuild: `python3 tools/asset-pipeline/audio/build_sfx.py --reel production/qa/evidence/sfx-reel.wav`.
Wiring: `src/core/audio.gd` (autoload Audio), plus one line in `src/base/shop_screen.gd` (buy / error).
Unknown ids are ignored silently. Every id has a bus (SFX / Music / UI), so the settings
sliders govern everything; ambient beds go to Music. Anti-spam: per-id `cd` and per-id
voice limit `max` (default `voice_limit` 3); polled world sounds farther than `hear_radius`
from the hero are skipped. Random pitch spread `pitch` (mostly ±5 %).

Status: **had** = first pass, **new** = this pass, **re-skinned** = id kept, new file,
**reserved** = sound exists, nothing in the game triggers it yet.

## Hero

| Event | Hook | Id | Status |
|---|---|---|---|
| swing 1-3 | `hero_acted swing` | `swing` (3 files) | had |
| hit / finisher | `hit_landed` | `hit` (3) / `hit_heavy` | had |
| sub-weapon hit | `sub_landed` | `hit` pitched up | new hook |
| jump / land | `hero_acted` | `jump` / `land` | had |
| roll / dash / pogo / ground slam | `hero_acted` | `roll` `dash` `pogo` `ground_slam` | had |
| footsteps | poll `run_ph` half-cycles on floor | `step_mud` / `step_dirt` / `step_snow` / `step_wood` (3 each, by location) | new |
| hurt | `Events.player_hurt` | `hero_hurt` | had |
| death | `died` | `hero_death` | new |
| revive | `revived` | `hero_revive` | new |
| weapon swap | `weapon_changed` | `weapon_swap` | new |
| weapon pick-up / compare card | WeaponDrop `taken` / `near` | `weapon_pickup` / `ui_card_deal` | new |
| parry hit / miss | called by parry code | `parry_clang` (2) / `parry_whiff` | new |

## Amulet and flare

| Event | Hook | Id | Status |
|---|---|---|---|
| charge tick | poll charge | `amulet_tick` | had |
| ready | `became_ready` | `amulet_ready` | new |
| overcharge cap | `capped` | `amulet_overcharge` | new |
| crack / spill | `spilled` | `amulet_crack` | new |
| fizzle | `fizzled` | `flare_fizzle` | new |
| flare | `Events.flare_fired` | `flare` | had |
| ember pickup | poll `run.embers` | `ember_pickup` | had |

## Enemies (poll `st` changes, map `states` in audio.json)

| Kind | State -> id | Status |
|---|---|---|
| any | wake: `enemy_wake`; death: `enemy_death` (3 files) | new / re-skinned |
| crawler | wind `growl_small`(2), leap / charge `lunge_whoosh`(2) | new |
| bat | swoop `bat_screech`, spitwind `spit_wind` | new |
| bloat | swell `bloat_swell`, death `bloat_burst` | new |
| jelly (cold spirit) | chill_w `frost_charge` | new |
| knight | wind `knight_windup`, lunge `lunge_whoosh`, guard `shield_raise` | new |
| ringer | call `bell_ring`, appear `spirit_appear`, gone `spirit_vanish`, swipe `claw_swipe` | new |
| rootling | dig `dig_dirt`, burst `dirt_burst` | new |
| sentry | aim `bow_draw`, bash `shield_bash` | new |
| wolf | crouch `wolf_growl`, bite `bite_snap` | new |
| shielded block (0 dmg strike) | `shield_block` | new |
| enemy shot / fire trail spawn | `shot_fire` / `fire_whoosh` | new |
| limbs (arm / head / part lands) | called by limb code: `limb_sever`(2), `limb_head_pop`, `limb_part_thud`(2) | new |

## Bosses

| Boss | State -> id | Status |
|---|---|---|
| all | wake / roar `boss_roar`, death `boss_death`, summon_w `boss_summon` | had / new |
| kikimora | roar `boss_roar`, lunge `lunge_whoosh` | had / new |
| likho | gaze `likho_gaze`, dark `darkness_fall`, blink `spirit_vanish`, leap / lunge `lunge_whoosh` | new |
| morena | breath_w `frost_charge`, breath `frost_breath`, scythe_w `scythe_windup`, scythe `scythe_swing`, dive `dive_whoosh`, stuck `heavy_thud` | new |

## World

| Event | Hook | Id | Status |
|---|---|---|---|
| doors open | `doors_opened` | `door_open` | had |
| near fork door | Door `near` | `ui_door_near` (pitch by door type) | new |
| chest | `opened` | `chest_open` | new (was door_open pitched) |
| trap warn / fire | Trap `phase` | `trap_warn`, `trap_spikes` / `trap_log` | new |
| breakable wall hit / break / wall slam | `damaged` / `broke` | `wall_crack` / `wall_slam` | new / had (break was never hooked: walls are enemies) |
| rune taken | `Events.rune_taken` | `rune_chime` | had |
| god voice over cards | screen `voice_god` | `god_voice` (pitch per god) | new |
| base gate | Base `gate_used` | `gate_whoosh` | new |
| base station near | Station `near` | `ui_door_near` low | new |
| knight reward / reward orb | — | `reward_take` | reserved (no signal yet) |

## Ambient loops (Music bus, 36 s, seamless, cross-fade 1.5 s on `room_started`)

`amb_swamp`, `amb_forest`, `amb_frost` (by location `lib`), `amb_base` — new.

## UI (ui-style-guide §10.2; map `screens` in audio.json)

| Screen | Open | Hover | Confirm / close |
|---|---|---|---|
| any Button / Slider / focus | — | `ui_hover_wood` | `ui_confirm_gold`, `ui_cancel_wood` for «Назад/Продолжить/Нет/Отмена» |
| PauseMenu | `ui_open_wood` | focus | `ui_close` |
| SettingsScreen | `ui_open_wood` | focus | `ui_close`; tab `ui_tab_switch`; rebind `ui_rebind_wait` loop |
| RuneOfferScreen / GodChoiceScreen | `ui_open_god` + `ui_card_deal` per card | `ui_thread_run` | `ui_rune_select` |
| DifficultyChoiceScreen | `ui_menu_start` + deal | `ui_hover_wood` | `ui_confirm_gold` |
| RunSummaryScreen | `ui_thread_snap` (dead) / `ui_victory_swell` (win) + `ui_count_tick` x8 | button hover | `ui_confirm_gold` |
| ShopScreen | `ui_shop_knock` | `ui_hover_wood` | buy `ui_forge_buy`, refused `ui_error_clank`, `ui_close` |
| DialogueBox | `ui_bark_unroll` | option hover | `ui_confirm_gold`, `ui_close` |
| StoryCard / StoryScene steps | `ui_page_turn` | — | `ui_close` |
| HeroBark | `ui_text_tick` | — | — |
| codex | `ui_codex_new` | reserved (no codex screen yet) | |
| page turn in codex tabs | `ui_page_turn` | reserved | |

`ui_move` / `ui_confirm` (first pass) now play the wood / gold files.

## Listening reel

`production/qa/evidence/sfx-reel.wav` (124 s, 0.4 s gaps, 6 s of each loop), order:

ui_hover_wood, ui_open_wood, ui_close, ui_cancel_wood, ui_confirm_gold, ui_error_clank, ui_open_god,
ui_card_deal, ui_rune_select, ui_thread_run, ui_bark_unroll, ui_text_tick, ui_shop_knock, ui_forge_buy,
ui_page_turn, ui_tab_switch, ui_count_tick, ui_thread_snap, ui_victory_swell, ui_door_near, ui_codex_new,
ui_rebind_wait, ui_menu_start, limb_sever_1, limb_sever_2, limb_head_pop, limb_part_thud_1,
limb_part_thud_2, parry_clang_1, parry_clang_2, parry_whiff, enemy_death_2, enemy_death_3, step_mud_1-3,
step_dirt_1-3, step_snow_1-3, step_wood_1-3, hero_death, hero_revive, weapon_swap, weapon_pickup,
amulet_ready, amulet_overcharge, amulet_crack, flare_fizzle, enemy_wake, wolf_growl, bite_snap,
claw_swipe, bat_screech, spit_wind, bloat_swell, bloat_burst, frost_charge, frost_breath, knight_windup,
shield_raise, shield_block, shield_bash, bell_ring, spirit_appear, spirit_vanish, dig_dirt, dirt_burst,
bow_draw, shot_fire, fire_whoosh, boss_summon, boss_death, likho_gaze, darkness_fall, scythe_windup,
scythe_swing, dive_whoosh, heavy_thud, chest_open, trap_warn, trap_spikes, trap_log, wall_crack,
reward_take, gate_whoosh, god_voice, growl_small_1, growl_small_2, lunge_whoosh_1, lunge_whoosh_2,
amb_swamp, amb_forest, amb_frost, amb_base.

## Known gaps

- Nothing has been heard on speakers yet: the cloud box has no audio device. Levels are set by ear-less
  reasoning (UI -12 dB, hover -18 dB per §10.1); a listening pass on the reel is needed.
- Summary count ticks are a fixed burst of 8; the screen does not animate the count yet.
- `ui_codex_new`, `reward_take` are reserved until their screens / signals exist.
