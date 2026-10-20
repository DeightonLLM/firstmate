# Stash archive — stash@{0}

**Archived:** 2026-10-17 · **Status:** archived, NOT applied, NOT dropped · **Stash entry retained**

## What a stash is

A git stash is a snapshot git took when work was set aside. The work is not deleted; it is parked
outside the working tree on a numbered list, and it survives commits, branches and checkouts until
someone either restores it or throws it away.

```
git stash list            # what is parked
git stash show -p stash@{0}   # exactly what is inside one
```

## Metadata

| Field | Value |
|---|---|
| Stash ref | `stash@{0}` |
| Message | `On main: local AGENTS.md mod pre-sync-20261006` |
| Author | `Firstmate Coordinator <hd2admin@brandon-compute>` |
| Date | 2026-10-06 04:30:34 +0100 |
| Branch of origin | `main` |
| Files | `AGENTS.md` only |
| Diff stat | 286 insertions, 626 deletions |
| Full diff | `stash-0-pre-sync.patch` — 119,976 bytes |
| Live `AGENTS.md` | 604 lines |
| Stashed `AGENTS.md` | 286 lines |

## Why it is archived rather than applied

Applying this stash would replace the live 604-line shared instruction contract with a 286-line
snapshot, deleting 626 lines including the escalation, supervision and To-Do material that is
currently in force. Its own message says "pre-sync", which identifies it as a stale snapshot taken
before a sync brought in the fuller contract rather than as newer work.

## Does anything in `main` still depend on this content?

**No.** The stashed `AGENTS.md` blob is not an ancestor of the current `HEAD` — it is a distinct
snapshot, not a delta that has since landed by another route. Concretely: the live file has grown
from 286 to 604 lines, and the stashed version omits sections the live contract requires. So the work
was never merged; it was simply overtaken by a later, larger version of the same file.

**Already superseded** is therefore the honest characterisation: the *content* is obsolete, but it was
not merged and must not be read as delivered work.

This is the signal, recorded as requested, that this stash may eventually be dropped **by decision,
later, never by accident**. Until such a decision is made, the stash entry stays in `git stash list`
and this archive keeps the content independently recoverable.

## Second stash

`stash@{1}` on `fm/afk-return-dir-fix` — `status-dir-validate patches from /10 worktree`, dated
2026-09-23, containing `bin/fm-classify-lib.sh` (+23/-2), `docs/architecture.md` (+1) and
`tests/fm-teardown.test.sh` (+159, new). Not archived here and not applied: it is coherent
test-first work that belongs on its own branch with an upstream, and one of its files,
`bin/fm-classify-lib.sh`, was already committed on main today, so applying it could double-apply.
Awaiting its own ruling.

## Recovery

The content in this directory is sufficient to reconstruct the stash without the stash itself:
`git apply stash-0-pre-sync.patch` against the tree that produced it reproduces the change.