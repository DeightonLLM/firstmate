# Controller watcher stale-heartbeat recovery - interim report

State: needs-decision; Review and Test passed, but the lint gate is blocked by unrelated findings and publication stages remain skipped. This is not a completed delivery.

## Change

Commit `051cd56d9fbf5dc04222946125354f8f9f49f528` on `fm/controller-watcher-heartbeat-recovery` adds exact-child stale-beat monitoring and guarded recovery to `bin/fm-watch-arm.sh`, with disposable regressions in `tests/fm-watcher-lock.test.sh`.

No changes were made to `bin/fm-watch.sh`.

No live controller process, `/root/.pi/agent`, system-ops-owned file, or remote was touched.

## RED

Command: `bin/fm-test-run.sh tests/fm-watcher-lock.test.sh`.

At `2026-10-03T16:16:54Z`, the test runner exited 1 with `not ok - arm left its live but stale watcher in place instead of recovering it (starts=1)`.

This RED is provisional, not yet sufficient TDD evidence: the fixture touched the stale beat before explicitly waiting for the arm to confirm initial health, and the final review found another fixture synchronization race between `watcher-starts` and `helper-$first`.

The final synchronized fixture was not rerun against the pre-fix source, so the initial local RED remains provisional. The no-mistakes fix-round log independently records a `--restart` regression failing with the exact stale live owner still blocking replacement, followed by GREEN after correction.

## GREEN

After implementation and fixture synchronization changes, `bin/fm-test-run.sh tests/fm-watcher-lock.test.sh` exited 0 at `2026-10-03T16:43:43Z`.

It reported passing checks for exact stale-owner recovery with exactly one replacement, no watcher overlap, a fresh replacement heartbeat, preservation of an unrelated live process, and recovery of an exact stopped watcher.

The no-mistakes Test step passed `timeout 300s bash tests/fm-watcher-lock.test.sh` on pipeline head `1f830f960b8a4ea9a37aa3e074211ba7efcb1516`, including a direct production `--restart` drive and adversarial owner-boundary checks. Evidence is in `/home/hd2admin/.no-mistakes/evidence/01M41AHR903VHHMMT2NSHDB49X/fm-watcher-lock-target.log` and `fm-live-restart.log`.

`bin/fm-test-run.sh tests/fm-supervision-events.test.sh` exited 0 at `2026-10-03T16:44:11Z`.

`shellcheck -x bin/fm-watch-arm.sh tests/fm-watcher-lock.test.sh` exited 0, and `git diff --check` exited 0.

Repository-wide `bin/fm-lint.sh` initially exited 1 on unrelated SC2016 findings in `bin/fm-teardown.sh` lines 589 and 592 and SC2006 findings in `bin/fm-brief.sh` lines 272 and 394. The pipeline later corrected the new in-scope SC2015 in `bin/fm-watch-arm.sh`; lint still reports only those four unchanged out-of-scope warnings.

## REFACTOR

The arm's child monitor, stale-owner predicate, and recovery are separated into named helpers.

`wait_owned_child` centralizes child exit monitoring, while `watcher_child_running` distinguishes zombies from live children so a completed child is reaped instead of polled indefinitely.

The focused watcher-lock suite was rerun after this refactor and passed.

## No-mistakes and delivery

No-mistakes run `01M41AHR903VHHMMT2NSHDB49X` completed Review, Test, and Document; its current Lint fix-review head is `9521d751c8adb5b2f002e158fb9b6bd6181185b3`, while the clean local branch remains at `051cd56d9fbf5dc04222946125354f8f9f49f528`.

Test passed on head `1f830f960b8a4ea9a37aa3e074211ba7efcb1516`; Lint remains parked after its correction to the in-scope ShellCheck finding.

Structured `branch_sync.next_action.code` is `continue_active_run`, so I did not run `no-mistakes axi sync` and left branch custody with the active pipeline.

Captain's Option 1 approval from inbox messages 001 and 002 was applied with `no-mistakes axi respond --action fix`, selecting the restart-path finding and both first-round auto-fix findings.

The resolved finding said: “The required criterion says: ‘Fix the recurring Firstmate controller supervision failure where the watcher remains apparently owned but its heartbeat stops advancing, preventing automatic recovery.’ The new recovery at `bin/fm-watch-arm.sh:394-401` only runs when the stale lock PID is this invocation’s `child`; Pi and OpenCode automatically launch the arm with `--restart` (`.pi/extensions/fm-primary-pi-watch.ts:374`, `.opencode/plugins/fm-primary-watch-arm.js:293`), whose existing path sends TERM and waits five seconds but never enters this recovery. If the pipe-blocked watcher survives TERM, the replacement child exits behind the live stale lock and the arm reports failure, leaving the exact reproduced owner in place. Extend the identity/home/path-checked stale-owner escalation into the `--restart` pre-start path, or authorize another shared pre-start recovery boundary; do not broaden it to unrelated live processes.”

The original run still has `push`, `pr`, and `ci` skipped to obey the explicit no-remote-push rule; no remote push or PR creation occurred, and there is no PR URL.

The current Lint finding is `lint-1`, a warning summary with no file/action attribution; the complete output points only to the four unchanged lines in `fm-brief.sh` and `fm-teardown.sh`. I have not approved or skipped the Lint gate.

The captain said skipped push/PR/CI stages are not a green PR outcome, while the task still forbids remote pushes; the captain's message also says a no-skip run needs separate authorization before publication.

The second review raised the new ask-user finding `stale-owner-signal-toctou`: “The review fix round added a TOCTOU signal race: `recover_stale_watcher` verifies ownership at lines 351-353, sends TERM at line 356, and only checks identity afterward at line 358. If the stale watcher exits and its PID is reused, or its heartbeat becomes fresh in that gap, TERM can hit an unrelated or newly valid process; the later check only prevents KILL. This helper is reached from both restart recovery at line 389 and owned-child recovery at line 438. That contradicts the accepted criterion to recover only the exact owner and not signal unrelated processes. Use an owner-bound/atomic signaling mechanism or an equivalent final ownership guard before every signal.”

The other findings are `stale-fixture-helper-read-race`, `stale-fixture-process-leak-on-failure`, `stale-owner-lock-not-reclaimable`, and `watcher-fixture-cleanup-incomplete`; all four were selected for automatic fixes.

Captain's message 004 authorized the bounded TOCTOU fix. I responded in the same run, selecting the three ask-user findings covered by the captain's prior approvals and both current auto-fix findings. Review passed with no findings; Test and Document also passed.

The approved signal-boundary, owner-exit, lock-reclamation, and fixture changes passed Review and Test. Lint remains blocked by unrelated files outside the task's authorized source scope.

Inbox messages 001, 002, 003, and 004 are in the handled directory.

## Residual limitations and next decision

The approved restart recovery, signal-boundary, lock-reclamation, and fixture repairs are in the pipeline head. Review and Test passed; Lint is blocked by unrelated warnings and PR validation is incomplete.

The initial local RED remains provisional. The no-mistakes fix agent later logged a new restart-fixture RED and a focused green result, but the full validation pipeline has not completed.

No-mistakes reports `branch_sync.next_action.code=continue_active_run`; do not sync or edit the branch while the pipeline owns it.

Two decisions are required before completion: authorize or decline the four-line lint cleanup outside the approved source scope, and explicitly authorize or decline a no-skip push/PR/CI run. Until then, do not respond to Lint or begin publication.
