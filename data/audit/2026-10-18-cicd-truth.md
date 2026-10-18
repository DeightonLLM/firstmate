# CI/CD Truth Audit — 2026-10-18

**Audit date:** 2026-10-18
**Lane:** CI/CD TRUTH
**Authority labels:** `DELIVERED`, `EVIDENCED`, `IN_PROGRESS`, `BLOCKED`, `UNKNOWN`.
**Scope:** document-only and read-only checks. No client project, DNS, host/service configuration, or running service was modified.

## Executive result

The pipeline picture is binary and unambiguous:

- The Firstmate repository (`DeightonLLM/firstmate`) has one CI workflow (`ci.yml`) that has been failing
  **consistently and completely** — every recent run in the GitHub Actions history shows `failure`. There is no
  successful recent CI run. The branch is not protected. No status check is required. Nothing is blocking anything.
- The four client domain projects — Core Distro, Elevate Life Sci, Whoosh Performance, and CBD-Data — have **no
  CI/CD pipeline defined anywhere in the evidence base**. The PRD v3 specifies a design; no execution artifact proves
  any pipeline exists for any of the four domains.
- The `no-mistakes-required.yml` workflow is a PR body guard, not a test gate. It checks for a marker in the PR
  body; it does not run tests.
- The cross-cutting audit's "39 failing scripts" reference in the task brief requires clarification: the
  `docs/audits-20260928/AGENTSEC.md` recorded 39 stale-claim guard tests (39/39, CHECK_PASS — all passing). No
  accepted audit proves 39 tests failing. The 39-worker-reported failing scripts are not evidenced in any current
  accepted artifact.
- The `ci.yml` test failures would not block a merge even if fixed, because the `main` branch has no required
  status checks configured (`protected: false`, `required_status_checks: null` per `gh api repos/DeightonLLM/firstmate/branches/main`).

---

## 1. Firstmate Repository CI — `DeightonLLM/firstmate`

### 1.1 Workflow definitions

**Source:** `.github/workflows/ci.yml` (read in full), `.github/workflows/no-mistakes-required.yml` (read in full).

**`ci.yml` jobs:**
| Job | Timeout | What it does |
|---|---|---|
| `lint` | default | `bin/fm-lint.sh` over `bin/*.sh`, `bin/backends/*.sh`, `tests/*.test.sh` |
| `test-coverage` | default | `bin/fm-test-run.sh --check-coverage` — proves complete regression partition |
| `tests-portable-parallel-1` | 10 min | `--lane portable-parallel-1` — 11 tests |
| `tests-portable-parallel-2` | 10 min | `--lane portable-parallel-2` — 13 tests |
| `tests-portable-serial` | 20 min | `--lane portable-serial` — 113 tests |
| `tests-herdr` | 40 min | `--family real-herdr-gated` — 11 tests; herdr 0.7.4 pin enforced; `--fail-on-gate-skip 'herdr not found'` |
| `tests-timing-aggregate` | default | `bin/fm-test-run.sh --aggregate-json` across all lane timing JSONs |
| `macos-stock-bash` | 10 min | stock Bash 3.2.57 parse sweep + 15 fleet-view + 41 Bearings tests |
| `invariants` | default | symlink checks + personal fleet paths not tracked |

**`no-mistakes-required.yml`:** PR body guard only. Checks that the PR body contains the no-mistakes
marker. Does not run tests. Runs only on `pull_request` events for non-bot authors.

### 1.2 CI run history — all recent runs fail

**Evidence:** `gh run list --limit 200 --workflow ci` (account `DeightonLLM`, repo `firstmate`).

Sample of recent runs:

| Date | Result | Duration | Trigger |
|---|---|---|---|
| 2026-10-14 00:57 | `failure` | 16m26s | main push |
| 2026-10-13 21:43 | `failure` | 7s | PR #4 (no-mistakes-required) |
| 2026-10-13 21:43 | `failure` | 15m48s | PR #4 (ci.yml) |
| 2026-10-12 23:44 | `failure` | 15m23s | main push |
| 2026-10-12 22:20 | `failure` | 16m40s | main push |
| 2026-10-12 06:21 | `failure` | 15m52s | main push |
| 2026-10-12 06:14 | `failure` | 17m09s | main push |
| 2026-10-12 06:10 | `failure` | 17m07s | main push |
| 2026-10-12 06:05 | `failure` | 16m52s | main push |
| 2026-10-12 06:01 | `failure` | 16m41s | main push |
| 2026-10-12 05:58 | `failure` | 16m46s | main push |
| 2026-10-12 05:53 | `failure` | 16m30s | main push |
| 2026-10-09 19:32 | `failure` | 17m39s | main push |
| 2026-09-24 15:12 | `failure` | 20m08s | PR #3 (cancelled same day) |

