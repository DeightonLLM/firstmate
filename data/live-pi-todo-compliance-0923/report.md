# Live Pi TODO Compliance — Pane Reconciliation Report
**Task:** live-pi-todo-compliance-0923  
**Date:** 2026-09-23  
**Scope:** Reconcile retired pane references (`default:w2:pR`, `default:w2:pS`) against current tracked launch instructions and session evidence.

---

## Stale Pane References

The original audit examined two live Pi panes:
- `default:w2:pR` — CBD scout pane
- `default:w2:pS` — Elevate scout pane

Both are now **retired**; no session evidence for either remains observable. Their absence is consistent with the brief instruction to "do not reopen those client tasks or steer client workers." No further evidence can be gathered from those panes.

---

## Current Tracked Launch Instructions

### `bin/fm-brief.sh` — shared tracked scaffold ✅ FIXED

The shared tracked scaffold at `bin/fm-brief.sh` (branch `pi-todo-worker-defaults`, commit `1d3846b3`, 4 commits ahead of `origin/main`) now contains:

```
# Pi Worker Defaults
For Pi workers: create one concise checklist with the Pi `todo` tool and print the full
list into the pane. For other harnesses: print the checklist as plain text in the pane.
Keep exactly one step active and update the same checklist in place...
```

**Ship scaffold** (rules 1–7, unnumbered Pi Worker Defaults section):
- Rule 1: Never push / Rule 2: Stay in worktree / Rule 3: Use gh-axi, chrome-devtools-axi / Rule 4: Report status / **(unnumbered) Pi Worker Defaults** / Rule 5: obstacle blocker / Rule 6: human decision / Rule 7: no-mistakes daemon

**Scout scaffold** (same structure, rules 1–7, unnumbered Pi Worker Defaults):
- Rules 1–4 identical; Pi Worker Defaults unnumbered; Rules 5–7 renumbered correctly (no duplicate Rule 6)

**Secondmate charter scaffold**: includes Pi Worker Defaults verbatim.

### `config/brief-include.md` — main home captain-private ⚠️ OUT OF DATE

The main home's `config/brief-include.md` (3139 bytes, captain-private, not inherited by secondmate homes) contains:
```
## Pi Worker Defaults
At task start, create one concise checklist with Pi's `todo` tool and print the full list into the pane.
```
This is the **old text** — it lacks the "For Pi workers / For other harnesses" distinction added to `bin/fm-brief.sh`. Captain-private; updating it is a separate captain decision.

---

## Provable vs. Unprovable

| Item | Status |
|---|---|
| `bin/fm-brief.sh` Pi Worker Defaults — correct "For Pi / For other" text | ✅ Provable (commit `1d3846b3`) |
| `bin/fm-brief.sh` Rule numbering sequential (no duplicate Rule 6) | ✅ Provable (same commit) |
| `brief-include.md` Pi Worker Defaults — old text without distinction | ✅ Provable (file read) |
| `brief-include.md` intentionally not inherited by secondmate homes | ✅ Provable (AGENTS.md §1, captain confirmed) |
| Original pane output in `default:w2:pR` / `default:w2:pS` | ❌ Unobservable — panes retired |
| Current live pane TODO state for any active CBD/Elevate worker | ❌ Unobservable without reopening those tasks |

---

## Findings

1. **`bin/fm-brief.sh` (shared tracked) is correctly fixed.** All three scaffold variants (ship, scout, secondmate charter) now include Pi Worker Defaults with the correct Pi vs. non-Pi distinction, and Rule numbering is sequential.

2. **`brief-include.md` (main home, captain-private) has stale text.** It still reads "At task start, create one concise checklist with Pi's `todo` tool..." without the "For other harnesses" clause. This is captain-private, not inherited by secondmates, and updating it is the captain's decision.

3. **Retired pane references are closed.** `default:w2:pR` and `default:w2:pS` cannot be examined further without reopening client tasks, which the brief instruction prohibits.

4. **The audit's root-cause finding stands.** The original non-compliance was caused by `config/brief-include.md` not being inherited by secondmate homes (AGENTS.md §1), so the enforcement was supervisor-steered. The fix in `bin/fm-brief.sh` addresses this by making Pi Worker Defaults part of the shared tracked scaffold itself, effective for all future briefs in all homes.

---

## Recommendations

1. **Apply `pi-todo-worker-defaults` branch to main** (`1d3846b3`, 4 commits). This deploys the fix to `bin/fm-brief.sh` and `tests/fm-brief.test.sh`.

2. **Optionally update `config/brief-include.md`** (captain-private): Replace its Pi Worker Defaults section with the corrected "For Pi workers / For other harnesses" text for consistency with the shared scaffold. This does not affect secondmate homes.

3. **No further audit needed** — the fix is deterministic and test-covered (29/29 regression tests pass).
