# Mutation Evidence: Pre-Turn Snapshot & Rollback for Agent CLI Refreshes

**Audit Reference:** `docs/audits-20260928/SUPPLYCHAIN.md` §"Herdr Pre-Turn Update Asymmetry"  
**Target Script:** `/root/bin/herdr-agent-start-fresh`  
**Evidence Path:** `/root/agent-work/firstmate/docs/audits-20260928/MUT-SNAPSHOT.md`  
**Date:** 2026-09-29  
**Status:** **ACCEPTED & VERIFIED**

---

## 1. Objective & Threat Mitigation

### Background & Supply Chain Vulnerability
Previously, `herdr-agent-start-fresh` implemented pre-update snapshotting and automatic rollback exclusively for `senpi` (`/var/tmp/herdr-senpi-rollback`). In contrast, the refresh phases for `pi`, `codex`, `claude`, `omp`, and `agy` performed in-place vendor updates directly on host paths without pre-update snapshots. A corrupt upstream package release or mid-stream network drop could leave the CLI corrupted or missing (as experienced with Codex on 2026-09-24), causing subsequent agent turn starts to fail closed across the entire system.

### Remediated Architecture
Implemented symmetrical, fail-closed pre-turn snapshotting, post-update verification, and automatic rollback for `pi`, `codex`, `claude`, `omp`, and `agy`:
1. **Pre-Update Snapshot:** Before executing any CLI update, snapshots the resolved binary path into `/var/tmp/herdr-cli-rollback/<kind>/<timestamp>/` (mode `0700`). If the binary is a symlink, both the symlink and the resolved target are preserved.
2. **Snapshot Rotation:** Automatically prunes snapshots to keep strictly the newest 3 snapshots per kind.
3. **Fail-Closed Snapshot Guard:** If snapshot directory creation or binary copying fails, the update phase immediately aborts (exit 79), preventing any unrecoverable updates.
4. **Post-Update Probe:** Executes `<cli> --version` with a bounded timeout (`HERDR_CLI_VERIFY_TIMEOUT_SEC:-10`). Any non-zero exit code or timeout failure is treated as a verification failure.
5. **Automatic Rollback:** On either update failure or post-update verification failure, the broken binary is quarantined (`failed_<timestamp>_$$`), and the snapshot is restored atomically (using staging files and `mv -f` to prevent `ETXTBSY`), then verified. The phase fails closed (exit 79) with clear diagnostic messaging.
6. **Additive & Safe:** If the binary path cannot be resolved or does not exist yet, behavior remains additive without breaking.
7. **Isolated Selftest Mode:** Embedded `--selftest` suite exercises snapshot creation, 3-generation rotation, update failure rollback, verification failure rollback, and clean update verification on dummy binaries without modifying real CLIs.

---

## 2. Subagent Plan & Execution

| Subagent Role | Conversation ID | Scope | Verdict |
| :--- | :--- | :--- | :--- |
| **Subagent 1: Design Reviewer** | `3c1a95e1-ba4e-44e8-a111-cc88891c9ad5` | Review edge cases (binary vs wrapper vs symlink, ETXTBSY atomic replacement, disk capacity & rotation, coreutils timeout, argument parsing collision). | **APPROVED WITH REQUIRED ARCHITECTURAL REVISIONS** (Revisions incorporated into implementation). |
| **Subagent 2: Selftest Validator** | `452d90f5-8325-4acf-956b-fb1259bc2e33` | Independent execution of `/root/bin/herdr-agent-start-fresh --selftest`, filesystem clean verification, and interface/exit-code validation. | **PASS (ALL 5 TEST CASES & ALL INTERFACE CONTRACTS VERIFIED)**. |

---

## 3. Interface & Argument Parsing Diff

The script's usage signature (`herdr-agent-start-fresh <name> --kind <kind> --pane <pane-id> [-- agent-args...]`), environment contract (`HERDR_ENV=1`), and exit codes (`64`, `77`, `79`) are strictly preserved.

