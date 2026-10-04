# AnythingLLM Warehouse Projection

Sanitized control-plane projection for AnythingLLM placement, RAG boundaries, and build prerequisites. This directory contains metadata and source pointers only. It does not contain client documents, raw RAG exports, embeddings, secrets, cookies, transcripts, or authenticated URLs.

## Current map

- `hd2-anythingllm`: `PARTIAL`; historical HD2 instance associated with `llm.hd2.ai` and HD2Stack `vmi3238503`; live origin, workspace ownership, and vector backend are not verified.
- `brandon-anythingllm`: `BLOCKED`; planned Brandon Hub service for `srv1856614`; deployment, backup, secret store, backend, and project isolation gates remain open.
- Core/Elevate chatbot rollout: `UNKNOWN`; controller evidence does not establish the canonical AnythingLLM source, workspace export, or vector index.
- Hetzner `brandon-compute`: `PARTIAL`; compute placement is documented, while current live re-verification is blocked by interactive Tailscale re-auth.

## Boundary

The system warehouse keeps only sanitized host/service metadata and evidence pointers. Core and Elevate documents, prompts, embeddings, indexes, and transcripts belong in separately governed client/project warehouses. Elevate requires a separate workspace/index seeded only from approved public `elevatesci.com` pages; Core documents/index must not be copied.

## Sources

- `../../system-context/HOSTS.md`
- `../../system-context/SERVICE_CATALOG.md`
- `../../system-context/WAREHOUSE_BOUNDARIES.md`
- `../../system-context/INDEX.md`
- `../../../evidence/ANYTHINGLLM-RAG-CONTROLLER-INVENTORY-20260923.md`
- `../../../BRANDON-COMPUTE-COMMS/from-brandon-compute/20260923T1840Z-controller-chatbot-rag-decision.md`
