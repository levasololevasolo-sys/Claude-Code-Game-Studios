# Skill Test Spec: /honest-review

## Skill Summary

`/honest-review` scores the built, running game on the 52 criteria in
`references/rubric.md` against a benchmark set (default Dead Cells, Skul,
Rogue Legacy 2, Hades), using a panel derived from `.claude/agents/` minus
other engines' agents. It builds an evidence pack (screenshots, measurements,
content counts), spawns the whole panel in parallel under
`references/honesty-protocol.md`, audits every scorecard (adjustments only go
down), and consolidates by median per criterion with the overall truncated.
Verdicts: `AT TARGET`, `BELOW TARGET`, `NOT ASSESSED`.

## Static Assertions (Structural)

- [ ] Has frontmatter `name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`
- [ ] Has ≥2 phase headings
- [ ] Verdict vocabulary includes `NOT ASSESSED`
- [ ] References `references/rubric.md`, `references/benchmarks.md`, `references/honesty-protocol.md`, `references/agent-panel.md`, and all four exist
- [ ] Panel is derived from `.claude/agents/`, not an allowlist

## Test Cases

### Case 1: Build cannot launch
**Fixture:** a Godot project with no Godot binary on PATH.
**Expected:** Phase 2 records the launch as ABSENT; `SEEN` criteria become `INFERRED` (max 7) or N/A; verdict is `NOT ASSESSED` unless the observed part is already below target.

### Case 2: Inflated scorecard
**Fixture:** an agent scorecard with an 8 on C2 and no benchmark sentence, and an `INFERRED` 9 on S2.
**Expected:** audit lowers C2 to 7 and S2 to 7; both appear in `audit-log.md` with the rule; no score is raised.

### Case 3: New agent added
**Fixture:** a new `.claude/agents/foo-designer.md` not in the criteria map.
**Expected:** it is spawned with the generic brief and listed as `UNMAPPED` in the report.

### Case 4: Godot project panel
**Fixture:** stock 49 agents, `engine.name: Godot`.
**Expected:** 39 agents spawned; the 10 `unity-`/`ue-`/`unreal-` agents listed as dropped for engine.

## Protocol Compliance

- [ ] Never edits game code, data or design docs
- [ ] Never passes one agent's scores into another's brief
- [ ] Report first line holds the verdict and the overall score
