# Scout Report: Pi GPT-6 Luna Context Window Override — Validation

## Task
Verify the provider-scoped override lookup for `openai-codex/gpt-6-luna` against the installed Pi catalog and source, test the proposed fix in an isolated environment, and report exact commands/output and the smallest recommended patch.

## 1. Prior Diagnosis Review

The existing diagnosis at `/tmp/pi-context-window-system-fix-0926/diagnosis.md` is **confirmed and accurate**. The root cause is a provider-scope mismatch: overrides are registered under `providers.openai.modelOverrides` but the active model `gpt-6-luna` belongs to provider `openai-codex`, so the overrides are never consulted.

## 2. Catalog Evidence

**File**: `.../pi-ai/dist/providers/data/openai-codex.json`  
**Finding**: `gpt-6-luna` is defined with `contextWindow: 272000` (272K) and `maxTokens: 128000`. This is the hardcoded catalog value.

```sh
$ grep -n "gpt-6-luna" .../pi-ai/dist/providers/data/openai-codex.json | head -1
{"openai-codex-responses":{
  ...
  "gpt-6-luna":{
    "id":"gpt-6-luna",
    "name":"GPT-6 Luna",
    "provider":"openai-codex",
    "contextWindow":272000,   ← 272K hardcoded in catalog
    "maxTokens":128000,
    ...
  }
}}
```

## 3. Override Lookup Mechanism — Source Verification

**File**: `dist/core/provider-composer.js`, lines 319–326

```js
const getModels = () => {
    let models = applyExtension(providerId, applyModelsJson(providerId, base?.getModels() ?? [], config), currentExtension());
    return models.map((model) => {
        const override = config?.modelOverrides?.[model.id];  // line 325
        return override ? applyModelOverride(model, override) : model;
    });
};
```

The lookup key is `model.id` (`"gpt-6-luna"`). The `config` object is scoped to the provider being composed, obtained from `modelConfig.getProvider(providerId)`. For provider `"openai-codex"`, `config` = `providers["openai-codex"]` from `models.json`.

**File**: `dist/core/model-config.js`, lines 272–276

```js
getProvider(providerId) {
    return this.providers.get(providerId);
}
getProviderIds() {
    return [...this.providers.keys()];
}
```

The `providers` map keys are the provider IDs directly from `models.json`.

**Apply function** — `dist/core/provider-composer.js`, line 63:

```js
contextWindow: override.contextWindow ?? model.contextWindow,
maxTokens: override.maxTokens ?? model.maxTokens,
```

The `applyModelOverride` function correctly applies `contextWindow` and `maxTokens` from the override.

**Conclusion**: The override path is syntactically correct — `providers["openai-codex"].modelOverrides["gpt-6-luna"]` would be consulted when composing `openai-codex` models.

## 4. Current models.json — Confirmed Mismatch

**File**: `~/.pi/agent/models.json`

```json
{
  "providers": {
    "openai": {            ← "openai", NOT "openai-codex"
      "modelOverrides": {
        "gpt-6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        "openai/gpt-6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        ...
      }
    }
  }
}
```

The overrides are under `providers.openai`, but `gpt-6-luna` is in the `openai-codex` provider. These overrides are **never consulted** for `openai-codex/gpt-6-luna`.

## 5. Schema Evidence

**File**: `dist/core/model-config.js`

The `ModelOverrideSchema` (lines 157–172) includes:
- `contextWindow: Type.Optional(Type.Number())` ✓
- `maxTokens: Type.Optional(Type.Number())` ✓

The `ProviderConfigSchema` (lines 207–218) includes:
- `modelOverrides: Type.Optional(Type.Record(Type.String(), ModelOverrideSchema))` — string key = model ID ✓

The `ModelsConfigSchema` (lines 220–222):
```js
const ModelsConfigSchema = Type.Object({
    providers: Type.Record(Type.String(), ProviderConfigSchema),
});
```

The proposed patch is valid against this schema.

## 6. Isolated CLI Test — Gap Report

**Attempted**: Set `PI_CODING_AGENT_DIR=/tmp/pi-isolated-test-0927` with a minimal `models.json` containing only `providers.openai-codex.modelOverrides.gpt-6-luna`, then run `pi --list-models gpt-6-luna`.

