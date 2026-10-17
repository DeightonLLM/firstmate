# Whoosh Performance — Domain PRD Status Brief

**Domain:** `whooshperformance.com`
**Date:** 2026-10-18
**PRD this derives from:** `whoosh-performance-wp-data-outreach-prd-v1.0.md` (authoritative; 1616 lines)
**House template:** `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (v3.0, 2026-08-04)
**Status verdict:** BLOCKED — coordinates missing; no eligible implementation lane exists.

---

## 0. Status Header

| Field | Value |
|---|---|
| Domain | `whooshperformance.com` |
| Authoritative PRD | `data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md` (v1.0, 2026-10-17) |
| Project code | `whoosh` |
| Current measured state | Parked domain on Hostinger DNS; data/lc subdomains do not resolve; no WordPress, no data service, no Aspire evidence |
| PRD-v3 placement | Project 3 of 4 in Phase 5 rollout order (after Core Distro, Elevate) |
| Domain status | BLOCKED — `COORDINATES_MISSING` per PRD_TRACEABILITY.md |
| Bot routing status | UNKNOWN — do not claim completion without accepted artifact |
| Phase 0 eligibility | NOT ELIGIBLE — Gates A–E cannot open without coordinates |

---

## 1. Current State

### Status table (source-grounded, not estimated)

| Item | Status | Source | Blocker / Notes |
|---|---|---|---|
| `whoosh-audit` | `BLOCKED` | `PRD_TRACEABILITY.md` — `whoosh-audit` row; `PRD_DELIVERY_MAP.md` unresolved area 1 | `COORDINATES_MISSING` — exact repository, hosting, runtime, production IP required |
| `whoosh-bot-routing` | `UNKNOWN` | `PRD_TRACEABILITY.md` — `whoosh-bot-routing` row; task acceptance rule 7 | No accepted artifact for routing completion; do not claim Brandon bot routing is complete |
| `whoosh-service` (SERVICE_CATALOG) | `BLOCKED` | `SERVICE_CATALOG.md` — `whoosh-service` record | `COORDINATES_MISSING` |
| `whoosh-runtime` (HOSTS) | `BLOCKED` | `HOSTS.md` — `whoosh-runtime` record; `PRD_DELIVERY_MAP.md` unresolved area 1 | `COORDINATES_MISSING`; last verified 2026-09-12 |
| Domain apex (`whooshperformance.com`) | EVIDENCED | External measurement 2026-10-18 | HTTP 200 serving Hostinger PARKED DOMAIN page |
| `www` hostname | EVIDENCED | External measurement 2026-10-18 | HTTP 200 serving Hostinger PARKED DOMAIN page; byte-identical to apex (md5 f474cd3131bc962cb57256dab5741d34) |
| Canonical redirect (apex↔www) | NOT PRESENT | External measurement 2026-10-18 | No 301/302 redirect; plain HTTP returns 200 with no HTTPS redirect |
| `data.whooshperformance.com` | NOT RESOLVING | External measurement 2026-10-18 | DNS resolution fails (curl exit, no HTTP response); **discrepancy with v1.0 §2.5** |
| `lc.whooshperformance.com` | NOT RESOLVING | External measurement 2026-10-18 | DNS resolution fails (curl exit, no HTTP response); **discrepancy with v1.0 §2.5** |
| WordPress site | NOT PRESENT | External measurement 2026-10-18 | No WordPress stack evidenced; parked page only |
| Whoosh repository | UNKNOWN | No source | Required by Gates A–E; not in `projects/` evidence |
| Whoosh Hostinger KVM8 host | UNKNOWN | No source | Required by Gates A–E; `whoosh-runtime` record is BLOCKED |
| Whoosh Hetzner services | UNKNOWN | No source | Required by Gates A–E; no evidence surfaced |
| Whoosh Namecheap backup | UNKNOWN | No source | Required by v1.0 §7.3; no coordinates |
| `info@whooshperformance.com` inbox | UNKNOWN | No source | Required notification target; not verified |
| Namecheap DR target classification | UNKNOWN | No source | Required Gate B; `bdn-dr-whoosh-01` named in PRD v3 but not evidenced |

---

## 2. What Is Actually Proven vs What Is Not

### Actually proven

| Claim | Evidence | Source |
|---|---|---|
| `whooshperformance.com` resolves to Hostinger and serves a parked-domain page | HTTP 200, page title "Parked Domain name on Hostinger DNS system" | External measurement 2026-10-18 |
| `www.whooshperformance.com` is byte-identical to apex (no canonical redirect) | md5 f474cd3131bc962cb57256dab5741d34 | External measurement 2026-10-18 |
| No HTTPS redirect on plain HTTP | HTTP 200, not 301→HTTPS | External measurement 2026-10-18 |
| `data.whooshperformance.com` does not resolve | DNS: curl exit, no HTTP response | External measurement 2026-10-18 |
| `lc.whooshperformance.com` does not resolve | DNS: curl exit, no HTTP response | External measurement 2026-10-18 |
| `whoosh-audit` is blocked by missing coordinates | `BLOCKED`/`COORDINATES_MISSING` | `PRD_TRACEABILITY.md`, `PRD_DELIVERY_MAP.md` unresolved area 1 |
| `whoosh-bot-routing` is not proven complete | Status `UNKNOWN`; task acceptance rule 7 | `PRD_TRACEABILITY.md` |

### Not proven (and cannot be assumed)

- No WordPress stack is running or deployed
- No data service is running at `data.whooshperformance.com`
- No Aspire cold-email service is evidenced
- No repository, host IP, runtime, or credentials exist for Whoosh
- No backup, monitoring, or operational infrastructure exists
- No DNS A/CNAME records for `data` or `lc` subdomains
- No gate from v1.0 or PRD v3 is passed

### v1.0 §2.5 discrepancy — must be recorded, not silently overwritten

v1.0 §2.5 (written 2026-10-17) states:

> `data.whooshperformance.com` returned `502 Bad Gateway` over HTTPS.
> `lc.whooshperformance.com` returned `502 Bad Gateway` over HTTPS.

External measurement on 2026-10-18 shows:

> `data.whooshperformance.com` does NOT RESOLVE (curl exit, no HTTP response at all)
> `lc.whooshperformance.com` does NOT RESOLVE (curl exit, no HTTP response at all)

**The discrepancy matters.** A `502` means a host exists but the upstream is failing — the origin is addressable and potentially repairable. `NOT RESOLVING` means the DNS records themselves do not exist — there is no host to repair, no upstream to investigate, and the repair path is DNS record creation, not upstream configuration.

Both observations may be true at different times; however, the current measured state (2026-10-18) is **non-resolving**, and this brief records that state as authoritative for its date. The v1.0 text is preserved unchanged. Resolution of the discrepancy requires fresh measurement with a timestamp and the specific DNS method used.

---

## 3. Scope

What this domain includes, per v1.0 and PRD v3:

- WordPress conversion of the approved Whoosh static site on `whooshperformance.com`
- Hostinger KVM8 as the public/control plane for WordPress
- Hetzner dedicated server as the data compute plane for `data.whooshperformance.com`
- Aspire cold-email service at `lc.whooshperformance.com`
- Namecheap VPS as encrypted backup/DR target (`bdn-dr-whoosh-01`)
- `info@whooshperformance.com` as the operational notification target
- Four social platforms (Instagram, Facebook, X/Twitter, LinkedIn) asset package via Sawar
- Isolated project namespace per PRD v3 §§6–8 (queues, files, database roles, Qdrant collections)

---

## 4. Non-Goals

What v1.0 explicitly excludes (and this brief does not add):

- Full rebranding or full redesign
- Figma deliverables
- E-commerce, customer portals, memberships, subscriptions
- New CRM or replacement of Aspire
- Social account administration or posting
- Kubernetes
- Moving compute-heavy scraping onto Hostinger or public WordPress onto Hetzner
- Public exposure of databases, queues, or management tools
- Storing secrets in Git, chat, screenshots, or this document

---

## 5. Open Blockers

### 5.1 Named blockers (must clear before any implementation)

| Blocker | What unblocks it | Who owns it |
|---|---|---|
| `COORDINATES_MISSING` — exact repository, hosting, runtime, and production IP for Whoosh are unknown | Operator supplies: repository URL, Hostinger KVM8 hostname/IP, Hetzner Whoosh service hostname/IP, Namecheap VPS hostname/IP, and production IP for `whooshperformance.com` | **Captain / operator** — per PRD_DELIVERY_MAP.md unresolved area 1 |
| `whoosh-audit` blocked — Gates A–E cannot open | Coordinates + discovery work by Saad | **Saad** (once coordinates provided) |
| `BR-ARCH-001` placement cannot close | `whoosh-audit` must complete first | **Saad / Captain** |
| `BR-GATE-001` Eric/Dubz approval cannot close | `BR-ARCH-001` must complete first | **Eric and Dubz** |
| `whoosh-bot-routing` — no accepted artifact | Separate accepted routing task artifact required | **Captain / operator** |

### 5.2 Discrepancy resolution needed

| Item | What is needed | Who owns it |
|---|---|---|
| v1.0 §2.5 says `data` and `lc` return 502; measurement says they do not resolve | Fresh DNS check with timestamp and method; clarify whether records existed on 2026-10-17 and were deleted, or whether the v1.0 measurement method was incorrect | **Captain** — must be resolved before Gate B inventory |

---

## 6. Shared Platform Blockers

These cross-cutting UNKNOWNs gate every domain including Whoosh, regardless of domain-specific work:

| Blocker | Source | What would unblock it | Owner |
|---|---|---|---|
| **Project coverage** — Whoosh coordinates missing | `PRD_DELIVERY_MAP.md` lines 36–40; unresolved area 1 | Operator supplies exact repo, hosting, runtime, production IP | Operator / Captain |
| **Canonical application architecture unresolved** — current Core/CBD evidence is PHP/MySQL/mixed; v3 targets Hostinger PostgreSQL/PgBouncer + Hetzner queues/workers; no accepted ADR maps existing software to that target | `PRD_DELIVERY_MAP.md` lines 41–44; unresolved area 2 | ADR mapping existing Whoosh software (if any) to the PRD v3 target | Captain / ADR process |
| **Cross-project runtime isolation** — no accepted evidence for four queue namespaces, worker denial tests, project-scoped ingest, file namespaces, database roles, or Qdrant collection isolation | `PRD_DELIVERY_MAP.md` lines 45–49; unresolved area 3 | Isolation test evidence, accepted by QA agent | CrispR / Captain |
| **Hub application delivery** — app deployment pending; LiteLLM placeholder keys; AnythingLLM backend/vector-store relationship and Brandon-vs-HD2 data boundary unknown | `PRD_DELIVERY_MAP.md` lines 50–58; unresolved area 4 | Approved secret store, backup/restore, DNS/TLS, and data boundary decisions | Captain / operator |
| **Release controls (CI/CD) UNKNOWN** | `PRD_DELIVERY_MAP.md` lines 59–60; unresolved area 5 | Per-project CI/CD pipeline evidence | CrispR |
| **Backup/DR UNKNOWN, blocked on operator input** | `PRD_DELIVERY_MAP.md` lines 61–63; unresolved area 6; `BR-HUB-010` BLOCKED_OPERATOR_INPUT | Provider/account, retention, RPO/RTO, key custody — for Whoosh this means Namecheap DR target confirmation | Captain / operator |
| **Observability UNKNOWN** | `PRD_DELIVERY_MAP.md` lines 64–66; unresolved area 7 | Complete four-project SLO/alert/restore-age implementation evidence | CrispR / Captain |
| **Canonical source provenance** — historical Git blob absent | `PRD_DELIVERY_MAP.md` lines 67–69; unresolved area 8 | Recover blob only if exact-byte signoff required | n/a — informational only |
| **Reusable HD2 client baseline incomplete** | `PRD_DELIVERY_MAP.md` lines 70–74; unresolved area 9 | Host-profile overlay with named admin/key pointer, approved ingress, rollback window | CrispR |

---

## 7. Acceptance Criteria

Each criterion is traceable to a v3 PRD section. Criteria without sourced tests are marked UNKNOWN.

### Inventory and Ownership (v1.0 §5, PRD v3 §5 Gates A–E)

- [ ] Hostinger KVM8 inventory documented — **UNKNOWN** (no source)
- [ ] Hetzner Whoosh services documented — **UNKNOWN** (no source)
- [ ] Namecheap VPS capacity and access documented — **UNKNOWN** (no source)
- [ ] Repository, branch, and production branch identified — **UNKNOWN** (no source)
- [ ] Human and service access matrix approved — **UNKNOWN** (no source)
- [ ] `info@whooshperformance.com` ownership and receipt tested — **UNKNOWN** (no source)

### Domain, DNS, and Mail (v1.0 §10)

- [ ] Complete before-state DNS export stored — **UNKNOWN** (no source)
- [ ] Root, `www`, `data`, `lc` purpose documented — **UNKNOWN** (v1.0 §2.5 is the stated intent, but no evidence)
- [ ] Canonical hostname approved — **UNKNOWN** (v1.0 §9 suggests apex; no approved decision)
- [ ] Aspire DNS records identified and validated — **UNKNOWN** (no source)
- [ ] SPF/DKIM/DMARC pass — **UNKNOWN** (no source)
- [ ] `data` DNS records created and resolving — **BLOCKED** (coordinates missing)
- [ ] `lc` DNS records confirmed correct — **BLOCKED** (coordinates missing)
- [ ] **Discrepancy:** v1.0 §2.5 says 502; measurement says NOT RESOLVING — resolution method and timestamp required

### Hostinger / WordPress (v1.0 §9, PRD v3 §7.1, §20.3)

- [ ] WordPress replaces parked-domain response — **UNKNOWN** (no source; parked page confirmed live)
- [ ] WordPress database/user/files isolated — **UNKNOWN** (no source)
- [ ] Nginx and TLS configuration passes — **UNKNOWN** (no source)
- [ ] WordPress security hardening complete — **UNKNOWN** (no source)
- [ ] Forms, media, links, redirects, analytics, and SEO pass — **UNKNOWN** (no source)
- [ ] `www`→apex or apex→`www` canonical redirect implemented — **UNKNOWN** (currently absent per measurement)
- [ ] HTTP→HTTPS redirect implemented — **UNKNOWN** (currently absent per measurement)
- [ ] WordPress release rollback demonstrated — **UNKNOWN** (no source)

### Hetzner / Data Service (v1.0 §2.2, §7.2, PRD v3 §7.2)

- [ ] `data.whooshperformance.com` reaches documented upstream — **BLOCKED** (DNS does not resolve; no upstream to reach)
- [ ] Existing services audited before change — **BLOCKED** (coordinates missing)
- [ ] Required workers have resource, retry, timeout, and concurrency limits — **UNKNOWN** (no source)
- [ ] Cross-project access tests fail as intended — **UNKNOWN** (no source)
- [ ] Controlled scrape/enrichment smoke job passes — **UNKNOWN** (no source)

### Aspire / `lc` (v1.0 §2.3, §7.3)

- [ ] Aspire account owner and administrator identified — **UNKNOWN** (no source)
- [ ] Aspire required DNS records validated — **UNKNOWN** (no source)
- [ ] Tracking, bounce, suppression, and unsubscribe functions validated — **UNKNOWN** (no source)
- [ ] `lc` expected behavior documented — **UNKNOWN** (no source; v1.0 §2.5 intent recorded but not verified)
- [ ] Controlled internal test message succeeds — **UNKNOWN** (no source)

### Security (v1.0 §11, PRD v3 §11)

- [ ] Root login disabled — **UNKNOWN** (no source)
- [ ] Public SSH removed after private access validation — **UNKNOWN** (no source)
- [ ] MFA required for WordPress admin — **UNKNOWN** (no source)
- [ ] Secrets absent from repositories and evidence — **UNKNOWN** (no source; but no implementation exists to audit)
- [ ] Vulnerability and secret scans pass — **UNKNOWN** (no source)

### Monitoring, Backup, and Recovery (v1.0 §14–16, PRD v3 §14–16)

- [ ] Website, data, Aspire/domain, host, and backup monitoring active — **UNKNOWN** (no source)
- [ ] All alerts route to `info@whooshperformance.com` — **UNKNOWN** (no source)
- [ ] Namecheap backup schedule and retention active — **UNKNOWN** (no source; `bdn-dr-whoosh-01` named in PRD v3 but not evidenced)
- [ ] WordPress restore test passed — **UNKNOWN** (no source)
- [ ] Data-service restore test passed — **UNKNOWN** (no source)
- [ ] Actual RPO/RTO recorded — **UNKNOWN** (no source)

### Bot Routing (PRD v3 §17, PRD_TRACEABILITY.md)

- [ ] `whoosh-bot-routing` accepted artifact exists — **UNKNOWN**; do not claim completion without it per task acceptance rule 7

---

## 8. Rollout Sequence

Consistent with PRD v3 Phase 5 ordering: Core Distro → Elevate → **Whoosh** → CBD-Data.

### Phase 0 — Freeze and Baseline

**Cannot start** — Gates A–E are blocked by `COORDINATES_MISSING`.

Required pre-conditions to unlock:
1. Operator supplies: Whoosh repository URL, Hostinger KVM8 hostname/IP for Whoosh, Hetzner Whoosh service hostname/IP, Namecheap VPS hostname/IP, current production IP for `whooshperformance.com`
2. Captain records the v1.0 §2.5 vs 2026-10-18 discrepancy and resolves which state is current

**Gate 0 (exit gate for Phase 0):** Complete baseline package exists; rollback to current parked-domain state is documented.

### Phase 1 — Inventory and Discovery (Gates A–E)

**Cannot start** until Gate 0 passes.

Owner: Saad; reviewed by Captain.

Exit gate: Captain approves discovery report; DNS discrepancy resolved.

### Phase 2 — Security, Access, and Network Foundation

**Cannot start** until Phase 1 exits.

Owner: Saad; approved by Captain.

Exit gate: Access, firewall, TLS, and notification tests pass.

### Phase 3 — WordPress Build

**Cannot start** until Phase 2 exits. Sawar supplies approved imagery.

Exit gate: Desktop/mobile staging review passes.

### Phase 4 — Website and Social Asset Package

**Cannot start** until Phase 3 content is ready.

Owner: Sawar; orchestrated by Captain.

Exit gate: Captain confirms package completeness; Eric/Brandon approve visuals.

### Phase 5 — Data Service Validation and Repair

**Cannot start** until DNS discrepancy is resolved and `data` routing is understood.

Owner: Saad; approved by Captain.

Exit gate: Documented `data` behavior works; smoke job completes.

### Phase 6 — Aspire and Mail Validation

**Cannot start** until Aspire ownership is confirmed.

Owner: Saad; Brandon confirms provider/account state.

Exit gate: Aspire/provider checks pass.

### Phase 7 — Monitoring, Backup, and Recovery

**Cannot start** until Namecheap DR target is classified and provisioned.

Owner: Saad; reviewed by Captain.

Exit gate: Recent verified backup and successful restore report exist.

### Phase 8 — Pre-Launch QA and Failure Testing

Owner: Captain coordinates; Saad executes technical QA; Sawar corrects assets.

Exit gate: No critical issue remains; Captain approves launch readiness.

### Phase 9 — Production Launch and Handoff

Owner: Captain controls; Saad deploys; Eric and Brandon approve.

Exit gate: All acceptance criteria checked; ownership handed off.

---

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `COORDINATES_MISSING` extends indefinitely; Whoosh remains blocked | High | Whoosh cannot enter Phase 0 | Operator must supply repository and host coordinates |
| v1.0 §2.5 discrepancy (502 vs NOT RESOLVING) not resolved before DNS work | Medium | Wrong repair path chosen (configure upstream vs create DNS records) | Captain resolves with fresh timestamped DNS check before Gate B |
| Static-site source not locatable | Medium | WordPress migration has no source material | Gate C stop condition; Saad reports missing asset list to Captain |
| Aspire ownership unresolved | Medium | `lc` service not validated; cold-email deliverability at risk | Brandon confirms Aspire account owner before Phase 6 |
| Namecheap DR target (`bdn-dr-whoosh-01`) not classified | Medium | Backup/DR does not meet PRD v3 requirement | Classify before Phase 7; Mode B if shared hosting |
| Bot routing claimed complete without artifact | Low | Delivery map violation; audit finding | Do not claim; route through proper artifact acceptance |
| Shared platform blockers (isolation, CI/CD, observability, backup) delay Whoosh Phase 5 | Medium | Whoosh rollout stalls at Phase 5 smoke/isolation gate | Coordinate with CrispR on shared platform completion timeline |

---

## 10. Required Evidence to Change Any Status Here

No status moves from `BLOCKED` or `UNKNOWN` to `EVIDENCED` or `DELIVERED` without:

1. **Coordinates supply** — exact repository URL, Hostinger KVM8 hostname/IP, Hetzner Whoosh hostname/IP, Namecheap VPS hostname/IP, and current production IP for `whooshperformance.com`
2. **DNS discrepancy resolution** — timestamped fresh DNS check for `data` and `lc` confirming current state (resolving/502/not resolving) with method used
3. **Gates A–E completion** — per v1.0 §5, signed off by Captain
4. **BR-ARCH-001** — Whoosh placement artifact accepted
5. **BR-GATE-001** — Eric/Dubz approval artifact accepted
6. **`whoosh-bot-routing`** — accepted routing artifact (do not fabricate; task acceptance rule 7)
7. **Shared platform gates** — cross-project isolation, CI/CD, observability, and backup evidence must exist for Whoosh to pass Phase 5 smoke/isolation gate

Do not use the manifest `ACCEPTED` status as a completion signal. The manifest is a task/evidence ledger; accepted rows may describe read-only audits, specifications, or operator-gated work only.

---

## 11. ADR / Decision Items Required

| ADR | Decision needed | Owner |
|---|---|---|
| **ADR-WHOOSH-001** | WordPress deployment method: Docker Compose on Hostinger KVM8 or documented native deployment | Captain / Saad |
| **ADR-WHOOSH-002** | Canonical hostname: apex (`whooshperformance.com`) or `www` | Eric / Brandon |
| **ADR-WHOOSH-003** | `data.whooshperformance.com` public/authenticated behavior and expected HTTP response when DNS resolves | Captain / Saad |
| **ADR-WHOOSH-004** | `lc.whooshperformance.com` Aspire function and whether HTTPS response is required | Captain / Brandon |
| **ADR-WHOOSH-005** | Namecheap DR target mode: Mode A (VPS-capable DR node) or Mode B (shared/cPanel cold recovery) | Captain / operator |
| **ADR-WHOOSH-006** | `info@whooshperformance.com` mailbox provisioning and spam/forwarding policy | Captain |
| **ADR-WHOOSH-007** | DNS discrepancy resolution method: who resolves the 502 vs NOT RESOLVING gap and on what timeline | Captain |
| **ADR-WHOOSH-008** | AnyLLM/vector-store relationship for Whoosh (if applicable) — align with hub application delivery shared blocker | Captain |

---

## Source Index

| File | Lines | Used for |
|---|---|---|
| `data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md` | 1–1616 | Authoritative PRD for Whoosh domain; preserved unchanged |
| `docs/system-context/PRD_TRACEABILITY.md` | 1–339 | `whoosh-audit` BLOCKED/COORDINATES_MISSING; `whoosh-bot-routing` UNKNOWN |
| `docs/system-context/PRD_DELIVERY_MAP.md` | 1–136 | Unresolved areas 1–9; do-not-claim rules; manifest ACCEPTED warning |
| `docs/system-context/SERVICE_CATALOG.md` | 1–200+ | `whoosh-service` BLOCKED/COORDINATES_MISSING |
| `docs/system-context/HOSTS.md` | 1–200+ | `whoosh-runtime` BLOCKED/COORDINATES_MISSING |
| `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` | 1–2072 | House template; Phase 5 ordering; isolation, CI/CD, backup, observability requirements |
| External measurement (2026-10-18) | — | HTTP 200 parked page; md5; no redirect; data/lc NOT RESOLVING; v1.0 discrepancy |
