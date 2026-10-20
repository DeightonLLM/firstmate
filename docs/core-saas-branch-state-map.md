# Core SaaS branch ↔ state map — READ THIS BEFORE ANY CORE WORK

**Written 2026-10-19 after firstmate committed a redundant fix that already existed on a branch.**

## The failure this file prevents

The real Add Leads fix — `f26d4d8 fix(add-leads): re-parent modal overlays trapped inside a
display:none container` — had been sitting on `fix/add-leads-modal-nesting` since it was written.
Firstmate did not find it, wrote and pushed a **redundant** z-index fix (`65f28e8`), and spent a
verification lane proving what was already known. The work was correct; **it was undiscoverable.**

**Rule: before writing any fix in this repo, list the branches and read their commits. If a fix for
the same symptom already exists on a branch, that branch is the source of truth — not a fresh patch.**

## Branch state as of 2026-10-19 (measured, not assumed)

| Branch | Head | On remote as | What it is |
|---|---|---|---|
| `main` | `a46cea9` | `origin/main` | **Canonical.** Contains the shipped Add Leads nesting fix + its jsdom test + deploy tooling |
| `fix/add-leads-modal-nesting` | `fb89e14` | `origin/fix/add-leads-modal-nesting` | The branch **production was deployed from**. Merged into `main` |
| `fix/pa04-list-ownership-guard` | `40cdc60` | `origin/archive/fix/pa04-list-ownership-guard` | PA-04 guard (also merged to `main` as `5af61db`) |
| `fm/core-mobile-fix` | `349eaaf` | `origin/archive/fm/core-mobile-fix` | Mobile theme-toggle override. **Not merged. Review before use** |
| `fm/core-stream-a-checkpoint-0924` | `676546d` | `origin/archive/fm/core-stream-a-checkpoint-0924` | Manifest hardening (`-euo pipefail`, fail-on-wrapper, SHA gate) |
| `fm/core-v3-product-acceptance-spec-0927` | `538e4c2` | `origin/archive/fm/core-v3-product-acceptance-spec-0927` | V3 acceptance spec doc |
| `checkpoint/baseline-pre-dispatch` | `ba233e1` | `origin/archive/checkpoint/baseline-pre-dispatch` | Pre-dispatch baseline |
| `stream-a-language-nav` | `ba233e1` | `origin/archive/stream-a-language-nav` | Language-nav checkpoint |
| `regression-pa04-list-ownership-20261018` | `7e59baf` | `origin/archive/regression-pa04-list-ownership-20261018` | PA-04 candidate (superseded by `5af61db`) |

Every branch that had **no remote at all** is now preserved under `origin/archive/…`. Nothing lives
only on a borrowed laptop any more.

## The two Add Leads defects — do not conflate them

| # | Defect | Root cause | Status |
|---|---|---|---|
| **1** | Modal never opens when a lead card is open | `.slide-backdrop.open` sets `pointer-events: auto`, swallowing the click on the header button (`staged-export-test/leadlists.php:5165`); the click just closes the card | Fixed by `f26d4d8` — modal overlay re-parented out of the `display:none` container. **This is the real bug** |
| **2** | Modal painted beneath the lead card once open | `.modal-overlay` z-index 1000 vs `.slide-panel` 1001 | Fixed by `65f28e8` → 2001. **Real but secondary** — it never mattered while defect 1 prevented the modal opening |

Both are now in `main`. Verify against defect 1 when testing the entry path; fixing only z-index will
look like a pass and change nothing.

## Verification commands (proven working 2026-10-19)

```bash
php -l staged-export-test/leadlists.php
php tests/regression_pa04_list_ownership.php      # PASS
php tests/local_lane_test.php                     # PASS
bash tests/run_jsdom_tests.sh                     # 20/20, incl. --credits 0
```

The modal-above-card invariant is proven by **hit test**: with `#slidePanel.open` at z 1001 and the
modal at z 2001 overlapping, `elementFromPoint` at the overlap pixel returns `.modal-body`
(`inModal: true`, `inPanel: false`). Assert the layering that way; a screenshot will not prove it.

## Standing rules

1. **List branches and read their commits before writing any fix.** A fix for the same symptom on a
   branch makes that branch the source of truth.
2. **Merge to `main` and push when a branch is verified**, so the next session inherits it rather
   than rediscovering it.
3. **Every branch gets a remote**, immediately, under `archive/` if it is not going forward.
4. If a lane discovers a branch, port, credential location or service, it lands in
   `bin/fm-surface-inventory.sh` **in the same turn** — the `surface-first` contract. That is the
   difference between work that is found and work that is redone.