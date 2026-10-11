# CBD Worker/Canary — Roadmap Blocker Reconciliation

**Artifact:** `cbd-worker-canary-roadmap-reconciliation_20260802.md`  
**Date:** 2026-08-02  
**Scope:** Reconcile all known CBD worker/canary blockers; park only the exact external dependency; identify the single next independently verifiable readiness step.  
**Constraints honored:** Read-only evidence pass; no AminoVPS retry; no deploys; no credential writes.

---

## 1. Blocker Summary

| ID | Subject | Status | Evidence |
|---|---|---|---|
| M1 | Gate-file SHA | ✅ **RESOLVED** | `CBD_PRE_CANARY_STATIC_BASELINE_CLOSEOUT_20260730.md` §2 |
| M5 | HTTP 503 routes | ✅ **RESOLVED** | Same doc, §3 — 8/8 routes return 503 |
| M6 | Decision ledger | ✅ **RESOLVED** | `CBD_M6_DECISION_LEDGER_CLOSEOUT_20260730.md` |
| Core-Distro | `durable_scrape_worker.php` | ✅ **RESOLVED** | SHA exact-match; 404 lockdown confirmed |
| **M4** | **`cbd_worker.py` on AminoVPS** | 🔴 **BLOCKED** | SSH/Tailscale access not available non-interactively |
| **LVE** | **Resource proof via cPanel** | 🔴 **BLOCKED** | UAPI `ResourceUsage`/`Stats` unsupported on `server401.web-hosting.com` |

---

## 2. Exact External Dependency Blocker

**Blocker: `AMINOVPS_ACCESS_UNAVAILABLE`**

- **Host:** `srv1137994` — Hostinger KVM 8 (AminoVPS), IP `100.69.211.43`
- **Asset:** `cbd_worker.py` (Python worker binary)
- **Baseline SHA recorded:** `5b8cde74ad103bab1623b2132697cc6b446395b09abd97cb762db469e89d02c4`
- **Current state (attested 2026-07-31):** `/etc/cbd-worker/disabled` + `/run/cbd-worker/disabled` present; `cbd-worker.service` inactive
- **Access method tried:** Tailscale SSH — interactive auth required; non-interactive SSH unavailable
- **Prior successful access:** 2026-08-01T22:10Z via Tailscale SSH (bounded canary cycle, `CBD_EXACT_CANARY_FULLY_CLOSED`); subsequent re-access has failed
- **Constraint applied:** AminoVPS access not retried per brief instruction

**Why this is the exact external blocker:** All other gates (M1, M5, M6, Core-Distro worker, CBD endpoint canonicalization) are controller-local and have been resolved. The `cbd_worker.py` on the remote VPS is the only remaining uninspectable component. No local preparation can advance it — it requires either operator-provided non-interactive SSH credentials, a manual operator check, or a future re-authorization window for the Tailscale interactive session.

---

## 3. Supplemental Blocker

**LVE Resource Proof:** cPanel UAPI `ResourceUsage` and `Stats` return status 0 on `server401.web-hosting.com` — module unsupported. This is an infrastructure constraint, not a code issue. No guarded-helper path exists. Operator waiver or an alternative verification method (e.g., manual cPanel screenshot) is required.

---

## 4. Canonical State Already Achieved

The following are confirmed clean, requiring no further action:

- CBD endpoint `cbd_worker_endpoint.php` — SHA canonical match, valid JSON, 503 containment on all workload routes
- Integration gate `.cbd-workload-disabled` — present, production integration **disabled**
- Kill-switch markers `.cbd-legacy-routes-disabled`, `.cbd-workload-disabled` — both SHA-verified
- Decision ledger `CONTROLLER_OPS_DECISIONS_20260730_CBD.md` — approved D1–D5; D6 deferred
- Canary exact-ID cycle — **fully closed** 2026-08-01T22:10Z (`CBD_EXACT_CANARY_FULLY_CLOSED`)
- Durable worker `durable_scrape_worker.php` on Core-Distro — SHA exact match, 404 lockdown, cron active

---

## 5. Next Independently Verifiable Readiness Step

**Single next step (no AminoVPS access required, no operator gate required for execution):**

> **Verify `cbd_worker_endpoint.php` containment posture remains intact** — re-confirm all 8 CBD workload routes return HTTP 503 and the `.cbd-workload-disabled` marker is still in place.

**Why this is the next step:** The endpoint is the controller-local, externally accessible surface of the CBD system. A single `curl` sweep of the 8 known CBD routes (`cron_drip.php`, `hist_worker.php`, `webhook_scrape.php`, `cbd_hist_worker.php`, `maps_proxy.php`, `api_wrapper.php`, `leadlists.php?action=fireAllScrapes`, `dashboard.php?action=fireAllScrapes`) and a SHA check of the two gate markers can be performed entirely from the controller without any AminoVPS access or operator authorization. This is a bounded, independently verifiable read-only action.

**If containment is confirmed intact:** The CBD canary is in a safe parked state. The only path to further advancement requires AminoVPS re-access (M4 unblocked) or an LVE waiver (supplemental blocker resolved).

---

## 6. Authorization Required to Advance Past Blocker

| Action | Authorization Required | Owner |
|---|---|---|
| AminoVPS `cbd_worker.py` inspection/restart | Operator explicit non-interactive SSH or Tailscale re-auth | Operator |
| LVE resource proof waiver | Operator waiver or manual cPanel screenshot | Operator |

---

*Artifact: `cbd-worker-canary-roadmap-reconciliation_20260802.md` | Agent: codex | Host: /root/agent-work | Read-only evidence pass | No mutations performed*
