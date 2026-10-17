# WO-0006 fix lane B landed - necessary, and honestly NOT sufficient

**Correlation:** `controller-wo-0006-capacity-and-six-lane-wave-20261015`
Report: `data/2026-10-15/reap-meta-cleanup-b/report.md`, full text below.

## Landed and pushed

`3277fab5` - "Ignore closed tasks with leftover metadata in fleet snapshot"
```
bin/fm-fleet-snapshot.sh           | 15 +++++++----
tests/fm-reap-meta-cleanup.test.sh | 43 ++++++++++++++++++++++++++
```

**I ran the test myself, in the worker's worktree, with my own hands:**
```
ok - closed backlog tasks with leftover metadata are excluded from current task rows
PASS: 1   FAIL: 0
```
Worker's own runs: `fm-fleet-snapshot-view` PASS=16 FAIL=0, `fm-reap-gate` PASS=17 FAIL=0.

## But it does not fully fix the board, and the worker says so

It filtered tasks whose **backlog state is Done**. The strays that remain are a different kind:

```
decision-hold-gate-diagnosis-20261015   backlog=<no record>  data/=absent  meta=present
system-repair-sprint-0924               backlog=<no record>  data/=present  meta=present
cbd-g5-source-refresh-0924              backlog=<no record>  data/=present  meta=present
```

**A leftover meta file with no backlog record at all cannot be filtered by backlog state.** That needs
endpoint liveness, which is lane A's job and still running.

So the board is *less* wrong, not correct. I am not claiming the defect closed until the board proves it.

## Close paths enumerated by source inspection

