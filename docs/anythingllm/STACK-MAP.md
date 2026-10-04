# AnythingLLM Stack Map

| Surface | Role | Status | Verified placement / pointer | Current limitation |
|---|---|---|---|---|
| HD2Stack `vmi3238503` | Existing HD2 AnythingLLM | `PARTIAL` | Historical `llm.hd2.ai`; Docker Compose and named volumes; `../../system-context/SERVICE_CATALOG.md` | No current live check, workspace assignment, vector backend, or client isolation proof |
| HD2.ai `llm.hd2.ai` | HD2 brand/domain | `PARTIAL` | Historical service catalog entry | DNS/origin was not checked; do not infer Brandon tenancy |
| Brandon Hub `srv1856614` | Intended Brandon AnythingLLM host | `BLOCKED` | `../../system-context/SERVICE_CATALOG.md`, Brandon Hub task records | No accepted deployment, backup/restore, secret-store, backend, or project-isolation evidence |
| Hetzner `brandon-compute` | Brandon compute/model/RAG support plane | `PARTIAL` | `../../system-context/HOSTS.md` | Coordinates accepted historically; live re-verification blocked by Tailscale interactive re-auth |
| Core Distro | Core chatbot tenant/reference | `UNKNOWN` | `../../../evidence/ANYTHINGLLM-RAG-CONTROLLER-INVENTORY-20260923.md` | Canonical AnythingLLM workspace, index, source repo, and prompt not established |
| Elevate | Separate chatbot tenant | `UNKNOWN` | `../../../BRANDON-COMPUTE-COMMS/from-brandon-compute/20260923T1840Z-controller-chatbot-rag-decision.md` | Approved corpus decision exists; source, workspace, route, and quality evidence remain open |

Historical or intended placement is labeled as such and is not a deployment claim.
