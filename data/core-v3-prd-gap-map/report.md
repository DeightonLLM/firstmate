# Core Distro V3 acceptance gap map

Date: 2026-09-26  
Task: `core-v3-prd-gap-map` (read-only scout)  
Scope: inspect the provided Core Distro checkout and the explicitly named local PRD/evidence paths. No project files, tests, refs, branches, remotes, builds, browser captures, deployment state, AnythingLLM, or Docker/port 3001 were changed or used.

## Finding and confidence boundary

**The Core Distro product V3 acceptance source is still missing, so product V3 completion cannot be scored or mapped criterion by criterion.** The available local anchor, `projects/firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`, is explicitly Brandon's multi-project infrastructure PRD, not a product specification for Core Distro. It has six Core Distro infrastructure acceptance checks in §20.1. Those are listed separately below and must not be treated as the missing product criteria.

`projects/core-distro.com/` is absent from the local `projects/` directory. The other two context files do exist: `docs/warehouse/anythingllm/STACK-MAP.md` records the Core chatbot tenant as `UNKNOWN` and says its canonical workspace, index, source repo, and prompt are not established; `FIRSTMATE_COORDINATOR_KICKOFF.md` is a coordinator planning document and contains no Core Distro product V3 acceptance criteria. The product acceptance source therefore remains missing. The saved Stream A and mobile-footer reports are present and usable within their stated scope. The Core Distro checkout itself identifies `staged-export-test/` as canonical editable source and `current-core-distro/` as legacy reference (`README.md:7-12`; `SOURCE_OF_TRUTH.md:35-60`). No source beyond these named local paths was attempted.

## Product acceptance matrix

The following is the complete honest matrix possible from the available source: one unknown row for the unavailable authoritative product acceptance set. Expanding it into guessed product criteria would misstate acceptance.

| Criterion | Status | Exact evidence | Remaining action |
|---|---|---|---|
| Complete Core Distro product V3 acceptance set | unknown | No product V3 PRD or product acceptance file appears in the inspected Core Distro checkout. `SOURCE_OF_TRUTH.md:35-60` establishes source ownership and release procedure, not product criteria. `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:1,43,1870-1914` identifies itself as Brandon's multi-project infrastructure PRD and gives infra acceptance. `projects/core-distro.com/` is absent. The locally present `docs/warehouse/anythingllm/STACK-MAP.md` records Core as `UNKNOWN`, and `FIRSTMATE_COORDINATOR_KICKOFF.md` covers coordination rather than product criteria; neither supplies the missing acceptance set. | Source custodian must provide the canonical product V3 acceptance document (exact path, revision/version) and any acceptance evidence directory. Then enumerate every criterion and map it against source and saved evidence before stating a completion percentage. No product implementation ticket can be assigned safely before this. |

## Brandon infrastructure PRD: Core Distro checks only

These six checks are recorded to answer the requested comparison with the local V3 anchor. The matrix makes no claim that they are product V3 requirements. PRD source: `projects/firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md`, §20.1 (`1870-1880`).

