Mode: MCode primary (minimax-code).

MCode is the standalone `mcode` CLI, a documented MiniMax fork of pi.dev, and it runs Firstmate with verified session-lock ancestry, harness self-report, and visible To-Do List support.

Verified for this primary:

- Session lock acquisition and self-ownership through the shared session-lock library.
- Harness self-report as `minimax-code`, so dispatch and supervision resolve to this protocol instead of the unknown-harness fallback.
- Visible To-Do List extension, usable as the preflight tracker before the first task action.

Not verified for this primary, and therefore never to be assumed:

- A native turn-end, `Stop`, `session_end`, or idle hook.
- Extension or plugin loading from the harness itself.
- Event push of any kind.

## The arm owner: `bin/fm-watch-supervise.sh`

Because there is no native hook, this primary's arm owner is a SCRIPT, not the model.
`bin/fm-watch-supervise.sh` runs `bin/fm-watch-arm.sh` in a loop and owns every later cycle, so the watcher stays alive across wakes and a routine wake costs no model turn at all.

When this session owns supervision and away mode is not active:
1. Drain first with `bin/fm-wake-drain.sh`.
2. First cycle: start the supervisor as the harness's own tracked background task, as its own call, on exactly:

   `exec bin/fm-watch-supervise.sh`

   Never bundle it onto another command, and never use shell `&` for it.
   The supervisor sources `config/x-mode.env` itself when X mode is active, so no extra sourcing step is needed.
3. Trust the supervisor's status lines.
   `watcher: started ...` or `watcher: attached ...` means a live cycle exists.
   `supervise: routine wake absorbed (...)` means the wake was classified in bash, cost no model turn, and the next cycle was armed already.
4. Ordinary wake: **the re-arm step is no longer the model's job.**
   The supervisor re-arms itself after every routine wake. Do not run `bin/fm-watch-arm.sh`, and do not re-run the supervisor, after an ordinary wake.
5. A captain-relevant wake arrives as the tracked background task's completion: the supervisor prints `supervise: ESCALATION - ...` with the reason and the arm's own lines, then exits 0.
   Drain queued wakes, handle the wake, then start the next supervisor as a new tracked background task.
6. `supervise: PARKED after <N>s - ...` is the bounded park interval (default 900s; `FM_WATCH_SUPERVISE_PARK_SECS` sets it, 0 means no bound).
   The watcher was still alive, and the cycle is handed back on purpose so the primary gets a periodic heartbeat.
   The bound is enforced at CYCLE BOUNDARIES: a healthy blocked watcher is never interrupted, so a quiet fleet keeps one watcher alive instead of bouncing it every bound, and the park fires at the first boundary at or after it.
   Drain, then start the next supervisor as a new tracked background task.
7. `supervise: FAILED - ...` with a non-zero exit means the watcher could not be kept alive and supervision is DOWN.
   This is the only repair case: drain queued wakes, inspect the failure, and start a fresh supervisor.
8. Never use shell `&` for watcher supervision.

## How a wake is classified

The supervisor classifies every wake in bash with the shared classifier (`bin/fm-classify-lib.sh`), the same one `bin/fm-watch.sh` and `bin/fm-supervise-daemon.sh` use, so there is one captain-relevant definition and not a third copy that can drift.

Routine (absorbed in bash, no model turn): a signal whose crew is provably working, a transient stale, a pane the classifier proves is deliberately paused.

Captain-relevant (escalated, the model is woken): `done`, `needs-decision`, `blocked`, `failed`, a terminal stale pane, an open decision, a persistent wedge, an approval gate, authenticated check output, and a heartbeat wake (which the watcher only surfaces when its fleet-scan found an unsurfaced captain-relevant status).

Anything the classifier cannot confidently call routine is escalated.

## Why the supervision host was not used

`bin/fm-supervision-host.sh` is the designed answer for a primary with no native hook, but it cannot be reached from this primary today, for two measured reasons:

- `bin/fm-supervision-engine-lib.sh` sets `FM_SUPERVISION_ENGINES_VERIFIED='claude'`. Only Claude has a verified supervision engine: a `config/supervision-host` that names any other engine is refused, and the default engine of a non-Claude primary does not exist.
- `fm_supervision_host_attended_ready` requires a verified dialog mirror for the primary, and `bin/fm-host-mirror.sh verified minimax-code` exits 1. There is no mirror writer for minimax-code, so the attended path reports "no verified dialog mirror for minimax-code".

`bin/fm-watch-supervise.sh` is the additive replacement for the missing arm owner: it uses the same arm, the same watcher and the same shared classifier, and it needs neither an engine nor a mirror. It is listed as this primary's arm owner in [`../supervision-host.md`](../supervision-host.md) ("Arm owners").

## Notes

Crewmate state is read from `state/<id>.status` wake events and reconciled with `bin/fm-crew-state.sh`; do not treat a status line as current-state truth.

An ACP-over-stdio bridge is under evaluation as a candidate native transport.
Do not depend on it until it is verified and accepted under its own evidence record.
If a native transport is ever verified, it becomes this primary's arm owner and this protocol is superseded by it.
