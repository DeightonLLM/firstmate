# Audit of removed Treehouse worktrees and surviving Git work

**Snapshot:** 2026-10-15 on `brandon-compute` as `hd2admin`. **Mode:** read-only; no restore, merge, cleanup, fetch, prune, `git gc`, task-axi, or remote API calls. This is an adversarial audit, but the retained evidence does not support a categorical claim about every removed worktree's former untracked files.

## Direct answer: did the 12 removals destroy unlanded work?

**UNVERIFIED — I cannot truthfully answer YES or NO from surviving evidence.** I found no proof that any particular commit or untracked file was destroyed by those 12 removals, but also found no pre-removal manifest, file snapshot, checksums, or removed-worktree list that could establish that nothing was lost. Current Git worktrees contain untracked files and dirty tracked files that the stated check would miss. They prove the check is insufficient; they do not prove those particular files were present in the 12 removed worktrees. A “NO” would be unjustified, and naming a specific lost file as fact would also be unjustified.

The known recovered features are not presently lost: `50abe4e0`'s exact patch is in landed `973ff553`; `051cd56d` still exists on local and remote-tracking refs and is not landed; and the `c020fa22` worklocation patch is landed in equivalent commit `23f0468e`, included by landed merge `bab949ac`. The latter original commit hash itself remains on an unlanded branch.

**Important:** the inspection found other unlanded commits and live untracked work. That is a preservation warning, not permission to merge, recover, or delete anything.

## Scope and completeness limits

The host's registered project registry (`/home/hd2admin/kun-agent-workspace/data/projects.md`, lines 1–4) names two projects: `core-distro-saas-clean` and `firstmate`. I also enumerated Git repositories under `/home/hd2admin` because the request says every project on the host. `find /home/hd2admin -name .git -print` found the registered repositories and several other Git roots, plus many Treehouse `.git` files whose gitdir points into removed `/tmp` directories. Those stale gitfiles are not working trees usable by Git. For example, actual output included:

```text
/home/hd2admin/.treehouse/scratch-project-84147c/1/scratch-project: gitdir: /tmp/fm-herdr-launcher-e2e.5MWrwq/scratch-project/.git/worktrees/scratch-project
/home/hd2admin/.treehouse/core-distro-saas-clean-30c8c1/2/core-distro-saas-clean: gitdir: /tmp/fm-local-sources-0926/core-distro-saas-clean/.git/worktrees/core-distro-saas-clean1
```

`git -C <path> worktree list --porcelain` on those paths returned `fatal: not a git repository` because the referenced `/tmp` gitdir no longer exists. They are evidence of stale filesystem remnants, not a registered/surviving worktree. I could not inspect paths owned by root or other users; no claim is made about inaccessible home directories or remote servers. No fetch or remote query was performed; remote evidence below means local remote-tracking refs only.

### Registered worktrees found

These are worktree paths reported by `git worktree list --porcelain` from the relevant accessible Git common directories. A worktree path listed below was present in Git's registry at inspection. Status details for the two principal project repos are summarized separately; “registered” does not imply the worker is live.

- `kun-agent-workspace` repository, rooted at `/home/hd2admin/kun-agent-workspace`: primary `/home/hd2admin/kun-agent-workspace`; Treehouse slots `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/{1,4,15,16,17,18,19,20,21,22,23}/kun-agent-workspace` and `/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/{1,2,3,4,5,6,7,8,9,10,11,12}/kun-agent-workspace`. The current task worktree is slot `22`. Several other `.treehouse` directories found by `find` were broken gitfiles and are not in this registered list.
- `core-distro-saas-clean`, rooted at `/home/hd2admin/agent-work/core-distro-saas-clean`: main repo; slots `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/{1,2,3,4,5,6,7}/core-distro-saas-clean`; and `/home/hd2admin/agent-work/core-distro-saas-clean-stream-a-nav`.
- Additional accessible roots / clones: `/home/hd2admin/agent-work/firstmate` and its Treehouse slots `/home/hd2admin/.treehouse/firstmate-46aafc/{1,2,3,4,5,6,7,8,9,10,11,12}/firstmate`; `/home/hd2admin/agent-work/deightonllm-firstmate` and slots `/home/hd2admin/.treehouse/deightonllm-firstmate-46aafc/{1,2,3,4,5,6,7,8}/deightonllm-firstmate`; `/home/hd2admin/overnight-20260924/repo`; `/home/hd2admin/kun-agent-workspace/data/mm-saas-snapshot-20260925` and its registered slot `/home/hd2admin/.treehouse/mm-saas-snapshot-20260925-387625/1/mm-saas-snapshot-20260925`; `/home/hd2admin/vps-ops`; `/home/hd2admin/agent-work/firstmate/tools/ZCode`; `/home/hd2admin/.codex/.tmp/plugins`; `/home/hd2admin/.nvm`; and two registered no-mistakes worktrees under `/home/hd2admin/.no-mistakes/repos/1f3f1a9a1089.git`.