1. Regular teardown / `tasks-axi done` - `fm-teardown.sh:515,519,523,525,532`
2. Nested child cleanup in secondmate teardown - `fm-teardown.sh:1506-1508`
3. Automatic reap - `fm-reap-gate.sh:207-218`, delegates to teardown without `--force`
4. Manual direct `tasks-axi done` outside teardown - **none exists in tracked bin/**
5. Worker self-reaping - **none found in tracked code**

Point 4 and 5 are worth noting: the orphan metas are **not** from a code path that skips cleanup. They are
most likely leftovers from before `fm-teardown.sh:1753` did the right thing. A historical residue, not a
live bug in the close path.

# Reap metadata cleanup — lane B report

## Result

**Defect fixed and proven by a regression test that failed before the fix and passed after.** The snapshot now omits structured tasks already marked `Done` from `tasks[]`, even when stale `.meta`, `.status`, and `.turn-ended` files remain. The snapshot remains read-only; it does not delete those files.

## Diff summary

- `bin/fm-fleet-snapshot.sh`: Filter structured `Done` tasks out of the current task projection before inventory checks and secondmate aggregation. Persistent secondmates are retained. Update the output contract comments.
- `tests/fm-reap-meta-cleanup.test.sh`: Add a temp-home regression fixture with a completed backlog item and leftover task files. Assert the snapshot has no task row and keeps the backlog valid; assert snapshot did not mutate the leftover metadata.

## Close paths found by source inspection

1. **Regular task teardown / `tasks-axi done`:** `bin/fm-teardown.sh:515,519,523,525,532` selects and executes the done command for scout, local-only, and PR-based tasks. Both the tasks-axi backend and the manual backlog backend run through this teardown function; the manual Done update is at `bin/fm-teardown.sh:535,588-589`. The canonical state removal is at `bin/fm-teardown.sh:1753-1755`.
2. **Nested child cleanup during secondmate teardown:** `bin/fm-teardown.sh:1506-1508` removes the child's status, turn-ended marker, and metadata.
3. **Automatic reap:** `bin/fm-reap-gate.sh:207-218` delegates to `fm-teardown.sh` without `--force`; its sweep iterates metadata at `bin/fm-reap-gate.sh:236-239`. The session-start sweep calls it at `bin/fm-session-start.sh:356`; the watcher calls it at `bin/fm-watch.sh:1297`.
4. **Manual direct `tasks-axi done` outside teardown:** No such invocation exists in tracked `bin/` source; the grep evidence below shows the only tracked invocations are in `fm-teardown.sh`. An external/manual direct invocation can update the backlog without deleting task files; the snapshot fix prevents that `Done` item being represented as current work. The direct external command itself cannot be made to delete home state from this repository without changing the external `tasks-axi` owner.
5. **Worker self-reaping:** No tracked worker-close implementation was found. The tracked code removes task `.meta` only in `fm-teardown.sh`; workers' terminal status events are not the teardown path. Any out-of-band worker that directly removes state is outside the tracked implementation.

### Verbatim source-search evidence

Command:

```text
grep -nE 'done_cmd=|eval "\$done_cmd"|rm -f "\$STATE/\$ID.status"|rm -f "\$sub_state/\$child_id.status"' bin/fm-teardown.sh; grep -nE 'Delegate exclusively|"\$teardown" "\$id"|if \[ "\$teardown_rc" -eq 0 \]' bin/fm-reap-gate.sh; grep -n 'fm-reap-gate.sh' bin/fm-session-start.sh bin/fm-watch.sh; grep -R -nE 'tasks-axi[[:space:]]+done|rm -f .*\.meta' bin --exclude='*.bak*'
```

Output:

```text
515:        done_cmd="tasks-axi done $ID --report $report_path"
519:          done_cmd="tasks-axi done $ID --note \"local main\""
523:            done_cmd="tasks-axi done $ID --pr $pr"
525:            done_cmd="tasks-axi done $ID --pr PR_URL"
532:    eval "$done_cmd" || printf '%s\n' "warning: tasks-axi done command failed for $ID" >&2
1506:    rm -f "$sub_state/$child_id.status" "$sub_state/$child_id.turn-ended" \\
1753:rm -f "$STATE/$ID.status" "$STATE/$ID.turn-ended" "$STATE/$ID.meta" \\
207:  # Delegate exclusively to bin/fm-teardown.sh WITHOUT --force
218:    "$teardown" "$id" 2>&1) || teardown_rc=$?
220:  if [ "$teardown_rc" -eq 0 ]; then
bin/fm-session-start.sh:356:    "$SCRIPT_DIR/fm-reap-gate.sh" --sweep 2>&1 || true
bin/fm-watch.sh:1297:      "$SCRIPT_DIR/fm-reap-gate.sh" "$task" "$STATE" >/dev/null 2>&1 || true
bin/fm-teardown.sh:515:        done_cmd="tasks-axi done $ID --report $report_path"
bin/fm-teardown.sh:519:          done_cmd="tasks-axi done $ID --note \"local main\""
bin/fm-teardown.sh:523:            done_cmd="tasks-axi done $ID --pr $pr"
bin/fm-teardown.sh:525:            done_cmd="tasks-axi done $ID --pr PR_URL"
bin/fm-teardown.sh:532:    eval "$done_cmd" || printf '%s\n' "warning: tasks-axi done command failed for $ID" >&2
bin/fm-teardown.sh:1753:rm -f "$STATE/$ID.status" "$STATE/$ID.turn-ended" "$STATE/$ID.meta" \\
```

Additional path evidence:

```text
535:  elif fm_backlog_backend_manual "$CONFIG" && [ -f "$backlog_path" ]; then
588:    ' "$backlog_path" > "$backlog_path.tmp" && mv "$backlog_path.tmp" "$backlog_path"
589:    printf 'Backlog: $ID moved to Done in data/backlog.md (manual mode).\n'
1506:    rm -f "$sub_state/$child_id.status" "$sub_state/$child_id.turn-ended" \\
1753:rm -f "$STATE/$ID.status" "$STATE/$ID.turn-ended" "$STATE/$ID.meta" \\
239:    reap_single_task "$task_id" "$STATE"
```

## TDD and test evidence

### RED — before implementation

Command: `bash tests/fm-reap-meta-cleanup.test.sh`

Exact lines from command output:

```text
not ok - closed backlog task was still projected as current work: {
  "schema": "fm-fleet-snapshot.v1",
      "id": "stale-task",
        "state": "unknown",
        "source": "none",
        "detail": "worktree gone (torn down?)",
        "raw": "state: unknown · source: none · worktree gone (torn down?)",
        "state": "done",
        "id": "stale-task",
Command exited with code 1.
```

### GREEN — after implementation

Command: `tests/fm-reap-meta-cleanup.test.sh`

Verbatim output:

```text
ok - closed backlog tasks with leftover metadata are excluded from current task rows
PASS: 1
FAIL: 0
```

### Relevant suites

`tests/fm-fleet-snapshot-view.test.sh` — **PASS=16 FAIL=0 RC=0**:

```text
ok - empty fleet snapshot and view use explicit absence markers
ok - snapshot and secondmate summary preserve 12000 records from a 1692028-byte backlog
ok - fixture snapshot covers task rows, backlog rows, pointers, and stable ordering
ok - main_inventory discloses orphan/unstructured and clears when inventory is consistent
ok - backlog normalization preserves strict roles and resolves every blocker compatibly
ok - snapshot event hints follow reconciled current state
ok - durable fold keeps an open decision past a later unrelated event
ok - a live secondmate endpoint preserves unrelated open decisions
ok - durable captain-held transfer closes the duplicate live status decision
ok - durable fold clears a decision only on a keyed resolution
ok - a completed scout's stale decision surfaces as a report pointer, not pending
ok - a scout still parked at a decision stays pending (terminal clear does not over-fire)
ok - snapshot includes durable scout reports after teardown
ok - snapshot parses tasks-axi rows and respects operational overrides
ok - fleet view renders the snapshot without secondmate peek guidance
ok - fleet view renders secondmate agent liveness
PASS=16 FAIL=0 RC=0
```

`tests/fm-reap-gate.test.sh` — **PASS=17 FAIL=0 RC=0**:

```text
PASS  verified-landed crew is reaped automatically without operator prompt
PASS  verified-landed crew reap was logged
PASS  crew with unlanded work is preserved
PASS  refusal of unlanded crew was logged with reason
PASS  Crisp-R window is preserved and never touched
PASS  Crisp-R protection refusal was logged
PASS  undeterminable landed-work state preserves crew
PASS  undeterminable state refusal was logged
PASS  --sweep reaped landed task and preserved unlanded task
PASS  live crew with absent status file is preserved
PASS  refusal of live crew with absent status was logged
PASS  live endpoint with stale status is preserved
PASS  refusal of live endpoint with stale status was logged
PASS  ambiguous endpoint is preserved
PASS  refusal of ambiguous endpoint was logged
PASS  unverified endpoint is preserved
PASS  refusal of unverified endpoint was logged
PASS=17 FAIL=0
RC=0
```

`tests/fm-teardown.test.sh` was also attempted and **failed** at its tasks-axi reminder assertion (`teardown did not preserve date-gate check`). The observed output included the feature-branch tangle warning and the completion lines below; no teardown files were changed by this test failure. This failure remains unresolved and is not claimed as a pass:

```text
not ok - teardown did not preserve date-gate check: /tmp/fm-teardown-tests.WTLrDe/tasks-axi-reminder/project: already current
teardown task-x1 complete (window firstmate:fm-task-x1, worktree /tmp/fm-teardown-tests.WTLrDe/tasks-axi-reminder/wt)
Backlog: task-x1 just finished. Executing: tasks-axi done task-x1 --pr https://github.com/example/repo/pull/7
Backlog: task-x1 just finished. Executing: tasks-axi ready
Command exited with code 1
```

Syntax/diff checks were run:

```text
bash -n bin/fm-fleet-snapshot.sh tests/fm-reap-meta-cleanup.test.sh && git diff --check
(no output; exit 0)
```

## Closeout status

Commit `3277fab5` (`Ignore closed tasks with leftover metadata in fleet snapshot`) is on branch `fm/reap-meta-cleanup-b`; `git status --short --branch` returned `## fm/reap-meta-cleanup-b`. The snapshot defect is regression-tested. The implementation does not physically delete metadata left by a direct external `tasks-axi done`; it filters those completed records from the current-task projection while preserving the snapshot's read-only contract. The teardown suite's failing reminder assertion remains unresolved, so task completion is not attested.

blocked: [key=reap-meta-validation] Direct external `tasks-axi done` bypasses repository cleanup, and `tests/fm-teardown.test.sh` failed its date-gate reminder assertion; completion requires an owner decision on these acceptance gaps and a passing required validation.


## Wave 1 status

- L1 admission gap (MiniMax high) - running, this gates the most
- L2 ticket 0029 notify route (MiniMax medium) - running
- L3 ticket 0022 audit timer (MiniMax medium) - running
- L4 / L5 / L6 - wave 2, staggered per your per-minute rate limit

Your re-measurement corrected a wrong order of yours and mine. Recorded: 16 cores, load 6.15, ceiling ~6 per
provider. My "0 additional slots" caused a one-lane instruction that should never have been issued.
