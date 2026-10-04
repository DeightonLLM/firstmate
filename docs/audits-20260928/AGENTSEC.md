# AGENTSEC Audit: Agent Safety Guard Chain Verification & Bypass-Surface Analysis

**Date:** 2026-09-28T22:55:00+01:00  
**Host:** `controller` (/root)  
**Lane:** `syssec-agentsec`  
**Role:** Worker (Read-Only Agent-Guard Audit Lane)  
**Status:** COMPLETE | ALL TEST SUITES PASS | DETERMINISTIC VERDICTS RECORDED  

---

## 1. Executive Summary

This audit evaluates the deterministic enforcement, fail-closed properties, test coverage, and bypass surfaces across the entire agent safety guard chain on the controller host. The scope comprises:
1. **Pi Core Extensions (`/root/.pi/agent/extensions/`):**
   - `00-spend-gate.ts`: Spend-pattern bash block, mutation gate, and `SPEND_UNLOCK` handling.
   - `01-model-firewall.ts`: Cost controls, Astra/Sol blocking, and temporary GLM 5.3 Flash cutoff gate.
   - `02-production-gate.ts`: Live SaaS write gating, dangerous command blocking, and `PRODUCTION_UNLOCK`.
   - `03-enhanced-permission-gate.ts`: Dangerous system/destructive bash command confirmation.
   - `06-worker-pane-isolation.ts`: Prevention of worker stacking on coordinator's pane via `herdr pane split`.
   - `07-stale-claim-guard.ts`: Deterministic verification requirement for host/service claims in operator docs.
2. **Dispatch & Lifecycle Gates (`/root/bin/`):**
   - `validate-herdr-lane-prompt`: Strict lane prompt contract, routing banners, required fields, write-boundary denial enumeration, and credential collection prevention (exit codes 0–5, 64, 78).
   - `herdr-agent-start-fresh`: Startup freshness enforcement, per-kind fail-closed CLI/plugin update phases, subagent cap check, AGY auto-approve checkpoint gate (exit 79), and one-use session receipt generation.
   - `herdr-send-submit`: Gate pipeline enforcing pane idle/done state, terminal readiness, overlap prevention, continuity matching, stale-session isolation, artifact stability, independent checker verification, intent guard recording, and post-dispatch turn/To-Do check-in.
3. **Bypass Surface Analysis:**
   - Architectural gaps between wrapper scripts and daemon/socket interfaces (`herdr pane send-text` / `send-keys`).
   - Environment override vectors (`HERDR_OPERATOR_APPROVED`, `HERDR_AGY_AUTO_APPROVE`, `PRODUCTION_OVERRIDE`).
   - Extension runtime boundaries and parsing anomalies in coordinate ledger compilation.

All existing test suites were executed live. Zero live exploits were attempted.

---

## 2. Live Test Suite Execution Receipts

### 2.1 Stale Claim Guard Suite (`07-stale-claim-guard.ts`)
- **Command:** `node --experimental-strip-types /root/.pi/agent/extensions/tests/test-stale-claim-guard.ts`
- **Timestamp:** 2026-09-28 22:34 BST
- **Receipt:**
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
- **Verdict:** PASS (39 passed, 0 failed).

### 2.2 Production Write Gate Suite (`02-production-gate.ts`)
- **Command:** `node --experimental-strip-types /root/agent-work/harness-fix/tests/test-production-gate-readfix.ts`
- **Receipt:**
  ```text
  PASS | plain GET public site | want block=false got=false
  PASS | GET piped to grep | want block=false got=false
  PASS | GET with -w, stdout to /dev/null | want block=false got=false
  PASS | HEAD request (-I) | want block=false got=false
  PASS | cPanel UAPI read (:2083) stays gated | want block=true got=true
  PASS | cPanel UAPI write (POST -d) stays gated | want block=true got=true
  PASS | -o output flag stays gated | want block=true got=true
  PASS | -X POST stays gated | want block=true got=true
  PASS | --json body flag stays gated | want block=true got=true
  PASS | redirect to local file stays gated | want block=true got=true
  PASS | no-space append >>/etc/hosts stays gated | want block=true got=true
  PASS | pipe to sh stays gated | want block=true got=true
  PASS | pipe to tee stays gated | want block=true got=true
  PASS | control: plain echo passes | want block=false got=false
  PASS | control: rm -rf still blocked | want block=true got=true
  PASS | fresh unlock active | want true got true
  PASS | stale unlock expired | want false got false
  PASS | missing unlock inactive | want false got false
  PASS | agent attempt to forge unlock file blocked | want block=true got=true
  SUITE: GREEN
  ```
