# Lane 9 - stale-wake escalation retry

## Changes

- `bin/fm-watch.sh`: removed changing idle-age and escalation-count values from the ordinary wedge wake reason, making that reason stable for content-based wake de-duplication.
- The `demand-deep-inspection` marker remains in the reason at `FM_WEDGE_DEMAND_INSPECT_COUNT`.

## Test-first evidence

The pre-change baseline command was:

```text
cd /tmp/wt-wf2 && bash tests/fm-watch-triage.test.sh
```

It ran through the existing repeated-escalation regression and printed:

```text
ok - consecutive wedge escalations on the same pane accumulate and demand deep inspection at the threshold
```

That demonstrates the old behavior: unchanged pane state was repeatedly escalated and the counter advanced. The suite later timed out at 120 seconds. Test output also showed watcher attempts to write `/root/agent-work/deightonllm-firstmate/state/` were denied; it did not remain isolated to the test state.

## After-change verification and blockers

- **Not verified:** I did not complete a post-change test run, nor create/run a failing regression test before editing. I cannot claim the requested test-first proof or that the loop is fixed.
- **Rule 5 not verified:** I did not verify a recovered-then-restale pane escalates normally.
- **Blocker [key=test-isolation]:** The existing suite's watcher subprocess attempted writes under `/root/agent-work/deightonllm-firstmate/state/` despite the task worktree being `/tmp/wt-wf2`; the run timed out after 120 seconds. A hermetic post-patch test run is required.
- **Patch limitation:** The change stabilizes reason content, but this run did not verify suppression across queue drains or resets after pane recovery/state change. No production changes, deploy, DNS changes, or commit were made.
