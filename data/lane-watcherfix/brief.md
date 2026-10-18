# Lane 10 - Stale-wake escalation loop, CORRECTED diagnosis (Luna 6, high)

Worktree /tmp/wt-wf3, branch lane/wf3. Parent holds the fleet lock; you will not acquire it.
Expected. Read + WRITE under your worktree. No commit. No fm-session-start.

## A previous patch was REJECTED by the coordinator. Read this so you do not repeat it.
It stabilised the wake reason text, assuming the queue deduplicates on reason content.
**That assumption is false.** It would not have stopped the loop. Do not build on it.

## The REAL mechanism, read from the code
`bin/fm-wake-lib.sh`:

```bash
fm_wake_append() {
  ...
  printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$seq" "$kind" "$clean_key" "$clean_payload" >> "$FM_WAKE_QUEUE"
```

**`fm_wake_append` appends UNCONDITIONALLY. It never suppresses anything.** There is no dedup in it.

Dedup happens LATER, at drain, and by KEY not by payload:

```bash
fm_wake_queued_keys()   # <kind>
  awk -F '\t' -v kind="$kind" 'NF >= 5 && $3 == kind && !seen[$4]++ { print $4 }' "$FM_WAKE_QUEUE"
```

So the loop is: `wedge_timer_check` appends a fresh record every poll, the drain collapses them
only while they sit unconsumed, and once drained the next poll appends again - forever, because the
pane's underlying condition never changes.

## So the fix is a GUARD BEFORE THE APPEND
Before `fm_wake_append stale "$win" ...` in `wedge_timer_check`, do not append when that window is
already queued as a stale key. `fm_wake_queued_keys stale` already exists and returns exactly the
distinct stale keys currently queued. Use it.

## Required behaviour
1. First escalation for a pane fires normally.
2. While the window is already queued as stale, further polls do NOT append a duplicate.
3. Once the drain consumes the record, a still-wedged pane can escalate again - it is no longer
   queued. **This is how rule 5 falls out naturally; do not add a special case that could silence a
   window permanently.**
4. `demand-deep-inspection` at FM_WEDGE_DEMAND_INSPECT_COUNT still works.
5. Never touch the protected primary pane. Never add blanket kills.

## Absolute rules
```
NEVER weaken or delete a guard to make this pass
NEVER suppress the FIRST escalation
NEVER permanently silence a window
do not change global wake or drain semantics - guard inside wedge_timer_check only
no production change, no deploy, no DNS
```

## Deliverables - a patch is mandatory
1. The patch to `bin/fm-watch.sh`.
2. **A test that counts APPENDS, not message text.** Assert that N repeated ticks for one wedged
   window produce 1 queued record. A test asserting on reason strings proves nothing and will be
   rejected.
3. Test-first, both runs pasted: failing before the patch, passing after.
4. Explicit evidence for rule 5: after the record is drained, a still-wedged pane escalates again.
5. `data/lane-watcherfix/report.md`.

A previous lane exited having produced nothing at all. If you are blocked, say so early with a
reason rather than exiting empty-handed.
