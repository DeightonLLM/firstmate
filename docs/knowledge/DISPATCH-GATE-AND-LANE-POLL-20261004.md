# Dispatch gate & lane poll — what they are, what they compose (2026-10-04)

Operator order: documented fixes only — no janky made-up mechanisms. This file
is the canonical record of tonight's two new helpers, their documented
sources, and their upgrade path. If a helper is not described here (or in a
skill), it does not exist.

## 1. quota-dispatch-gate (/root/bin/quota-dispatch-gate)

- **What it enforces**: no lane dispatch (mcode, agy-fresh, herdr-send-submit,
  herdr-agent-start-fresh) without confirmed provider headroom (default ≥15%).
- **Documented source of truth**: quota-axi (`/root/.pi/agent/skills/quota-axi/`)
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
  see `/root/agent-work/deightonllm-firstmate/docs/herdr-backend.md`), no invented state files beyond the
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

## 4. LOCAL LOAD SHIELD (added 2026-10-04, captain order — system-critical incident)
- The gate now refuses ALL dispatch while dubz 15-min loadavg >= nproc (4 cores); override `LOAD_GATE_BYPASS=1` (logged to /root/.config/quota-gate-bypass.log). Backup: quota-dispatch-gate.bak-loadgate-20261004.
- Incident: dubz ran 5-min loadavg averaging 7.77 (~2x oversubscribed, sustained) from stacked local mcode lanes on a 4-core box. No OOM — CPU lane-count was the failure mode. Workers moved to hd2stack by architecture order (see data/captain.md WORKER-SURFACE ARCHITECTURE).

## 5. mcode-launch + lane-reaper (added 2026-10-05, captain order)
- **/usr/local/bin/mcode-launch** (dubz + hd2stack): auto-update gate at pane launch — checks npm for @minimax-ai/code latest vs installed (6h cache), refreshes if stale, fail-open on check failure, hard-fail only if no binary. NEVER launch mcode panes directly again (stale-binary glitch class: wrong model, broken keys). Launch pattern: `mcode-launch --model minimax/MiniMax-M3.1-Flash-Preview` (mcode >=0.6.2 requires provider/model format).
- **/usr/local/bin/lane-reaper.sh** (dubz + hd2stack, cron */20): closes agent panes idle/non-working >45min (two-strike state files); protects MAIN/QUOTA/REVIEW/LISTENER + working panes. Log /var/log/lane-reaper.log. Makes lane pile-ups mechanically impossible (dubz load incident never repeats).
- **Mechanical dispatch verify (mandatory after every lane launch):** (1) footer shows expected MODEL id (assert string, e.g. M3.1-Flash-Preview — not plain M3); (2) prompt submitted (Loading/● marker visible); (3) re-Enter if composer still holds text. Model mismatch = broken dispatch, fix before walking away.
