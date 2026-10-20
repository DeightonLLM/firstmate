# local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1 — Scout Report

**Date:** 2026-09-23
**Scope:** Read-only scout. No production writes, no deploys, no runtime changes, no data ingestion.
**Workers:** Two parallel Pi/worker children (MiniMax-M2.7): source-map and local-llm-benchmark.
**Lab:** Herdr session `fm-lab-local-chatbot-tr-4192532-11870` provisioned and viewer-attached via `fm-herdr-lab.sh`; teardown on EXIT.

---

## 1. What I did

1. **Herdr lab setup** — provisioned isolated lab session `fm-lab-local-chatbot-tr-4192532-11870` with foreground viewer, using `fm-herdr-lab.sh` exclusively. Default session preserved throughout.
2. **Parallel children** — launched two Pi/worker children via workflow: `chatbot-source-map` (source discovery) and `local-llm-benchmark` (LFM2.5 benchmark). Both ran concurrently.
3. **Independent reconnaissance** — while children ran, inspected: controller-reference source tree, service catalog, PRD traceability, warehouse boundaries, DubzAi AnythingLLM SKILL, client-sales-journeys, elevatesci.com Nginx route record, and the live `current-core-distro/index.html` embed snippet.
4. **Local model probe** — confirmed LFM2.5 live on `localhost:8081` via `/v1/models`; ran non-streaming and streaming sanity checks before children launched.

---

## 2. Benchmark observations: Hetzner LFM2.5 on port 8081

**Model:** `lfm2.5:latest` — llama.cpp serving, Q4_KMedium, 8.47B params; live `n_ctx=32768`, `n_ctx_train=128000`
**Endpoint:** `http://localhost:8081/v1/chat/completions`, OpenAI-compatible
**Host:** Hetzner; the benchmark captured coarse before/after resource snapshots only.

### Synthetic prompts, no customer data

| Test | Observed result | What the evidence supports |
|------|-----------------|----------------------------|
| Short prompt, streaming | First SSE event at 1.734s, 2.162s, and 2.806s; each first event had `content: null` | First-content-token latency was not measured. The report's former 96–190ms values are unsupported by this raw log. |
| Medium prompt, non-streaming | 7.107s / 349 output tokens; 8.843s / 439 tokens; 10.839s / 525 tokens | Approx. 48–50 generated tokens/s. One run exceeded 10s. The final confirmation command aborted. |
| Concurrent requests | N=1: 1.920s; N=2: 3.813s; N=4: 5.137s | These runs do not support the former near-perfect scaling claim. |
| Long streaming prompts | Logged durations: 85.37s, 115.23s, and 121.21s | The raw log does not establish first-content timing or the cause of the observed duration. |

The previous benchmark table and pass verdict were incorrect and are superseded by these observations. No reviewed answer set or quality rubric was captured, so answer quality is unverified. The resource log contains only coarse before/after `/proc/stat` and memory snapshots; available memory was approximately 51.6–52.3 GiB in those snapshots, which does not establish peak memory or sustained host responsiveness.

**Verdict:** Inconclusive for production routing. These observations justify a controlled follow-up benchmark with a defined answer-quality rubric and measured first-content latency; they do not establish acceptable customer-facing quality or end-to-end AnythingLLM latency. Do not route production traffic based on this report.

---

## 3. Core Distro chatbot — source map

### 3a. Chatbot embed provider

**Provider:** AnythingLLM (DubzAi/HD2 standard embed)
**Script URL:** `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js`
**API base:** `https://llm.hd2.ai/api/embed`
**Embed ID:** `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`

### 3b. Exact embed snippet

File: `agent-work/core-distro-saas-clean/current-core-distro/index.html` lines 246–260

```html
<!-- AnythingLLM Chatbot Widget (DubzAi/HD2 standard embed) -->
<script
  data-cfasync="false"
  data-embed-id="0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2"
  data-base-api-url="https://llm.hd2.ai/api/embed"
  data-assistant-name="Core Distro Assistant"
  data-brand-image-url="https://core-distro.com/core-distro-mark-green.png"
  data-assistant-icon="https://core-distro.com/core-distro-mark-green.png"
  data-chat-icon="chatBubble"
  data-user-bg-color="#00d455"
  data-sponsor-text="Powered by HD2.ai"
  data-sponsor-link="https://hd2.ai"
  src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js">
</script>
<!-- HD2ai (https://hd2.ai) -->
```

### 3c. Mobile CSS override