Several of these are not entries in the two-project registry (e.g. `.nvm`, plugins, no-mistakes evidence, and the additional `agent-work` clones). They were enumerated as accessible Git roots, not treated as customer project work. No attempt was made to scan all filesystem contents for embedded `.git` files outside `/home/hd2admin` or to access another account.

## Named commits: independent verification

Commands included `git show -s --format='commit=%H%nparents=%P%ndate=%cI%nsubject=%s' <hash>`, `git diff-tree --no-commit-id --name-status -r <hash>`, `git show <hash> | git patch-id --stable`, `git merge-base --is-ancestor <hash> origin/main`, `git branch -a --contains <hash>`, and `git reflog --all --date=iso-strict`.

| Commit / claim | Findings | Verdict |
|---|---|---|
| `50abe4e064a214590d8085f914f3a295663c4607` -> `973ff55338cfc566fc7331bc97160be1581a87ae` | Both subjects are `feat: add checksum-verified Brandon order delivery`; both touch `bin/fm-outbound-order.sh`, `bin/fm-test-run.sh`, `docs/configuration.md`, and `tests/fm-outbound-order.test.sh`. Both commits yield stable patch-id `1c08ba621dbc11bc54c50fc244c010e116b69fa2`. `git merge-base --is-ancestor 973ff553 origin/main` exited `0`; `50abe4e0` itself exited `1`, and the original is still named by `fm/outbound-order-delivery-tdd` and `remotes/no-mistakes/fm/outbound-order-delivery-tdd`. | **Confirmed landed by exact patch** in `973ff553`; source hash still exists. Not data loss. |
| `051cd56d9fbf5dc04222946125354f8f9f49f528` | Subject `Recover exact stale watcher child`; changes `bin/fm-watch-arm.sh` and `tests/fm-watcher-lock.test.sh`. `git merge-base --is-ancestor 051cd56d origin/main` exited `1`. `git branch -a --contains 051cd56d` lists `fm/controller-watcher-heartbeat-recovery` and `remotes/no-mistakes/fm/controller-watcher-heartbeat-recovery`; `git worktree list` shows the local branch checked out at `.treehouse/kun-agent-workspace-46aafc/4/kun-agent-workspace`. Reflog shows it was cherry-picked onto main as `d494b868...` at 06:34:23, then main was reverted at `4086c377...` at 06:34:44; current `origin/main` is `0e8b140...`, not containing it. | **Confirmed still exists; confirmed NOT landed.** Recoverable from extant local/remote-tracking refs. |
| `c020fa22228714967520fdc96913ff8cd1222c0f` -> `bab949acbfb0d9b2be02f03e446d7a72fe8b273f` | The original changes `bin/fm-brief.sh` and `tests/fm-brief.test.sh`; it is still on branch `fm/worklocation-reland-20261014` and is not an ancestor of `origin/main` (exit `1`). Its stable patch-id is `9d97b1a5bc25576070aa67ced22efa40bc698b4f`, identical to commit `23f0468ec7bd30e023df26ba0a66cf6a60783f1d`. `23f0468e` is a parent of merge `bab949ac`; `bab949ac` is reachable from `origin/main` (ancestor check exit `0`). `git show bab949ac:bin/fm-brief.sh` and `:tests/fm-brief.test.sh` both show the `--worklocation` implementation/tests. | **Feature claim confirmed independently:** same patch landed via `23f0468e` in `bab949ac`. The original `c020fa22` commit remains on an unlanded branch but is duplicate patch content, not unique lost work. |

Quoted reflog evidence (real output):

