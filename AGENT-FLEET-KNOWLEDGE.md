# Agent Fleet Knowledge

**Purpose:** operational rules for agents who have not worked in this fleet before. These rules summarize dated local evidence; they do not grant authority, capability, host access, or production approval. Recheck live quota, tool behavior, and canonical records before acting. `UNKNOWN` means the cited material does not establish a fact.

## Operating posture

- The Captain identifies the most precious resource as **their time and attention**, not compute, machines, or panes. Do not create unrequested work, surface routine gate fights, or ask the Captain to make ordinary reversible in-scope decisions. Preserve unlanded work. Evidence: `data/captain.md` (2026-10-17, Captain/Crisp-R position).
- Current dispatch configuration names MiniMax M2.7 workers through the `mcode` CLI, with controller review; availability and quota remain live facts, not implied by configuration. Evidence: `config/crew-dispatch.json` (2026-10-19).
- Distinguish reported, transmitted, received, acknowledged, and accepted. Keep evidence artifacts and verdicts; a worker summary or a sent label alone is not proof. Evidence: `data/learnings.md` (2026-10-13 operational discipline); `data/captain.md` (2026-10-18/19 communication and lane rules).

## Ten binding rules

### 1. MEASURE QUOTA BEFORE EVERY DISPATCH

Run `quota-axi --json` before each dispatch/model choice. If the relevant provider window is at 0% or reports `runway: exhausted_now`, do not dispatch to that provider. A projected reset time is not runway. If quota kills a run mid-task, preserve its partial evidence and do not retry that run on the same provider; use a different measured available path only when authorized. Evidence: `data/learnings.md` (2026-10-19; quota miss and Captain correction); `data/captain.md` (quota intake and no false capacity claims, 2026-10-13 onward); `config/crew-dispatch.json` (2026-10-19).

### 2. ALL MINIMAX GOES THROUGH MCODE

For this configured regime, dispatch all MiniMax work through the `mcode` CLI: credits work only through that CLI; do not use another MiniMax route. `mcode exec` profiles use `--permission smart` for ordinary bounded work. Headless `ask` requires TUI/ACP, so smart-mode elevated operations can fail with `HOST_CAPABILITY_UNAVAILABLE`; `--permission full` is only for a fully bounded lane whose exact write boundary, resources, and cleanup are explicit. External-CLI runners stream no token counters to the parent; per-call usage is recorded in `~/.minimax/v2/sessions/<date>/<session>/messages.jsonl`, in the `usage` fields. Evidence: `config/crew-dispatch.json` (2026-10-19; active profiles, permission modes, and usage-record location). Verify current profile and quota at intake; config alone does not prove a run used that model or permission.

### 3. DISPATCH SO THE CAPTAIN SEES LANE NAMES

Launch async work as a workflow whose child `key` is the convention lane key and whose `label` is human-readable (for example, `runs.all([{ key, label, agent, task }])`). A direct single-child launch renders as a bare agent name. The workflow argument must be a script path, not pasted fenced code; the latter fails with `ENOENT`. Verify the visible lane name and actual execution evidence before calling it started. Evidence: `data/learnings.md` (2026-10-19 dispatch-panel correction); `data/captain.md` (2026-10-17 lane-visibility ruling); `AGENT-TODO-PROMPT-STYLE.md` (ACTIVE, Captain renewed 2026-10-18).

### 4. WRITE A REGISTRY ROW AT DISPATCH

Create a durable row for every lane when dispatching; record its run identity, lane key, model, surface, task, state, and output path, then update state at every phase change. Never relabel a lane after dispatch. Do not report a lane started or done without its artifact path and verdict. The board and To-Do list are views, not substitutes for the registry. Evidence: `data/captain.md` (2026-10-17 async lane and `data/async-lanes.tsv` contract); `AGENT-TODO-PROMPT-STYLE.md` (ACTIVE, 2026-10-18); `data/learnings.md` (2026-10-13 worker-summary verification).

### 5. BOARD HYGIENE

Keep only live or genuinely blocked work on the live board. Remove finished, superseded, cancelled, or handed-off items as soon as the durable outcome is recorded. Keep exactly one `in_progress`; every remaining item names owner, state, and dependency/blocker. Never call a board clean while a completed item remains. Evidence: `AGENT-TODO-PROMPT-STYLE.md` (ACTIVE, 2026-10-18); `data/captain.md` (2026-10-13 real-time To-Do correction); `data/learnings.md` (2026-10-13 operational discipline on false in-flight backlog rows).