### Diff of Argument Parsing & Entrypoint:
```diff
 usage() {
   printf 'usage: herdr-agent-start-fresh <name> --kind <kind> --pane <pane-id> [-- agent-args...]\n' >&2
   exit 64
 }
 
+if [ "${1:-}" = "--selftest" ] || [ "${1:-}" = "--selftest-snapshot" ]; then
+  _run_snapshot_selftest
+  exit $?
+fi
+
 [ "${HERDR_ENV:-}" = 1 ] || {
   printf 'REFUSE: HERDR_ENV=1 is required\n' >&2
   exit 77
@@ -349,18 +660,35 @@
 
 _phase1_update() {
   case "$kind" in
-    pi)    "${AGENT_START_FRESH_PI_BIN:-/usr/local/bin/pi}" update --self --no-approve ;;
-    senpi) "$_senpi_bin" update --self --no-approve ;;
-    codex) "${AGENT_START_FRESH_CODEX_BIN:-/usr/bin/codex}" update ;;
-    claude) "${AGENT_START_FRESH_CLAUDE_BIN:-/usr/bin/claude}" update ;;
-    omp)   "${AGENT_START_FRESH_OMP_BIN:-/root/.local/bin/omp}" update ;;
+    pi)
+      local _pi_bin="${AGENT_START_FRESH_PI_BIN:-/usr/local/bin/pi}"
+      _update_cli_with_snapshot pi "$_pi_bin" "$_pi_bin" update --self --no-approve
+      ;;
+    senpi)
+      "$_senpi_bin" update --self --no-approve
+      ;;
+    codex)
+      local _codex_bin="${AGENT_START_FRESH_CODEX_BIN:-/usr/bin/codex}"
+      _update_cli_with_snapshot codex "$_codex_bin" "$_codex_bin" update
+      ;;
+    claude)
+      local _claude_bin="${AGENT_START_FRESH_CLAUDE_BIN:-/usr/bin/claude}"
+      _update_cli_with_snapshot claude "$_claude_bin" "$_claude_bin" update
+      ;;
+    omp)
+      local _omp_bin="${AGENT_START_FRESH_OMP_BIN:-/root/.local/bin/omp}"
+      _update_cli_with_snapshot omp "$_omp_bin" "$_omp_bin" update
+      ;;
     agy)
-      "${AGENT_START_FRESH_AGY_BIN:-/root/.local/bin/agy}" update || {
+      local _agy_bin="${AGENT_START_FRESH_AGY_BIN:-/root/.local/bin/agy}"
+      _update_cli_with_snapshot agy "$_agy_bin" "$_agy_bin" update || {
         printf 'REFUSE: AGY CLI update failed\n' >&2
         return 79
       }
       ;;
-    warp) "${AGENT_START_FRESH_WARP_BIN:-/root/.local/bin/warp}" --version >/dev/null ;;
+    warp)
+      "${AGENT_START_FRESH_WARP_BIN:-/root/.local/bin/warp}" --version >/dev/null
+      ;;
     gemini)
       printf 'REFUSE: Gemini is disabled on this controller; use AGY for this lane\n' >&2
       return 79
```

---

## 4. Selftest Execution & Verbatim Receipt

### Execution Command:
```bash
/root/bin/herdr-agent-start-fresh --selftest
```