```text
973ff553... origin/main@{2026-10-15T06:35:03+01:00} update by push
973ff553... main@{2026-10-15T06:34:44+01:00} cherry-pick: feat: add checksum-verified Brandon order delivery
4086c377... main@{2026-10-15T06:34:44+01:00} commit: revert: hold watcher recovery commit until it can be validated
d494b868... main@{2026-10-15T06:34:23+01:00} cherry-pick: Recover exact stale watcher child
bab949ac... origin/main@{2026-10-15T05:11:35+01:00} update by push
bab949ac... main@{2026-10-15T05:11:34+01:00} commit (merge): feat(brief): add --worklocation for briefs operating outside the worktree
```

Thus the known 051 commit was briefly cherry-picked but its changes were explicitly reverted; do not treat the transient cherry-pick reflog entry as landing.

## Present dirty work: tracked and untracked evidence

The current `kun-agent-workspace` worktree summary was collected using `git worktree list --porcelain`, then `git -C <worktree> status --porcelain --untracked-files=all` for each registered path. Representative exact output:

```text
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/16/kun-agent-workspace | fm/provider-cap-20261014 | tracked=3 untracked=0
 M bin/fm-dispatch-guard.sh
 M docs/configuration.md
 M tests/fm-dispatch-guard-max-lanes.test.sh
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/18/kun-agent-workspace | 46768547 | tracked=0 untracked=2
?? bin/fm-scope-check.sh
?? tests/fm-scope-check.test.sh
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/21/kun-agent-workspace | 0e8b1401 | tracked=0 untracked=1
?? docs/README-index.md
/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/kun-agent-workspace | fdd36879 | tracked=2 untracked=1
 M bin/fm-watch.sh
 M tests/fm-watch-triage.test.sh
?? live-todo.md
/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/7/kun-agent-workspace | fm/system-stale-wake-loop-0924 | tracked=2 untracked=0
 M bin/fm-watch.sh
 M tests/fm-watch-triage.test.sh
```

These current worktrees were not removed in the inspected registry. Their existence is exactly why “0 ahead + 0 tracked modifications” does not establish empty: worktrees 18 and 21 have untracked source/docs/tests, while slot 4 has an untracked file in addition to tracked edits. The primary `/home/hd2admin/kun-agent-workspace` also reported **715 untracked paths** (including private/generated material; not enumerated or modified). These findings do not establish those paths belonged to the twelve removed worktrees.

A prior same-day scoped inventory, `data/core-branch-inventory-20261015/report.md` (read in full), records for the two registered projects the then-current untracked work: 32 screenshots and five probe scripts in Core mobile-fix; 1,846 dependency files plus export/test artifacts in Core stream-a-nav; and scratch files plus tracked/untracked changes in Firstmate worktrees. Its exact paths and caveats are in that report. It also listed 12 unlanded side-branch commits in its project checkout, but it explicitly said the October 3 hashes and worklocation branch were not found in its two repositories. The current inspection found those hashes in a different Git common directory. The earlier report is therefore useful corroboration for extant untracked risk, not a complete record of the twelve later removals.

## Other unlanded commits found

“Unlanded” here means the exact commit is not an ancestor of that repository's local default branch (`git merge-base --is-ancestor <commit> main` fails), unless called out as a duplicate patch already landed under a different hash. Remote status was not refreshed. These are current references/evidence; no action taken.

### `kun-agent-workspace` Git common directory

| Commit | Ref/evidence | Classification / note |
|---|---|---|
| `051cd56d9fbf5dc04222946125354f8f9f49f528` — Recover exact stale watcher child | `fm/controller-watcher-heartbeat-recovery`; `remotes/no-mistakes/...`; path above | Unlanded, confirmed; see named-commit proof. |
| `c020fa22228714967520fdc96913ff8cd1222c0f` — Add explicit brief worklocation option | `fm/worklocation-reland-20261014` | Exact commit unlanded; exact patch is already landed through `23f0468e`/`bab949ac`, so duplicate, not unique feature loss. |
| `9601685d53e8551325e2b53368b8308563f8ba55` — fix: stream fleet JSON into jq | `fm/fleet-snapshot-arg-limit`; parent `cf2a3db...`; 2026-10-13 | One commit ahead of `origin/main`; branch does not appear in the current `git worktree list` (branch-only retained work). Exact ancestry check against local main was not completed in this read-only pass; treat as **candidate unlanded**, not proven unique work. |
| `c51cf8d9f0aa25227bd03a5ec378ad64715ac64a` — Add fm-brandon-queue-push helper and colocated test | `overnight/queue-push-helper`, `remotes/deighton/...`, `remotes/origin/...`; parent `2e61f527...`; 2026-09-24 | One commit ahead of `origin/main`; exact ancestry against local main not completed; **candidate unlanded**. |
| `be1ec4b62d103e79969edf8cbc17362aeebf4edd`, `b229a02d05344aec080f1642420fef98e70fb08b`, `593a56e6a05b90082935314ec76c0644652b4ac2`, `c07673ef27d4ebdf9ae4d7f15576e1547d63f28f`, `e0807c410ffa9943a1f1b8d7d6171ebef42da4d7`, `b5f3dfe38ff71b6d61ad254ae4d118728c48a983` | `fm/system-repair-sprint-0924`, remote-tracking ref; six-commit chain shown by `git log origin/main..fm/system-repair-sprint-0924` | Candidate unlanded side-branch history. Prior inventory identified `be1ec4b` as teardown printf fix and the remaining five as CI/test/lint/CI re-trigger adjustments. The exact branch is retained; no merge/landing assertion beyond the branch-vs-origin log. |

