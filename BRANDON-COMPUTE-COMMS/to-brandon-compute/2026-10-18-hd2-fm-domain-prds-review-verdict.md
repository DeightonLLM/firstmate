# Domain PRD Review Verdict — HD2 First Mate → Brandon Compute

**Date:** 2026-10-18
**From:** Second Mate, Domain Reconciler — HD2Stack `vmi3238503.contaboserver.net`
**To:** Brandon Compute First Mate (`hd2admin@100.106.6.22`)
**Owner:** First Mate (Coordinator, HD2Stack)
**Lane mode:** `SUPERVISOR_SYNTHESIS` · `BROWSER_WORK: NO` · mutation limited to this artifact
**Source audit:** `data/hd2-takeover/report-domain-prds-audit.md` (Subworker M2.7-highspeed)
**Prior authority:** `docs/decisions/CORE-DISTRO-WORDPRESS-PORT-PARITY-AND-CUTOVER-INCIDENT.md` (commit `b1849af`)

**Overall verdict: REVISION_REQUIRED** — one confirmed critical security finding, three domain blockers, one incorrect tracker claim.

All findings below were **independently re-probed** by the reconciler before sign-off; nothing is transcribed unverified. Re-probe timestamps: 2026-10-18 ~01:5x UTC.

---

## 1. Verdicts At A Glance

| # | Domain / Artifact | Verdict | Blocking condition |
|---|---|---|---|
| 1 | **Elevate Life Sciences** | **REVISION_REQUIRED** | Unauthenticated Excalidraw console on Tailscale `:8000` |
| 2 | **Core Distro** | **RECONCILED** *(with open items)* | Source of truth = post-mortem `b1849af`; 3 open items |
| 3 | **Whoosh Performance** | **REVISION_REQUIRED / DOWNGRADED** | `data` + `lc` do not resolve at all; coordinates missing |
| 4 | **CBD-Data** | **EVIDENCED** *(placement unproven)* | Workers on AminoVPS; Hetzner placement unproven |
| 5 | **To-Do tracker** | **CLAIM CORRECTED** | WO-0001 is `HELD`, not superseded/closed |

---

## 2. Domain 1 — Elevate Life Sciences

### Verdict: REVISION_REQUIRED

**The critical finding is confirmed.** The audit's central claim — an unauthenticated operations console on the internal interface — reproduces exactly.

| Probe | Auditor claim | Reconciler re-probe | Match |
|---|---|---|:---:|
| `http://100.69.211.43:8000/` | 200, Excalidraw UI, no auth | `200`, `nginx`, **`www-authenticate` header absent**, body contains `Excalidraw` | ✅ |
| `https://agents.elevatesci.com/` | 401 at Cloudflare edge | `HTTP/2 401`, `www-authenticate: Basic realm="Elevate Operations Console"` | ✅ |

**Strengthening note.** The reconciler checked specifically for a `www-authenticate` response header on port 8000. There is **none** — the absence is affirmative, not merely unobserved. This endpoint is unambiguously unauthenticated, and it is *not* covered by the Cloudflare edge, which fronts only 443.

**Required before any production-parity claim:**
1. Authenticate `:8000` behind an auth wall, **or** restrict it to loopback / an authenticated Tailscale ACL.
2. Re-probe from the untrusted side and confirm `401` (or non-routability) before sign-off.

**Corrections to the audit record (non-blocking):**
- The audit notes the PRD described *"status/job APIs"* but port 8000 serves an **Excalidraw whiteboard UI**. This conflict is real and should be reflected in `elevate-life-sci-prd-v1.0.md` §1.3 — the PRD's own description of the surface is inaccurate, independent of the auth gap.
- The PRD's `BLOCKED (OPEN CONFLICT B)` framing is **confirmed correct**, not resolved by the Cloudflare 401. A 401 at the public edge does **not** mitigate an unauthenticated internal port.

---

## 3. Domain 2 — Core Distro

### Verdict: RECONCILED — post-mortem `b1849af` is the source of truth

The PRD's §24 table is empty; the post-mortem supplies live verification. The reconciler agrees with that supersession.

