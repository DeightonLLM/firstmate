# HD2 Agent Harness Software Supply Chain Audit

**Audit Date:** 2026-09-28T22:45:00+01:00  
**Target Host:** Controller (`/root`) — Local Only  
**Role:** Worker (read-only supply-chain audit lane)  
**Owner:** Minimax_DubzAI  
**Executor:** agy Gemini 3.8 Flash Medium (runtime model token: `gemini-3.8-flash-medium`)  
**Evidence Path:** `/root/agent-work/firstmate/docs/audits-20260928/SUPPLYCHAIN.md`  
**Handoff:** Coordinator `wD3:p2` (herdr-review-send contract)  
**Mutation Boundary Status:** Strictly preserved (no packages modified, zero unauthorized writes, read-only audit).

---

## Executive Summary

A comprehensive software supply chain security audit of the HD2 agent harness was conducted across four critical subsystems:
1. **FirstMate GitHub Actions CI Workflows** under `/root/agent-work/firstmate/.github/workflows/*`
2. **Global npm Harness Tooling** under `/usr/local/lib/node_modules/`
3. **mcode Installer Tree and Release Pointer Architecture** under `/root/.minimax-code/`
4. **Herdr Update Channel and Fail-Closed Startup Refresh Phases** in `/root/bin/herdr-agent-start-fresh`

**Summary of Key Findings:**
- **No Critical Compromise:** Zero active backdoors, malicious install hooks, secret exfiltration vectors, or `pull_request_target` / `workflow_run` injection vulnerabilities were detected.
- **CI Pinning Weakness (Medium Severity):** FirstMate CI workflows use mutable major tags (`actions/checkout@v6`, `actions/upload-artifact@v4`, `actions/download-artifact@v4`) rather than immutable 40-character commit SHAs.
- **Herdr Pre-Turn Update Asymmetry (Medium Severity):** While Senpi features robust pre-update snapshotting (`/var/tmp/herdr-senpi-rollback`) and automatic rollback on failure, other agent CLI update paths (`pi`, `codex`, `claude`, `omp`, `agy`) lack snapshot/rollback protection. If an upstream registry serves a corrupt binary or drops network connectivity mid-stream, the CLI binary can be stranded in a broken state, failing closed across subsequent session launches.
- **mcode Resilience to Hollow Packages (Low Severity / Architecture Commended):** The mcode layout v2 utilizes atomic directory pointer updates (`current` -> `releases/<version>`) guarded by a mandatory `postinstall` verification script (`verify-native-install.mjs`). This effectively prevents the hollow-package failure mode that impacted `@openai/codex` on 2026-09-24.

---

## Section 1: FirstMate CI Workflow Audit

**Target Directory:** `/root/agent-work/firstmate/.github/workflows/` (symlink target: `/root/agent-work/deightonllm-firstmate/.github/workflows/`)  
**Files Audited:**
- `ci.yml` (376 lines)
- `no-mistakes-required.yml` (54 lines)

### 1.1 Trigger Evaluation
- **Audit Requirement:** Flag `pull_request_target` or `workflow_run` triggers that could allow untrusted fork PR code to execute with repository write permissions or secret access.
- **Findings:**
  - `ci.yml` triggers strictly on `push: branches: [main]` and `pull_request: branches: [main]`.
  - `no-mistakes-required.yml` triggers on `pull_request: types: [opened, edited, synchronize, reopened], branches: [main]`.
  - Neither workflow employs `pull_request_target` or `workflow_run`.
- **Verdict:** **PASS (INFO)**. Safe trigger definitions preventing unauthorized fork privilege escalation.

### 1.2 Action Pinning Analysis
- **Audit Requirement:** Flag unpinned third-party actions utilizing mutable tags instead of immutable commit SHAs.
- **Findings:**
  - `actions/checkout@v6` is used across 9 distinct jobs (`lint`, `test-coverage`, `tests-portable-parallel-1`, `tests-portable-parallel-2`, `tests-portable-serial`, `tests-herdr`, `tests-timing-aggregate`, `macos-stock-bash`, `invariants`).
  - `actions/upload-artifact@v4` is used across 5 jobs (`tests-portable-parallel-1`, `tests-portable-parallel-2`, `tests-portable-serial`, `tests-herdr`, `tests-timing-aggregate`).
  - `actions/download-artifact@v4` is used in `tests-timing-aggregate`.
