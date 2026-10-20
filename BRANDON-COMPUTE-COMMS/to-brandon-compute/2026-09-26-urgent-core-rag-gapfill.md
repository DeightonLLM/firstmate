# URGENT TASK — Core chatbot RAG gap-fill (client-facing, fast) (2026-09-26)

## Problem (captain-verified)
The new Core chatbot (workspaces `core-distro` on localhost:3001) does NOT mention **cold chain logistics** — a core-distro.com offering shown in the green ticker/info strip. The 8-doc reference corpus is incomplete vs the live site. Client is desperate to see it live.

## Your job (authorized — captain directive tonight)
1. **Full crawl of core-distro.com** (same method as your elevate inventory): sitemap + ALL pages, ESPECIALLY homepage ticker/info-strip content, services (cold chain logistics!), catalogue/category pages, about/contact. Save HTML + manifest.csv (URL,SHA256,crawl-date) like you did for Elevate.
2. **Ingest into the existing `core-distro` workspace** via the instance HTTP API:
   - API key: `/home/hd2admin/hd2stack-anythingllm/.api-key` (you own this box, hd2admin)
   - Upload each page: `POST http://localhost:3001/api/v1/document/upload` (multipart file=@f, `Authorization: Bearer $KEY`)
   - Then: `POST /api/v1/workspace/core-distro/update-embeddings {"adds":[<locations>]}`
   - Prefix document titles with `site:` (e.g. `site: cold-chain-logistics.html`) so sources are distinguishable from the 8 reference docs. DO NOT delete or modify the existing 8 reference docs or the workspace prompt.
3. **Verify**: chat test `POST /api/v1/workspace/core-distro/chat {"message":"Does Core-Distro offer cold chain logistics?","mode":"chat"}` — the answer MUST reference cold chain. Also re-ask the original "What is Core-Distro and what do they do?" and confirm the fuller catalogue is now covered. Capture transcripts.
4. **Isolation rule (hard)**: core site content goes ONLY into `core-distro` workspace. Nothing crosses into `elevate`. Re-run the negative test (elevate ws asked about Core must still refuse).
5. Report: `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/from-brandon-compute/20260926T-core-rag-gapfill.md` (manifest stats, test transcripts, any pages that failed) + one line via ssh route.

## Hard rules
- Container `hd2stack-anythingllm`: HTTP API calls ONLY. No docker exec/restart/stop. Port 3001 stays up.
- No live core-distro.com changes — read-only crawl.
- AGY-review the transcript evidence before reporting done.
