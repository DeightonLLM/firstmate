# Kun Lane placeholders — current-state scope report

**Reviewed:** 2026-10-13  
**Task:** `scope-kun-lanes-20261013` (read/report only).  
**Boundary:** No config, source, settings, project, or credential/auth-store changes; no agents dispatched; no secondmate homes read. This report is the only artifact written outside the isolated task worktree.

## Executive result

| Backlog entry | Verdict | Reason |
|---|---|---|
| `kun-concurrency-impl` | **OBSOLETE** | A configurable, spawn-enforced Firstmate live-lane ceiling has since landed. The old `parallel-dispatch-cap` home setting does not match the landed `dispatch-max-lanes` key. Nothing in the inspected evidence authorizes treating `50` as Firstmate's live-lane ceiling or changing a current setting. |
| `kun-config-inventory` | **READY TO SCOPE** | Its 2026-01-26 report is stale against current Pi settings and current dispatch profiles. A bounded refresh has specific files, checkable output, and safety boundaries below. |
| `kun-video-source-study` | **ALREADY SATISFIED** | The existing Lane A report answers the original source-study question: it reports no universal Kun concurrency key and distinguishes the cited Fable 50% quota from a configurable concurrency limit. No duplicate public-source study is justified by the evidence inspected here. |

## Evidence and current facts

### Backlog and prior deliverables

- `/home/hd2admin/kun-agent-workspace/data/backlog.md` lists the three entries as one-line items under `## In flight`; the `kun-*` rows have no ticket bodies or acceptance criteria (the task rows are around lines 125–145; `ctx_read` of lines 1–25 confirms the backlog format and current in-flight section).
- Existing Lane A study: `/home/hd2admin/agent-work/firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-A-video-source-study.md`. Its lines 12, 49–55, and 164–170 say no universal concurrency key was found and describe the 50 cap as Fable quota rather than a configuration key. Its section 5 lists the YouTube and repository URLs. This is an existing report, not a fresh verification of public pages in this task.
- Existing Lane B inventory: `/home/hd2admin/agent-work/firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-B-config-inventory.md`. Its date is 2026-01-26 (line 3); it asserts a `config/parallel-dispatch-cap` cap at lines 5–13 and records Pi M2.7 defaults/reviewer at lines 54–80 and 207–217. These values do not describe current Pi settings or the current Firstmate guard contract.

### Firstmate concurrency capability

- `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/10/kun-agent-workspace/docs/FLEET-STATUS-20261012.md:136–153` says the durable cap change landed as `1ad17ff`, with precedence `FM_DISPATCH_GUARD_MAX_LANES` → `config/dispatch-max-lanes` → default `4`; it records historical verification `PASS=52` plus `PASS=4` at line 153.
- In this source, `bin/fm-dispatch-guard.sh:25` names the supported config key. Lines 207–218 resolve the key and default. Lines 221–256 count live lanes and refuse another lane once the ceiling is reached. `bin/fm-spawn.sh:637–646` calls this guard before backend/worktree/state mutation. `tests/fm-dispatch-guard-max-lanes.test.sh:36–90` checks config override, default, environment precedence, and malformed-value fallback.
- The home-local `/home/hd2admin/kun-agent-workspace/config/parallel-dispatch-cap` was read and contains `6`; the adjacent current code expects `config/dispatch-max-lanes`, not `parallel-dispatch-cap`. Reads of `/home/hd2admin/kun-agent-workspace/config/dispatch-max-lanes` and the task worktree's `config/dispatch-max-lanes` returned file-not-found. Consequently, the old value `6` is not evidence of the current guard's effective configured ceiling; where no supported knob is present, the code's documented fallback is `4`.
- Exact live runtime inventory of every task endpoint was not performed. The cap's current runtime effect is evidenced by its source and historical test record, not a fresh run in this task.

### Current Pi, Codex, and Firstmate configuration evidence

