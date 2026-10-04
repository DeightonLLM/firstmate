# FULLHYG-BRANDON: Full-Surface Hygiene Audit (Brandon-Compute Hetzner Host)

- **Date / Time**: 2026-09-29 03:32:00 BST
- **Role**: worker (bounded full-hygiene lane: brandon-compute Hetzner)
- **Host**: controller (`/root`) — target host `brandon-compute` (Hetzner AX42, 16 CPUs, worker surface) via ssh alias
- **Owner**: Minimax_DubzAI
- **Executor**: agy Gemini 3.8 Flash Medium (`gemini-3.8-flash-medium`)
- **Handoff**: Reply in-pane to coordinator wD3:p2 (`herdr-review-send` contract)
- **Lane Mode**: `EXECUTE_BOUNDED_TASK`
- **Dispatch Provenance**: `CONTROLLER_BOUND_TASK`
- **Evidence Path**: `/root/agent-work/firstmate/docs/audits-20260928/FULLHYG-BRANDON.md`
- **Remote Copy**: `brandon-compute:/home/hd2admin/audits-20260928/FULLHYG-BRANDON.md`
- **Overall Verdict**: **ALL STEPS PASSED (CLEAN)**

---

## 1. Executive Summary & Lane Progress

Full-surface hygiene on `brandon-compute` was executed strictly in the prescribed order:
1. **PRE Secret Scan**: Exit code `0` (`SUCCESS: no new leaked secret files found; 383 existing path(s) accepted by baseline/manifest`).
2. **HARNESS Layer (`~/fleet-hygiene update`)**: All 5 installed agent CLIs (`pi`, `codex`, `agy`, `mcode`, `herdr`) snapshot, updated, and verified cleanly (`UPDATED-PASS`). Zero failures.
3. **OS Layer (`~/fleet-hygiene os-update`)**: 20 packages upgradable, pre-upgrade manifest recorded at `/var/tmp/fleet-hygiene-rollback/os/20260929-032856`, upgrades completed cleanly with `UPGRADE-PASS`. Reboot flag detected (`reboot-required=YES`) and reported (NO REBOOT performed per policy).
4. **VERIFY (`fleet-hygiene verify` + `os-verify`)**: All 5 installed CLIs verified pass (`VERIFY-PASS`); APT package state verified clean (`OS: VERIFY-PASS (apt check clean)`).
5. **Smoke (`codex --version; mcode --version`)**: Both commands succeeded with exit code `0`.
6. **POST Secret Scan**: Exit code `0` (`SUCCESS: no new leaked secret files found; 383 existing path(s) accepted by baseline/manifest`).
7. **Independent Checker Subagent**: Independent read-only verification performed by subagent `b7830918-6381-460c-86df-3396723adb92`, returning **`CHECK_PASS`**.

---

## 2. Preflight Secret Scan (Phase 1)

- **Command**: `ssh brandon-compute '~/bin/agent-secret-scan check /home/hd2admin'`
- **Exit Code**: `0`
- **Output**:
  ```text
  SUCCESS: no new leaked secret files found; 383 existing path(s) accepted by baseline/manifest
  ```
- **Evaluation**: Clean scan. No new secret findings. Proceeded to Phase 2.

---

## 3. Harness Layer Updates (Phase 2)

- **Engine Deployment**: Controller `/root/bin/fleet-hygiene` deployed to `brandon-compute:/home/hd2admin/fleet-hygiene`.
- **Command**: `ssh brandon-compute 'bash -lc "~/fleet-hygiene update"'`
- **Exit Code**: `0`
- **Per-CLI Execution Log**:
  ```text
  CLI pi: current=[0.87.1]
  CLI pi: snapshot=/var/tmp/fleet-hygiene-rollback/pi/20260929-032432
  CLI pi: running: pi update --self --no-approve
  CLI pi: running: pi update --extensions --no-approve
  CLI pi: UPDATED-PASS new=[0.87.1]
  CLI senpi: not-installed
  CLI omp: not-installed
  CLI claude: not-installed
  CLI codex: current=[codex-cli 0.158.0]
  CLI codex: snapshot=/var/tmp/fleet-hygiene-rollback/codex/20260929-032433
  CLI codex: running: codex update
  CLI codex: UPDATED-PASS new=[codex-cli 0.158.0]
  CLI agy: current=[1.2.12]
  CLI agy: snapshot=/var/tmp/fleet-hygiene-rollback/agy/20260929-032433
  CLI agy: running: agy update
  CLI agy: UPDATED-PASS new=[1.2.12]
  CLI mcode: current=[0.5.5]
  CLI mcode: snapshot=/var/tmp/fleet-hygiene-rollback/mcode/20260929-032434
  CLI mcode: running: mcode update
  CLI mcode: UPDATED-PASS new=[0.5.5]
  CLI herdr: current=[herdr 0.9.1]
  CLI herdr: snapshot=/var/tmp/fleet-hygiene-rollback/herdr/20260929-032435
  CLI herdr: running: herdr update
  CLI herdr: UPDATED-PASS new=[herdr 0.9.1]
  ```
- **Harness Summary**: 5 installed CLIs verified up-to-date with pre-update snapshots retained under `/var/tmp/fleet-hygiene-rollback/`. 0 failed updates.

---

## 4. OS Layer Update (Phase 3)

- **Command**: `ssh brandon-compute 'bash -lc "~/fleet-hygiene os-update"'`
- **Exit Code**: `0`
- **Output**:
  ```text
  OS: 20 packages upgradable; manifest=/var/tmp/fleet-hygiene-rollback/os/20260929-032856
  OS: UPGRADE-PASS
  OS: reboot-required=YES
  ```
