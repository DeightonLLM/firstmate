# Stash archive report

**Date:** 2026-10-17 · **Subject:** `stash@{0}` archived, not applied, not dropped

## Diff

  path:  data/archive/stash-20261017/stash-0-pre-sync.patch
  size:  119,976 bytes
  full:  `git stash show -p stash@{0}`, complete and byte-exact

## Metadata recorded

  ref          stash@{0}
  message      On main: local AGENTS.md mod pre-sync-20261006
  author       Firstmate Coordinator <hd2admin@brandon-compute>
  date         2026-10-06 04:30:34 +0100
  branch       main
  files        AGENTS.md only
  diff stat    286 insertions, 626 deletions
  live file    604 lines
  stashed file 286 lines

Recorded in `data/archive/stash-20261017/README.md` alongside the diff, including the plain sentence
on why it is archived rather than applied, and the recovery instruction
(`git apply stash-0-pre-sync.patch` against the originating tree reproduces it without the stash).

## Push result

  commit:  e0a98337  docs(archive): preserve stash@{0} content and metadata without applying it
  push:    b16f6e45..e0a98337  main -> main
  method:  ordinary fast-forward. Fetched first: behind 0, ahead 1, merge-base confirmed ancestor.
  client data: zero matches for cbd-campaign, h5-coredistro or SAAS-* in this commit.

One thing worth flagging rather than burying: `data/` was **not** gitignored in this repository, so the
archive staged normally. Had it been ignored the archive would have committed as an empty change and
the "durable" claim would have been false. I checked before committing rather than after.

## Does main depend on this content?

**No.** Evidence: `git merge-base --is-ancestor $(git rev-parse stash@{0}:AGENTS.md) HEAD` returns
false — the stashed blob is a distinct snapshot, not a delta that landed by another route.

The honest characterisation is **already superseded, never merged**. The live contract grew from 286
to 604 lines after that snapshot was taken, and the stashed copy omits sections the live contract
requires. So it must not be read as work that was delivered. That is also the recorded signal that it
may eventually be dropped — by decision, later, never by accident.

## Stash entries retained

`git stash list` after the archive and the push:

```
stash@{0}: On main: local AGENTS.md mod pre-sync-20261006
stash@{1}: On fm/afk-return-dir-fix: status-dir-validate patches from /10 worktree
```

Both entries present. Neither applied, neither dropped, nothing deleted.

## Second stash, for completeness

`stash@{1}` is not archived and not applied. It contains `bin/fm-classify-lib.sh` (+23/-2),
`docs/architecture.md` (+1) and `tests/fm-teardown.test.sh` (+159, new) — coherent test-first work
that belongs on its own branch. It was deliberately not applied because `bin/fm-classify-lib.sh` was
already committed on main today in `ac35147e`, so applying it risks a double-apply. Awaiting its own
ruling.

NEXT: the Captain rules on the two stash entries this report leaves open - stash@{0} is archived, superseded and never merged so it may be dropped by decision, and stash@{1} still holds coherent test-first work (fm-classify-lib.sh, docs/architecture.md, fm-teardown.test.sh) that was not archived because fm-classify-lib.sh already landed in ac35147e | owner: captain | by: 2026-10-22
VERDICT: PASS — stash@{0} content archived with diff (119,976 bytes) and metadata, committed e0a98337 and pushed fast-forward with no force, no rewrite and no client data; main does not depend on it and it is recorded as superseded-but-never-merged; both stash entries remain in `git stash list`, neither applied nor dropped.
