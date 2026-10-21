# AnythingLLM Warehouse Projection

Sanitized control-plane projection for AnythingLLM placement, RAG boundaries, and build prerequisites. This directory contains metadata and source pointers only. It does not contain client documents, raw RAG exports, embeddings, secrets, cookies, transcripts, or authenticated URLs.

## Current map

- `hd2-anythingllm`: `VERIFIED` (measured 2026-10-17); internal instance on HD2Stack `vmi3238503` serving our own properties (`hd2.ai`, internal sites) via endpoint `llm.hd2.ai`; container `anythingllm` (`1.12.1`) published `127.0.0.1:3010 -> 3001` (healthy); provider `LLM_PROVIDER=gemini`, `GEMINI_LLM_MODEL_PREF=gemini-3.1-flash-lite-preview`, `VECTOR_DB=lancedb`; local companion `ollama-hd2-1panel` published `127.0.0.1:21434 -> 11434` with `OLLAMA_MODEL_PREF=qwen2.5:0.5b` and no models pulled (verified empty `[]`).
- `hetzner-anythingllm` (`elevate-anythingllm`): `VERIFIED` (measured 2026-10-17); client-facing instance on Hetzner host `brandon-compute` (`100.106.6.22`); container `elevate-anythingllm` (`1.16.2`) bound to loopback `127.0.0.1:3001` and tailnet `100.106.6.22:3001`; provider `generic-openai` (`lfm2.5`) backed by llama-server on `http://host.docker.internal:8081/v1`. Serves client sites (Core-Distro, CBD, customer sites) through the site's own hostname proxy, never through `llm.hd2.ai`.
- `brandon-anythingllm`: `BLOCKED`; planned Brandon Hub service for `srv1856614`; deployment, backup, secret store, backend, and project isolation gates remain open.
- Core/Elevate client chatbot rollout: `VERIFIED`; deployed on Hetzner host `100.106.6.22:3001`. Client sites access this through their own site hostname proxy. Core-Distro staging previously broke the architecture rule by pointing its widget at `llm.hd2.ai/api/embed` (yielding 404).

## Architecture Rule & Boundary

**Internal vs Client Instance Separation:**
- **Our own properties** (`hd2.ai`, internal sites) use AnythingLLM on **HD2Stack (`vmi3238503`)** via endpoint `llm.hd2.ai`.
- **Client sites** (Core-Distro, CBD, any customer) use AnythingLLM on **Hetzner host (`100.106.6.22`)** via loopback `127.0.0.1:3001`, reached strictly through the site's **own hostname** proxy, never through `llm.hd2.ai`.
- A client site must never depend on our internal instance. Core-Distro staging broke this rule by pointing at `llm.hd2.ai/api/embed`, which returned 404.

The system warehouse keeps only sanitized host/service metadata and evidence pointers. Core and Elevate documents, prompts, embeddings, indexes, and transcripts belong in separately governed client/project warehouses. Elevate requires a separate workspace/index seeded only from approved public `elevatesci.com` pages; Core documents/index must not be copied.

## Sources

- `../../system-context/HOSTS.md`
- `../../system-context/SERVICE_CATALOG.md`
- `../../system-context/WAREHOUSE_BOUNDARIES.md`
- `../../system-context/INDEX.md`
- `../../../evidence/ANYTHINGLLM-RAG-CONTROLLER-INVENTORY-20260923.md`
- `../../../BRANDON-COMPUTE-COMMS/from-brandon-compute/20260923T1840Z-controller-chatbot-rag-decision.md`
