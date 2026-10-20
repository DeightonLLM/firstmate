# Fleet board — Core first

Authoritative execution baseline: `data/2026-10-20/core-execution-baseline/baseline.md`.
Live task status: native To-Do extension; this file is a durable navigation record, NOT that live tracker.
Current execution receipt: `data/2026-10-20/core-execution-baseline/execution.json`.

## Captain's questions — saved, not left to scroll

- **Security approval needed:** HD2 reports exposed RapidAPI and Replicate keys. Captain was asked to authorise rotating both and updating existing consumers; possible interruption, NO approval/rotation inferred. Saved relay: native46 and `data/2026-10-20/core-execution-baseline/hd2-owner-assessment.md`.
- **Answer still needed:** whether to commit the already-reviewed Core harness fix. No approval recorded.
- **Deferred; no answer needed now:** the two-job MCode quota exception. Primary is checking HD2's actual setup first. Captain has NOT approved it. Source: `data/2026-10-20/core-execution-baseline/admission-assessment.md`.
- **Current requested explanation:** why HD2 MCode's own “5h 24%” stays unchanged. Local MCode0.6.12 source decodes it as24% REMAINING of Token Plan five-hour quota; HD2's build/account/fresh reading STILL UNKNOWN. A fixed number alone proves neither free usage nor a stale display. Fresh owner settings export pending. Source: `data/mcode-system-sidecar/comparison-assessment.md`.

This is navigation, not a replacement backlog or approval system. Ahoy recaps visible session events/questions; silence never answers a decision.

## Where the behaviour is actually documented — read upstream, do not improvise

The upstream docs fully explain how Herdr and the firstmate harness work. Prefer them over inference, and
prefer a documented invocation over an improvised one.

**Harness / agent runtime** (`/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/docs/`):
`how-pi-works.md` · `tui.md` · `models.md` · `custom-provider.md` · `providers.md` · `settings.md` ·
`compaction.md` · `codemode.md` · `containerization.md` · `environment-variables.md` · `extensions.md` ·
`configuration.md` (context files) · `security.md` (context loading)

**Subagents and delegation** (`/home/hd2admin/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/`):
`SKILL.md` plus `references/` — `execution-controls.md`, `prompting-and-roles.md`,
`constraints-and-recipes.md`, `review-and-validation.md`. In-session, `subagent({action:"guide",
options:{topic:"…"}})` serves the live tool reference, including workflow recipes, lane metadata,
execution and budget guidance. Prefer the guide over recalled tool shapes — this session twice relied on
memory and was wrong.

**Herdr** is a terminal workspace manager for coding agents: `herdr --help`, then `herdr tab list`,
`herdr workspace list`. Herdr tab labels are presentation, not identity; pane titles do not prove which
agent or model is running. See `data/learnings.md` (2026-09-24) and `bin/fm-harness.sh` for what a pane
label may and may not be used to infer.

**Firstmate's own contract** lives in this repo, not upstream: `AGENTS.md` is the standing contract,
`AGENT-TODO-PROMPT-STYLE.md` solely owns naming, `.agents/skills/` holds the agent-only skills, and
`docs/README-index.md` indexes the rest.

**Agent startup context (how Pi finds its context file):** Pi loads ONE context file per directory, first match
wins, in the order `AGENTS.override.md`, `AGENTS.md`, `AGENTS.MD`, `CLAUDE.md`, `CLAUDE.MD`, and the agent
directory, the working directory, and parent directories all count, so a file at a shared parent path reaches
every domain below it. `AGENTS.override.md` is the per-directory override and applies in its own directory only;
the agent directory `~/.pi/agent/` currently holds no context file at all. Upstream statement:
`configuration.md` (context-files section) and `security.md` in the harness docs directory above; shipped
resolver at
`/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/resource-loader.js:116`,
ancestor walk at lines 168-190.
**Measured state 2026-10-20:** secondmate homes carry a month-old, mutually divergent startup context; no
`AGENTS.override.md` exists on any home; a shared parent file reaches every domain; two live homes sit on a
diverged lineage the local fast-forward contract will not force. Source: `data/learnings.md` (2026-10-20).
**Detector, landing in a parallel lane:** the re-runnable per-home domain-identity check is being built as
`bin/fm-domain-identity.sh`, with its contract to live in `docs/domain-identity.md`. Read that contract there
before claiming any home is synced.

## Session handoff from the previous first mate (2026-10-19)

Read this before trusting anything inherited from that session. Its most expensive mistake is recorded
here so it is not repeated.

