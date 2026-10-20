# hd2.ai chat — speed ticket, with a routing correction to check first

Correlation: 0037-hd2-ai-chat-time-to-first-token

## 1. First, the host identity — check this before you start

The Captain said "KVM1, I believe, unless we moved it." Our rubric answers it, but **read the rubric
rather than trust my summary**:

- `hd2.ai` is the **live WordPress site on Hostinger `srv797124`**, alias `srv797124-hd2`. It is the
  HD2.ai edge/review host.
- It is **not** the HD2Stack Contabo host, and it is **not** Hetz.

Confirmed in `docs/system-context/hosts.yaml` and `GLOSSARY.md`. If that contradicts what you measure
locally, **the measurement wins and the document is the defect** — report it, do not obey it.

One important consequence: the AnythingLLM instance that serves `llm.hd2.ai` runs on **HD2Stack**, not on
the site host. The site's chat does not have to run where the site is served from. Verify which is
actually in the path before assuming.

## 2. The work

The chat works. The problem is **time to first token**. We are paying for a cloud model service that is
slower than local inference on Hetz, and the Captain suspects our Ollama model is an old one.

**Measure before changing anything.** Split two numbers and never conflate them:

| Metric | Meaning | Typical fix |
|---|---|---|
| **Time to first token** | gap before generation starts | cold start, remote provider latency, RAG retrieval blocking generation, sync steps before the stream opens |
| **Tokens per second** | generation speed once started | model size, quantisation, local vs remote, GPU/CPU contention |

A slow first token with fine tokens/sec is a retrieval or startup problem. Fine first token with slow
tokens/sec is a model-serving problem. They have completely different fixes.

**Establish with evidence:** which model answers today, which provider, remote or local, where the RAG
pipeline runs, the current chunk size and overlap, the retrieval depth, and anything that runs
*synchronously* before the stream opens.

Then state the bottleneck before proposing anything. Test these as hypotheses, do not assume them:
model cold-start; remote provider time-to-first-token; chunk size and overlap; number of chunks
retrieved; any pre-generation step that should be async.

**If you change chunking or retrieval, say what it does to answer quality.** Speed bought by worse
answers is not a fix.

## 3. Boundaries

- No production change to hd2.ai without a measured before and after, and a working rollback.
- No spend, and do not add a provider or buy a model without the Captain.
- Nothing on Hetz, HD2Stack or elevatesci in this lane — it is a read-and-measure lane until the
  Captain approves a change.

## 4. Deliverable

`report-hd2ai-ttft.md` with: the measured baseline (both metrics, with the commands and their output),
the identified bottleneck with its evidence, the ranked options with their expected effect, and a
recommendation. If the bottleneck is the cloud provider being slower than the local option, say that
plainly and quantify the gap — that is the decision the Captain will actually be making.

Final line exactly `VERDICT: PASS <one line>` or `VERDICT: FAIL <one line>`.