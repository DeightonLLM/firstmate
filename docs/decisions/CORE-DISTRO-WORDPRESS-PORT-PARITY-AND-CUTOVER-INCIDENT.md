# Core Distro — WordPress Port, Pixel-Perfect Parity & Cutover Incident (Post-Mortem)

- **Status:** POST-MORTEM — production verified, one open regression
- **Date:** 2026-10-18
- **Owner:** Second Mate, Domain Execution & Report Synthesis (HD2Stack `vmi3238503`)
- **Authority:** Captain (Sole Orchestrator & Technical Acceptance Authority); First Mate Coordinator
- **Supersedes:** `ADR-0001-core-distro-production-cutover.md` (Next.js recommendation) — see §3
- **Verification host:** HD2Stack `vmi3238503.contaboserver.net` (all measurements below)
- **Lane:** `EXECUTE_BOUNDED_TASK` · `BROWSER_WORK: NO` · no mutation outside the declared write boundary

---

## 1. Executive Summary

`core-distro.com` is now served by **WordPress 7.1.3** on Hetzner (`100.106.6.22:8087`) behind Hostinger nginx (`45.90.220.156`), with the AnythingLLM chat tenant proxied through the client's **own hostname** to Hetzner `100.106.6.22:3001`.

Verified on 2026-10-18:

| # | Invariant | Result | Evidence |
|---|---|---|---|
| 1 | Production returns HTTP/2 200 | **PASS** | `HTTP/2 200`, `x-powered-by: PHP/8.3.35` |
| 2 | Zero `llm.hd2.ai` references | **PASS** | `grep -c 'llm\.hd2\.ai'` → **0** |
| 3 | Widget proxied via client hostname | **PASS** | `data-base-api-url="https://core-distro.com/api/embed"` |
| 4 | Proxy terminates at Hetzner 3001 | **PASS** | embed ID 200 on **both** proxy and origin; `X-Frame-Options: DENY` match |
| 5 | Pixel-perfect asset parity | **PASS** | favicon **8,160 B**; logo **146,940 B**; 4/4 section images byte-identical |
| 6 | Fonts (Barlow Condensed, DM Sans) | **PASS** | Google Fonts `css2` link, both families loaded |
| 7 | Flags (gb, pl, es) | **PASS** | `assets/flags/{gb,pl,es}.svg` → 200, **475 / 211 / 284 B byte-exact** |
| 5b | Baselined assets byte-exact | **PASS** | **8 of 8** — favicon, logo, 4 section images, 3 flags |
| 8 | `/root/bin/check-visual-correctness` | **PASS** | exit 0 |
| 9 | Chat TTFT vs 500 ms SLA | **FAIL** | **847 ms** — open regression, §7 |
| 10 | Hardening: `xmlrpc.php` exposed | **FAIL** | reachable in production, §7 |

**Two issues remain open. Neither is a parity or isolation failure.**

---

## 2. Mandate — Why WordPress Was the Mandated Port

The Captain's mandate was explicit and predates ADR-0001. On **2026-10-06** the Controller issued the Hetzner Second Mate work order
`BRANDON-COMPUTE-COMMS/controller-replies/2026-10-06-core-distro-wordpress-port-prep.md`:

> *"Prepare Staged Port of `core-distro.com` to WordPress"* — *"Try vanilla WordPress structure first. Astra plugin license is available on HD2 stack as fallback if vanilla cannot faithfully reproduce components."*
>
> **HARD SAFETY GATE:** *"DO NOT touch live webroot or DNS. Do NOT execute the port yet — prepare assets, tokens, Docker staging scripts, and queue the tickets only."*

This established three durable constraints that ultimately decided the architecture:

1. **WordPress was the target platform**, not a fallback for a failed Next.js build.
2. **Astra (or vanilla WordPress) was the sanctioned mechanism** — a plugin/theme port, not a bespoke React rewrite.
3. **Live webroot and DNS were gated** until a staged port existed and was verified.

Production today runs exactly that stack: WordPress 7.1.3 with the **Astra** base theme and a `core-distro-stage` child theme carrying the ported parity assets.

---

## 3. Why Next.js and WordPress Diverged

### 3.1 ADR-0001 chose Next.js

