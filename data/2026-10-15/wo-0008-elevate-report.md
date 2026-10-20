# WO-0008 lane 3 — AnythingLLM workspace repair

## Scope and method

Only unauthenticated HTTP GET requests were sent to `https://agents.elevatesci.com`; no requests were sent to `elevatesci.com`, and no direct-host or app-directory access was attempted. No application, workspace, route, credential, or production changes were made. The evidence below does **not** establish that `agents.elevatesci.com` is a staging-only endpoint; staging ownership/routing remains unverified.

## Before

Measured 2026-10-15 UTC before any attempted repair:

| Fact | Measured result | Evidence |
|---|---|---|
| `GET https://agents.elevatesci.com/` | HTTP 200, `text/html; charset=utf-8`, 1,926 bytes; body includes `<title >AnythingLLM | Your personal LLM trained on anything</title>` | `curl -sS -L --max-time 20 -D - -o /dev/null https://agents.elevatesci.com/`; response headers showed `HTTP/2 200`. A body GET returned the quoted title. |
| `GET /api/health` | HTTP 200, `text/html; charset=utf-8`; body is the same 1,926-byte AnythingLLM HTML shell | `curl -i https://agents.elevatesci.com/api/health` returned `HTTP/2 200` and the HTML shell. |
| `GET /api/embed` | HTTP 200, `text/html; charset=utf-8`; body is the same 1,926-byte AnythingLLM HTML shell | `curl -i https://agents.elevatesci.com/api/embed` returned `HTTP/2 200` and the HTML shell. |
| `GET /api/v1/workspaces` without an API key | HTTP 403, `application/json`; body `{"error":"No valid api key found."}` | `curl -i https://agents.elevatesci.com/api/v1/workspaces`. No workspace records were disclosed. |
| Staging-only identity / workspace contents | UNVERIFIED | Public responses do not identify the backing host or prove staging isolation; workspace listing requires an API key. |

## After

Re-measured 2026-10-15 UTC after diagnosis. No repair could be applied, so this is a no-change remeasurement:

| Same fact | Measured result | Evidence |
|---|---|---|
| `GET https://agents.elevatesci.com/` | HTTP 200, `text/html; charset=utf-8`, 1,926 bytes | `curl -sS --max-time 15 -o /dev/null -w ... https://agents.elevatesci.com/` printed `HTTP=200 TYPE=text/html; charset=utf-8 BYTES=1926`. |
| `GET /api/health` | HTTP 200, `text/html; charset=utf-8`, 1,926 bytes | Same remeasurement printed `HTTP=200 TYPE=text/html; charset=utf-8 BYTES=1926`. |
| `GET /api/embed` | HTTP 200, `text/html; charset=utf-8`, 1,926 bytes | Same remeasurement printed `HTTP=200 TYPE=text/html; charset=utf-8 BYTES=1926`. |
| `GET /api/v1/workspaces` without an API key | HTTP 403, `application/json`, 35 bytes; body `{"error":"No valid api key found."}` | Same remeasurement printed `HTTP=403 TYPE=application/json BYTES=35`; body GET returned the quoted JSON. |
| Staging-only identity / workspace contents | UNVERIFIED | No changed evidence; the API still denies access without a key, and endpoint-to-staging mapping remains unproven. |

The workspace repair is **blocked**: the workspace API rejects unauthenticated access, and the available evidence does not prove this endpoint is staging-only. No existing credential was located or used, no credential was created, and no writes were attempted. Exact next requirement: an authorized staging endpoint identity plus access to an already-approved API key (or an operator-provided authenticated path) so workspace state can be inspected and repaired without crossing the production boundary.

VERDICT: BLOCKED — before and after measurements are unchanged; workspace state and staging-only identity remain UNVERIFIED, so no repair is claimed.
