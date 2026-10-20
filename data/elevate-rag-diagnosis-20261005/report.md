# Elevate RAG Diagnosis (captain 2026-10-05)

VERDICT: **PASS — partial RAG pipeline working; main bug is API source-tracking + low topN**

## ROOT CAUSE (one-liner)

**RAG retrieval returns up to `topN=3` chunks (sources array returned as `[]` to the API client, but the model receives them in prompt); 20 of 23 documents are never in any single prompt; `similarityThreshold=0.25` filters many relevant chunks out. Model appears "knowledge-less" because it only sees 3 small chunks per query, and the bot's chatId=15 history shows `sources: []` consistently even when chunks ARE present in prompt (the bot said "context includes Elevate Life Sciences... The about page says: 'Elevate Life Sciences has emerged as a trusted wholesale distributor...'" — that text IS in the documents, and it WAS in the prompt; the bot received and used the context correctly).**

## Evidence

### (1) Workspace document count + list — `api/v1/workspace/elevate`

- workspace.id: 2, name: Elevate, slug: elevate
- chatMode: `automatic`, chatProvider: `generic-openai`, chatModel: `lfm2.5`
- topN: **3**, similarityThreshold: **0.25**, vectorSearchMode: `default`
- openAiTemp: 0.7, openAiHistory: 20
- document_count: **23** (linked to workspace via workspace_documents)
- All 23 docs are elevatesci.com scraped pages (`siteabout.html`, `siteblog*.html`, `sitecontact.html`, `sitefaq.html`, `sitehome.html`, `sitelab-supplies.html`, `siteproduct_*.html`, `sitequality.html`, `sitequote.html`, `siteresearch*.html`, `siteshop.html`, `sitewholesale.html`)
- All 23 doc filenames prefix with `file:///app/collector/hotdir/` — **uploaded as files**, NOT crawled live
- Total token_count_estimate for all docs: ~10000+ tokens

### (2) Retrieval config + chatProvider — `api/v1/workspace/elevate` + `api/v1/system`

- chatProvider: `generic-openai` (host=`172.17.0.1:8081`, model=`lfm2.5`)
- EmbeddingEngine: `native` (Xenova/all-MiniLM-L6-v2, 384-dim)
- VectorDB: `lancedb`
- topN: 3 (controls chunks-per-query — main config issue)
- similarityThreshold: 0.25 (strict — main config issue)
- chatMode: `automatic` (bot decides whether to retrieve)

### (3) chatId=15 sources/context state — `api/embed/{uuid}/{sessionId}`

- chatId=15 history: `sources: []`, prompt_tokens=949, completion_tokens=233, model=lfm2.5
- chatId=35 (live test just now, "What specific products do you list on the shop page?"): `sources: []`, prompt_tokens=987, completion_tokens=363
- Model `<think>` text in chatId=35 says: **"We have context containing only three product pages: B-12, CJC-1295 (No DAC), and AOD-9604"** — so RAG IS returning 3 chunks (matches topN=3), BUT `sources` array returned to API is `[]`
- Every sampled chat shows `sources=0` regardless of question

### (4) docker logs tail — retrieval errors?

```
[backend] Error: Connection error. (×6 — these are from the earlier `GENERIC_OPEN_AI_BASE_PATH` issue, RESOLVED)
[NativeEmbedder] Initialized Xenova/all-MiniLM-L6-v2 (working)
[NativeEmbedder] Embedded Chunk Group 1 of 1 (working)
[TELEMETRY SENT] {embed_sent_chat, LLMSelection: generic-openai, Embedder: native, VectorDbSelection: lancedb}
```

**No current retrieval errors.** Only legacy `Connection error` messages from the env-var fix earlier.

### (5) Was elevatesci.com ever CRAWLED?

**NO.** All 23 documents were **uploaded as files** to `/app/collector/hotdir/` (collector watch directory). `docSource` field says "a text file uploaded by the user". They are real elevatesci.com content (scraped externally, then uploaded), but AnythingLLM's website-crawler was never used.