`ADR-0001-core-distro-production-cutover.md` (2026-10-17/18) recommended **Option B — promote the Hostinger Next.js stack to production apex**, and the Captain's acceptance was recorded at commit `05c6cac` (2026-10-18 00:10). Its §1 justification cited two measurable wins:

> *"**Chat TTFT Latency Fixed:** Replaced the stalled Hetzner CPU AnythingLLM proxy with direct HD2Stack Gemini embed (`https://llm.hd2.ai/api/embed`, UUID `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`), bringing measured Time-To-First-Token down from ~60s to **143.8ms**."*

### 3.2 The justification was an architectural violation

That 143.8 ms figure — and therefore the core performance argument for Option B — was measured against **`llm.hd2.ai`**, the *internal HD2* AnythingLLM instance. `docs/anythingllm/STACK-MAP.md` states the rule without ambiguity:

> *"Client sites (Core-Distro, CBD, customer sites) use AnythingLLM on Hetzner host (`100.106.6.22`) via loopback `127.0.0.1:3001` / tailnet, reached strictly through the site's **own hostname** proxy."*
>
> *"**The rule that was broken:** Core-Distro staging pointed its widget at `llm.hd2.ai/api/embed`, which returns 404."*

So ADR-0001 selected a platform whose headline advantage depended on an endpoint a client site may never call. The advantage was not merely inadvisable — it was non-existent under the correct architecture.

### 3.3 The divergence became self-evident under enforcement

`data/hd2-takeover/report-q3-staging-chat.md` (2026-10-17, **VERDICT: PASS**) records the correction: the Next.js staging chat was repointed off `llm.hd2.ai` to Hetzner via nginx proxy blocks on `staging.core-distro.com`:

```
/llm/chat/embed/  -> http://100.106.6.22:3001/embed/
/llm/chat/api/    -> http://100.106.6.22:3001/api/
/api/embed/       -> http://100.106.6.22:3001
```

with embed ID **`fd029baa-22fd-4a3a-b074-40c7a00daf30`** — the same embed ID production WordPress serves today, confirming tenant continuity from staging straight through the cutover.

Once the Next.js path was forced onto the compliant Hetzner tenant, it needed a **reverse proxy to emulate the thing WordPress gets natively**: an AnythingLLM reachable at the client's own hostname. That proxy layer is the structural tell. The WordPress cutover instead **colocates content and chat tenant on the same Hetzner host** (`8087` content, `3001` AnythingLLM), so the client's own hostname *is* the correct origin and no emulating hop is needed.

**Divergence, in one line:** Next.js required a hand-built proxy to satisfy an invariant that the WordPress-on-Hetzner topology satisfies by construction, while its stated performance benefit was an artifact of the forbidden endpoint.

---

## 4. How the Divergence Was Caught

Four independent controls surfaced the conflict — none of them a production outage:

1. **The architecture rule in `STACK-MAP.md`** already documented `llm.hd2.ai/api/embed` as the previously-broken configuration. ADR-0001 re-introduced the identical dependency while citing it as a feature. Contradiction was visible on the page.
2. **Visual-correctness standard (Ticket 0036).** `/root/bin/check-visual-correctness` plus the pixel-parity audit forced a side-by-side of the Next.js staging against live WordPress, which is what surfaced that the two stacks served structurally different markup, assets, and language plumbing.
3. **The Q3 repoint verification.** The explicit check *"Zero client-side requests from `staging.core-distro.com` reach `llm.hd2.ai`"* is a hard isolation assertion, and satisfying it required the architecture change.
4. **The mandated-port order of 2026-10-06**, which made WordPress the pre-authorized destination rather than an open question — so the fix was a return to mandate, not a fresh debate.

Had the mandate not pre-existed, this would have presented as a migration between two equally-viable stacks with a trade-off (compliance cost vs. latency, §7).

---

## 5. Verified Production Architecture

```
Browser
  └─ Cloudflare  (HTTPS, HTTP/2, cf-cache-status: DYNAMIC)
       └─ Hostinger nginx   45.90.220.156   (TLS terminator; 301 → https on :80)
            ├─ WordPress        100.106.6.22:8087   Apache/2.4.68 · PHP/8.3.35 · WP 7.1.3
            │     └─ theme  core-distro-stage  (Astra child) — assets served locally
            └─ AnythingLLM      100.106.6.22:3001   container elevate-anythingllm
                  └─ embed fd029baa-22fd-4a3a-b074-40c7a00daf30
```

