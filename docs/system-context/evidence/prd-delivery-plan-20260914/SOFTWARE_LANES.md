# Brandon software delivery lanes — 2026-09-14

## Executive decision

The active source-backed ticket is `BR-ELEVATE-OPS-001`. Its missing provider
adapter is implementation work, not a reason to stop: build it locally with an
injectable transport and mock tests. Real provider keys, provider calls, live
control-plane mutation, VPS writes, and deployment remain separate gates.

Baseline evidence:

- `agents-dashboard-source/` is the canonical Core-Distro console source.
- Local tests pass: adapter contract `23/23`, metric states `59/59`, Phase-4
  controls `70/70`, upstream PHP shape `37/37`.
- `BR-ELEVATE-OPS-001` remains `BLOCKED_AUTHORIZATION` for live/provider work;
  `local-dashboard-adapter-20260914/local-adapter-contract.md` is explicitly
  `SPECIFICATION_ONLY`.

## Lane plan

| Order | Lane / real source | Disjoint write boundary | Acceptance | Dependency and status |
|---|---|---|---|---|
| 1 | **Server-side provider adapter** — `BR-ELEVATE-OPS-001`; implementation choice: a new isolated module beside `agents-dashboard-source/backend/agents_dashboard_json.php`, with tests under `agents-dashboard-source/tests/` | New adapter module plus injectable transport and mock fixtures; do not change the existing read-only PHP endpoint into a provider caller; no real key reads or live calls | Mock tests cover OpenAI and MiniMax M3 selection, request normalization, missing-credential and timeout/error mapping, `CONTROL_PLANE_LLM_ENABLED=false`, and no credential leakage; existing 166 assertions remain green | Backend path is an engineering decision grounded in the existing PHP backend contract; exact module/interface is selected by the implementer. Live provider authority remains separate. |
| 2 | **Frontend provider selector and states** — `BR-ELEVATE-OPS-001`; `agents-dashboard-source/frontend/agentic-dashboard-v2.html` plus focused tests under `agents-dashboard-source/tests/` | Frontend staging copy only; wire provider/model selection and loading/error/disabled states to Lane 1's agreed interface; preserve Elevate branding and rollback package; no remote file edit | 166/166 baseline remains green; exact 10 tab IDs, read-only `/api/*` contract, sidebar/card reconciliation, branding/age/research-use invariants, and fail-closed mutation/LLM guards remain intact; mock UI tests cover unavailable, selected, timeout, and locked states | Depends on Lane 1's interface contract. Local staging only; `/home/user/htdocs/srv1137994.hstgr.cloud/agentic-dashboard-v2.html` and its rollback bundle remain remote evidence, not write targets. |
| 3 | **Independent integration/browser QA and release owner** — `BR-ELEVATE-OPS-001` acceptance chain; existing `tests/test_sidebar_drawer_and_persistence.mjs`, static suites, and accepted Elevate release evidence | Read-only QA artifacts, screenshots/logs/checksums, and release recommendation; no source edits during verification and no deployment | Run static suites plus browser matrix against a local/staged mock backend; verify provider selector states, mutation gates, branding, API failures, rollback checksum, UTF-8, and clean scans; independent reviewer returns `CHECK_PASS` before release recommendation | Starts after Lanes 1–2. Codex is integration/release owner and reconciles evidence; no live release until separately authorized. |

## Dependency order and integration owner

1. Lane 1 defines and implements the backend interface with injectable mocks.
2. Lane 2 consumes that interface in the frontend staging copy.
3. Lane 3 independently tests the combined local/staged result and owns the
   release recommendation; Codex reconciles artifacts and evidence.

## Remote compute and access boundary

`brandon-compute` is a supporting remote prerequisite for the campaign, not an
automatic controller fallback. Before any remote build/rehearsal or inference
task, provision/verify the complete allowlisted remote secondmate home/worker
pack; do not place arbitrary individual files in a remote worker directory.
Then verify Brandon-only target identity, Tailscale route, resource fingerprint,
listener ownership, and write boundary. Locally hosted models remain inference
workloads, not coding agents. A working Tailscale admin route/account is an
**access** prerequisite; separate operator authority for a live mutation is an
**authorization** prerequisite. Missing route/account is `BLOCKED_ACCESS`;
missing approval for live mutation is `BLOCKED_AUTHORIZATION`. The 168-hour
SSH/access interval does not itself grant engineering or deployment authority.

## Explicit non-actions

No SSH, Tailscale, deployment, DNS/TLS, cPanel, database, firewall, provider
API, real credential, model download, remote worker placement, or production
mutation is part of this plan.