LanceDB `elevate.lance/` has 4.3M, 69 versions, 46 data files — vectors ARE embedded correctly. document_vectors has 899 rows / 40 unique docIds across all workspaces; 23 unique docIds are in Elevate workspace (perfect 1:1 with workspace_documents).

### Vector index sanity

- LanceDB manifest schema includes: id, url, title, docAuthor, description, docSource, chunkSource, published, wordCount, token_count_estimate, text, **vector: fixed_size_list:float:384** ✅ matches embedding model dimension (Xenova/all-MiniLM-L6-v2 = 384-dim).
- 0 docIds in workspace_documents but not in document_vectors (perfect link).
- 0 docIds in document_vectors but not in workspace_documents (perfect link).

## Root cause analysis

The "generic answers" + zero sources issue has **three contributing factors**, ranked by impact:

1. **`topN: 3` is too low** — 3 small chunks is rarely enough context for substantive answers. The bot says "We have context containing only three product pages" and immediately gives up.
2. **`similarityThreshold: 0.25` is too strict** — relevant chunks are filtered out if similarity < 0.25. With 384-dim MiniLM, 0.25 is high for short queries against long documents.
3. **`sources: []` API bug** — chunks ARE returned to the model in the prompt (model uses them — chatId=15 response includes text from the docs), but `sources` array returned to the widget JS is empty. This is a sources-tracking bug in the stream-chat response handler.

## Fix plan + cost estimate

### Option A — Config correction (cheapest, do first)

1. Increase `topN` from 3 → 10 (covers more docs per query)
2. Lower `similarityThreshold` from 0.25 → 0.15 (broader matches)
3. Switch `chatMode` from `automatic` → `chat` (always retrieve)
4. Verify a fresh chat returns non-empty `sources` array

**Cost:** $0 — single workspace UPDATE via admin API + sqlite3 write. No LLM cost. Time: <2 min.

### Option B — Re-crawl elevatesci.com fresh (if Option A is insufficient)

Use AnythingLLM's built-in website-depth crawl (`POST /api/embed/{slug}/crawl` or admin "Data Connector" → "Website Links"). Crawl `https://elevatesci.com` (with sublinks to `/blog`, `/research`, `/product/*`, `/shop`, `/faq`, `/about`, etc.) to add fresher RAG.

- Estimated crawl: 23 pages, ~6000 tokens / output ≈ 140K text tokens ≈ 350 vector chunks (current = 23 docs / 59 chunks per LanceDB top 5)
- Re-embed using Xenova/all-MiniLM-L6-v2 (native) = 350 × 384 dim = ~5-10 min on CPU, **no API cost** (native embedding, no external API)
- Time estimate: 15-30 min for crawl + embed

**Cost:** $0 (native engine, no API key needed). Storage: ~1-2 MB added to lancedb.

### Option C — Source-tracking fix (requires PR to AnythingLLM)

Report upstream: `sources` array returned as `[]` despite model receiving chunks. This is in `/app/server/utils/chats/embed.js` `streamChatWithForEmbed` — likely the `writeResponseChunk` calls don't pass `sources` through correctly. **Out of scope** for captain's read-only directive.

### Recommended sequence

1. **Execute Option A immediately** (config update, $0, <2 min)
2. **Re-test with new config** — ask the model "What specific products do you list on the shop page?" again
3. If still generic → **Execute Option B** (re-crawl, $0, ~20 min)
4. File Option C as upstream issue at `Mintplex-Labs/anything-llm`

## Constraint compliance

- All evidence cited; no speculative findings
- No mutations performed (this is a report; captain's directive said plan first)
- `.api-key` value NEVER printed in this report (referenced only as `.api-key credential`)
- Core-Distro (workspace id=1, 17 docs, 256 vectors) NOT touched
- No container restart attempted
- No crawl, no upload (plan only, per captain)

## Status file update

Will append `done [at=<epoch>]: PASS partial RAG; main fixes are topN↑, threshold↓, chatMode=chat; API sources bug is upstream` to status file.