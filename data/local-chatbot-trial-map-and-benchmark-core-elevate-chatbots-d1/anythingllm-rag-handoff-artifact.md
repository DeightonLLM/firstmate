# AnythingLLM / RAG Handoff Artifact
**Task:** local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1
**Produced:** 2026-09-23
**Controller request:** sanitized handoff listing workspace/index metadata, document manifest, embedding/chunk/retrieval settings, prompt/style references, Elevate corpus plan, adapter/build/test command, private route evidence.
**Excludes:** secrets, tokens, cookies, raw embeddings, raw workspace exports, transcripts.

> **Captain scope correction (2026-09-23):** Elevate's approved corpus is public `elevatesci.com` pages only. The internal sales-journey material described below is excluded and must not be used for RAG ingestion or company framing. The public corpus still needs to be collected and reviewed.

---

## Section 1 — Core Distro AnythingLLM Workspace

### 1a. Workspace Identity

| Field | Value | Evidence | Status |
|-------|-------|---------|--------|
| Instance | `hd2-anythingllm` | `SERVICE_CATALOG.md` | UNCONFIRMED_LIVE |
| Domain | `llm.hd2.ai` | `SERVICE_CATALOG.md` | UNCONFIRMED_LIVE |
| Host | `hd2stack` / Contabo `vmi3238503` (historical) | `WAREHOUSE_BOUNDARIES.md` | STALE — not verified since 2026-09-15 |
| Workspace name | **UNKNOWN** | No workspace config found in workspace | UNKNOWN |
| Workspace slug/ID | **UNKNOWN** | No workspace config found in workspace | UNKNOWN |
| Embed ID (live site) | `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` | `current-core-distro/index.html:249` | CONFIRMED_IN_SOURCE |
| API base | `https://llm.hd2.ai/api/embed` | `current-core-distro/index.html:250` | CONFIRMED_IN_SOURCE |

### 1b. Document Manifest — Core

| Document | Source path | Content | Ingested? | Status |
|----------|-------------|---------|-----------|--------|
| `llms.txt` (Lead Engine product description) | `staged-export-test/llms.txt` | Public product summary, feature list, page inventory | **UNKNOWN** — not evidenced as ingested | UNKNOWN |
| Public site pages (homepage, pricing, login, register, public_list) | `staged-export-test/` PHP files | Crawlable public content | **UNKNOWN** | UNKNOWN |
| SaaS app internal pages | `staged-export-test/` | NOT public — excluded from RAG | n/a | EXCLUDED |

**No document manifest hashes available** — no AnythingLLM workspace export or config file found locally. Live workspace has not been inspected (API requires credentials; `llm.hd2.ai` serves HTML for all paths from public network).

### 1c. Embedding / Chunk / Retrieval Settings

| Field | Value | Status |
|-------|-------|--------|
| Embedding model | **UNKNOWN** | UNKNOWN |
| Chunk size | **UNKNOWN** | UNKNOWN |
| Chunk overlap | **UNKNOWN** | UNKNOWN |
| Retrieval method | **UNKNOWN** | UNKNOWN |
| Max context tokens | **UNKNOWN** | UNKNOWN |
| Temperature / generation settings | **UNKNOWN** | UNKNOWN |
| LLM provider for chat | **UNKNOWN** | UNKNOWN |

### 1d. Prompt / Style References

| Field | Value | Evidence |
|-------|-------|---------|
| Assistant name | `Core Distro Assistant` | `index.html:251` |
| Brand image | `https://core-distro.com/core-distro-mark-green.png` | `index.html:252–253` |
| Chat icon | `chatBubble` | `index.html:254` |
| User background color | `#00d455` | `index.html:255` |
| Sponsor text | `Powered by HD2.ai` | `index.html:256` |
| Sponsor link | `https://hd2.ai` | `index.html:257` |
| System prompt / persona | **UNKNOWN** | No AnythingLLM workspace config found |
| Approved response style | **UNKNOWN** | UNKNOWN |
| Guardrails / refused topics | **UNKNOWN** | UNKNOWN |

### 1e. Live Route Evidence

| Path | Result |
|------|--------|
| `https://llm.hd2.ai/api/embed` | Returns HTML (AnythingLLM landing page) — auth-gated or behind reverse proxy |
| `https://llm.hd2.ai/v1/info` | Returns HTML — auth-gated or behind reverse proxy |
| `https://llm.hd2.ai/api/workspace` | Returns HTML — auth-gated or behind reverse proxy |
| Core embed-ID resolves | `0ec57bfa-…` — live site uses it successfully; API is reachable for serving |
| Any workspace list endpoint | No public endpoint found |

**Conclusion:** `llm.hd2.ai` is reachable at the embed level (confirmed by live Core Distro site working) but its admin/API endpoints are not accessible from this network without credentials. This is consistent with AnythingLLM's embedded-chat API design — the embed JS reaches the API, but admin routes require authentication.

---

## Section 2 — Elevate AnythingLLM Workspace Plan

### 2a. Workspace Identity (planned)

| Field | Planned value | Basis |
|-------|---------------|-------|
| Workspace name | `elevate_<dataset>_<version>` | PRD v3 naming convention (`PRD_TRACEABILITY.md`) |
| Tenant | `elevate` | `SERVICE_CATALOG.md` |
| Domain | `elevatesci.com` | `SERVICE_CATALOG.md` |
| Embed ID | **TO BE ASSIGNED** | New workspace must be created first |
| API base | `https://llm.hd2.ai/api/embed` (same instance) | Shared AnythingLLM instance |

