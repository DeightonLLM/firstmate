# Reaped agents 2026-10-15

Preserved before closing. All were idle with no live work; none produced a landable result.

## clear-closeout-20261013
- backlog: queued
- report: absent
- last status: blocked: To-Do List extension unavailable or incomplete

## worklocation-reland-20261014
- backlog: in_flight
- report: absent
- last status: 

## provider-cap-20261014
- backlog: in_flight
- report: absent
- last status: blocked: bash is denied by the execution allowlist; required tests and lint cannot run

## offload-backlog-close-2-20261014
- backlog: in_flight
- report: present
- last status: blocked: tasks-axi list refused by shell allowlist (exit 126); no retry or entries closed; report written

## brief-worklocation-template-fix
- backlog: in_flight
- report: present
- last status: captain-held [key=default]: tracked by brief-worklocation-template-fix-decision-default


## baseline-root-fix-20261015 (M3.1, ship)
- verdict: DONE, reviewed by firstmate, landed and pushed as d89b84d7
- tests: tests/fm-fresh-baseline.test.sh ALL TESTS PASSED, run by firstmate
- GAP: worker wrote no report.md
- status: done: ready in branch fm/baseline-root-fix-20261015

## baseline-scope-tests-20261015 (Luna 6, ship)
- outcome: FAILED TO DELIVER — ended without touching tests, no report.md
- firstmate completed the test rewrite inline instead
- status: 

## durable-docs-20261015 (Luna 6, ship)
- outcome: FAILED TO DELIVER — pane reached 'done', no docs, no report, no status line
- pattern: THIRD worker this session to end without producing work
- prior: baseline-scope-tests-20261015 (same), provider-cap-20261014 (shell denial), worklocation-reland-20261014 (silent)
- conclusion: delegation to spawned panes is not currently producing deliverables on this surface

## durable-docs-20261015b / d (Luna 6, ship/scout)
- b: ship task on main worklocation -> refused branch collision with untracked files. CORRECT refusal.
- d: brief carried conflicting ship+scout sections (firstmate derivation bug). CORRECT refusal.
- d outcome: --worklocation authorizes in prose but ctx_read sandbox still refuses outside-root paths. Firstmate-authored fix is INCOMPLETE.

## durable-docs-final (Luna 6, scout) — DELIVERED
- outcome: SUCCESS. 27 tool calls, 3 files written and verified in its own worktree, copied to live home by firstmate.
- pattern that worked: worker writes into ITS OWN WORKTREE, firstmate copies across. Sandbox refuses live-home paths; being authorized does not grant capability.
- status: 

## 2026-10-15 land + reap (Captain direct instruction)
- All tracked work landed: main == origin/main at 2196cb6f.