**Landed and pushed — verified 0 unpushed:**
- Core `a46cea9` — both Add Leads defects fixed and merged. The REAL bug was
  `.slide-backdrop.open { pointer-events: auto }` (`staged-export-test/leadlists.php:5165`) swallowing the
  header click, fixed by `f26d4d8`; the secondary z-index fix is `65f28e8`. Read
  `docs/core-saas-branch-state-map.md` before touching Core — do not re-derive which branch holds what.
- Firstmate `b5fae02c` — lane-key contract enforcement (harness segment + run-id uniqueness, both with
  negative controls), `fm-whoosh-fixture.sh`, `fm-astra-licence.sh`, `fm-brief-preflight.sh`, and
  `AGENT-FLEET-KNOWLEDGE.md` (18 rules, propagates to all surface agents).
- Seven Core branches that had **no remote at all** are preserved under `origin/archive/…`.

**The lesson, at the top because it cost real time:** before writing any fix, list the branches and read
their commits. That session wrote and pushed a fix that already existed on another branch, then spent a
lane proving it. A fix for the same symptom on a branch makes that branch the source of truth.

**Claims from that session that are WITHDRAWN — do not cite:**
- Whoosh parity v6/v7/v8/v9 figures: the analyzer had hardcoded input paths and measured v6-era captures.
- Whoosh "260px too tall": against a repaired reference the port is **677px SHORT**. The old reference was
  failing 38 of 52 subresources including 9 fonts.
- "Core is REPAIRED": single vantage only, recorded as INSUFFICIENT EVIDENCE.
- "Core backup is DONE": same-host only, **no off-host copy exists anywhere**.
- "Elevate VPS is KVM1": the Elevate VPS is `srv1137994` / `45.90.220.156` / `100.69.211.43` (Captain ruling
  2026-10-19). **KVM1 / `srv797124` is our own infrastructure**, not a client host.

**Open risks carried forward:** no off-host backup anywhere (restic evaluated and recommended); the
Whoosh reference bundle exists in exactly one place; `agents.core-distro.com` and
`agents.whooshperformance.com` are dead pending HD2's DNS; `agents.elevatesci.com` serves auth-gated;
origin certificate for `data.core-distro.com` invalid and expiring 2026-11-17.

**Obey `surface-first`:** run `bash bin/fm-surface-preflight.sh <keywords>` before escalating anything to
the Captain. That session escalated questions that were answerable from disk, which is a documented
recurring failure.

## Current delegation

Captain requested less primary execution and the job list moved to the existing interactive MCode second mate. Consolidated instructions: `data/mcode-system-sidecar/consolidated-job-list.md`. **OWNERSHIP ACCEPTED**, correlated receipt dcbde8f5fbd859cb in boardkeeper.status: existing interactive MCode / requested and worker-measured MiniMax-M3.1-Flash; own native tracker and queue. This resolves the earlier unconfirmed send without a retry. First technical priority is Sol-only automatic compaction <=50% under49; **not yet applied**. Routine list follow-through and compaction handoff48 now belong to the second mate; memory remains over-budget until evidence says otherwise. Primary retains actual Core dispatch and Captain-only decisions. No new agent or Core worker launched. Core holds and Captain decisions below are unchanged.

## Main focus: CORE

Captain approved SAVE, PLOT, EXECUTE. All new execution uses proper interactive MCode CLI / M3.1 Flash this promotional week. No fresh Luna/Gemini/Codex/M2.7 or headless/async workaround.

| Work | Owner | Actual state / dependency | Evidence |
|---|---|---|---|
| Installer counterfactual | Primary dispatches dedicated MCode CLI worker | Approved but UNEXECUTED.05:05Z original code check now PASSES API-source61%; managed CLI coverage remains unestablished and retry identity unresolved. No new Core worker running. | Existing `data/m3.1f-brandon-installer-counterfactual/brief.md`; `data/2026-10-20/core-execution-baseline/admission.stderr` |
| Add Leads partial inventory | Primary dispatches separate MCode CLI worker | Read-only inventory prepared and preflight PASS; NOT launched. Independent of installer once admission passes. Do not rewrite partials or canonical source. | `data/m3.1f-brandon-addleads-inventory/brief.md` |
| Canonical Lead Lists/Top Cities | HD2 ownership ACKNOWLEDGED | Fresh owner reply reports corrected branch926cfbb/canonicalb4de449b green but NOT merged into main43eae3d; no PR URL supplied. No independent verification/merge here. | `data/2026-10-20/core-execution-baseline/hd2-owner-assessment.md` |
| Migration0043/0044 | HD2;0044 confirmation pending | Production data export and valid origin certificate still block cutover; DNS unchanged.0044 was incorrectly stood down assuming our old worker6 covered it; correction sent, native47 waits for ownership confirmation. | Same assessment and original inbound reply |
| Packaging at43eae3d | Completed scoped evidence | Prior14/14 permitted checks, deterministic reproduction and bounded independent PASS. NOT a release including later proposed fixes. Do not rerun to fill lanes. | `data/2026-10-20/core-local-validation/` |
| Reviewed harness change | Captain decision / primary | Commit approval remains unanswered. No commit/merge inferred from execute-plan approval. | Native task5; original candidate/review preserved |
| Final integration/artifact | Primary-selected integration worker | QUEUED behind accepted candidates, canonical ownership and explicit commit/merge authority. | Execution baseline |

