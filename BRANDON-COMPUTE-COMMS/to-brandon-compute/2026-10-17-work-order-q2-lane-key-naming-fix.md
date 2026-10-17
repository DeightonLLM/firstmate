# WORK ORDER — Q2: Fix Lane-Key Naming Defect for M2.7-highspeed

**From:** Controller (HD2 / `vmi3238503`)  
**To:** brandon-compute First Mate (`hd2admin@100.106.6.22`)  
**Date:** 2026-10-17T15:40:00Z  
**Correlation:** `hd2-standing-queue-q2`  
**Priority:** P1 — Q2 on standing queue

---

## 1. Defect Description

In `AGENT-TODO-PROMPT-STYLE.md`, `bin/fm-lane-naming-check.sh`, and `tests/fm-lane-naming-check.test.sh`:
- Model alias list currently defines `m2.7`, but workers are `M2.7-highspeed` (`m2.7h`).
- Worker scripts (e.g. `data/m27-batch2-20261017.js`, `data/m27-isolation-policy-path-fix.js`) and live To-Do items use `m2.7h` (e.g., `m2.7h-brandon-land-factory-work`, `[m2.7h @ brandon]`).
- Testing `bash bin/fm-lane-naming-check.sh "m2.7h-brandon-land-factory-work"` fails with `invalid lane key or board line: m2.7h-brandon-land-factory-work`.
- In `data/async-lanes.tsv`, registry rows claimed `m2.7` when the workers were `M2.7-highspeed`.

---

## 2. Required Fix

Execute on your workspace:

1. **`bin/fm-lane-naming-check.sh`**:
   - Update `_model_pat`:
     ```bash
     _model_pat='m2\.7h|m2\.7|m3\.1f|luna6|glm5\.3f|gem38f|pi'
     ```
   - Update comments to list `m2.7h` (MiniMax M2.7 Highspeed) alongside `m2.7`.

2. **`AGENT-TODO-PROMPT-STYLE.md`**:
   - Update canonical model alias list to include `m2.7h`:
     ```markdown
     Model aliases: `m3.1f`, `m2.7h`, `m2.7`, `luna6`, `glm5.3f`, `gem38f`, `pi`.
     ```
   - Clarify that `m2.7h` denotes `MiniMax M2.7 Highspeed` (matching the `f` suffix in `m3.1f`).

3. **`tests/fm-lane-naming-check.test.sh`**:
   - Add unit tests for `m2.7h`:
     - `test_lane_key_valid_m2_7h()` testing `m2.7h-brandon-build` (must pass).
     - `test_board_line_valid_m2_7h()` testing `[m2.7h @ brandon] action — working` (must pass).
   - Wire both tests into the test runner `main()`.

4. **`data/async-lanes.tsv`**:
   - Update rows for `M2.7-highspeed` runs to use `m2.7h` in `lane_key` and `model` columns.
   - Run `bash bin/fm-lane-naming-check.sh data/async-lanes.tsv` and ensure 0 exit code.

5. **Validation**:
   - Run `bash tests/fm-lane-naming-check.test.sh`.
   - Run all 5 suites (`tests/fm-lane-naming-check.test.sh`, `tests/fm-reap-records-check.test.sh`, `tests/fm-client-infra-isolation-check.test.sh`, `tests/fm-dead-pane-sweep.test.sh`, `tests/fm-teardown-archive.test.sh`).

6. **Commit & Push**:
   - Commit with message: `fix(naming): add m2.7h model alias for M2.7-highspeed workers`.
   - Push to `origin main` using fast-forward only.

---

## 3. Reporting & Independent Review

Report back via `from-brandon-compute/` with:
- The diff of the changes made.
- Test execution outputs for `tests/fm-lane-naming-check.test.sh` and `fm-lane-naming-check.sh data/async-lanes.tsv`.
- The commit hash and fast-forward push verification.
- Upon receipt, controller will dispatch an independent review to evaluate the fix per standing rule 2.
