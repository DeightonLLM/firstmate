# Independent Checker Report: Brandon Pi Runtime Audit
**Task**: `pi-runtime-checker` (independent verification)
**Date**: 2026-10-02
**Scope**: Read-only diagnostic — no mutations
**Checker**: Parent coordinator w1E:p6 → w1E:pA

---

## 1. models.json Override Structure — VERIFIED

**Schema path** (from Pi docs `docs/models.md`):
```
providers.<provider-name>.modelOverrides.<model-id>
```

**Current installed `~/.pi/agent/models.json`**:
```json
{
  "providers": {
    "openai": {
      "modelOverrides": {
        "gpt-6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        "gpt-5.6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        ...
      }
    },
    "openai-codex": {
      "modelOverrides": {
        "gpt-6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        "gpt-5.6-luna": { "contextWindow": 1050000, "maxTokens": 128000 },
        ...
      }
    }
  }
}
```

**Correct schema for gpt-6-luna via Codex**: `providers.openai-codex.modelOverrides.gpt-6-luna.contextWindow`

---

## 2. Report Recommendation: SCHEMA-COMPLIANT ✅

The report recommended:
```
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
```

**Verification**:
- ✅ Correct provider key (`openai-codex`, not `openai`)
- ✅ Correct model key (`gpt-6-luna`, exact match to catalog ID)
- ✅ Uses `contextWindow` field (supported override field per docs)
- ℹ️ Report recommended 1,000,000; current config has 1,050,000 — both are schema-valid

---

## 3. Catalog contextWindow — VERIFIED

**Catalog source**: `openai-codex.json` (inside `pi-ai` package)

| Model | Catalog contextWindow | Current Override |
|-------|----------------------|-----------------|
| `gpt-6-luna` | **272,000** | **1,050,000** ✅ |

The override correctly supersedes the catalog value of 272,000 with 1,050,000.

---

## 4. Compaction Threshold — VERIFIED

**Formula** (from `dist/core/compaction/compaction.js:173-176`):
```js
export function shouldCompact(contextTokens, contextWindow, settings) {
    return contextTokens > contextWindow - settings.reserveTokens;
}
```

**Settings** (defaults):
- `compaction.enabled`: true
- `compaction.reserveTokens`: **16,384**

**Computed thresholds**:

| Config | contextWindow | Compaction fires at |
|--------|--------------|---------------------|
| Catalog only | 272,000 | **255,616** (93.98%) |
| With override | 1,050,000 | **1,033,616** (98.44%) |

The active override raises the compaction threshold by ~778,000 tokens.

---

## 5. Report Accuracy Assessment

| Finding | Report | Checker Verification |
|---------|--------|----------------------|
| Import error root cause (stale chunk hash) | ✅ Stale bundle reference | ✅ Confirmed — `J5WXPPPC` absent, `A6EXUBG6` present |
| m3-early-compaction extension absent | ✅ Not found | ✅ Confirmed — no such file exists |
| Compaction formula | ✅ `contextTokens > contextWindow - reserveTokens` | ✅ Verified at line 176 |
| openai-codex override scope | ⚠️ Reported as "wrong provider key — inert" | 🔄 **Updated**: override now exists at correct path |
| Compaction threshold (catalog) | 255,616 | ✅ Confirmed |

**Status**: Report is substantially accurate. The "inert override" finding appears outdated — `providers.openai-codex.modelOverrides.gpt-6-luna` is now present and active with contextWindow 1,050,000.

---

## 6. Blocker

**None.** All verification paths succeeded.

---

## 7. Summary

```
✅ models.json schema: providers.<provider>.modelOverrides.<model-id>
✅ gpt-6-luna override path: providers.openai-codex.modelOverrides.gpt-6-luna
✅ Override present: contextWindow = 1,050,000
✅ Catalog value: contextWindow = 272,000 (openai-codex.json)
✅ Compaction formula verified from source
✅ Active compaction threshold: 1,033,616 tokens (with override)
✅ Report recommendation: schema-compliant
ℹ️ Report's "inert override" finding: superseded by current config
```

---

## Files Referenced

- `/home/hd2admin/.pi/agent/models.json` — current override config
- `~/.nvm/.../pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/data/openai-codex.json` — catalog (gpt-6-luna contextWindow: 272000)
- `~/.nvm/.../pi-coding-agent/dist/core/compaction/compaction.js:173-176` — compaction formula
- `~/.nvm/.../pi-coding-agent/docs/models.md` — override schema
- `~/.nvm/.../pi-coding-agent/docs/settings.md` — compaction settings defaults
- `data/brandon-pi-runtime-audit-20261002/report.md` — original report
