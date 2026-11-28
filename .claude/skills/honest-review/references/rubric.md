# Honest Review Rubric

10 categories, 52 criteria, weights summing to 100. Every criterion is scored
**against the benchmark set** (`benchmarks.md`), not against "indie games in
general", not against the team's effort, and not against the previous build.

The default benchmark set is Dead Cells, Skul: The Hero Slayer, Rogue Legacy 2
and Hades, each a **10/10** on the scale below. A project may name another set
in the skill's arguments; the anchors keep their meaning.

## The scale (identical for every criterion)

| Score | Meaning | A reviewer could honestly write... |
|---|---|---|
| **10** | Equals the best of the benchmarks on this criterion | "Nobody in the genre does this better." |
| **9** | Stands beside the benchmarks; one minor gap | "As good as Dead Cells/Hades here, except X." |
| **8** | Clearly good; matches the *weakest* benchmark on this criterion; 2-3 visible gaps | "Strong, but you feel where it is behind." |
| **7** | Solid commercial indie; obviously below the benchmarks | "Good Steam game, not a genre leader." |
| **6** | Competent and generic; nothing to remember | "Works. I would not tell a friend about it." |
| **5** | Functional but flat, or a good design only partly built | "It is there. That is all." |
| **4** | Visible problems: placeholders, prototype feel, missing feedback | "Unfinished." |
| **3** | Broken in places, or mostly missing | "Gets in the way of playing." |
| **2** | Barely present | "Technically exists." |
| **1** | Absent or actively harmful | "Hurts the game." |
| **N/A** | Not observable with the evidence available | Never a guess. |

Half points are allowed (7.5). Nothing above 9.5 is allowed for an unreleased
build: a 10 means a shipped, refined result proven by players.

## Hard caps (apply before anything else)

A cap is a ceiling the evidence sets. A reviewer may go lower, never higher.

| Condition observed | Criteria capped | Cap |
|---|---|---|
| Criterion judged only from design docs, never seen in the build or its code/data | that criterion | 3 (or N/A) |
| Placeholder or programmer art visible on the scored surface | V1, V2, V3, V6 | 4 |
| Mixed art sources that read as different games (e.g. 3D renders beside hand-drawn) | V2, I1 | 5 |
| No music in that context | A1, A2, A3 for that context | 1 |
| Music judged without listening (signal metrics, generation spec only) | A1, A2 | 6, confidence Low |
| Crash, softlock or progression blocker reproduced | T2 | 3 |
| Average FPS below target on the reference scene | T1 | 4 |
| A mechanic exists in code but is unreachable in normal play | that criterion | 4 |
| Only one biome / boss / weapon built | R6 | 3 |
| No tutorialisation of a core verb (dodge, parry, special) | U1 | 5 |
| A dominant build or item found (clearly best in every run) | B2 | 5 |
| Unfair death source found (unreadable attack, offscreen hit, no i-frames on unavoidable damage) | B3, C4 | 5 |
| Text in two languages mixed in the player-facing UI | U2, U5 | 5 |

## Categories and criteria

`W` is the category weight (sum 100). Inside a category criteria are averaged
equally unless marked `x2`.

### 1. Combat and game feel — W 18
| ID | Criterion | What a 10 looks like (benchmark anchor) |
|---|---|---|
| C1 | Control responsiveness | Input-to-action under 3 frames, buffered inputs, cancel windows, coyote time — Dead Cells |
| C2 x2 | Hit feedback and juice | Hit-stop, screen shake, knockback, flash, sound sync on every hit — Dead Cells, Hades |
| C3 | Combat depth and skill ceiling | Dodge, parry, crowd control, positioning and timing all matter — Hades, Dead Cells |
| C4 | Enemy design and telegraphs | Each enemy asks a different question; every attack is readable — Dead Cells |
| C5 x2 | Boss fights | Multi-phase, learnable, spectacular, each a set piece — Hades, Skul |
| C6 | Movement and traversal | Fast, expressive, fun even with no enemies — Dead Cells |
| C7 | Weapon/skill feel differences | Each weapon or form plays like a different game — Skul skulls, Hades aspects |

### 2. Build and systems depth — W 14
| ID | Criterion | What a 10 looks like |
|---|---|---|
| S1 x2 | Build diversity | Many viable archetypes per run — Hades boons, Dead Cells scrolls/colours |
| S2 | Synergy depth | Combinations that create new behaviour, not just bigger numbers — Hades duo boons, Skul inscriptions |
| S3 | Meaningful choice per pick | Every offer is a real trade-off the player thinks about |
| S4 | Identity change inside a run | The character transforms how it plays — Skul skull swap |
| S5 | Class/start variety | Different starts change the run — RL2 classes and traits |
| S6 | System clarity | The player understands what a pick does before taking it |

### 3. Balance and difficulty — W 10
| ID | Criterion | What a 10 looks like |
|---|---|---|
| B1 x2 | Difficulty curve | Steady ramp, spikes only at bosses, early runs teach — Hades |
| B2 | Build balance | No dominant strategy; weak picks still have a niche |
| B3 | Fairness of deaths | Every death is the player's fault and they know why — Dead Cells |
| B4 | Economy (sinks/faucets) | Currencies always have a use; nothing hoarded or starved — RL2 manor |
| B5 | Difficulty customisation | Heat / Boss Cells / House Rules let every skill level play — Hades, RL2 |
| B6 | Enemy and boss number tuning | HP, damage, timings tuned; no sponges, no one-shots outside the design |

