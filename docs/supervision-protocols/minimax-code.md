Mode: MCode primary (minimax-code).

MCode is the standalone `mcode` CLI, a documented MiniMax fork of pi.dev, and it runs Firstmate with verified session-lock ancestry, harness self-report, and visible To-Do List support.

Verified for this primary:

- Session lock acquisition and self-ownership through the shared session-lock library.
- Primary ownership token and lock contracts through bin/fm-mcode-primary-lib.sh (atomic claim, self-ownership verification, stale detection, safe release, and reacquisition).
- Harness self-report as `minimax-code`, so dispatch and supervision resolve to this protocol instead of the unknown-harness fallback.
- Visible To-Do List extension, usable as the preflight tracker before the first task action.

Not verified for this primary, and therefore never to be assumed:

- A native turn-end, `Stop`, `session_end`, or idle hook.
- Extension or plugin loading from the harness itself.
- Event push of any kind.

Use the generic contract in `AGENTS.md` until a native transport is verified.
First cycle: drain queued wakes, then choose a supervision wait the harness can actually wake from.
Ordinary wake: drain and handle the wake, then repeat that same verified wait while supervision is still required.
Use `bin/fm-watch-arm.sh` only when a tracked background mechanism survives the tool call and notifies the model on process exit.
Until such a mechanism is verified for this primary, use a bounded foreground wait over `bin/fm-watch.sh`.
Never use shell `&` for watcher supervision.
Failure or missing cycle only: inspect the failure and restore the same verified wait shape.

Crewmate state is read from `state/<id>.status` wake events and reconciled with `bin/fm-crew-state.sh`; do not treat a status line as current-state truth.

An ACP-over-stdio bridge is under evaluation as a candidate native transport.
Do not depend on it until it is verified and accepted under its own evidence record.