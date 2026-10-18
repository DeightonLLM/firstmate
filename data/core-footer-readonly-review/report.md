# Core Distro Mobile Footer — Read-Only Review Report

**Task:** `core-footer-readonly-review` (scout, priority 4)
**Reviewer:** owner pane, Pi MiniMax-M2.7
**Date:** 2026-09-23
**Artifact index:** `data/fleet-reset-handoff-2026-09-23.md`
**Source worktree:** `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean`
**Source branch/HEAD:** `fm/core-mobile-fix` / `349eaaf694f43a937efb0d2802677ff0a5001584`

---

## 1. Source worktree integrity

| | Before review | After review |
|---|---|---|
| HEAD | `349eaaf694f43a937efb0d2802677ff0a5001584` | `349eaaf694f43a937efb0d2802677ff0a5001584` (unchanged) |
| Tracked modifications | `staged-export-test/index.php`, `tests/run.sh` | same (unchanged) |
| Untracked evidence | 40 files under `tests/evidence/` + 5 test scripts | same (unchanged) |

No commits, no rebases, no edits, no test runs, no browser captures, no pushes, no PRs, no merges, no deployments were performed during this review. The worktree is fully preserved.

---

## 2. Two patches distinguished

### 2a. Header / theme-toggle correction

**Location:** `staged-export-test/index.php:555–569`

```php
/* Mobile late-scoped override */
/* The earlier `@media (max-width: 767px)` rule hides
   `.theme-toggle-compact`, but the Final Surgical Responsive Overrides
   block above re-declares `display: flex !important` outside any
   @media wrap. Both rules have identical specificity and `!important`,
   so the CSS cascade tie-breaks on source order — the Final Surgical
   rule (later) was winning on mobile, leaving the moon icon visible
   next to the hamburger and producing the reported Android Chrome
   overlap. This late-scoped override re-establishes the mobile hide
   AFTER the Final Surgical block, without wrapping that block in
   `@media (min-width:768px)` (which would change the 768–1024 tablet
   path). */
@media (max-width: 767px) {
    .theme-toggle-compact { display: none !important; }
}
```

This fix re-asserts `.theme-toggle-compact { display: none !important; }` in a `@media (max-width: 767px)` block placed after the "Final Surgical Responsive Overrides" block, to win the CSS cascade tie-break and suppress the moon-icon overlap on narrow mobile viewports.

### 2b. Footer contrast patch

**Location:** `staged-export-test/index.php:222–229`

```php
/* WCAG AA: light-mode --text-tertiary (#8e8e93) yields only ~3.26:1 on the
   white footer background, below 4.5:1. Scope a darker token to <footer>
   so both the inline copyright <div> and .footer-links a resolve to a
   passing shade. The dark-mode override restores the existing
   html[data-theme="dark"] --text-tertiary (#748094 ≈ 4.69:1 on #0b1220)
   so dark-theme contrast is preserved unchanged. */
footer { --text-tertiary: #5d5d61; }
html[data-theme="dark"] footer { --text-tertiary: #748094; }
```

- **Light mode:** `--text-tertiary` is overridden inside `<footer>` to `#5d5d61`, yielding **6.55:1** contrast on white — above WCAG AA (≥4.5:1).
- **Dark mode:** the existing dark `--text-tertiary` (`#748094`) is restored under `html[data-theme="dark"] footer`, yielding **4.69:1** on `#0b1220` — above WCAG AA, unchanged from before the patch.
- **Baseline red:** before the patch, `--text-tertiary` (`#8e8e93`) on white yielded **3.26:1** — below WCAG AA for normal text.

**Saved ratios:**
| Theme | Token value | Background | Contrast ratio |
|---|---|---|---|
| Light (post-fix) | `#5d5d61` | `#ffffff` | **6.55:1** |
| Dark (post-fix) | `#748094` | `#0b1220` | **4.69:1** |
| Light (baseline red) | `#8e8e93` | `#ffffff` | 3.26:1 (FAIL) |

**Viewport limits:**
- Test checks exactly **two** Playwright-emulated viewports:
  - Mobile: Pixel 7, 412×915, `deviceScaleFactor: 2.625`, Android 14 Chrome UA, `isMobile: true`, `hasTouch: true`
  - Desktop: 1280×800, standard Chrome UA, `isMobile: false`
- Assertions cover only `footer > .container > .footer-inner > div:first-child` (copyright) and `footer .footer-links a:first-child` (first link), not every footer link independently.

