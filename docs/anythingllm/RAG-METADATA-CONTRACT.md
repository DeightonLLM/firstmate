# RAG Metadata Contract

This contract defines sanitized metadata required before a Core or Elevate AnythingLLM build. It never requires copying raw corpus content.

## Core metadata

- workspace name/opaque ID;
- document inventory: relative logical ID, source category, byte size, SHA-256, and approval status;
- embedding model/version and vector backend/index identity;
- chunk size, overlap, retrieval count, rerank settings, and citation policy;
- system prompt/style/brand source references with secret and private text removed;
- adapter repository, checkout, build command, test command, and runtime endpoint identity;
- private route proof between the chatbot and model/vector services.

## Elevate metadata

- separately governed workspace/index name and opaque ID;
- approved public `elevatesci.com` URL inventory, crawl date, and content hashes;
- Elevate company framing and vertical-aware answer rubric;
- the same embedding, chunking, retrieval, adapter, route, and benchmark metadata as Core;
- explicit proof that Core documents/index were not copied.

## Exclusions

Do not project client documents, raw exports, vector databases, embeddings, secrets, tokens, cookies, authenticated URLs, provider keys, or production transcripts. Workspace names alone do not prove tenant isolation; require access, retrieval, backup, deletion, restore, and negative cross-tenant tests.