The patch-equivalent `50abe4e0` is not repeated in this table because its exact patch is already landed as `973ff553`. Other historical `origin/*` / `deighton/*` refs can be ahead of the current `origin/main` because they are remote branches with independent work, not proof they were produced by the twelve removed local worktrees. No remote server state was queried.

### Registered project checkouts in prior same-day inventory

`data/core-branch-inventory-20261015/report.md` names these 12 **genuinely unlanded side-branch commit hashes** in the registered Core-Distro and Firstmate project checkouts, checked there against local `main`; it also lists touched files, subjects, branch, and whether a test path was included. They are reproduced here so the “other unlanded work” finding is not hidden:

- Core `fm/core-mobile-fix`: `7922e94f6b5eb4f7ba00d3808ccc1ed050e27c76`, `3fc80c7fb85beaefc0f2d746c4e45e8fe7b2a0a5`, `349eaaf694f43a937efb0d2802677ff0a5001584`.
- Core `fm/core-stream-a-checkpoint-0924`: `e93cc10812334b8c8ce419e4982df4f84901f160`, `aa9de8343a3ebfdb6acaa0135feaaab2155462c2`, `676546d4d0044f044ab6cb62afadfe62e6cbb76c`.
- Firstmate `fm/calm-worker-version-consistency`: `d83e6f216fb5f05feccc20b5c195089694569acf`.
- Firstmate `fm/system-repair-sprint-0924`: `be1ec4b62d103e79969edf8cbc17362aeebf4edd` (also listed above; count once).
- Firstmate `fm/tool-auto-update`: `8f6216b281aeee56c295b94402cb1161227de70a`, `70a8ca1d59c0eb3d58b33b7d0adc295a80fd02a9`, `dac9e8e8e547fcd3c84a696a491119bbb5a78cfd`, `3aa352a8d6127f292601ee49ee5008dfd01b8dea`.

That prior inventory reported a total of 12 across five branches; the duplicated `be1ec4b` is not a thirteenth commit. The inventory's complete subject/touched-path/test table is preserved at `data/core-branch-inventory-20261015/report.md`, section “Ahead commits, touched paths, and landing checks.” It reported four of those commits touched tests. This audit did not independently replay all 12 ancestry checks in the separate clone; they are carried forward explicitly as scoped earlier evidence, not represented as fresh command output from this pass. The previous report also says its Firstmate local `main` was 17 ahead / 47 behind `origin/main`, so branch-vs-remote must not be confused with reachability from that checkout's local default branch.

**Therefore:** at least the 12 previously inventoried side-branch commits plus the now-confirmed watcher commit are preserved as refs, and multiple branch-only candidates also exist in the current common dir. This is not a count of unique unlanded feature sets across every Git root: some commits are duplicates, some refs are stale or remotely divergent, and some separate-clone ancestry checks were not refreshed.

## Packfiles, reflogs, stashes, and unreachable objects

Read-only probes on `/home/hd2admin/kun-agent-workspace`:

```text
$ git stash list --date=iso
stash@{2026-10-06 04:30:34 +0100}: On main: local AGENTS.md mod pre-sync-20261006
stash@{2026-09-23 22:25:58 +0200}: On fm/afk-return-dir-fix: status-dir-validate patches from /10 worktree
```

