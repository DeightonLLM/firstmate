# Fleet view live-actions — blocked, no deliverable

**Status: BLOCKED. No change was made. This file exists only to satisfy the teardown report requirement and to
preserve the blocked state honestly. It is not a completed deliverable.**

## What the task was

Make the active section of `bin/fm-fleet-view.sh` include only genuinely in-flight tasks, show current state
and endpoint, render the existing snapshot actions, separate done/held rows, and test working, done, held and
missing-endpoint fixtures.

## Why it was blocked

The worker could not construct a safe live fixture for a parked task with no pending decision, so the exact
row and steer action could not be verified. No change was committed.

## Findings it did surface (evidence, not fixes)

1. `bin/fm-fleet-snapshot.sh` aborted with `/usr/local/bin/jq: Argument list too long`, printing
   `fm-fleet-snapshot: main inventory summary failed`. Bulk fleet JSON was being passed through the jq command
   argument vector, which the kernel bounds. The snapshot therefore produced NO output at realistic backlog
   sizes, so the fleet view rendered nothing. Independently reproduced by the primary in the home checkout.
   This defect is now being fixed under `fleet-snapshot-jq-resync`.
2. The committed renderer has NO "Needs attention" section at all, so even with a working snapshot the view
   cannot surface blocked, held or parked work. This remains unimplemented and unverified.

## Not done

No fixture, no renderer change, no test, no commit. Both findings above require a fresh dispatch against a
working snapshot before the original task can be attempted.

## Provenance

Recorded by the worker before teardown; see `state/fleet-view-live-actions.status` for its blocked line and
`data/backlog-truth-pass/report.md` for the corroborating fleet-state evidence.
