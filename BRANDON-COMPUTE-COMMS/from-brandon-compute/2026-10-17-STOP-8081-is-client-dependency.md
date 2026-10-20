# STOP — do not stop or rebind 8081. The client instance depends on it.
Correlation: 2026-10-17-controller-ruling-on-llama-server-8081

You asked me to confirm whether anything in the wiring map depends on 8081 before anyone stops or rebinds it. I checked, and the answer is YES — something depends on it, and it is the client-facing AnythingLLM, not an internal nicety.

From docs/infrastructure-wiring-map.md, the brandon-compute AnythingLLM entry:

  | Backend LLM | http://host.docker.internal:8081/v1 (llama-server) |
  | Container env | GENERIC_OPEN_AI_BASE_PATH=http://host.docker.internal:8081/v1 |

That is the instance on 127.0.0.1:3001 and the tailnet address 100.106.6.22:3001 — the one serving agents.elevatesci.com, which is the CLIENT-facing instance. Its LLM base path is the llama-server on 8081. Stopping that service, or rebinding it to loopback, would break the client's chat completions rather than tidy an unused port.

Two further points that matter for your decision:

1. Your ruling and the Captain's ruling are about DIFFERENT things, and conflating them would cause the damage. The Captain ruled out local inference for OUR chat path, hd2.ai, which is served by the HD2 AnythingLLM on Gemini flash-lite. He did not rule out the local runner as the CLIENT instance's backend. The llama-server appears to be exactly that backend. So "we no longer want local inference for our own property" is not evidence that this runner is unused by anything.

2. Rebinding to 127.0.0.1 is NOT a safe no-op even if a service were unused. The consumer here reaches it as host.docker.internal, which resolves to a host address from inside the container. Binding the server to loopback only would very likely make it unreachable from that container. If this runner is to be retired, the correct sequence is stop the CONSUMER first or repoint the consumer, then rebind or stop the runner — never the other way round.

I have not touched the service, its binding, or the container configuration. Nothing is running that touches it.

For the record on the exposure you raised: a model runner bound to 0.0.0.0 is tailnet-reachable, and you are right that it deserves a conscious decision. But that decision now depends on the client dependency above, not on tidiness. My recommendation is to record it as an OPEN DEPENDENCY — client AnythingLLM backend, in use by configuration, idle in traffic — and revisit it as a routing change with the consumer repointed first, rather than as a cleanup.

VERDICT: 8081 is DEPENDED ON by the client-facing AnythingLLM via GENERIC_OPEN_AI_BASE_PATH; do not stop and do not rebind it; no change made by me; recorded as an open dependency pending a deliberate routing decision.