- **Supply Chain Risk:** Action tags (e.g. `@v6`, `@v4`) are mutable git references. In the event of an upstream account compromise, maintainer token theft, or tag reassignment, malicious code can be injected into the CI pipeline without changing repository commit hashes.
- **Verdict:** **MEDIUM SEVERITY**. Actions should be pinned to immutable commit SHAs with semantic tag comments (e.g. `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`).

### 1.3 Secret Exposure & Fork Contexts
- **Audit Requirement:** Audit secrets passed into fork-PR contexts.
- **Findings:**
  - Grep verification across all workflows for `secrets.` yielded **0 occurrences**.
  - Top-level permissions in both workflows are explicitly locked to `permissions: contents: read`.
  - PR body validation in `no-mistakes-required.yml` safely maps `${{ github.event.pull_request.body }}` to an environment variable (`env: PR_BODY`), preventing shell script injection.
- **Verdict:** **PASS (INFO)**. Zero secrets are exposed to CI runners or fork PR executions.

### 1.4 Dynamic External Tool Ingestion in CI
- **Findings:**
  - In `ci.yml`, several jobs download external assets over the network without cryptographic checksum validation:
    - `sudo wget -qO /usr/local/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64`
    - `npm install -g tasks-axi`
- **Supply Chain Risk:** If GitHub Release assets for `jq` or the npm package `tasks-axi` are replaced or compromised, runners execute unverified external code.
- **Verdict:** **LOW SEVERITY**. Binaries should be verified against explicit SHA256 checksums before execution.

---

## Section 2: Global npm Harness Tools Audit

**Target Directory:** `/usr/local/lib/node_modules/`

### 2.1 Verbatim `npm ls -g --depth=0` Receipt
```text
/usr/local/lib
├── @code-yeongyu/bin@
├── @code-yeongyu/games@
├── @code-yeongyu/lib@
├── @code-yeongyu/share@
├── @openai/codex@0.158.0
├── acpx@0.15.1
├── backpass@0.1.22
├── lavish-axi@0.1.79
├── mmx-cli@1.0.26
├── quota-axi@0.1.55
└── tasks-axi@0.2.5
```

### 2.2 Package-by-Package Supply Chain Inspection

#### 1. `@openai/codex@0.158.0`
- **Repository:** `{"type": "git", "url": "git+https://github.com/openai/codex.git", "directory": "codex-cli"}`
- **Lifecycle Scripts:** `{}` (None). Zero preinstall, install, postinstall, or uninstall scripts.
- **Binary Wrapper (`bin/codex.js`):** Node.js launcher resolving target triple (e.g. `x86_64-unknown-linux-musl`) to `@openai/codex-linux-x64` under `vendor/<triple>/bin/codex`. If missing, prompts the operator to reinstall. No network callbacks.
- **Verdict:** **PASS (INFO)**.

#### 2. `quota-axi@0.1.55`
- **Repository:** `https://github.com/kunchenguid/quota-axi.git`
- **Lifecycle Scripts:** `build`, `build:skill`, `test`, `dev`, `lint`, `format`, `prepublishOnly`. Zero install/remove lifecycle hooks.
- **Dependencies:** `@toon-format/toon`, `axi-sdk-js`, `proxy-from-env`, `undici`.
- **Network Behavior:** No postinstall network execution.
- **Verdict:** **PASS (INFO)**.

#### 3. `backpass@0.1.22`
- **Repository:** `git+https://github.com/kunchenguid/backpass.git`
- **Lifecycle Scripts:** `check`, `start`, `lint`, `format`, `test`, `typecheck`. Zero install/remove hooks.
- **Dependencies:** `[]` (None).
- **Network Behavior:** No postinstall network execution.
- **Verdict:** **PASS (INFO)**.

#### 4. `lavish-axi@0.1.79`
- **Repository:** `git+https://github.com/kunchenguid/lavish-axi.git`
- **Lifecycle Scripts:** `build`, `build:skill`, `build:plugin`, `check`, `start`, `lint`, `format`, `prepack`, `prepare`, `test`, `typecheck`. Zero preinstall/postinstall hooks.
- **Dependencies:** `@tailwindcss/browser`, `axi-sdk-js`, `chokidar`, `cross-spawn`, `daisyui`, `express`, `open`, `parse5`, `ws`.
- **Network Behavior:** No postinstall network execution.
- **Verdict:** **PASS (INFO)**.

#### 5. `tasks-axi@0.2.5`
- **Repository:** `git+https://github.com/kunchenguid/tasks-axi.git`
- **Lifecycle Scripts:** `build`, `build:skill`, `test`, `lint`, `dev`, `prepack`. Zero install/remove hooks.
- **Dependencies:** `@toon-format/toon`, `axi-sdk-js`.
- **Network Behavior:** No postinstall network execution.
- **Verdict:** **PASS (INFO)**.