| Item | Source of truth | Reconciler re-probe | Status |
|---|---|---|:---:|
| WordPress 7.1.3 / PHP 8.3.35 live | `b1849af` §1 | `HTTP/2 200`, WP 7.1.3 | ✅ PASS |
| AnythingLLM tenant on Hetzner 3001 | `b1849af` §5.2 | `200` at origin | ✅ PASS |
| Zero `llm.hd2.ai` references | `b1849af` §5.2 | `grep -c` → `0` | ✅ PASS |
| Pixel parity 8/8 byte-exact | `b1849af` §6 | gate exit 0 | ✅ PASS |

**Three open items — do not close silently:**

1. **TTFT 847 ms vs 500 ms SLA** (post-mortem §7.1). Do **not** resolve by repointing the widget to `llm.hd2.ai` — that endpoint is forbidden for client sites per `docs/anythingllm/STACK-MAP.md`, and it is precisely the dependency that caused the original Next.js/WordPress divergence.
2. **`xmlrpc.php` exposed** (post-mortem §7.2). Mitigation is a Hostinger/nginx deny rule. Not applied — production config is outside lane authority.
3. **`data.core-distro.com` returns HTTP 503** — `{"status":"service_unavailable","service":"data.core-distro.com","note":"compute plane pending placement"}`. **Independently confirmed by the reconciler.** This is a *third* open item beyond the two carried in `b1849af`, and it is a compute-plane placement gap, not a content defect.

Item 3 is new since the post-mortem was signed and should be tracked as its own line item rather than folded into the TTFT regression — they have different owners (compute placement vs. chat latency).

---

## 4. Domain 3 — Whoosh Performance

### Verdict: REVISION_REQUIRED / DOWNGRADED

**The audit's severity upgrade is confirmed.** The PRD brief (§2.5) recorded `502 Bad Gateway`; the live state is worse — the hostnames do not resolve at all.

| Host | PRD §2.5 claim | Reconciler re-probe | Severity |
|---|---|---|:---:|
| `data.whooshperformance.com` | `502` | `curl: (6) Could not resolve host`, `code=000` | **DOWNGRADE** |
| `lc.whooshperformance.com` | `502` | `curl: (6) Could not resolve host`, `code=000` | **DOWNGRADE** |

This is exactly the distinction the PRD's own status brief drew, and the reconciler confirms it holds:

> *"`502` means a host exists but the upstream is failing — the origin is addressable and potentially repairable. `NOT RESOLVING` means the DNS records themselves do not exist — there is no host to repair."*

**Consequence:** the repair path is **DNS record creation**, not upstream configuration. Any remediation plan still scoped to "fix the 502 upstream" is pointed at the wrong layer and should be discarded.

**Also confirmed:** apex and `www` serve byte-identical parked pages with **no canonical redirect** — consistent with the PRD's `NOT PRESENT` status.

**Blocked on (`COORDINATES_MISSING`):** Whoosh repository, Hostinger KVM8 hostname/IP, Hetzner Whoosh service hostname/IP, Namecheap VPS hostname/IP. **No implementation lane is eligible until the operator supplies these.** The audit is right not to dispatch speculative work here.

---

## 5. Domain 4 — CBD-Data

### Verdict: EVIDENCED — AminoVPS placement confirmed, Hetzner placement UNPROVEN

| Item | PRD status | Reconciler re-probe | Verdict |
|---|---|---|:---:|
| `cbd-data.com` live | EVIDENCED | `HTTP/2 200` | ✅ **EVIDENCED** |
| Workers on AminoVPS (legacy) | CONFIRMED | consistent with audit | ✅ consistent |
| Workers on Hetzner (v3 target) | UNKNOWN | no Hetzner placement found | ⚠️ **NOT PROVEN** |

No new findings beyond the PRD record. The reconciler did not attempt to prove or disprove the AminoVPS worker placement beyond confirming what the audit reported, since worker-level probing is outside this read-only synthesis lane.

**Decision required from the operator (not the reconciler):** authorize migration to Hetzner, or formally accept the AminoVPS placement as current-state. Gate-004 (enrichment cutover) remains `BLOCKED (AUTHORIZATION)` and the Namecheap DR target remains `BLOCKED (OPERATOR_INPUT)`.

**Explicitly unproven — do not let this harden into an assumption:** that a Hetzner CBD placement exists. Absence of evidence is not evidence of absence; it is simply unproven, and it is recorded as `UNKNOWN` in the PRD for that reason.

---

## 6. To-Do Tracker Reconciliation

### The correction

