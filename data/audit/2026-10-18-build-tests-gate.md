# Build lane: make tests gate something

Date: 2026-10-18

## Changes

- Added `.github/workflows/ci.yml` job `required-ci-gate`, which runs after all nine existing CI jobs and requires each result to be `success`. A failed, cancelled, or skipped required job makes this gate exit non-zero.
- Added `bin/fm-ci-required-gate.sh` and `tests/fm-ci-required-gate.test.sh`. The test exercises the all-success path and deliberately supplies `tests=failure` and `tests=skipped`, asserting that both fail the gate.
- Corrected `bin/fm-test-run.sh`'s partition: `fm-spawn-bash-regression.test.sh` was listed as proven-isolated by the runner but absent from `bin/fm-test-isolation-proof.sh --list`. It now runs in the serial remainder instead of falsely being called proven-isolated. The coverage guard had failed before this correction and passes after it.
- Classified the new CI-gate regression test as `pure-contract-unit` so the existing runner includes it in the normal CI lane composition.

## Backups

- `.github/workflows/ci.yml` prior bytes: `.github/workflows/ci.yml.bak-20261018T013824Z`; verified with `cmp -s` before editing.
- New script's empty pre-mutation state: `bin/fm-ci-required-gate.sh.bak-20261018T013824Z`.
- New test's empty pre-mutation state: `tests/fm-ci-required-gate.test.sh.bak-20261018T013824Z`.
- `bin/fm-test-run.sh` before each edit: `bin/fm-test-run.sh.bak-20261018T014212Z`, `bin/fm-test-run.sh.bak-20261018T014220Z`, and `bin/fm-test-run.sh.bak-20261018T014303Z`.
- New audit artifact's empty pre-mutation state: `data/audit/2026-10-18-build-tests-gate.md.bak-20261018T014412Z`.
- Audit correction backup: `data/audit/2026-10-18-build-tests-gate.md.bak-20261018T014432Z`.

## Verification commands and output

- `bin/fm-test-run.sh --check-coverage` -> `FM_TEST_COVERAGE ok total=150 parallel=24 serial=115 herdr=11`.
- `bin/fm-test-run.sh tests/fm-ci-required-gate.test.sh` -> exit 0; four assertions passed, including deliberate failed and skipped job results.
- `set +e; output=$(bin/fm-ci-required-gate.sh lint=success portable-serial=failure 2>&1); rc=$?; printf '%s\nexit=%s\n' "$output" "$rc"; test "$rc" -ne 0` -> `::error::CI job 'portable-serial' did not pass (result: failure)`, `exit=1`.
- `bin/fm-test-run.sh tests/fm-test-run.test.sh` -> exit 0; all 15 runner contract tests passed, including shard partition and coverage assertions.
- `shellcheck bin/fm-ci-required-gate.sh bin/fm-test-run.sh` -> exit 0, no diagnostics.
- `bash -n tests/fm-ci-required-gate.test.sh` -> exit 0.
- `python3` with PyYAML parsed `.github/workflows/ci.yml`; confirmed `required-ci-gate` depends on all nine existing jobs.
- `(cd /home/hd2admin/agent-work/core-distro-saas-clean && php tests/local_lane_test.php)` -> `PASS local lane contracts: auth, lead-list/job states, CSV round-trip, health route, accessibility, PHP-only ownership`.
- `git diff --check` -> exit 0.
- `bin/fm-lint.sh` -> timed out after 120 seconds; no complete lint result. The changed shell files passed direct ShellCheck.
- The complete 150-test suite was not run locally. The focused test and runner test were run; the CI workflow continues to execute its existing full test lanes.

## Client-domain acceptance suite inventory

| Domain | Suite claimed / location | Present on this host? | Exact gap to wiring |
|---|---|---|---|
| Core Distro | `tests/local_lane_test.php` in `/home/hd2admin/agent-work/core-distro-saas-clean`; `LOCAL_DEVELOPMENT.md` documents this dependency-free local test. | Yes. It passed above. This is local-lane contract evidence, not proof of the proposed product-wide V3 acceptance spec or production readiness. The checkout has no `.github/workflows` pipeline. | Run from the Core repository itself and add/maintain its own CI workflow there; the Firstmate repository checkout does not contain that external source. The Core repo is `https://github.com/DeightonLLM/core-distro-saas-clean`.
| Elevate Life Sci | PRD describes acceptance/smoke checks, but no executable acceptance suite or Elevate source checkout was found in the available `projects/` or `agent-work/` repositories. | No suite/source checkout found. | Provide the canonical Elevate source repository/checkout, an authoritative acceptance runner and criteria, and its approved CI/deploy repository. No production or external endpoint was contacted.
| Whoosh Performance | No executable suite or source repository found; existing domain records state project coordinates are missing. | No suite/source checkout found. | Provide the source repository and owner-approved application acceptance criteria/runner; current coordinates are insufficient to run or wire a check.
| CBD-Data | `cbd-campaign/L2/tests/run_tests.php` with local stub-server and helper fixtures is present under the Firstmate workspace, but that path is ignored/untracked and is not a canonical CBD project checkout. Historical `L2/REPORT.md` records test results; this run was not repeated. | The campaign suite exists locally, but no canonical CBD-Data repository checkout/test workflow was found. | Provide/checkout the canonical CBD-Data repository and confirm whether the campaign suite is the approved acceptance suite; then place the runner in the owning repo and wire it there. The existing ignored/untracked suite was not force-added or run.

## What blocks and what does not

The CI workflow now exposes one `Required CI gate` status that fails whenever any existing CI job is not successful. Its deliberately injected failed-job case returned exit 1, and the runner coverage defect that made the coverage job red was repaired without skipping or weakening tests.

This in-repository status does not itself prevent a GitHub merge while repository branch protection does not require it. Per the supervisor instruction, branch protection was not changed or scripted. The operator must configure `Required CI gate` as a required status check for merge blocking.

No client-domain acceptance suite is currently run by this repository's CI or by a client-facing deploy pipeline. Firstmate does not contain those external project sources, and no client deploy workflow was found in the checked-out sources. Client gates remain unwired until each owner supplies the source repository and authoritative executable acceptance checks described above.