#### 6. `mmx-cli@1.0.26`
- **Repository:** `git+https://github.com/MiniMax-AI/cli.git`
- **Lifecycle Scripts:** `dev`, `build`, `build:dev`, `prepublishOnly`, `lint`, `typecheck`, `test`. Zero install/remove hooks.
- **Dependencies:** `@clack/core`, `@clack/prompts`, `bun-plugin-dts`, `es-toolkit`, `jsonc-parser`, `picocolors`, `smol-toml`, `undici`, `yaml`.
- **Network Behavior:** No postinstall network execution.
- **Verdict:** **PASS (INFO)**.

### 2.3 Additional Filesystem Observation: `@code-yeongyu/*`
- **Observation:** Directories `@code-yeongyu/{bin,games,lib,share}` exist under `/usr/local/lib/node_modules/` without standard package structure. `@code-yeongyu/bin` contains system binaries and symlinks (`agy`, `bun`, `codex`, `herdr`, `senpi`, `treehouse`, `1panel-agent`, etc.).
- **Supply Chain Hygiene:** Placing system executable roots inside `node_modules` causes `npm ls -g` warnings (`@code-yeongyu/bin@` unversioned) and risks accidental modification during global package operations.
- **Verdict:** **LOW SEVERITY**. Unconventional directory layout; recommend relocating system symlinks outside node_modules.

---

## Section 3: mcode Installer Tree Audit

**Target Directory:** `/root/.minimax-code/`

### 3.1 Architecture & Current Pointer
- **Release Pointer (`current`):** `0.5.5` (verified live on 2026-09-28).
- **Configuration (`install.json`):**
  ```json
  {
    "schemaVersion": 2,
    "product": "minimax-code",
    "updateOwner": "npm-prefix",
    "packageManager": "npm",
    "packageName": "@minimax-ai/code",
    "registry": "https://registry.npmjs.org/",
    "distTag": "latest",
    "npmExecutable": "/usr/bin/npm",
    "nodeExecutable": "/usr/bin/node",
    "prefix": "/root/.minimax-code",
    "layoutVersion": 2,
    "releasesDirectory": "releases",
    "currentFile": "current"
  }
  ```
- **Wrapper Script (`bin/mcode`):**
  ```sh
  #!/bin/sh
  set -eu
  root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
  release=$(tr -d "\r\n" < "$root/current")
  case "$release" in ""|*[!0-9A-Za-z._-]*) echo "Invalid MCode current release pointer." >&2; exit 1;; esac
  exec "$root/releases/$release/.mcode-launcher" "$@"
  ```
- **Release Launcher (`releases/0.5.5/.mcode-launcher`):**
  ```sh
  #!/bin/sh
  set -eu
  root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
  exec '/usr/bin/node' "$root/lib/node_modules/@minimax-ai/code/cli.js" "$@"
  ```

### 3.2 Comparison with 2026-09-24 Hollow-Platform-Package Incident
- **The Codex Incident (2026-09-24):**
  `@openai/codex` 0.158.0 relies on an optional platform dependency `@openai/codex-linux-x64` to provide the native `codex` binary. When the platform package was published or installed without the binary (`hollow package`), `findCodexExecutable()` failed at runtime with `Missing optional dependency @openai/codex-linux-x64`. Because npm installs in place, the tool was immediately non-functional with no automatic rollback.
- **mcode Architectural Protection:**
  1. **Strict Postinstall Verification:** In `@minimax-ai/code` `package.json`, `"postinstall": "node ./verify-native-install.mjs"` executes immediately upon download. `verify-native-install.mjs` checks Node ABI compatibility, glibc minimum version, and performs an active in-memory SQLite smoke test (`SELECT 1 AS value` on `better-sqlite3`). If any check fails, `verify-native-install.mjs` exits with code 1, immediately aborting the npm install.
  2. **Isolated Versioned Directory Layout:** Updates are installed into an isolated directory `releases/<new-version>/`.
  3. **Atomic Current Pointer Switch:** The `current` release pointer is updated only after the entire installation and verification cycle terminates successfully.
- **Assessment:**
  If an upstream release of `@minimax-ai/code` is hollow or has broken native bindings, the `postinstall` verification fails, npm exits non-zero, and the `current` file remains pointed at the existing verified release (`0.5.5`). **mcode cannot be broken in place by a hollow release.**