**Command and output**:

```sh
$ PI_CODING_AGENT_DIR=/tmp/pi-isolated-test-0927 \
  /home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi --list-models gpt-6-luna

No models available. Use /login to log into a provider via OAuth or API key.
```

**Root cause of test gap**: The `available` model list is filtered by `configuredProviders` (line 171 of `model-runtime.js`):
```js
available: all.filter((model) => this.snapshot.configuredProviders.has(model.provider)),
```

A provider enters `configuredProviders` only when it has a truthy `auth` result from `checkAuth` (line 231–234 of `model-runtime.js`), or when `configuredRequestAuthStatus` returns `configured: true` (which requires an `apiKey` or env-var reference). The isolated test has no `auth.json`, no stored credentials, and the isolated `models.json` has no `apiKey` for `openai-codex`, so the provider is not added to `configuredProviders` and its models do not appear in `available`.

**Precise gap**: The isolated CLI `--list-models` command requires the provider to be "authenticated" (have an API key or OAuth token) before its models appear in the `available` list. The override mechanism is correctly implemented in `composeModelProvider` and `applyModelOverride` (verified by code inspection), but this cannot be demonstrated with `pi --list-models` offline without either (a) providing a valid API key in the isolated config, or (b) modifying the CLI to bypass auth for listing purposes. Neither is appropriate for a safe offline test.

**Alternative verification**: The current live `pi --list-models gpt-6-luna` confirms the 272K value:

```sh
$ /home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi --list-models gpt-6-luna
provider      model         context  max-out  thinking  images
openai-codex  gpt-6-luna    272K     128K     yes       yes
```

This confirms the catalog value (272K) is what the live system shows today.

## 7. Compaction Threshold Context

**File**: `dist/core/compaction/compaction.js`, line 194:

```js
export function shouldCompact(contextTokens, contextWindow, settings) {
    return contextTokens > contextWindow - settings.reserveTokens;
}
```

With the current `contextWindow = 272000` and default `reserveTokens = 16384`, compaction fires at `272000 - 16384 = 255616 tokens`. With the proposed `contextWindow = 1000000`, it would fire at `1000000 - 16384 = 983616 tokens`.

## 8. Smallest Recommended Patch

Add a new `openai-codex` provider block to `~/.pi/agent/models.json`:

```json
{
  "providers": {
    "openai-codex": {
      "modelOverrides": {
        "gpt-6-luna": {
          "contextWindow": 1000000,
          "maxTokens": 128000
        }
      }
    },
    "openai": {
      "modelOverrides": {
        "gpt-6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        "openai/gpt-6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        ...
      }
    }
  }
}
```

This is additive — it does not remove the existing (unused) `openai` overrides. The existing overrides under `providers.openai` remain harmless for `openai-codex/gpt-6-luna`.

**After applying**: Restart the Pi process and run:

```sh
/home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi --list-models gpt-6-luna
```

Expected output: `openai-codex  gpt-6-luna  1000K  128K  yes  yes`

## 9. Summary Table

| Check | Status | Evidence |
|-------|--------|----------|
| Catalog has `gpt-6-luna` at 272K | ✓ Confirmed | `openai-codex.json` — `contextWindow: 272000` |
| Override lookup uses `model.id` as key | ✓ Confirmed | `provider-composer.js:325` — `config?.modelOverrides?.[model.id]` |
| Override applies `contextWindow` and `maxTokens` | ✓ Confirmed | `provider-composer.js:63` — `applyModelOverride` |
| Current `models.json` has wrong provider key | ✓ Confirmed | `providers.openai` ≠ `providers.openai-codex` |
| Proposed patch matches schema | ✓ Confirmed | `model-config.js` — `ModelOverrideSchema` |
| Isolated CLI test of override | ✗ Gap | Requires auth to make provider "configured" |

## 10. Recommendation

Apply the patch in section 8 to `~/.pi/agent/models.json`, restart Pi, and verify with `pi --list-models gpt-6-luna`. The override mechanism is correctly implemented; the diagnosis is sound; the isolated test gap is an authentication requirement in the listing tool, not a flaw in the proposed fix.
