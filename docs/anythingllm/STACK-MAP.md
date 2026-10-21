# AnythingLLM Stack Map

| Surface | Role | Status | Verified placement / pointer | Current limitation |
|---|---|---|---|---|
| HD2Stack `vmi3238503` | Internal HD2 AnythingLLM (our own properties: `hd2.ai`, internal sites) | `VERIFIED` | Measured 2026-10-17: Container `anythingllm` (`mintplexlabs/anythingllm:1.12.1`), published `127.0.0.1:3010 -> 3001` (healthy). Provider `LLM_PROVIDER=gemini`, `GEMINI_LLM_MODEL_PREF=gemini-3.1-flash-lite-preview`, `VECTOR_DB=lancedb`. Companion `ollama-hd2-1panel`, published `127.0.0.1:21434 -> 11434` with `OLLAMA_MODEL_PREF=qwen2.5:0.5b`. | Ollama has no models pulled (`curl http://127.0.0.1:21434/api/tags` returns `{"models":[]}`). Internal-only; strictly prohibited for client sites. |
| HD2.ai `llm.hd2.ai` | Internal endpoint for HD2 properties | `VERIFIED` | Measured 2026-10-17: Cloudflare edge proxy returning HTTP 200 to HD2Stack port 3010. | Serves internal properties only. Architecture rule: Client sites must never query `llm.hd2.ai`. |
| Brandon Hub `srv1856614` | Intended Brandon AnythingLLM host | `BLOCKED` | `../../system-context/SERVICE_CATALOG.md`, Brandon Hub task records | Application deployment gated; not deployed. |
| Hetzner `brandon-compute` (`100.106.6.22`) | Client sites AnythingLLM host (Core-Distro, CBD, customer sites) | `VERIFIED` | Measured 2026-10-17: Container `elevate-anythingllm` (`mintplexlabs/anythingllm:1.16.2`), published on loopback `127.0.0.1:3001` and tailnet `100.106.6.22:3001`. Provider `generic-openai` (`lfm2.5`) backed by llama-server on `http://host.docker.internal:8081/v1`. | Must be reached by client sites through the site's own hostname proxy, never through `llm.hd2.ai`. Port 8081 is a required client dependency. |
| Core Distro | Client chatbot tenant | `VERIFIED` | Client site served via Hetzner host (`100.106.6.22:3001`) through client site proxy. | Staging widget previously misconfigured to point at `llm.hd2.ai/api/embed` (yielding 404). Must use client site proxy. |
| Elevate | Client chatbot tenant | `VERIFIED` | Client site served via Hetzner host (`100.106.6.22:3001`) through client site proxy. | Separate client corpus and workspace on Hetzner host. |

## Architecture Rule

**Strict separation of internal vs client AnythingLLM instances:**
1. **Our own properties** (`hd2.ai`, internal sites) use AnythingLLM on **HD2Stack (`vmi3238503`)** via endpoint `llm.hd2.ai`.
2. **Client sites** (Core-Distro, CBD, customer sites) use AnythingLLM on **Hetzner host (`100.106.6.22`)** via loopback `127.0.0.1:3001` / tailnet, reached strictly through the site's **own hostname** proxy.
3. **The rule that was broken:** Core-Distro staging pointed its widget at `llm.hd2.ai/api/embed`, which returns 404, causing client chat to fail. Client sites must never depend on the internal HD2 instance.

Historical or intended placement is labeled as such and is not a deployment claim.

