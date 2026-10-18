# Retained branch and worktree inventory

**Snapshot:** 2026-10-15. **Scope:** project clones registered in `/home/hd2admin/kun-agent-workspace/projects` and their Git worktree/branch records: `core-distro-saas-clean` and `firstmate`. I did not inspect `warehouse/` or any secondmate home. This is a read-only snapshot; no fetch, merge, test execution, or cleanup was performed.

## Method and classification

Commands run included `git worktree list --porcelain`, `git branch --format='%(refname:short) %(worktreepath)'`, `git symbolic-ref --short refs/remotes/origin/HEAD`, `git rev-list --count origin/main..HEAD`, `git status --porcelain=v1 --untracked-files=all`, `git diff --name-only`, `git ls-files --others --exclude-standard`, `git log --reverse`, `git show -s --format='%H|%s'`, `git diff-tree --no-commit-id --name-only -r`, and `git merge-base --is-ancestor <commit> main` (and against `origin/main` to distinguish local default-branch reachability from remote reachability). The worktree listing and the individual commands below provide the evidence; status output is the Git working-tree state, not used to infer whether commits landed.

Both repos identify `origin/main` as the origin default branch. `core-distro-saas-clean` local `main` is 3 commits ahead and 0 behind `origin/main`. `firstmate` local `main` is 17 ahead and 47 behind `origin/main`; its main worktree has tracked change `tools/ZCode`. Thus the `origin/main` comparison is not interchangeable with reachability from the local default branch. The 17 commits on firstmate's default `main` are already part of that local default branch, not retained side-branch commits; they are not included in the 12-commit unlanded side-branch count. Since `origin/main` is 47 commits ahead as well, this snapshot does not make any claim that those default-branch-only commits have reached the remote. Here **ALREADY LANDED** means `merge-base --is-ancestor <commit> main` succeeds (exit 0); **GENUINELY UNLANDED** means it fails (exit 1). Branch ahead numbers below are against `origin/main`, as requested. `ahead local main` is also shown when it matters.

Tracked modifications are reported as paths from `git diff --name-only` (no staged-only changes were reported by that command); the worktree porcelain command was also run. Untracked files are listed or grouped by the exact generated subtree and count when the subtree contains very many files. A `—` means none found. Detached worktrees have no branch name.

## Every discovered worktree

