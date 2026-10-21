---
name: ai-infra-benchmark
description: Reusable AI infrastructure testing skill measuring Time To First Token (TTFT), tokens per second (TPS), RAG retrieval latency stages, chunking behavior, and proxy buffering profiles.
user-invocable: true
metadata:
  internal: true
---

# ai-infra-benchmark

Test and benchmark AI infrastructure endpoints (LLM inference, RAG pipelines, AnythingLLM embed endpoints, and Ollama) with rigorous separation of latency components.

## Core Rules & Invariants

1. **Keep TTFT and TPS Apart**:
   - Never report a single combined latency figure. Slow Time-To-First-Token (TTFT) and slow Tokens-Per-Second (TPS) have entirely different causes and remediations.
2. **First-Class RAG Stage Measurement**:
   - The RAG pipeline itself is frequently the dominant bottleneck, not the model.
   - Separately measure:
     - Embedding latency (query embedding time)
     - Vector search retrieval latency
     - Context assembly and reranking latency
     - Chunking behavior (chunk size, overlap, chunks injected into prompt)
3. **Cold vs. Warm Separation**:
   - Always run at least one initial cold run and two subsequent warm runs to prevent first-call model loading or connection overhead from being conflated with regular inference latency.
4. **Proxy Buffering Profile**:
   - Check whether SSE chunks stream incrementally or arrive in a single buffered burst (caused by reverse proxy buffering, e.g., Nginx `proxy_buffering on`).
5. **Quality Impact Statement**:
   - When recommending any change to chunking parameters, retrieval depth, or reranking models to improve latency, explicitly document the expected impact on answer quality.

## Execution

Run the automated benchmark runner:

```bash
python3 /root/agent-work/deightonllm-firstmate/.agents/skills/ai-infra-benchmark/scripts/benchmark_llm_rag.py \
  --url "https://llm.hd2.ai/api/embed/<UUID>" \
  --message "test prompt" \
  --warm 2 \
  --output "/path/to/report.md"
```

## Telemetry Extraction for Local AnythingLLM

To extract internal RAG pipeline telemetry from local Docker instances:

```bash
docker logs --tail 100 anythingllm 2>&1 | grep -E "(Embedding|VectorSearch|Rerank|ContextAssembly)"
```

