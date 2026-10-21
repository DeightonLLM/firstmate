---
name: ai-infra-probe
description: Measure AI-serving and RAG latency from an explicit target, and report unavailable internals as unknown rather than guessing.
user-invocable: true
metadata:
  internal: true
---

# AI infrastructure probe

Load this skill when diagnosing slow AI chat, comparing cold and warm behavior, or measuring retrieval latency.

## Safety and scope

The probe is read-only and performs HTTP GET requests only.
It never sends chat prompts, calls model-generation endpoints, changes configuration, pulls models, installs runners, restarts services, or deploys.
A GET-only run cannot measure generation or internal RAG stages; those values must remain unavailable unless separately exposed by a non-generative diagnostics interface.
Never infer inaccessible timings or chunking values from total request latency.

## Procedure

1. Require an explicit `--target` URL for the AnythingLLM instance or target page.
2. Run `probe.sh --target <url> --out <json-path>` and optionally supply a known `--embed-id` for reporting.
3. Review the observed HTTP status and request timing before making any bottleneck claim.
4. Treat embedding, vector search, context assembly, chunking, time-to-first-token, and tokens-per-second as unknown unless the target exposes those measurements through a non-generative read-only endpoint.
5. Keep time-to-first-token and tokens-per-second as separate fields; do not substitute one for the other.
6. Compare cold and warm measurements only when both were actually collected with comparable requests.
7. Attribute pre-generation delay only to observed phases. Overall HTTP time does not identify proxy buffering, retrieval, or model time by itself.
8. Any chunking or retrieval recommendation must state the likely answer-quality tradeoff alongside the measured speed evidence.

## Output

The JSON report records target, reachability, observed HTTP status, elapsed request time, any embed identifier explicitly provided or discovered in page markup, and separate fields for embedding, vector search, context assembly, chunking, time-to-first-token, tokens-per-second, cold/warm, and pre-generation synchronization.
Unavailable values are `null` with an explanatory `limitations` entry.
The command prints the same JSON it writes to `--out`.
A failed input exits nonzero with a diagnostic on stderr; an unreachable target exits nonzero after writing its observation when possible.

The bundled probe intentionally does not issue chat or generation requests, because those may incur provider charges and this skill has no spend authority.