### 2b. Trusted Corpus Sources

| Source document | Path | Content | Corpus role |
|----------------|------|---------|------------|
| Client sales journeys | `agent-work/.lavish/client-sales-journeys.html` | Internal sales material | **EXCLUDED** — Captain approved public Elevate pages only |
| Elevate public site content | `elevatesci.com` (live) | Research-use peptides, lab supplies, wholesale enquiry route, batch documentation | Source for public-facing description |
| Elevate GHL modules | Derived from internal sales material | Workflow modules | **EXCLUDED** — not part of the approved public corpus |

### 2c. Corpus Content Summary (from client-sales-journeys.html)

No approved Elevate corpus has been collected yet. Build it from public `elevatesci.com` pages only; do not use internal sales journeys or derived GHL workflow material.

### 2d. RAG Indexing Settings (planned — replicate Core settings once known)

| Field | Planned |
|-------|---------|
| Embedding model | Match Core workspace (UNKNOWN — pending) |
| Chunk strategy | Match Core workspace (UNKNOWN — pending) |
| Max chunk size | Match Core workspace (UNKNOWN — pending) |
| Retrieval top-k | Match Core workspace (UNKNOWN — pending) |

### 2e. Elevate Embed Snippet (planned — same pattern as Core)

```html
<!-- HD2.ai AI Assistant Widget -->
<script
  data-cfasync="false"
  data-embed-id="[TO-BE-ASSIGNED-WHEN-WORKSPACE-CREATED]"
  data-base-api-url="https://llm.hd2.ai/api/embed"
  data-assistant-name="ElevateSCI Assistant"
  data-brand-image-url="[ELEVATE-BRAND-LOGO-URL]"
  data-assistant-icon="[ELEVATE-ICON-URL]"
  data-chat-icon="chatBubble"
  data-user-bg-color="[ELEVATE-COLOR]"
  data-sponsor-text="Powered by HD2.ai"
  data-sponsor-link="https://hd2.ai"
  src="https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js">
</script>
<!-- HD2ai (https://hd2.ai) -->
```

---

## Section 3 — Adapter / Build / Test

### 3a. Existing Adapter

**No AnythingLLM adapter exists in this repository.** The Core chatbot is embedded via a static HTML script tag, not a backend adapter.

### 3b. Elevate Ops Adapter (planned)

| Field | Value |
|-------|-------|
| Source | `agents-dashboard-source/backend/` — per `SERVICE_CATALOG.md` |
| Repository | **UNKNOWN** — not found in workspace |
| Current local checkout | **UNKNOWN** |
| Build command | **UNKNOWN** |
| Test command | **UNKNOWN** |
| Mock-test scope | `read`, `local-build`, `mock-test` only (`SERVICE_CATALOG.md`) |
| Status | `BLOCKED` — authorization; local mock-test only |

### 3c. Recommended Build/Test for Embed Deployment

For the chatbot embed (not the ops adapter):

```
# Validate embed snippet syntax (no live calls)
python3 -c "import re; html=open('index.html').read(); m=re.search(r'data-embed-id=\"([^\"]+)\"', html); print('embed-id:', m.group(1) if m else 'MISSING')"

# Verify script URL returns 200
curl -sI "https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js" | head -1

# Verify API base responds (should return JSON error without embed-id, not 5xx)
curl -s "https://llm.hd2.ai/api/embed" | head -5
```

---

## Section 4 — Missing Evidence Summary

| Item | Status | How to resolve |
|------|--------|---------------|
| Core AnythingLLM workspace name | **UNKNOWN** | Operator or DubzAi/HD2 provides workspace name |
| Core document manifest hashes | **UNKNOWN** | Operator provides workspace document export (no embeddings/raw vectors) |
| Core embedding/chunk settings | **UNKNOWN** | Operator provides AnythingLLM workspace settings screenshot or config |
| Core system prompt | **UNKNOWN** | Operator provides prompt template |
| Core LLM provider/model | **UNKNOWN** | Operator confirms provider (LFM2.5 or other via AnythingLLM) |
| `llm.hd2.ai` admin API access | BLOCKED | Credentials required; not accessible from public network |
| Elevate workspace | **NOT FOUND IN AVAILABLE EVIDENCE** | Workspace inventory is unavailable; existence and owner remain unverified |
| Elevate embed ID | **UNKNOWN** | No embed marker was found on the inspected homepage; workspace/embed inventory remains unverified |
| Elevate document corpus | **UNKNOWN** | Ingestion state was not verified. Any future corpus work remains limited to public `elevatesci.com` pages; internal sales material is excluded |
| Core production landing page source | **NOT IN REPO** | Operator provides cPanel path or git remote |
| Elevate ops adapter repository | **UNKNOWN** | Controller confirmed `BR-ELEVATE-OPS-001` pending reply |

---

## Section 5 — Privacy / Safety Notes

- **No secrets, tokens, API keys, or credentials in this document.**
- **No raw embeddings or vector data included.**
- **No workspace exports or transcripts referenced.**
- All `UNKNOWN` fields represent genuine absence of evidence, not redacted content.
- Live AnythingLLM workspace inspection requires credentials — this artifact is compiled from source inspection and public API probing only.