File: `current-core-distro/index.html` lines 163–199 (inline `<style>` block)

Contains the DubzAi/HD2 standard AnythingLLM host-page mobile override: `overflow: hidden` clip, `width: min(400px, calc(100vw - 24px))`, `max-height: calc(100svh - 24px)`, `@media (max-width: 720px)` breakpoint with `left: 12px`, `border-radius: 14px`. This CSS is embedded in the landing page, not served from AnythingLLM.

### 3d. Deploy owner

- **In-repo canonical source:** `agent-work/core-distro-saas-clean/staged-export-test/` — the editable PHP SaaS application. Chatbot embed is **absent** from this tree (zero matches for `anythingllm`, `llm.hd2`, `chatbot`, `chat-widget`).
- **Landing page source:** `current-core-distro/index.html` — static HTML, legacy/reference only.
- **Production landing page:** Not tracked in this repository. Served via cPanel from Contabo host. The `core-distro.com` SaaS app itself (PHP, cPanel) is also not in this repo.
- **Deploy owner:** DubzAi/HD2 operator (per AGENTS.md management URL map and DubzAi/HD2 standard embed SKILL).

### 3e. HD2.ai rebrand points in Core source

| Element | Value | Location |
|---------|-------|----------|
| Sponsor text | `Powered by HD2.ai` | `index.html:256` |
| Sponsor link | `https://hd2.ai` | `index.html:257` |
| Trailing comment | `<!-- HD2ai (https://hd2.ai) -->` | `index.html:260` |
| API base URL | `https://llm.hd2.ai/api/embed` | `index.html:250` |
| Script src | `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js` | `index.html:258` |

### 3f. AnythingLLM implementation-facing wording requiring review

| Location | Text | Action |
|----------|------|--------|
| `index.html:246` | `<!-- AnythingLLM Chatbot Widget (DubzAi/HD2 standard embed) -->` | Replace "AnythingLLM Chatbot Widget" with "AI Assistant" or "Chat" in visible or structural comments |
| `index.html:163` | `/* ── AnythingLLM host-page mobile override (DubzAi/HD2 standard) ── */` | Replace "AnythingLLM" with generic "AI chat widget" or "Chat container" |
| SKILL file | `/home/hd2admin/.codex/skills/dubzai-anythingllm-chatbot/SKILL.md` | Retain for operational reference; rename title to "HD2.ai Website Chat Embed" if desired |

**Safe HD2.ai sponsor treatment:** `data-sponsor-text="Powered by HD2.ai"` and `<!-- HD2ai (https://hd2.ai) -->` are the correct, approved sponsor attribution and should be preserved.

### 3g. RAG / vector backend

- **Status:** Unknown. Service catalog marks vector backend as `UNKNOWN`.
- **No RAG source files** in `core-distro-saas-clean/` or `staged-export-test/`.
- **AnythingLLM instance:** `hd2-anythingllm` on `llm.hd2.ai`, hosted on Contabo `vmi3238503` (HD2Stack), Docker Compose. Last verified 2026-09-15.
- **Workspace name for Core:** Not explicitly recorded in workspace evidence. PRD v3 convention would be `core_<dataset>_<embedding_version>`.

---

## 4. Elevate — source map

### 4a. Domain distinction

| Domain | Type | Current state |
|--------|------|---------------|
| `elevatesci.com` | Marketing website | Static; host UNKNOWN in workspace evidence; last verified 2026-09-15 |
| `agents.elevatesci.com` | Dashboard | Static Nginx on Hostinger KVM8 `srv1137994-aminolifesciences`; `/api/*` returns `503` locally; no HD2Stack upstream; dashboard auth unresolved |

### 4b. Chatbot for Elevate

**No chatbot embed exists** for either `elevatesci.com` or `agents.elevatesci.com` in any workspace evidence. Grep across all agent-work and HD2 admin home returned zero matches for `anythingllm`, `llm.hd2`, `chatbot`, or `chat-widget` in any Elevate context.

### 4c. Approved company-material sources for Elevate

| Source | Content | Relevance |
|--------|---------|-----------|
| `/home/hd2admin/agent-work/.lavish/client-sales-journeys.html` | HD2-authored Elevate/Core buyer journeys; Elevate's buyer persona (research organisations, lab procurement contacts), peptide/lab-supply wholesale, M01–M04 GHL workflow modules, FDA compliance risk note | **Primary RAG corpus candidate** |
| `elevatesci.com` public site | Research-use peptides, lab supplies, wholesale enquiry route, batch documentation | Source for public-facing Elevate description |
| `agents.elevatesci.com` | Static dashboard; no chatbot or AI backend | Out of scope for chatbot |