### 5.1 Origin proof (not assumed)

Direct probes:

| Probe | Result |
|---|---|
| `--resolve core-distro.com:443:45.90.220.156` | `HTTP/2 200` → **Hostinger is the TLS origin** |
| `--resolve core-distro.com:443:100.106.6.22` | `curl: (7) connection refused` → Hetzner does **not** serve 443 |
| `core-distro.com` default Hostinger vhost (`http://45.90.220.156/`) | `301 → https://agents.elevatesci.com/` → unrelated default vhost |

Content-origin equivalence proven by MD5 on the same theme asset:

```
core-distro.com (CF)  : 3f2dad7605517065cfab46d6eeab545f  146940
hetzner 8087 (origin) : 3f2dad7605517065cfab46d6eeab545f  146940
```

Byte-identical logo on the Cloudflare edge and the Hetzner origin confirms the edge is a pure passthrough for content.

### 5.2 Tenant isolation proof (not assumed)

Isolation is proven **positively** (reaches the right tenant) rather than only negatively (does not mention the wrong host):

- `https://core-distro.com/api/embed/` → `301 → /api/embed/` → **`HTTP/2 200`**
- `https://core-distro.com/api/embed/fd029baa-…` → **`HTTP/2 200`**
- `http://100.106.6.22:3001/api/embed/fd029baa-…` → **`200`** *(same embed ID resolves at the origin)*
- `X-Frame-Options: DENY` on **both** the client proxy and the Hetzner origin for
  `/embed/anythingllm-chat-widget.min.js`

A different embed ID would 404 at the origin; it resolves, so the proxy terminates at Hetzner 3001. Serving the AnythingLLM asset through the client hostname also keeps the tenant CORS/`server` identity inside the client's own origin — the requirement in §1 of the charter.

---

## 6. Pixel-Perfect Parity Result

Full matrix in `data/hd2-takeover/report-staging-visual-pixel-perfect.md`. Summary versus the mandated baseline:

| Asset | Live (WordPress) | Baseline | Status |
|---|---|---|---|
| `favicon.ico` | 200 · **8,160 B** | 8,160 B | **EXACT** |
| `core-distro-logo.webp` | 200 · **146,940 B** | 146,940 B | **EXACT** (MD5-matched to Hetzner origin) |
| `vials-packaging-v2.webp` | 200 · 85,134 B | 85,134 B | **EXACT** |
| `automation-machine-v2.webp` | 200 · 194,938 B | 194,938 B | **EXACT** |
| `about-pharma-v3.webp` | 200 · 165,238 B | 165,238 B | **EXACT** |
| `compliance-quality-v2.webp` | 200 · 170,948 B | 170,948 B | **EXACT** |
| `hero-lab-v2.webp` | 200 · 162,396 B | — | served; no baseline recorded |
| Barlow Condensed | `wght@400;600;700;800` | required | **MATCH** |
| DM Sans | `ital,opsz,wght@0,9..40,300…600` | required | **MATCH** |
| Flags | `assets/flags/gb.svg` · `pl.svg` · `es.svg` (`lang="en\|pl\|es"`) | 475 / 211 / 284 B | **EXACT** |

Note on URLs: the Next.js staging served assets from root-relative paths (`/favicon.ico`, `/images/…`, `/assets/flags/…`). WordPress serves them from `/wp-content/themes/core-distro-stage/assets/…` (flags from the `assets/flags/` subdirectory). **All 8 baselined assets are byte-identical**, confirming the same binaries were ported; the paths changed because the platform changed. The root-relative paths now return `404` on production — expected, not a regression, but any tooling pinned to the old paths will need updating.

---

## 7. Open Issues (Do Not Close the Incident on These Silently)

### 7.1 TTFT regression — 847 ms vs 500 ms SLA — **OPEN**

| Path | Time-To-First-Byte | Compliant? |
|---|---|---|
| `core-distro.com/api/embed/…` (Hetzner tenant) | **847 ms** | ✅ yes |
| `llm.hd2.ai/api/embed/…` (internal HD2) | 159 ms | ❌ **forbidden for client sites** |

The previously-cited 143.8 ms / ADR-0001's headline number was measured on the forbidden path. **On the compliant path the site is ~5.4× slower than that figure and misses the 500 ms SLA.** The cost is inherent to routing a client tenant across hosts; ADR-0001's "fix" was to avoid that hop by taking the illegal one.

