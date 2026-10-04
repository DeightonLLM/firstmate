# Dispatch gate & lane poll — what they are, what they compose (2026-10-04)

Operator order: documented fixes only — no janky made-up mechanisms. This file
is the canonical record of tonight's two new helpers, their documented
sources, and their upgrade path. If a helper is not described here (or in a
skill), it does not exist.

## 1. quota-dispatch-gate (/root/bin/quota-dispatch-gate)

- **What it enforces**: no lane dispatch (mcode, agy-fresh, herdr-send-submit,
  herdr-agent-start-fresh) without confirmed provider headroom (default ≥15%).
- **Documented source of truth**: quota-axi (`~/.pi/agent/skills/quota-axi/`)
  with its `--json` schema — the gate reads only documented fields:
  `providers[].provider` and
  `providers[].quotaSemantics.effectiveAvailability[].effectivePercentRemaining`.
- **Composition**: pure CLI wrapper; no parsing of undocumented state; cache
  (/tmp/quota-gate-last.json) is ≤10 min old; only override is
  `QUOTA_GATE_BYPASS=1`, which is logged to
  /root/.config/quota-gate-bypass.log.
- **Upgrade path (proper home)**: the check belongs inside the dispatch
  adapters (bin/fm-spawn.sh intake + fm-send-submit preflight) as a firstmate
  patch with tests; the standalone gate is the interim enforcement point and
  is documented here as canonical until that PR lands.

## 2. lane-poll (/root/bin/lane-poll.sh)

- **What it does**: for each registered lane (state/lanes/<name>.lane with
  `pane=`, `artifact=`, `note=`), polls three honest signals: pane foreground
  process alive (herdr `pane process-info`), CPU-time delta (two samples),
  artifact existence/size/mtime. Prints one STATUS line per lane.
- **Documented source**: herdr CLI `pane process-info` (same call firstmate's
  own herdr backend uses for liveness) + plain stat(1). No screen-scraping
  (herdr alt-screen panes cannot be read programmatically — known limitation,
  see docs/herdr-backend notes), no invented state files beyond the
  registration records in volatile state/.
- **Honest limitation**: CPU delta and artifact growth infer progress; a lane
  sitting at an interactive approval dialog can still burn CPU. Mitigation is
  contractual, not mechanical: every lane charter must demand non-interactive
  flags and require the lane to end with an explicit VERDICT/BLOCKED line, and
  the controller treats IDLE + no-artifact as suspected-prompt-stall.
- **Upgrade path**: if lane-poll earns its keep, it moves to bin/ with tests;
  until then it is a documented composite of documented CLIs.

## 3. Temporary watcher instrumentation (REMOVE after 24h stable)

- `state/.watch-cycle.log` (sweep_start/cycle_end lines) and the
  `.last-watcher-beat` touch at sweep start exist ONLY to diagnose the
  multi-minute cycle times observed 2026-10-03/04 and to keep the turn-end
  guard truthful while diagnosis continues. Root causes fixed tonight (all
  matched upstream oh-my-openagent poller/subprocess fixes):
  1. herdr CLI calls unbounded → `timeout -k` bounds (bin/backends/herdr.sh).
  2. Dead windows probed per-cycle → bulk `pane list --json` map + decay.
  3. Event-FIFO reads unbounded → `-t` bounded reads + KILL-reaped reader.
  4. Watcher PATH lacked /root/.local/bin → absolute-path fallback.
  5. 17 stale pending-reply records × ~10-20s pane captures per cycle →
     archived (state/pending-replies.archived-20261004/), records are
     volatile runtime state.
- Removal criteria: 24h of cycle_end durations < 90s → strip the two log
  lines, keep all five fixes.

## Standing rules referenced
- data/captain.md: upstream-first debugging; dispatch gate threshold 15%;
  every RUNNING lane registered + polled; LEDGER.md updated at every lane
  event.