- **Verdict:** PASS (19 passed, 0 failed).

### 2.3 Temporary GLM Model Block Suite (`01-model-firewall.ts`)
- **Command:** `node --experimental-strip-types /root/agent-work/harness-fix/tests/test-pi-temporary-glm-block.ts`
- **Receipt:**
  ```text
  PASS: temporary GLM block observes the exact cutoff and leaves other routes available
  ```
- **Verdict:** PASS.

### 2.4 Fresh-Agent Baseline Invariant Suite (`herdr-agent-start-fresh`)
- **Command:** `bash /root/agent-work/deightonllm-firstmate/tests/fm-direct-start-fresh-baseline.test.sh`
- **Receipt:**
  ```text
  ok - canonical policy declares the FRESH_AGENT invariant
  ok - direct fresh launch emits shared baseline manifest before Herdr start
  ok - direct fresh launch fails closed before refresh/start when baseline helper is missing
  ALL TESTS PASSED
  ```
- **Verdict:** PASS.

---

## 3. In-Depth Code Review of Pi Extensions

| Extension | Path | Load Order | Hook Events | Determinism | Fail-Closed Mode |
|---|---|---|---|---|---|
| `00-spend-gate.ts` | `/root/.pi/agent/extensions/00-spend-gate.ts` | 1 | `tool_call` (bash, write, edit) | High | Absolute (no dialog override) |
| `01-model-firewall.ts` | `/root/.pi/agent/extensions/01-model-firewall.ts` | 2 | `session_start`, `model_request`, `tool_call` | High | Hard block on GLM & unapproved Astra/Sol |
| `02-production-gate.ts` | `/root/.pi/agent/extensions/02-production-gate.ts` | 3 | `session_start`, `tool_call` (bash, edit, write) | High | Fail-closed if `hasUI=false`; dialog if interactive |
| `03-enhanced-permission-gate.ts` | `/root/.pi/agent/extensions/03-enhanced-permission-gate.ts` | 4 | `tool_call` (bash) | High | Fail-closed if `hasUI=false`; dialog if interactive |
| `06-worker-pane-isolation.ts` | `/root/.pi/agent/extensions/06-worker-pane-isolation.ts` | 7 | `tool_call` (bash) | High | Unconditional block on coordinator split |
| `07-stale-claim-guard.ts` | `/root/.pi/agent/extensions/07-stale-claim-guard.ts` | 8 | `tool_call` (bash, write, edit) | High | Fail-closed if `hasUI=false`; dialog if interactive |

