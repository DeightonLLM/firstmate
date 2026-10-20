# Scout Report: Brandon Pi Runtime Import Error & Compaction Settings Audit
**Task**: `brandon-pi-runtime-audit-20261002`
**Date**: 2026-10-02
**Scope**: Read-only diagnostic — no code/service changes

---

## 1. w1D:p2 Import Error — Root Cause

**Reported error**:
```
Cannot find module /home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/chunks/anthropic-messages-J5WXPPPC.js
```

### Chunk Presence Check

| Check | Result |
|-------|--------|
| `anthropic-messages-J5WXPPPC.js` (reported missing) | **ABSENT** |
| `anthropic-messages-A6EXUBG6.js` (closest match) | PRESENT |
| Total chunks in bundle | 66 files |

The chunk with hash suffix `J5WXPPPC` does not exist in the installed bundle. The only `anthropic-messages-*` chunk present is `anthropic-messages-A6EXUBG6.js` — different hash, different build.

### Diagnosis

The import references a chunk hash (`J5WXPPPC`) that does not correspond to any file in the installed `@earendil-works/pi-coding-agent@0.99.1` bundle. This indicates a **stale bundle reference**, not a missing dependency. Possible causes:

1. A prior Pi process held a stale in-memory module map from an older build
2. The w1D:p2 pane (`system-ops`, GPT-6 Luna, open-codex harness) loaded with a cached session state that referenced a previous bundle version
3. A parallel Pi process for a different project has a mismatched bundle

The `anthropic.js` entry chunk and `anthropic-messages-A6EXUBG6.js` are both present — the module system can still load the Anthropic provider. The `J5WXPPPC` hash is simply orphaned from a prior build.

---

## 2. Pi Package Version

```
/home/hd2admin/.nvm/versions/node/v22.23.2/lib
└── @earendil-works/pi-coding-agent@0.99.1

$ pi --version
0.99.1
```

- **Node**: v22.23.2 (via nvm)
- **Pi**: 0.99.1
- **pi-coding-agent**: 0.99.1 (version-aligned)

No version mismatch detected.

---

## 3. m3-early-compaction Extension — Absent

**Searched path**: `/home/hd2admin/kun-agent-workspace/.pi/extensions/m3-early-compaction.ts`

**Result**: **NOT FOUND**

Installed `.pi/extensions/*.ts` files:

```
fm-branch-supervision.ts
fm-calm.ts
fm-primary-pi-watch.ts
fm-primary-turnend-gard.ts
```

Plus `fm-calm-*` library helpers. No `m3-early-compaction.ts` exists anywhere in the extensions directory.

The extension referenced in the task does not exist in this environment. No compaction settings are overridden by a custom extension.

---

## 4. Compaction Behavior (from Prior Evidence)

**Source**: `data/pi-luna-context-scratch-validation-0927/report.md`

The default compaction threshold is derived from the catalog `contextWindow` minus `reserveTokens`:

```js
// dist/core/compaction/compaction.js, line 194
export function shouldCompact(contextTokens, contextWindow, settings) {
    return contextTokens > contextWindow - settings.reserveTokens;
}
```

**Current defaults for `gpt-6-luna`**:

| Parameter | Value | Source |
|-----------|-------|--------|
| `contextWindow` | 272,000 | `openai-codex.json` catalog |
| `reserveTokens` | 16,384 | default settings |
| Compaction fires at | 255,616 tokens (93.98%) | calculated |

**Prior report finding**: The existing `models.json` override was registered under `providers.openai` but `gpt-6-luna` belongs to provider `openai-codex`, so the override was never applied. The catalog 272K value applies.

**No `m3-early-compaction` override exists** — compaction uses the catalog threshold with default reserve.

---

## 5. Smallest Supported Recovery Actions

### For the import error (w1D:p2):

1. **Restart the w1D:p2 pane** (kill and relaunch the Pi process). This clears any stale in-memory module map and forces a fresh bundle resolution against the installed 0.99.1 files.
2. If the error persists after restart, the pane's session state snapshot is carrying a stale reference — a `/new` or `/resume` in that pane will reset the module loader.

No reinstall of `pi-coding-agent` is needed; the bundle is complete (66 chunks present).

### For compaction (if early compaction is desired):

The `m3-early-compaction` extension does not exist. To implement earlier compaction for `gpt-6-luna`, the correct path is:

1. Add a properly-scoped override to `~/.pi/agent/models.json` under `providers.openai-codex` (not `providers.openai`):

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

2. This raises the compaction threshold to `1,000,000 - 16,384 = 983,616 tokens`.
3. Restart Pi to pick up the config change.

**Note**: The prior report's `providers.openai` override for `gpt-6-luna` is inert because it is in the wrong provider namespace. The fix is the same scope (additive `models.json` edit), scoped to `openai-codex`.

---

## 6. Summary

| Finding | Status |
|---------|--------|
| `anthropic-messages-J5WXPPPC.js` | Absent — stale bundle reference |
| `anthropic-messages-A6EXUBG6.js` | Present |
| pi-coding-agent version | 0.99.1 aligned |
| Pi version | 0.99.1 |
| `m3-early-compaction.ts` | Not present — extension does not exist |
| Compaction threshold for gpt-6-luna | 255,616 tokens (catalog 272K − 16,384 reserve) |
| Openai-codex override in models.json | Wrong provider key — inert |

**Smallest recovery**: Restart w1D:p2 pane to clear stale module map. No reinstall needed.

---

## Files Referenced

- `/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/chunks/` — bundle chunk directory
- `~/.pi/agent/models.json` — model override config
- `dist/core/compaction/compaction.js:194` — compaction threshold formula
- `dist/providers/data/openai-codex.json` — catalog (contextWindow: 272000)
- `/home/hd2admin/kun-agent-workspace/.pi/extensions/` — extension directory (m3-early-compaction absent)
- `/home/hd2admin/kun-agent-workspace/data/pi-luna-context-scratch-validation-0927/report.md` — prior evidence