| Infrastructure PRD §20.1 criterion | Status | Evidence | Remaining action / gate |
|---|---|---|---|
| Public site loads over HTTPS | blocked | PRD §20.1. Local code/source docs do not provide current live HTTPS evidence. `SOURCE_OF_TRUTH.md:35-60` describes canonical local source and artifact rules. | Operator-approved deployment and production URL access, then capture HTTPS verification. Deployment/operator gate. |
| Quote/contact submission is durable | unknown | PRD §20.1. No named saved report demonstrates durable quote/contact persistence, and the product V3 source is absent. | Obtain product source/acceptance details; use a disposable local DB or approved production evidence as authorized. Source-access and runtime/build gate as applicable. |
| Uploaded or downloadable documents respect authorization | unknown | PRD §20.1. `projects/core-distro-saas-clean/tests/local_lane_test.php` at commit `2eb4e12d` only checks login and lead-list auth source markers; it does not establish document-specific authorization. This file is not present in the scout's checkpoint-baseline worktree. | Identify document flows from authoritative source, then test authenticated and unauthorized access with approved local configuration. Source access and runtime gate. |
| Any lead-enrichment job uses the Core queue and Core credentials only | unknown | PRD §20.1. `projects/core-distro-saas-clean/tests/local_lane_test.php` at commit `2eb4e12d` checks job states and claim/complete route markers, not Core-only queue/credential isolation. No live queue evidence was supplied. | Need approved architecture/source mapping plus safe local queue/credential test inputs. Source-access and operator authorization gates. |
| Core data does not appear in another project's database, logs, files, or backup | blocked | PRD §20.1. No cross-project isolation evidence is in the available Core source reports. The requested `projects/core-distro.com/` artifact directory is absent; the warehouse map exists but records Core as `UNKNOWN` without isolation proof. | Supply project-local data inventory and approved isolation test plan; run only with authorization and non-production data. Source-access and operator gate. |
| Core backup restores successfully | blocked | PRD §20.1. No Core restore report is present in the inspected evidence. | Operator/source custodian supplies approved backup and isolated restore target; record restore verification. Operator authorization and runtime access gate. |

## Existing Core Distro evidence (bounded; not product acceptance)

| Evidence area | Status | Exact evidence and limits | Remaining action |
|---|---|---|---|
| Canonical source vs legacy snapshot | evidenced | `README.md:7-12`; `SOURCE_OF_TRUTH.md:35-60` say `staged-export-test/` is canonical and `current-core-distro/` is legacy/reference only. | None for source ownership. The requested product criteria still need their own authority. |
| Checkpoint baseline | evidenced | `git show checkpoint-baseline --stat --oneline` resolves tag `checkpoint-baseline` to `ba233e1b558d2282b446e4d72f6e29520964c642`, “feat(index): add cross-platform language nav”, changing `staged-export-test/includes/theme_bootstrap.php` and `staged-export-test/index.php` (+642 lines). It is a provenance checkpoint, not an acceptance document. | Use as baseline only when relevant product requirements are supplied. |
| Completed local lane A harness | evidenced for its local source-contract scope | Commit `2eb4e12d33106a71f3e7439c053df9080c4adca6` (“test(core-distro): add local lane acceptance evidence”) adds `LOCAL_DEVELOPMENT.md`, `RELEASE_METADATA.md`, `bin/core-distro-local-check.sh`, and `tests/local_lane_test.php` (179 insertions). No tests were run for this scout. The saved prior report describes no-secrets checks and source-contract checks; these are not production/runtime acceptance. | No extra harness ticket is justified by this scout. If product criteria map to those files, retain their existing ownership and open only a discrete uncovered criterion. |
| Stream A language navigation/category/toast/artifact | evidenced for saved report scope | `data/stream-a-language-nav/report.md:11-17`: 55-entry artifact, language navigation 29/29, category 15/15, toast 21/21, PHP syntax, checksum, fresh-build byte match; report states work remains local and uncommitted and no merge/deploy occurred. | Reconcile the existing `stream-a-language-nav` worktree before assigning any overlapping code. Its status currently includes changes to `staged-export-test/assets/saas-toast.js`, `staged-export-test/includes/theme_bootstrap.php`, plus untracked scripts/tests/archive and `node_modules`; preserve it. |
| Mobile footer contrast | evidenced for saved review scope | `data/core-footer-readonly-review/report.md:50-80,84-95`: saved light 6.55:1 and dark 4.69:1 results; PASS in saved review. Coverage was Pixel 7 emulation and 1280×800 only in post-fix assertions, copyright plus first footer link; no physical Android evidence. The source worktree status shows edits in `staged-export-test/index.php`, `tests/run.sh` and untracked evidence/test scripts. | No additional fix is evidenced. Reconcile `fm/core-mobile-fix` first; do not assign its files to another worker. Broader viewports/links would be a separate QA task only if the authoritative criteria require it. |
| Runtime authentication, persistence, health, external services | blocked | `projects/core-distro-saas-clean/LOCAL_DEVELOPMENT.md` at commit `2eb4e12d` says the deterministic check requires no credentials/DB/network, while runtime start needs environment-specific `config/*.php` and MySQL/MariaDB; its explicit gates state fresh-database install and browser acceptance are not executable from the sanitized checkout. This file is not present in the scout's checkpoint-baseline worktree. No runtime/browser evidence was collected here. | Provide sanitized local config and disposable DB/API access, plus authorization for a runtime pass. Do not use production secrets. Runtime gate. |
| Release artifact and deployment | blocked | `SOURCE_OF_TRUTH.md:40-53` says the deployment zip is generated after changes are confirmed and operator approves an artifact. Stream A saved report says no deployment. | Requires accepted product criteria, reconciled source, build/checksum evidence, and operator release approval; deployment is a separate gate. |