### 4. Replayability and progression — W 12
| ID | Criterion | What a 10 looks like |
|---|---|---|
| R1 x2 | Run-to-run variance | Layouts, encounters, offers and routes make each run different — Dead Cells routes |
| R2 | Meta-progression pacing | Each run unlocks something; never a grind wall — RL2, Hades |
| R3 | Long-term goals | 30-100 h of goals: unlocks, bosses, endings, challenges — Hades |
| R4 x2 | "One more run" pull | The player restarts immediately after dying |
| R5 | Run length and pacing | 20-40 min runs with rhythm (fight / reward / rest) |
| R6 | Content volume vs benchmarks | Biomes, enemies, bosses, weapons, items counted against the benchmarks at launch |

### 5. Visual presentation — W 10
| ID | Criterion | What a 10 looks like |
|---|---|---|
| V1 | Art quality | Professional, distinctive — Hades illustration, Dead Cells pixel/3D pipeline |
| V2 x2 | Art cohesion | Every asset reads as one game, one hand, one palette |
| V3 | Animation | Fluid, weighty, readable anticipation and follow-through — Dead Cells |
| V4 | VFX | Hits, spells, deaths look great and stay readable |
| V5 | Combat readability | Player, enemies, attacks and pickups never get lost in the art |
| V6 | Biome and environment identity | Each area is recognisable from one screenshot |

### 6. Audio — W 8
| ID | Criterion | What a 10 looks like |
|---|---|---|
| A1 | Music quality | Composition and production at the level of Darren Korb (Hades) |
| A2 x2 | Music fit to setting and moment | Music *is* the setting; every biome and boss has its own voice |
| A3 | Adaptive music and transitions | Music reacts to combat, boss phases, rooms; seamless crossfades |
| A4 | SFX quality and feedback | Every action has a satisfying, informative sound |
| A5 | Mix and loudness | Nothing masks combat cues; consistent loudness; no fatigue |

### 7. Narrative and world — W 8
| ID | Criterion | What a 10 looks like |
|---|---|---|
| N1 x2 | Story inside the loop | Story advances because you die — Hades |
| N2 | Characters and dialogue | Memorable NPCs with voices, reactive lines |
| N3 | World identity | A setting nobody else has, used consistently |
| N4 | Lore delivery | Found, not lectured; optional depth |
| N5 | Reason to run again (fiction) | The fiction explains the loop — Hades, RL2 lineage |

### 8. Cohesion, uniqueness and hooks — W 8
| ID | Criterion | What a 10 looks like |
|---|---|---|
| I1 x2 | Holistic cohesion | Mechanics, theme, art, music and UI tell the same story |
| I2 x2 | Uniqueness of features | At least one mechanic the benchmarks do not have, and it is central |
| I3 | Strongest hook | The single thing that grabs the most — named and judged on strength |
| I4 | First 10 minutes | The player knows what the game is and wants more within 10 min |
| I5 | Pitchability | The game sells in one sentence and one GIF |

### 9. UX, onboarding and accessibility — W 6
| ID | Criterion | What a 10 looks like |
|---|---|---|
| U1 | Onboarding | Every verb taught by play, never a wall of text |
| U2 | HUD and UI clarity | Health, resources, cooldowns, build state readable at a glance |
| U3 | Menus and flow | Restart, inventory, codex, settings: fast, few clicks |
| U4 | Accessibility | Remapping, assist modes, text size, colour options, screen shake toggle — Celeste/Hades god mode level |
| U5 | Localisation readiness | Strings externalised, no mixed languages, fonts cover the target alphabets |
| U6 | Input devices | Gamepad and keyboard both first-class |

### 10. Technical quality — W 6
| ID | Criterion | What a 10 looks like |
|---|---|---|
| T1 x2 | Performance | Locked target FPS on the reference scene and in the busiest fight |
| T2 x2 | Stability | No crash, softlock or progression bug in the observed runs |
| T3 | Load and restart speed | Death to new run in under 5 s |
| T4 | Save robustness | Saves survive quit, crash and version change |
| T5 | Code health | Architecture lets the fixes below be made without rewrites |

## Computing the score

1. Per criterion: the **median** of the scores the panel gave it (not the mean;
   one generous reviewer must not move it). N/A scores are left out. A
   criterion nobody could score is N/A in the report and its weight is
   redistributed — and the report says how much weight was redistributed.
2. Per category: weighted mean of its criteria (`x2` counts twice).
3. Overall: weighted mean of categories by `W`, **truncated** to one decimal
   (8.68 → 8.6, never rounded up).
4. Report the spread: for every criterion where panel scores differ by more
   than 3 points, both extremes and their evidence are quoted.
5. Gap to target: `target − overall`, plus the five criteria with the largest
   `weight × (9 − score)` — those are where the points are.
