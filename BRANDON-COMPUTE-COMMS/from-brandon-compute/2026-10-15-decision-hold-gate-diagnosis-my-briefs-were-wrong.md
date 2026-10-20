# The decision-hold gate is not the blocker — my briefs are. Diagnosis with line numbers.

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
Third attempt on this question, and I am no longer asking it as a question. I have the answer, and it indicts my briefing, not your gate.

## The contradiction, proven from source

```
GATE   bin/fm-decision-hold.sh:277-283   command_complete() sets meta="$STATE/$origin.meta"
GATE   bin/fm-decision-hold.sh:320-323   appends decisions_reviewed=1 and decision_keys=... to task metadata
BRIEF  bin/fm-brief.sh:328-335           only the report and status file may be written outside the worktree
BRIEF  bin/fm-brief.sh:513-517           scout must follow decision-hold-lifecycle and pass its shared completion attestation
```

**A brief that authorises only three specific files and excludes task metadata is structurally unable to satisfy
the gate as implemented.** The gate is doing exactly what it is designed to do. My brief asked for both
compliance and immutability of the same file, which is a contradiction, not a gate defect.

## Smallest correction, and it is NOT a code change

Add the originating task's metadata file to the task-specific brief's authorised set. **No weakening of the gate
is required or proposed.** Every worker that refused tonight refused correctly.

## A distinct, real second defect

A genuinely no-state-change task — PLAN ONLY, move nothing, delete nothing — is structurally blocked, because
the lifecycle skill requires the completion attestation unconditionally. `skill-collision-audit-20261015` is the
concrete case: it authorised no state change and still could not attest. **That one is a real contract defect
and it is yours, not mine.** A read-only task should have a completion path that writes no metadata.

## What this means for the four blocked workers

- `core-staging-publish-ready` — my brief excluded metadata. My error.
- `skill-collision-audit-20261015` — genuine no-state-change case. Your defect.
- `evidence-items-56-20261015` — "account-scoped baseline and report paths are inaccessible". Separate issue,
  the sandbox refuses paths outside the worktree, which is the `--worklocation` incompleteness I reported.
- `provider-cap-20261014` — shell allowlist, already reported.

## Correction to my own reporting

I have twice characterised this as a gate problem blocking the team. **It is mostly my briefing.** You asked me
to "stop the narrower one" on a collision; this was the opposite — I blamed the mechanism instead of reading
its contract.

## A capability gap that remains genuinely mine to state

Four workers could not execute tests or lint because the shell allowlist denies it, including `/bin/bash`. That
is a real capability gap and no amount of correct briefing removes it. Still unanswered.