| Project | Worktree path | Branch | Commits ahead of `origin/main` (ahead of local `main`) | Tracked modifications | Untracked files |
|---|---|---|---:|---|---|
| core-distro-saas-clean | `/home/hd2admin/agent-work/core-distro-saas-clean` | `main` | 3 (default branch) | — | — |
| core-distro-saas-clean | `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/1/core-distro-saas-clean` | `fm/core-mobile-fix` | 3 (3) | `staged-export-test/index.php`, `tests/run.sh` | 32 untracked screenshot files under `tests/evidence/`, plus `tests/probe_footer.js`, `tests/probe_footer_diag.js`, `tests/probe_footer_postfix.js`, `tests/scroll_check.js`, `tests/test_footer_contrast.js` |
| core-distro-saas-clean | `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/2/core-distro-saas-clean` | `fm/core-stream-a-checkpoint-0924` | 4 (3) | — | — |
| core-distro-saas-clean | `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/3/core-distro-saas-clean` | `fm/core-v3-product-acceptance-spec-0927` | 2 (0) | — | — |
| core-distro-saas-clean | `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/4/core-distro-saas-clean` | detached | 0 (0) | — | — |
| core-distro-saas-clean | `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/5/core-distro-saas-clean` | detached | 0 (0) | — | — |
| core-distro-saas-clean | `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/6/core-distro-saas-clean` | detached | 0 (0) | — | — |
| core-distro-saas-clean | `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/7/core-distro-saas-clean` | detached | 0 (0) | — | — |
| core-distro-saas-clean | `/home/hd2admin/agent-work/core-distro-saas-clean-stream-a-nav` | `stream-a-language-nav` | 0 (0) | `staged-export-test/assets/saas-toast.js`, `staged-export-test/includes/theme_bootstrap.php` | `lead-engine-saas-export-20260923_stream-a-lang-nav.zip.sha256`, `scripts/build-deployment-artifact.py`, `staged-export-test/tests/category-filter.smoke.js`, `staged-export-test/tests/lang-nav.smoke.js`, `staged-export-test/tests/toast.smoke.js`; also 1,846 untracked files under `staged-export-test/node_modules/` |
| firstmate | `/home/hd2admin/agent-work/firstmate` | `main` | 17 (default branch) | `tools/ZCode` | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/1/firstmate` | detached | 0 (0) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/2/firstmate` | `fm/system-repair-sprint-0924` | 1 (1) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/3/firstmate` | detached | 0 (0) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/4/firstmate` | `fm/tool-auto-update` | 4 (4) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/5/firstmate` | detached | 0 (0) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/6/firstmate` | detached | 0 (0) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/7/firstmate` | detached | 0 (0) | — | `.scratch/capture-evidence.mjs`, `.scratch/node_modules` (contents untracked; directory notation as listed by Git) |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/8/firstmate` | `fm/herdr-pane-board-context` | 0 (0) | `bin/fm-bearings-snapshot.sh`, `bin/fm-fleet-snapshot.sh` | `tests/fm-fleet-snapshot-herdr.test.sh` |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/9/firstmate` | detached | 0 (0) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/10/firstmate` | `fm/calm-worker-version-consistency` | 1 (1) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/11/firstmate` | detached | 0 (0) | — | — |
| firstmate | `/home/hd2admin/.treehouse/firstmate-46aafc/12/firstmate` | detached | 0 (0) | — | — |

The 32 mobile-fix screenshot paths are individual baseline/current/postfix captures under `tests/evidence/` for desktop 1280, iPhone SE, Galaxy S24, Pixel 3/7, and iPad mini variants; they are grouped here by directory and verified count rather than reproduced as 32 table cells. The targeted per-worktree Git listing verified 1,846 untracked dependency files in `staged-export-test/node_modules/` in the stream-a-nav checkout. No tracked modification was inferred from untracked content.

One retained local branch has no associated worktree: `core-distro-saas-clean:checkpoint/baseline-pre-dispatch`. It is 0 ahead of both `origin/main` and local `main`; its tip `ba233e1b558d2282b446e4d72f6e29520964c642` is the language-navigation commit reachable in local `main`. As there is no checkout, tracked/untracked working-tree status does not apply.

## Ahead commits, touched paths, and landing checks

All commit subjects and paths below come from `git show -s` and `git diff-tree`. Each landing result was checked with `git merge-base --is-ancestor <hash> main`; every `Genuinely unlanded` entry returned exit 1 and every `Already landed` entry returned exit 0. Test presence means a test file is part of the commit's touched paths; it is not a claim that tests were executed.

### core-distro-saas-clean

| Retained branch / source | Commit, subject, and touched files | Classification | Tests / one-line work |
|---|---|---|---|
| `main` (3 commits ahead of origin) | `2eb4e12d33106a71f3e7439c053df9080c4adca6` — `test(core-distro): add local lane acceptance evidence` — `LOCAL_DEVELOPMENT.md`, `RELEASE_METADATA.md`, `bin/core-distro-local-check.sh`, `tests/local_lane_test.php` | Already landed (main contains itself) | Has test. Local lane acceptance evidence/check. |
| `main` | `538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc` — `docs: propose Core Distro V3 acceptance spec` — `CORE_DISTRO_V3_PROPOSED_PRODUCT_ACCEPTANCE_SPEC.md` | Already landed | No test in commit. Proposed product-acceptance spec. |
| `main` | `7e59bafbfe58c01a299e31aa92f3b006c5e702f8` — `chore: ignore firstmate .treehouse scratch leaking into the repo` — `.gitignore` | Already landed | No test in commit. Ignore scratch material. |
| `fm/core-mobile-fix` | `7922e94f6b5eb4f7ba00d3808ccc1ed050e27c76` — `fix(index): make header .container flex on desktop — sit nav and lang-nav-container inline` — `staged-export-test/index.php`, `tests/.gitignore`, `tests/package.json`, `tests/run.sh`, `tests/test_header_desktop_layout.js`, `tests/test_header_structure.js` | Genuinely unlanded | Has tests. Desktop header/navigation layout correction. |
| `fm/core-mobile-fix` | `3fc80c7fb85beaefc0f2d746c4e45e8fe7b2a0a5` — `test: add browser-based layout probe + Android/Desktop comparison + reproduce evidence` — baseline/current platform screenshots, `tests/package.json`, `tests/package-lock.json`, `tests/test_android_compare.js`, `tests/test_browser_layout.js` | Genuinely unlanded | Has tests. Adds browser layout comparison and reproduction evidence. |
| `fm/core-mobile-fix` | `349eaaf694f43a937efb0d2802677ff0a5001584` — `fix(index): hide .theme-toggle-compact on mobile — late-scoped override after Final Surgical block` — `staged-export-test/index.php`, mobile screenshots, `tests/package.json`, `tests/run.sh`, `tests/test_mobile_theme_toggle_hide.js` | Genuinely unlanded | Has test. Hides compact theme toggle on mobile. |
| `fm/core-stream-a-checkpoint-0924` | `2eb4e12d33106a71f3e7439c053df9080c4adca6` — local lane acceptance evidence; paths as above | Already landed | Has test. **Same commit/hash appears on local main, mobile-fix, stream-a, and V3 branches: duplicate presence is shared ancestry, not four separate changes.** |
| `fm/core-stream-a-checkpoint-0924` | `e93cc10812334b8c8ce419e4982df4f84901f160` — `feat(core-distro): add language-route .htaccess + artifact manifest from checkpoint-baseline` — `ARTIFACT_MANIFEST.md`, `lead-engine-saas-export-20260625_canonical-geo.zip`, `staged-export-test/.htaccess` | Genuinely unlanded | No test file touched by commit. Language route and deployment artifact manifest/package. |
| `fm/core-stream-a-checkpoint-0924` | `aa9de8343a3ebfdb6acaa0135feaaab2155462c2` — `fix(manifest): remove geo_data fiction; update SHA-256; add parity table; correct SQL exclusions` — `ARTIFACT_MANIFEST.md`, `lead-engine-saas-export-20260625_canonical-geo.zip` | Genuinely unlanded | No test file touched by commit. Corrects artifact manifest, checksum, parity, and SQL exclusions. |
| `fm/core-stream-a-checkpoint-0924` | `676546d4d0044f044ab6cb62afadfe62e6cbb76c` — `fix(manifest): harden validation block — set -euo pipefail, fail-on-wrapper, SHA gate` — `ARTIFACT_MANIFEST.md` | Genuinely unlanded | No test file touched by commit. Hardens artifact validation/checksum gate. |
| `fm/core-v3-product-acceptance-spec-0927` | `2eb4e12d33106a71f3e7439c053df9080c4adca6` — local lane acceptance evidence; paths as above | Already landed | Has test; shared commit, not duplicate unlanded work. |
| `fm/core-v3-product-acceptance-spec-0927` | `538e4c2d3cd8e69bb23e4a12795c7ee7a3d77fdc` — proposed V3 acceptance spec; path as above | Already landed | No test in commit. Both branch commits are ancestors of local `main` (`merge-base` exit 0), despite being ahead of the current `origin/main` tip. |

### firstmate

| Retained branch | Commit, subject, and touched files | Classification | Tests / one-line work |
|---|---|---|---|
| `fm/calm-worker-version-consistency` | `d83e6f216fb5f05feccc20b5c195089694569acf` — `fix(bin): sync canonical Calm files into task worktree before Pi launch` — `bin/fm-spawn.sh` | Genuinely unlanded | No test file touched. Syncs canonical Calm files into task worktree before Pi launch. |
| `fm/system-repair-sprint-0924` | `be1ec4b62d103e79969edf8cbc17362aeebf4edd` — `fix(teardown): expand variables in printf format strings` — `bin/fm-teardown.sh` | Genuinely unlanded | No test file touched. Fixes teardown printf variable expansion. |
| `fm/tool-auto-update` | `8f6216b281aeee56c295b94402cb1161227de70a` — safe watched-tool update detector and staged-install orchestrator — `bin/fm-tool-install.sh`, `bin/fm-tool-live.sh`, `bin/fm-tool-update-check.sh`, `docs/configuration.md`, `docs/examples/watched-tools.json` | Genuinely unlanded | No test file touched. Adds watched-tool update detection/install orchestration. |
| `fm/tool-auto-update` | `70a8ca1d59c0eb3d58b33b7d0adc295a80fd02a9` — scheduled update detection and Pi extension support — `bin/fm-tool-install.sh`, `docs/configuration.md` | Genuinely unlanded | No test file touched. Routes scheduled installs through detector and includes Pi extensions. |
| `fm/tool-auto-update` | `dac9e8e8e547fcd3c84a696a491119bbb5a78cfd` — Pi on-load self/extension update check — `.pi/extensions/fm-primary-turnend-guard.ts`, `bin/fm-tool-install.sh`, `docs/configuration.md` | Genuinely unlanded | No test file touched. Adds Pi session-start update check. |
| `fm/tool-auto-update` | `3aa352a8d6127f292601ee49ee5008dfd01b8dea` — `fix(tool-auto-update): three regressions fixed` — `.pi/extensions/fm-primary-turnend-guard.ts`, `bin/fm-tool-live.sh`, `tests/fm-tool-live-exclude-pid.test.sh`, `tests/fm-tool-timer-cleanup.test.sh` | Genuinely unlanded | Has tests. Fixes three watched-tool update regressions. |

The `fm/herdr-pane-board-context` branch has 0 commits ahead of `origin/main` and local `main`; its worktree is dirty (`bin/fm-bearings-snapshot.sh`, `bin/fm-fleet-snapshot.sh`) with untracked `tests/fm-fleet-snapshot-herdr.test.sh`. This is **uncommitted work**, so there are no commit hashes to classify. It does contain a test file, but no test was run. The other detached worktrees shown in the inventory are clean and at 0 ahead.

## Known hashes, duplicates, and count

- The two commits from October 3, `50abe4e0` and `051cd56d`, could not be resolved in either discovered project repository (`git rev-parse --verify <hash>^{commit}` failed in both). The described landed replacement `973ff553` was not found in these two repositories either. They are therefore not counted as verified inventory items here; the `051cd56d` claim remains unverified within the permitted project scope and needs the Controller's source coordinates or access to the repository containing it.
- The retained `fm/brief-worklocation-template-fix` branch and `bab949ac` were not present in either project's local branch list/commit object lookup; no retained worktree with that branch was found. The claimed landed status was not independently verified within this scope.
- Duplicate: the exact hash `2eb4e12d...` is shared across four Core-Distro branch histories and is reachable from local `main`; count it once, and as landed. No other exact duplicate unlanded commit hash was found. Similarity of different commits was not treated as proof of duplicate work.
- **Verified genuinely unlanded committed side-branch work: 12 commits across 5 feature branches** (3 Core-Distro mobile-fix + 3 Core-Distro stream-a + 1 firstmate Calm + 1 firstmate teardown + 4 firstmate tool-auto-update). Of these, at least 4 commits visibly touch test files; the remaining 8 do not. This count excludes the 17 commits already on local firstmate `main`, dirty/uncommitted worktree changes, and the two unresolved October 3 hashes. `origin/main` is 47 commits behind firstmate local `main`, so remote publication of those default-branch commits is not established.
- Additional uncommitted work: Core-Distro mobile-fix has tracked modifications and untracked evidence/probe files; Core-Distro stream-a-nav has tracked modifications and untracked files including 1,846 dependency files; firstmate has `tools/ZCode` modified on main, `.scratch` files in detached worktree 7, and the two tracked changes plus untracked test in `fm/herdr-pane-board-context`. These are not counted in the 12 committed changes. No merge approval is implied for any branch; any merge requires a named branch and explicit approval.

## Recommendation

Keep all genuinely unlanded work retained. Route the five verified unlanded branches to the Controller for an explicit disposition, preserving the captain's rule that retention is not merge approval. Investigate the October 3 hashes and the held worklocation branch using the correct repository/worktree coordinates before claiming completeness beyond the two discovered project repositories. Do not merge any branch based on this inventory alone.
