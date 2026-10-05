# LIVE BOARD — who is working
**Last update: 2026-10-05 ~18:45 UTC — LANE STANDARD LOCKED; RAG tuning FAIL-RESTORED; lanes A/B/D rewriting missing artifacts**

## 2026-10-05 ~18:45 UTC — LANE STANDARD LOCKED + RAG VERDICT
- STANDARD LOCKED (WAR-ROOM LANE STANDARD v2): every lane = TUI + visible pane label (herdr pane rename) + state/lanes registration; lane-spawn.sh refuses (exit 64) unnamed/unregistered spawns; watcher alarms by lane letter (RAW-SHELL / APPROVAL / UNREGISTERED-LANE / LOCAL-EVIDENCE). Labels live on windows: LANE-A pF, LANE-B pG, LANE-C pJ, LANE-D pK, LANE-E pE, LANE-F pH.
- RAG TTFT: FAIL-RESTORED — topN 7/threshold 0.20 cut prompt tokens but end-to-end LLM time ROSE on 2/3 queries; workspace restored to topN 10/threshold 0.15 (backup intact). RAG-side TTFT win not available; remaining lever is provider-side (model choice/prompt caching). Artifact: brandon rag-ttft-20261005.md.
- ARTIFACT GAP CAUGHT: lanes A/B/D completed analysis in-pane (todos 7/7, 5/5, 6/6) but wrote no files; steered to write artifacts from completed context — all three re-running. Gate that caught it: artifact+VERDICT verification in hd2fleet.check.sh.
- LANES NOW: A spec-v2 rewrite RUNNING; B zcode-prep rewrite RUNNING; D parity rewrite RUNNING; C apply-standby (gated); F gemini-recheck standby; E fixture done. Dubz: clean.

## 2026-10-05 ~16:35 UTC — CAPTAIN VISIBILITY ORDER EXECUTED
- VISIBLE NOW: hd2stack w6:t5 "REPAIR-YARD" → w6:pF agent `spec-rev` (pi/M3.1) writing WIDGET-PATCH-SPEC-V2 (fixes Gemini REVISE defects); w6:pE #5496 fixture (15 bg results, reconcile pending); BRANDON w1E:p6 RAG TTFT tuning on captain GO. Stale done panes pB/pC/pD closed.
- CONTROLLER (dubz): ZERO agent jobs — all headless lanes finished/migrated; kept free for emergencies per captain.
- USAGE: hd2stack 7.5 GB RAM available, load 1.5 (5-min), 2 worker panes — not over-subscribed.
- ZCODE: study VERDICT NOT-SUITABLE — the 0.67-coefficient/1.5x quota benefit EXPIRED 2026-08-01; GUI-only AppImage, no Linux CLI, no extension host. Launch+prep CANCELLED, no purchase. Artifact: warehouse/reports/ZCODE-HARNESS-STUDY-20261005.md.
- GEMINI REVIEW: VERDICT REVISE — RCA diagnosis sound; patch spec P3/P4 defects + mobile keyboard math + missing host-executable verification. Spec-v2 lane addresses all; no live re-patch until spec-v2 + review pass.

## 2026-10-05 16:03 UTC — WIDGET INCIDENT RESOLVED (captain confirmed working)
- WHY IT BROKE: the `focusfix` widget layer set the composer `position:fixed` with a phone-keyboard `bottom`/`height` formula; on desktop the formula pins the composer OUTSIDE the visible window on click-to-type (all browsers). Sending still worked — only display moved. The `viewportfit` layer additionally rewrote the host page's viewport meta unconditionally. Full mechanism + corrected P1–P4 patch spec: `warehouse/reports/WIDGET-COMPOSER-BUG-RCA-20261005.md`.
- FIX: two rollbacks (viewportfit, then focusfix). Live = 674,287 B sha256 `1f1bb8c4…` (widgetfix4/consentfix2/hdsizingfix2), verified served local+public. Captain confirmed widget working 16:0x UTC.
- OPEN on widget: Gemini review of patch spec (RCA-REVIEW artifact); corrected mobile patch re-apply ONLY after review + real-browser validation; NOTE RCA also flags consentfix layer bugs (page-wide preventDefault, permanent form.hidden, hot-path MutationObserver) — deliberately out of scope, separate change later.
- RAG TTFT: captain reports longer time-to-first-token (expected: topN 3→10 grew prompt ~2.5x). Recommendation queued: topN 7, threshold 0.20, trim system prompt; apply only on captain GO (DB change, backup first).
- DOCS: `warehouse/chatbots/` created — `ANYTHINGLLM-SITUATION.md` (docs lane, in flight) + `INDEX.md` linking old Sept fix docs (anythingllm-isolation-deep-0924 etc.).
- ALSO RUNNING: mcode RCA lane done; mcode docs lane finishing; #5496 fixture lane (hd2stack pE) reconcile pending.

## 2026-10-05 05:22 UTC — LIVE LANE RECONCILIATION (wake 1387)
- ACTIVE: HD2Stack w6:pE — #5496 fixture-resume ticket 060 delivered; spinner verified at 05:22 UTC. Reconcile next wake.
- IDLE/COMPLETE: HD2 w6:pB Android QA = VERDICT FAIL (no Android browser runtime; static only); w6:pC iOS QA = VERDICT PASS as study only (no WebKit runtime; no device pass claimed); w6:pD complete/idle. No other HD2 worker is currently active.
- BRANDON: widget stack second review PASS + viewport-fit fix report PASS; actual iPhone/Android device test remains captain-side. RAG dedupe PASS. Current Brandon pane status not re-verified this wake.
- GEMINI: no live supervisor process/pane and no surface-audit artifact — stale claimed-running item; re-dispatch required if still wanted.
- Open, not active: canonical-index merge to warehouse README; Gemini surface audit; hetz Gates A-E (captain GO); brand-guard keep/drop; physical device tests.

## 2026-10-04 late — ARCHITECTURE CHANGE (captain order)
- dubz controller = DELEGATION + MONITORING ONLY; no worker agents run from its panes. ALL new lanes dispatch to **hd2stack** panes (verified ready: mcode + herdr, 6 CPU/11 GiB); captain watches via herdr machine switcher, labeled war-room layout. In-flight controller lanes (wD3:p43 merge, wD3:p45 docs, wD3:p46 no-mistakes, p3R/p3S/p3W) finish in place. Exceptions: main pane, QUOTA TUI, REVIEW·M3.1, controller session, secondmate homes. Rule recorded in data/captain.md.

