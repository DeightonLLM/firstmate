# Adversarial PRD audit — Core Distro

**Audit date:** 2026-10-18  
**Scope:** Read-only source review and non-mutating HTTP GET probes. No project, DNS, host, or service configuration was changed.  
**Audited PRD:** `data/prds/core-distro-prd-v1.0.md` (1093 lines).  
**Source documents read in full:** `docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` (2071 lines; PD_V3 variant absent), `docs/system-context/PRD_TRACEABILITY.md` (339 lines), `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md` (136 lines), and `data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md` (1615 lines). The latter was used only as the requested structural template, not as evidence about Core Distro.

## Executive assessment

**Overall status: UNKNOWN.** The PRD preserves the major architecture disagreement and states that ADR approval must precede migration decisions, but its current-application mapping overstates what the audit/ledger prove. Its chatbot section is materially stale: it says no source was found and centers an unverified “Invalid session ID” report, while a present-day read-only probe returns the AnythingLLM HTML shell from both the staging client route and the direct upstream. No assistant reply was verified by this audit.

## Findings

### F1 — Current SaaS model is only partly represented; evidence is over-attributed

**Status: UNKNOWN.** The PRD lists the full set of v3 §2.1 application patterns—internal lead/account dashboards, product/supplier records, uploads/downloads, enrichment, and CRM/workflow integrations—at `data/prds/core-distro-prd-v1.0.md:78-87`. It also identifies the application as a SaaS lead-generation product at lines 89-101. That is not a marketing-site-only representation.

However, line 76 says BR-AUD-002 “maps these to actual PHP SaaS implementation.” The ledger's BR-AUD-002 evidence is narrower: PHP production, Next.js staging, MySQL/Percona, auth/lead-list data, and queue-like jobs (`docs/system-context/PRD_TRACEABILITY.md:58-69`). The delivery map likewise calls this source/runtime evidence and not PRD completion (`docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:24`). BR-AUD-002 itself enumerates authenticated sessions, subscriptions/credits, search/enrichment, CRM, and CSV export, but does not establish every v3 pattern; in particular, the cited materials do not establish Core product/supplier records or the v3-style product catalog/quote-partnership flows (`data/BR-AUD-002/report.md:1-12, 35-54, 144-162`).

The source identity disagreement is preserved but not fully neutral: line 76 says the audit description is the “authoritative current application identity” while also calling the matter unresolved. Keep the distinct readings open rather than making either PRD product description authoritative. **Major scope risk:** this does not prove the application is only a marketing site, but the PRD currently blurs expected v3 patterns with implemented application evidence.

### F2 — Production placement is broadly recorded, but the production-host readings remain unreconciled

