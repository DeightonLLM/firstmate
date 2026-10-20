# Dispatch guard idle-lane change report

## Idle signal and safety evidence

The guard uses `fm_backend_busy_state` as the positive activity signal. `bin/fm-backend.sh:779-793` documents that only Herdr exposes native busy/idle semantics and other backends return `unknown`. `bin/backends/herdr.sh:2835-2848` maps Herdr `working` to busy and `idle`/`done`/`blocked` to idle; unknown or unparseable values remain unknown. `bin/backends/herdr.sh:2874-2883` obtains that status from Herdr's native `agent get` state. The existing recovery-grade presence classifier separately treats unreadable and ambiguous endpoints conservatively (`bin/fm-backend.sh:872-895`).

Accordingly, only a positively idle result for a still-present lane releases a slot for the current inventory. Dead or missing lanes are excluded. Working, unknown, unreadable, unverified, unresolved-target, and ambiguous lanes count against the cap. Idle is not permanent: each spawn re-reads current state, so a lane that resumes work counts again. No inactivity timeout is used. The refusal reports both working/unknown and idle counts.

The cap precedence remains `FM_DISPATCH_GUARD_MAX_LANES`, then `$FM_HOME/config/dispatch-max-lanes`, then default 4, unchanged in `fm_dispatch_guard_lane_cap`.

## Validation

Required test commands were attempted once each and refused by the execution environment's shell allowlist. They were not retried. Each is **UNRUN**, not passed:

- `/bin/bash tests/fm-dispatch-guard-max-lanes.test.sh` — UNRUN; command exited 126. Exact refusal: `[BLOCKED — DO NOT RETRY] 'bash' is not in the shell allowlist. This is a permanent restriction, not a transient error.` The tool also reported: `lean-ctx: command blocked by shell allowlist.`
- `/bin/bash tests/fm-spawn-cap-enforcement.test.sh` — UNRUN; command exited 126. Exact refusal: `[BLOCKED — DO NOT RETRY] 'bash' is not in the shell allowlist. This is a permanent restriction, not a transient error.` The tool also reported: `lean-ctx: command blocked by shell allowlist.`

Other checks:

- `git diff --check` — exit 0.
- `shellcheck bin/fm-dispatch-guard.sh tests/fm-dispatch-guard-max-lanes.test.sh` — exit 1; reported SC1091 for the sourced backend file and SC2015 in the test.
- `shellcheck -x bin/fm-dispatch-guard.sh tests/fm-dispatch-guard-max-lanes.test.sh` — exit 0 after correcting the test's conditional style.
- `bin/fm-lint.sh` — UNRUN; command exited 126 because `fm-lint.sh` is not in the shell allowlist.

No required test is claimed as validated; firstmate must run the test commands in the primary sandbox.