- **Residual Risk:** Update collision if multiple processes invoke update simultaneously without lock compliance; however, `.mcode-update.lock` is present.
- **Verdict:** **LOW SEVERITY / MITIGATED (INFO)**. Architecture provides strong resilience against hollow platform packages.

---

## Section 4: Herdr Update Chain Audit

### 4.1 Update Channel Status
- **Command:** `herdr channel show`
- **Output:** `stable`
- **Verdict:** **PASS (INFO)**. Herdr is locked to the stable release channel.

### 4.2 Fail-Closed Startup Refresh in `/root/bin/herdr-agent-start-fresh`
`herdr-agent-start-fresh` executes two mandatory update phases prior to launching the first turn of any agent session:

#### Phase 1: CLI Refresh
- **pi:** `${AGENT_START_FRESH_PI_BIN:-/usr/local/bin/pi} update --self --no-approve`
- **senpi:**
  - Implements an atomic lock directory (`_senpi_lock="/var/run/herdr-senpi-update.lock"`).
  - Snapshots working package to `_senpi_snapshot="/var/tmp/herdr-senpi-rollback"`.
  - Checks Node.js version; if installed Senpi package requires Node >= 24 and host has older Node, defers update safely.
  - Executes `senpi update --self --no-approve`.
  - Performs post-update binary verification (`senpi --version`).
  - **Automatic Rollback:** If the update fails or leaves no runnable binary, automatically restores the working package from snapshot and quarantines the failed package (`/var/tmp/herdr-senpi-failed.<pid>`).
- **codex:** `${AGENT_START_FRESH_CODEX_BIN:-/usr/bin/codex} update`
- **claude:** `${AGENT_START_FRESH_CLAUDE_BIN:-/usr/bin/claude} update`
- **omp:** `${AGENT_START_FRESH_OMP_BIN:-/root/.local/bin/omp} update`
- **agy:** `${AGENT_START_FRESH_AGY_BIN:-/root/.local/bin/agy} update` (validates post-update version against semver regex `^[0-9]+\.[0-9]+\.[0-9]+$`).
- **warp:** `${AGENT_START_FRESH_WARP_BIN:-/root/.local/bin/warp} --version` (probe only).
- **gemini:** Explicitly refused (`REFUSE: Gemini is disabled on this controller; use AGY for this lane`).

#### Phase 2: Extension / Plugin Refresh
- **pi:** `pi update --extensions --no-approve`
- **senpi:** `senpi update --extensions --no-approve`
- **omp:** `omp update --plugins`
- **claude:** `claude plugin update` (runs only if `/root/.claude/plugins/installed_plugins.json` exists and is non-empty).
- **codex, agy, warp:** Documented no-op (no extension/plugin CLI subcommand).

#### 4.3 Supply Chain Risk Analysis of Startup Refresh
- **The Pre-Turn Update Trap:** Because updates run over the public network before every fresh session, any upstream registry outage, DNS glitch, or compromised upstream release blocks agent dispatch across the entire fleet (`REFUSE: ... update failed`, exit 79).
- **Rollback Asymmetry:** Senpi contains exemplary snapshot and rollback logic. In contrast, `pi`, `codex`, `claude`, `omp`, and `agy` execute self-updates directly against their system paths without prior snapshotting. If `codex update` or `pi update` fails mid-unpacking, the host binary can be left corrupted, requiring manual operator recovery.
- **Verdict:** **MEDIUM SEVERITY**. Pre-turn updates should incorporate local package snapshotting and rollback parity across all agent types, or decouple routine session startup from mandatory network updates.

---

## Section 5: Master Findings Table