### Verbatim Output:
```
=== Selftest Case 1: Snapshot creation ===
PASS: Snapshot created at /var/tmp/herdr-cli-rollback/selftest-2953756/selftest-dummy/20260929_002754_2953756
=== Selftest Case 2: Snapshot rotation (keep newest 3) ===
PASS: Snapshot rotation preserved exactly 3 newest snapshots (count=3)
=== Selftest Case 3: Update command failure -> automatic rollback ===
herdr-agent-start-fresh: pre-turn snapshot created for selftest-dummy at /var/tmp/herdr-cli-rollback/selftest-2953756/selftest-dummy/20260929_002758_2953756
Simulating broken update failure mid-unpack
herdr-agent-start-fresh: selftest-dummy update command failed (exit 1), attempting rollback...
herdr-agent-start-fresh: ROLLED BACK selftest-dummy to snapshot /var/tmp/herdr-cli-rollback/selftest-2953756/selftest-dummy/20260929_002758_2953756
PASS: Rollback on update failure succeeded; binary restored to dummy-agent-cli 1.0.0
=== Selftest Case 4: Post-update verification failure -> automatic rollback ===
herdr-agent-start-fresh: pre-turn snapshot created for selftest-dummy at /var/tmp/herdr-cli-rollback/selftest-2953756/selftest-dummy/20260929_002758_2953756
Simulating hollow update (exit 0 but binary broken/unrunnable)
herdr-agent-start-fresh: selftest-dummy update completed but binary verification failed at /tmp/herdr-snapshot-selftest.zsEiqr/dummy-agent-cli, rolling back...
herdr-agent-start-fresh: ROLLED BACK selftest-dummy to snapshot /var/tmp/herdr-cli-rollback/selftest-2953756/selftest-dummy/20260929_002758_2953756 (verification failed post-update)
PASS: Rollback on verification failure succeeded; binary restored to dummy-agent-cli 1.0.0
=== Selftest Case 5: Successful update -> verified clean ===
herdr-agent-start-fresh: pre-turn snapshot created for selftest-dummy at /var/tmp/herdr-cli-rollback/selftest-2953756/selftest-dummy/20260929_002758_2953756
herdr-agent-start-fresh: selftest-dummy CLI verified post-update at /tmp/herdr-snapshot-selftest.zsEiqr/dummy-agent-cli
PASS: Clean update succeeded and verified at dummy-agent-cli 1.1.0
herdr-agent-start-fresh: snapshot/verify/rollback selftest passed (all cases verified)
```
**Exit Code:** `0`

---

## 5. Verification Matrix & Results

| Check | Command | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Bash Syntax** | `bash -n /root/bin/herdr-agent-start-fresh` | Exit 0, clean stdout/stderr | Exit 0 | **PASS** |
| **Selftest Suite** | `/root/bin/herdr-agent-start-fresh --selftest` | Exit 0, 5 test cases passed | Exit 0, 5/5 pass | **PASS** |
| **Clean Rollback Dir** | `ls -la /var/tmp/herdr-cli-rollback` | Clean directory, 0 stale dirs | Clean | **PASS** |
| **Missing HERDR_ENV** | `env -u HERDR_ENV /root/bin/herdr-agent-start-fresh` | Exit 77, `REFUSE: HERDR_ENV=1 is required` | Exit 77 | **PASS** |
| **Usage Contract** | `HERDR_ENV=1 /root/bin/herdr-agent-start-fresh` | Exit 64, standard usage line | Exit 64 | **PASS** |
| **Invalid Arg Contract** | `HERDR_ENV=1 /root/bin/herdr-agent-start-fresh name --invalid` | Exit 64, standard usage line | Exit 64 | **PASS** |
| **Pre-Turn Secret Scan** | `/root/bin/agent-secret-scan check /root` | Exit 0, 0 new findings | Exit 0 | **PASS** |
| **Post-Turn Secret Scan**| `/root/bin/agent-secret-scan check /root` | Exit 0, 0 new findings | Exit 0 | **PASS** |

---

## 6. Conclusion
The supply-chain pre-turn update asymmetry documented in `SUPPLYCHAIN.md` is resolved. `herdr-agent-start-fresh` now provides robust snapshotting, execution verification, and fail-closed automatic rollback across all CLI types (`pi`, `codex`, `claude`, `omp`, `agy`, and existing `senpi`), preserving the exact invocation contract and preventing upstream or network corruptions from stranding controller runtimes.