### 3.1 `00-spend-gate.ts`
- **Code Citations:**
  - `SPEND_PATTERNS` ([00-spend-gate.ts:21-50](file:///root/.pi/agent/extensions/00-spend-gate.ts#L21-L50)): Catches transactions across Namecheap API (`namecheap\.[a-z0-9.]*\.(create|renew|reactivate|transfer|purchase)`), Stripe API (`api.stripe.com/v1/(charges|payment_intents)`), PayPal, cPanel/WHM orders (`:2082/:2083.*(order|purchase)`), cloud purchases (`reserved instances`, `hetzner.*order`), metered AI APIs (`generativelanguage.googleapis.com`, `perplexity`, `replicate`), and subscriptions.
  - `MUTATION_PATTERNS` ([00-spend-gate.ts:52-65](file:///root/.pi/agent/extensions/00-spend-gate.ts#L52-L65)): Catches cPanel DNS writes (`execute/DNS/`), `/etc/hosts` and `/etc/cron.d/spendgate` tampering, CLI DNS modifications (`dig`, `nsupdate`), and registrar auth codes.
  - `unlockActive()` ([00-spend-gate.ts:67-76](file:///root/.pi/agent/extensions/00-spend-gate.ts#L67-L76)): Enforces that `/root/.pi/agent/SPEND_UNLOCK` must have `mtime` within 15 minutes (`UNLOCK_WINDOW_MS = 15 * 60 * 1000`) and content starting with `"APPROVED"`. If the file is missing, stale, or malformed, it throws or returns `false`.
  - Anti-Tamper / Anti-Forge ([00-spend-gate.ts:83-93](file:///root/.pi/agent/extensions/00-spend-gate.ts#L83-L93) and [00-spend-gate.ts:98-105](file:///root/.pi/agent/extensions/00-spend-gate.ts#L98-L105)): Any `write` or `edit` tool call targeting `SPEND_UNLOCK` is blocked immediately. Any bash command referencing `SPEND_UNLOCK` is blocked immediately.
- **Fail-Closed Evaluation:** Pass. The extension has no UI override prompt; an unlock is strictly external (operator terminal only).

### 3.2 `01-model-firewall.ts`
- **Code Citations:**
  - GLM Cutoff ([01-model-firewall.ts:13-19](file:///root/.pi/agent/extensions/01-model-firewall.ts#L13-L19)): Blocks `glm-5.3-flash` until `2026-10-01T06:46:00+01:00`.
  - Blocked Models ([01-model-firewall.ts:21-26](file:///root/.pi/agent/extensions/01-model-firewall.ts#L21-L26)): Blocks `gpt-6-astra` and `gpt-6-astra-pro` by default.
  - Enforcement Hook ([01-model-firewall.ts:39-62](file:///root/.pi/agent/extensions/01-model-firewall.ts#L39-L62)): In `model_request`, temporary GLM block is non-bypassable by session prompt. Astra and Sol require explicit system prompt tokens (`AUTHORIZE_ASTRA`, `AUTHORIZE_SOL`) captured at session start.
  - CLI Spawn Interception ([01-model-firewall.ts:65-73](file:///root/.pi/agent/extensions/01-model-firewall.ts#L65-L73)): Blocks attempts to spawn Astra via CLI flags (`--model` or `-m`).
- **Fail-Closed Evaluation:** Pass.

### 3.3 `02-production-gate.ts`
- **Code Citations:**
  - Production Targets ([02-production-gate.ts:19-34](file:///root/.pi/agent/extensions/02-production-gate.ts#L19-L34)): Matches production hosts (`business186`, `business184`, `business190`, `100.106.6.22`, `100.92.152.109`, `vmi3196300`, etc.) and domains (`cbd-data.com`, `musicmetricstools`, `lawyer-dta`, `core-distro`).
  - Dangerous System Commands ([02-production-gate.ts:85-94](file:///root/.pi/agent/extensions/02-production-gate.ts#L85-L94)): Catches `rm -rf`, `drop table/database`, `truncate`, `delete from ... ;`, `pkill -9`, `kill -9`, `init 6`, `reboot`.
  - Anti-Forge Protection ([02-production-gate.ts:117-123](file:///root/.pi/agent/extensions/02-production-gate.ts#L117-L123)): Blocks agent commands referencing `/root/.pi/agent/PRODUCTION_UNLOCK`.
  - Autonomous Fail-Closed Gate ([02-production-gate.ts:128-130](file:///root/.pi/agent/extensions/02-production-gate.ts#L128-L130), [02-production-gate.ts:154-156](file:///root/.pi/agent/extensions/02-production-gate.ts#L154-L156)): If `!ctx.hasUI`, returns `{ block: true, reason }`.
- **Fail-Closed Evaluation:** Pass. Autonomous execution fails closed without UI prompt.

### 3.4 `03-enhanced-permission-gate.ts`
- **Code Citations:**
  - Dangerous Command Patterns ([03-enhanced-permission-gate.ts:9-28](file:///root/.pi/agent/extensions/03-enhanced-permission-gate.ts#L9-L28)): `rm -rf`, `sudo rm`, `chmod/chown 777`, `dd of=`, `mkfs`, `fdisk`, `parted`, `init 0/6`, `shutdown now`, `systemctl stop/disable (nginx|php)`, `iptables -F`, `ufw disable`, `git push --force`, `eval $(`, `| bash`.
  - Autonomous Block ([03-enhanced-permission-gate.ts:38-40](file:///root/.pi/agent/extensions/03-enhanced-permission-gate.ts#L38-L40)): In headless mode (`!ctx.hasUI`), immediately blocks execution.
- **Fail-Closed Evaluation:** Pass.

### 3.5 `06-worker-pane-isolation.ts`
- **Code Citations:**
  - Coordinator Detection ([06-worker-pane-isolation.ts:40-52](file:///root/.pi/agent/extensions/06-worker-pane-isolation.ts#L40-L52)): Queries live coordinator pane ID via `herdr pane current`.
  - Interception & Block ([06-worker-pane-isolation.ts:60-93](file:///root/.pi/agent/extensions/06-worker-pane-isolation.ts#L60-L93)): Matches `herdr pane split <target>`. Blocks if target is `--current`, `$PANE`, `${PANE}`, or matches the live coordinator pane ID.
- **Fail-Closed Evaluation:** Pass. Enforces use of `/root/bin/herdr-worker-pane`.

### 3.6 `07-stale-claim-guard.ts`
- **Code Citations:**
  - Target Path Matching ([07-stale-claim-guard.ts:18-23](file:///root/.pi/agent/extensions/07-stale-claim-guard.ts#L18-L23)): Evaluates writes/edits targeting `BOARD.md`, `CONTROLLER_STATE.md`, `IDENTITY.md`, `data/IDENTITY.md`, and `docs/*.md`.
  - Dual-Marker Requirement ([07-stale-claim-guard.ts:139-144](file:///root/.pi/agent/extensions/07-stale-claim-guard.ts#L139-L144)): Requires both a dated check (`DATE_MARKERS`, lines 95-100) and a live command/receipt marker (`VERIFICATION_MARKERS`, lines 103-111).
  - Autonomous Block ([07-stale-claim-guard.ts:213-215](file:///root/.pi/agent/extensions/07-stale-claim-guard.ts#L213-L215)): Autonomous runs block unverified claims without prompt.
- **Fail-Closed Evaluation:** Pass (39/39 tests verified live).

---

## 4. In-Depth Code Review of Dispatch Gates

### 4.1 `validate-herdr-lane-prompt`
- **File:** `/root/bin/validate-herdr-lane-prompt`
- **Verification of Exit Codes:**
  - **Exit 0:** Contract fully satisfied.
  - **Exit 1:** Generic contract violation:
    - Missing literal phrase `"Use the To-Do List extension"` ([line 213-216](file:///root/bin/validate-herdr-lane-prompt#L213-L216)).
    - Negative lean-ctx wording or missing positive instruction ([line 237-252](file:///root/bin/validate-herdr-lane-prompt#L237-L252)).
    - Naming retired Gemini 3.6 or superseded 3.7 routes ([line 258-272](file:///root/bin/validate-herdr-lane-prompt#L258-L272)).
    - Forbidden sentinels (`context-mode active`, `<session_state>`, etc.) ([line 309-320](file:///root/bin/validate-herdr-lane-prompt#L309-L320)).
  - **Exit 2:** Missing or invalid required fields:
    - Missing any of 12 required fields (`ROLE:`, `HOST:`, `OWNER:`, etc.) ([line 168-195](file:///root/bin/validate-herdr-lane-prompt#L168-L195)).
    - Missing `LANE_MODE: EXECUTE_BOUNDED_TASK` or `DISPATCH_PROVENANCE: CONTROLLER_BOUND_TASK` ([line 204-211](file:///root/bin/validate-herdr-lane-prompt#L204-L211)).
    - Self-declaring `DISPATCH_AUTHORIZATION:` ([line 200-203](file:///root/bin/validate-herdr-lane-prompt#L200-L203)).
    - `PROGRESSIVE_DISCLOSURE:` not having 1 to 3 coordinates ([line 218-230](file:///root/bin/validate-herdr-lane-prompt#L218-L230)).
    - `WRITE_BOUNDARY:` missing explicit denials for `AGENTS.md`, `credential`, `Herdr pane state`, or `client application` ([line 292-304](file:///root/bin/validate-herdr-lane-prompt#L292-L304)).
    - Placeholder values (< 4 characters) in `OBJECTIVE`, `TARGET_BOUNDARY`, etc. ([line 325-343](file:///root/bin/validate-herdr-lane-prompt#L325-L343)).
  - **Exit 3:** Routing banner violation:
    - First line not matching approved banner ([line 125-140](file:///root/bin/validate-herdr-lane-prompt#L125-L140)).
    - Banner and `BROWSER_WORK` mismatch ([line 159-166](file:///root/bin/validate-herdr-lane-prompt#L159-L166)).
  - **Exit 4:** Prompt too short (< 8 bytes) ([line 116-119](file:///root/bin/validate-herdr-lane-prompt#L116-L119)).
  - **Exit 5:** Prompt oversized (> 65536 bytes) ([line 120-123](file:///root/bin/validate-herdr-lane-prompt#L120-L123)).
  - **Exit 64:** Usage or stdin read error ([line 78](file:///root/bin/validate-herdr-lane-prompt#L78), [line 103](file:///root/bin/validate-herdr-lane-prompt#L103)).
  - **Exit 78:** Credential collection attempted via `/root/bin/herdr-secret-input-guard` ([line 109-113](file:///root/bin/validate-herdr-lane-prompt#L109-L113)).

### 4.2 `herdr-agent-start-fresh`
- **File:** `/root/bin/herdr-agent-start-fresh`
- **Key Invariants & Gates:**
  - Fresh-Agent Baseline Invariant ([lines 119-130](file:///root/bin/herdr-agent-start-fresh#L119-L130)): Calls `/root/agent-work/deightonllm-firstmate/bin/fm-session-start.sh --baseline-manifest`. Refuses launch with exit 79 if missing or failing.
  - Pi Route Guard ([lines 170-241](file:///root/bin/herdr-agent-start-fresh#L170-L241)): Pins default Pi model to `openai-codex/gpt-5.6-luna`. Refuses `zai/glm-5.3-flash` until UK cutoff `2026-10-01T06:46:00+01:00` with exit 79.
  - AGY Bounded Auto-Approval & Checkpoint Gate ([lines 261-315](file:///root/bin/herdr-agent-start-fresh#L261-L315)):
    - `--dangerously-skip-permissions` requires `HERDR_OPERATOR_APPROVED=1` or campaign marker (exit 79).
    - If `HERDR_OPERATOR_APPROVED=1` and `HERDR_AGY_AUTO_APPROVE=1`, requires `HERDR_AGY_CHECKPOINT_LANE=<lane-id>` and executes `/root/bin/agy-checkpoint-gate "$_agy_gate_lane"`.
    - `agy-checkpoint-gate` ([agy-checkpoint-gate:17-33](file:///root/bin/agy-checkpoint-gate#L17-L33)) checks `/root/.herdr/checkpoints/${LANE}.receipt`. Exits 79 if receipt is missing, malformed, or older than 3600 seconds. Verified live: exiting 79 on un-checkpointed lane.
  - Per-Kind Update Phases ([lines 350-582](file:///root/bin/herdr-agent-start-fresh#L350-L582)):
    - Phase 1 (CLI): Idempotent vendor updates for `pi`, `senpi`, `codex`, `claude`, `omp`, `agy`, `warp`. For Senpi, uses atomic lock directory (`/var/run/herdr-senpi-update.lock`) and package rollback snapshot (`/var/tmp/herdr-senpi-rollback`).
    - Phase 2 (Extensions/Plugins): Fail-closed for `pi` (`update --extensions`), `senpi` (`update --extensions`), `omp` (`update --plugins`), `claude` (`plugin update`).
  - Subagent Cap Check ([lines 614-629](file:///root/bin/herdr-agent-start-fresh#L614-L629)): Invokes `herdr-subagent-cap-reap` and `herdr-subagent-cap-check`. Exits 64 if cap is reached.
  - Fresh Session Receipt Generation ([lines 709-780](file:///root/bin/herdr-agent-start-fresh#L709-L780)): Generates `/tmp/herdr-fresh-session-receipts/<pane>.receipt` bound to the verified PID and command-line SHA256.

### 4.3 `herdr-send-submit`
- **File:** `/root/bin/herdr-send-submit`
- **Invariants & Gates:**
  1. **Pane State Gate ([lines 188-206](file:///root/bin/herdr-send-submit#L188-L206)):** Accepts only `idle` or `done` (where `interactive_ready == true`). Any `working` or `blocked` pane immediately exits 2.
  2. **Fresh-Session Receipt Gate ([lines 230-289](file:///root/bin/herdr-send-submit#L230-L289)):** For `agy`, `codex`, `warp`, and `senpi`, validates and atomically consumes the one-use fresh-session receipt. If missing or already consumed, exits 2.
  3. **Context Gate ([lines 316-370](file:///root/bin/herdr-send-submit#L316-L370)):** Hard stop at >= 80% (exit 2). Warning/handoff required at >= 70% unless it is a compaction continuation of the identical task file.
  4. **Continuity & Stale Session Gate ([lines 444-486](file:///root/bin/herdr-send-submit#L444-L486)):** Verifies proposed task against `$LAST_TASK` via `diff -q`. Mismatch exits 4. A previously used pane missing `$LAST_TASK` requires a verified `/new` reset receipt from `herdr-pane-reuse` (exit 4).
  5. **Artifact Gate ([lines 487-504](file:///root/bin/herdr-send-submit#L487-L504)):** When `--artifact` or `HERDR_ARTIFACT_REQUIRED=1` is specified, verifies artifact exists (>= 16 bytes) and performs a settling stability check over 0.2s. Unstable or missing artifact exits 5.
  6. **Independent-Verdict Gate ([lines 509-552](file:///root/bin/herdr-send-submit#L509-L552)):** If `INDEPENDENT_REVIEW_REQUIRED:` is present, requires `--independent-verdict <file>`. Requires `VERDICT: CHECK_PASS` and matching reviewer model (`REVIEWER_MODEL: glm-5.3`), else exits 6.
  7. **Check-In & Sentinel Gate ([lines 776-854](file:///root/bin/herdr-send-submit#L776-L854)):** Waits for `herdr-dispatch-ack`. If the worker fails to confirm a model turn or To-Do state within deadline, writes `/tmp/herdr-ack-fail/<pane>.json`, **removes `$LAST_TASK`** to block subsequent dispatches, and exits 7.

---

## 5. Bypass Surface Map & Vulnerability Analysis

```
+--------------------------------------------------------------------------------------------------+
|                                    BYPASS SURFACE TAXONOMY                                       |
+--------------------------+-----------------------+----------+------------------------------------+
| Surface                  | Component             | Severity | Description / Proof                |
+--------------------------+-----------------------+----------+------------------------------------+
| GAP-01: Direct PTY Pipe  | herdr CLI binary      | HIGH     | Raw send-text/send-keys skips all  |
|                          |                       |          | wrapper dispatch gates.            |
+--------------------------+-----------------------+----------+------------------------------------+
| GAP-02: State Collision  | agent-intent-guard    | HIGH     | Global un-namespaced coords file   |
|                          |                       |          | overwritten across concurrent runs |
+--------------------------+-----------------------+----------+------------------------------------+
| GAP-03: Ledger Parser    | agent-intent-guard    | HIGH     | Trailing text & negative denials   |
|                          |                       |          | added to allowed coordinate ledger |
+--------------------------+-----------------------+----------+------------------------------------+
| GAP-04: System Prompt    | 02-production-gate.ts | MEDIUM   | PRODUCTION_OVERRIDE token in       |
| Override                 | 01-model-firewall.ts  |          | prompt bypasses live checks.       |
+--------------------------+-----------------------+----------+------------------------------------+
| GAP-05: Redirection Regexp| 07-stale-claim-guard  | LOW      | Quotes around target in bash       |
|                          |                       |          | redirect defeat doc matching.      |
+--------------------------+-----------------------+----------+------------------------------------+
```

### 5.1 GAP-01: Raw `herdr pane send-text` / `send-keys` Path
- **Component:** `herdr` CLI (`/usr/local/bin/herdr`)
- **Severity:** HIGH
- **Proof & Citation:**
  - `herdr-send-submit` is an external wrapper script enforcing validation, continuity, artifact presence, and check-in.
  - The native daemon/CLI implements `herdr pane send-text <pane_id> <text>` and `herdr pane send-keys <pane_id> <keys>` directly into the pane PTY socket.
  - In `06-worker-pane-isolation.ts` ([lines 64-75](file:///root/.pi/agent/extensions/06-worker-pane-isolation.ts#L64-L75)), the hook only intercepts `herdr pane split`. It does not intercept `herdr pane send-text`.
  - In `herdr-send-submit` ([lines 717-719](file:///root/bin/herdr-send-submit#L717-L719)), raw Senpi dispatches explicitly fall back to `herdr pane send-text` and `herdr pane send-keys`.
  - **Risk:** Any process or subagent with shell execution authority can inject unvalidated prompts, bypass overlap locks, ignore compaction continuity, and bypass secret scanners by calling `herdr pane send-text` directly.

### 5.2 GAP-02: Coordinate Ledger Collision Across Concurrent Lanes
- **Component:** `/root/bin/agent-intent-guard`
- **Severity:** HIGH
- **Proof & Citation:**
  - In `agent-intent-guard` ([lines 12-14](file:///root/bin/agent-intent-guard#L12-L14) and [lines 183-189](file:///root/bin/agent-intent-guard#L183-L189)):
    ```bash
    agent="${agent//[^a-zA-Z0-9_-]/_}"
    state_dir="${TMPDIR:-/tmp}/agent-intent-guard"
    coords_file="$state_dir/coords.$agent"
    ```
  - In `herdr-send-submit` ([lines 566-573](file:///root/bin/herdr-send-submit#L566-L573)):
    ```bash
    intent_agents=(agy gemini antigravity)
    ```
    Every approved AGY dispatch loops through `(agy gemini antigravity)` and writes `coords.$agent`.
  - **Live Observation:** When `syssec-supplychain` dispatched, it ran `agent-intent-guard coords --agent antigravity ...`, overwriting `/tmp/agent-intent-guard/coords.antigravity`. When `syssec-agentsec` was executing, `coords.antigravity` contained the SUPPLYCHAIN coordinates (`.../SUPPLYCHAIN.md`), causing subsequent operations on `AGENTSEC.md` to trigger `SCOPE_DENY`.
  - **Risk:** Coordinates are not pane-isolated or process-isolated. Concurrent dispatches of the same agent kind clobber each other's coordinate ledgers.

### 5.3 GAP-03: Parser Ingestion of Negative Denials and Trailing Prose
- **Component:** `/root/bin/agent-intent-guard`
- **Severity:** HIGH
- **Proof & Citation:**
  - In `agent-intent-guard` ([lines 127-153](file:///root/bin/agent-intent-guard#L127-L153)):
    `extract_declared_paths()` scans the entire `WRITE_BOUNDARY:` block and extracts tokens starting with `/`.
  - Prompts conforming to `validate-herdr-lane-prompt` ([lines 292-304](file:///root/bin/validate-herdr-lane-prompt#L292-L304)) must explicitly enumerate denials:
    `WRITE_BOUNDARY: ALLOW: /target.md and /tmp only. You MUST NOT write to: /etc, /root/.ssh, /root/.secrets, /root/.pi, /root/.minimax.`
  - `extract_declared_paths()` extracts `/etc`, `/root/.ssh`, `/root/.secrets`, `/root/.pi`, and `/root/.minimax` as allowed coordinates!
  - **Live Verification:** Inspected `/tmp/agent-intent-guard/coords.antigravity`:
    ```text
    /etc
    /root/.local/bin
    /root/.minimax
    /root/.minimax-code
    /root/.pi
    /root/.secrets
    /root/.ssh
    /tmp only
    ```
    The forbidden paths `/etc`, `/root/.minimax`, `/root/.pi` were placed into the allowlist.
  - Furthermore, trailing prose such as `/tmp only` was preserved literally as `/tmp only`, causing legitimate operations on `/tmp/file` to fail prefix matching.

### 5.4 GAP-04: System Prompt Token Bypasses
- **Component:** `01-model-firewall.ts`, `02-production-gate.ts`
- **Severity:** MEDIUM
- **Proof & Citation:**
  - `02-production-gate.ts` ([lines 99-102](file:///root/.pi/agent/extensions/02-production-gate.ts#L99-L102), [line 150](file:///root/.pi/agent/extensions/02-production-gate.ts#L150)):
    ```ts
    if (sys.includes('PRODUCTION_OVERRIDE')) productionOverride = true;
    ...
    if (productionOverride) return undefined;
    ```
    If the system prompt contains `"PRODUCTION_OVERRIDE"`, all live SaaS and SSH write blocks are bypassed.
  - `01-model-firewall.ts` ([lines 32-37](file:///root/.pi/agent/extensions/01-model-firewall.ts#L32-L37), [lines 51-52](file:///root/.pi/agent/extensions/01-model-firewall.ts#L51-L52)):
    ```ts
    if (sysPrompt.includes('AUTHORIZE_ASTRA')) astraUnlocked = true;
    if (sysPrompt.includes('AUTHORIZE_SOL')) solUnlocked = true;
    ```
    If the system prompt contains `"AUTHORIZE_ASTRA"` or `"AUTHORIZE_SOL"`, quota-burn model restrictions are unlocked for the entire session.

### 5.5 GAP-05: Redirection Parsing Regex in `07-stale-claim-guard.ts`
- **Component:** `07-stale-claim-guard.ts`
- **Severity:** LOW
- **Proof & Citation:**
  - In `extractDocTargetAndContent` ([07-stale-claim-guard.ts:192-200](file:///root/.pi/agent/extensions/07-stale-claim-guard.ts#L192-L200)):
    ```ts
    const redirectMatch = command.match(/(?:>|>>|tee\s+(?:-a\s+)?)\s*([^\s;&|]+\.md)/);
    ```
  - If quotes are placed around the target path (e.g. `echo "..." > "BOARD.md"`), `redirectMatch[1]` captures `"BOARD.md` (with leading quote).
  - In `isGuardedDoc` ([07-stale-claim-guard.ts:18-23](file:///root/.pi/agent/extensions/07-stale-claim-guard.ts#L18-L23)), the pattern `/(^|\/)(BOARD|CONTROLLER_STATE|IDENTITY)\.md$/i` fails to match `"BOARD.md` because `^` does not match after `"`.
  - While `write` and `edit` tools are safely evaluated, quoted bash redirection can bypass the claim check.

---

## 6. Recommendations & Remediation Plan

1. **Scoped Coordinate Ledgers:**
   Modify `agent-intent-guard` to namespace state files by pane or session ID (e.g. `coords.$pane_id.$agent`) rather than a single shared `$agent` file.
2. **Denial-Aware Coordinate Extraction:**
   Update `extract_declared_paths()` in `agent-intent-guard` to parse only the `ALLOW:` clause and discard anything following `You MUST NOT write to:` or `DENY:`. Strip trailing words (`only`, `scratch`, `config`, `as needed`).
3. **PTY Enforcement Hook:**
   Extend `06-worker-pane-isolation.ts` (or implement a `herdr-send-guard` extension) to intercept direct `herdr pane send-text` commands that do not originate from an approved dispatcher like `herdr-send-submit` or `herdr-review-send`.
4. **Redirection Regex Normalization:**
   In `07-stale-claim-guard.ts`, strip leading and trailing quotes (`['"]`) from captured path tokens before checking `isGuardedDoc()`.

---

## 7. Audit Conclusion

The agent guard chain is **fundamentally robust, deterministic, and fail-closed** across its primary runtime paths. The financial spend gate (`00-spend-gate.ts`), model cutoff gate (`01-model-firewall.ts`), prompt validation contract (`validate-herdr-lane-prompt`), and submission pipeline (`herdr-send-submit`) reliably enforce safety invariants. Test suites pass with zero failures. The identified gaps (GAP-01 through GAP-05) are documented above with exact file:line citations for remediation.
