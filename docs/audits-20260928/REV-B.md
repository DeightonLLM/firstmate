# Wave-2 Independent Audit Review (REV-B)

**Review Date:** 2026-09-28T23:22:00+01:00  
**Reviewer Role:** Independent Reviewer (Read-Only Checker Lane, Wave-2 REV-B)  
**Host:** Controller (`/root`) — Local Only  
**Owner:** Minimax_DubzAI  
**Executor:** agy Gemini 3.8 Flash Medium (runtime model token: `gemini-3.8-flash-medium`, reasoning effort: high)  
**Evidence Path:** `/root/agent-work/firstmate/docs/audits-20260928/REV-B.md`  
**Handoff:** Reply in-pane to coordinator `wD3:p2` (herdr-review-send contract)  
**Target Scope:**
1. `/root/agent-work/firstmate/docs/audits-20260928/SUPPLYCHAIN.md`
2. `/root/agent-work/firstmate/docs/audits-20260928/HARDEN.md`
3. `/root/agent-work/firstmate/docs/audits-20260928/HEALTH-RETRO.md`

---

## 1. Executive Summary & Verdict

Each of the three Wave-1 audit artifacts was reviewed against the five mandatory acceptance criteria:
1. Every host/service claim carries a dated marker or verbatim command receipt.
2. Findings cite specific file paths and line references.
3. Recommendations are explicitly marked **`NOT APPLIED`** (with zero mutation evidence).
4. Severity ratings are technically justified.
5. Post-mortem claims match the forensic facts in `/root/agent-work/SESSION-RECOVERY-mvs-c890dcea-20260928.md`.

In addition, 3 live read-only spot-checks were executed per artifact (9 spot-checks total) against the live controller environment to verify factual fidelity. Zero reviewed artifacts were modified.

### Master Verdict Table

| Artifact | Size / Lines | Acceptance Status | Spot-Checks | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **`SUPPLYCHAIN.md`** | 20,416 B / 268 lines | All 5 criteria met | 3/3 MATCH | **CHECK_PASS** |
| **`HARDEN.md`** | 34,069 B / 457 lines | All 5 criteria met | 3/3 MATCH | **CHECK_PASS** |
| **`HEALTH-RETRO.md`** | 27,134 B / 323 lines | All 5 criteria met | 3/3 MATCH | **CHECK_PASS** |

**Consolidated Review Verdict:** `VERDICT: 3 PASS / 0 REVISE`

---

## 2. Per-Artifact Detailed Audit

### 2.1 Artifact 1: `SUPPLYCHAIN.md` (Supply-Chain Security Audit)

- **Artifact Path:** `/root/agent-work/firstmate/docs/audits-20260928/SUPPLYCHAIN.md`
- **File Integrity:** Present, 20,416 bytes, 268 lines (passes >2 KB stop condition).
- **Criterion Evaluation:**
  1. **Dated Markers & Verbatim Receipts:** PASS. Header timestamped `2026-09-28T22:45:00+01:00`. Contains verbatim command receipts for `npm ls -g --depth=0`, `mcode` wrapper scripts, `herdr channel show`, and pre/post `agent-secret-scan`.
  2. **File Paths & Line References:** PASS. Cites specific paths: `.github/workflows/ci.yml` (376 lines), `.github/workflows/no-mistakes-required.yml` (54 lines), `/root/.minimax-code/install.json`, `/root/bin/herdr-agent-start-fresh` (lines 350-370 and 375-520). Master findings table (Table 5) details exact paths and commands for items SC-01 through SC-13.
  3. **Recommendations Explicitly NOT APPLIED:** PASS. Header and Section 6.2 state zero packages were installed, updated, or uninstalled ($0.00 spend). Action items in Sections 1.2, 1.4, 2.3, and 4.3 are framed as unapplied recommendations.
  4. **Severity Ratings Justified:** PASS. SC-01 (GitHub Actions mutable tags) rated MEDIUM with upstream hijacking rationale; SC-04 (unverified wget of jq/tasks-axi) rated LOW; SC-13 (Herdr startup refresh rollback asymmetry across non-Senpi CLIs) rated MEDIUM with stranded session rationale.
  5. **Post-Mortem Alignment:** PASS. Section 3.2 references the 2026-09-24 Codex hollow-package incident and details how mcode's native verification (`verify-native-install.mjs`) and atomic pointer switch prevent this failure mode.
