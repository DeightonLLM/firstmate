# Core Distro V3 Acceptance Gap Map — Independent Review Report

- **Date:** 2026-09-26  
- **Reviewer:** Crewmate (`core-v3-prd-gap-map-agy-review-20260926`) via AGY harness  
- **Target Report:** `/home/hd2admin/kun-agent-workspace/data/core-v3-prd-gap-map/report.md`  
- **Review Mode:** Strict read-only scout (no project files, tests, git refs, builds, remotes, Docker/port 3001, or AnythingLLM touched or executed)

---

## 1. Executive Summary & Verdict

### Verdict: **ACCEPT WITH NOTED PATH CORRECTIONS**

The target report's **primary architectural and status findings are solidly verified**:
1. **Core Distro Product V3 acceptance source remains missing:** There is no product-level V3 PRD or acceptance matrix in the Core Distro checkout, the local system context, or warehouse references. A product-level 100% completion claim is entirely unsupported, and product V3 completion cannot be scored criterion by criterion without fabricating requirements.
2. **Proper separation of infrastructure vs product criteria:** The six checks in `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` §20.1 belong strictly to multi-project infrastructure readiness (HTTPS, durable quote submission, document auth, queue/credentials isolation, cross-project data isolation, backup restore) and must not be conflated with Core Distro product acceptance criteria.
3. **Existing worktree protection:** The dirty working trees for Stream A (`agent-work/core-distro-saas-clean-stream-a-nav`) and mobile fix (`.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean`) contain active, uncommitted, and unmerged deliverables that must be preserved and reconciled prior to any overlapping file assignment.

### Material Discrepancies & Path Errors Identified
The independent verification identified three factual/path discrepancies in the reviewed report:
1. **`FIRSTMATE_COORDINATOR_KICKOFF.md` exists locally:** The report claimed this file was "not found at the named local locations" (lines 11, 19, 48, 66). In fact, `/home/hd2admin/kun-agent-workspace/FIRSTMATE_COORDINATOR_KICKOFF.md` exists (3,033 bytes, modified Sep 23 03:10). The file defines coordinator orchestration, token economy, model routing, rollback checkpoints, and disjoint workstream priorities (Stream A priority). It contains no product V3 PRD; thus, while claiming the file was absent is a factual error, the finding that product V3 criteria are missing remains valid.
2. **`docs/warehouse/anythingllm/STACK-MAP.md` exists locally:** The report claimed this path was "not found" / "absent" (lines 11, 19, 49, 66). In fact, `/home/hd2admin/kun-agent-workspace/docs/warehouse/anythingllm/STACK-MAP.md` exists (1,539 bytes, modified Sep 25 08:05). Inspecting this file reveals that Core Distro's AnythingLLM status is explicitly listed as `UNKNOWN` (*"Canonical AnythingLLM workspace, index, source repo, and prompt not established"*). Its presence actually provides direct evidence confirming the report's conclusion that Core Distro's chatbot/RAG status is undetermined.
3. **Worktree absolute path inaccuracy:** Lines 29, 30, and 43 cite `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/3/core-distro-saas-clean/tests/local_lane_test.php` and `.../LOCAL_DEVELOPMENT.md`. Worktree 3 is currently checked out at detached HEAD `ba233e1b` (`checkpoint-baseline`), where neither file exists. Both files were added in commit `2eb4e12d` (`main`) and exist in `/home/hd2admin/agent-work/core-distro-saas-clean/` and worktree 4. The substantive evaluation of what `local_lane_test.php` and `LOCAL_DEVELOPMENT.md` contain remains 100% accurate, but the path reference should specify commit `2eb4e12d` or the `main` worktree.

---

## 2. Itemized Verification of Material Claims

