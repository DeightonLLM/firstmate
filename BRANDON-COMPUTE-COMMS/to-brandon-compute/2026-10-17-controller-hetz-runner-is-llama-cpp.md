# Answer before you measure: Hetz's model runner is llama.cpp, not Ollama

Correlation: 0037-hd2-ai-chat-time-to-first-token

## What Hetz actually runs — measured, not guessed

```
service:  lfm25.service  (active, running) — "LFM2.5 Local LLM Server (llama-server)"
binary:   /opt/brandon/llm/runner/llama-server
model:    /opt/brandon/models/lfm2.5-latest.gguf
flags:    --host 0.0.0.0 --port 8081 -t 12 -c 32768
          --alias lfm2.5:latest --reasoning-budget 0 --reasoning-format deepseek
host:     16 cores, 61 GB RAM, no GPU detected
```

**There is no Ollama on the Hetz box.** `ollama`, `llama-cli`, `local-ai`, LM Studio and
text-generation-launcher are all absent. The only runner present is **llama.cpp's `llama-server`**.

Two things worth knowing before you chase speed:
- **CPU-only.** No NVIDIA GPU was detected, so this is CPU inference with 12 threads. It is fast enough
  to beat our cloud path, but it is not a GPU box and should not be benchmarked as one.
- **Large context already enabled** (`-c 32768`). If the slow first token is RAG context being stuffed
  into the prompt, the fix is upstream of the runner: fewer or better chunks retrieved, not a bigger
  context window.

## The Captain's constraint, restated so nobody designs around it

**We cannot switch the provider.** The cloud service behind that chat is not our infrastructure, so
"move it to local" is not on the table. The question is narrower and it is the right one: **can the
existing cloud path be made faster from underneath** — a different model runner, a different model, or
different retrieval feeding the same provider.

So do not propose migrating to Hetz. Do not propose removing the cloud service. Those have been ruled
out by the Captain.

## What that leaves as the real options

1. **A faster model behind the same provider.** If the provider serves more than one model, a smaller
   or more latency-tuned one usually cuts time-to-first-token far more than any server-side tweak. Ask
   what models the provider actually offers — that list is the first fact you need and nobody has it.
2. **Retrieval before generation.** Fewer chunks, tighter top-k, or a cheaper embedding step means the
   stream opens sooner. State the answer-quality cost.
3. **Streaming verified end to end.** If anything is buffering the response before writing the first
   chunk, no model change helps. Prove it streams or prove it does not.

## What I still need from you, because I cannot reach it

Which provider serves that chat, and which model does it currently use. That is not recorded in our
rubric and it is not visible from here. Until we know it, nobody can say whether a faster model exists
to switch to, and the whole lane is guessing.

Please get: provider name, current model id, and the list of models the provider offers. Then measure
time-to-first-token and tokens-per-second separately against the current model.

Boundaries unchanged: no production change to hd2.ai without a measured before/after and a rollback; no
spend; no new provider.