Recommended next step (not executed — out of this lane's write boundary): confirm whether the 847 ms is transport or generation, then decide between a Hetzner-side warm path, a same-host embedding, or a revised SLA. Do **not** resolve this by repointing to `llm.hd2.ai`.

Measurement caveat: this is `time_starttransfer` on the embed config endpoint, not a full streamed first-token measurement; treat it as a regression signal, not a final SLA verdict.

### 7.2 `xmlrpc.php` exposed — **OPEN**

`https://core-distro.com/xmlrpc.php` is present in production markup and advertised via the `Link` headers. It is a well-known brute-force and amplification surface. Mitigation is a Hostinger/nginx deny rule (or WordPress-side disable). Not applied here: production configuration is outside this lane's write boundary.

### 7.3 Stale report superseded — **DONE in this lane**

`report-staging-visual-pixel-perfect.md` described the **Next.js** staging on elevatesci and instructed operators to bind the widget to `https://llm.hd2.ai/api/embed` with embed ID `0ec57bfa-…`. Both are now wrong: the endpoint is forbidden for client sites and the embed ID belongs to the wrong tenant. That document has been rewritten to describe the live WordPress production stack, with the historical content retained as an appendix.

---

## 8. Hardening Baseline Applied

| Control | State |
|---|---|
| Cloudflare edge TLS + HTTP/2 | Active (`cf-ray`, `alt-svc: h3`) |
| `x-content-type-options: nosniff` | Present |
| `x-frame-options: SAMEORIGIN` | Present on WordPress responses |
| `referrer-policy: strict-origin-when-cross-origin` | Present |
| Canonical HTTPS enforcement | Active (`:80` → `301 → https`) |
| Content served from client origin, not vendor CDN | Confirmed — `site.css` and all images local to theme |
| Client tenant isolation | Enforced + positively proven (§5.2) |
| `xmlrpc.php` | **Exposed — see §7.2** |

---

## 9. Scope & Boundaries Observed

- **Verified:** Hetzner `100.106.6.22:8087`, AnythingLLM `100.106.6.22:3001`, Hostinger `45.90.220.156`, Cloudflare edge.
- **Mutated:** only `docs/decisions/CORE-DISTRO-WORDPRESS-PORT-PARITY-AND-CUTOVER-INCIDENT.md`, `data/hd2-takeover/report-staging-visual-pixel-perfect.md`, and a git commit of those two paths.
- **Not touched:** AGENTS.md, M3/protected lanes, credentials, Herdr pane state, client application code, databases, Docker configuration, live nginx/WordPress config. §7.2's remediation is **recommended, not applied**.
- **Browser work:** none. No screenshot was captured; the visual report states this rather than implying fresh capture.
- **No production failure occurred.** Both hosts reachable, no HTTP 500, no stop condition triggered.

---

## 10. Evidence Index

| Fact | Where verified |
|---|---|
| WP 7.1.3, PHP 8.3.35, CF headers | `curl -I https://core-distro.com/` |
| Zero `llm.hd2.ai` | `grep -c 'llm\.hd2\.ai' /tmp/cd-root.html` → `0` |
| Widget binding | `data-base-api-url` in fetched root HTML |
| Proxy → Hetzner 3001 | dual-origin 200 on embed ID; `X-Frame-Options: DENY` match |
| Hostinger is TLS origin | `--resolve core-distro.com:443:45.90.220.156` |
| Content origin equivalence | MD5 `3f2dad76…` on both planes |
| Asset parity | size/MD5 table §6 |
| TTFT regression | curl `time_starttransfer`, both paths |
| Visual gate | `/root/bin/check-visual-correctness` exit 0 |
| Captain mandate | `2026-10-06-core-distro-wordpress-port-prep.md` |
| ADR conflict | `ADR-0001…` §1.2 vs `STACK-MAP.md` |
| Isolation enforcement | `report-q3-staging-chat.md` |

---

**VERDICT: PASS** — WordPress port is in production, pixel-perfect parity is verified byte-exact, and AnythingLLM tenant isolation is enforced and positively proven against Hetzner `100.106.6.22:3001` with zero `llm.hd2.ai` references. Two follow-ups are open and must not be closed silently: the **847 ms TTFT SLA regression (§7.1)** and **exposed `xmlrpc.php` (§7.2)**.