# Pi Extension Implementation & Verification Report: 07-stale-claim-guard.ts

**Date:** 2026-09-28  
**Scope:** `/root/.pi/agent/extensions/07-stale-claim-guard.ts`, First Mate Operator Docs  
**Lane:** docs-rule-r2  
**Status:** COMPLETE | ALL TESTS PASS | 8 EXTENSIONS LOADED VERIFIED  

---

## 1. Executive Summary

This report documents the implementation and verification of Pi extension `07-stale-claim-guard.ts` on host `controller`. The extension enforces the operator documentation rule:

> **Docs Rule:** Any host or service claim (reachability, DNS, SSL, ports, versions, agent/model status, uptime) written to operator documentation must be verified live before being recorded.

The extension intercepts file writes, edits, and shell redirects targeting First Mate operator docs (`BOARD.md`, `CONTROLLER_STATE.md`, `IDENTITY.md`, and report files in `docs/*.md`). When content adds host or service assertions without a dated verification marker and command/receipt reference, the extension blocks the operation (or prompts for confirmation in interactive UI mode).

---

## 2. Architecture & Pattern Alignment

The extension strictly follows the `03-enhanced-permission-gate.ts` pattern established in `/root/.pi/agent/extensions/`:
- **API Interface:** Subscribes to `tool_call` lifecycle events via `pi.on("tool_call", ...)`.
- **Target Extraction:** Supports `write` (full content), `edit` (evaluates `edits[].newText`), and `bash` (detects redirection/appends to guarded docs).
- **Enforcement Mode:**
  - In non-interactive/autonomous execution (`ctx.hasUI === false`), returns `{ block: true, reason: ... }`.
  - In interactive execution (`ctx.hasUI === true`), prompts the operator via `ctx.ui.select` allowing explicit override or rejection.
- **Fail-Closed Verification:** Claims must satisfy two conjunctive criteria:
  1. **Dated check:** e.g., `YYYY-MM-DD`, `DD Month YYYY`, or `Month DD, YYYY`.
  2. **Live command or receipt reference:** e.g., command name (`curl`, `ssh`, `dig`, `openssl`, `ping`), backticked execution expression (`` `...` ``), or receipt token (`receipt`, `proof`, `evidence`, `exit code`, `sha256`, `HTTP 200`, `SSL_VERIFY: 0`).

---

## 3. Evidence of Verification & Stop Condition Checklist

### 3.1 Syntax Check
Executed: `node --experimental-strip-types --check /root/.pi/agent/extensions/07-stale-claim-guard.ts`
- **Exit Code:** 0
- **Result:** PASSED — TypeScript types stripped and syntax verified cleanly under Node v22.23.3.

### 3.2 All 8 Extensions Load into Pi Runtime
Executed via Pi Core's `discoverAndLoadExtensions` in `/root/tools/pi-agent/node_modules/@earendil-works/pi-coding-agent/dist/core/extensions/index.js`:
- **Total Loaded:** 11 extensions (3 workspace/system extensions + 8 root Pi extensions)
- **Errors:** `[]` (0 errors)
- **Active Root Extensions:**
  1. `00-spend-gate.ts`
  2. `01-model-firewall.ts`
  3. `02-production-gate.ts`
  4. `03-enhanced-permission-gate.ts`
  5. `04-model-status.ts`
  6. `05-handoff-helper.ts`
  7. `06-worker-pane-isolation.ts`
  8. `07-stale-claim-guard.ts`

### 3.3 Blocked Stale Claim Test Evidence
- **Target:** `BOARD.md`
- **Attempted Content:** `"elevatesVPS is reachable and nginx is running on port 80"`
- **Evaluation:** Blocked (missing dated check and command/receipt reference).
- **Block Reason Returned:**
  ```text
  BLOCKED by 07-stale-claim-guard: Host/service claim (reachability: "reachable") in operator doc "BOARD.md" lacks live verification marker. Claims (reachability, DNS, SSL, ports, versions, agent/model status, uptime) must include a dated check (e.g. YYYY-MM-DD) and a live command/receipt reference (e.g. curl, ssh, receipt/proof) before being written. Verify live first.
  ```