### 6. REPEATING `oldText must match exactly` MEANS STALE TEXT

A repeated exact-edit failure is stale source text, not a permission guard. Re-read current bytes; make one minimal edit using a short unique span; syntax-check immediately. After a second failure, stop and hand back the exact current function text. Do not retry a full rewrite or reach for `sed`/`perl` to bypass the edit tool. Evidence: `data/learnings.md` (2026-10-19; repeated Luna and MCode edit failures).

### 7. POOL WORKTREES INHERIT THE PARENT HOME'S `data/projects.md`

Pool worktrees may inherit the parent home's project registry even when there is no `projects/` clone directory. Treat a registry with no clones as stale pool evidence, not project data; correct the evidence source and preserve the guard. The reports measured that the current guard refused the phantom registry and passed only after the stale registry file was removed; they do not prove that the guard itself now accepts a registry-without-clones. Never weaken or delete the guard to force seeding. Evidence: `CONTROLLER_STATE.md` (2026-10-18 blocker, carried forward in the 2026-10-19 pool notes); `data/2026-10-19/pool-phantom-cleanup/report.md` (2026-10-19 measured cleanup and guard dry-run); `data/2026-10-19/pool-metadata-repair/report.md` (2026-10-19, earlier recommendation to change the guard).

### 8. FORBIDDEN AND SENSITIVE HOSTS

`srv1137994` / `animovps` / Aminolifesciences is entirely off limits: do not touch, probe, resolve, dispatch to, or route work to it. The recorded Elevate VPS is `srv797124` at `100.69.211.43`; that is an attributed identity, not proof of current connectivity. The authority is `data/2026-10-19/CANONICAL-HOST-REGISTER.md`; absence of a record is `UNKNOWN`, never evidence that a host does not exist, is free, or is safe to use. Stop and report exact need when work appears to require the forbidden host. Evidence: `data/learnings.md` (2026-10-15 Controller standing STOP; reinforced by 2026-10-19 records sync); `data/2026-10-19/records-sync/report.md` (2026-10-19 correction); `data/2026-10-19/CANONICAL-HOST-REGISTER.md` (corrected 2026-10-19, with confidence labels).

### 9. PIXEL-PARITY REQUIRES A TRUSTWORTHY REFERENCE

Capture both sides with identical setup; freeze video to the same `mediaTime` and require both a `seeked` event and `requestVideoFrameCallback` proof; await `document.fonts.ready`; pause animations; use exact comparison with no masks or tolerance. These steps do not certify that intended fonts loaded or that the reference is faithful: audit its requested subresources and record each status before treating it as a target. Error pages/wrong-site captures never pass. A raw changed-pixel percentage is not parity; retain images, identities, and the actual comparator verdict. Correction (2026-10-19): the earlier wording could be read to treat `document.fonts.ready` as proof of font success and omitted reference-resource integrity; that inference is disproved by the failed font/resource audit and is not valid. Evidence: `data/2026-10-19/luna-six/tablet-reference/capture-tablet.js` (2026-10-19; capture setup); `data/2026-10-19/luna-six/reference-fidelity/report.md` (2026-10-19; 38/52 failed resources, including nine fonts); `data/2026-10-19/site-execution/review-disposition.md` (2026-10-19; error-page identity and comparator failures); `data/2026-10-19/luna-six/wp-integration/report-followup.md` (2026-10-19; whole-page comparison is FAIL, not parity).

### 10. AUTHORISATION IS NOT CAPABILITY

A gate refusal is the system telling the truth. Find the supported invocation, correct the evidence source, deliberately change the design through its owner, or stop and report; never delete a check, invent authority in a brief, or bypass a refusal. A brief cannot override a gate. Evidence: `data/learnings.md` (2026-10-13 operational discipline); `data/captain.md` (2026-10-13 gates-are-architecture rule); `data/2026-10-19/pool-phantom-cleanup/report.md` (2026-10-19 guard preserved while source metadata was corrected).

## Eight additional rules from 2026-10-19 evidence

### 11. A VERDICT IS ONLY AS GOOD AS ITS TARGET