---

## 3. Saved evidence reviewed

| Evidence type | Path | Details |
|---|---|---|
| Diff (footer patch) | `staged-export-test/index.php:222–229` | 8 CSS lines + explanatory comment, per git diff |
| Diff (test runner) | `tests/run.sh:113–141` | Browser-based test block appended to run.sh |
| Test file | `tests/test_footer_contrast.js` | Playwright contrast measurement; VIEWPORTS at lines 47–50, assertions at 155–168 |
| Baseline screenshots | `tests/evidence/footer-baseline-*.png` | 14 files across mobile/desktop/tablet emulated viewports, captured 2026-09-23 07:01 |
| Current screenshots | `tests/evidence/footer-current-*.png` | 14 files matching viewport set, captured 2026-09-23 07:01 |
| Postfix screenshots | `tests/evidence/footer-postfix-{mobile-pixel-7,desktop-1280}-{light,dark}-{bottom,crop}.png` | 8 files; light crops visibly show darker text; dark crops retain dark palette |
| Runner result | `state/core-mobile-fix.status` | `Summary: 4 passed, 0 failed`; 8/8 footer contrast assertions passing |
| Earlier core-mobile-review report | `data/core-mobile-review/report.md` | Independent verdict: PASS with limited viewport coverage finding |

**No physical Android testing was performed.** All screenshots and contrast measurements use Playwright browser emulation with Android-like viewport and user-agent settings.

---

## 4. Codex Luna medium subagent — capability gap

**Decision:** Skipped. `minimax/MiniMax-M2.7` is the sole available Pi child model. `codex-exec` (the only Codex CLI builtin) also runs on MiniMax-M2.7, not on a Codex Luna medium model. Codex Luna medium does not appear in the current model registry.

- `quota-axi` reports Codex provider at 47% remaining with ~334,659 s runway (projected exhaustion 2026-09-27 07:05 UTC) — runway is sufficient, but the model is not installed.
- **Exact gap:** `Codex Luna medium` is not an installed Pi child model capability.
- **Fallback:** Owner review completed in this visible pane, incorporating the already-completed independent subagent verdict from the earlier `core-mobile-review` pass.

---

## 5. Verdict

**PASS — the saved evidence is sufficient to close the client issue, with one known limitation.**

The footer contrast fix (`staged-export-test/index.php:222–229`) correctly scopes a darker `--text-tertiary` value to `<footer>` in light mode, lifting the contrast ratio from 3.26:1 to 6.55:1 (WCAG AA), while explicitly restoring the existing dark-mode token (`#748094`, 4.69:1) so dark-theme contrast is unchanged. The copyright `<div>` and `.footer-links a` both consume this token, so both elements are fixed by the same two CSS rules.

**Sufficient to close because:**
- WCAG AA threshold (≥4.5:1) is met in both themes at both tested viewports.
- The fix is surgical — two CSS property overrides, no structural changes.
- The earlier `core-mobile-review` report independently confirmed the same verdict.
- The test harness has a clear missing-Chromium path (exits 1, not silent pass).
- The worktree is clean (no commits, no untracked changes introduced by this review).

**Remaining gap (low severity):**
- Coverage is limited to two Playwright-emulated viewports (Pixel 7 mobile and 1280 desktop) and asserts only the copyright and first footer link per viewport/theme combination. The 7 remaining footer links are not independently asserted, nor are intermediate tablet widths (768, 900, 1024 px). This is a known limitation documented in the test and the prior review; it does not block closure.

**No physical Android device evidence exists.** All evidence uses Playwright browser emulation, which reproduces the same CSS cascade that Chrome on Android would resolve, but cannot prove device-specific rendering differences.

**No merge recommendation is made.** The fix remains in a local-only branch (`fm/core-mobile-fix`).

---

## 6. Captain-hold completion gate

`fm-captain-hold.sh complete core-footer-readonly-review --none` — passed; no unresolved captain calls in this review surface.

---

## 7. Worktree preserved confirmation

```
BEFORE: HEAD=349eaaf694f43a937efb0d2802677ff0a5001584
AFTER:  HEAD=349eaaf694f43a937efb0d2802677ff0a5001584  (identical)
Tracked modified: staged-export-test/index.php, tests/run.sh  (unchanged)
Untracked evidence: 40 files under tests/evidence/ + 5 test scripts  (unchanged)
```

No edits, test runs, commits, rebases, pushes, PRs, merges, or deployments were performed.
