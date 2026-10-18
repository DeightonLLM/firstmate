# GPT-6 Luna context and compaction test

Date: 2026-09-27.

This is a scout report from the isolated Firstmate worktree at `/home/hd2admin/.treehouse/firstmate-46aafc/6/firstmate`.

## Result

The safest supported Firstmate value for the selected Pi model `openai-codex/gpt-6-luna` is `contextWindow: 272000`, or leaving the model value unset so Pi's current catalog supplies 272000.

Do not transfer the separate `openai` provider override of 1050000 to `openai-codex`.

The installed Pi compaction implementation does not compact Luna at one quarter of its window.

With Pi's built-in defaults, the deterministic threshold is strictly above 255616 estimated tokens, which is 93.9768% of a 272000-token window.

The only installed early-compaction extension is explicitly gated to MiniMax M3 and therefore does not apply to Luna.

## Fresh Codex session evidence

Commands run:

```text
codex --version
codex --help
python3 ... /home/hd2admin/.codex/models_cache.json ... /home/hd2admin/.codex/config.toml
python3 ... /home/hd2admin/.codex/sessions/2026/09/27/rollout-2026-09-27T02-13-24-01a0e06c-8937-7733-af14-8365ed624b07.jsonl
```

Codex reported version `codex-cli 0.156.1`.

The fresh session record is `/home/hd2admin/.codex/sessions/2026/09/27/rollout-2026-09-27T02-13-24-01a0e06c-8937-7733-af14-8365ed624b07.jsonl`.

Its `turn_context` selected model is `gpt-6-astra` at `xhigh` effort, because this worker was launched with that model.

The same session's `task_started` and every `token_count` record advertise `model_context_window: 258400`.

The latest token record in that session has `last_token_usage.input_tokens: 97557` and `model_context_window: 258400`, approximately 37.8% of the runtime-advertised window.

The Codex local catalog is `/home/hd2admin/.codex/models_cache.json`, fetched at `2026-09-27T01:13:24.061502487Z` by client `0.156.1`.

For `gpt-6-luna`, the catalog records `context_window: 272000` and `effective_context_window_percent: 95` at lines 274-382, so the runtime advertised window is `272000 * 0.95 = 258400`.

The current `/home/hd2admin/.codex/config.toml` has no `model_context_window` or `model_auto_compact_token_limit` entry.

Therefore this session establishes four separate values: model/catalog window 272000, runtime advertised window 258400, no explicit Codex override in config, and no observed compaction event in this bounded session.

The Codex session was Astra, so its observed runtime values are evidence about Codex's interface and catalog plumbing, not a Luna execution test.

## Pi Luna catalog evidence

Commands run:

```text
pi --version
pi --list-models
nl -ba /home/hd2admin/.pi/agent/models-store.json | sed -n '632,674p'
nl -ba /home/hd2admin/.pi/agent/models.json | sed -n '1,14p'
```

Pi reports version `0.87.1`.

The `pi --list-models` row is:

```text
openai-codex  gpt-6-luna              272K     128K     yes       yes
```

The authoritative local `openai-codex` entry in `/home/hd2admin/.pi/agent/models-store.json:633-659` identifies `gpt-6-luna`, API `openai-codex-responses`, `contextWindow: 272000`, and `maxTokens: 128000`.

The file `/home/hd2admin/.pi/agent/models.json:3-11` contains a different provider namespace, `openai`, with a model override of `contextWindow: 1050000` for `gpt-6-luna`.

That 1050000 override does not match the selected provider `openai-codex` and must not be applied to the Firstmate Luna lane.

The current official OpenAI changelog also describes GPT-6 Luna pricing for prompts up to 272K input tokens: https://developers.openai.com/api/docs/changelog.

## Pi compaction source and synthetic test

The installed Pi package is `@earendil-works/pi-coding-agent 0.87.1`.

`dist/core/compaction/compaction.js:74-78` defines defaults of `enabled: true`, `reserveTokens: 16384`, and `keepRecentTokens: 20000`.

`dist/core/compaction/compaction.js:194-197` implements the trigger as `contextTokens > contextWindow - settings.reserveTokens`.

`dist/core/agent-session.js:2137-2138` calls that predicate for the automatic threshold path.

The exact bounded test command was:

```sh
node --input-type=module <<'JS'
import { shouldCompact } from '/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/compaction/compaction.js';
const settings={enabled:true,reserveTokens:16384,keepRecentTokens:20000};
for (const w of [272000,258400,1050000]) {
  const t=w-settings.reserveTokens;
  console.log(JSON.stringify({contextWindow:w,reserveTokens:settings.reserveTokens,thresholdExclusive:t,below:{tokens:t,compact:shouldCompact(t,w,settings)},above:{tokens:t+1,compact:shouldCompact(t+1,w,settings)},percentAtTrigger:(t+1)/w*100}));
}
JS
```

Observed output:

```json
{"contextWindow":272000,"reserveTokens":16384,"thresholdExclusive":255616,"below":{"tokens":255616,"compact":false},"above":{"tokens":255617,"compact":true},"percentAtTrigger":93.97683823529411}
{"contextWindow":258400,"reserveTokens":16384,"thresholdExclusive":242016,"below":{"tokens":242016,"compact":false},"above":{"tokens":242017,"compact":true},"percentAtTrigger":93.65982972136223}
{"contextWindow":1050000,"reserveTokens":16384,"thresholdExclusive":1033616,"below":{"tokens":1033616,"compact":false},"above":{"tokens":1033617,"compact":true},"percentAtTrigger":98.43971428571429}
```

The same package estimates text messages with a characters-divided-by-four heuristic when provider usage is unavailable, as implemented in `dist/core/compaction/compaction.js:131-150` and exercised by `estimateContextTokens`.

This is a reproducible source-level runtime test of the actual trigger predicate and token estimator.

It does not call an API, consume model quota, or mutate live Pi or Firstmate settings.

## Early-compaction extension check

The installed extension `/home/hd2admin/.pi/agent/extensions/m3-early-compaction.ts:14-17` returns true only when the model id contains `minimax-m3` or equals `m3`.

Its threshold is `COMPACT_AT = 0.50` at lines 7-11, with rearming below 0.25.

Because `openai-codex/gpt-6-luna` fails the MiniMax M3 gate, this extension cannot explain Luna compaction at 25% or 50%.

The project-local Firstmate Pi supervision extensions are watcher and turn-end lifecycle adapters, not context-window policies, as documented in `.agents/skills/harness-adapters/references/harness/pi.md:47-56`.

## Limitations and recommendation

The Codex worker session was launched as Astra, so no claim about Luna's provider-side runtime behavior is inferred from Astra's live turn.

The Codex catalog's 272000 model window and 258400 effective runtime value are authoritative local catalog/session evidence for this installation, while Pi's `openai-codex` catalog independently supplies 272000 for Luna.

The synthetic test proves Pi's automatic trigger boundary but cannot prove an upstream provider rejecting a request earlier than Pi's configured threshold.

No live Firstmate setting was changed, no service was restarted, and no authentication or credential file was read.

Firstmate should retain or set the Luna model entry to `openai-codex/gpt-6-luna` with `contextWindow: 272000` and the existing compaction reserve of 16384.

If an observed lane still compacts near 25%, capture its Pi session's model id, `contextWindow`, context usage event, loaded extension list, and compaction event reason before changing any value.

