# Independent review: M2.7 Pi GPT-6 Luna context override

## Verdict

The M2.7 report's central diagnosis is correct: the installed catalog identifies Luna as `openai-codex/gpt-6-luna`, while the live sanitized `models.json` view contains overrides only below provider key `openai`. Pi resolves `modelOverrides` from the config object for the provider currently being composed and indexes that map by the bare model ID. Therefore the current `providers.openai.modelOverrides.gpt-6-luna` entry cannot override the built-in `openai-codex/gpt-6-luna` model. An equivalent entry under `providers["openai-codex"].modelOverrides["gpt-6-luna"]` has the right provider and model lookup scope and is valid against the installed schema.

However, M2.7 overstates two conclusions:

1. Its evidence proves the override mechanism and provider mismatch, but it does **not** prove that Luna actually supports a 1,000,000-token context window. The installed catalog says 272,000; no authoritative capability source for 1,000,000 was presented or found in the inspected local material. Treat `1000000` as a proposed operator override, not a verified model limit.
2. A full Pi restart is not the smallest documented reload step. Installed `docs/models.md:66` says opening `/model` reloads `models.json`. A restart may also reload it, but is broader than necessary.

No settings were changed, no credential/auth file was read, no network was used, and Pi was not restarted or cut over.

## Installed build and catalog evidence

The active executable resolves to:

```text
/home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi
-> /home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js
package: @earendil-works/pi-coding-agent 0.87.1
```

Command (read-only):

```sh
jq '."openai-codex-responses"."gpt-6-luna" | {id,name,provider,contextWindow,maxTokens}' \
  /home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/data/openai-codex.json
```

Output:

```json
{
  "id": "gpt-6-luna",
  "name": "GPT-6 Luna",
  "provider": "openai-codex",
  "contextWindow": 272000,
  "maxTokens": 128000
}
```

This confirms the provider ID, bare model ID, and built-in 272K metadata. It does not establish any larger true service limit.

## Provider and override lookup scope

All references below are in the installed `@earendil-works/pi-coding-agent` package root shown above.

- `dist/core/provider-composer.js:312-326`: `composeModelProvider(providerId, ...)` calls `modelConfig.getProvider(providerId)` and later reads `config?.modelOverrides?.[model.id]`. Thus the first lookup key is the exact provider ID (`openai-codex`) and the override key within it is the bare model ID (`gpt-6-luna`), not `openai/gpt-6-luna`.
- `dist/core/model-config.js:265-273`: top-level `providers` entries are placed in a map using their JSON keys verbatim, and `getProvider(providerId)` performs an exact map lookup.
- `dist/core/provider-composer.js:39-65` (specifically 59-60): `applyModelOverride` replaces `contextWindow` and `maxTokens` when supplied.
- `docs/models.md:66`: `modelOverrides` changes metadata for an existing built-in or extension-provided model; unknown override IDs are ignored.

The M2.7 report cites the same substantive path at its sections 2-5. Its line numbers are slightly different from the currently installed files (for example, `ModelOverrideSchema` is now at `model-config.js:175`, not 157), but its quoted logic remains accurate.

## Schema verification

The proposed shape is accepted by the installed schema:

- `dist/core/model-config.js:175-194`: `ModelOverrideSchema` permits optional numeric `contextWindow` and `maxTokens`.
- `dist/core/model-config.js:195-205`: `ProviderConfigSchema` permits `modelOverrides` as a string-keyed record of `ModelOverrideSchema`.
- `dist/core/model-config.js:207-209`: `ModelsConfigSchema.providers` is a string-keyed record of provider configs.

Therefore this **shape and lookup path** are correct:

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
    }
  }
}
```

The schema only validates type/shape; it does not validate that `1000000` is a supported upstream limit.

## Sanitized live configuration evidence

I inspected `~/.pi/agent/models.json` only through a `jq` projection that emitted provider names and `modelOverrides`; it did not read or print `apiKey`, `auth`, `token`, or `secret` values.

Command:

```sh
jq '{provider_names:(.providers|keys), modelOverrides:(.providers|with_entries(select(.value.modelOverrides != null)|.value={modelOverrides:.value.modelOverrides}))}' \
  /home/hd2admin/.pi/agent/models.json
```

Relevant result:

```json
{
  "provider_names": ["openai"],
  "modelOverrides": {
    "openai": {
      "modelOverrides": {
        "gpt-6-luna": {"contextWindow": 1050000, "maxTokens": 128000},
        "openai/gpt-6-luna": {"contextWindow": 1050000, "maxTokens": 128000}
      }
    }
  }
}
```

This confirms M2.7's reported provider mismatch. Both shown Luna keys are ineffective for the built-in `openai-codex` provider: one is under the wrong provider, and the provider composer also expects a bare model ID rather than `openai/gpt-6-luna`.

## Authentication limitation review

M2.7's practical conclusion is correct: an isolated `pi --list-models` run with a fresh agent directory and only a metadata override will not list Luna when that isolated environment has no usable authentication for `openai-codex`.

Local evidence:

- `docs/models.md:29` says the model picker shows models whose providers have usable authentication.
- `docs/models.md:109-111` says models remain unavailable in `/model` until Pi can resolve credentials.
- `dist/core/model-runtime.js:174-193` performs provider auth checks and constructs `configuredProviders` from successful checks.
- `dist/core/model-runtime.js:166-172` filters the available model list by membership in `configuredProviders`.
- `dist/core/provider-composer.js:409-421` recognizes request-auth configuration from a configured API-key value, command, or resolvable environment reference; stored OAuth/API credentials and ambient provider auth are handled by the runtime auth check.

Qualification: saying the command categorically "requires a valid API key or OAuth token" is narrower than the implementation. Availability requires Pi to resolve usable provider authentication; possible sources include runtime keys, stored credentials, `models.json` configuration, provider environment variables, ambient provider auth, or extension-defined auth (`docs/models.md:19-23`). In the specific fresh isolated directory described by M2.7—with no credentials, API-key configuration, or auth-bearing environment—its observed `No models available` result is expected. I did not repeat the CLI test because the existing output plus source/docs establish the behavior, and a new check was not needed to resolve the review.

## Review of M2.7 recommendation

Correct:

- Use provider key `openai-codex`.
- Use override key `gpt-6-luna`.
- `contextWindow` and `maxTokens` are supported override fields.
- Leave unrelated existing provider config untouched in the smallest additive change.

Not established by its evidence:

- That `1000000` is the correct supported context window. The live config's existing intent is 1,050,000 under the wrong provider, while M2.7 recommends 1,000,000 without documenting why it changed the value. Either figure needs an authoritative capability basis before it is represented as correct.
- That a restart is necessary. The installed documentation identifies `/model` as the reload action.
- That expected display text must be exactly `1000K`; formatting was not independently verified and should not be treated as the acceptance criterion. The underlying resolved numeric metadata is the meaningful check.

## Smallest safe next step

Before implementation, establish the intended and supported Luna context limit from an authoritative provider/catalog source or an already-approved local policy. Once that number is decided, the smallest implementation is an additive `providers["openai-codex"].modelOverrides["gpt-6-luna"]` entry, followed by the documented `/model` reload and a read-only model metadata check. Do not copy the provider-qualified string into the inner override key, and do not remove the existing `openai` block as part of this narrowly scoped correction.

No implementation is authorized by this review.
