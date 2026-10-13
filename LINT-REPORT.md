# ShellCheck report

Date: 2026-10-13

## Scope and method

- ShellCheck version: 0.11.0 (the version pinned by `bin/fm-lint.sh`).
- Merge payload: 99 `bin/*.sh` paths changed by merge `4abb674`.
- Additional paths: the two changed scripts `bin/fm-spawn.sh` and
  `bin/fm-wake-lib.sh`, plus `tests/fm-spawn-enforcement.test.sh`.
- All 102 unique paths were checked through `bin/fm-lint.sh`; the 99 merge
  paths were split into four batches to stay within the lean-ctx command
  timeout. The two changed scripts and focused test were checked together.

## Results

- 102 files checked.
- 99 of 99 merge scripts checked; 96 had no findings and 3 had one finding
  each.
- Both changed scripts and the focused enforcement test passed with no
  findings after documenting the sourced-library diagnostic output in
  `fm-wake-lib.sh`.
- 3 total findings, all ShellCheck `SC2153`, in upstream merge files:

| File | Line | Finding |
| --- | ---: | --- |
| `bin/fm-on.sh` | 85 | `SECONDMATE_REGISTRY_ID` / `SECONDMATE_REGISTRY_HOST`: possible misspelling (`SC2153`). |
| `bin/fm-remote-home-seed.sh` | 119 | `SECONDMATE_REGISTRY_HOST`: possible misspelling (`SC2153`). |
| `bin/fm-stow-cascade.sh` | 189 | `SECONDMATE_REGISTRY_HOST`: possible misspelling (`SC2153`). |

The three findings are recorded without rewriting the upstream files, preserving
the requested upstream byte fidelity.

## Enforcement verification

`bin/fm-test-run.sh tests/fm-spawn-enforcement.test.sh` passed: the dry branch
spawn refused with a logged reason, and the occupied project capacity deferred
the dry spawn before worker launch. The test summary was `total=1 failed=0`.

The broader legacy spawn suites were also attempted during phase 1. The
remaining failures are test/environment mismatches before the new enforcement
seam: three legacy Codex spawn fixtures omit `--model`, so the existing
dispatch guard exits 64; a Claude dispatch-profile fixture reaches the quota
gate and exits 4 because quota-axi/provider quota data is unavailable. The
named `fm-supervision-host.test.sh` and `fm-branch-supervision.test.sh` files
are absent from this branch. `fm-spawn-no-click-startup.test.sh` passed.