### 4d. Elevate vertical framing (from client-sales-journeys.html)

> *"Elevate Life Sciences / ElevateSCI — Research supply, from enquiry to repeat order. Public site: research-use peptides, lab supplies and wholesale enquiries. Proposed first buyer segment: verified research organisations and authorised laboratory procurement contacts."*

**Key vertical-aware topics for RAG:**
- Peptide/lab-supply product knowledge
- Research buyer qualification (organisation verification, intended use)
- Batch documentation requirements
- Regulatory compliance (FDA risk patterns for peptide sellers)
- GHL workflow modules M01–M04
- Quote/RFQ follow-up cadence

### 4e. Service catalog records

| Record | Domain | Owner | Status |
|--------|--------|-------|--------|
| `elevate-site` | `elevatesci.com` | `elevate` | `EVIDENCED` (static, 84 files) |
| `elevate-dashboard` | `agents.elevatesci.com` | `elevate` | `PARTIAL` (static dashboard retained; API disabled) |
| `elevate-ops-adapter` | `elevatesci.com` | `elevate` | `BLOCKED` (authorization; mock-test only) |

---

## 5. AnythingLLM service topology (from SERVICE_CATALOG)

| Instance | Owner | Domain | Host | Status |
|----------|-------|--------|------|--------|
| `hd2-anythingllm` (live, serving Core Distro) | `deightonllm` | `llm.hd2.ai` | Contabo `vmi3238503` (HD2Stack) | `PARTIAL` — last verified 2026-09-15; vector backend unknown |
| `brandon-anythingllm` (planned, not deployed) | `brandon` | UNKNOWN | UNKNOWN — target: Hostinger `srv1856614` | `BLOCKED` — awaiting auth, backup/restore, DNS/TLS |

**DNS/live check gate:** `llm.hd2.ai` origin has not been live-verified since 2026-09-15. No route should be inferred without a live HTTP check.

---

## 6. DubzAi/HD2 AnythingLLM SKILL — rebrand points

**SKILL file:** `/home/hd2admin/.codex/skills/dubzai-anythingllm-chatbot/SKILL.md`
**Staging copies:** `.codex/skills.staging.20260923T080000Z/` and `.codex/skills.staging.20260923T080600Z/`

**Required defaults (keep):**
- `data-chat-icon="chatBubble"` — functional, keep
- Mobile CSS override block — functional, keep
- `data-sponsor-text="Powered by HD2.ai"` + `data-sponsor-link="https://hd2.ai"` — approved sponsor, keep
- Timestamped restore points before edits — operational safety, keep

**Renamed rebrand opportunity:**
- SKILL title: `"dubzai-anythingllm-chatbot"` → `"hd2-website-chatbot"` or `"hd2-ai-chat-embed"`
- SKILL description: remove "DubzAi/HD2 standards for AnythingLLM" → "HD2.ai website chatbot embed standard"
- Section headings mentioning "AnythingLLM website chatbot embeds" → "HD2.ai website chatbot embeds"

---

## 7. Open blockers

| # | Blocker | Impact | Who resolves |
|---|---------|--------|--------------|
| B1 | Public embed JavaScript returns HTTP 200 and the Core homepage includes its embed, but live service origin, authenticated API, workspace mapping, and RAG data remain unverified | Cannot inspect Core's workspace or establish a safe Elevate workspace | Controller/operator provides a read-only workspace inventory and current service coordinates |
| B2 | Live Core homepage renders a Next.js app, while the warehouse catalog records PHP-FPM production; canonical production source/deploy ownership is unresolved | Cannot modify either site safely without identifying its real source and delivery path | Controller/operator provides canonical source and deploy owner |
| B3 | Core AnythingLLM vector backend unknown | Cannot confirm RAG corpus or indexing pipeline | DubzAi/HD2 provides AnythingLLM workspace name and vector backend |
| B4 | No Elevate chatbot workspace was found in available evidence; its public homepage currently has no embed marker | No verified target workspace or embed deployment path | Controller/operator confirms whether a workspace exists and its owner |
| B5 | Elevate corpus scope is approved as public `elevatesci.com` pages only; page inventory and workspace isolation still need verification | Do not ingest until the public page set and isolated destination are confirmed | Worker curates public pages after workspace/source access is confirmed |
| B6 | Existing AnythingLLM is cataloged on Contabo; the Hetzner model listens on `localhost:8081`, and private reachability is unverified | Cannot route inference to the requested Hetzner model | Controller/operator verifies an approved private route; do not change network configuration in this scout |