## Missing inputs and explicit gates

- **Source/spec:** the canonical Core Distro product V3 acceptance document and revision are absent. The listed `projects/core-distro.com/` directory is not present. `FIRSTMATE_COORDINATOR_KICKOFF.md` exists at the workspace root but covers coordination, not product acceptance. Without the product source there is no honest per-product-criterion matrix.
- **Warehouse source:** `docs/warehouse/anythingllm/STACK-MAP.md` exists and records the Core chatbot tenant as `UNKNOWN`; it provides infrastructure context, not product acceptance criteria or isolation evidence.
- **Existing worktree ownership:** `fm/core-mobile-fix` and `stream-a-language-nav` contain dirty/uncommitted changes. Preserve these and avoid their owned files until their owners hand off/reconcile. `checkpoint-baseline` tag and the lane commit are present locally.
- **Runtime/build:** no tests, browser captures, or builds were run per instruction. Runtime checks need a sanitized config and disposable database/API credentials; release builds need explicit operator approval as documented in `SOURCE_OF_TRUTH.md`.
- **Deployment:** no deployment occurred. Production approval, deployment, and rollback evidence are separate operator gates.

## Recommended distinct ticket slices

1. **Resolve the product acceptance source (source-custodian ticket).** Deliverable: canonical product V3 PRD path/revision plus acceptance evidence index. No code file ownership. This is the dependency for all remaining product-scoped tickets.
2. **Reconcile current Stream A/mobile handoffs (existing owners only).** No new worker or overlapping file assignment from this scout. Stream A owns its changed toast/theme/bootstrap/script/test/artifact paths; mobile fix owns `staged-export-test/index.php`, `tests/run.sh`, and its evidence/scripts. Record reviewed handoffs, then release paths.
3. **Runtime acceptance (new isolated worktree, after #1 and config gate).** Scope only criteria confirmed by the product matrix and the six relevant infra checks. Candidate files for evidence/report only; do not change app source unless a specific failing criterion is demonstrated. Depends on operator-provided sanitized config, disposable DB/API test access, and existing worktree reconciliation.
4. **Criterion-specific product fixes (one ticket per confirmed gap, after #1-3 as applicable).** Assign exact source files only after comparing confirmed criteria with clean worktree ownership. No implementation slice is sufficiently specified now.
5. **Build/release/deploy (separate approval-gated work).** Depends on accepted product criteria, source reconciliation, runtime evidence, and operator artifact approval. Deployment and rollback remain distinct operator authorization gates.

## Method, commands, and limits

Read/search used `lean-ctx` and direct read-only Git operations. Commands/evidence included:

- `lean-ctx -c "rg --files ..."` and targeted local path checks: found the canonical infrastructure PRD through `projects/firstmate`, confirmed `FIRSTMATE_COORDINATOR_KICKOFF.md` and warehouse `STACK-MAP.md` exist but do not provide product criteria, and confirmed `projects/core-distro.com/` is absent.
- `lean-ctx read README.md`, `lean-ctx read SOURCE_OF_TRUTH.md`, and reads of `data/stream-a-language-nav/report.md` and `data/core-footer-readonly-review/report.md`.
- `git show checkpoint-baseline --stat --oneline`; `git show --stat --oneline 2eb4e12d33106a71f3e7439c053df9080c4adca6`; `git worktree list --porcelain`; and read-only `git status --short --branch` on this and the two relevant worktrees.
- PRD sections read: §20.1 Core Distro infrastructure acceptance and §21 global infrastructure acceptance. The PRD title/purpose at lines 1 and 43 explicitly scopes it to Brandon's infrastructure.

One attempted combined `lean-ctx` command was stopped by its allowlist because it included `nl`; it was not retried. No project changes resulted. Pi `todo` was not available as a callable tool in this session; the numbered checklist was kept visible in the pane instead. The steering inbox was empty.

## Completion gate

Read `/home/hd2admin/kun-agent-workspace/.agents/skills/captain-hold-lifecycle/SKILL.md` as required. The script was absent from the client project checkout at `/home/hd2admin/agent-work/firstmate/bin`, so the initial attempt from that directory failed. Firstmate then directed the worker to the authoritative home script. `FM_HOME=/home/hd2admin/kun-agent-workspace /home/hd2admin/kun-agent-workspace/bin/fm-captain-hold.sh complete core-v3-prd-gap-map --none` passed with output `complete: core-v3-prd-gap-map captain-call inventory reviewed` (exit 0). The report was reviewed and no unresolved captain choice was found; the missing product PRD is an external source blocker already recorded above, not a captain decision. Shared completion gate passed.

## Independent review corrections

The independent review at `data/core-v3-prd-gap-map-agy-review-20260926/report.md` accepted the product-criteria gap and infrastructure-status analysis, while identifying the path errors corrected above. The workspace kickoff and warehouse map exist; the requested `projects/core-distro.com/` directory does not. The local lane evidence references now point to `projects/core-distro-saas-clean/` at commit `2eb4e12d`, not the scout worktree based on `checkpoint-baseline`. At the time of that review, no unresolved decision requiring a human choice was present; the later controller response below introduced a separate acceptance-authority choice.

## Controller follow-up, 2026-09-26

A routed controller reply, `brandon-inbox/2026-09-26-three-asks-answered.md` with SHA-256 `71227d4c391df715f2fcb3a0b683a22e5c86195c7005f8edf2f501e094fe4b8e`, reports that no standalone product acceptance specification exists and that the gap-map finding is terminal. It supplies controller-side coordinates: `/root/lead-gen-saas-v3-first-install-ready-20260710/` locked at commit `c0dde36`, with post-lock changes documented in `agent-work/FIRST_INSTALL_RELEASE_INTEGRITY_DECISION_20260720.md`; `/root/agent-work/projects/core-distro.com/current-core-distro/`; and `deightonllm-firstmate/projects/core-distro.com/SOURCE_OF_TRUTH.md`. These controller-local paths were not accessed or verified in this local review.

The reply leaves a separate owner decision: either explicitly ratify the infrastructure PRD and an identified acceptance matrix as product V3 criteria, with the matrix path and revision supplied, or commission a standalone product acceptance specification. The decision is recorded as `core-v3-acceptance-spec-choice`; the recommendation is the standalone specification because the independent review confirmed that PRD §20.1 covers infrastructure readiness, not product acceptance. Until that choice is resolved, no product-level completion score or criteria-specific implementation is supported.

## Conclusion

Product V3 status remains **unknown**, and a product-level 100% completion claim is unsupported. The six Core Distro infrastructure PRD checks are separately mapped above; none has sufficient current runtime/production evidence to call fully accepted. The next safe step is to obtain the exact product PRD and evidence locations, then reconcile the already-dirty Stream A/mobile worktrees before assigning criterion-specific implementation work.
