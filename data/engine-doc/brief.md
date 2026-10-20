# WO-0017 - Document the Core Distro AI engine, and map the HD2 -> Hetz migration (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. Worktree: /tmp/wt-engine, branch docs/engine.

## Captain's instruction
"the bot should be running from its own ollana on hetz [with] ornith model - this right here
needs properly documenting as the engine"

## What is TRUE today (verified, do not re-derive)
```
ENGINE    Ollama, Hetz, 127.0.0.1:11434  (localhost only; public 11434 correctly closed)
MODEL     ornith-1.5:9b   6.6GB   qwen35 family   (the only model installed)
CURRENT   https://core-distro.com  ->  data-base-api-url="https://llm.hd2.ai/api/embed"
          embed id 0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2, assistant "Core Distro Assistant"
SHOULD    own Ollama on Hetz with ornith-1.5:9b
```

**So the LIVE site currently runs its chatbot on HD2's AnythingLLM. That is the defect.**
Staging inherits the same config from the same source.

## Deliverable 1 - the documentation, and this is the primary ask
**`docs/ai-engine.md`** - a real engineering document, not a note:
- what the engine IS: Ollama + ornith-1.5:9b, on Hetz, and why (own data boundary, no HD2 dependency
  for Core Distro customer conversations)
- model facts: name, size, family, digest, how it is served, what is exposed and what is NOT
- the current wrong configuration and the correct target configuration, side by side
- the migration path from HD2 AnythingLLM to the Hetz Ollama
- **explicitly**: what data boundary this protects and why customer chat must not reach HD2
- how to verify the engine is the engine (commands anyone can run)

## Deliverable 2 - the migration map, NOT the migration
Map what must change to move the chatbot from `llm.hd2.ai/api/embed` to the Hetz Ollama:
- which files/config carry the URL and embed id
- what API shape the widget needs vs what Ollama exposes (this is the hard part - say so if it is)
- whether anything needs to be exposed beyond localhost, and the safe way to do it
- what breaks, what must stay on HD2, and what must NOT be touched
- **Do NOT migrate anything. Do NOT change the live site. Do NOT expose 11434.**
  This is a map for a human decision.

## Rules
- READ ONLY on everything. No edits to the app, no deploys, no nginx, no DNS.
- **Never touch srv1137994 / elevatesVPS / Aminolifesciences.**
- **Never expose or restart Ollama. Never bind 11434 to anything but localhost.**
- Commit on docs/engine. **No merge, no push, no rebase of main.**
- `bash <script>` RUNS. `bash -c` / `python3 -c` BLOCKED - write a script file.

## Report
data/engine-doc/report.md with a summary and one VERDICT line on whether the migration is
straightforward or carries real risk. Be blunt about the risk.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
