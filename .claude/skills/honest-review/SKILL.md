---
name: honest-review
description: "Strictly honest, non-flattering scoring of the built game by the whole agent panel against named benchmark games, with concrete fixes, cuts and the gap to a target score."
argument-hint: "[--benchmarks \"Dead Cells,Skul,Rogue Legacy 2,Hades\"] [--target 9] [--agents all|list] [--lang ru|en]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Bash, Agent, AskUserQuestion
---

# Honest Review

Scores the **built, running game** on 52 criteria in 10 categories against a
benchmark set, using every relevant agent in the studio, under a protocol that
forbids grading on effort, intent or potential. When the score is below the
target, every agent says what to finish, how, which system to rework and what
to remove.

Defaults: benchmarks **Dead Cells, Skul: The Hero Slayer, Rogue Legacy 2,
Hades** (each 10/10), target **9**, all derived agents, report language = the
language the user writes in.

References (read them; the parent session needs all four):
- `references/rubric.md` — scale, hard caps, criteria, weights, scoring math
- `references/benchmarks.md` — what each benchmark does best, per criterion
- `references/honesty-protocol.md` — reviewer rules and the audit
- `references/agent-panel.md` — panel derivation, criteria map, brief template

## Verdicts

| Verdict | Meaning |
|---|---|
| `AT TARGET` | Overall ≥ target and no category below target − 1.5 |
| `BELOW TARGET` | Overall < target, or a category below target − 1.5 |
| `NOT ASSESSED` | The build could not be launched and observed, or more than 30% of the rubric weight is N/A |

`NOT ASSESSED` outranks `AT TARGET` and never hides a `BELOW TARGET`: when
the observed part is already below target the verdict is `BELOW TARGET
(partially assessed)` and the report names what was not assessed.

## Phase 1 — Inputs (check before anything else)

Record `FOUND` / `ABSENT` for each:

1. `project.yaml` → `engine.name`, `commands.run`, `commands.test`.
2. The build: the current commit (`git rev-parse --short HEAD`) and whether the
   game launches (Phase 2).
3. Code root and data (`.claude/docs/directory-structure.md`).
4. Audio assets (music, SFX) — list files.
5. Design docs — read for intent only.

If the game cannot be launched, say so, keep going with code/data evidence, and
apply the caps: every `SEEN` criterion becomes `INFERRED` (max 7) or N/A. The
final verdict is then `NOT ASSESSED` unless the observed part is already below
target.

## Phase 2 — Evidence pack

Create `production/qa/honest-review/[YYYY-MM-DD]/evidence/` and fill it. This is
the only view of the game most reviewers get, so cover every rubric category.

1. **Launch and capture** per `.claude/docs/run-and-observe.md` (Godot:
   `--write-movie` with `--quit-after`, never `--headless` for pictures). Capture
   at least: title/menu, hub, every biome (surface and cave if any), a busy
   fight, every boss (each phase if reachable), every choice screen (gods,
   runes, shop, doors), death/results screen, settings. Use any debug launch
   arguments or scenes the project already has; do not add code to the game.
2. **Measure:** FPS on the reference scene and the busiest fight; death → new
   run time; test suite result (`commands.test`).
3. **Simulate** if the project has balance sims or autoplay tools — run them and
   keep the logs. Do not write new game code; a read-only analysis script in
   the evidence folder is fine.
4. **Content count:** biomes, enemies, bosses, weapons, items/boons, NPCs,
   dialogue lines, music tracks — from data files, with paths.
5. **Audio:** list tracks with duration and loudness (e.g. `ffmpeg -af
   ebur128`). State plainly that no reviewer can listen; A1/A2 use the
   "judged without listening" cap unless the user supplies listening notes.
6. Write `evidence-index.md`: one line per file — what it shows, which
   criteria it serves — and a **Not captured** section naming every rubric
   surface with no evidence and why.

## Phase 3 — Panel

Derive the panel (`agent-panel.md`). Fill the brief template for every agent and
spawn **all of them in parallel** (`Agent`, `subagent_type` = the agent name),
in batches if the session limits concurrency. Each writes
`production/qa/honest-review/[date]/agents/[agent].md` — the path this skill
names, so no per-file write prompt is needed.

Never pass one agent's output, the parent's opinion, or an earlier review's
scores into a brief.

If an agent fails or returns nothing, record it as `BLOCKED` by name in the
report and continue; do not re-run it more than once.

## Phase 4 — Audit

Apply the audit table in `honesty-protocol.md` to every scorecard. Send a card
back at most once. Record every adjustment in `audit-log.md`. Adjustments only
lower scores.

## Phase 5 — Consolidate

Compute scores exactly as `rubric.md` says (median per criterion, truncate the
overall). Then build:

1. **Score table:** every criterion — median, min, max, number of scorers, N/A count.
2. **Category scores** and the overall, with the weight that was N/A.
3. **Gap to target:** the five criteria with the largest `weight × (target − score)`.
4. **Where we stand vs each benchmark:** per benchmark, the criteria where
   it is far ahead (≥3 points) and any where we match or beat it.
5. **Strongest hook** (I3) and **most unique feature** (I2) by panel consensus,
   with the votes.
6. **Ranked fix plan:** merge duplicate fixes across agents (keep every
   agent's name on the merged fix); rank by `lift × weight / effort`; group
   into P0 (blocks the target), P1, P2. For each: FINISH / REWORK / ADD /
   REMOVE, how, systems and files, borrowed from, effort, lift.
7. **Cut list:** every proposed removal, with who proposed it and why.
8. **Disagreements:** criteria with a spread > 3 and both sides' evidence.
9. **Projected score** if all P0 fixes land — labelled as a projection, not a score.

## Phase 6 — Report

Write `production/qa/honest-review/[date]/report.md` in the report language,
in this order: verdict and overall score on the first line; what was not
assessed; score table; gap to target; benchmarks comparison; hook and
uniqueness; ranked fix plan; cut list; disagreements; audit log summary; panel
list (spawned, BLOCKED, UNMAPPED, dropped for engine). Ask before writing the
report if the project's collaboration protocol requires it.

The report never contains a banned phrase from `honesty-protocol.md` and never
rounds a score up.
