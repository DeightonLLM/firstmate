# Core Distro AI Engine

**Status:** target architecture and migration map; no migration has been performed.

**Last updated:** 2026-10-16

## Decision and purpose

Core Distro's intended chatbot engine is its own Ollama service on Hetz, running `ornith-1.5:9b`. Core Distro customer conversations must be processed within Core Distro's service boundary and must not be routed to HD2's AnythingLLM (`llm.hd2.ai`). The separation is an ownership and data-boundary requirement, not merely a preference for a model host: customer prompts, conversation history, retrieved context, and generated responses are Core Distro data. Sending them to HD2 would make the HD2 service, its operators, logs, storage, backups, and subprocessors part of the customer-data path without an established Core Distro authorization or isolation contract.

Staging currently inherits the same chatbot configuration from the same source as live, so it is not an independent test boundary for this route. A staging change alone would not correct production; a shared-source change could affect both environments.

## Engine facts

| Property | Verified/known value |
|---|---|
| Inference server | Ollama |
| Host | Hetz (Hetzner; exact host identity is not independently re-probed in this documentation task) |
| Listener | `127.0.0.1:11434`, localhost only |
| Model | `ornith-1.5:9b` |
| Installed model size | 6.6 GB |
| Model family | Qwen 3.5 (`qwen35`) |
| Installed models | This is reported as the only installed model |
| Model digest | Not supplied in the verified facts available for this task; obtain it from the host's local Ollama model listing before recording a digest. Do not guess. |
| Public exposure | None for Ollama port 11434; public port must remain closed |

Ollama serves its native HTTP API on the loopback listener. Its API includes model-oriented generation/chat operations and an OpenAI-compatible API surface. That is not the same thing as an AnythingLLM hosted-embed endpoint: the site's current widget identifies an AnythingLLM embed by a URL and embed ID, and may depend on AnythingLLM's page, streaming, session, and conversation semantics. The exact compatibility requirements must be checked against the widget in the Core Distro source before a replacement is designed.

### Verify the engine (read-only; run on Hetz)

These commands inspect local state only. Do not change the bind address, start/restart Ollama, or make port 11434 public as part of verification.

```sh
systemctl is-active ollama
ss -ltnp | grep ':11434'
curl --fail --silent http://127.0.0.1:11434/api/tags
ollama list
ollama show ornith-1.5:9b
```

Expected evidence: the service is active; the listener is loopback (`127.0.0.1:11434`, not `0.0.0.0`, `[::]`, or a public interface); the tags/list output contains `ornith-1.5:9b`; and model metadata reports the expected family. Record the digest reported by the local model inventory if available. A local successful API call proves only that Ollama answers on that host; it does not prove the public site is routed to it.

Verify the public data path separately by inspecting the deployed site's source/configuration and browser network requests, without sending a real customer conversation. Confirm that the request goes only to the approved Core Distro endpoint, and that no URL, embed, fallback, telemetry, or retrieval request reaches `llm.hd2.ai` or another HD2-owned service.

## Current route and target route

| | Current (known defect) | Intended target (not implemented) |
|---|---|---|
| Chatbot engine | HD2 AnythingLLM | Core Distro's own Ollama on Hetz |
| Site configuration | `data-base-api-url="https://llm.hd2.ai/api/embed"` | A Core Distro-controlled, authenticated chat endpoint/adaptor that reaches Ollama privately; exact public URL and contract remain to be designed |
| Embed identity | `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2` | Not applicable to Ollama itself. If retaining the current widget, a compatible embed service and its Core Distro-owned embed identity must be provisioned; do not reuse HD2's ID by assumption |
| Model | HD2 AnythingLLM's configured model (not verified here) | `ornith-1.5:9b` |
| Network boundary | Browser reaches `llm.hd2.ai` | Browser reaches only an explicitly approved Core Distro HTTPS application endpoint; that endpoint reaches Ollama over a private/local path |
| Staging | Inherits the same source configuration | Must be tested with a staging-owned endpoint/config and data boundary; do not send staging traffic to HD2 as a fallback |

The site source was not present in this worktree, and the historically referenced path `/root/agent-work/projects/core-distro.com/current-core-distro` was not available during this task. Therefore the URL and embed ID are known from the supplied verified facts, but their exact current source filenames and deployment mechanism have **not** been verified. Do not represent the path in the older evidence as a currently available checkout.

