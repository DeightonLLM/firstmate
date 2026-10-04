# Bounded Mutation Evidence: Pi Extensions GAP-04 & GAP-05 Repair

**Date:** 2026-09-29  
**Host:** controller (`/root`)  
**Role:** worker (bounded code-fix lane: pi extensions GAP-04 + GAP-05)  
**Executor:** agy Gemini 3.8 Flash Medium (medium effort)  
**Lane Mode:** `EXECUTE_BOUNDED_TASK`  
**Dispatch Provenance:** `CONTROLLER_BOUND_TASK`  
**Checkpoint Lane:** `mut-pigate`  

---

## 1. Subagent Plan & Execution

- **Plan:** Direct bounded execution in pane without spawning subagents (0 sub-agents). Both fixes are tightly coupled to extension hooks and verified against local node test suites; avoiding subagent context overhead.
- **Scope:** `NONE`
- **Verdict:** `DIRECT_EXECUTION`

---

## 2. Executive Summary of Changes

### GAP-04: Prompt Token Bypass Elimination & Operator Environment Binding
- **Files Modified:**
  - `/root/.pi/agent/extensions/01-model-firewall.ts`
  - `/root/.pi/agent/extensions/02-production-gate.ts`
- **Vulnerability:**
  - `02-production-gate.ts` parsed `ctx.session.systemPrompt` during `session_start` for `PRODUCTION_OVERRIDE` to bypass live SaaS write protection.
  - `01-model-firewall.ts` parsed `ctx.session.systemPrompt` during `session_start` for `AUTHORIZE_ASTRA` / `AUTHORIZE_SOL` to unlock restricted quota-burning models.
  - Untrusted prompts, agent-generated prompts, or prompt injection payloads containing these strings could bypass critical live protections without operator intervention.
- **Remediation & Chosen Mechanism:**
  - Removed all `session_start` prompt token checks (`PRODUCTION_OVERRIDE`, `AUTHORIZE_ASTRA`, `AUTHORIZE_SOL`).
  - In `02-production-gate.ts`: Bound bypass strictly to:
    1. Explicit operator-set environment variable `process.env.PI_PRODUCTION_OVERRIDE === "1"` (cannot be set via agent prompt), OR
    2. Existing operator time-boxed file unlock (`/root/.pi/agent/PRODUCTION_UNLOCK`, mtime < 60 min, with fail-closed agent forge blocking).
  - In `01-model-firewall.ts`: Bound model unlocks strictly to explicit operator-set environment variables:
    1. `process.env.PI_AUTHORIZE_ASTRA === "1"`
    2. `process.env.PI_AUTHORIZE_SOL === "1"`
  - Documented mechanism in both extensions' header documentation.

### GAP-05: Quote-Aware Redirection Target Extraction
- **Files Modified:**
  - `/root/.pi/agent/extensions/07-stale-claim-guard.ts`
  - `/root/.pi/agent/extensions/tests/test-stale-claim-guard.ts`
- **Vulnerability:**
  - `07-stale-claim-guard.ts` extracted bash redirection targets using `/(?:>|>>|tee\s+(?:-a\s+)?)\s*([^\s;&|]+\.md)/`.
  - When the target was quoted (e.g. `>> "BOARD.md"` or `>> 'BOARD.md'`), the extracted target retained leading quotes (e.g. `"BOARD.md`) and/or dropped trailing quotes, causing `isGuardedDoc` to return `false` and bypassing stale claim verification.
- **Remediation:**
  - Updated extraction pattern to be quote-aware:
    ```typescript
    const redirectMatch = command.match(
      /(?:[0-9&]?>{1,2}|tee\s+(?:-a\s+)?)\s*(?:"([^"\n;&|]+\.md)"|'([^'\n;&|]+\.md)'|([^\s;&|'"]+\.md))/
    );
    if (redirectMatch) {
      const path = redirectMatch[1] || redirectMatch[2] || redirectMatch[3];
      return { path, content: command };
    }
    ```
  - Added support for double quotes, single quotes, unquoted targets, descriptors (`1>>`, `2>>`, `&>>`), and `tee`/`tee -a`.

---

## 3. TDD RED -> GREEN Evidence