`agents.elevatesci.com` is the separate dashboard and is outside this rollout's accepted scope; the targets are `elevatesci.com` marketing and `core-distro.com`.

The separate planned `brandon-anythingllm` service has its own PRD gates, but this report does not treat it as a prerequisite because the captain requested the existing AnythingLLM integration. Revisit that path only if the runtime owner selects it.

---

## 8. Staged implementation plan (bounded, with gates)

### Phase A — Elevate chatbot via the existing AnythingLLM integration and Hetzner LFM2.5, subject to benchmark gates

**Gate A1 (must close before workspace or RAG work):** The public Core embed asset is reachable, but obtain an authorized read-only Core workspace inventory and confirm the actual workspace and RAG backend. Do not infer the workspace from the public embed id.

**Gate A2:** Confirm Hetzner LFM2.5 on port 8081 is accessible from the AnythingLLM container/network, not just localhost.

**Gate A3:** Operator provides Core Distro production landing page source path (cPanel file or git remote).

**Then:**
1. Locate or create Elevate AnythingLLM workspace (name: `elevate_<dataset>_<version>` per PRD v3 convention)
2. Ingest only the approved public `elevatesci.com` pages after confirming a separate workspace, retrieval isolation, and recovery path
3. Add embed snippet to `elevatesci.com` source (same pattern as Core, replace embed-id, assistant name, brand image, sponsor)
4. Re-run a controlled synthetic benchmark only after approval, and require the agreed latency and answer-quality gates to pass. Current observations of 7.107s, 8.843s, and 10.839s for 349–525 output tokens do not demonstrate a sub-10s gate or acceptable answer quality.
5. Preserve the approved `data-sponsor-text="Powered by HD2.ai"` attribution.

### Phase B — Core Distro embed rebrand (HD2.ai wording cleanup)

**Gate B1:** Obtain production source access (cPanel or git).

**Then:**
1. Replace `<!-- AnythingLLM Chatbot Widget -->` comment → `<!-- HD2.ai AI Assistant -->` or remove
2. Replace `/* AnythingLLM host-page mobile override */` CSS comment → `/* HD2.ai chat widget mobile override */`
3. Keep all functional attributes (`data-embed-id`, `data-base-api-url`, `data-chat-icon`, etc.) unchanged
4. Keep `data-sponsor-text="Powered by HD2.ai"` unchanged
5. Timestamp a backup: `index.html.bak-YYYYMMDD-HHMMSS`
6. Test: public HTTP 200 + confirm override CSS present in fetched HTML

### Phase C — RAG corpus for Core (preserve existing, extend if needed)

**Gate C1:** Identify current Core Distro workspace name in AnythingLLM and its vector backend (Qdrant or internal AnythingLLM vector DB).

**Then:**
1. Read existing workspace document list (via AnythingLLM API — read-only)
2. Add any missing Core-distro-specific content from `llms.txt` (public product description)
3. Preserve existing RAG set — do not replace

---

## 9. What was NOT changed

- No production site files modified
- No AnythingLLM settings changed
- No DNS, ports, proxy, or service configuration touched
- No Ollama or new inference runtime installed
- No RAG documents or indexes modified
- No auth, credentials, or secret-bearing configs read
- No docker inspect, no raw config dumps
- No deploys executed

---

## 10. Next bounded tasks for parent review

| # | Task | Model | Owner | Blocker |
|---|------|-------|-------|---------|
| N1 | Obtain a safe, read-only Core workspace/vector/document inventory from HD2 | Controller/operator | — | B1, B3 |
| N2 | Obtain canonical Core and Elevate source/deploy paths and owners | Controller/operator | — | B2 |
| N3 | Curate a public Elevate page set with company framing and vertical coverage | MiniMax-M2.7 | — | B4, B5 |
| N4 | Confirm or create a separate isolated Elevate workspace | Controller/operator | — | B4, B5 |
| N5 | Deploy Elevate embed snippet to elevatesci.com source | MiniMax-M2.7 | Operator | N1, N2, N3, N4 |
| N6 | Rebrand Core embed comments (AnythingLLM → HD2.ai) | MiniMax-M2.7 | Operator | B3 |
| N7 | Confirm Core RAG corpus and vector backend | MiniMax-M2.7 | Operator | B2 |
| N8 | Verify the approved private route from the existing AnythingLLM host to Hetzner's model | Controller/operator | — | B6 |

