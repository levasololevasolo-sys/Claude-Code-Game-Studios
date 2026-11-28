# Honesty Protocol

Every reviewer on the panel follows these rules. The parent session enforces
them in the audit phase. A scorecard that breaks a rule is sent back once; if it
still breaks it, the offending score is replaced by the audited score and the
report says so.

## Why this exists

A reviewer that knows its author made the game drifts upward: it grades effort,
intent and potential, it softens every weakness with a compliment, and it scores
the design document instead of the build. Each rule below removes one of those
drifts. The person asking for the review explicitly wants scores that may hurt.

## The rules

1. **Score the build, not the plan.** Design docs show intent. Only what is in
   the running build, or in its code and data, earns points. A feature present
   only in a doc is capped at 3 or marked N/A (see `rubric.md` caps).
2. **Every score cites evidence.** One of: a screenshot path from the evidence
   pack, a log or measurement (FPS, test output, simulation numbers), or
   `file:line` in code or data. "Generally", "seems", "overall feels" are not
   evidence.
3. **Say how you observed it.** Each score carries an observation method —
   `SEEN` (screenshot/run), `MEASURED` (number), `CODE` (read code/data),
   `INFERRED` (reasoned from code, not run) — and a confidence: High / Medium / Low.
   `INFERRED` scores cannot exceed 7.
4. **Start at 5 and earn every point upward.** A new, unreleased game made by a
   small team in weeks starts at 5 on every criterion. Each point above 5 needs
   its own evidence. Each point above 7 needs a named benchmark comparison from
   `benchmarks.md`: "Equal to <game>'s <feature> because <evidence>; still
   missing <gap>."
5. **Steelman down.** For every score of 7 or more, write the strongest
   argument for a score 2 points lower. If the evidence does not refute it,
   take the lower score.
6. **Weakness first.** The scorecard opens with the single weakest point in the
   reviewer's domain, before any strength.
7. **No grading on circumstances.** Team size, budget, time spent, the use of
   AI, "for a prototype", "for an indie" — none of these move a score. The
   comparison is the shipped benchmark.
8. **Banned phrasing** (in any language) unless the next sentence is a measured
   fact: "great potential", "solid foundation", "impressive for", "with some
   polish", "almost there", "very promising", "отличный потенциал", "хорошая
   основа", "впечатляет для", "немного полировки", "почти готово", "очень
   перспективно". A compliment is a claim; it needs evidence like any claim.
9. **N/A is honest; a guess is not.** If the evidence pack cannot show a
   criterion (e.g. music cannot be heard), score N/A or apply the cap for the
   method used, and say what evidence would let it be scored.
10. **Independence.** Reviewers do not see each other's scores or any previous
    review's scores. The parent never passes them in.
11. **Domain discipline.** Score only the criteria assigned to you plus any you
    have direct evidence for. If your domain barely applies to this game (e.g.
    networking in a single-player game), say so and give the few findings you
    have; do not pad.
12. **Fixes are concrete or they are not fixes.** Every fix names: the action
    (FINISH / REWORK / ADD / REMOVE), the system and files, the steps, the
    benchmark it borrows from, effort (S ≤1 day, M ≤1 week, L >1 week),
    and the criterion and expected score lift. "Improve polish" is not a fix.
13. **Consider removal.** Every reviewer lists at least one thing to cut,
    simplify or merge, or states with evidence that nothing in their domain
    should be cut.

## The audit (parent session)

For every returned scorecard the parent checks, mechanically:

| Check | Fails when | Action |
|---|---|---|
| Evidence | a score has no path, number or `file:line` | send back; on second failure, mark the score N/A |
| Method cap | `INFERRED` > 7, doc-only > 3, a rubric cap exceeded | lower to the cap, note it |
| 8+ justification | an 8+ score has no benchmark sentence | lower to 7, note it |
| Steelman | a 7+ score has no steelman-down line | lower by 1, note it |
| Banned phrasing | a banned phrase appears without a measured fact after it | quote it in the audit log |
| Weakness first | the card opens with praise | note it; does not change scores |
| Fix format | a fix lacks action, system, steps, effort or lift | drop the fix from the ranked list, keep it in the appendix |

Every adjustment goes in the report's **Audit log** with the agent, criterion,
original score, audited score and the rule. Adjustments only ever go **down**:
the audit never raises a score.
