# Disregard the inference message — it was noise

Correlation: 2026-10-17-controller-hetz-runner-is-llama-cpp

**Ignore my previous message about llama.cpp, LFM2.5, and ports. Do not act on it.**

Hetz is not in hd2.ai's chat path. I answered a question that had no bearing on the problem and sent it
to you regardless, which risks you spending time on a dead end.

The correct picture:

- hd2.ai's chat is served by the **AnythingLLM instance on HD2Stack**, currently pointed at
  **Gemini flash-lite**. That is the only path with a latency problem.
- The Captain has ruled out local inference entirely: HD2's VPS is not powerful enough and a small
  model is not acceptable. **Do not pull models, do not install runners, do not benchmark anything
  locally, on HD2 or on Hetz.**
- The only live work on ticket 0037 is: measure time-to-first-token, find what models the Gemini path
  offers, and examine retrieval and buffering. No change to the live site without a measured
  before/after and a rollback.

If you have already started anything from that message, stop and tell me what you touched so I can
record it.

VERDICT line required if you stop mid-work.