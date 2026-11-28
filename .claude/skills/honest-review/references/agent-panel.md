# Agent Panel

## Deriving the panel (do not hand-pick)

The panel is **every agent file in `.claude/agents/`**, minus the agents of
engines the project does not use. Derive it each run:

```bash
ls .claude/agents/*.md | xargs -n1 basename | sed 's/\.md$//'
```

then drop, by `engine.name` from `project.yaml`:

| engine.name | Drop agents whose name starts with |
|---|---|
| Godot | `unity-`, `ue-`, `unreal-` |
| Unity | `godot-`, `ue-`, `unreal-` |
| Unreal | `godot-`, `unity-` |
| Web | `godot-`, `unity-`, `ue-`, `unreal-` |

The run's report lists the derived panel and the dropped agents by name, so a
new agent added to the repo is reviewed by default. With the stock 49 agents a
Godot project gets **39**.

An agent that is in the derived panel but not in the map below is still spawned
with the generic brief and the criteria `I1, I3, R4` plus "your domain", and the
report marks it `UNMAPPED`.

## Criteria map

Primary criteria each agent must score. Agents may score others with evidence.

| Agent | Primary criteria | Domain question it must also answer |
|---|---|---|
| creative-director | I1, I2, I3, I4, I5, N3, V2 | Is this a game with one identity? What is the one thing to protect, and what dilutes it? |
| technical-director | T1, T2, T5, T3 | What technical risk blocks a 9? |
| producer | R6, R5, I4 | What is the shortest path to 9: scope, order, cuts? |
| game-designer | C3, S1, S3, R1, R4, B1, R5 | Which core loop pieces are weaker than the benchmarks and why? |
| systems-designer | S1, S2, S3, S4, S6, B2 | Which synergies are real, which are just numbers? Any dominant build? |
| level-designer | R1, C6, R5, V6, B1 | Do rooms and routes create decisions and rhythm? |
| economy-designer | B4, R2, B2 | Sinks vs faucets, grind walls, prices — with numbers. |
| ux-designer | U1, U2, U3, I4, S6 | Where does the player get lost or confused? |
| live-ops-designer | R3, R4, B5 | What keeps a player for 30+ h (daily runs, challenges, unlocks)? |
| narrative-director | N1, N2, N3, N5, I1 | Does the story make dying meaningful the way Hades does? |
| writer | N2, N4, U5 | Quality of the actual lines in the build. |
| world-builder | N3, N4, I2 | Is the setting used consistently and is it distinct? |
| art-director | V1, V2, V5, V6, I1 | Does the art read as one game? What is off-model? |
| technical-artist | V4, V3, V5, T1 | Shaders/VFX quality and cost; readability in busy fights. |
| audio-director | A1, A2, A3, A5, I1 | Does the music fit the setting and each moment? |
| sound-designer | A4, A5, C2 | Does every action sound right and inform the player? |
| lead-programmer | T5, T2, C1 | Can the fixes be built on this code without rewrites? |
| gameplay-programmer | C1, C2, C6, C7, B3 | Input, hit feedback, cancels, i-frames — measured. |
| ai-programmer | C4, C5, B3, B6 | Do enemies and bosses behave readably and fairly? |
| engine-programmer | T1, T3, T4 | Loading, scene changes, memory. |
| ui-programmer | U2, U3, U6 | HUD and menus as implemented. |
| tools-programmer | T5, R6 | Does the content pipeline let the team scale content to benchmark volume? |
| network-programmer | R3, R4 | Online features that would help (daily seed leaderboard, co-op) — or state none apply. |
| performance-analyst | T1, T3 | FPS in reference and worst scenes, with numbers. |
| qa-lead | T2, B3, T4 | Release-quality gate: blockers by severity. |
| qa-tester | T2, U3, B3 | Concrete bugs found in the evidence, with repro. |
| prototyper | I4, R4, I3 | Strip everything: is the core loop fun on its own? |
| accessibility-specialist | U4, U6, V5 | Options vs Hades God Mode and RL2 House Rules. |
| localization-lead | U5 | Hardcoded strings, mixed languages, font coverage. |
| release-manager | I5, R6, T2 | Could this ship on Steam today? What blocks the store page? |
| devops-engineer | T2, T5 | Build reproducibility, CI, tests on every push. |
| analytics-engineer | R4, B1 | What telemetry is needed to prove the next balance pass? |
| security-engineer | T4 | Save tampering and integrity; single-player risk is low — say so. |
| community-manager | I3, I5, I2 | What would players praise and complain about in the first week of reviews? |
| godot-specialist | T5, T1, T3 | Godot-specific architecture problems in the build. |
| godot-gdscript-specialist | T5, T2 | GDScript quality: typing, signals, hot-path cost. |
| godot-shader-specialist | V4, V2, T1 | Shader look and cost. |
| godot-csharp-specialist | T5 | Is any part worth moving to C#? Usually: no — say so. |
| godot-gdextension-specialist | T1, T5 | Is any hot path worth native code? Usually: no — say so. |

## Brief template (fill per agent; spawn all in parallel)

```
You are <agent> on an honest-review panel for <game> at commit <sha>.
Benchmarks (each 10/10): <benchmark list>. Target: <target>/10.

Read first, in full:
- .claude/skills/honest-review/references/honesty-protocol.md
- .claude/skills/honest-review/references/rubric.md (scale, caps, your criteria)
- .claude/skills/honest-review/references/benchmarks.md
- <evidence-dir>/evidence-index.md, then the screenshots and logs it lists that
  touch your criteria (Read renders PNGs).
Then read the code/data your domain needs. Do NOT read design docs to score —
only to know intent. Do NOT read any other review or earlier scores.

Your primary criteria: <IDs>. Domain question: <question>.

Write your scorecard to <out-dir>/agents/<agent>.md in <language>, exactly:

# <agent> — scorecard
## Weakest point
<one paragraph, evidence>
## Scores
| ID | Score | Method | Confidence | Evidence | Benchmark comparison (8+) | Steelman down (7+) |
## Domain question
<answer>
## Fixes
| # | Action (FINISH/REWORK/ADD/REMOVE) | What | How (systems, files, steps) | Borrow from | Effort S/M/L | Criterion → lift |
## Cut list
<at least one item, or evidence that nothing should be cut>
## Not assessed
<criteria you could not score and the evidence that would let you>

Do not edit game code, data or docs. Write only your scorecard file.
```