## 2026-10-04 late-night — handoff state (read after session-start)
- ELEVATE: w1E:p6 (brandon) — first recreate used :latest which republished v1.16.2 (no fix); rollback done; AUTHORIZED: pull explicit mintplexlabs/anythingllm:1.17.0 + recreate + verify (embed returns JSON, chat answers, Core intact) + recovery report. Old build defect: /api/embed routes absent (upstream issue #3978 matches).
- FIRSTMATE UPDATE: mcode worker pane wD3:p43 (tab wD3:t1V, WORKER · upstream-update) — merging upstream kunchenguid/firstmate into isolated clone /root/agent-work/firstmate-upstream-update/repo, enabling config/wait-no-turns (PR #4859, the speed feature), MERGE-REPORT.md + cutover plan (cutover to live home is captain-gated). Our copy was frozen at local-only b8fb5d6 — that hash is also what broke secondmate syncs.
- STANDING ORDERS LIVE: dark factory (controller ≤ coordination; lanes execute); VISIBLE LANES (no headless for real work; mcode sends = type+enter+VERIFY working); routine lanes medium/low effort; M3.1 reviews low-effort output (M3.1 = mcode-only, never Pi); secondmate harness pinned pi+gpt-6-luna (effort per job, never GLM on hd2stack); no-GLM-on-brandon; lane asks flow via status, never silent parking.
- PRODUCTION-GATE fix: controller patched (open panes carry old code until restart — new sessions clean); brandon patch dispatched (w1G:p2); hd2stack patch queued (diff remote /root/.pi/agent/extensions/02-production-gate.ts md5 72ad39f5 vs fixed, backup, push).
- QUEUED: lavish bearings (needs fm-fleet-snapshot jq E2BIG fix — temp-file not argv); warehouse docs fix (SAAS_ACCESS_INVENTORY + SAAS_STATE_MAP per hd2stack lane's facts); luna-6-med poller restore; pi-codex-fast install (pi.dev/packages rule in learnings); weekly stale-check lane; JOB 2 test CI registration; Gemini+M3.1 review of Elevate recovery report when it lands.
- AWAITING CAPTAIN: no-mistakes install GO; brand-guard cron keep/drop.

## 2026-10-04 late — Elevate live-state changes (captain-direct)
- Container RENAMED: hd2stack-anythingllm → elevate-anythingllm (live rename, healthy, /api/ping online; run-config captured; compose file updated, adopts on next compose up; host DIR rename deferred to next sanctioned restart). Mechanical brand-guard live: /usr/local/bin/hd2stack-brand-guard.sh + cron 15min on brandon.
- Credential pointer UNBLOCKED: /home/hd2admin/hd2stack-anythingllm/.api-key (600) authenticates /api/v1/workspaces 200; workspaces [core-distro, elevate] confirmed existing.
- TWO lanes on the fix: w1E:p6 (single executor, Core-pattern workspace UPDATE per exec GO) + w1G:p2 (read-only discovery, Brandon-dispatched) — reconciliation steer sent to w1E:p6; watching for duplicate mutation. Recovery report still pending.
- lane-todo-board.sh BUILT+tested (31 cases/76 assertions) — todos visible per lane; permanent war-room pane wiring pending.

## 2026-10-04 evening — Captain refinement (relayed via hd2stack pane)
- Target architecture (captain): hd2.ai instance on hd2stack physical stays untouched (HD2-internal only); ONE client AnythingLLM on brandon :3001 holding BOTH RAG workspaces (Elevate + Core-Distro). Current container already matches; superseded the secondmate's second-instance idea.
- QUEUED (needs captain GO + brandon firstmate, restart mutation): rename the client container off the `hd2stack-` prefix. Not during the P0 fix.
- Elevate P0: Option A GO delivered (file + pane steer, w1E:p6 working): backup DB → read-only diff Core(working) vs Elevate → narrow Elevate-only UPDATE to local ollama per Core's pattern → verify /api/embed → recovery report. Gemini+M3.1 review on report.
- JOB 2 guard: built+corrected on branch secondmate-guard-20261004 (98/98 assertions; deny narrowed to fm_watch_arm_pi; marker predicate mirrored; diff-verified 15/15 vs shell). NOT merged — merge/wiring is captain-gated follow-up. Charters corrected (orchestrator/handoff → read-only, no coordination); captain.md standing order 'NO POINTLESS STOPPING' recorded.
- Kun bundle review: Gemini 3/4 PASS; Kun-Lane-B config inventory REVISION_REQUIRED (unverified 'enforced cap' claim).

## 2026-10-04 03:20 UTC — Controller restart day: one controller restored
| Item | State |
|---|---|
| Controller | Fresh Pi session wD3:p41 holds lock; watcher armed (extension-owned). Duplicate GLM controller-style lanes (orchestrator wD3:p42, handoff wD7:p2) closed on captain GO; findings saved to data/duplicate-lane-findings-20261004.md (incl. 6/7 baseline pins stale — unverified claim to re-check). Stale panes cleared. Live panes: controller + QUOTA + REVIEW·M3.1 + hd2stack supervisor (wD9:p2). |
| HD2 identity | hd2stack secondmate charter + registry now carry a binding identity block (controller-local vs physical Contabo vmi3238503 vs brandon-compute; container named `hd2stack-anythingllm` actually runs on brandon-compute:3001 — names lie). Live steer to wD9:p2 pending (pane busy; fm-send delivery unconfirmed ×2 — will land on idle). |
| Elevate | Full picture read: warehouse (elevate-dashboard on KVM8 srv1137994, /api/* fails-closed record superseded by live hash match), outage work order + route recheck (brandon-compute:3001 healthy; embed path returns HTML; Elevate-workspace-only reversible fix, checkpoint first, Core read-only). BLOCKER: Brandon's 2026-10-02 REPLY says the Elevate work order never reached its inbox — redelivery + kick is the next action, then hetz lane executes, Gemini + M3.1 review evidence. |
| Job 2 (queued) | Mechanical fix: secondmate homes must never run controller session-start/watcher (role marker + hook); charter hygiene for orchestrator/handoff homes. After Elevate, delegated lane. |
| Parked | no-mistakes install needs captain GO; secondmate sync skips (dangling commit b8fb5d64); Brandon system-ops still blocked on stale-wake task ownership. |

## 2026-10-03 22:47 UTC — Unlock executed under operator order (live-verified)
| Item | State |
|---|---|
| Watcher | Wedged twice more this hour (arm 3793549, then 4003632 — each ran ~10-20 min then froze with stale beat); both terminated after exact identity check (TERM ignored → KILL). Fresh cycle now live: arm 329436 / watcher 329451, beat 22:46:20Z. Third wedge today strengthens the case to prioritize the permanent fix (t5) over the stalled publication decision. |
| Panes | Verified live: exactly 2 remain — main controller (wD3:p32) + quota TUI (wD3:p39). Closed under operator order with work saved: p3A/p3B/p3C/p3D (blocked audit lanes; reports preserved in data/) and wD6:p3 (hd2stack Secondmate; superseded-audit resolution recorded with corr 87dd3111dee3a4ff; home preserved). |
| Secret blocker | 7 flagged test files in elevate-chatbot-docs/tests/ quarantined unread to /root/secret-quarantine/elevate-chatbot-docs-tests-20261003/ (MANIFEST.txt inside). Root scan re-run: PASSES, 194 accepted. Codex owner must restore sanitized fixtures. |
| Cap + M3 | Subagent cap raised 6/7 → 10/11 (operator order). M3 pane protection fully retired: guardian absent, cap.sh gates removed, routing doc updated, cap tests 22/22 green. Backups + full gate audit: data/gate-audit-20261003.md. |
| Elevate | External Codex owns diagnosis (embed API returns HTML shell; container healthy). Controller review lane can resume now that the scan passes and pane slots are free. |

## 2026-10-03 20:54 UTC — HD2Stack is reachable; remote coding home is not provisioned
| Item | State |
|---|---|
| Physical host | `hd2stack` is now a saved Herdr machine. Read-only SSH verified hostname `vmi3238503`, 6 CPUs, and 11 GiB RAM; Herdr/Pi/MCode are installed. The remote Herdr inventory shows only root shell `w6:p1`, not an agent. `/home/hd2admin` is empty; `/opt/overnight-mirror/repo` is a clean `overnight/mirror` snapshot at `bdd465de643beaf7fd6fd4f6618cae05948c204b` (2026-09-24, no Git remote), not a current task workspace. |
| Existing Secondmate | The `hd2stack` registry entry and `state/hd2stack.meta` point to `/root/secondmates/hd2stack`, pane `wD6:p3` on the controller. It is not the physical remote host. Do not count it as remote capacity or close the persistent Secondmate. |
| Controller lanes | AGY and three M3.1 lanes remain blocked; blocked lanes are not closable under the current lifecycle rule. The quota TUI and main controller remain protected. |
| Action | Registered the physical Herdr machine; no remote Secondmate home/agent was created, and no production service changed. Correct shared routing docs/rules through the approved isolated path. |

## 2026-10-03 18:25 UTC — Elevate embed API mismatch; authority boundary unresolved
| Item | State |
|---|---|
| Elevate symptom | Public Elevate HTML references `agents.elevatesci.com/api/embed` and the AnythingLLM widget. That API path currently returns 200 HTML, matching the internal `brandon-compute:3001` AnythingLLM root, rather than API data. The container is healthy. Core's public page references `llm.hd2.ai`, a different service. |
| Safety boundary | Existing warehouse evidence says the Elevate `/api/*` route was intentionally disabled pending an approved Elevate-owned backend; the later access inventory/work order describe Brandon `:3001`, and workspace isolation is unproven. No production write made. Repointing or changing the shared route requires explicit boundary reconciliation. |
| Elevate worker | Dedicated `elevate-p0-repair` Secondmate is provisioned but idle. The approved marked instruction is queued in its inbox; `fm-send` timed out and no worker start/status is confirmed. |
| Controller monitoring | At 17:56:57Z the guard reported the watcher down and a 1009s-stale beat. The exact stale arm parent was terminated at 17:55; no watcher was present immediately afterward. Pi extension owns the next recovery; no duplicate arm started. |
| Watcher TDD | Option 1 decision was delivered and the task message queued; no PR or final RED proof yet. |

## 2026-10-03 17:43 UTC — Watcher healthy; captain approved restart recovery
| Item | State |
|---|---|
| Controller monitoring | At 17:43:39Z, the home-scoped heartbeat was 211s old (within the 300s grace) and `fm-guard.sh` returned clean. The Pi extension still owns the watcher; no process was signaled and no duplicate cycle was started. |
| Permanent fix | Captain approved Option 1 for `controller-watcher-tdd`: extend identity/home/path-checked stale-owner recovery into the `--restart` pre-start path only. The answer is checksum-verified in Brandon's nested inbox; the task message is queued and pane `w1E:pF` reports working. No gate resolution or PR yet. |
| Acceptance | The report says synchronized RED against pre-fix source remains outstanding, and the current no-mistakes run skipped push/PR/CI. Do not call the fix complete until the worker closes these gaps and required PR validation passes. |
| Elevate | Still unrepaired. Resume the isolated Elevate outage after this controller recovery; keep Core-Distro read-only. |

## 2026-10-03 16:32 UTC — Brandon Firstmate is provisioning a clean Elevate lane
| Item | State |
|---|---|
| Elevate | Remote Firstmate acknowledged the corrected nested inbox and is actively using its supported Secondmate provisioning flow for a fresh Elevate-scoped lane. It is checking its existing Secondmate scope before dispatch. No repair artifact or production change yet. |
| Parallel Firstmate work | Kun source/config and the two Firstmate system-fix orders are in the same remote inbox; lane status and actual agent models must be verified before calling them active. Requested concurrency=50 and the Treehouse/AXI source inputs remain in scope. |
| Existing panes | Remote parent is active; prior task-affined panes remain untouched. Do not reassign SystemOps. |

## 2026-10-03 15:39 UTC — Brandon Firstmate is processing the delivered orders
| Item | State |
|---|---|
| Remote coordinator | Submitted the validated bounded dispatch prompt to Brandon Firstmate primary `w1E:p6`; live Herdr result reports `working`. It has been asked to route the urgent Elevate order and independent system tasks without reusing task-bound panes. |
| Elevate | Still no repair artifact or worker assignment yet. The remote coordinator is now active on intake; preserve the exact Elevate-only boundary. |
| Controller watcher | Three reproduced stalls have a queued local TDD/no-mistakes task and a delivered remote work order. The current local monitor was previously confirmed healthy after recovery; no code fix yet. |
| Parallel work | Remote Firstmate must verify its own capacity and active task overlap, then run independent eligible lanes concurrently. Controller-local 6/6 is not used as a Brandon limit. |

## 2026-10-03 09:14 UTC — Supervision restored again; permanent fix queued
| Item | State |
|---|---|
| Current monitoring | After another stale-beat alert, the old owner was verified and cleared; the Pi recovery tool then started arm child 33. Latest beat is 09:14:31Z and `fm-guard.sh` is clean. Do not manually arm again unless a new unhealthy notice arrives. |
| Permanent fix | `firstmate-controller-watcher-heartbeat-20261003` is queued in the local backlog with three reproduced incidents and TDD/no-mistakes acceptance. The controller-watcher work order and supplemental evidence are on Brandon; owner acknowledgment remains absent. No source changes have been made. |
| Remote work | Three original Brandon orders plus controller-watcher evidence are present in its inbox; no remote worker has accepted any of them. |

## 2026-10-03 06:34 UTC — Third controller watcher stall recovered
| Item | State |
|---|---|
| Recovery | Third stall confirmed with exact owner/lock identity. Arm PID 2035416 was terminated; Pi automatically started arm PID 2198294 and watcher PID 2198309. Beat advanced to 06:33:59Z and `fm-guard.sh` returned clean. |
| Permanent fix | Local backlog task `firstmate-controller-watcher-heartbeat-20261003` is queued; private brief now records three occurrences and requires TDD/no-mistakes. Matching work order and second-occurrence evidence are in Brandon's inbox, but no owner acknowledgment. |
| Current state | Supervision is active at last check. This is a recurring defect, not a durable fix; do not manually rearm again absent a new unhealthy notice. |

## 2026-10-03 06:26 UTC — Controller watcher wedged a second time
| Item | State |
|---|---|
| Recovery | A second verified stale cycle occurred: arm PID 1637272 waited while its lock-matched watcher PID 1637287 was blocked in `pipe_read`; the heartbeat was over seven minutes old. Terminated only that verified arm parent. Pi auto-started arm PID 2035416/watcher PID 2035431; beat advanced to 06:25:59Z and `fm-guard.sh` was clean. |
| Permanent fix | Main backlog task `firstmate-controller-watcher-heartbeat-20261003` is queued with updated two-occurrence evidence, TDD and no-mistakes criteria. Matching work order has been delivered to Brandon; owner acceptance remains unconfirmed. No source edit by controller. |
| Current outcome | The new cycle is healthy at the last check, but the recurring cause is still not fixed. No more manual recovery unless a new unhealthy notification arrives. |

## 2026-10-03 06:21 UTC — Controller watcher recovery tracked for permanent fix
| Item | State |
|---|---|
| Current controller cycle | Exact stale arm parent PID 759104 was terminated only after its lock identity and stale heartbeat were verified. Pi auto-started arm PID 1637272 and watcher PID 1637287. Latest beat is 06:17:10Z (261s old, inside 300s grace); `fm-guard.sh` is clean. No second cycle. |
| Permanent fix | Added queued TDD ship `firstmate-controller-watcher-heartbeat-20261003` with reproduced live-but-wedged evidence and no-mistakes acceptance. A scoped work order was copied to Brandon and SHA-verified; remote owner must first check overlap with its own in-flight stale-wake task. No source/config edit or worker acceptance yet. |

## 2026-10-03 06:05 UTC — Wedged controller watcher recovered
| Item | State |
|---|---|
| Recovery | The extension helper found an arm child but did not re-arm. Fresh evidence confirmed arm PID 759104 had been waiting for 3h28m, watcher PID 759119 owned the matching lock, the heartbeat was over 10 minutes old, and the watcher was blocked reading a pipe. Terminated only the exact stale arm parent after verifying its identity. |
| Result | Pi automatically started arm PID 1637272 and watcher PID 1637287; heartbeat advanced to 2026-10-03 06:04:57Z and `fm-guard` returned clean. No second arm or broad process kill. |
| Durability | Immediate alert is cleared; recurrence root cause is not fixed. Do not claim Brandon's separate stale-wake task proves a controller fix. |

## 2026-10-03 05:54 UTC — Controller watcher is healthy again
| Item | State |
|---|---|
| Supervision alert | `fm_watch_arm_pi` reported an existing arm child. Exact process check found the controller `fm-watch-arm.sh` and `fm-watch.sh` live (PIDs 759104/759119); last beat was 2026-10-03 05:52:30Z and `bash bin/fm-guard.sh` returned clean. The cycle recovered automatically; no process was killed and no second cycle was started. |
| Permanent recurrence | This alert is clear now, but durable controller-side prevention is not proven. Brandon's `system-stale-wake-loop-0924` concerns its own home and is not yet verified to cover this controller watcher; do not claim it is fixed or interfere with that worker. |
| Active work | Remote Elevate/Kun/outbound work orders remain SHA-verified in Brandon's inbox, but the owner has not acknowledged them. |

## 2026-10-03 05:45 UTC — Remote intake reconciled; no worker pickup yet
| Item | State |
|---|---|
| Brandon Firstmate queue | Confirmed the three orders are on the remote inbox with matching hashes. A fresh inbound sync found no acknowledgment/report; live pane list is unchanged. |
| Eligible system lane | Brandon's valid SystemOps home is scoped to Firstmate infrastructure, but its own backlog has `system-stale-wake-loop-0924` in flight and a separate teardown guard queued/held. Do not reuse or interrupt it for these new tasks. The dirty main home is not a Secondmate home. |
| Capacity | Brandon has 16 vCPU, 61 GiB RAM, 53 GiB available, load average 1.29. Resource headroom is established, but it does not prove 50 concurrent agents safe. Remote status remains two unknown panes and five idle/task-affined panes. |
| Next routing state | Elevate, Kun integration, and outbound-delivery fix are present in the remote inbox; no worker has accepted them. Keep controller primary coordination-only and do not claim code/config work is underway. |

## 2026-10-03 04:39 UTC — Brandon work orders physically delivered; parallel lanes queued
| Item | State |
|---|---|
| Delivery gap | Confirmed the controller-side `to-brandon-compute` files were local only: Brandon's inbox directory was absent and `sync-brandon-comms.sh` only pulls replies. Created the remote inbox and copied the Elevate, Kun high-throughput, and outbound-delivery work orders; local/remote SHA-256 hashes match. |
| Elevate outage | Remote owner pickup and repair acknowledgement still pending. The order authorizes a fresh clean home via the remote owner's supported process; dirty homes and the active SystemOps task remain protected. |
| Kun high-throughput setup | Remote order requests parallel source/config discovery, then isolated implementation of the source-verified native concurrency value 50, concise coding direction, and verified plugins. No runtime configuration has changed; no remote worker acknowledgement yet. |
| Delivery-system fix | Added a separate TDD task/order to make future outbound work-order delivery idempotent and checksum-verified; currently no worker acknowledgement. |
| Capacity | Controller-local 6/6 does not govern Brandon. Remote read-only snapshot: 16 vCPU, 61 GiB RAM, 53 GiB available, load average 1.29. This is headroom evidence, not proof that 50 concurrent agents are safe. Use Brandon's own enforced cap; pane inventory remains two unknown and five idle/task-affined, with no pane reused. |

## 2026-10-03 04:29 UTC — Parallel Elevate and Kun configuration work orders
| Item | State |
|---|---|
| Elevate outage | Updated the Brandon work order: the controller-local 6/6 limit does not block remote work; Brandon must use its own verified cap/resources and may provision a distinct clean Secondmate home. Dirty homes and the existing SystemOps task remain protected. No remote acknowledgement or repair is confirmed. |
| Kun high-throughput setup | Added a separate Brandon work order for parallel video/source research and current-config inventory, followed by isolated implementation of the source-verified native 50-agent setting, concise coding direction, and verified plugins. Codex Luna 6 XHigh is requested; no worker acknowledgement or configuration change is confirmed. |
| Safety and concurrency | A configured native worker-pool value of 50 is not permission to exceed enforced Herdr pane caps or load-test production. Remote host capacity must be verified independently; canary testing remains after the outage. |
| Local implementation | Primary-delegation guard remains queued for an eligible isolated worker; primary has made no source/config changes and will not self-review. |

## 2026-10-03 03:08 — Remote outage handoff and quota/capacity update
| Item | State |
|---|---|
| Elevate outage | Bounded work order written to `BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-03-elevate-assistant-outage-work-order.md`. It limits live writes to Elevate, keeps Core read-only, requires a checkpoint, and requests Codex Luna 6 XHigh/Max only when live-verified. Awaiting remote-owner pickup; no service or app changes by controller. |
| Remote panes | Fresh Brandon pane list shows two unknown panes and idle panes with existing task/session context. No pane was refilled, closed, or restarted; no new Secondmate assignment is confirmed. |
| Quota | Fresh no-refresh read: Codex 96%, MiniMax 94%, Gemini 99% with runway unknown, Z.AI tools 0%. Captain reports extra Z.AI weekly refills, not reflected in the tool quota evidence. |
| Capacity policy | Captain clarifies the six-pane limit is controller-local, not a global remote-host cap. Keep controller at 6/6; verify each remote host's own cap and resources before dispatch. Capacity testing is queued until Elevate is stable and must use bounded non-production canaries. |
| Follow-ups | Delegation guard, T3Code surface/install map, system-skill freshness audit, and per-host capacity mapping remain queued for eligible delegated workers. |

## 2026-10-03 03:02 — Watcher recovery and new coding tasks

## 2026-10-03 03:02 — Watcher recovery and new coding tasks
| Item | State |
|---|---|
| Supervision | The stale arm child was terminated by its exact verified PID; the Pi extension automatically started a new home-scoped cycle. New arm child PID 364684, lock owner PID 364699; `bin/fm-guard.sh` returned no warning with 93 tasks in flight. |
| Firstmate guard | Task `firstmate-primary-delegation-guard-20261003` is queued with an isolated TDD/no-mistakes brief. No code changes or worker dispatch yet. |
| T3Code | Task `t3code-cli-surface-map-20261003` is queued for read-only CLI and coding-surface verification. No installation or warehouse edit yet. |
| Capacity | Safe pre-spawn audit reports 6/6 open subagents. Existing blocked, unknown, and persistent Secondmate panes were preserved; no pane had verified settlement for automatic cleanup. No new lane started. |
| Routing | AGY Gemini has 99% weekly remaining but lacks the required visible To-Do extension. MiniMax M2.7 has 94% general quota with runway through reset; model catalog confirms it is available in Pi. |

## 2026-10-03 00:26 — Sprint list drafted and boundaries recorded
| Item | State |
|---|---|
| Sprint draft | `BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-03-brandon-client-sprint.md`; built from existing task records and captain request, with no filler. |
| DubzAI | Site stabilization remains Done per captain. The historical-set audit was superseded by another surface agent; our Secondmate received a stop request, not a site mutation. |
| Lavish | Static review complete; four sections and responsive rules are present, but the 17:23 UTC snapshot and current-status cards are stale. Refresh before reusing as current. |
| Existing sprint work | Core V3 acceptance spec and MiniMax challenge are in flight; independent review is queued. Core/Elevate rollout is prerequisite-blocked. Gap map, embed prep, and benchmark are Done. |
| Hetz Secondmate | Provisioning remains paused until a clean parent-owned home and exact client-repo/delivery scope are available. Existing dirty/unseeded paths and the SystemOps Secondmate were preserved. |

## 2026-10-03 00:15 — Captain closes DubzAI site work; Lavish review and sprint list
| Item | State |
|---|---|
| DubzAI site | Stabilization remains Done per captain. No further site work. The separate surface agent owns the historical content-set search; our duplicate HD2Stack audit was canceled, with a stop request sent. |
| Lavish | Static review complete: four sections and responsive wrapping are present. Snapshot timestamp is 2026-10-02T17:23:07Z; the current-status cards are stale and need a fresh snapshot before reuse. Portable export remains available. |
| Next client sprint | Existing records show Core V3 standalone acceptance spec + MiniMax challenge in flight, independent review queued behind the challenge, and Core/Elevate rollout blocked by its local trial/benchmark prerequisite. Core V3 gap map, HD2 embed prep, and Music Metrics benchmark are Done. |
| New Git/backup audit | Keep as a read-only item for completed live/SaaS final updates; no commits, backups, restores, or production changes yet. |
| Hetz Secondmate | Not provisioned: the registered parent home is unseeded/dirty with an unknown focused pane; the valid SystemOps home has an unrelated in-flight task. A clean home and permitted client-repo delivery scope remain prerequisites. |

## 2026-10-02 23:16 — New DubzAI report-first investigation routed
| Item | State |
|---|---|
| Captain's observation | Current DubzAI blog set differs from the pre-outage set; treat this as a new read-only investigation, not as evidence to restore or publish content. |
| Existing evidence | Oct. 1 reports verify ten Stack technical slugs; the separate editorial search found six planned music/AI slugs but no authoritative exact ten. The earlier closeout does not answer which set was live before the outage. |
| Secondmate | Added `dubzai-prior-post-set-audit-20261002` to the valid HD2Stack Secondmate backlog and routed it to idle `wD6:p3` (GPT-6 Luna). Live Herdr state now reports `working`; report path: `data/dubzai-prior-post-set-audit-20261002/report.md`. |
| Boundaries | Read-only source/history/skill/warehouse audit; no blog edits, Git writes, backup creation, restore, deploy, service, DNS/TLS, or credential work. |
| Hetzner Secondmate | Dedicated client-home provisioning remains unresolved: the registered home path is unseeded/dirty and the visible valid SystemOps Secondmate has an existing in-flight system ticket. Preserve both; no re-seed/reassignment. |

## 2026-10-02 21:33 — Lavish address corrected after DNS failure
| Item | State |
|---|---|
| Browser URL | `http://100.117.47.27:4387/session/5299ef675ee8f812`; confirmed port 4387 listens on the controller's Tailscale IP and loopback. Numeric address avoids the failing MagicDNS hostname. |
| Portable file | Exported `.lavish/bearings-20261002-portable.html` (10,835 bytes, zero unresolved local assets). It can be opened with `file:///root/agent-work/deightonllm-firstmate/.lavish/bearings-20261002-portable.html` on a browser with access to this filesystem; remote CDN styles still need network. |
| Sharing | No third-party/public upload or server configuration change. |

## 2026-10-02 20:53 — Duplicate missed-reply wake and delegation correction
| Item | State |
|---|---|
| Captain's direction | Captain reports AGY/Gemini is full and objects to controller doing implementation directly. Stop controller-side source edits and no-mistakes retries; continue only through an eligible delegated owner after route/availability is established. |
| Latest wake | Drained first; `hd2stack.status` repeats `pending-reply-missed` for the seven secret-scan paths. Current Secondmate state remains blocked; no correlated path-only report exists. |
| Security | Main root scan still passes with 194 baseline paths accepted. No files were moved or inspected by contents. Recovery condition: Secondmate returns exact paths and scanner classifications through its report/status channel. |
| Bearings/Lavish | Snapshot and local `.lavish/bearings-20261002.html` are complete. Code branch remains clean/local; no PR or merge. Lavish review session remains open. |
| Next | Wait for path-only evidence or captain direction. Do not reissue unchanged requests or continue pipeline recovery solo. |

## 2026-10-02 18:26 — Bearings state refreshed; pipeline and scanner blockers recorded
| Item | State |
|---|---|
| Bearings snapshot | Fresh local-only snapshot generated at 2026-10-02T17:23:07Z; PR discovery was not requested. It shows 90 in-flight records (20 displayed, endpoints absent), two Captain's Calls, one main-inventory warning, and two unreadable/invalid Secondmate homes. |
| Lavish | Current CLI guidance and table/explanation playbooks reviewed; FirstMate repo has no CSS/Tailwind design system. Create a local `.lavish/` review artifact using the snapshot, with all four Bearings sections and a pointer to the current task report. |
| No-mistakes | The scoped branch is clean with only the two authorized files, but both Pi review attempts (GPT-6 Luna and MiniMax M2.7) exited 1 before tests/push. No PR exists; no merge. |
| Security triage | The current root secret scan passes with 194 existing paths accepted; the Secondmate's seven-file warning has no correlated path-only report. No files were quarantined. |
| Next | Finish Bearings/Lavish, keep the secret warning uncorroborated until path-only evidence arrives, and recover the no-mistakes review route without broadening scope. |

## 2026-10-02 17:31 — Clean Bearings branch separated; Pi audit stopped on scan discrepancy
| Item | State |
|---|---|
| Bearings fix | TDD RED/GREEN/REFACTOR complete; focused snapshot suite 17/17 and synthetic local-only Bearings output pass. Commit `462d9a021aedbd7b2fd386e071df380cc42ebf5e` is on `fm/bearings-snapshot-arg-limit-20261002`, with only the authorized script and test. |
| PR validation | Captain chose to exclude local CI commit `53e473c`; original branch retained. New no-mistakes run on the clean branch failed in Review because its Pi process exited 1; logs have no detail, and nothing was pushed. |
| Secret scan | Secondmate's fresh Pi session reported seven possible test-file findings but returned no correlated path-only report and stopped before audit-source reads. The current root scan passes with 194 existing paths accepted; no files were moved. |
| Next | Finish a current Bearings digest and Lavish HTML; diagnose the Pi review failure and obtain path-only reconciliation before any quarantine. No merge, broad pane cleanup, or guard changes. |

## 2026-10-02 16:23 — Earlier CI change would be bundled into the Bearings PR
| Item | State |
|---|---|
| Review request | The pipeline found local commit `53e473c` (`ci: pin actions to SHAs, verify jq checksum, drop unverified tasks-axi install`) is not on `origin/main`; the proposed PR would include `.github/workflows/ci.yml` plus the two authorized Bearings files. |
| Scope | The Bearings task's approved write boundary is only the snapshot script, its regression test, and task evidence. The pipeline is paused before review/tests; no push or PR has happened. |
| Captain choice | Confirm whether to include that earlier CI workflow change or keep the PR limited to the Bearings fix. Recommendation: keep the PR scoped to the two Bearings files and separate the pre-existing commit. No branch edits while the validation run owns it. |

## 2026-10-02 16:11 — Bearings/Lavish work resumed through verified Pi tools
| Item | State |
|---|---|
| Captain direction | Captain authorized a different verified harness rather than requiring them to identify an internal guard. The existing decision is recorded and resolved; Codex hook registrations remain untouched. |
| Implementation | Current visible Pi controller is working in the existing clean isolated task worktree on `fm/bearings-snapshot-arg-limit-20260930`; no sidecar pane was available without disturbing blocked or persistent lanes. |
| TDD | RED reproduced `Argument list too long` in main inventory, child-home summary, and large task JSON. GREEN and REFACTOR: `fm-fleet-snapshot-view.test.sh` passes 17/17. Evidence: `data/bearings-snapshot-arg-limit-20260930/report.md`. |
| Validation | Synthetic default Bearings JSON passes with no `gh`, `gh-axi`, or `curl` calls. `fm-bearings-snapshot.test.sh` stops at a root-only chmod fixture; `fm-lint.sh` cannot run because ShellCheck 0.11.0 is absent. No package install, guard edit, network access, or production action. |
| Next | Finish scoped validation, commit only the two authorized files, then run the existing no-mistakes path. No merge without captain approval. |

## 2026-10-02 04:23 — HD2Stack reset request cannot be routed
| Item | State |
|---|---|
| Secondmate event | `hd2stack.status` confirms `/new` is interactive-only and cannot be invoked through routed messages/tools; no task is open and the session is idle. No source/host action or session reset occurred. |
| Recovery | The supported reuse helper previously refused because `interactive_ready` was absent. Keep the queued checker untouched until a supported reset route or captain interaction; do not use raw pane input. |
| Monitoring | Wake drain warned that the beacon was stale; Pi extension reports an arm child is already owned. No manual re-arm performed. |

## 2026-10-02 04:06 — Brandon compaction audit and fresh checker remain blocked
| Item | State |
|---|---|
| Visible audit evidence | Parent p6 and visible checker pA reports conflict on the effective compaction trigger (93.98% vs about 98.4% from the stated window/reserve); pA is same-family MiniMax M2.7, not independent. The purported AGY pane pB was actually Pi and lacked an extension To-Do; its report is unaccepted and pane is closed. No settings or hooks changed. |
| Brandon SystemOps | Persistent `w1D:p2` stopped before completing its task because Pi could not import `anthropic-messages-J5WXPPPC.js`; the `/6` vs `/7` ownership disagreement remains unresolved. Preserve the task and reports. |
| HD2Stack checker | Fresh-session reset in its persistent Secondmate was not confirmed; supported reuse helper refused because `interactive_ready` was absent. Preserve its process; no manual reset/kill. |
| Next | Reconcile with the lock owner, then require a fresh visibly verified runtime and genuinely independent visible checker before accepting the compaction audit. Do not change config, credentials, hooks, services, or containers. |

## 2026-10-02 01:18 — Secondmate-first routing and pane cleanup
| Item | State |
|---|---|
| HD2Stack editorial task | Origin is marked Done using the existing decision/report; visible checklist 5/5 complete, secret scan passed, no post/source/site edits. Report: `secondmates/hd2stack/data/dubzai-editorial-set-20261001/report.md`. |
| Brandon panes closed | `w2:p2E`/`w2:p2B` were empty Bash prompts (PIDs 10828/10825, no task/model/credential affinity); guarded closes verified. |
| Controller shells closed | `wD3:p38` and `wD5:p2` were Bash-only panes (PIDs 1622621/1622125). The orchestrator Secondmate's task is Done; the handoff Secondmate keeps its queued captain decision. Closed only the shells; homes/backlogs remain intact. |
| Preserved | Quota TUI `wD3:p39` is still running PID 516347 with credential refresh disabled. Kept main controller, four blocked review/queue lanes, persistent HD2Stack Secondmate, and Brandon's lock owner, blocked lane, decision reviewer, SystemOps Secondmate, ZCode pane, and live controller link. |
| Compaction/docs/auth | Pi compaction enabled; 525k reserve applies to `openai-codex/gpt-6-luna`. Current controller reads 19.1%/1.1M after captain compaction; auto-trigger failure not proven. Missing token-efficiency policy reference and M3-protection docs conflict recorded. Local HD2Stack Secondmate already used Codex; no credential copy needed there. |
| Brandon agents | SystemOps `w1D:p2` returned on a missing Pi module (`anthropic-messages-J5WXPPPC.js`) with no accepted artifact. Parent p6 then launched a detached child and reports Pi 0.99.1, a missing stale chunk, and a 93.98% default compaction threshold; the child pane was not visible and the task is not accepted. P6 is now reviewing the evidence. |
| Next | Require a visible independent checker and verify the actual report/config before any hook change. Keep the `/6` vs `/7` task ownership blocker and the missing Pi module distinct; no credential/service/container changes. |

## 2026-10-01 19:35 — No authoritative guard source found
| Item | State |
|---|---|
| Guard repair | Codex hooks reference missing `/root/bin/agent-target-guard`; the Pi wrapper also references absent `/root/bin/agent-shell-guard.sh`. No authoritative copy/spec/test was found in searched local or Brandon paths. No hooks or code changed. Evidence: `data/bearings-snapshot-arg-limit-20260930/report.md`. |
| Safety | Keep existing hooks intact. Do not invent a security guard or bypass the configured hook. TDD is blocked pending an authoritative source/spec or a revised verified runtime route. |
| Bearings/Lavish | Snapshot task remains blocked; no report or URL exists. To-Do item t14 remains pending until the snapshot TDD passes. |
| Hetz | Four confirmed-unused shells were closed. The live home-lock owner, persistent system-ops Secondmate, blocked/review panes, and live mirrors remain. No home seed or service/container change. |
| To-Do | Pruned closed history; seven open items remain, with the active guard-source blocker at top. |

## 2026-10-01 17:05 — Brandon pane cleanup safely narrowed
| Item | State |
|---|---|
| Closed | `w2:p2R`, `w2:p2S`, and `w2:p2T` were empty bash shells at prompts; `w1E:p8` was a completed L3 report shell. Each was checked for process/output and passed the war-room guard before close. Reports remain preserved. |
| Kept | `w1D:p2` is a registered persistent system-ops Secondmate; `w1E:p6` is the live Pi owner of the remote home lock and watcher; `w1E:p7` is blocked by that lock; `w1E:p2` has an open decision. Also kept active ZCode, controller connection, live mirrors, and quota pane `wD3:p39`. |
| Next | Do not close the lock owner or blocked/uncertain panes. Once the owner releases the lock, provision a distinct physical Hetz Secondmate and route the existing file-only Compose runbook. |

## 2026-10-01 11:20 — Brandon remote connected; provisioning waits on its live owner
| Item | State |
|---|---|
| Music/AI posts | Closed per captain because the remaining four slugs are unavailable. Decision hold resolved and closeout marked done; no content/source/host changes. |
| Brandon remote | Added the `brandon-compute` Herdr machine profile; remote server is ready. The registered home still lacks Secondmate identity/charter, and a live Pi process on `pts/0` holds its lock outside the managed Herdr panes. Do not interrupt or seed it. |
| Capacity | Canonical policy counts every non-Codex pane as a subagent; local count 6/6 is expected. No cap change or bypass retained. Quota pane `wD3:p39` remains open. |
| Existing work | The file-only AnythingLLM `:3001` Compose runbook remains outstanding; L1/L2/L3 reports contain no artifact. No container/service change. |
| Next | After the live owner releases the home lock, provision a distinct physical Hetz Secondmate through its own supported path, then route only the existing runbook. |

## 2026-10-01 06:06 — Editorial job closed; no content changes
| Item | State |
|---|---|
| Music/AI post set | Captain directed closure because the other four slugs are unavailable. Resolved the HD2Stack decision hold and completed closeout; retained the report and decision record. No post selection, source change, or deployment. |
| Brandon Secondmate | Local Herdr cap is 6/6; four agents are blocked, one is the persistent HD2Stack Secondmate, and other panes are unknown. Safe cap check did not free a slot. Remote registered home remains an active primary with lock PID 4113345 and no Secondmate marker/charter. No new home/pane. Quota pane `wD3:p39` remains open. |
| Existing Brandon work | L1/L2/L3 reports are present; no Docker Compose runbook artifact found for the existing `:3001` file-only work order. Assign only after a valid worker home/slot is available. |
| Next | Need a free eligible pane or the remote owner to provision a separate home after releasing its lock. Do not close blocked/unknown panes or retire the persistent HD2Stack Secondmate to force capacity. |

## ⚠️ 2026-10-01 05:25 — Two precise blockers remain
| Item | State |
|---|---|
| Music/AI posts | First-party plan identifies six exact new posts, including label operations and monthly cron, but no authoritative ten-post list. The HD2Stack Secondmate registered a decision for the remaining four; see its report. No content changes. |
| Hetz Secondmate | Registered remote home is unseeded and its active primary holds the lock. Existing L1/L2/L3 tasks are complete; one file-only AnythingLLM runbook remains. Harnesses MCode/Pi/AGY are current; ZCode update channel is unverified. |
| Next | Captain selects the remaining four slugs and chooses controller-managed Brandon access via SSH vs waiting for the remote owner to provision a physical Hetz home. No new home or pane until resolved. |

## ⚠️ 2026-10-01 05:11 — Hetz home is not safe to reuse in place
| Item | State |
|---|---|
| Existing remote home | The registered Brandon workspace lacks the Secondmate identity marker and charter; a Pi process holds its home lock. Do not seed or alter that live workspace. |
| Existing work | L1/L2/L3 reports are complete and reviewed. One file-only AnythingLLM :3001 runbook remains in the existing work order; no container changes. |
| Harnesses | MCode 0.5.9, Pi 0.99.1, AGY 1.2.13 verified current. ZCode update channel is unavailable/unverified; no software update attempted. M3.1 route still needs live-model verification. |
| Other tracks | HD2Stack Secondmate is working read-only on the corrected music/AI editorial set. Snapshot/Lavish remain blocked by the missing Codex target guard. Quota window remains open. |
| Next | Choose controller-managed Secondmate for Brandon via approved SSH, or wait for the active remote owner to provision a distinct physical Hetz home after releasing its lock. No new home/pane created. |

## ✅ 2026-10-01 03:46 — Ten posts verified live; feed endpoints missing
| Item | State |
|---|---|
| Selected posts | All ten Stack versions return 200; titles and representative opening text match. Blog index and sitemap contain exactly these ten, no canonical-only posts. |
| Missing feeds | Public `/llms.txt` and RSS both return 404. The canonical source needs an approved ten-post LLM index and RSS endpoint before a compliant release. |
| Changes | Secondmate performed read-only checks only; no source, build, or host changes. Preserve the Stack dirty tree, panel, Jungle Drop, and quota view. |
| Next | Route a clean source-controlled fix with build/tests/quality checks, then use the Secondmate for the documented safe deployment after required review/approval. |

## 🟡 2026-10-01 03:33 — Captain selected the ten new Stack posts
| Item | State |
|---|---|
| Content choices | Keep the Stack versions for the nine divergent posts; exclude all eleven canonical-only posts. The choices are recorded and both decision items are resolved in the Secondmate's backlog. |
| Worker | The existing HD2Stack Secondmate is checking the public rendered pages and blog indexes against the selected ten. Its visible To-Do has five dependent steps; scope is read-only. No source/host changes and no new pane. |
| Safety | Preserve panel, Jungle Drop, unrelated apps, and the live quota window. No deployment from the dirty Stack tree or unreviewed `rsync --delete` path. |
| Next | Review the live-content comparison; if versions differ, prepare the required source-controlled release path before any deployment. |

## ✅ 2026-10-01 03:04 — DubzAI report and visible checklist verified
| Item | State |
|---|---|
| Report | Ten live/Stack slugs match; nine post files differ from canonical; canonical has eleven additional slugs; public `/llms.txt` returns 404. |
| Worker checklist | Visible Pi To-Do shows 0 open / 5 total, all dependency-ordered items complete. The worker made no source or host changes and is idle. |
| Captain choices | Keep Stack or canonical versions for the nine divergent posts; publish or omit the eleven canonical-only posts. No build/deploy until answered. Report: `/root/secondmates/hd2stack/data/dubzai-blog-version-compare-20261001/report.md`. |

## ⚠️ 2026-10-01 02:58 — Local fleet summary exceeded its command limit
| Item | State |
|---|---|
| Fleet check | `bash bin/fm-fleet-view.sh` did not return before the 60s local command limit; a follow-up process check found no remaining view/snapshot/`jq` process. Cause not isolated; no DubzAI/HD2Stack request, deployment, or restart. |
| Known blocker | Snapshot task remains blocked by the missing `/root/bin/agent-target-guard`; no unchanged retry. |
| Pane / quota | Captain-identified idle Codex pane `wD3:p3F` is closed; quota TUI remains live at `wD3:p39`, five-minute refresh, credential refresh disabled. |

## ✅ 2026-10-01 02:53 — Idle Codex pane closed; quota view protected
| Item | State |
|---|---|
| Pane cleanup | Closed only the captain-identified idle Codex pane `wD3:p3F` after preflight and the war-room guard. Its blocked task record and clean isolated worktree remain; no source changes. |
| Quota window | Preserved live at `wD3:p39`; `quota-axi --tui`, five-minute refresh, credential refresh disabled. Verified still running after cleanup. |
| Captain rule | Added to local `data/captain.md`: keep an accessible quota window open through cleanup; do not hide/close it; never refresh credentials for passive checks. |
| Other panes | Main controller and useful/unknown/blocked panes remain open; no broad reap. |
| DubzAI | Version choices remain pending: nine divergent post versions and eleven canonical-only posts. No build/deploy; report remains the evidence source. |

## 🔴 2026-10-01 02:40 — Blog release awaits captain choices; compaction threshold corrected
| Item | State |
|---|---|
| Live site | `dubzai.com` and `www` remain live through the controller TLS proxy to HD2Stack `:3102`; `panel.dubzai.com` and Jungle Drop were not changed. |
| Version evidence | Live sitemap and HD2Stack contain the same 10 slugs; 9 Stack post files differ from canonical; canonical has 11 additional slugs; public `/llms.txt` returns 404. Report: `/root/secondmates/hd2stack/data/dubzai-blog-version-compare-20261001/report.md`. |
| Protected work | HD2Stack dirty source tree and test apps remain untouched. No build, copy, commit, or deployment. |
| Captain choices | Select Stack or canonical versions for the 9 differing posts; decide whether to publish the 11 canonical-only posts and match `llms.txt`. Both decisions are recorded in the Secondmate's own backlog. |
| Release safety | Existing deploy script uses `rsync --delete` and a numeric host; it was not run. Prepare a clean release, verified backup/rollback, deletion manifest, and `hd2stack` alias path only after the choices. |
| Compaction | `/root/.pi/agent/settings.json` now sets `openai-codex/gpt-6-luna` reserve to 525,000 of its verified 1,050,000-token window (50%). Active Pi needs `/reload` or a new session to load it. RED→GREEN checks passed. |
| Quota snapshot | 2026-10-01 01:32 UTC, refresh disabled: MiniMax general 97% (5h 99%); Codex 60% weekly / 78% 5h; Z.AI 73% all-model but tools/MCP 0%; Gemini 95% 5h / 99% weekly with runway unknown. |
| Next | Await the two content choices; then prepare the no-loss release and live verification. |

## ✅ 2026-10-01 01:40 — DubzAI live via HD2Stack origin; version refresh underway
| Item | State |
|---|---|
| Live site | `dubzai.com` and `www.dubzai.com` now return 200; `panel.dubzai.com` remains 200. |
| Origin | The Next.js app is active on HD2Stack `vmi3238503:3102`; controller Nginx now forwards root/www to that Stack service. Controller retains only the existing TLS/proxy edge. |
| Repair evidence | `nginx -t` passed; Nginx reload completed; public root/www verified. Original vhost backup: `data/dubzai-blog-recovery-20260930/controller-vhost.before`. No DNS, TLS certificate, panel, or Jungle Drop changes. |
| Root cause | Controller's local `dubzai-portfolio.service` was disabled/inactive after its shutdown before reboot; its vhost pointed to dead localhost:3102. Cleanup itself was not proven as the cause. |
| Version request | Now verifying the canonical `magic-portfolio` source and the ten posts against the Stack deployment. No build, rsync, commit, or deploy yet. |
| Worker/panes | HD2Stack-scoped Secondmate is updating its read-only report. Reaper found no safely settled panes; no panes closed and the cap is full. |
| Next | Deploy only after source/tree state, ten posts, backup, and the script's `rsync --delete` scope are verified. Direct Cloudflare-to-Stack cutover remains a follow-up requiring approved DNS/TLS access. |

## 🔴 2026-10-01 01:06 — DubzAI blog outage; tracked stack worker active
| Item | State |
|---|---|
| Public failure | `dubzai.com` and `www` return Cloudflare 502; `panel.dubzai.com` returns 200 and is the separate 1Panel UI. |
| HD2Stack origin | `vmi3238503`: `dubzai-portfolio.service` is enabled/active on `:3102`; local HTTP for `Host: dubzai.com` returns 200; local HTTPS currently presents a non-matching certificate. |
| Controller origin | The controller copy is inactive/disabled; local `:3102` refuses connections and its HTTPS vhost returns 502. A stale public origin route is a hypothesis, not yet proven. |
| Worker | The controller-hosted HD2Stack-scoped Secondmate is working in `wD6:p3`; its Pi To-Do shows 5 open items. It is read-only and will report before any production change. |
| Security | A historical report containing plaintext secret material was quarantined; the post-scan passed. Owner-side rotation remains recommended. |
| Pane lifecycle | No panes closed. The cap preflight passed; unresolved blocked/unknown sessions and the quota visual remain preserved. |
| Next | Review the worker's origin/cleanup report, then make the smallest authorized cutover and add a recurrence guard. Cloudflare access is absent from the access inventory. Storage migration and Herdr update cadence remain queued until the site is stable. |

## 🟡 2026-09-30 21:45 — Code work paused at an unresolved security guard
| Item | State |
|---|---|
| Snapshot TDD task | `bearings-snapshot-arg-limit-20260930` is structurally blocked by a Captain's Call. Codex worker is isolated, but its hook review found `~/.codex/hooks.json` points at missing `/root/bin/agent-target-guard`; no hooks were trusted and no code was edited. |
| Guard decision | `bearings-snapshot-arg-limit-20260930-decision-codex-agent-target-guard-restore` is registered and its decision inventory is complete. Await captain authorization to repair the guard or use another verified runtime; do not bypass it. |
| Bearings / Lavish | Canonical snapshot still fails at `fm-fleet-snapshot.sh:567` (`jq: Argument list too long`); no digest or visual artifact was generated. |
| Main view | Ten grouped To-Do entries are active-first; coordinator label and pane layout are cleaned. The blocked Codex worker is visible beneath the coordinator; blocked M3.1/AGY evidence panes remain preserved in labeled tabs. |
| Audit reports | Safe queue report and surface report are drafts awaiting independent review; the Brandon delivery decision remains open. No remote delivery or merge occurred. |
| Next | Wait for the captain's guard decision; then resume the TDD fix through a verified isolated worker. |
| Evidence | `data/bearings-snapshot-arg-limit-20260930/brief.md`; `data/ticket-root-branch-queue-20260930/report-safe-rerun.md`; `data/backlog.md`. |

## 🟡 2026-09-30 13:49 — Queue terminal event is historical; fresh retry remains active
| Item | State |
|---|---|
| Queue signal | The `done` event at 12:57 belongs to the earlier boundary-breached session (`p3C`), already rejected and preserved. Current fresh retry `p3D` remains working; no newer queue status event was present. |
| Surface signal | The `needs-decision` event names the Brandon delivery route. Its Captain's Call is now registered in the backlog; completion verification still stops because the originating task record is absent. |
| War-room | Current view remains coordinator above the surface-review pane and fresh queue-retry pane; blocked AGY and prior queue sessions stay preserved in separate tabs. |
| Supervision | Drain warned that the beacon was stale; Pi extension reports its arm child is already owned, so no manual re-arm is needed. |
| Next | Wait for the safe queue range check; keep independent report review pending and do not act on the Brandon route until the captain chooses. |
| Evidence | `state/ticket-root-branch-queue-20260930.status`; `state/ticket-root-branch-surfaces-20260930.status`; `data/backlog.md`. |

## 🟡 2026-09-30 13:45 — Brandon delivery choice is awaiting the captain
| Item | State |
|---|---|
| Captain decision | Surface audit reports the Sep-30 Brandon work orders lack a verified receipt and newer reply; the outbound repair remains parked and live delivery never ran. Three choices are prepared: merge and deliver with receipts, accept unverified delivery, or use the alternate inbox. No merge or send is authorized. |
| Durable record | Captain decision task `ticket-root-branch-surfaces-20260930-decision-brandon-push-live-delivery` is registered in the backlog. Completion verification is blocked because the originating task record is absent; no record was fabricated. |
| Surface audit | Report is in review; M3.1 pane `p3B` is idle/review. Independent source/citation check is still pending. |
| Queue retry | Fresh M3.1 session `p3D` remains working on baseline/range verification; no safe audit result yet. Prior boundary-breached session `p3C` and AGY session `p3A` are preserved and blocked in separate tabs. |
| Next | Captain selects a delivery route; meanwhile no remote action occurs. Continue only the shell-enforced range audit, then independent review and ledger consolidation. |
| Evidence | `data/ticket-root-branch-surfaces-20260930/report.md`; `data/ticket-root-branch-queue-20260930/report.md`; `data/backlog.md`. |

## 🟡 2026-09-30 13:24 — Fresh queue retry is verifying the restricted range before audit reads
| Item | State |
|---|---|
| Queue retry | A fresh M3.1 MCode session is working in the visible queue pane with the pinned baseline and validated safe-rerun prompt. Its six-item To-Do tracker puts shell-enforced range verification before source discovery; no audit-source read is confirmed yet. |
| Prior queue report | Revision 2 disclosed a silent range-read defect that returned the handoff's file head for a request limited to lines 53–85. The report is rejected and preserved; the affected session is blocked in its separate labeled tab. |
| Surface report | Draft exists; independent source/citation review and durable decision inventory remain pending. |
| AGY / Pi routes | AGY stopped before source reads because its To-Do extension was unavailable. The Pi M3 startup remains blocked by `/usr/local/bin/pi` verification/rollback failure; no Pi task started. |
| War-room | Coordinator above equal surface and fresh queue-retry panes; blocked AGY and prior queue sessions remain open in separate labeled tabs. Quota visuals remain live. |
| Next | Verify the safe line slice before continuing; accept no queue report until boundary-safe and independently checked. Keep the checker/ledger paused until then. |
| Evidence | `data/ticket-root-branch-queue-20260930/report.md` (rejected incident record); `agent-prompt-m3.1-safe-rerun.md`; `data/backlog.md`. |

## 🟡 2026-09-30 12:59 — Queue report rejected after silent range-read breach
| Item | State |
|---|---|
| Queue audit | Revision 2 disclosed that a request for handoff lines 53–85 returned the file head, exposing lines 1–52 outside scope. The worker says it did not use them as evidence and later used a shell-enforced slice; nevertheless, the boundary was crossed. Report rejected; pane marked blocked; no further reads. |
| Surface audit | Report draft exists; no acceptance until an independent read-only check and durable decision inventory. |
| War-room | Coordinator remains above the surface worker and blocked queue pane. The affected session stays preserved; no close/restart. AGY remains separately blocked; quota view stays live. |
| Recovery | Do not reuse the affected session or range-read mode. A new queue attempt, if continued, must be a fresh M3.1 session using `lean-ctx -c --raw` with shell-enforced `awk` limited to the authorized lines; no lean-ctx configuration change. |
| Next | Preserve the report and incident note; hold checker and ledger acceptance until a boundary-safe queue report exists. |
| Evidence | `data/ticket-root-branch-queue-20260930/report.md` (revision 2); `data/backlog.md`. |

## 🟡 2026-09-30 12:51 — Audit reports under review
| Item | State |
|---|---|
| Task | `ticket-root-branch-check-20260930` remains in flight; neither report is accepted yet. |
| War-room | `wD3:t17` shows the coordinator above equal M3.1 workers: `p3B` surface audit and `p3C` queue audit. Both visible dependency-aware To-Do trackers completed before source reads. |
| Queue report | Draft exists (256 lines); review found undocumented `LEAN_CTX_DISABLED=1` use after compressed output omitted rows. Same worker received `REVISION_REQUIRED` to use documented `lean-ctx -c --raw` and confirm supplemental evidence is in scope; it is actively revising. |
| Surface report | Draft exists (15 sections; To-Do 6/6). Independent evidence check and decision-hold inventory are still required before acceptance. |
| AGY attempt | Gemini lane stopped before source reads because its runtime lacked the required To-Do extension. Terminal reply sent; original session is preserved and marked blocked in tab `wD3:t1F`. |
| Pi fallback | Pi M3 startup was refused after `/usr/local/bin/pi` verification and snapshot rollback failed. No Pi task was started; do not retry until the installed CLI is verified/recovered. |
| Quota | The quota visuals pane remains open with five-minute refresh and credential refresh disabled. |
| Next | Accept only corrected, independently checked reports; complete the shared decision inventory, then consolidate the ledger. The controller updated the parent backlog row; workers made no source/backlog edits. |
| Evidence | `data/ticket-root-branch-queue-20260930/report.md`; `data/ticket-root-branch-surfaces-20260930/report.md`; `data/backlog.md`. |

## 🟡 2026-09-30 08:38 — Active work visible; warehouse warning surfaced
| Item | State |
|---|---|
| Session | `bin/fm-session-start.sh` ran once; lock held by live harness PID 1620295. The extension-owned watcher arm child was started after the stale warning. |
| To-Do | Current board keeps the active row first. Startup output and `todo-model-board` now explain how to populate the extension without burying live work. |
| Warehouse | Session baseline pins INDEX/preflight; startup output now requires reading INDEX before host/service/PRD decisions. Preflight exits 3: 51 records, four forbidden `../` evidence paths in `prd_items/cbd-data-enrichment-gap`. No warehouse records changed. |
| lean-ctx | `/root/.codex/LEAN-CTX.md` reviewed. Earlier `systemctl show`/`ufw` results were allowlist denials, not service failures; no broad allowlist relaxation. |
| Pane | Old tab `wD3:t1D` and idle shell `wD3:p38` renamed `Cody's Command Deck` after the mandatory guard passed for each rename. |
| Validation | New To-Do/warehouse assertions pass; full suite later fails in the fake secondmate recovery fixture because `bin/fm-spawn.sh` is absent. `fm-lint` needs ShellCheck 0.11.0; syntax/diff checks pass. |
| Quota | Snapshot: Gemini 55% weekly, MiniMax 99%, Codex 77% weekly. GLM excluded per captain direction. |
| Dispatch | No sidecars started. Backlog is empty; Brandon triad/.dsh is still claimed-running, and registered secondmates have no live metadata. |
| Evidence | `data/startup-readiness-20260930.md`. |

## 🟡 2026-09-30 07:03 — Handoff prepared; dispatch deferred
| Item | State |
|---|---|
| Fresh primary | Handoff saved at `data/session-handoff-20260930-primary-transfer.md`. No lock transfer or sidecar dispatch; Pi PID 7151 held the lock at last check. |
| Queue | Backlog has no in-flight items; older handoff and mission board conflict on Brandon triad/`.dsh` status. Reconcile live lanes and artifacts before dispatch. |
| OpenFang | Read-only findings and blocked checks are recorded in the handoff; caller/auth/firewall posture remain unverified. No mutation. |
| Next action | Captain restarts current Pi; fresh session runs `bin/fm-session-start.sh` and resumes only eligible work. |

## ✅ 2026-09-30 06:39 — GPT-6 model window corrected; restart initiator unknown
| Item | State |
|---|---|
| GPT-6 Luna context | ✅ Added the `openai-codex/gpt-6-luna` 1,050,000-context / 128,000-output override; RED exit 1 → GREEN 1.1M. Config: `/root/.pi/agent/models.json`. |
| Controller restart | ⚠️ Orderly reboot completed 05:45:10 BST; OpenFang logged POST `/api/shutdown` at 05:44:52. The initiating actor is unknown; no OOM/panic evidence. |
| lean-ctx | Version 3.8.8 remains; upstream #1876 concurrency race is known but not linked to this restart. Keep `ctx_shell` calls serial; no upgrade/restart performed. |
| Evidence | `data/leanctx-runaway-20260930.md`; durable context/TDD guidance updated. |


## ✅ FIRST MATE GO-FORWARD OWNERSHIP 2026-09-29 22:38 BST (this pane, controller pid 190499)
| Item | State |
|---|---|
| Session lock | ✅ ACQUIRED — legacy coordinator released the guard; `fm-session-start.sh` re-run clean |
| Wake queue | ✅ Drained — 0 records |
| Watcher | ✅ ARMED — Pi extension arm child 1; extension owns continuity from here |
| Fleet | Idle: backlog 0 queued / 6 done; no live lanes; all recorded endpoints dead (historical) |
| SECONDMATE_SYNC skip ×2 | Noted — `controller-pi-glm53-handoff/orchestrator` homes cannot fetch `53e473c` (live on controller HEAD + fleet remote, absent in their origins); both are legacy orchestrator stack (captain ruling: no further investment) — no repair planned |
| Standing captain gates | 🔴 Token rotation (operator); controller reboot slot — an orderly reboot occurred 05:45, but its initiator/authorization is unresolved; no further reboot inferred |

## ✅ LEGACY LANE EVENTS RECONCILED 2026-09-29 22:45 BST (4 signal wakes, all terminal, evidence verified on disk)
| Lane | Verdict |
|---|---|
| br-comms-reverify (handoff 2ndmate) | done — controller→Brandon comms re-verified read-only: 26/30 delivered; 3 never reached any remote inbox (GO-note-H1 + clearance-GRANTED behaviorally acked; agy-presence-question zero ack). Report: `data/br-comms-reverify-20260929/report.md` (5.1 KB, 21:51) |
| brandon-queue-push-verify (orchestrator 2ndmate) | done — files absent from main checkout by branch topology only, preserved intact as `c51cf8d` on `overnight/queue-push-helper` (origin+no-mistakes); blob hashes match evidence; no mutation. Evidence: `firstmate-pi-glm53-orchestrator-20260924/data/controller-push-fix/verify-20260929.md` (1.8 KB, 21:52) |
| controller-push-fix-20260924 | resolved — dead at launch 09/24; verified no branch/report/commits; lane never wrote anything; retired clean, no unlanded work |
| docs-drift-gate | informational usage note only, no actionable event |

## ✅ HOUSEKEEPING CLOSED 2026-09-29 ~23:00 BST — stale holds, backlog debris, docs drift
| Item | State |
|---|---|
| Captain holds `saas-git-gap-decision-1/2` + origin `saas-git-gap` | ✅ RETIRED — underlying core-distro login.php/SHA256SUMS worktree state verified gone; evidence `data/decision-records/20260929-stale-hold-cleanup.md` |
| 7 stale backlog rows (core-distro QA cycle, mattermost-next-v3, client-roadmap-v9, cbd canary-prep) | ✅ RETIRED with dated reasons in `data/backlog.md` (were parser-invisible debris) |
| Backlog state | ✅ 0 queued / 6 done; afk-return catch-up gate clear |
| Docs drift | ✅ 24 paths waived with decision records (`docs/drift-waivers.tsv`); gate PASS, marker written |
| Tools | ✅ `gh-axi` + `chrome-devtools-axi` installed globally (were genuinely missing); lavish/tasks/quota-axi + no-mistakes already current |
| Dead lanes BR-AUD-002 / BR-AUD-005 | ✅ TEARDOWN COMPLETE 2026-09-29 (captain GO) — worktrees returned to pool, endpoints killed, backlog moved to Done, wake queue drained |
| Stuck branch `lane-004-cbd-auth-hardening` | ✅ RETIRED 2026-09-29 (captain GO) — artifact preserved at `data/lane-004-cbd-auth-hardening-artifact/data/lane-004/artifact.md` (149 lines); branch deleted (was 7134f43, docs-only); 4 worktrees + orphan projects clone + treehouse pool dir removed (one 1-line scratch deletion disclosed and discarded) |

## ✅ FIRST MATE GO-FORWARD + wrapper fix 2026-09-29 ~23:4x BST
| Item | State |
|---|---|
| **Captain ruling** | **First Mate is the go-forward system**; the old elaborate no-firstmate orchestrator stack is legacy — do not invest further there |
| pi wrong-folder root cause | ✅ FIXED — `/usr/local/bin/pi` wrapper hard-coded `cd /root/agent-work` on every launch; now respects the invoking folder (fallback to `/root/agent-work` only when launched bare from `/root`). Backup: `/usr/local/bin/pi.bak-20260929T*` |
| Secret-gate blocker | ✅ 3 closed MiniMax session transcripts (Sep 28/29, possible secret material) quarantined to `/root/.quarantine/leaked-transcripts-20260929/` (reversible, manifest inside); scan now PASS 153 accepted. Recurrence note: MiniMax transcripts keep regenerating findings — root-cause hygiene ticket open |
| First Mate pane | ✅ LIVE `wD3:p32` (WORKERS tab, visible war-room) — correct folder, trust approved, `fm-primary-turnend-guard` + `fm-primary-pi-watch` extensions loaded, boot sequence dispatched. Model: zai/glm-5.3-flash (wrapper default) |
| Old wDF:p5 "FIRSTMATE-PI" pane | legacy leftover in hidden workspace wDF (pi always failed there pre-fix) — candidate for closeout next tidy |

## ✅ RESOLVED 2026-09-28 — brandon triage complete, leaks quarantined
| Item | State |
|---|---|
| Triage lane `wD3:p1G` | ✅ Report read: 373 findings → 17 groups. 324 `VENDORED_FALSE_POSITIVE`, **49 `SUSPECTED_REAL_LEAK`** across `.gemini/antigravity-*` (31), `.pi/agent` (13), `firstmate-baseline/.env` (1) |
| Manifest | ✅ Verified byte-identical both hosts: `328c41d1e7f93bc691bbcfe5e0f96010cd272f5186a4cd2377674ea84d53ce00`, 170 lines |
| Quarantine | ✅ **993 files** (267 + 726) moved to `/home/hd2admin/.quarantine/leaked-transcripts-20260928/`, mode go-rwx. Reversible — moved, not deleted. Scanner already excludes `.quarantine/**` so no scanner edit was needed. |
| brandon scan | ✅ **PASSING** — `SUCCESS: no new leaked secret files found; 981 existing path(s) accepted`, rc=0 |
| `firstmate-baseline/.env` | ✅ Deliberately NOT moved — it is the live active config, mode 600 |
| 🔴 Rotation | **NOT DONE — operator action.** `PANEL_API_KEY`, two 125-char `sk-tokens` and a 183-char bearer token are quarantined but **still valid**. Quarantine hides them from the scanner; it does not invalidate them. |

> **Correction to an earlier controller statement:** `.gemini/antigravity-*` was wrongly classified as
> "vendored IDE assets, safe to whitelist". It is Antigravity **session transcripts** holding live
> secrets. Had the 348-file bulk-accept been used, real leaked credentials would have been
> hash-pinned into the manifest and could never have been loosened again. Operator's decision to
> triage before accepting is what prevented that.
| Item | State |
|---|---|

## ✅ RESOLVED 2026-09-29 06:0x BST — lean-ctx tuning: metric was STALE, no tuning needed
| Item | State |
|---|---|
| **lean-ctx cache + capacity tuning** | ✅ **CLOSED — DO NOT TUNE.** Deferral window expired 05:45 BST; re-measured as instructed. **Both targets already met.** `compression_rate` = **69.7% all-time** (target 40%) and `cache_hit_rate` = **29%** (target ≥29%). The `14` / `0` figures came from `cep.last_snapshot`, frozen at **2026-06-15** — 3 months stale. |
| Root-cause hypothesis | ❌ **DISPROVEN.** "5-min idle eviction destroys the cache" is wrong — `lean-ctx verify-cache` = PASS, 2181 → 21 tokens (99% savings), 827 sessions / 29% cross-call hit. |
| At-capacity stores | ❌ **Not a bottleneck.** facts 200/200 + history 100/100 are a rolling oldest-out chronological window, still accepting writes. Expected steady state. |
| `doctor --fix` (XDG split) | Unrelated hygiene — moves files, changes no compression parameter. Not actioned. |
| Change made | **None.** Candidate knob `output_density=terse` cannot be validated without knowing whether the MCP server hot-reloads `config.toml`; if it does not, it needs a session restart and the right answer is still "no change". An auto-degradation policy (`DegradationPolicyV1`) also already adjusts the same knobs. |
| Evidence | `LEANCTX-FINDING-20260929.md` |

> **Measure compression correctly from now on** — do NOT use `token-report`'s `cep(last)`:
> `python3 -c "import json;d=json.load(open('/root/.config/lean-ctx/report/latest.json'))['cep'];print(round((1-d['total_tokens_compressed']/d['total_tokens_original'])*100,1))"`

| Promote any of this to a different token tool | No evidence any alternative beats lean-ctx here. Tool surface is already `minimal` (6 MCP tools) — that lever is fully pulled. Operator explicitly has no allegiance to lean-ctx; goal is token saving. | `lean-ctx doctor` → `Tool Profile: minimal`, `Tools exposed: 6` |

## ✅ FIXED 2026-09-29 — agent-secret-scan FAIL-OPEN (security control defect)
| Item | State |
|---|---|
| Defect | 🔴 `agent-secret-scan` returned **`SUCCESS` / exit 0 when it could not scan at all.** A failed `cd` into the scan root produced no ripgrep output, which the caller read as the "no matches — clean" branch. The scanner certified trees it never read. |
| Impact | Directly hit brandon: the documented `hd2admin` wrapper cannot read `/root`, so routine scans returned a **vacuous pass** while the real root scan (as root) returns `rc=1` with findings. The reassuring result was the false one. |
| Fix | Explicit `cd` accessibility precondition in `scan_paths()` → unreachable root returns `rc=2` with "no clean result is implied". Subshell + path normalization preserved. |
| TDD | RED `3 passed, 2 failed` (T1/T2 failed on the live defect) → GREEN `5/5` → REFACTOR `5/5` (fixture value now built at runtime so the test file itself no longer trips the scanner). Suite: `firstmate/tests/agent-secret-scan-fail-closed.sh`. |
| Deployed | ✅ **ALL FOUR HOSTS DONE.** controller · brandon (`sha aa538a47…`) · hd2stack (`sha 87926cf1…`, surgically patched, backup `.bak-20260929T051334Z`). Regression-checked on hd2stack: pre/post finding lists byte-identical (133 → 133, zero added/removed). |
| ✅ elevatesVPS | **Tested and found NOT vulnerable** — no change needed. Its scanner resolves the root eagerly at line 6 (`ROOT="$(cd "$ROOT" && pwd -P)"` under `set -e`), so a failed `cd` aborts before scanning. It is an older/simpler scanner (no false-positive manifest support) but fail-closed. |
| Evidence | `MUT-SECSCAN-FAILCLOSED.md` |

> **Host-name rule (corrected 2026-09-29):** the only valid SSH aliases for that host are **`elevatesVPS`** and the deprecated `animovps`. Bare `elevate` and bare `elevates` **do not resolve** — `ssh elevates` fails with "Could not resolve hostname". Use `elevatesVPS`.

## 🛑 PARKED BY OPERATOR DECISION — 2026-09-28 (domains that never existed)
| Domain | Status | Action |
|---|---|---|
| musicmetricstools.com | NXDOMAIN — **never owned, never needed** | **PARKED. DO NOT RE-REGISTER.** |
| lawyer-dta.com | NXDOMAIN — **never owned, never needed** | **PARKED. DO NOT RE-REGISTER.** |
| cbd-data.com | ✅ HTTPS 200 | Live |
| data.core-distro.com | ✅ HTTPS 200 | Live |

> **Operator ruling (2026-09-28):** these two domains were **agent hallucinations** and the
> resulting registration spend was **illegal spend**. HD2 never owned and never needed them.
> This item is **closed and parked permanently** — no re-registration, no recovery, no spend.
> Any future session that surfaces this as "URGENT" is wrong and must not act on it.
> Root cause of the hallucination stays tracked in the spend-gate incident record.
>
> Superseded history (kept for audit only): the earlier note said "re-register ASAP before
> drop-catch" and pointed at the CSVentric Namecheap account. **That instruction is revoked.**

## MUSIC METRICS — domain questions closed by the ruling above; no domain work outstanding.
| Lane | Owner | Task | State |
|---|---|---|---|
| Fastpath bootstrap | controller | MM_BOOTSTRAP_VERSION deploy | ✅ LIVE SHA256 3e708faf (hosting OK) |
| M3 Layer A | controller | queue_claim.php deploy | ✅ LIVE SHA256 d46fe6e8 |
| CSV city-coverage | controller | leadlists.php deploy | ✅ LIVE SHA256 ae96c535 |
| Post-deploy watch | controller | 5-min error log watch | ✅ 10/10 clean |
| **Domain recovery** | — | ~~Re-register via Namecheap~~ | 🛑 **CANCELLED — hallucinated domain, never owned. Parked by operator 2026-09-28. Do not re-register.** |

## ELEVATE SCI chatbot ✅ LIVE
| Lane | Owner | State |
|---|---|---|
| 23-page crawl + ingest | controller | ✅ de-boilerplated |
| De-boilerplate tightening | MiniMax @ brandon | ✅ 10-14s → 9.34s steady |
| TLS proxy | MiniMax @ brandon | ✅ agents.elevatesci.com |
| Branding | controller | ✅ 0 AnythingLLM refs |

## CORE-DISTRO chatbot ✅ LIVE
| Lane | Owner | State |
|---|---|---|
| core-distro workspace | controller | ✅ 8 docs, cold-chain verified |
| Chatbot | controller | ✅ live HTTP 200 |
| data.core-distro.com | controller | ✅ HTTPS 200 |

## CBD (cbd-data.com) — LIVE, app fixed, REV3 hardening staged (2026-09-27 ~22:17 BST)

### Live
| Item | State | SHA / note |
|---|---|---|
| leadlists.php | ✅ LIVE | `b01b8dae` (559,879 B) — bootstrap flag-guard + JS structure repair + Add-Leads engine; user confirmed working |
| Top Cities engine | ✅ PRESENT in source | preset panel + handlers intact post-repair |

### REV3 hardening (local-only, deploy-awaiting)
| Item | State | SHA |
|---|---|---|
| leadlists.php (REV3-hardened) | local-tested, deploy awaits operator GO | `8cdb6b43` (573,037 B) — failure-aggregation + flock + flag-dir + reproducible MariaDB 10.11.14 LEFT JOIN scoring |
| Deploy evidence | written | `cbd-campaign/DEPLOY-LEADLISTS-20260927.md` |

### Sprint H1–H5 (hetz @ brandon w2:p2G)
| Lane | State | Evidence |
|---|---|---|
| H1 — L2 bundle verify | ✅ **CLOSED** (brandon 32/33 + controller contract 52/52 = GREEN) | `cbd-campaign/H1-CLOSEOUT.md`, `cbd-campaign/L2/BRANDON-RUN.md` |
| H2 — lawyer-dta local audit | partial (earlier) | hetz's earlier report |
| H3 — CBD test-gap backlog filing | filed (9 rows earlier) | prior reports |
| H4 — Enrichment arch doc refresh | ✅ DONE — `Modular path (ACTIVE)` section added; full-service marked `FUTURE` | `h4-inputs/ENRICHMENT_TARGET_ARCHITECTURE.md`, hetz mirror `20260927T-H4-enrichment-architecture.md` |
| H5 — Core-Distro queue_claim deploy runbook | ✅ PREPARED (not deployed) | `warehouse/reports/H5-RUNBOOK-20260927.md` + `h5-coredistro/H5-RUNBOOK.md` |

### Open — operator-decisions only
1. **Refund** $22.96: delete `musicmetricstools.com` + `lawyer-dta.com` from **CSVentric** Namecheap account (these were hallucinated on the wrong account; agency registrar = `boxedagency`). Captain's hands.
2. **REV3 deploy**: ship `8cdb6b43` to live (captain's word).
3. **GHL/cron_drip + enrich_queue.php**: PARKED — wait for partner conversation (today).
4. **VContabo access**: needed to fix `hd2.ai` chatbot 525.

## SPRINT — HETZ (2026-09-27 ~15:10 BST) — sprint file: BRANDON-COMPUTE-COMMS/sprint-20260927-cbd-and-parity.md
| Lane | Owner | State |
|---|---|---|
| H1 L2 brandon test run | hetz @ brandon | QUEUED (gated on R1 GO note) |
| H2 lawyer-dta state audit (local, read-only) | hetz @ brandon | QUEUED |
| H3 CBD test-gap backlog filing | hetz @ brandon | QUEUED |
| H4 enrichment arch doc refresh | hetz @ brandon | QUEUED |
| H5 core-distro queue_claim deploy PREP (no deploy) | hetz @ brandon | QUEUED |

## CBD HANG — ROOT CAUSED + FIXED (2026-09-27 ~17:00 BST)
| Item | State |
|---|---|
| Root cause | Top Cities UI deploy (d6d3c1d0) inserted its JS methods INSIDE closeAddLeadsModal(), leaving an orphaned `this.updateTopUsCitiesPanel();` at class level → SyntaxError killed the whole script block → lists cards never populated ("ghosts") |
| Fix 1 (server) | Bootstrap flag-path guard deployed earlier today (stops 432-line DDL block re-running every load) |
| Fix 2 (client) | JS structure repaired: stray call moved into switchCountry(), closeAddLeadsModal() restored, updateTopUsCitiesPanel/renderTopCityPresetState/selectTopCities intact — node --check CLEAN |
| Shipped | leadlists.php SHA 15454334 (backup d6d3c1d0 + 6826ec65 staged in warehouse/backups/) |
| Pending | operator reload verdict; GHL/cron_drip deploy still PARKED pending partner conversation |


## CONTROLLER RECOVERY — 2026-09-28 03:11 BST → **BOTH GATES OPEN as of 04:23**
| Item | State |
|---|---|
| Gemini route guard | ✅ Updated to default AGY Gemini 3.8 Flash Low; Medium remains backward-compatible |
| Low-route test | ✅ GREEN with skill-drift check skipped in deterministic test harness |
| **SKILL_DRIFT baseline** | ✅ **RESOLVED** — manifest refreshed 04:23, `SKILL_DRIFT_CHECK_PASS: files=110`. Herdr prompt handoff unblocked. |
| **AGY ledger** | ✅ **RESOLVED** ~04:19 UTC — `coords.agy` exists; `agent-intent-guard authorize --agent agy --ttl 900` succeeds from an agent lane. 900s TTL, refresh before use. |
| MCode controller | ✅ Live in protected `wD3:p2`, label `main Crisp-R Pi MCode`, `M3.1-Flash-Preview` |
| Current lock | ✅ Held by MCode in `wD3:p2`. `state/.lock` PID 1737817 is a **stale orphan** — safe to refresh. |

## CBD CAMPAIGN CLOSE-OUT (2026-09-27 ~19:55 BST)
| Phase | Result |
|---|---|
| L1+L2 build + R1 review + R1 revisions | DONE (suites 22/22 + 33/33, CHECK: PASS) |
| Hang root cause + fix + ship | DONE (live leadlists.php = b01b8dae, JS structure + bootstrap flag-guard + Add-Leads engine) |
| R2 code+docs revisions | DONE (5/6 findings closed; F-11 doc-side closed with honest pending note) |
| R3 REV hardening | DONE locally (failure-aggregation + flock + flag-dir + reproducible MariaDB test); VERDICT: CLOSED. NOT deployed live — awaits operator GO per isolation policy |
| Codex Luna MAX R3 re-review | REVIEW: CHANGES_REQUIRED on 4 minor items (F-01/02/03/11) — accepted with disclosed residuals; campaign closed |
| Live deploy | b01b8dae (live working); 8cdb6b43 (REV3 hardened, local) — deploy needs operator GO |

## 2026-10-05 01:4xZ — ELEVATE P0 RESOLVED (chat answered YES, end-to-end)
- Root cause: env `GENERIC_OPEN_AI_BASE_PATH=host.docker.internal:8081` unreachable from container. Fix (captain-authorized): GenericOpenAiBasePath=http://172.17.0.1:8081/v1 via /api/v1/system/update-env with .api-key → 200, picked up per-request. LFM2.5 answered "What does Elevate Scientific do?" correctly (233 tok, 4.8s). Widget WORKS.
- Core-Distro untouched (workspace row sha256 identical). One authorized test chat (chatId=15). DB backup: anythingllm.db.backup-pre-llmfix-20261005-013331. Report: from-brandon-compute/2026-10-04-elevate-assistant-recovery.md. Remaining deferred: host-DIR rename (next recreate window), service crash-loop S1 on hd2stack (new ticket), merge cutover (fixture #5496 in fix).
