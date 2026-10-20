# Commit provenance audit (2026-10-15)

## Scope and method

Read-only audit of the eight requested commit prefixes. The primary project repository inspected was `/home/hd2admin/kun-agent-workspace`; `git symbolic-ref --short refs/remotes/origin/HEAD` returned `origin/main`, and both local `main` and `origin/main` pointed to `0e8b1401`. The repository was not shallow (`git rev-parse --is-shallow-repository` returned `false`). I also checked the two persistent Firstmate mirrors at `/home/hd2admin/agent-work/firstmate` and `/home/hd2admin/agent-work/deightonllm-firstmate` for objects/refs.

The object checks used `git cat-file -e <prefix>^{commit}`; main ancestry used `git merge-base --is-ancestor <sha> main`; branch reachability used `git branch -a --contains <sha>`. For potential re-lands, I compared stable patch IDs and ran full textual `git diff` comparisons for the relevant pairs. I did not rely on task status records. No checkout, merge, cherry-pick, reset, rebase, fetch, gc, prune, task tracker CLI, or remote operation was performed.

A host-wide read-only `find / -name .git` scan followed by `git cat-file -e` checks found all eight objects in the audited project repo. It also found copies in many disposable `.treehouse` worktrees and `/tmp/fm-*` test-fixture repositories; these are copies/fixtures, not independent evidence that a change landed. The global `find` returned exit 1 because some filesystem paths were not accessible, so this is an all-discovered-accessible-repositories result, not a claim about inaccessible directories. Of the two additional persistent Firstmate mirrors checked, only `c51cf8d9` was present; it was on `origin/overnight/queue-push-helper`, not their `origin/main`.

## Results

| Commit | Exists where | Ancestor of audited repo `main`? | Content-equivalent to which commit? | Verdict |
|---|---|---:|---|---|
| `9601685d` `fix: stream fleet JSON into jq` | `/home/hd2admin/kun-agent-workspace`; `fm/fleet-snapshot-arg-limit` | No | `0118dd4974a6699786f3fd34689720c0056cb243` (`fix: stream fleet JSON into jq`) | **Work landed by a different SHA.** The reported SHA is branch-only, but its full textual patch equals the patch in the main-ancestor commit `0118dd49`. Not lost. |
| `c51cf8d9` `Add fm-brandon-queue-push helper and colocated test` | `/home/hd2admin/kun-agent-workspace`; `overnight/queue-push-helper` and its origin tracking ref; also both persistent Firstmate mirrors on `origin/overnight/queue-push-helper` | No | None found in main | **Not landed in main; no equivalent implementation found in audited main.** Branch-only, not orphaned. |
| `973ff553` `feat: add checksum-verified Brandon order delivery` | `/home/hd2admin/kun-agent-workspace` | Yes | Same change as `50abe4e064a214590d8085f914f3a295663c4607` | **Landed.** This is the main-ancestor version of the original order-delivery work. |
| `50abe4e0` (original order-delivery commit) | `/home/hd2admin/kun-agent-workspace`; `fm/outbound-order-delivery-tdd` and `remotes/no-mistakes/fm/outbound-order-delivery-tdd` | No | `973ff55338cfc566fc7331bc97160be1581a87ae` | **Original SHA is not in main, but its work is present through `973ff553`.** The helper, test, and runner files have identical blob IDs across `50abe4e0`, `973ff553`, and `main`; the documentation commit shows the same added sentence/hunk. |
| `051cd56d` `Recover exact stale watcher child` | `/home/hd2admin/kun-agent-workspace`; `fm/controller-watcher-heartbeat-recovery` and `remotes/no-mistakes/fm/controller-watcher-heartbeat-recovery` | No | `d494b868e2fbf1a7139c88f34ef59f850d5313d2` (`Recover exact stale watcher child`) | **Work landed by a different SHA.** Full textual patch equals the main-ancestor commit `d494b868`; not lost. |
| `c020fa22` `Add explicit brief worklocation option` | `/home/hd2admin/kun-agent-workspace`; `fm/worklocation-reland-20261014` | No | `23f0468ec7bd30e023df26ba0a66cf6a60783f1d` (`Add explicit brief worklocation option`) | **Work landed by a different SHA.** Full textual patch equals the main-ancestor commit `23f0468e`; not lost. |
| `bab949ac` `feat(brief): add --worklocation for briefs operating outside the worktree` | `/home/hd2admin/kun-agent-workspace` | Yes | Itself (main contains the exact commit) | **Landed.** `git branch -a --contains` includes `main` and `origin/main`. |
| `f941d893` `fix(baseline): label cross-home scope instead of reporting readable files unavailable` | `/home/hd2admin/kun-agent-workspace` | Yes | Itself (main contains the exact commit) | **Landed.** `git branch -a --contains` includes `main` and `origin/main`. |

