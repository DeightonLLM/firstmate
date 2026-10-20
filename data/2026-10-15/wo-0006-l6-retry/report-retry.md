# WO-0006 L6 retry: Core branch merge assessment

Inspection only. No command changed the Core repo; no merge, push, checkout, rebase, or project-repo write was performed. The branch tips and comparisons below were re-derived from `/home/hd2admin/kun-agent-workspace/projects/core-distro-saas-clean`.

## Preflight: refs and landed status

Verbatim relevant command output:

```text
+ fm/core-mobile-fix
+ fm/core-stream-a-checkpoint-0924
+ fm/core-v3-product-acceptance-spec-0927
7e59bafbfe58c01a299e31aa92f3b006c5e702f8
676546d4d0044f044ab6cb62afadfe62e6cbb76c
stream-a ancestry exit=1
349eaaf694f43a937efb0d2802677ff0a5001584
mobile ancestry exit=1
538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc
spec ancestry exit=0
```

The first hash is `main`; subsequent hashes are the exact branch tips, respectively. In the requested `git merge-base --is-ancestor <tip> main` test, exit 0 means landed and exit 1 means not landed:

| Branch | Tip | Landed in `main`? | Merge base with `main` |
|---|---|---|---|
| `fm/core-stream-a-checkpoint-0924` | `676546d4d0044f044ab6cb62afadfe62e6cbb76c` | No (exit 1) | `2eb4e12d33106a71f3e7439c053df9080c4adca6` |
| `fm/core-mobile-fix` | `349eaaf694f43a937efb0d2802677ff0a5001584` | No (exit 1) | `ba233e1b558d2282b446e4d72f6e29520964c642` |
| `fm/core-v3-product-acceptance-spec-0927` | `538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc` | Yes (exit 0) | `538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc` |

For the spec branch, `git log --oneline main..fm/core-v3-product-acceptance-spec-0927`, `git diff --stat main...fm/core-v3-product-acceptance-spec-0927`, and `git diff --name-status main...fm/core-v3-product-acceptance-spec-0927` all produced no output. It has no unique changes to merge.

## Branch: `fm/core-stream-a-checkpoint-0924`

Comparison: merge base `2eb4e12d33106a71f3e7439c053df9080c4adca6`; three commits ahead of that base, not an ancestor of `main`.

### Commit-by-commit summary

- `e93cc10 feat(core-distro): add language-route .htaccess + artifact manifest from checkpoint-baseline` — adds `ARTIFACT_MANIFEST.md` (150 lines) and `staged-export-test/.htaccess` (13 lines); replaces the zip with a much smaller archive (21,067,637 → 1,723,704 bytes). The rewrite rules route `/pl/` and `/es/` to `index.php` and apply only when the target is not an existing file/directory.
- `aa9de83 fix(manifest): remove geo_data fiction; update SHA-256; add parity table; correct SQL exclusions` — edits the manifest and changes the archive slightly (1,723,704 → 1,723,395 bytes); documentation claims and archive SHA/parity are corrected.
- `676546d fix(manifest): harden validation block — set -euo pipefail, fail-on-wrapper, SHA gate` — edits only the manifest validation commands, adding strict shell behavior and wrapper/SHA failure checks.

Net changes from the `main` merge base: adds `ARTIFACT_MANIFEST.md` and `.htaccess`, replaces `lead-engine-saas-export-20260625_canonical-geo.zip`; 230 text lines added, plus binary replacement.

### Blast radius and risk

- The `.htaccess` rules affect Apache deployments with `mod_rewrite`; non-Apache deployment routing is unaffected by these rules and would need equivalent configuration.
- The large archive replacement is the broadest risk: it changes a deployable package from roughly 21 MB to roughly 1.7 MB. Missing files or incorrect sanitization could break consumers of that artifact. The manifest describes exclusions and parity, but this review did not extract or independently validate the binary archive contents.
- The manifest's validation snippets themselves include shell operations, but they are documentation; they were not run as part of this read-only review.
- Overall risk: **medium-high**, primarily due to replacement of a deployment artifact and its unverified binary contents; the routing change is comparatively narrow.

### Rollback

Use a dedicated revert branch based on the updated target branch and revert the merge commit (do not reset shared history). Exact sequence after a no-ff merge, once its SHA exists:

```bash
git switch -c revert/fm-core-stream-a <updated-main-ref>
git revert -m 1 <stream-merge-commit-sha>
git push -u origin revert/fm-core-stream-a
```

`<updated-main-ref>` and `<stream-merge-commit-sha>` cannot be literal values yet: no merge has happened, so neither merge commit SHA nor future target tip exists. Open a revert PR from that branch. If the eventual integration is not a merge commit, do not use `-m 1`; prepare a normal revert for the actual integration commits instead.

