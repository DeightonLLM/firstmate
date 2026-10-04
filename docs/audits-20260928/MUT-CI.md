# MUT-CI: FirstMate CI Supply Chain Fix Evidence

**Audit / Fix Date:** 2026-09-29T00:26:00+01:00  
**Target Host:** Controller (`/root`) — Local Only  
**Role:** Worker (bounded code-fix lane: firstmate CI pinning + checksums)  
**Owner:** Minimax_DubzAI  
**Executor:** agy Gemini 3.8 Flash Medium (runtime model token: `gemini-3.8-flash-medium`)  
**Evidence Path:** `/root/agent-work/firstmate/docs/audits-20260928/MUT-CI.md`  
**Handoff:** Coordinator `wD3:p2` (herdr-review-send contract)  
**Local Commit:** `53e473cc2431d91d638cd4043de0a5712f030f0d`  
**Commit Message:** `ci: pin actions to SHAs, verify jq checksum, drop unverified tasks-axi install`  
**Push Status:** STRICTLY PRESERVED — NO GIT PUSH PERFORMED  

---

## 1. Executive Summary & Verification

In accordance with `docs/audits-20260928/SUPPLYCHAIN.md` §1 findings and the bounded task objective:
1. **GitHub Action Immutable Pinning:** All 15 GitHub Actions references across `.github/workflows/ci.yml` were resolved via upstream git references and pinned to immutable 40-character commit SHAs with semantic tag comments (`actions/checkout`, `actions/upload-artifact`, `actions/download-artifact`). No unpinned third-party actions remain.
2. **Cryptographic Checksum Verification for `jq`:** The official authoritative SHA256 checksum for `jq-1.7` (`jq-linux-amd64`) was obtained from GitHub release provenance (`2f312b9587b1c1eddf3a53f9a0b7d276b9b7b94576c85bda22808ca950569716`) and embedded into all 4 `jq` installation steps in `ci.yml`. Checksums are verified via `sha256sum -c -` before making the binary executable.
3. **Unverified `tasks-axi` Install Dropped:** Repository-wide analysis confirmed that neither parallel shard 1 nor shard 2 references `tasks-axi`. Tests in `portable-serial` contain clean skip guards (`command -v tasks-axi >/dev/null 2>&1 || { echo "skip: tasks-axi not found"; exit 0; }`), ensuring tests succeed without unverified global npm package installations. All 3 `npm install -g tasks-axi` steps were removed from `ci.yml`.
4. **Zero Collateral Edits:** `.github/workflows/no-mistakes-required.yml` was audited and confirmed clean (no `uses:` or unverified downloads). Only `.github/workflows/ci.yml` was committed.

---

## 2. Subagent Architecture & Verdicts

| Subagent | Role | Conversation ID | Scope | Verdict |
|---|---|---|---|---|
| **Subagent 1** | SHA & Checksum Resolver | `13583a43-2e8f-4fa7-9e82-30833988997a` | Resolve upstream SHAs via `git ls-remote` for `actions/checkout`, `actions/upload-artifact`, `actions/download-artifact`; retrieve authoritative `jq-1.7` release checksum. | **PASS** |
| **Subagent 2** | Edit Validator | `5326ec38-74e1-4928-93b5-5d07101b242b` | Validate YAML structure, verify 100% action pinning (15/15), verify 4/4 jq checksum verifications before chmod, verify removal of tasks-axi, confirm zero collateral changes. | **PASS** |

---

## 3. Detailed Fix Inventory

### 3.1 Pinned GitHub Actions in `ci.yml`