- **Live Spot-Checks:**
  1. *Global npm Harness Packages:* Command `npm ls -g --depth=0` confirmed the exact 6 harness packages (`@openai/codex@0.158.0`, `acpx@0.15.1`, `backpass@0.1.22`, `lavish-axi@0.1.79`, `mmx-cli@1.0.26`, `quota-axi@0.1.55`, `tasks-axi@0.2.5`) and unversioned `@code-yeongyu/*` roots.
  2. *OpenAI Codex Module Structure:* Command `ls -la /usr/local/lib/node_modules/@openai/` confirmed directory presence.
  3. *Herdr Update Channel:* Command `herdr channel show` returned `stable`.
- **Verdict:** **CHECK_PASS**

---

### 2.2 Artifact 2: `HARDEN.md` (3-Host Hardening Audit)

- **Artifact Path:** `/root/agent-work/firstmate/docs/audits-20260928/HARDEN.md`
- **File Integrity:** Present, 34,069 bytes, 457 lines (passes >2 KB stop condition).
- **Criterion Evaluation:**
  1. **Dated Markers & Verbatim Receipts:** PASS. Header timestamped `2026-09-28T22:40:00+01:00`. Contains verbatim outputs for `sshd -T`, `ufw status verbose`, `fail2ban-client status`, `systemctl is-enabled unattended-upgrades`, `apt list --upgradable`, `getent group sudo`, and `ss -tulpn` across all three hosts (`controller`, `brandon-compute`, `hd2stack`).
  2. **File Paths & Line References:** PASS. Cites APT configuration files (`/etc/apt/apt.conf.d/20auto-upgrades`, `/etc/apt/apt.conf.d/50unattended-upgrades`), exact port numbers, PID numbers, and socket listening configurations.
  3. **Recommendations Explicitly NOT APPLIED:** PASS. Section 4 explicitly lists 8 prioritized recommendations with the literal tag `[NOT APPLIED]` on every item:
     - `[NOT APPLIED] Remove 22/tcp ALLOW IN Anywhere from HD2Stack UFW firewall.`
     - `[NOT APPLIED] Apply pending security updates on Brandon Compute (dracut-install, python3-jwt, python3-requests).`
     - `[NOT APPLIED] Restrict public SSH on Controller to Tailscale / VPN management interfaces.`
     - `[NOT APPLIED] Disable SSH X11 Forwarding on Controller (X11Forwarding no).`
     - `[NOT APPLIED] Reduce MaxAuthTries from 6 to 3 or 4 on Controller and HD2Stack.`
     - `[NOT APPLIED] Enforce Tailscale or localhost binding for public Docker / Node ports on Brandon Compute (e.g. port 3001).`
     - `[NOT APPLIED] Enable fail2ban recidive / increment jail on HD2Stack.`
     - `[NOT APPLIED] Migrate Controller SSH authentication from PermitRootLogin without-password to dedicated non-root admin accounts (PermitRootLogin no).`
  4. **Severity Ratings Justified:** PASS. Categorized by Priority 1 (High Risk / Exposure Reduction), Priority 2 (Medium Risk / Daemon Hardening), and Priority 3 (Low Risk / Defense in Depth) with individual risk rationales.
  5. **Post-Mortem Alignment:** N/A (Scope is live 3-host infrastructure hardening baseline; no conflicting claims).