- Read `/home/hd2admin/.pi/agent/settings.json`. Lines 4–5 set provider `minimax` and default `MiniMax-M3.1-Flash-Preview`; lines 8–17 register `pi-subagents` and pin its default/reviewer to M3.1; lines 38–40 enable `pi-codex-fast` mode `fast`; lines 60–71 list enabled models and omit MiniMax M2.7. The settings' line 29–30 area contains M3.1 compaction override. These are configured settings, not proof that every model-store record has been deleted.
- Read `/home/hd2admin/.pi/agent/models-store.json`. Its MiniMax catalog still contains entries for `MiniMax-M2.7` and `MiniMax-M2.7-highspeed`, alongside M3.1. Thus the accurate distinction is that M2.7 is absent from the current `enabledModels` setting while an old catalog record remains; the model-store alone must not be reported as the active default or as proof of retirement. The current dispatch config explicitly says not to select M2.5/M2.7 families and gives retirement dates; those dates and provider retirement status were not independently checked with the vendor.
- Read `/home/hd2admin/kun-agent-workspace/config/crew-dispatch.json`. Lines 3–30 define active three-role modes A/B and the no-M2.5/M2.7 note; lines 35–79 contain task routing and fast flags; lines 65–71 pin the reviewer profile to M3.1. This is the current local dispatch policy, distinct from the Pi primary default in `settings.json`.
- Read `/home/hd2admin/.codex/config.toml` without reading `auth.json` or session stores. Lines 1–5 still show `gpt-5.6-luna`, `xhigh`, `approval_policy="never"`, `sandbox_mode="danger-full-access"`, and `service_tier="default"`. This is Codex's global configuration; it is not evidence that Codex is the active Pi primary.
- `git ls-tree --name-only HEAD` in the isolated Firstmate worktree showed no root `package.json`; Firstmate's own relevant runtime source is its tracked `bin/`, `docs/`, and tests. Pi's current settings register four npm packages: `pi-subagents`, `@calesennett/pi-codex-fast`, `@juicesharp/rpiv-todo@2.12.0`, and `pi-lean-ctx`. Installed package manifests were read for `pi-subagents` (repository `nicobailon/pi-subagents`), `@juicesharp/rpiv-todo` (repository `juicesharp/rpiv-mono`, `packages/rpiv-todo`), and `pi-lean-ctx` (repository `yvgude/lean-ctx`, `packages/pi-lean-ctx`). The `@calesennett/pi-codex-fast` manifest contains no repository field, so its source repository remains unknown from inspected local evidence. No plugins outside the current settings registration and the named relevant package manifests were audited.

## Per-entry disposition and ticket content

### 1. `kun-concurrency-impl` — **OBSOLETE**

**Why:** Its motivating claim that Firstmate lacks a configurable concurrency/live-lane ceiling is superseded by the landed, tested `config/dispatch-max-lanes` implementation. The old Lane A/B material does not prove that 50 should mean 50 simultaneously live Firstmate agents: Lane A describes the cited 50 as a Fable percentage quota limit, while Lane B's six-lane setting uses an old, unrecognized key. The current code default is 4 when no supported key is present. No config value was changed.

**Recommendation:** Do not dispatch a ship ticket merely to add the already-existing knob. Do not translate the number 50 into `dispatch-max-lanes=50` without a separately explicit operational instruction. If a future request is to change the home-local cap, its sole candidate path is `/home/hd2admin/kun-agent-workspace/config/dispatch-max-lanes`; owner intent/value is not established by this read-only task.

**Hard boundaries:** No code/config write, no cap increase, no alteration of the legacy `parallel-dispatch-cap`, no concurrency stress test, no agent launch, no inference from provider quota to worker count.

**Provenance:** `docs/FLEET-STATUS-20261012.md:136–153`; `bin/fm-dispatch-guard.sh:207–256`; `bin/fm-spawn.sh:637–646`; `tests/fm-dispatch-guard-max-lanes.test.sh:36–90`; existing Lane A report lines 49–55 and 164–170; existing Lane B report lines 5–13 and 207–217.

**Verdict: OBSOLETE.**

### 2. `kun-config-inventory` — **READY TO SCOPE**

**Dispatchable scout ticket:**

> Refresh the stale Lane B Firstmate/Codex/Pi configuration and installed-package inventory against the files listed below. Produce one sanitized report that separates (a) configured and enabled models from model-store catalog entries, (b) policy/routing preferences from mechanically enforced behavior, and (c) currently observed settings from historical claims. Explicitly reconcile the old `config/parallel-dispatch-cap=6` record with the current `config/dispatch-max-lanes` guard/default. Inventory package names and repository provenance only from installed Pi package metadata; mark absent repository metadata unknown. Report the M3.1 primary default, M2.7 enabled-versus-catalog distinction, fast-mode flag, both three-role mode definitions, reviewer pin, Codex config, and the evidence path for the enforced Firstmate lane ceiling. Do not change any file or setting.

**Exact read scope:**

- `/home/hd2admin/.pi/agent/settings.json`
- `/home/hd2admin/.pi/agent/models-store.json` (model catalog only; no auth or credential files)
- `/home/hd2admin/.pi/agent/npm/node_modules/{pi-subagents,@calesennett/pi-codex-fast,@juicesharp/rpiv-todo,pi-lean-ctx}/package.json`
- `/home/hd2admin/.codex/config.toml` (configuration only; explicitly exclude `auth.json`, sessions, history, and credential stores)
- `/home/hd2admin/kun-agent-workspace/config/crew-dispatch.json`
- `/home/hd2admin/kun-agent-workspace/config/parallel-dispatch-cap` and `/home/hd2admin/kun-agent-workspace/config/dispatch-max-lanes` (read-only existence/value comparison)
- Firstmate source: `bin/fm-dispatch-guard.sh`, `bin/fm-spawn.sh`, `tests/fm-dispatch-guard-max-lanes.test.sh`, `docs/FLEET-STATUS-20261012.md`
- Existing comparison artifact: `BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-B-config-inventory.md`