`git fsck --full --no-reflogs --unreachable` returned many unreachable blobs/trees and commit objects. It did **not** mean each object is unique unrecoverable work: the output includes objects held by reflogs/stashes and old no-mistakes validation/evidence commits. The recent unreachable-commit summary included temporary baseline-root-fix stash/index commits at 02:15–02:19 on Oct 15 (`3b646fb`, `d64a4df`, `43364e0`, `4c95590`, `c1b244e`, `ca40d98`, `6ebf57b`, `ee23bfe`) with reflog descriptions `index on ...` / `WIP on ...`; these are stash/work-in-progress snapshots rather than verified lost task commits. They remain object-readable now. No `git gc`, reflog expiry, or pruning was run.

The latest reflog output identifies the 051 cherry-pick and explicit revert (shown above), and the 50/bab landed commits. The actual commit `051cd56d` still has branch and remote-tracking references; it is not merely an orphan. There may be older unreachable commits in the complete output; because no prior inventory maps them to the twelve removed worktrees, this pass does not label arbitrary old evidence commits as lost product work.

Packfiles were not rewritten, unpacked, or pruned. The object database was inspected with `fsck` only. A pack containing a commit proves its object remains available, not that a deleted untracked file was ever committed or packed.

## What is and is not proved

**Proved now:**

1. The two alleged recovered code changes are present in Git history/refs; `50abe4e0` patch is landed, `051cd56d` is preserved but unlanded, and `c020fa22`'s identical patch landed as `23f0468e` within `bab949ac`.
2. Multiple current registered worktrees contain untracked files and/or tracked modifications. The tracked-only + ahead-only check is not a valid emptiness test.
3. The accessible host has stale Treehouse `.git` pointer files to missing `/tmp` gitdirs, and Git still has other work in branches, remote-tracking refs, reflogs, stashes, and unreachable objects.
4. The twelve removed worktrees cannot be individually re-audited from `git worktree list`: removal removes them from the current registry. No before-removal manifest was found in the audited project records. Their precise identities and per-worktree former tracked/untracked file state are not established by current status output.

**Not proved:**

- That no untracked file existed in any removed worktree.
- That any specific untracked file was deleted by the 12 removals.
- That all commits/remotes on the host were enumerated across inaccessible accounts or servers.
- That all refs in every historical clone/repository have been classified for unique feature content.

## Recommendation

Do not treat the 12 removals as proven safe. Preserve the currently named branches, reflogs, stashes, and dirty/untracked work until a separate owner decides disposition. To resolve the yes/no loss question, compare the exact twelve removed slot identities against a pre-removal snapshot or the cleanup's captured command log, especially `git status --porcelain=v1 --untracked-files=all`, untracked file hashes, branch/HEAD refs, reflogs, and stash/object inventory. Without that contemporaneous evidence, the responsible conclusion remains **unknown**, not “nothing was lost.”

## Audit execution evidence and limits

Representative commands actually run:

```sh
find /home/hd2admin -name .git -print
find /home/hd2admin/.treehouse -type f -name .git -print0
# For each discovered repository root:
git -C "$repo" worktree list --porcelain
git -C "$repo" branch -avv
git -C "$repo" status --porcelain --untracked-files=all
git -C "$repo" rev-list --count origin/main.."$ref"
git -C "$repo" merge-base --is-ancestor "$commit" origin/main
git -C "$repo" reflog --all --date=iso-strict
git -C "$repo" stash list --date=iso
git -C "$repo" fsck --full --no-reflogs --unreachable
git -C "$repo" show "$commit"
git -C "$repo" show "$commit" | git -C "$repo" patch-id --stable
```

Initial access constraints were also recorded: `ctx_read` rejected the supplied account/cross-home policy pointers because they were outside the isolated worktree, while direct read-only file reads succeeded. The provided two durable Controller board files under `/root/agent-work/deightonllm-firstmate/` were absent (`ENOENT`). The pinned policy hashes themselves matched all six provided hashes by `sha256sum`. The required pre-session secret-scan executable `/home/hd2admin/kun-agent-workspace/bin/agent-secret-scan` was absent; this is recorded as a policy/tooling gap, not as evidence about Git data.

The shared decision-hold completion gate was **not run**. The required skill says to run `bin/fm-decision-hold.sh complete <origin> --none` only after a semantic inventory; inspection of that script shows it requires compatible `tasks-axi` and, when task metadata exists, appends completion attestation/status. The task explicitly forbids tasks-axi and allows writes outside this isolated worktree only to this report and the named status file. Therefore running the gate would violate the stated task boundaries. No unresolved captain choice was found in the report beyond the historical-evidence limitation; this closeout remains blocked on the incompatible gate requirement, not on Git recovery work.
