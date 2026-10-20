# Lane 10 - stale-wake queue guard

## Change

`bin/fm-watch.sh` now checks the queued stale keys inside `wedge_timer_check` before incrementing escalation state or appending. If this window is already queued, that poll returns without another append. Since the guard consults the durable queue, draining the record naturally makes the window eligible to escalate again. No global append or drain behavior changed.

`tests/fm-watch-triage.test.sh` now counts actual `stale` queue records across four forced wedge ticks, checks that `demand-deep-inspection` remains in the queued payload at threshold, drains the record, then verifies a still-wedged window appends a fresh record. Existing consecutive-escalation fixtures now drain between simulated wake cycles, matching the real consumer boundary.

## Test-first evidence

Before the production patch:

```text
$ cd /tmp/wt-wf3 && bash tests/fm-watch-triage.test.sh
expected 1 queued append after repeated ticks; got 4
exit 1
```

After the patch:

```text
$ cd /tmp/wt-wf3 && bash tests/fm-watch-triage.test.sh
PASS: queued stale append suppressed on repeat ticks, deep-inspection retained, and post-drain re-escalation works
exit 0
```

The suite also passed its existing escalation and busy-turn-age coverage. It emitted permission warnings for attempts by existing watcher instrumentation to write under `/root/agent-work/deightonllm-firstmate/state`; these writes were denied and no primary-pane action was taken.

Additional checks passed: `bash -n bin/fm-watch.sh tests/fm-watch-triage.test.sh`, `shellcheck -S error bin/fm-watch.sh tests/fm-watch-triage.test.sh`, and `git diff --check`.

`bin/fm-lint.sh` was run with its pinned ShellCheck 0.11.0 and exited non-zero on numerous lint findings elsewhere in the repository (including existing findings in `bin/fm-always-four.sh`, `bin/factory-health.sh`, and other files). It also reported pre-existing issues in the touched test/script context; the error-severity ShellCheck check on both changed files passed.

## Scope and safety

Only `bin/fm-watch.sh` and `tests/fm-watch-triage.test.sh` were changed, plus this report. No commit, production change, deployment, DNS operation, blanket kill, or primary-pane operation was performed.