| Action | Tag Comment | Immutable 40-char Commit SHA | Count in `ci.yml` | Locations (Jobs) |
|---|---|---|---|---|
| `actions/checkout` | `# v6.1.0` | `d23441a48e516b6c34aea4fa41551a30e30af803` | 9 | `lint`, `test-coverage`, `tests-portable-parallel-1`, `tests-portable-parallel-2`, `tests-portable-serial`, `tests-herdr`, `tests-timing-aggregate`, `macos-stock-bash`, `invariants` |
| `actions/upload-artifact` | `# v4.6.2` | `ea165f8d65b6e75b540449e92b4886f43607fa02` | 5 | `tests-portable-parallel-1`, `tests-portable-parallel-2`, `tests-portable-serial`, `tests-herdr`, `tests-timing-aggregate` |
| `actions/download-artifact` | `# v4.3.0` | `d3f86a106a0bac45b974a628896c90dbdf5c8093` | 1 | `tests-timing-aggregate` |

### 3.2 `jq` Binary Integrity Verification

Official release checksum retrieved from `https://github.com/jqlang/jq/releases/download/jq-1.7/sha256sum.txt`:
```
2f312b9587b1c1eddf3a53f9a0b7d276b9b7b94576c85bda22808ca950569716  jq-linux-amd64
```

Applied pattern in `ci.yml` across jobs `lint`, `tests-portable-parallel-1`, `tests-portable-parallel-2`, and `tests-portable-serial`:
```yaml
      - name: Install pinned ShellCheck + jq 1.7
        run: |
          set -eu
          jq_sha256="2f312b9587b1c1eddf3a53f9a0b7d276b9b7b94576c85bda22808ca950569716"
          sudo wget -qO /usr/local/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64
          echo "$jq_sha256  /usr/local/bin/jq" | sha256sum -c -
          sudo chmod +x /usr/local/bin/jq
          bin/fm-install-shellcheck.sh "$RUNNER_TEMP/bin"
          echo "$RUNNER_TEMP/bin" >> "$GITHUB_PATH"
```

### 3.3 `tasks-axi` Analysis & Removal

- **Shard Analysis:**
  - `tests-portable-parallel-1`: 0 test scripts invoke `tasks-axi`.
  - `tests-portable-parallel-2`: 0 test scripts invoke `tasks-axi`.
  - `tests-portable-serial`: 2 test scripts check for `tasks-axi` availability:
    - `tests/fm-backlog-handoff.test.sh:14`: `command -v tasks-axi >/dev/null 2>&1 || { echo "skip: tasks-axi not found (required by the delegated handoff path)"; exit 0; }`
    - `tests/fm-public-followup.test.sh:27`: `command -v tasks-axi >/dev/null 2>&1 || { echo "skip: tasks-axi not found"; exit 0; }`
  - Neither test fails if `tasks-axi` is absent; both skip cleanly with `exit 0` and are logged under `skipped_gate` in test summary.
- **Action Taken:** Removed unverified `npm install -g tasks-axi` from `tests-portable-parallel-1`, `tests-portable-parallel-2`, and `tests-portable-serial`.

---

## 4. Git Diff & Commit Evidence

### 4.1 Commit Metadata
```text
commit 53e473cc2431d91d638cd4043de0a5712f030f0d (HEAD -> main)
Author: Firstmate Agent <agent@firstmate>
Date:   Tue Sep 29 00:24:48 2026 +0100

    ci: pin actions to SHAs, verify jq checksum, drop unverified tasks-axi install

 .github/workflows/ci.yml | 69 ++++++++++++++++++++++++------------------------
 1 file changed, 35 insertions(+), 34 deletions(-)
```

### 4.2 Diffstat
```text
 .github/workflows/ci.yml | 69 ++++++++++++++++++++++++------------------------
 1 file changed, 35 insertions(+), 34 deletions(-)
```

---

## 5. Security Postflight Verification

- **Agent Secret Scan:**
  `/root/bin/agent-secret-scan check /root` executed:
  ```text
  SUCCESS: no new leaked secret files found; 197 existing path(s) accepted by baseline/manifest
  ```
- **Local Network Boundary:** No git push executed; commits strictly local on `main`.
- **Target Boundary Compliance:** Only `.github/workflows/ci.yml` modified and committed.