None of the eight commits was orphaned in the audited repository: every `git branch -a --contains` result named a local or remote branch. A `+` before some branch names in Git's output indicates the branch is checked out in another worktree; it does not change reachability.

## Evidence

### Ref and ancestry output

The repository ref listing reported:

```text
origin/main 0e8b1401
main        0e8b1401
fm/fleet-snapshot-arg-limit 9601685d
overnight/queue-push-helper c51cf8d9
fm/outbound-order-delivery-tdd 50abe4e0
fm/controller-watcher-heartbeat-recovery 051cd56d
fm/worklocation-reland-20261014 c020fa22
```

For each requested SHA, `git merge-base --is-ancestor <sha> main` returned success only for `973ff553`, `bab949ac`, and `f941d893`; it returned exit 1 for the other five. Representative exact output:

```text
9601685d ... fix: stream fleet JSON into jq
ancestor-main: no (exit=1)
branches-containing:
  fm/fleet-snapshot-arg-limit

973ff553 ... feat: add checksum-verified Brandon order delivery
ancestor-main: yes
branches-containing:
* main
  remotes/origin/HEAD -> origin/main
  remotes/origin/main

c51cf8d9 ... Add fm-brandon-queue-push helper and colocated test
ancestor-main: no (exit=1)
branches-containing:
  overnight/queue-push-helper
  remotes/deighton/overnight/queue-push-helper
  remotes/origin/overnight/queue-push-helper
```

The firstmate mirrors independently returned `c51cf8d9 exists=yes ancestor-origin-main=no`, with only `remotes/origin/overnight/queue-push-helper` containing it; the other seven prefixes were absent from those mirror object databases.

### Patch/content checks

For the re-landed pairs, the script compared the complete output of `git diff --no-ext-diff --no-color <sha>^ <sha>` using `diff -u`:

```text
9601685d vs 0118dd49...: full textual diffs: identical
051cd56d vs d494b868...: full textual diffs: identical
c020fa22 vs 23f0468e...: full textual diffs: identical
```

The matching changes cover, respectively:

- `bin/fm-bearings-snapshot.sh`, `bin/fm-fleet-snapshot.sh`, `tests/fm-fleet-snapshot-view.test.sh` (78 insertions, 61 deletions).
- `bin/fm-watch-arm.sh`, `tests/fm-watcher-lock.test.sh` (221 insertions, 24 deletions).
- `bin/fm-brief.sh`, `tests/fm-brief.test.sh` (131 insertions, 13 deletions).

`git show <sha> | git patch-id --stable` matched between `973ff553` and `50abe4e0` (`1c08ba621dbc11bc54c50fc244c010e116b69fa2`). Blob IDs for `bin/fm-outbound-order.sh`, `bin/fm-test-run.sh`, and `tests/fm-outbound-order.test.sh` were identical in both commits and current `main`. `docs/configuration.md` has different overall blob IDs because the commits had different parent contents, but both diffs add the exact same sentence to the `state/` description: outbound work-order receipts under `state/outbound-orders/` (`bin/fm-outbound-order.sh`). The main commit `973ff553` is an ancestor of main.

For `c51cf8d9`, `git show --stat` lists only `bin/fm-brandon-queue-push.sh` and `tests/fm-brandon-queue-push.test.sh` (336 insertions). Both paths exist in that commit's tree and are absent from `main`; `git ls-tree -r --name-only main` and `git grep` found no matching helper or queue-publisher implementation. The branch commit describes a checksum-verified SSH queue publisher with idempotent receipts and a fake-transport test suite. The distinct outbound-order mechanism in main is not evidence that this queue-push helper's work was re-landed.

## Conclusion and recommendation

The report that `9601685d` itself was landed was incorrect: it is not an ancestor of main. Its change did land under `0118dd4974a6699786f3fd34689720c0056cb243`. Likewise, the original `50abe4e0`, `051cd56d`, and `c020fa22` SHAs are not main ancestors, but their changes have main-ancestor equivalents. `973ff553`, `bab949ac`, and `f941d893` are actual main ancestors. `c51cf8d9` is the exception: its helper and tests remain on an overnight branch and are absent from main by the checks above; whether to ship that feature is a separate decision, not a provenance conclusion.

For future landed claims, record the SHA and verify `git merge-base --is-ancestor <sha> <default-branch>` in the actual project repository. When it fails, report “not this SHA” until a patch/content comparison establishes whether an equivalent change landed under another SHA.

## Completion-gate note

I read `.agents/skills/decision-hold-lifecycle/SKILL.md`. This report surfaces no unresolved choice required to complete the audit; the possible future decision whether to ship `c51cf8d9` is explicitly outside this read-only provenance task. The skill's prescribed `fm-decision-hold.sh complete <origin-id> --none` writes the originating task metadata (and may update its status log), which is outside the brief's read-only boundary permitting only this report and the specified status file to be written outside the disposable worktree. I therefore did not execute that mutating completion command. The report is present, but the shared completion attestation remains unperformed under the given write boundary.
