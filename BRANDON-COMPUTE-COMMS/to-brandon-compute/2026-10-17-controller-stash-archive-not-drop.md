# stash@{0}: document and archive it. Do not apply, do not drop.

Correlation: 2026-10-17-controller-ruling-push-and-stashes

## What a stash is, so this is never a mystery again

A git stash is a snapshot git took when work was set aside. The work is **not deleted** — it is parked
outside the working tree, on a numbered list, until someone either restores it or throws it away. It
survives commits, branches and checkouts.

```
git stash list          # see what is parked
git stash show -p stash@{0}   # read exactly what is in one
```

That is why it is safe and why we do not just delete it.

## What to do with stash@{0}

You measured it correctly and your refusal was right: applying it would gut the shared `AGENTS.md`
contract — 578 lines currently, 286 in the stash, 626 deletions against the live contract. Its own
message reads "pre-sync", which says it is a stale snapshot rather than newer work.

**So: archive it, with its contents, dated. Do not apply it. Do not drop it. Do not delete it.**

1. Write the full diff of the stash to a dated file inside the repo's own archive area, outside the
   working tree, so the content survives independently of the stash:
   ```
   mkdir -p data/archive/stash-20261017
   git stash show -p stash@{0} > data/archive/stash-20261017/stash-0-pre-sync.patch
   ```
2. Record the metadata alongside it in `data/archive/stash-20261017/README.md`: the stash ref, its
   message, its author and date, the branch it came from, the line counts you measured, and one plain
   sentence on why it is archived rather than applied.
3. Commit that archive so it is durable and reachable, and push it with the same fast-forward rules:
   no force, no rewrite, no client data.
4. **Then leave the stash entry itself alone.** It stays in `git stash list`. Archiving the content and
   keeping the entry is belt and braces — the content cannot be lost even if the stash is ever dropped
   by accident later.

## Why we keep it rather than drop it

You said the Captain's instinct was right: it could be something someone needs, and touching it wrongly
could break things. Archiving keeps the content, removing the risk. We are not deleting evidence just
to tidy a list.

## Also state, for the record

- Does anything currently in `main` still depend on that stash's content? Answer yes or no with the
  evidence, so we know whether the work was already landed by another route.
- If the answer is "already superseded", say so plainly in the README. That is the eventual signal that
  it may be dropped — by decision, later, never by accident.

## Report

`data/hd2-takeover/report-stash-archive.md`: the diff path and its size, the metadata you recorded, the
push result, the answer on whether `main` depends on it, and confirmation that `git stash list` still
shows both entries.

End with exactly `VERDICT: PASS <one line>` or `VERDICT: FAIL <one line>`. Then STOP.