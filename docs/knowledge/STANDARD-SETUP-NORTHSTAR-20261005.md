# STANDARD FLEET SETUP — NORTH STAR (locked 2026-10-05, captain order: "lock this as part of the standard setup")

## Surfaces
- **dubz controller = DELEGATION + MONITORING ONLY** (4 cores, load-shielded). Permanent panes: coordinator, QUOTA TUI, REVIEW·M3.1, MONITOR·LUNA POLL, HETZ LISTENER. No worker lanes here, ever.
- **hd2stack = THE WORKER SURFACE.** Tab `WAR-ROOM · WORKER LANES`, 2x2+ grid, panes labeled `LANE-A · OBJECTIVE`… one ticket per pane, launched only via `mcode-launch`.
- **brandon** runs its own lanes/rules (client AnythingLLM; no GLM there). **hetz** is queue-fed and self-governs (drop files only).

## Launch contract (every lane, no exceptions)
1. `quota-dispatch-gate` passes (≥15% headroom; dubz 15-min load < cores).
2. Pane in the WAR-ROOM grid, label `LANE-<L> · OBJECTIVE`, launched: `/usr/local/bin/mcode-launch --model minimax/MiniMax-M3.1-Flash`.
3. VERIFY mechanically: footer shows the expected MODEL id; prompt submitted (Loading/● marker; re-Enter if composer holds text).
4. Register `state/lanes/<name>.lane` (pane=ssh:hd2stack:…, artifact=remote path, note=…) + LEDGER RUNNING row.
5. Lane contract: To-Do ≥5 items before first action; non-interactive; AUTONOMY (never ask the coordinator mid-task — decide per standing orders, record rationale; true gates → `VERDICT: FAIL <blocker>` + STOP); BACKUP before mutation (`.bak-<tag>-<date>`); artifact + final `VERDICT: PASS|FAIL` line; then STOP.
6. On finish: lane-poll auto-RETIRES (VERDICT detected) → REVIEW pool (M3.1 + one other family, producer ≠ checker) → **next queued ticket into the same pane immediately** (no idle gap) → close reviewed panes.

## Mechanics (deterministic hooks — not memory)
`mcode-launch` auto-update gate (never launch stale binaries) · `lane-reaper` cron */20 both hosts (45-min two-strike idle reaping; MAIN/QUOTA/REVIEW/LISTENER/LUNA protected) · `lane-poll` + `factory-safetynet` ssh-aware (remote process + artifact + VERDICT) · load shield (refuse dispatch while dubz 15-min load ≥ cores) · quota gate · docs mirror cron 15 min + standing-rules AGENTS.md at worker cwd · **LUNA POLL digest = the coordinator's only poll**.

## Escalation to captain — true gates only
Spend · registrar/DNS · client-production deploy beyond authorized tests · destructive/irreversible · credentials. Everything else: decide, record, continue.