- **Rollback Manifest & Upgraded Packages**:
  - Manifest directory: `/var/tmp/fleet-hygiene-rollback/os/20260929-032856/`
  - Manifest records: `installed-before.txt` (22,467 bytes) and `upgradable-before.txt` (20 packages, including `containerd.io`, `docker-ce`, `docker-ce-cli`, `docker-buildx-plugin`, `docker-compose-plugin`, `apparmor`, `libapparmor1`, `dmidecode`, `libaudit1`, `libaudit-common`, `distro-info-data`, `libdrm-common`, `libdrm2`, `libssh-4`).
- **Reboot Requirement**:
  - `reboot-required=YES` (`/var/run/reboot-required` present, flagged by `linux-image-6.8.0-142-generic` and `linux-base`).
  - **Policy Enforcement**: Reported only, **NO REBOOT** initiated.

---

## 5. Verification & Smoke Checks (Phases 4 & 5)

### Verification Commands
- **Command**: `ssh brandon-compute 'bash -lc "~/fleet-hygiene verify && ~/fleet-hygiene os-verify"'`
- **Exit Code**: `0`
- **Output**:
  ```text
  CLI pi: VERIFY-PASS [0.87.1]
  CLI senpi: not-installed
  CLI omp: not-installed
  CLI claude: not-installed
  CLI codex: VERIFY-PASS [codex-cli 0.158.0]
  CLI agy: VERIFY-PASS [1.2.12]
  CLI mcode: VERIFY-PASS [0.5.5]
  CLI herdr: VERIFY-PASS [herdr 0.9.1]
  OS: VERIFY-PASS (apt check clean)
  ```

### Smoke Checks
- **Command**: `ssh brandon-compute 'bash -lc "codex --version; mcode --version"'`
- **Exit Code**: `0`
- **Output**:
  ```text
  codex-cli 0.158.0
  0.5.5
  ```

---

## 6. Postflight Secret Scan (Phase 6)

- **Command**: `ssh brandon-compute '~/bin/agent-secret-scan check /home/hd2admin'`
- **Exit Code**: `0`
- **Output**:
  ```text
  SUCCESS: no new leaked secret files found; 383 existing path(s) accepted by baseline/manifest
  ```
- **Evaluation**: Post-scan clean with 0 new findings. Baseline and false positive manifests intact.

---

## 7. Subagent Plan & Execution

In accordance with dispatch instructions (`at most 2 internal sub-agents on disjoint scopes; record scope + verdict in the evidence file`):

### Subagent 1: Independent Hygiene & Smoke Verifier
- **Conversation ID**: `b7830918-6381-460c-86df-3396723adb92`
- **Scope**: Disjoint read-only verification of post-hygiene state on `brandon-compute`:
  1. Login-shell verification of `codex --version` and `mcode --version`.
  2. Inspection of `/var/tmp/fleet-hygiene-rollback/os/` manifest and package records.
  3. Verification of `/var/run/reboot-required` and associated packages.
  4. Independent execution of `fleet-hygiene verify` and `fleet-hygiene os-verify`.
- **Findings**:
  - `codex-cli 0.158.0` and `mcode 0.5.5` exit code 0.
  - Manifest `/var/tmp/fleet-hygiene-rollback/os/20260929-032856/` contains verified `upgradable-before.txt` and `installed-before.txt`.
  - `reboot-required=YES` verified due to kernel packages; no reboot performed.
  - Both verify commands exit code 0.
- **Verdict**: **`CHECK_PASS`**

---

## 8. Summary Table for Acceptance

| Step / Verification | Exit Code | Result / Output Summary | Status |
|---|---|---|---|
| **PRE Secret Scan** | `0` | `SUCCESS: no new leaked secret files found; 383 existing path(s)` | **PASS** |
| **Harness `pi`** | `0` | `UPDATED-PASS` (`0.87.1`) | **PASS** |
| **Harness `codex`** | `0` | `UPDATED-PASS` (`codex-cli 0.158.0`) | **PASS** |
| **Harness `agy`** | `0` | `UPDATED-PASS` (`1.2.12`) | **PASS** |
| **Harness `mcode`** | `0` | `UPDATED-PASS` (`0.5.5`) | **PASS** |
| **Harness `herdr`** | `0` | `UPDATED-PASS` (`herdr 0.9.1`) | **PASS** |
| **OS Upgradable Count** | `0` | 20 packages upgradable; manifest recorded | **PASS** |
| **OS Upgrade Result** | `0` | `UPGRADE-PASS` (apt packages upgraded cleanly) | **PASS** |
| **OS Reboot Status** | `0` | `reboot-required=YES` (reported, no reboot) | **CAPTURED** |
| **Verify: Harness** | `0` | All 5 CLIs `VERIFY-PASS` | **PASS** |
| **Verify: OS** | `0` | `OS: VERIFY-PASS (apt check clean)` | **PASS** |
| **Smoke: `codex`** | `0` | `codex-cli 0.158.0` | **PASS** |
| **Smoke: `mcode`** | `0` | `0.5.5` | **PASS** |
| **POST Secret Scan** | `0` | `SUCCESS: no new leaked secret files found; 383 existing path(s)` | **PASS** |
| **Independent Checker** | `0` | Subagent `b7830918-6381-460c-86df-3396723adb92` | **CHECK_PASS** |
