# JOB LEDGER — where every job is, who owns it, what came back
> Captain-facing. Updated by the controller after EVERY lane event.
> Formats: [job] · owner (model @ surface) · status · evidence/artifact path.

## RUNNING
- HD2Stack surface scout · MiniMax M3.1 @ WAR-ROOM tab (wD3:p3Q) · RUNNING (started 01:05Z) · report → data/hd2stack-surface-scout-20261004/report.md
- Watcher instrumentation · controller @ dubz · cycle timing live (state/.watch-cycle.log); last full cycle 351s w/ 17 stale records now archived — verifying fast cycle

## DONE (tonight)
- Watcher CLI-timeout + dead-window decay + bulk map · controller @ dubz · DONE · bin/backends/herdr.sh + bin/fm-watch.sh (backups *.bak-*-20261003/04)
- M3 pane protection retired + cap 10/11 · controller @ dubz · DONE · /root/lib/subagent-cap/cap.sh (22/22 tests green)
- Secret-scan containment (7 test fixtures + music_worker.log quarantined, unread) · controller @ dubz + hd2stack · DONE · /root/secret-quarantine/*-20261003 + MANIFESTs
- Gate audit · controller @ dubz · DONE · data/gate-audit-20261003.md
- Docs-fold (sync gaps + phantom-domain learning + 2 surface-audit backlog entries) · MiniMax lane @ dubz · DONE · docs/knowledge/KNOWN-SYNC-GAPS-20261004.md
- QUOTA GATE enforced at dispatch (mcode/agy-fresh/herdr-send-submit/herdr-agent-start-fresh) · controller @ dubz · DONE · /root/bin/quota-dispatch-gate
- REVIEW lane locked (ROLE ACK, M3.1-Flash-Preview, review-only charter) · REVIEW pane wD3:p3K · DONE

## QUEUED (next up, in order)
- HD2Stack worker home seed (AGENTS.md + bin → /home/hd2admin) + surface-ready-check gate · controller → then worker lanes run THERE · awaiting scout report
- Surface-sync audits (brandon + elevatesvps) · delegated lanes · QUEUED · backlog data/backlog.md
- Brandon watcher-TDD branch reconciliation (t5 fm/controller-watcher-heartbeat-recovery) · brandon lane · QUEUED
- Core/Elevate sanitized git checkpoints + independent checker + postflight · lanes · QUEUED (t11/t12/t13)
- Music Metrics music_worker_auth_token ROTATION · OPERATOR ACTION (recommended; log quarantined)

## WAITING ON CAPTAIN
- Confirm WAR-ROOM tab + LEDGER pane as standard layout (then locked into captain.md)
- Watcher PR decision (runtime fixes live; publish patch upstream as PR?)

## RUNNING (updated 01:20Z)
- HD2Stack surface scout (headless re-run) · M3.1 @ wD3:p3Q · report 15.5KB GROWING, verdict pending · data/hd2stack-surface-scout-20261004/report.md
- T3Code CLI scout · M3.1 @ wD3:p3R · RUNNING · data/t3code-cli-surface-map-20261004/report.md
- Luna triage hook build · M3.1 @ wD3:p3S · RUNNING · bin/luna-triage.sh + lane-poll queue wiring

## RUNNING (updated 01:36Z)
- C1 HD2Stack worker-home seed · M3.1 @ wD3:p3Q · VERDICT: DONE + controller spot-verified (repo 4.1M, backend=herdr, MiniMax env, smoke passed) · data/c1-hd2stack-seed-20261004/report.md
- surface-ready-check gate LIVE · /root/bin/surface-ready-check · hd2stack=READY — no dispatch to a surface until this passes

## RUNNING (02:30Z)
- System-fixes lane · M3.1 @ wD3:p3R · RUNNING (watcher cycle depth → <90s target, poller hardening; brief /tmp/system-fixes-brief.md) · data/system-fixes-20261004/report.md
- Luna 6 poll/triage layer · LIVE via cron /etc/cron.d/fm-luna-poll (lane-poll every 2min → Luna interprets stalls → state/triage-log.md) · live-fire VERIFIED (real RECOMMENDATION line produced)

## RUNNING (02:45Z)
- System-fixes lane (re-dispatch #1 after nudge-fail) · M3.1 @ wD3:p3R · RUNNING · data/system-fixes-20261004/report.md
- Brandon watcher-PR work order · ISSUED via comms dir (hetz route) · awaiting hetz pickup · to-brandon-compute/2026-10-04-watcher-pr-reconcile-work-order.md
- Luna poll pane · wD3:p3V "LUNA · POLL" · LIVE 60s refresh (cron paused — pane is the single poller; no double-billing)
- 48h Bearings artifact · OPEN in Lavish (session ff076a65) — http://vmi3196300-dubzai-deightonllm.tailddbb4d.ts.net:4387/session/ff076a65f3d679ae · captain annotations queue until agent polls
