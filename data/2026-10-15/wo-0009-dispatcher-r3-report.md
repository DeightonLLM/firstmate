# WO-0009 dispatcher r3 report

## RED

Command: `bash tests/fm-always-four.test.sh` from the worktree, with the new completed-blocker regression added and before the selector implementation change.

Result: exit 1. Existing assertions passed, then the regression reported `not ok - completed blocked-by prerequisite should make satisfied-ticket eligible, got: <none>`.

## GREEN

Command: `bash /tmp/wt-wo0009-disp-r3/bin/fm-test-run.sh /tmp/wt-wo0009-disp-r3/tests/fm-always-four.test.sh /tmp/wt-wo0009-disp-r3/tests/fm-dispatch-guard.test.sh`.

Result: exit 0; 2 scripts, 0 failures, 0 skipped gates. `fm-always-four.test.sh` passed its selector cases; `fm-dispatch-guard.test.sh` reported `PASS=52 FAIL=0` and `ALL TESTS PASSED`.

The selector now admits a queued ticket when each referenced blocker is in `Done`, reports tickets blocked by open or blocked records as ineligible, and returns a refusal for an unresolved blocker. Both cycle paths stop and emit a coordinator stall event when dependency resolution refuses.

## Full-suite regression run

Command: `bash /tmp/wt-wo0009-disp-r3/bin/fm-test-run.sh --all`.

Result: exit 1; `FM_TEST_SUMMARY total=143 failed=41 skipped_gate=12`. Distinct script-level counts: PASS 90, FAIL 41, SKIP 12. The failing outputs span unrelated runtime/spawn, watcher-path permissions, docs, backend, and tool-environment checks; no failure was reported by the changed selector tests, which passed in the targeted run.

## Other validation

`git diff --check` passed.

`bash bin/fm-lint.sh` did not pass: the canonical lint reported warnings across existing repository files, including existing diagnostics in `bin/fm-always-four.sh` and `tests/fm-always-four.test.sh`; no new diagnostic was reported in the changed lines.

## Fixtures and outcome

Commit: `65ace64f` (`fix: resolve completed dispatcher blockers`) on `wo-0009/dispatcher-r3`; the worktree is clean. No merge, push, or rebase was performed.

Committed fixture data lives under `tests/fixtures/dispatcher-r3/` and covers unblocked, satisfied, unsatisfied, chained, and unresolved dependencies, plus a registered-owner charter-scope match and a ticket with no matching owner.

A satisfied `blocked-by` ticket is now correctly eligible: **yes**.