### 2.1 Product Acceptance Gap & Infrastructure PRD Scope
- **Target Report Claim:** Product V3 acceptance source is missing. The local anchor `projects/firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` is Brandon's multi-project infrastructure PRD, not a Core Distro product specification. Core Distro infrastructure acceptance checks are in §20.1 (`1870-1880`).
- **Independent Evidence:**
  - File exists via symlink: `/home/hd2admin/kun-agent-workspace/projects/firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (58,440 bytes).
  - Lines 1–43 establish its title (*"Brandon Multi-Project Infrastructure PRD v3.0"*) and purpose (*"This PRD defines the complete target architecture, project isolation model, agent responsibilities, rollout order, security controls, deployment gates, monitoring requirements, backup design, disaster-recovery model, and acceptance criteria for Brandon's infrastructure"*).
  - Lines 1872–1880 (§20.1 Core Distro) list exactly the six infrastructure checks cited:
    1. Public site loads over HTTPS.
    2. Quote/contact submission is durable.
    3. Uploaded or downloadable documents respect authorization.
    4. Any lead-enrichment job uses the Core queue and Core credentials only.
    5. Core data does not appear in another project's database, logs, files, or backup.
    6. Core backup restores successfully.
  - Furthermore, `projects/firstmate/docs/system-context/PRD_TRACEABILITY.md:69` explicitly documents: *"Deployment/hydration/auth gates still open; PRD-v3 application architecture decision pending"*.
  - An earlier lookup request at `data/core-v3-prd-gap-map/controller-request.md` previously asked the controller for canonical product V3 criteria because local checkouts lacked them.
- **Verdict:** **VERIFIED & FULLY SUPPORTED.**

### 2.2 Local Paths Existence Check
| Path Claimed in Target Report | Reported Status | Actual Verification | Details & Impact |
|---|---|---|---|
| `projects/core-distro.com/` | Absent / Not found | **CONFIRMED ABSENT** | Under `/home/hd2admin/kun-agent-workspace/projects/`, only symlinks `core-distro-saas-clean` and `firstmate` exist. |
| `docs/warehouse/anythingllm/STACK-MAP.md` | Absent / Not found | **EXISTS (Refuted claim)** | Exists at `/home/hd2admin/kun-agent-workspace/docs/warehouse/anythingllm/STACK-MAP.md` (1,539 bytes, Sep 25 08:05). Row 5 explicitly lists Core Distro as `UNKNOWN` (*"Canonical AnythingLLM workspace, index, source repo, and prompt not established"*). Finding this file reinforces that no chatbot acceptance criteria exist. |
| `FIRSTMATE_COORDINATOR_KICKOFF.md` | Absent / Not found | **EXISTS (Refuted claim)** | Exists at `/home/hd2admin/kun-agent-workspace/FIRSTMATE_COORDINATOR_KICKOFF.md` (3,033 bytes, Sep 23 03:10). Covers coordinator scaling, model routing, rollback checkpoints, and Stream A priorities. Contains no product criteria. |

### 2.3 Source Hierarchy & Artifact Rules
- **Target Report Claim:** `staged-export-test/` is canonical editable source; `current-core-distro/` is legacy reference (`README.md:7-12`; `SOURCE_OF_TRUTH.md:35-60`). Generated deployment zip rules governed by `SOURCE_OF_TRUTH.md:40-53`.
- **Independent Evidence:**
  - `README.md` lines 7–8:
    - `- staged-export-test/ — canonical editable source. All agent edits go here.`
    - `- current-core-distro/ — legacy/reference only. A lean snapshot retained for provenance comparison. Do not edit unless the operator explicitly scopes work here.`
  - `SOURCE_OF_TRUTH.md` lines 35–60: Canonical Editable Source is `staged-export-test/`; Generated Deployment Artifact is `lead-engine-saas-export-20260625_canonical-geo.zip` (rebuilt from `staged-export-test/` when operator approves); `current-core-distro/` is Legacy / Reference Only.
- **Verdict:** **VERIFIED & EXACT MATCH.**

### 2.4 Brandon Infrastructure PRD §20.1 Check Statuses
| §20.1 Criterion | Reported Status | Review Assessment & Evidence |
|---|---|---|
| Public site loads over HTTPS | `blocked` | **SUPPORTED.** Requires deployment and production URL access; no runtime HTTPS evidence exists locally. |
| Quote/contact submission is durable | `unknown` | **SUPPORTED.** No saved report demonstrates end-to-end durable DB write; product V3 source absent. |
| Uploaded/downloadable documents respect authorization | `unknown` | **SUPPORTED.** Inspection of `tests/local_lane_test.php` (commit `2eb4e12d`) confirms it only checks static strings for password hashing, login redirects, protected lead-list redirects, and `selfCheck` HTTP 401. It does not test or verify document-level access control. |
| Lead-enrichment job uses Core queue/credentials only | `unknown` | **SUPPORTED.** `tests/local_lane_test.php` checks job state markers (`status = 'queued'`, `status = 'running'`, terminal states, `claimScrapeCityJobs`, `completeScrapeCityJob`), but provides no evidence of queue or credential isolation. |
| Core data does not appear in another project's database/logs/files/backup | `blocked` | **SUPPORTED.** Multi-project isolation verification requires cross-system environment and test harness not present locally. |
| Core backup restores successfully | `blocked` | **SUPPORTED.** No backup dump or restore verification report exists in the local checkout or evidence. |

### 2.5 Existing Local Evidence & Worktree Integrity
- **`checkpoint-baseline` tag:**
  - Verified via `git show checkpoint-baseline --stat --oneline`:
    Points to commit `ba233e1b558d2282b446e4d72f6e29520964c642` (*"feat(index): add cross-platform language nav — EN/PL/ES inline SVG flags, compact desktop dropdown, mobile drawer"*), modifying `staged-export-test/includes/theme_bootstrap.php` and `staged-export-test/index.php` (+642 lines). Exactly matches report line 39.
- **Local lane A commit `2eb4e12d`:**
  - Verified via `git show --stat --oneline 2eb4e12d33106a71f3e7439c053df9080c4adca6`:
    Adds `LOCAL_DEVELOPMENT.md`, `RELEASE_METADATA.md`, `bin/core-distro-local-check.sh`, and `tests/local_lane_test.php` (179 insertions). Exactly matches report line 40.
- **Stream A saved report and worktree:**
  - Verified via `/home/hd2admin/kun-agent-workspace/data/stream-a-language-nav/report.md:11-17`:
    55-entry artifact, tests passing (29/29, 15/15, 21/21), uncommitted local work.
  - Git status in `/home/hd2admin/agent-work/core-distro-saas-clean-stream-a-nav` shows modified `saas-toast.js`, `theme_bootstrap.php`, and untracked `scripts/`, `node_modules/`, `tests/`. Exactly matches report line 41.
- **Mobile footer review report and worktree:**
  - Verified via `/home/hd2admin/kun-agent-workspace/data/core-footer-readonly-review/report.md:50-80,84-95`:
    Saved light 6.55:1 and dark 4.69:1 ratios; PASS under Pixel 7 and 1280×800 emulation only.
  - Git status in `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean` (`fm/core-mobile-fix`) shows modified `staged-export-test/index.php`, `tests/run.sh`, and 32 untracked evidence screenshots and test probe files. Exactly matches report line 42.

---

## 3. Review Recommendations

1. **Uphold the primary recommendation:** Do not commission feature implementation tickets claiming to complete "Core Distro V3" until the source custodian provides an authoritative product V3 specification and criterion inventory.
2. **Accept the report with factual corrections:** When citing background context, acknowledge that `FIRSTMATE_COORDINATOR_KICKOFF.md` and `docs/warehouse/anythingllm/STACK-MAP.md` exist at the workspace root, and that `STACK-MAP.md` explicitly corroborates the `UNKNOWN` status of Core Distro chatbot integration.
3. **Preserve worktrees:** Retain protection on `stream-a-language-nav` and `fm/core-mobile-fix` worktrees until their uncommitted changes are formally reconciled or landed.

---

## 4. Audit Evidence: Commands Run & Verification Outputs

All verification was conducted using local read-only commands:

1. **Locating Brandon PRD v3:**
   ```bash
   ls -la /home/hd2admin/kun-agent-workspace/projects/firstmate/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md
   # Output: -rw-r--r-- 1 hd2admin hd2admin 58440 Sep 23 01:57
   ```
2. **Checking STACK-MAP.md and FIRSTMATE_COORDINATOR_KICKOFF.md:**
   ```bash
   ls -la /home/hd2admin/kun-agent-workspace/FIRSTMATE_COORDINATOR_KICKOFF.md \
          /home/hd2admin/kun-agent-workspace/docs/warehouse/anythingllm/STACK-MAP.md
   # Output:
   # -rw-r--r-- 1 hd2admin hd2admin 3033 Sep 23 03:10 /home/hd2admin/kun-agent-workspace/FIRSTMATE_COORDINATOR_KICKOFF.md
   # -rw-r--r-- 1 hd2admin hd2admin 1539 Sep 25 08:05 /home/hd2admin/kun-agent-workspace/docs/warehouse/anythingllm/STACK-MAP.md
   ```
3. **Verifying Git Tags and Commits:**
   ```bash
   git show checkpoint-baseline --stat --oneline
   # Output: tag checkpoint-baseline -> ba233e1 feat(index): add cross-platform language nav ... (+642 lines)
   git show --stat --oneline 2eb4e12d33106a71f3e7439c053df9080c4adca6
   # Output: 2eb4e12 test(core-distro): add local lane acceptance evidence (+179 lines)
   ```
4. **Inspecting Active Worktrees:**
   ```bash
   git -C /home/hd2admin/agent-work/core-distro-saas-clean-stream-a-nav status --short
   # Output: M staged-export-test/assets/saas-toast.js, M staged-export-test/includes/theme_bootstrap.php, ?? scripts/, ?? staged-export-test/node_modules/, ?? staged-export-test/tests/
   git -C /home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean status --short
   # Output: M staged-export-test/index.php, M tests/run.sh, ?? tests/evidence/...
   ```

---

## 5. Captain Hold Lifecycle & Completion Gate

In accordance with `/home/hd2admin/kun-agent-workspace/.agents/skills/captain-hold-lifecycle/SKILL.md`:
- The review surface has been completely read and inventoried.
- No unresolved captain decisions exist in this review: the missing product V3 specification is an external source dependency already documented and escalated to the controller/source custodian, not an internal task choice waiting on the captain.
- Completion gate executed:
  ```bash
  FM_HOME=/home/hd2admin/kun-agent-workspace /home/hd2admin/kun-agent-workspace/bin/fm-captain-hold.sh complete core-v3-prd-gap-map-agy-review-20260926 --none
  ```
  Execution output: `complete: core-v3-prd-gap-map-agy-review-20260926 captain-call inventory reviewed` (exit code 0).
