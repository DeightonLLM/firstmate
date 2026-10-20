# Elevate RAG Config Fix + Re-Crawl (captain 2026-10-05)

VERDICT: **PASS — both Phase A (config) and Phase B (re-crawl) executed and working**

## Phase A — config (~$0, <2 min, EXECUTED)

### Before
- chatMode: `automatic`
- topN: 3
- similarityThreshold: 0.25
- document_count: 23 (uploaded files, NOT crawled)
- typical prompt_tokens: 949

### Backup
- `anythingllm.db.backup-rag-config-20261005-040908` (sha256 `6050b20d…`)
- Pre-fix workspace row sha256: `007180a5…`

### After
- chatMode: `chat`
- topN: **10**
- similarityThreshold: **0.15**
- Post-fix workspace row sha256: `efe95e79…` (DIFFERENT from pre-fix)
- DB row also DIFFERENT — verified

### Verify-A test
Question: "Tell me everything on your wholesale page about research peptides and shipping"
- prompt_tokens: 949 (before) → **2371** (after) — **2.5× more context**
- text length: ~500 chars (before) → 3976 chars (after) — substantive answer
- sources: `[]` (API bug, unchanged — expected, upstream issue)
- Answer references wholesale page content accurately

## Phase B — re-crawl (~$0, ~5 min, EXECUTED)

### Method
- AnythingLLM endpoint: `POST /api/v1/document/upload-link` (admin API)
- 23 elevatesci.com URLs (all return 200 after redirect resolution):
  - `/`, `/about/`, `/contact/`, `/faq/`, `/shop/`, `/wholesale/`, `/quality/`, `/lab-supplies/`, `/research/`, `/research-notes/`, `/quote/`, `/blog/`, plus 3 blog posts + 8 product pages
- Each call: `{"link": url, "addToWorkspaces": "elevate"}`
- Result: **23 succeeded, 0 failed** (all pages scraped + added to workspace + embedded via native engine)

### After
- workspace=2 (Elevate) **documents: 46** (was 23 → +23 fresh-crawled)
- All 46 unique docIds have vectors (perfect link integrity)
- Total document_vectors rows for Elevate: **475** (was ~60 — 8× more retrieval corpus)

### Verify-B test
Question: "Tell me everything about your wholesale program: minimum order quantities, pricing tiers, shipping destinations, and how to apply"
- prompt_tokens: **2321**
- completion_tokens: **911**
- Model provided substantive answer citing actual wholesale page content:
  - Program benefits (preferred pricing, priority allocation, dedicated support, batch documentation)
  - How to apply (submit credentials + volume requirements)
  - Correctly identified gaps NOT in source (MOQ, exact pricing tiers, shipping destinations)
- **No hallucination** — model used retrieved context accurately

### Time
- API call roundtrip: ~3-5 sec per URL × 23 = ~90 sec total
- Embedding: native engine, runs in-container, ~30 sec for 23 URLs

## Constraints honored
- NO container/db/config/restart mutations (only workspace UPDATE + API uploads)
- Core-Distro (workspace id=1, 17 docs) UNTOUCHED
- Same shared widget
- No external API keys (native embedding engine, generic-openai local at 172.17.0.1:8081)

## Issues remaining (not in scope)
- `sources: []` API bug — model receives chunks in prompt but sources array returned empty. This is in `/app/server/utils/chats/embed.js` `streamChatWithForEmbed`. Should be filed upstream at Mintplex-Labs/anything-llm (separate ticket).

## Next ticket (per captain's standing authority)

The captain's directive also noted: **"ALSO route noted: brandon pi trust-prompt fatigue fix (pre-seed worktree root pattern trust, backup-then-test) — do it as a second ticket after the RAG work, same standards."**

Will be dispatched as a separate scout lane once this report is acknowledged.
## VENDOR-CONTACT POLICY OVERRIDE (captain 2026-10-05)

The `sources: []` API bug finding (chunks in prompt, sources array empty) was originally planned for filing upstream at Mintplex-Labs/anything-llm.

**Captain OVERRIDE:** do NOT file upstream. No GitHub issue. No vendor contact. Ever, without explicit per-case GO.

**Standing rule (per captain 2026-10-05):**
- No agent — controller, coordinator, worker, or subagent — may contact upstream vendors, file GitHub issues, comment on existing issues, or initiate any vendor-channel contact
- Without explicit per-case captain GO
- The `sources: []` finding stays as a **private note** in this artifact only
- RAG-only query mode is **CONFIRMED correct and stays**
- **Nothing else pending** on this ticket

This is the operational default going forward.