**Objective acceptance criteria:**

1. Report a row for every requested config surface with exact path, observed value or absent, date/read method, and whether evidence is configuration, policy, enforcement, or historical report.
2. State M3.1 default/reviewer and fast enabled from settings; state M2.7's absence from enabled models separately from its presence in the model catalog; do not claim provider retirement from local config alone.
3. State Codex values from its global config without opening auth stores, and avoid conflating that config with active Pi primary selection.
4. Identify all four settings-registered Pi packages and cite each local manifest's repository value, or state unknown if absent.
5. Show that the current enforcement key is `dispatch-max-lanes`, with env/config/default precedence and guard invocation; distinguish the legacy `parallel-dispatch-cap=6` value from the effective supported knob.
6. Record any current value or source provenance that cannot be verified as `unknown`; do not edit or normalize it.
7. No credentials/auth stores, network/browser requests, installation, setting changes, code edits, or plugin execution.

**Still unknown:** Whether the main-home legacy `parallel-dispatch-cap=6` is intended to migrate to the new key, whether the desired live ceiling should remain 4 or be another value, and the source repository for `@calesennett/pi-codex-fast`. This inventory-only ticket must report those unknowns, not resolve them by writing settings.

**Provenance:** Pi settings reads and `ctx_grep` matches at lines 4–17, 38–40, and 60–71; Codex `config.toml:1–5`; Firstmate `config/crew-dispatch.json:3–30,35–79`; `bin/fm-dispatch-guard.sh:207–256`; package manifests named above; prior Lane B report lines 3, 54–80, and 207–217.

**Verdict: READY TO SCOPE.**

### 3. `kun-video-source-study` — **ALREADY SATISFIED**

**Why:** The existing Lane A artifact is a completed report for the same video/public-source/concurrency question and already concludes that no universal concurrency config key exists and that the cited 50 cap is provider-side quota, not a user key. That finding removes the premise for another source-study ticket solely to discover a `concurrency=50` setting. The current Firstmate cap implementation was separately located in its source and acceptance test.

**Disposition limits:** The existing Lane A report's assertions were not independently re-fetched from YouTube, X, or GitHub during this task. Its own study-date line says `2025` while also mentioning a transcript dated `2026-09-13`; that chronology is unresolved. This does not change the disposition of the duplicate study ticket, but no claim here upgrades that report to a freshly verified public-source audit. If a future task requires current upstream fact-checking, it must name specific source pages/claims and produce direct source evidence rather than repeat the broad title.

**Hard boundaries:** No network/browser access or public source requests were made for this task; no inference that `max_trees=50` or Fable quota sets Firstmate's live-lane cap.

**Provenance:** Existing `Kun-Lane-A-video-source-study.md:3–5,12,49–55,164–170` and section 5 URL list; current Firstmate `bin/fm-dispatch-guard.sh:207–256` and `tests/fm-dispatch-guard-max-lanes.test.sh:36–90`.

**Verdict: ALREADY SATISFIED.**

## Commands and inspection record

Read-only evidence collection used Pi/lean-ctx `ctx_read`, `ctx_grep`, `ctx_ls`, `ctx_find`, and `ctx_shell` for:

- `pwd; git rev-parse --show-toplevel; git status --short --branch; git rev-parse HEAD`
- `git ls-tree --name-only HEAD`
- `git -C /home/hd2admin/agent-work/firstmate rev-parse --show-toplevel; git -C ... status --short --branch`
- targeted reads of `~/.pi/agent/settings.json`, `models-store.json`, `~/.codex/config.toml`, `config/crew-dispatch.json`, `config/parallel-dispatch-cap`, both Lane A/B reports, Firstmate guard/source/test and package manifests listed above.

The Pi settings read did not include `auth.json`, `trust.json`, session files, or credentials. The Codex read did not include `.codex/auth.json`, sessions, or history. One package-enumeration shell command was rejected by the local shell allowlist because it began with a `for` loop; it was not retried. Specific installed package manifests were read individually instead. No test was run in this read/report task; the test result cited above is the dated historical result in `docs/FLEET-STATUS-20261012.md`, not a test run performed here.

## Completion-gate state

The report's semantic inventory contains no new captain decision requiring dependent work: no setting change is recommended or authorized, and the unresolved cap migration/value is explicitly assigned as unknown in the proposed read-only inventory ticket. However, the shared `decision-hold-lifecycle` gate requires recording a completion attestation through `bin/fm-decision-hold.sh complete` in the originating authoritative home. That would write outside the two specifically permitted external paths (this report and the task status file), so it was not run. The shared gate is therefore **not passed**, and this report is not marked done. Firstmate must perform/authorize the originating-home completion attestation before closing the scout.