## Branch: `fm/core-mobile-fix`

Comparison: merge base `ba233e1b558d2282b446e4d72f6e29520964c642`; three commits ahead of that base, not an ancestor of `main`.

### Commit-by-commit summary

- `7922e94 fix(index): make header .container flex on desktop — sit nav and lang-nav-container inline` — adds desktop flex layout to `staged-export-test/index.php`; adds test package metadata, a test runner, and desktop/header structure tests (6 paths total, 390 insertions).
- `3fc80c7 test: add browser-based layout probe + Android/Desktop comparison + reproduce evidence` — adds baseline/current Android and desktop screenshots, Playwright/browser-layout and Android comparison scripts, and expands the test lock/package setup (14 paths; 816 insertions, 8 deletions).
- `349eaaf fix(index): hide .theme-toggle-compact on mobile — late-scoped override after Final Surgical block` — adds a final mobile CSS hide rule in `staged-export-test/index.php`; adds a test pinning the mobile/desktop display rule and updates test package/runner and screenshot evidence (16 paths; 203 insertions, 3 deletions).

Net changes from the `main` merge base: modifies `staged-export-test/index.php`; adds test sources, runner/package files, `.gitignore`, and screenshot evidence; 28 paths and 1,398 insertions.

### Blast radius and risk

- The PHP change affects the header layout at desktop/tablet breakpoints and the mobile visibility of the compact theme toggle. CSS cascade/order and responsive breakpoints are the main regression surface.
- Test runner and dependencies introduce Node/JSDOM/CSS-tree/Playwright tooling; screenshots and lockfile add repository weight. The test runner also creates temporary render/config files under `/tmp/core-mobile-fix-render` when run.
- Commit messages and test comments describe browser/environment limits; no tests or browser checks were executed in this inspection, so the claimed regression evidence is not independently confirmed here.
- Overall risk: **medium**: limited application surface, but responsive layout is user-visible and validation is not independently rerun.

### Rollback

Use a dedicated revert branch based on the updated target branch and revert the merge commit (do not reset shared history). Exact sequence after a no-ff merge, once its SHA exists:

```bash
git switch -c revert/fm-core-mobile-fix <updated-main-ref>
git revert -m 1 <mobile-merge-commit-sha>
git push -u origin revert/fm-core-mobile-fix
```

`<updated-main-ref>` and `<mobile-merge-commit-sha>` cannot be literal values yet because the merge has not happened. Open a revert PR from that branch. If the eventual integration is not a merge commit, use normal reverts for its actual commits instead of `-m 1`.

## Branch: `fm/core-v3-product-acceptance-spec-0927`

Tip `538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc` is already an ancestor of `main`; merge base equals the tip. `main..branch` log and the three-dot diff are empty, so there are no branch-only commits, changed paths, or additional blast radius to assess. **Do not merge it again.**

Rollback is not applicable to this branch as a new merge. If a decision is made to undo its already-landed changes, identify the actual integration commit(s) in `main` first, then create a revert PR using the appropriate revert form; this inspection did not establish an integration commit SHA.

## Dependency and overlap analysis

- The product-acceptance spec branch is already in `main`, so it precedes this decision and requires no merge.
- The two unlanded branches share merge base `ba233e1b558d2282b446e4d72f6e29520964c642`. Their three-dot path comparison reports `staged-export-test/index.php` as the sole common changed path; stream's manifest/archive/`.htaccess` paths are otherwise separate from mobile's test/evidence paths.
- The stream branch's `staged-export-test/index.php` blob is `c993b41516e238f013acbffb3a4fd5f579151e92`, equal to the common-base blob. Mobile changes it to `54f1e268bc731a7eaa1708d455c71cd247908843`. Stream also adds a prebuilt zip (`cfcf69cc2c880d997a290e12efb1c68b6ff0002d`) and describes it as a source-parity artifact. Because it was committed on a branch whose source index still matches the common base, merging both branches as-is risks leaving the zip behind the mobile source changes. The binary archive was not unpacked, so its internal file-level contents are **not independently verified**.

## Recommended order

1. `fm/core-v3-product-acceptance-spec-0927`: no action; already landed.
2. `fm/core-mobile-fix`: if approved, integrate first so the source CSS fixes and their evidence land.
3. `fm/core-stream-a-checkpoint-0924`: **do not merge as-is after mobile** if the zip is expected to match the source. Rebuild the archive from the resulting source, refresh/verify its hash and manifest, then reassess/merge that corrected branch. This inspection-only task does not authorize making that change.

The two unlanded branches are separate at most paths, but the packaged artifact creates a content dependency. Their merge order alone cannot update the prebuilt zip; archive regeneration and parity verification are the safety condition for the proposed sequence.