---

## 11. Evidence references

| Evidence | Path |
|----------|------|
| Core chatbot embed | `agent-work/core-distro-saas-clean/current-core-distro/index.html:246–260` |
| Core mobile CSS override | `agent-work/core-distro-saas-clean/current-core-distro/index.html:163–199` |
| DubzAi SKILL (rebrand reference) | `/home/hd2admin/.codex/skills/dubzai-anythingllm-chatbot/SKILL.md` |
| Service catalog — AnythingLLM | `agent-work/firstmate/docs/system-context/SERVICE_CATALOG.md:34–50, 257–270` |
| Service catalog — Elevate sites | `agent-work/firstmate/docs/system-context/SERVICE_CATALOG.md:226–247` |
| Warehouse boundaries | `agent-work/firstmate/docs/system-context/WAREHOUSE_BOUNDARIES.md:40, 59` |
| Elevate Nginx containment | `firstmate-baseline/docs/system-context/ELEVATE_NGINX_ROUTE_20260919.md` |
| Elevate PRD traceability | `agent-work/firstmate/docs/system-context/PRD_TRACEABILITY.md:43–54` |
| Elevate client-sales-journeys (RAG corpus candidate) | `agent-work/.lavish/client-sales-journeys.html` |
| Elevate ops-source-map report (prior work) | `kun-agent-workspace/data/elevate-ops-source-map/report.md` |
| LFM2.5 benchmark raw output | `/tmp/pi-subagents-uid-1000/async-subagent-runs/6fae2ad8-…/output-0.log` |
| Source-map child output | `/home/hd2admin/.pi/agent/sessions/…/subagent-artifacts/7fbaf907-…_worker_output.md` |

---

*Scout phase complete. Report written read-only. All worktree edits confined to this laboratory session. Herdr lab session `fm-lab-local-chatbot-tr-4192532-11870` will be torn down on EXIT via trap.*

## Supervisor reconciliation — 2026-09-23

This section records why the benchmark verdict above was corrected. The raw benchmark child log is `/tmp/pi-subagents-uid-1000/async-subagent-runs/6fae2ad8-bfb0-4531-8561-6930f6fb4b36/output-0.log`; no rerun was authorized or performed.

- The three short streaming runs logged first SSE-event times of 1.73s, 2.16s, and 2.81s. The first event contained `role: assistant` with `content: null`, so these are not first-content-token measurements. The report's 96–190ms figures are unsupported by this raw log.
- The three medium non-streaming runs logged 7.11s, 8.84s, and 10.84s, generating 349–525 completion tokens. The final confirmation command ended with `Command aborted`. The former 3.99–4.19s values did not match these raw runs; the imprecise 7–11s summary has been replaced by the exact observations in §2.
- The concurrency log recorded N=1 at 1.92s, N=2 at 3.81s, and N=4 at 5.14s. This does not support the report's "near-perfect parallel scaling" claim.
- No answer-quality rubric or reviewed output set is recorded. Treat quality as unverified; do not describe the model as quality-accepted for customer responses.
- `agents.elevatesci.com` dashboard authentication is out of scope because the captain specified `elevatesci.com` marketing and `core-distro.com` only. Remove it as a rollout blocker.

No benchmark was rerun and no worker was restarted for this correction. The result supports further controlled evaluation only; it does not authorize production routing. The existing `llm.hd2.ai` service is cataloged on Contabo, while the tested model endpoint is bound to `localhost:8081` on Hetzner; private reachability and runtime ownership remain unverified.

## Supervisor live public embed check — 2026-09-23 18:49 UTC

- `https://core-distro.com/` returned live HTML containing embed id `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` and `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js`.
- `https://elevatesci.com/` returned a homepage with no `data-embed-id`, widget script, or `/api/embed` marker. This checks the homepage only, not every marketing page.
- The public widget JavaScript URL returned HTTP 200 from the Cloudflare edge. This proves public asset availability only; it does not establish the service origin, authenticated workspace API, RAG workspace, document inventory, vector backend, or client isolation.
- The live Core homepage includes Next.js assets, while the warehouse catalog currently describes PHP-FPM production and a separate Next.js staging site. Treat the canonical source/deploy route as unresolved pending controller evidence.
- These were read-only HTTP requests. No chatbot prompt was sent and no configuration or RAG data was read or changed.