Fresh canonical source HEAD:43eae3d34e7a47e6060d8d50093b7f5ab345b66a. Untracked `evidence/` exists and must survive; source is NOT clean.
Below-six reason: two useful new authorised Core deliverables, completed checks already closed, one separate canonical owner; no filler or scope expansion.

## System sidecar — separate from Core conversation

Existing proper persistent interactive MCode Boardkeeper, endpointdefault:w60:p2, display **MCode M3.1 - SYSTEM SIDECAR**.
Role/own-charter/own-tracker acceptance confirmed corr2b42063b4e95d211; requested/served Flash distinguished, access not free-billing proof.
All new system work routes here; legacy Pi system-ops stays parked. Sidecar launches NO agents and executes NO client/Core tests or edits.
Canonical role: `data/mcode-system-sidecar/brief.md`.

- **Admission diagnosis received:** corr=e8a53ce5a48c96a9; current local quota uses Pi API source, while MCode uses managed login. Applicable CLI numeric allowance remains unmeasured. The proposed lab correction only refuses more accurately; it does not admit anything and is NOT applied. Primary assessment corrects overclaims and the reset-as-unblock proposal. Source: `data/2026-10-20/core-execution-baseline/admission-assessment.md`.
- **Correction accepted:** corr=1ab3afc7d3e99ba5 withdraws the causal overclaims and reset-as-unblock route; revised lab guard reports28/0 but remains unapplied and does not admit Core.
- **Current system priority:** HD2-vs-Brandon primary/worker settings and exact HD2 MCode counter. Interactive sidecar accepted8228b9629a0890c2/653fa4e53e15e92f and produced the LOCAL half; HD2 settings/footer export still awaited (Core owner reply is not it). Bounded follow-up asks for a supported safe native account/status readout, not a quota integration, private token access or extra model call. No async/new provider/config changes. Numeric exception45 stays deferred.
- **Calm:** sidecar reports both ctx-renderer and shared-install home-resolution patches/tests in own lab, uncommitted and NOT installed/globally delivered. New home-resolution tests pass; three pre-existing suite failures remain unchanged. Global+project automatic loading would duplicate registration, so rollout must address that before any install/reload. Preserve all patches; do not claim Captain's visual issue fixed.
- **Surface:** classification/planning only, no Herdr lifecycle authorisation. Protected main, quota monitor and unlanded work preserved.

## Admission and continuity

Post-reset05:05:55Z API-source quota: general5h100%,7d61%; original check PASSES exit0/effective61. The CODE refusal has cleared, but managed CLI numeric coverage has not been demonstrated. No new Core launch, quota exception or free-billing claim.
IMPORTANT: this API reset/old check PASS does not settle CLI coverage. The observation timer was acknowledged, exact hash-verified hook/trust archived and retired. Continue the HD2/native status comparison; do not claim the code still refuses or auto-launch from a different readout. Captain task45 is the explicit bounded decision; no exception inferred. Formal decision registration is blocked by the known tasks-axi refusal; preserve the private record and do not mark investigation formally complete or teardown.
Existing Pi supervision remains extension-owned; do not arm another cycle after routine events.

## Preserved history and unresolved evidence

Prior complete board archived at `data/2026-10-20/core-execution-baseline/board-before.md`; prior controller state beside it. Existing theme/instruction/Add Leads partials and old evidence are retained, not silently accepted or deleted. Registry legacy/schema disagreements remain unresolved and owned by sidecar tracking.
External controller-replies read was refused; no alternate-tool/path retrieval. Do not claim a fresh HD2 reply was read.
No whole-Core acceptance, commits, publication, deployment, global Calm rollout or cleanup claimed.