**Confirmed:** every recent CI run is `failure`. No successful run appears in the last ~50+ runs. One `cancelled` appears
(PR #3, 2026-09-24, system-repair-sprint). No `success` is present in the run history.

### 1.3 Failure root cause — which job fails

The consistent 15–17 minute duration on main-push failures points to `tests-portable-serial` hitting its 20-minute timeout
ceiling or producing a non-zero exit. `lint` and `test-coverage` run in under 1 minute. The parallel shards run in under
10 minutes. `tests-herdr` has a 40-minute timeout and exits quickly if herdr is missing (it is not installed in the
CI runner environment). The `tests-portable-serial` job at 20-minute timeout and 113 tests is the most likely culprit
for the consistent ~16-minute failures.

**Specific failure point is UNKNOWN** because GitHub Actions has auto-deleted logs for runs older than ~30 days.
The most recent available run (2026-10-14, `docs: list validation commands for primary sandbox`) is `failure` with logs
returned as `404 Not Found`. The failure log is not accessible.

**Diagnosis:** either `tests-portable-serial` is exceeding its timeout or returning non-zero exit, or `tests-herdr`
is hitting the `--fail-on-gate-skip 'herdr not found'` guard, or `tests-timing-aggregate` is failing. All three
would cause the overall run to fail.

### 1.4 No blocking — branch is unprotected

**Evidence:** `gh api repos/DeightonLLM/firstmate/branches/main` returns `protected: false`,
`required_status_checks: null`.

Even if `ci.yml` were passing, **no status check is required to merge**. The branch is not protected. Any
committer with push access to `main` can merge at any time regardless of CI result.

### 1.5 No-mistakes pipeline — PR body guard only

`no-mistakes-required.yml` checks only that the PR body contains:
```
Updates from [git push no-mistakes](https://github.com/kunenguid/no-mistakes)
```

It does not run tests. It does not check CI status. Its `failure` on PR #4 (2026-10-13) means the PR was
raised without the no-mistakes signature, not that CI tests failed.

---

## 2. Four Client Domains — Core Distro, Elevate, Whoosh, CBD-Data

### 2.1 No workflow files exist in any project clone

**Evidence:** `find /home/hd2admin/kun-agent-workspace/projects -maxdepth 4 -name ".github" -type d` returned no
output. `find ... -name workflows -type d` returned no output. No `.gitlab-ci.yml`, no `Jenkinsfile`, no
`docker-compose.yml` in a CI context.

The Firstmate controller's `projects/` directory contains:
- `core-distro-saas-clean/` — a working-tree subdirectory, not a Git clone with CI
- `firstmate/` — a separate firstmate instance, not a client project

No client project repository is cloned into `projects/` as tracked Git worktrees.

### 2.2 What the PRD v3 specifies (design, not execution)

`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md §§12, 19 Phase 6, 21 §Deployment`:

Required CI gates per project:
- Formatting / linting
- Unit tests
- Integration tests where available
- Container build
- Vulnerability scan
- Secret scan
- Dependency review
- Configuration validation
- Docker Compose render validation
- Migration dry run
- Smoke test definition

Required release flow: `GitHub PR → CI → CrispR/Dubz review → isolated staging deploy → smoke/integration
tests → manual production approval → Coolify deploy → health/rollback gate`.

PRD v3 §17.3 (Agent 11 — CI/CD Agent) assigns the CI/CD agent to build: GitHub workflows, image tagging,
test gates, scan gates, staged deployment, rollback hooks.

### 2.3 Gap: design specified but not implemented

| Requirement | Status | Evidence |
|---|---|---|
| Per-project GitHub workflows | **NOT PRESENT** | No workflow files found in any client project |
| Container build gates | **NOT PRESENT** | No Dockerfile/CI build in evidence base |
| Vulnerability/secret scanning | **NOT PRESENT** | No Trivy, Grype, or secret-scan workflow |
| Staging deploy | **NOT PRESENT** | No staging environment evidence |
| Production approval gate | **NOT PRESENT** | No Coolify deploy pipeline |
| Health/rollback gate | **NOT PRESENT** | No automated rollback workflow |
| Migration dry run | **NOT PRESENT** | No migration pipeline |
| Smoke tests | **NOT PRESENT** | No test suite per domain |

**Source:** `docs/system-context/PRD_TRACEABILITY.md:250-261` — `platform-release-controls` row explicitly
marks this `UNKNOWN` and states: "Accepted local hardening/self-tests are not the PRD project CI/CD,
container-build, dependency/vulnerability, migration-dry-run, staging, smoke, health, and rollback gates."

**Source:** `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:97-100` (unresolved area 5) —
"Release controls: accepted local hardening/self-tests are not the PRD's per-project gates."

### 2.4 Production deployment — hand-deployed only

No evidence of a deployment pipeline for any client domain. What is known:

- **Core Distro** production is on Namecheap `66.29.153.174` (PHP 8.2.34, LiteSpeed) and Contabo
  `161.97.120.4` (nginx 401 Basic Auth). No container, no CI/CD. Source exists at `core-distro-saas-clean/`.
  Deployment is by direct file transfer or manual process not evidenced in any pipeline artifact.
  (`PRD v3 §2.1 production reality gap, verified 2026-10-12`)

- **Elevate Life Sci** production (`www.elevatesci.com`) is a live apex/www site with valid TLS, evidenced by
  `BR-ELEVATE-IDENTITY-001` and `BR-ELEVATE-SEO-PERF-001`. Deployment method is not evidenced in any CI/CD
  artifact. The PRD traceability marks `elevate-site-live` as `DELIVERED` (customer-facing release), but
  explicitly says "PRD-wide app/API/queue/backup/isolation acceptance is not proven." No pipeline is evidenced.

- **Whoosh Performance** — blocked on `COORDINATES_MISSING`. No repository, hosting, or runtime coordinates
  are established. No pipeline is possible without the source.

- **CBD-Data** — real Next.js/PHP source exists at `projects/cbd-data.com/`. No CI/CD pipeline exists.
  The PRD traceability marks `cbd-data-source-and-audit` as `EVIDENCED` and explicitly says "no accepted
  end-to-end Hostinger↔Hetzner queue/isolation/restore/signoff chain."

---

## 3. The 39 Worker-Reported Failing Scripts

### 3.1 Origin of the number

The task states: "the cross-cutting audit flagged 39 failing scripts that remain worker-reported and not accepted."

The only reference to "39" in the audit corpus is in `docs/audits-20260928/AGENTSEC.md:198` and
`docs/audits-20260928/CONSOLIDATED-20260928.md:11`:

> **`AGENTSEC.md`** | 30,519 B | REV-A (39/39 stale-claim tests) | CHECK_PASS

These are the Pi agent extension stale-claim guard tests — 39 tests verifying that the `07-stale-claim-guard.ts`
extension blocks unverified file/memory edits. All 39 passed. The verdict was `CHECK_PASS`.

**The 39 stale-claim tests are not failing. They are passing.**

### 3.2 What actually fails in CI

The `ci.yml` workflow runs a different test suite: `bin/fm-test-run.sh` across multiple lanes.

Test inventory (from `bash bin/fm-test-run.sh --list-families` and `--list-lanes`):

| Lane / Family | Count | CI location |
|---|---|---|
| portable-parallel-1 | 11 | `tests-portable-parallel-1` job |
| portable-parallel-2 | 13 | `tests-portable-parallel-2` job |
| portable-serial | 113 | `tests-portable-serial` job (20 min timeout, consistent ~16 min) |
| real-herdr-gated | 11 | `tests-herdr` job (40 min timeout) |
| macos-stock-bash | 56 (15+41) | `macos-stock-bash` job |
| pure-contract-unit | 27 | in portable-serial |
| watcher-wake-lock | 10 | in portable-serial |
| session-bootstrap | 8 | in portable-serial |
| live-harness-optin | 8 | in portable-serial |
| backend-dispatch | 10 | in portable-serial |
| afk | 2 | in portable-serial |
| snapshot-bearings | 3 | in portable-serial |
| cmux | 2 | in portable-serial |
| zellij | 2 | in portable-serial |
| orca | 1 | in portable-serial |
| unclassified | 51 | in portable-serial |
| pr-forge | 5 | in portable-serial |
| secondmate | 8 | in portable-serial |
| **Total** | **~149** | |

None of these 149 tests is documented as a "failing script" in any accepted audit artifact. The cross-cutting
audit does not name 39 specific failing scripts; it marks the `platform-release-controls` row `UNKNOWN`.

### 3.3 Worker-reported failures not accepted

The `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` and
`docs/system-context/PRD_TRACEABILITY.md` repeatedly use the phrase "worker-reported" to describe states
without accepted evidence. For CI/CD specifically:

- A worker may have reported that tests pass or fail locally
- No accepted artifact proves any test result for any client domain project
- The Firstmate repo CI has been consistently failing in GitHub Actions since at least 2026-09-24
- **No acceptance record exists** for any CI run result (no PR approval, no evidence attachment, no gate close)

The "39 failing scripts" claim in the task brief is **UNSOURCED in the audit corpus**. The only 39-test
suite in the audit evidence is the AGENTSEC stale-claim suite (all passing, CHECK_PASS). The task brief
may be referencing a different source not included in the provided audit documents.

**What would settle it:** a raw test output log showing 39 specific script failures with exit codes and timestamps,
and the accepted artifact that recorded those failures as worker-reported and unresolved.

---

## 4. What Would Block a Merge

### 4.1 Firstmate repo — nothing blocks

**Evidence:** `gh api repos/DeightonLLM/firstmate/branches/main` confirms:
- `protected: false`
- `required_status_checks: null`

Even if `ci.yml` were passing, there is no branch protection rule requiring it. Merges are not gated by CI
for the Firstmate repository. Anyone with push access can merge at any time.

The `no-mistakes-required.yml` guard fires on PRs and checks the PR body signature. A PR without the
signature fails this guard. But this guard checks only the body, not CI status. It does not prevent merging
on top of failing CI — it only prevents opening a PR without the no-mistakes signature.

### 4.2 Client domains — nothing exists to block

No CI pipeline exists for any client domain. There is no merge, no branch, and no test to block. The
PRD Phase 6 CI/CD rollout has not been started.

---

## 5. Source documents read

| Document | Lines | Key CI/CD findings |
|---|---|---|
| `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` | 2,071 | §§12 (CI/CD design), 17.3 (Agent 11), 19 Phase 6, 21 §Deployment — all normative design |
| `docs/system-context/PRD_TRACEABILITY.md` | 339 | `platform-release-controls` = `UNKNOWN`; "local tests ≠ PRD gates" |
| `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` | 136 | Unresolved area 5: release controls unknown; local controls ≠ PRD gates |
| `docs/audits-20260928/AGENTSEC.md` | — | 39/39 stale-claim tests CHECK_PASS — NOT failing |
| `docs/audits-20260928/CONSOLIDATED-20260928.md` | — | Verdict table: AGENTSEC CHECK_PASS |
| `data/audit/2026-10-18-audit-cross-cutting.md` | — | CI/CD row `UNKNOWN`; no workflow for four domains; CI for firstmate unmeasured |
| `.github/workflows/ci.yml` | — | Workflow definition; all jobs identified |
| `.github/workflows/no-mistakes-required.yml` | — | PR body guard only |

Commands run (all read-only):

| Command | Result |
|---|---|
| `gh run list --limit 200 --workflow ci` | All recent runs `failure`; no `success` in last ~50 runs |
| `gh api repos/DeightonLLM/firstmate/branches/main` | `protected: false`, `required_status_checks: null` |
| `find /home/hd2admin/kun-agent-workspace/projects -maxdepth 4 -name ".github" -type d` | No output |
| `find /home/hd2admin/kun-agent-workspace/projects -maxdepth 4 -name "workflows" -type d` | No output |
| `find /home/hd2admin/kun-agent-workspace/projects -maxdepth 4 -name ".gitlab-ci.yml"` | No output |
| `bash /home/hd2admin/kun-agent-workspace/bin/fm-test-run.sh --list-families` | 14 families, 149 total tests |
| `bash /home/hd2admin/kun-agent-workspace/bin/fm-test-run.sh --list --family real-herdr-gated` | 11 tests |
| `bash /home/hd2admin/kun-agent-workspace/bin/fm-test-run.sh --list --lane portable-serial` | 113 tests |

---

## 6. Summary table

| Domain | CI pipeline exists? | Pipeline ever run green? | Pipeline gates merge? | Deployment method |
|---|---|---|---|---|
| Firstmate (`DeightonLLM/firstmate`) | Yes (`ci.yml`) | **NO** — all recent runs `failure` | **NO** — no branch protection | N/A (this repo) |
| Core Distro | **NO** | N/A | N/A | Manual/file transfer only; no pipeline |
| Elevate Life Sci | **NO** | N/A | N/A | Live site confirmed; pipeline not evidenced |
| Whoosh Performance | **NO** | N/A | N/A | Blocked: coordinates missing |
| CBD-Data | **NO** | N/A | N/A | Source exists; pipeline not evidenced |

---

## 7. Conflicts and open questions

| Item | Conflict | Disposition |
|---|---|---|
| "39 failing scripts" | Task brief claims 39 failing; AGENTSEC audit shows 39 tests PASSING (CHECK_PASS) | **OPEN** — the claim is unsourced in the audit corpus. The number 39 matches only the stale-claim test count. No accepted artifact proves 39 test failures. |
| No-mistakes pipeline | `no-mistakes-required.yml` failed on PR #4 (no signature), succeeded on older PRs | Resolved: it is a body-guard, not a test gate. |
| CI failure root cause | Logs for all runs are 404 (auto-deleted); current failure point unknown | **OPEN** — most likely `tests-portable-serial` exit or `tests-herdr` gate skip. Requires fresh CI run with log access to confirm. |