| ID | Subsystem | Target Path / Component | Severity | 1-Line Justification | Verbatim Receipt Command |
|---|---|---|---|---|---|
| **SC-01** | FirstMate CI | `/root/agent-work/firstmate/.github/workflows/ci.yml` | **MEDIUM** | GitHub Actions (`actions/checkout@v6`, `upload-artifact@v4`, `download-artifact@v4`) use mutable tags instead of immutable commit SHAs, exposing CI to upstream tag hijacking. | `grep -En "uses:[[:space:]]*actions/" /root/agent-work/firstmate/.github/workflows/ci.yml` |
| **SC-02** | FirstMate CI | `/root/agent-work/firstmate/.github/workflows/*.yml` | **INFO** | Zero `pull_request_target` or `workflow_run` triggers present; workflows trigger safely on standard push/pull_request. | `grep -En "pull_request_target|workflow_run" /root/agent-work/firstmate/.github/workflows/*` (exit code 1) |
| **SC-03** | FirstMate CI | `/root/agent-work/firstmate/.github/workflows/*.yml` | **INFO** | Zero secrets exposed to fork PRs; permissions strictly locked to `contents: read` and 0 occurrences of `secrets.*`. | `grep -rn "secrets\." /root/agent-work/firstmate/.github/workflows/` (exit code 1) |
| **SC-04** | FirstMate CI | `/root/agent-work/firstmate/.github/workflows/ci.yml` | **LOW** | External binaries (`jq-1.7` via wget, `tasks-axi` via npm) are downloaded in CI steps without SHA256 checksum verification. | `grep -En "wget.*jq|npm install -g" /root/agent-work/firstmate/.github/workflows/ci.yml` |
| **SC-05** | npm Global | `/usr/local/lib/node_modules/` | **INFO** | Verbatim `npm ls -g --depth=0` records clean dependency tree for 6 harness tools (@openai/codex, quota-axi, backpass, lavish-axi, tasks-axi, mmx-cli). | `npm ls -g --depth=0` |
| **SC-06** | npm Global | `/usr/local/lib/node_modules/*/package.json` | **INFO** | Audited packages contain zero malicious preinstall/postinstall lifecycle scripts or external network callbacks. | Python script inspecting `package.json["scripts"]` across all 6 packages |
| **SC-07** | npm Global | `/usr/local/lib/node_modules/*/package.json` | **INFO** | Repository fields across all global harness tools point to valid, authorized project repositories. | Python script inspecting `package.json["repository"]` across all 6 packages |
| **SC-08** | npm Global | `/usr/local/lib/node_modules/@code-yeongyu` | **LOW** | System tool symlinks (`agy`, `bun`, `codex`, `senpi`, `herdr`) placed under `/usr/local/lib/node_modules/@code-yeongyu/bin` create unversioned global npm artifacts. | `ls -la /usr/local/lib/node_modules/@code-yeongyu/bin/` |
| **SC-09** | mcode | `/root/.minimax-code/install.json` & `current` | **INFO** | mcode layout v2 utilizes atomic `current` release pointer (`0.5.5`) pointing to isolated version directory `releases/0.5.5`. | `cat /root/.minimax-code/current` (returns `0.5.5`) |
| **SC-10** | mcode | `/root/.minimax-code/.../verify-native-install.mjs` | **LOW (Mitigated)** | Postinstall native SQLite validation and atomic pointer updates prevent hollow-package failure modes that affected Codex on 2026-09-24. | `cat /root/.minimax-code/releases/0.5.5/lib/node_modules/@minimax-ai/code/verify-native-install.mjs` |
| **SC-11** | Herdr Update | `herdr channel show` | **INFO** | Herdr CLI update channel is set to `stable`. | `herdr channel show` (returns `stable`) |
| **SC-12** | Herdr Startup | `/root/bin/herdr-agent-start-fresh` (Senpi) | **INFO** | Senpi startup refresh implements exemplary atomic lock serialization, pre-update package snapshotting, Node version deferral, and automatic rollback on failure. | `/root/bin/herdr-agent-start-fresh` lines 375-520 |
| **SC-13** | Herdr Startup | `/root/bin/herdr-agent-start-fresh` (Other CLIs) | **MEDIUM** | Startup CLI refresh for `pi`, `codex`, `claude`, `omp`, and `agy` lacks snapshot/rollback protection; failed network updates can corrupt installed binaries and strand agent sessions. | `/root/bin/herdr-agent-start-fresh` lines 350-370 |

---

## Section 6: Postflight & Security Verification

### 6.1 Secret Scan Verification
- **Pre-session check:** Executed `/root/bin/agent-secret-scan check /root` at 2026-09-28T22:33:04+01:00 -> `SUCCESS: no new leaked secret files found; 197 existing path(s) accepted by baseline/manifest`.
- **Post-session check:** Executed `/root/bin/agent-secret-scan check /root` at 2026-09-28T22:48:00+01:00 -> `SUCCESS: no new leaked secret files found; 197 existing path(s) accepted by baseline/manifest`.

### 6.2 Mutation & Boundary Compliance
- Target files inspected read-only: `/root/agent-work/firstmate/.github/`, `/usr/local/lib/node_modules`, `/root/.local/bin`, `/root/.minimax-code`, `/root/bin`.
- Files written: Exclusively `/root/agent-work/firstmate/docs/audits-20260928/SUPPLYCHAIN.md` (and temporary scratch files in `/tmp`).
- Package operations: 0 installs, 0 updates, 0 uninstalls executed.
- Network spend: $0.00.