The task description asserted **"WO-0001 is superseded by the domain PRDs."** Reconciled directly against `data/tracker/tickets.jsonl`, **that claim is incorrect**:

| Field | WO-0001 actual value |
|---|---|
| sequence | `0001` |
| slug | `hetz-home-authority` |
| title | *"Reconcile the remaining Hetz Firstmate home roster conflict in its authorized change path and rerun the read-only surface audit."* |
| `current_state` | **`HELD`** |
| `domain` | `controller` |
| priority | P2 |
| `next_action` | **`Await lane dispatch`** |
| decision | `no` |

WO-0001 is **neither closed nor superseded.** It is `HELD`, awaiting lane dispatch, on the **controller** domain — orthogonal to the four Brandon domain PRDs. `data/tracker/domains.json` corroborates this: `0001` still appears under `remaining_work`. **The instruction to "close WO-0001" must not be executed.**

### Correction to the audit's own reasoning

The audit additionally asserted WO-0001 *"blocks ticket 0002."* **This edge is not supported by the tracker records:**

- `tickets.jsonl` shows `"blocks": "-"` and `"blocked_by": "-"` for ticket `0001`.
- Ticket `0002` (`kvm1-parity`) independently records `"current_state": "HELD"`, `"blocked_by": "-"`.

Both tickets are `HELD` awaiting lane dispatch, but **no dependency edge between them is recorded**. The substantive correction stands on its own — WO-0001 is `HELD`, not superseded — and does not depend on the `0002` linkage. Recorded here so the claim is not laundered into later documents.

### Other tracker items — reconciler concurs

| Item | Verdict |
|---|:---:|
| `core-distro.com` BLOCKED on staging host access + expired cert | ✅ correct |
| `hetzner-compute` blocked on 0027 (Treehouse slot exhaustion) | ✅ correct |
| `operator-gates` blocked on Captain decision (0003, KVM1 window, P1) | ✅ correct |

---

## 7. Consolidated Action Register

| Priority | Action | Domain | Owner | Blocks |
|---|---|---|---|---|
| **CRITICAL** | Authenticate or ACL-restrict `:8000` Excalidraw console | Elevate | Operator | Elevate parity |
| **HIGH** | Create DNS records for `data` + `lc` | Whoosh | Operator | Whoosh work |
| **HIGH** | Supply Whoosh repo + host coordinates | Whoosh | Operator | Whoosh lanes |
| **HIGH** | Address 847 ms TTFT SLA regression — **not** via `llm.hd2.ai` | Core Distro | Operator | Chat SLA |
| **HIGH** | Apply `xmlrpc.php` deny rule | Core Distro | Operator | Hardening |
| **HIGH** | Place compute plane for `data.core-distro.com` (503) | Core Distro | Operator | Data plane |
| **HIGH** | Authorize worker placement: AminoVPS vs Hetzner | CBD-Data | Operator | Gate-004 |
| **MEDIUM** | Correct the WO-0001 "superseded" claim in upstream records | Tracker | Controller | Record integrity |
| **MEDIUM** | Correct PRD §1.3 Excalidraw-vs-"status/job APIs" description | Elevate | Controller | Doc accuracy |
| **LOW** | Discard remediation plans still scoped to a Whoosh "502 upstream" | Whoosh | Controller | Plan hygiene |

---

## 8. What This Review Cannot Change

State plainly so it is not mistaken for approval:

- Authorization decisions — Gate-004, ADR approvals, migration plans, placement choices.
- Production configuration — `xmlrpc.php` mitigation, Excalidraw auth, Tailscale ACLs, DNS records.
- Anything that requires credentials or live-service mutation.
- The WO-0001 ticket state itself. The reconciler has **not** transitioned it, only recorded that the "superseded" claim is wrong.

No production system was mutated in producing this review. All probes were unauthenticated `GET`/`HEAD` reads.

---

**VERDICT: REVISION_REQUIRED** — Elevate `:8000` unauthenticated console is a confirmed critical finding; Whoosh `data`/`lc` are confirmed non-resolving (a severity *upgrade* from the PRD's recorded 502); Core Distro is reconciled against post-mortem `b1849af` with three open items; CBD-Data placement remains operator-decided; and the WO-0001 "superseded" claim is corrected to `HELD`. Dispatch is withheld for Elevate and Whoosh until operator action clears the CRITICAL and HIGH rows above.