- **Live Spot-Checks:**
  1. *Controller SSHD Parameters:* Command `sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|maxauthtries'` confirmed verbatim:
     - `maxauthtries 6`
     - `permitrootlogin without-password`
     - `pubkeyauthentication yes`
     - `passwordauthentication no`
     - `x11forwarding yes`
  2. *Controller UFW Status:* Command `ufw status verbose` confirmed `Status: active`, `Default: deny (incoming)`, `22/tcp ALLOW IN Anywhere`, `14200/tcp ALLOW IN Anywhere`, etc.
  3. *Controller Sudo Group:* Command `getent group sudo` confirmed verbatim `sudo:x:27:`.
- **Verdict:** **CHECK_PASS**

---

### 2.3 Artifact 3: `HEALTH-RETRO.md` (Quality, 7-Day Git Retro, and Post-Mortem)

- **Artifact Path:** `/root/agent-work/firstmate/docs/audits-20260928/HEALTH-RETRO.md`
- **File Integrity:** Present, 27,134 bytes, 323 lines (passes >2 KB stop condition).
- **Criterion Evaluation:**
  1. **Dated Markers & Verbatim Receipts:** PASS. Header timestamped `2026-09-28T23:05:00+01:00`. Includes verbatim ShellCheck version output (0.11.0), ShellCheck warning logs for 70 FirstMate scripts (17 warnings verbatim), ShellCheck error/warning logs for 46 `/root/bin` scripts (1 error, 35 warnings verbatim), and git log statistics.
  2. **File Paths & Line References:** PASS. Every ShellCheck finding cites file, line, and column reference (e.g. `/root/agent-work/firstmate/bin/fm-always-four.sh:71:1: warning: CONFIG appears unused [SC2034]`, `/root/bin/check-saas-status.test.sh:13:13: error: Double quote array expansions [SC2068]`).
  3. **Recommendations Explicitly NOT APPLIED:** PASS. Header and Section 1.3 explicitly confirm `ZERO fixes were applied` to audited scripts.
  4. **Severity Ratings Justified:** PASS. ShellCheck severity classifications (Error, Warning, Note) adhere to tool definitions with clear breakdown tables.
  5. **Post-Mortem Alignment with `/root/agent-work/SESSION-RECOVERY-mvs-c890dcea-20260928.md`:** PASS (100% factual match):
     - *Incident A (Session Compaction Corruption):* Matches session ID `mvs_c890dcea909a46039d91268cf2508cce`, crash message `"Canonical history target is missing after migration"`, session store path, and forensic byte/message counts (gen 0 snapshot lost, gen 1 compaction summary survived at 10,109 B / 1 msg, gen 2 active ledger lost at 291,075 B / 81 msgs).
     - *Incident B (`mcode` Symlink Resolution):* Matches root cause (symlinks in `/root/.local/bin` breaking `$0`-based path deduction) and remediation (trampoline scripts restoring `mcode --version` = `0.5.5`).
     - *Incident C (`codex` Hollow Package):* Matches missing native binary `vendor/x86_64-unknown-linux-musl/bin/codex` (gutted Sep 24) and remediation (quarantine to `/tmp/codex-broken-20260928/` and reinstallation of `codex-cli 0.158.0`).
- **Live Spot-Checks:**
  1. *ShellCheck Binary Version:* Command `shellcheck --version` returned `version: 0.11.0`.
  2. *Harness CLI Versions:* Commands `codex --version` and `mcode --version` returned `codex-cli 0.158.0` and `0.5.5` respectively.
  3. *7-Day Git Commit Log:* Command `git log --since='7 days ago' --oneline` in `/root/agent-work/deightonllm-firstmate` confirmed exactly 1 commit:
     `2e61f52 feat(system-context): sync approved warehouse docs and PRD traceability for Brandon remote execution (Option A)`.
- **Verdict:** **CHECK_PASS**

---

## 3. Verbatim Live Spot-Check Receipts Log

All spot-checks were executed live on the controller host during this review pass:

```text
=== SPOT-CHECK 1: CLI VERSIONS (codex, mcode, shellcheck) ===
$ codex --version; mcode --version; shellcheck --version
codex-cli 0.158.0
0.5.5
ShellCheck - shell script analysis tool
version: 0.11.0
license: GNU General Public License, version 3
website: https://www.shellcheck.net

=== SPOT-CHECK 2: GLOBAL NPM PACKAGES & STRUCTURE ===
$ ls -la /usr/local/lib/node_modules/@openai/ && npm ls -g --depth=0
total 12
drwxr-xr-x  3 root root 4096 Sep 28 21:30 .
drwxr-xr-x 10 root root 4096 Sep 28 20:55 ..
drwxr-xr-x  4 root root 4096 Sep 28 21:30 codex
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

=== SPOT-CHECK 3: HERDR CHANNEL ===
$ herdr channel show
stable

=== SPOT-CHECK 4: CONTROLLER SSHD CONFIGURATION ===
$ sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|maxauthtries'
maxauthtries 6
permitrootlogin without-password
pubkeyauthentication yes
passwordauthentication no
x11forwarding yes

=== SPOT-CHECK 5: CONTROLLER SUDO GROUP MEMBERSHIP ===
$ getent group sudo
sudo:x:27:

=== SPOT-CHECK 6: CONTROLLER UFW STATUS ===
$ ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
443/udp                    ALLOW IN    Anywhere                   # 1panel-rule:16a56ecd-a4dd-48f4-b022-c28c6d2a6549
22/tcp                     ALLOW IN    Anywhere                   # 1panel-rule:4429c5a2-ad1e-4b94-8d39-579f2535eb7c
14200/tcp                  ALLOW IN    Anywhere                   # 1panel-rule:6721be5b-fa86-4248-8866-83a64fc98ed7
80/tcp                     ALLOW IN    Anywhere                  
443/tcp                    ALLOW IN    Anywhere                  
8443/tcp                   ALLOW IN    Anywhere                  
8443/udp                   ALLOW IN    Anywhere                  
Anywhere on tailscale0     ALLOW IN    Anywhere                  
10000/udp                  ALLOW IN    Anywhere                  
443/udp (v6)               ALLOW IN    Anywhere (v6)              # 1panel-rule:4c51c280-db54-4d8e-83bf-7a36afadd7bf
22/tcp (v6)                ALLOW IN    Anywhere (v6)              # 1panel-rule:e100a204-07cf-4aa9-a22b-deed5b10ad7d
14200/tcp (v6)             ALLOW IN    Anywhere (v6)              # 1panel-rule:69373ff4-2b3c-4dc6-95f4-825030201273
80/tcp (v6)                ALLOW IN    Anywhere (v6)             
443/tcp (v6)               ALLOW IN    Anywhere (v6)             
8443/tcp (v6)              ALLOW IN    Anywhere (v6)             
8443/udp (v6)              ALLOW IN    Anywhere (v6)             
Anywhere (v6) on tailscale0 ALLOW IN    Anywhere (v6)             
10000/udp (v6)             ALLOW IN    Anywhere (v6)             

=== SPOT-CHECK 7: 7-DAY GIT LOG IN FIRSTMATE REPOSITORY ===
$ git log --since='7 days ago' --oneline
2e61f52 (HEAD -> main, origin/main, origin/HEAD, brandon/system-context-sync) feat(system-context): sync approved warehouse docs and PRD traceability for Brandon remote execution (Option A)
```

---

## 4. Verification and Boundary Compliance

- **Reviewed Artifact Mutation Status:** STRICTLY PRESERVED. Zero modifications were made to `SUPPLYCHAIN.md`, `HARDEN.md`, or `HEALTH-RETRO.md`.
- **Target Boundary:** Read-only access to `/root/agent-work/firstmate/docs/audits-20260928/`, `/root/agent-work/SESSION-RECOVERY-mvs-c890dcea-20260928.md`, `/usr/local/lib/node_modules`, and `/root/bin`.
- **Write Boundary:** Strictly confined to `/root/agent-work/firstmate/docs/audits-20260928/REV-B.md`.
- **Secret Scan Status:** Pre-session scan passed with `rc=0` (197 baselined files, 0 leaks). Post-session scan re-verified clean.