## Migration map (planning only)

This section describes work a human would need to authorize and design. It is not an instruction to perform the migration.

1. **Locate and inventory the source of truth.** Recover the Core Distro website repository and identify every occurrence of `llm.hd2.ai`, `/api/embed`, the supplied embed ID, and the widget script or iframe. Determine whether values live in source HTML/JS, a generated artifact, CMS, environment/config, or deployment variables. The available historical evidence identifies the static-site source as `/root/agent-work/projects/core-distro.com/current-core-distro`, but that path was absent when checked here. Search the actual deployment source and staging/live build inputs before editing anything.
2. **Measure the widget contract.** Capture its required request URL/method, headers, request and response JSON, streaming format, conversation/session identifiers, origin/CORS behavior, error handling, authentication, and any embed-specific features. Confirm if the widget is bundled locally or fetched from an external provider. The current embed ID may select an AnythingLLM embed/workspace configuration; Ollama has no corresponding hosted embed resource or ID.
3. **Choose a compatibility architecture.** Either replace the widget with a Core Distro-owned client that speaks to a Core Distro API, or implement a narrowly scoped server-side adapter that preserves the widget's exact API contract while calling Ollama. Directly changing `data-base-api-url` from `/api/embed` to an Ollama URL is not a valid migration unless the widget protocol is proven compatible. This API-shape mismatch is the principal technical risk.
4. **Keep Ollama private.** The target Ollama listener remains `127.0.0.1:11434`. Do not expose that port to the internet or bind it to a public interface. A browser on a customer's device cannot call Hetz loopback; provide a separately reviewed HTTPS application endpoint or reverse-proxy route that authenticates and authorizes requests, validates input, applies rate/size limits, handles streaming, and forwards only to the local Ollama listener. The proxy must not become an unauthenticated general-purpose model endpoint. Do not choose a hostname, firewall change, proxy, or deployment path without an explicit design and authorization.
5. **Prove tenant and data controls.** Define what is logged or retained, conversation-history policy, access controls, abuse controls, secret handling, backup/retention behavior, and whether prompts are sent to any third party. Check model license and customer-facing disclosure requirements before launch. The stated goal is no HD2 dependency for Core Distro customer conversations; ensure no fallback or telemetry path violates it.
6. **Validate in an isolated staging path.** Stage the adapter/widget and a staging-specific configuration without touching live. Test API compatibility, streaming, auth, error cases, model identity, response quality, rate limiting, and negative routing assertions (including that no request reaches HD2). Only after human approval should a separate cutover plan address live and inherited staging configuration.
7. **Cut over and retain rollback evidence only after approval.** A future change must identify the exact source/deploy mechanism, preserve a known-good configuration, use an approved rollout and rollback plan, and verify the live browser request path. No such actions were taken here.

### Network exposure answer

Ollama itself does **not** need to be exposed beyond localhost and port `11434` must stay private. If customer browsers need chat, some customer-reachable HTTPS application endpoint is necessary, but it should terminate at a purpose-built, access-controlled adapter/proxy—not at Ollama's raw port. Whether that endpoint can live on Hetz, an existing Core Distro application host, or another approved location is unresolved and requires a human architecture/security decision.

## What must remain untouched

- Do not migrate, reconfigure, restart, or expose Ollama as part of this map.
- Do not alter the live Core Distro site, staging site, DNS, firewall, Nginx, deployment, or AnythingLLM instance.
- Do not change or remove HD2 AnythingLLM: it remains HD2-owned and may serve HD2 workloads. The requirement is to remove Core Distro customer-chat dependency on it, not to disrupt HD2.
- Do not touch `srv1137994`, `elevatesVPS`, Aminolifesciences, or unrelated projects/hosts.
- Do not assume shared staging configuration, widget identity, or a model digest is known beyond the facts stated above.

## Evidence and limits

The current/wanted model, current URL, embed ID, 6.6 GB size, family, and loopback-only listener in this document are the verified facts supplied with the work order. The repository's historical system-context notes describe the old HD2 service but are explicitly stale/partial and do not establish the current Core Distro live route. No service or public endpoint was probed, no customer data was sent, and no live or staging configuration was changed.