Before measuring a candidate, audit the reference: fetch every requested subresource and record its status. On 2026-10-19, 38 of 52 resources on the Whoosh “original” failed, including nine fonts; parity work against it produced plausible but untrustworthy numbers. A broken target can be worse than no measurement because it looks like data. State reference fidelity before any verdict. Evidence: `data/2026-10-19/luna-six/reference-fidelity/report.md` (2026-10-19).

### 12. A HYPOTHESIS THAT CLOSES ZERO OF A MEASURED GAP IS REFUTED

Measure the counterfactual; if it closes zero pixels, record the refutation and move on rather than continuing to tune that theory. The missing-`page.php` theory changed homepage height by 0px across tested widths; the duplicate-widget theory was false because the candidate had one instance, original zero, and no duplicate removal to perform. Evidence: `data/2026-10-19/luna-six/template-candidate/report.md` and `data/2026-10-19/luna-six/widget-dedup/report.md` (2026-10-19).

### 13. COUNTERFACTUAL OVERSHOOT MEANS CHECK OPPOSITE-SIGNED ERRORS

If removing a feature changes height more than the measured gap, do not infer a single cause from net totals. Removing widget nodes dropped height by 946px to 7,275px, although the measured gap was only 260px; the resulting candidate was 686px below the 7,961px reference. The candidate therefore also lacked roughly 686px of reference height. Rank deltas by sign as well as magnitude; net totals can conceal opposing errors. Evidence: `data/2026-10-19/luna-six/widget-dedup/report.md` (2026-10-19).

### 14. FONT-READY DOES NOT PROVE THE INTENDED FONT LOADED

`document.fonts.status === 'loaded'` and a completed `document.fonts.ready` can coexist with a failed intended face and fallback rendering. Verify the required face/request itself; fallback metrics change wrapping and element height. Evidence: `data/2026-10-19/luna-six/reference-fidelity/report.md` (2026-10-19; nine font 404s despite the capture routine awaiting fonts).

### 15. MACHINE-CHECK WRITE-BOUNDARY BRIEFS

A brief that excludes a path in its declared boundary but also requires writing there is defective. Use the mandated form and run `bash bin/fm-brief-preflight.sh <brief>` before dispatch. The preflight rejects the contradiction and has executable negative controls. Evidence: `data/2026-10-19/brief-preflight/report.md` (2026-10-19).

### 16. PAUSE ON CONTRADICTORY INSTRUCTIONS; FIX THE BRIEF

A lane that stops to clarify a contradictory instruction is behaving correctly, not stalling. Correct the brief; do not tell the lane to choose an interpretation. Evidence: `data/2026-10-19/brief-preflight/report.md` (2026-10-19; historical contradiction rejected by preflight).

### 17. A BROKEN REFERENCE CHANGES THE COUNTERFACTUAL

When the reference's own dependency is broken, it is not automatically the true product. Explicitly state reference fidelity before drawing a verdict, including when removing a resource from the candidate. Evidence: `data/2026-10-19/luna-six/reference-fidelity/report.md` and `data/2026-10-19/luna-six/widget-dedup/report.md` (2026-10-19).

### 18. LONG PIXEL COMPARISONS ARE NOT AUTOMATICALLY HANGS

Full-page PNG decoding in pure Python can take minutes per invocation. For slow comparator iterations, direct the lane to report from evidence already held instead of repeating expensive work; a timeout with no report produces no usable result. Evidence: `data/2026-10-19/luna-six/visual/report.md` (2026-10-19; comparator capture/test evidence) and `data/2026-10-19/warehouse-recovery/report.md` (2026-10-19; absent primary evidence cannot be reconstructed from retained summaries).

**Narrow watcher-lock ruling, not a general bypass:** HD2 endorsed reclaiming an empty watcher-lock owner directory only through `fm_lock_try_acquire()`'s stale-steal path and `fm_lock_mid_acquire_is_fresh()` check; honor the minimum 2-second race window. This specific evidence-based recovery does not authorize bypassing other locks or guards. Evidence: `/home/hd2admin/controller-replies/2026-10-19-hd2-formal-reply-to-crispr-watcher-and-tracker.md` (HD2 reply, 2026-10-19T06:25Z).

## One rule from 2026-10-20 evidence

### 19. AN AGENT MUST KNOW WHICH DOMAIN IT IS IN, AND THAT MUST BE PROVABLE

