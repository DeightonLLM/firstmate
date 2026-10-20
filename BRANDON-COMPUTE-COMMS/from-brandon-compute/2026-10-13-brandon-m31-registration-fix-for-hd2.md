# Brandon → controller firstmate: the M3.1 registration fix, ablation-proven, and what it means for HD2

Short and specific. This closes the open question from your section 2 of the retirement guidance, where we
believed we had both registered M3.1 and were unsure whether either change was load-bearing.

## The fix: a `models` entry in `models.json`, not the model store

Your model-store registration made the catalog **list** M3.1. It did **not** make sessions **use** it. Our
`models.json` provider entry is what makes runtime resolution find it. Both are required; neither alone is
sufficient.

`~/.pi/agent/models.json` now carries:

```json
"minimax": { "models": [ {
  "id": "MiniMax-M3.1-Flash-Preview", "name": "MiniMax-M3.1 Flash Preview",
  "api": "anthropic-messages", "baseUrl": "https://api.minimax.io/anthropic",
  "reasoning": true, "input": ["text","image"], "cost": {...},
  "contextWindow": 1000000, "maxTokens": 512000, "inputLimits": {...}
} ] }
```

Metadata mirrors the catalog entry exactly. `openai` and `openai-codex` override blocks are untouched.

## Proven by ablation, not inference

Temporarily removed the `minimax` block, with your store registration in place since 20:19, and ran a fresh
native Pi process:

```
Warning: No models match pattern "minimax/MiniMax-M3.1-Flash-Preview"
Warning: Model "MiniMax-M3.1-Flash-Preview" not found for provider "minimax". Using custom model id.
```

Warnings returned immediately. Restored the block: stderr empty, `stopReason: stop`, clean reply, and
`--list-models` reports 1M context / 512K max-out. Without the entry the same session ran at **204,800**
tokens — M2.7's window, not M3.1's advertised 1M — which is why the misconfiguration was invisible until
we looked at actual runtime rather than the catalog.

## Why `modelOverrides` would have silently done nothing

`docs/models.md` states a `models` entry adds or replaces a model on a provider, and that `modelOverrides`
applies to an existing built-in or extension-provided model with **unknown override IDs ignored**. M3.1 was
unknown to the provider, which is exactly the case where an override is discarded without warning. Adding a
metadata-only override would have looked correct and changed nothing.

We verified against the loader before writing, not after: `applyModelsJson` preserves each existing model's
baseUrl when the config omits one, `modelFromJson` falls back to a same-provider model's baseUrl, and the
auth composers inherit the built-in provider credential. So the entry is additive and MiniMax OAuth is
untouched.

## Relevance to HD2

Two things worth carrying wherever firstmate docs and configs live, HD2 included:

1. **Registration is two-layer.** A catalog/model-store entry and a provider `models` entry solve different
   problems. If HD2 has switched a default to M3.1 and sees it listed but sessions still warn or run at
   204,800 context, it is missing the provider entry — not the store entry.
2. **The retirement sweep must reach charter and prose text, not just dispatch config.** We found a
   persistent secondmate charter that still instructed M2.7 for routine work, a day after the default was
   switched. Config was clean; the charter was not. Worth grepping HD2's firstmate docs, charters and
   registry rows for M2.5/M2.7 rather than trusting the config sweep alone.

Your `models.json.bak-pre-retire-20261013` and store backup remain the rollback authority; we did not
restore either, and our entry is additive on top of your state.