**Status: EVIDENCED.** The PRD records Namecheap `66.29.153.174` / PHP 8.2 / LiteSpeed and Contabo `161.97.120.4` / agents service (`data/prds/core-distro-prd-v1.0.md:107-115`), and states the Hostinger public/control plane plus Hetzner compute plane as the v3 target (`:126-138`). Those readings match the v3 reality-gap passages (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:449-461`) and the ledger/delivery map (`docs/system-context/PRD_TRACEABILITY.md:66-69`; `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:24`).

There is still an open production-host conflict inside the referenced evidence: BR-AUD-002 calls Contabo cPanel the PHP production deploy host (`data/BR-AUD-002/report.md:1-12, §1a`), while later DNS/HEAD evidence and the delivery map place the public PHP endpoints on Namecheap (`docs/system-context/PRD_TRACEABILITY.md:66-69`; `docs/system-context/evidence/prd-delivery-plan-20260914/PRD_DELIVERY_MAP.md:24`). The PRD lists both facts in separate passages (`data/prds/core-distro-prd-v1.0.md:111-112, 144-149`) but does not explicitly label this production-origin/deployment discrepancy an OPEN CONFLICT. These can potentially describe a proxy/origin distinction; current evidence here does not settle that.

**ADR ordering: EVIDENCED and correctly sequenced in principle.** The exact v3 instruction says an ADR comes first before any Core Distro architecture or migration decisions (`docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:449-451`). The PRD quotes this at `data/prds/core-distro-prd-v1.0.md:41-43`, makes placement conditional on the ADR at `:24-29`, and requires the ADR during discovery before Phase 2 at `:798-806`. It does not authorize a migration before that decision. Do not treat the proposed options in the PRD as the decision itself.

### F3 — Chatbot status omits current shell-response evidence and contains stale attribution

**Status: UNKNOWN.** The PRD calls the chatbot report unconfirmed, says no source was found, and refers to an `llm.hd2.ai` 404 (`data/prds/core-distro-prd-v1.0.md:1078-1089`). That conclusion misses existing source artifacts: `data/lane-widget/report-r1.md:1-24` documents a staging chat POST returning the AnythingLLM SPA HTML shell rather than SSE, and `data/m27.13-q3-staging-chat/report.md:26-57` records a later 404 JSON “Invalid session ID” response for a different route/test and explicitly says no real reply was proven there. A separate report claims a later staging widget test displayed a reply (`data/lane-widget/report-final.md:1-17`), so the evidence has conflicting test outcomes and must not be silently collapsed.

**Read-only probe run on 2026-10-18:**

```text
for u in 'https://core-distro.com' 'https://staging.core-distro.com' 'https://staging.core-distro.com/api/embed' 'https://100.106.6.22:3001/api/embed'; do curl -k -sS --max-time 6 -o /tmp/core-audit.body -D /tmp/core-audit.headers "$u" -w 'http=%{http_code} content_type=%{content_type} bytes=%{size_download}\\n'; done
```

Output: apex `200 text/html` (73,028 bytes); staging `200 text/html; charset=utf-8` (391,528 bytes); staging `/api/embed` `301 text/html`; HTTPS to `100.106.6.22:3001` was a protocol error because the measured upstream was plain HTTP. Follow-up HTTP GET probes to `http://100.106.6.22:3001/`, `/api/embed`, `/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30`, and `https://staging.core-distro.com/llm/chat/api/fd029baa-22fd-4a3a-b074-40c7a00daf30` each returned `200 text/html; charset=utf-8`, 1,926 bytes, beginning with an HTML document. The HTML is the app shell, not a stream payload. These were GETs, not chat submissions; no assistant response was sought or verified. The current direct-upstream and staging-route results support the user-provided finding that both currently serve the SPA shell. The bare `/api/embed` redirect is not proof of an embed configuration/API response.

The PRD should record the measured client hostname and direct upstream separately, with method/path, date, HTTP status, content type, and HTML-shell result; retain the earlier 404 JSON and later reply report as dated conflicting evidence. It must say explicitly **no assistant reply verified by this current audit**. Do not claim that an assistant reply was verified based on an HTTP 200 or an SPA response.

### F4 — Provenance label spot-check (21 assertions checked)

**Status: EVIDENCED.** Spot-check result: 21 provenance assertions checked; 19 substantiate the narrow statement they label and two fail. “Substantiates” here means the referenced section supports the asserted source content, not that the cited requirement is deployed or accepted.

| PRD location / label | Source cross-check | Result |
|---|---|---|
| `:41-43` `[PER v3 §2.1 production-reality-gap]` | v3 §2.1 says ADR first before any Core architecture or migration decision (`...PRD_V3.md:449-451`). | Substantiated |
| `:76` `[PER TRACEABILITY — BR-AUD-002/report.md]` | The accompanying assertion says BR-AUD-002 maps all listed v3 patterns to implemented PHP SaaS functionality. The ledger only supports PHP production, Next.js staging, MySQL/Percona, auth/lead-list data, and queue-like jobs (`docs/system-context/PRD_TRACEABILITY.md:58-69`); BR-AUD-002's feature inventory likewise does not prove every listed pattern (`data/BR-AUD-002/report.md:1-12, 35-54, 144-162`). | **Fails: over-attributes implementation evidence** |
| `:78-87` `[PER v3 §2.1]` | The listed patterns are stated as “expected application patterns” in v3 §2.1 (`...PRD_V3.md:66-83`). | Substantiated as expected patterns only; not proof of implementation |
| `:89-101` `[PER TRACEABILITY — BR-AUD-002]` | Audit reports PHP SaaS, auth/subscriptions, RapidAPI, Replicate, CRM, exports, and jobs (`data/BR-AUD-002/report.md:1-12, §1b`). | Substantiated for listed implementation facts |
| `:109-115` `[PER v3 ... verified 2026-10-12]` | v3 itself contains the Namecheap/Contabo reality-gap and localhost-trap text (`...PRD_V3.md:449-451, 460-461`). | Substantiated as a recorded source statement; see open host conflict F2 |
| `:117-118` `[PER TRACEABILITY — coredistro-source-runtime]` | Ledger status/evidence/date and open gates are at `PRD_TRACEABILITY.md:58-69`. | Substantiated |
| `:120-121` `[PER TRACEABILITY — coredistro-route-qa]` | Status and limits of BR-CORE-001 are at `PRD_TRACEABILITY.md:71-82`. | Substantiated |
| `:123-124` `[PER TRACEABILITY — coredistro-canary]` | Blocker, hash, paused backlog, and operator signal are at `PRD_TRACEABILITY.md:84-95`. | Substantiated |
| `:128-138` `[PER v3 §§7.1–7.2]` | Hostinger and Hetzner target roles and Core compute gap are at `...PRD_V3.md:356-461`. | Substantiated |
| `:220` `[PER TRACEABILITY — coredistro-source-runtime]` | Ledger says EVIDENCED; the PRD's claim that full Namecheap specs are absent is consistent with cited ledger fields (`PRD_TRACEABILITY.md:58-69`). | Substantiated |
| `:273` `[PER v3 §2.1 production-reality-gap]` | Quoted ADR-first direction matches v3 (`...PRD_V3.md:449-451`). | Substantiated |
| `:286` `[PER v3 §§6.1, 7.1–7.2]` | High-level architecture and server role references match those sections (`...PRD_V3.md:286-320, 356-461`). | Substantiated |
| `:351-392` `[PER v3 §§7.1–7.2]` | Responsibilities and Core compute gap correspond to the referenced role sections (`...PRD_V3.md:356-461`). | Substantiated |
| `:424-426` `[PER v3 §8.1]` | PostgreSQL/PgBouncer target and one-project-per-database pattern are at `...PRD_V3.md:692-724`. | Substantiated |
| `:443-445` `[PER v3 §8.2]` | Preferred Hostinger API → durable job → Hetzner queue/worker → ingest path is at `...PRD_V3.md:726-752`. | Substantiated |
| `:471-475` `[PER v3 §9.1 / TRACEABILITY]` | Hostinger file roles are at `...PRD_V3.md:806-817`; audit describes CSV exports and application data (`data/BR-AUD-002/report.md:1-12, §1b`). | Substantiated for stated roles/features; implementation placement remains unknown |
| `:497` `[PER v3 §10.1]` | Cloudflare placement and controls are at `...PRD_V3.md:878-892`. | Substantiated |
| `:503` `[PER v3 §11.4]` | Application-security requirements are at `...PRD_V3.md:1009-1025`. | Substantiated as requirements, not current compliance evidence |
| `:521` `[PER v3 §10.4]` | **Fails.** v3 §10.4 is Docker networks (`...PRD_V3.md:936-948`), not TLS/security headers. Its TLS and header claims are not supported by the cited section. v3 §11.4 supports only part (CSP staged report-only/enforced); it does not establish all listed TLS versions, HSTS, `nosniff`, or `X-Frame-Options` (`...PRD_V3.md:1009-1025`). |
| `:525` `[PER v3 §10.3]` | Public-port requirements are indeed v3 §10.3 (`...PRD_V3.md:911-934`). | Substantiated as target requirements; not proof of current port exposure |
| `:537` `[PER v3 §11.1]` | Host-hardening requirements are at `...PRD_V3.md:952-967`. | Substantiated |

**Failed provenance assertions found in this sample:** the `[PER TRACEABILITY — BR-AUD-002/report.md]` mapping claim at PRD line 76 overstates the cited implementation evidence; `[PER v3 §10.4]` at PRD line 521 cites Docker-network requirements for TLS/header requirements. Other overclaims are captured separately in F1/F2/F3.

The PRD's source-label key says `[VERIFIED TODAY]` requires command/output (`data/prds/core-distro-prd-v1.0.md:10-14`), but no such marker occurs in the PRD; this audit's own measurements are recorded above. A search found 88 bracketed label occurrences including the four key definitions, not 87 provenance rows (`grep -oE '\\[(PER v3|PER TRACEABILITY|VERIFIED TODAY|OPEN CONFLICT)[^]]*\\]' ... | wc -l` returned `88`). Treat the requested “87 rows” count as unreconciled with the visible marker count; it may count rows differently.

## Conclusion and minimal corrections

1. Keep the v3 full product-pattern list, but clearly distinguish it from BR-AUD-002-verified current functionality. Mark each unsupported product/supplier, quote/partnership, and file-flow assertion UNKNOWN rather than attributing it wholesale to the audit.
2. Explicitly record the Contabo cPanel deployment statement versus the later Namecheap public endpoint measurement as an OPEN CONFLICT until a source/origin map reconciles it.
3. Correct the TLS citation at PRD line 521; do not cite v3 §10.4 for TLS/security headers.
4. Replace the chatbot “no source found” framing with dated evidence and the present GET results. Preserve the conflicting earlier test outcomes. State that no assistant reply was verified in the current audit; an HTTP 200 SPA shell is not a stream or reply.
5. Leave the Hostinger/Hetzner adoption question BLOCKED pending the required ADR. The evidence does not authorize choosing a target architecture.

## Evidence and worktree state

- Full source documents were read in full; audited lines are referenced above.
- Commands run: `wc -l`; `grep`/`sed`/`find` for source and provenance inspection; `curl` GET probes described in F3; `git status --short`; and `git diff --cached --name-only` (post-audit check).
- No code/tests were added or changed. Only this requested audit report was created; `data/audit/` was created because it was absent.
- Initial `git status --short` showed pre-existing `M data/async-lanes.tsv`, `?? core-distro-saas-clean`, and `?? firstmate`. This audit did not stage, modify, or remove those paths. No staged files were present at the post-audit check.
- Residual risk: a HEAD/GET of HTML routes cannot verify POST streaming behavior, authentication state, or whether a real assistant reply can be produced. No POST chat request or credentialed API test was performed.
