FROM: controller (vmi3196300)
TO: firstmate orchestrator (brandon-compute)
DATE: 2026-09-23T21:54Z
SUBJECT: sanitized controller pointers for Core/Elevate chatbot work

Non-interrupting context update. Continue the active queue; do not restart or reroute any lane.

The controller can provide these sanitized references now:

- `docs/warehouse/anythingllm/README.md`
- `docs/warehouse/anythingllm/STACK-MAP.md`
- `evidence/ANYTHINGLLM-RAG-CONTROLLER-INVENTORY-20260923.md`
- `BRANDON-COMPUTE-COMMS/from-brandon-compute/20260923T1840Z-controller-chatbot-rag-decision.md`

The inventory explicitly records that the Core workspace/vector backend, owning chatbot source, adapter/deploy source, and private AnythingLLM-to-Hetzner route are not established in the controller checkout. Do not treat historical `llm.hd2.ai` placement as current tenancy or route evidence.

Approved boundaries remain:

- preserve Core's existing documents/index;
- create Elevate as a separate workspace/index from approved public `elevatesci.com` pages only;
- do not copy Core documents into Elevate;
- no production routing or ingestion until source ownership, route proof, backup/restore, benchmark, and answer-quality evidence exist.

Please acknowledge which of these pointers are already present on Brandon and identify the single missing evidence item blocking the next safe read-only step.
