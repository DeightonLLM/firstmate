# Captain's question: is M3.1 auto-resetting, and does the model actually reply?

## 1. Actual replies obtained (not catalog evidence)

Two native Pi CLI runs against `minimax/MiniMax-M3.1-Flash-Preview`, both exit 0:

| Probe | Time (UTC) | Reply | API |
|---|---|---|---|
| `native-reply` | 2026-10-13T19:34:35Z | `M31_NATIVE_OK` | anthropic-messages |
| `fresh-reply` | 2026-10-13T19:51:53Z | `M31_FRESH_OK` | anthropic-messages |

Raw streams: `native-reply.jsonl` / `native-reply.stderr`, `fresh-reply.jsonl` / `fresh-reply.stderr`.
Usage on the fresh probe: 257 tokens, $0.0000446. The model genuinely answers. It is reachable, authentic and cheap.

## 2. Not an auto-reset

`~/.pi/agent/settings.json` was rewritten at 2026-10-13T20:51:02+0100 (mtime 1791921062, 36s before this read).
Diff against the last snapshot taken earlier today (`pi-settings.immediate-pre-rollback.json`):

- `defaultModel`: `MiniMax-M2.7` -> `MiniMax-M3.1-Flash-Preview`
- `enabledModels`: 13 entries pruned to 7, with `minimax/MiniMax-M3.1-Flash-Preview` added FIRST
- `lastChangelogVersion`: `1.2.0`
- No keys added or removed.

That is a deliberate curated replacement, not a reset. Actor/cause not established; no evidence of an
automatic revert mechanism. Note for the record: `minimax/MiniMax-M2.7-highspeed` was REMOVED from
`enabledModels` in that rewrite, while dispatch rules and the live inbox-repair worker still target it.

## 3. Real root cause of "not showing on new launches"

A fresh launch at 19:51:53Z — after both file updates — still reports:

```
Warning: No models match pattern "minimax/MiniMax-M3.1-Flash-Preview"
Warning: Model "MiniMax-M3.1-Flash-Preview" not found for provider "minimax". Using custom model id.
```

So the model answers, but Pi cannot resolve it to a registered provider model and falls back to a
**custom model id**. Two independent sources disagree:

| Source | M3.1 present? |
|---|---|
| `~/.pi/agent/models-store.json` (cached catalog, mtime 2026-10-13T20:19:24Z) | YES — `/minimax/models[3]`, contextWindow 1000000 |
| runtime provider model list used for session resolution | NO — falls back to custom id |

Consequence, observed: the live M3.1 worker shows a **204,800-token (205K) footer context**, which is
M2.7's window, not the 1M the catalog advertises for M3.1. Fallback metadata is being applied because
the model is unresolved. This confirms the mismatch is real and is not a display artifact.

## 4. Documented fix (docs/models.md:67)

> A `models` entry adds or replaces a model with the same ID on that provider. Use `modelOverrides` to
> change metadata for an existing built-in or extension-provided model... **Unknown override IDs are ignored.**

Because M3.1 is unknown to the provider, `modelOverrides` alone would be silently ignored. The admitted
correction is a `models` entry for the `minimax` provider in `~/.pi/agent/models.json`:

```json
{ "providers": { "minimax": { "models": [
  { "id": "MiniMax-M3.1-Flash-Preview", "name": "MiniMax-M3.1 Flash Preview",
    "contextWindow": 1000000, "maxTokens": 512000, "api": "anthropic-messages" }
] } } }
```

`/model` reloads the file; no reinstall or credential change. This preserves every existing OpenAI and
OpenAI-Codex override already in that file.

## 5. Why nothing has been applied

Writing `~/.pi/agent/models.json` from this session is outside the permitted root and was already refused
once (`MCP error -32602: path escapes project root`). No alternate path, tool, widened root or parent
execution was attempted. Applying the entry requires Captain, or an admitted route to that file.

## 6. Refuted

The partial report's leading hypothesis — "M3.1 is absent from `enabledModels`" — is **false**. Direct
read shows it present and first in that array. The actual gap is provider registration, not enablement.
---

# 7. APPLIED (Captain authorization 2026-10-13)

Captain approved the additive MiniMax registration and directed that the retiring Highspeed model be
removed from documentation as well.

## 7.1 Registration written

`~/.pi/agent/models.json` gained a single new `providers.minimax` block containing one `models` entry for
`MiniMax-M3.1-Flash-Preview`, mirroring the catalog metadata exactly (api anthropic-messages, baseUrl
https://api.minimax.io/anthropic, reasoning true, input text+image, contextWindow 1000000, maxTokens
512000, tiered cost above 512000, image resize limits). Existing `openai` and `openai-codex` override
blocks were left byte-identical; both still hold 6 overrides each.

Safety was established from the loader source before writing, not assumed:
- `applyModelsJson` maps base models and preserves each model's baseUrl when the config omits one.
- `modelFromJson` resolves baseUrl from definition, then provider config, then an existing same-provider
  model's defaults; `api` may be given per model.
- `composeApiKeyAuth` / `composeOAuthAuth` inherit the built-in provider credential when models.json
  supplies no `apiKey`, so MiniMax OAuth is untouched.
- `hasOverrides`-style guard only throws when a provider block specifies none of baseUrl/headers/compat/
  modelOverrides/models; a `models` entry alone is a valid provider block.

## 7.2 Validation — actual fresh launch, post-change

Command: `pi --provider minimax --model minimax/MiniMax-M3.1-Flash-Preview --thinking medium --mode json
--no-session --no-tools --no-skills --no-context-files --no-extensions --no-mcp`

- exit code 0
- **stderr now empty** — both prior warnings are gone:
  `No models match pattern "minimax/MiniMax-M3.1-Flash-Preview"` and
  `Model "MiniMax-M3.1-Flash-Preview" not found for provider "minimax". Using custom model id.`
- assistant text: `M31_REGISTERED_OK`, stopReason `stop`
- model/provider/api reported: `MiniMax-M3.1-Flash-Preview` / `minimax` / `anthropic-messages`

`pi --list-models minimax/MiniMax-M3.1-Flash-Preview` now reports context **1M**, max-out **512K**,
thinking yes, images yes — matching the catalog, replacing the 204.8K fallback observed before.

Raw evidence: `registered-reply.jsonl`, `registered-reply.stderr`.
This is a fresh-launch resolution plus a real model reply, not catalog-only evidence.

## 7.3 Highspeed retirement applied

`minimax/MiniMax-M2.7-highspeed` removed from the active guidance layer:

- `config/crew-dispatch.json` — the above-50% Highspeed rule was deleted; bounded work now routes to
  regular `minimax/MiniMax-M2.7`, or native M3.1 where warranted. Verified by parse: no rule or default
  selects any `highspeed` model. (An intermediate malformed-JSON state was introduced by the edit and
  caught by validation before any dispatch used it; corrected and re-verified clean.)
- `data/captain.md` — added an explicit Highspeed retirement clause and marked `M27HS` invalid for new
  work in the label standard.
- `data/herdr-label-standard-20261012/instructions.md` — `M27HS` marked retired.
- `data/backlog.md` — active child-intake model policy updated.

Historical dated evidence was deliberately NOT rewritten: prior reports, settings snapshots, session
transcripts, and already-dispatched briefs remain as records of what was true when written. The
inbox-repair worker still executes on Highspeed; per Captain direction it was left running and
uninterrupted rather than restarted.