### GAP-04 RED (Before Fix)
Test suite: `/tmp/test-gap-04.ts`
```
=== GAP-04: Production Gate Prompt Token Bypass Test ===
❌ FAIL: 02-production-gate: PRODUCTION_OVERRIDE prompt token must NOT bypass live checks (must block)

=== GAP-04: Model Firewall Prompt Token Bypass Test ===
❌ FAIL: 01-model-firewall: prompt unlock token must NOT bypass model firewall (must block)

========================================
GAP-04 Test Results: 0 passed, 2 failed
========================================
```

### GAP-04 GREEN (After Fix)
Test suite: `/tmp/test-gap-04.ts`
```
=== GAP-04: Production Gate Prompt Token Bypass Test ===
✅ PASS: 02-production-gate: PRODUCTION_OVERRIDE prompt token must NOT bypass live checks (must block)

=== GAP-04: Production Gate Operator Env Override Test ===
✅ PASS: 02-production-gate: operator environment variable PI_PRODUCTION_OVERRIDE=1 authorizes live writes

=== GAP-04: Model Firewall Prompt Token Bypass Test ===
✅ PASS: 01-model-firewall: prompt unlock token must NOT bypass model firewall (must block)

=== GAP-04: Model Firewall Operator Env Override Test ===
✅ PASS: 01-model-firewall: operator environment variable PI_AUTHORIZE_ASTRA=1 authorizes Astra

========================================
GAP-04 Test Results: 4 passed, 0 failed
========================================
```

---

### GAP-05 RED (Before Fix)
Test suite: `/root/.pi/agent/extensions/tests/test-stale-claim-guard.ts` (with added test cases)
```
❌ FAIL: GAP-05: Extracts double-quoted bash redirection target
❌ FAIL: GAP-05: Extracts single-quoted bash redirection target
❌ FAIL: GAP-05: Extracts quoted tee redirection target
❌ FAIL: GAP-05: Extracts quoted full-path redirection target
...
❌ FAIL: GAP-05: Autonomous run: Blocks unverified claim via quoted bash redirection

========================================
Test Results: 39 passed, 5 failed
========================================
```

### GAP-05 GREEN (After Fix)
Test suite: `/root/.pi/agent/extensions/tests/test-stale-claim-guard.ts`
```
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
✅ PASS: GAP-05: Extracts double-quoted bash redirection target
✅ PASS: GAP-05: Extracts single-quoted bash redirection target
✅ PASS: GAP-05: Extracts quoted tee redirection target
✅ PASS: GAP-05: Extracts quoted full-path redirection target

=== 6. Extension Lifecycle & Tool Hook Execution ===
✅ PASS: Registers tool_call handler with pi
✅ PASS: Autonomous run: Blocks stale claim write when hasUI=false
✅ PASS: Autonomous run: Block reason contains guard ID
✅ PASS: Autonomous run: Allows verified claim write (returns undefined)
✅ PASS: Interactive run: Displays prompt modal to operator
✅ PASS: Interactive run: Blocks when operator selects 'No, verify live first'
✅ PASS: Interactive run: Allows when operator overrides
✅ PASS: GAP-05: Autonomous run: Blocks unverified claim via quoted bash redirection

========================================
Test Results: 44 passed, 0 failed
========================================
```

---

## 4. Full Suite & Syntax Check Verification

### Stale-Claim Test Suite Verification
Command:
```bash
node --experimental-strip-types /root/.pi/agent/extensions/tests/test-stale-claim-guard.ts 2>&1 | tail -2
```
Output:
```
Test Results: 44 passed, 0 failed
========================================
```

### TypeScript Syntax Verification
Command:
```bash
node --experimental-strip-types --check /root/.pi/agent/extensions/01-model-firewall.ts && \
node --experimental-strip-types --check /root/.pi/agent/extensions/02-production-gate.ts && \
node --experimental-strip-types --check /root/.pi/agent/extensions/07-stale-claim-guard.ts
```
Output:
Exit Code `0` (clean, no syntax errors).

---

## 5. Acceptance Verification

- [x] GAP-04 fixed: Prompt tokens removed; unlocks bound to operator environment variables / unlock file.
- [x] GAP-05 fixed: Quote-aware redirection target extraction implemented and verified.
- [x] RED -> GREEN evidence documented and quoted.
- [x] Stale-claim test suite fully green: 44 passed, 0 failed (baseline was 39).
- [x] Syntax checks clean for all 3 extensions.
- [x] Evidence file complete at `/root/agent-work/deightonllm-firstmate/docs/audits-20260928/MUT-PIGATE.md`.