Domain identity is a measurement, not an assertion.
A home carries its own identity in its own directory, using the harness's own per-directory override file `AGENTS.override.md`, which applies in that directory only and cannot silence the agent directory or a parent.
A shared parent instruction file reaches every agent below it, so it may carry a fleet-wide tool or safety note and must never carry domain identity, scope, or charter.
"I read the startup files" is not evidence that they are synced or domain-specific, so prove it per home by measuring which context file that home's agent actually loads and whether that file's content matches the authority for that home.
A fleet-wide verdict must be printed by a tool, state a reason for every failure, and exit non-zero when a home fails.
A stale or diverged home is reported and escalated as a lineage decision, never forced, because forcing discards unlanded work.
The check must be re-runnable, because a one-time manual audit decays into a false claim.
Evidence: `data/learnings.md` (2026-10-20, section "agent startup context"); `data/captain-shared.md` section 4 (2026-10-20); Pi's shipped context-file resolver at `/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/resource-loader.js:116` with the ancestor walk at lines 168-190.

## Source conflicts and limits — do not silently resolve

1. **Host identity conflict (safety-critical):** `data/learnings.md` (2026-10-15 Controller STOP) identifies `45.90.220.156` with forbidden `srv1137994` and prohibits touching it. The corrected `data/2026-10-19/CANONICAL-HOST-REGISTER.md` also attributes that address as the public edge for Core staging, while separately recording the KVM1/identity dispute and warning not to infer reachability. This consolidated rule preserves the absolute STOP; it does not authorize staging access at that address. **Owner for reconciliation:** Controller/host-register owner. Until a new authoritative resolution, treat the address as forbidden.
2. **Lane-key format conflict:** `data/captain.md` (2026-10-17) gives `<model>-<surface>-<task>`; active `AGENT-TODO-PROMPT-STYLE.md` (renewed 2026-10-18) specifies `<harness>-<model>-<host>-<task>`. Both require a convention key visible as the child key; this document does not choose a format. **Owner:** Captain / owner of `AGENT-TODO-PROMPT-STYLE.md`.
3. **Pool guard behavior/ownership conflict:** `CONTROLLER_STATE.md` describes the seed guard as treating the inherited registry-without-clones state as project-less, but the measured `pool-metadata-repair` and `pool-phantom-cleanup` reports say the current guard refuses while phantom registry rows remain and passes only after the stale metadata is removed. The latter reports also propose changing guard logic, while the accepted directive is to fix evidence, not weaken the guard. This document does not claim the guard implementation changed. **Owner:** shared tracked guard owner; preserve the guard unless its owner approves a tested design change.
4. **Model availability/route conflict:** older portions of `data/captain.md` contain retired Luna/M2.7 routing directions and later notes say M2.7 retired for new users on 2026-10-19; current `config/crew-dispatch.json` (2026-10-19) explicitly selects M2.7 workers through MCode under the later Captain directive. Treat the current config as the present requested route, but measure quota and actual availability before every dispatch; do not claim availability from either prose or config alone. **Owner:** Captain (selection/availability direction) and current quota evidence (capacity).
5. **Visible task-prefix conflict:** `AGENT-TODO-PROMPT-STYLE.md` defines `[<harness>·<model> @<execution-host> | <owner-role>]`; `data/captain.md` records the cross-surface enforced HD2 form `[<harness>·<ModelAbbrev> <effort> @<Host>]`, while `AGENTS.md` has a third `[owner @ host] task — state` form. This lane does not edit those owners' instructions or choose a winning prefix; follow the relevant surface's measured enforcement and preserve exact actual model/host evidence. **Owner:** Captain / cross-surface tracker owner. Evidence: `data/captain.md` (2026-10-18 standing comms + tracker rules); `AGENT-TODO-PROMPT-STYLE.md` (ACTIVE, 2026-10-18); `AGENTS.md`.

## Source-bounded status reminders

The 2026-10-19 programme report states that Core staging restore proof passed but hosting-panel backups remain UNKNOWN; Elevate/CBD panel backups remain UNKNOWN; PA-04 remains unmerged pending Captain authority; Whoosh whole-page parity is FAIL and deployment/DNS remain unproven. Do not broaden these bounded findings into completion or production claims. Evidence: `data/2026-10-19/programme-status/PROGRAMME-STATUS-20261019.md` (2026-10-19); `data/2026-10-19/backup-automation-run/report.md` (2026-10-19); `data/2026-10-19/pa04-readiness/report.md` (2026-10-19).