### 3.4 Passing Verified Claim Test Evidence
- **Target:** `BOARD.md`
- **Attempted Content:** `"Verified 2026-09-28 via `ssh elevatesVPS systemctl status nginx`: HTTP 200, nginx running on port 80 (receipt: rc=0)."`
- **Evaluation:** Allowed (`res === undefined`).
- **Markers Validated:**
  - Date: `2026-09-28`
  - Command: `` `ssh elevatesVPS systemctl status nginx` ``
  - Proof/Receipt: `Verified`, `receipt: rc=0`, `HTTP 200`

---

## 4. Test Suite Execution Log

Test Suite Location: `/root/.pi/agent/extensions/tests/test-stale-claim-guard.ts`  
Command: `node --experimental-strip-types /root/.pi/agent/extensions/tests/test-stale-claim-guard.ts`

```text
=== 1. Guarded Documents Target Matching ===
✅ PASS: Matches BOARD.md
✅ PASS: Matches full path BOARD.md
✅ PASS: Matches CONTROLLER_STATE.md
✅ PASS: Matches symlinked firstmate CONTROLLER_STATE.md
✅ PASS: Matches data/IDENTITY.md
✅ PASS: Matches full path data/IDENTITY.md
✅ PASS: Matches docs report
✅ PASS: Matches docs evidence path
✅ PASS: Rejects README.md (not guarded)
✅ PASS: Rejects source code (not guarded)
✅ PASS: Rejects config files (not guarded)

=== 2. Claim Detection Patterns ===
✅ PASS: Detects reachability claim: reachability
✅ PASS: Detects DNS claim: dns
✅ PASS: Detects SSL claim: ssl-tls
✅ PASS: Detects model status claim: model-runtime
✅ PASS: Detects uptime claim: uptime-outage
✅ PASS: Does not flag benign documentation updates

=== 3. Live Verification Marker Validation ===
✅ PASS: Identifies missing verification marker
✅ PASS: Identifies dated check + command/receipt reference
✅ PASS: Identifies dated check + curl command
✅ PASS: Rejects date-only without verification command/receipt
✅ PASS: Rejects proof-only without dated check

=== 4. Document Change Evaluation (Blocked vs Passing) ===
✅ PASS: BLOCKED: Stale/unverified claim in BOARD.md is blocked
✅ PASS: Provides actionable rejection reason
✅ PASS: PASSING: Verified claim with date and command/receipt in BOARD.md is allowed
✅ PASS: PASSING: Non-guarded doc (README.md) is not blocked
✅ PASS: PASSING: Guarded doc without claims is not blocked

=== 5. Tool Call Event Extraction ===
✅ PASS: Extracts write tool target
✅ PASS: Extracts write tool content
✅ PASS: Extracts edit tool target
✅ PASS: Extracts edit tool newText
✅ PASS: Extracts bash redirection target

=== 6. Extension Lifecycle & Tool Hook Execution ===
✅ PASS: Registers tool_call handler with pi
✅ PASS: Autonomous run: Blocks stale claim write when hasUI=false
✅ PASS: Autonomous run: Block reason contains guard ID
✅ PASS: Autonomous run: Allows verified claim write (returns undefined)
✅ PASS: Interactive run: Displays prompt modal to operator
✅ PASS: Interactive run: Blocks when operator selects 'No, verify live first'
✅ PASS: Interactive run: Allows when operator overrides

========================================
Test Results: 39 passed, 0 failed
========================================
```

---

## 5. Artifact Ledger

| Path | Purpose | State |
|:---|:---|:---|
| `/root/.pi/agent/extensions/07-stale-claim-guard.ts` | Stale claim guard extension implementation | Committed to extension tree |
| `/root/.pi/agent/extensions/tests/test-stale-claim-guard.ts` | Comprehensive unit & lifecycle test suite (39 assertions) | Passing |
| `/root/agent-work/deightonllm-firstmate/docs/STALE-CLAIM-GUARD-R2-20260928.md` | Formal lane evidence report | Verified |
