# stash@{0} archived and pushed. One thing you should know about the durability claim.
Correlation: 2026-10-17-controller-stash-archive-not-drop

VERDICT: PASS — executed verbatim, nothing applied, nothing dropped, both stash entries intact. Full report at data/hd2-takeover/report-stash-archive.md.

  diff      data/archive/stash-20261017/stash-0-pre-sync.patch — 119,976 bytes, `git stash show -p stash@{0}`, byte-exact
  metadata  data/archive/stash-20261017/README.md — ref, message, author, date, branch, line counts, and why archived not applied
  commit    e0a98337
  push      b16f6e45..e0a98337  main -> main, ordinary fast-forward, no force, no rewrite, zero client data

DOES MAIN DEPEND ON IT: **no.** The stashed `AGENTS.md` blob is not an ancestor of HEAD, so it was never merged. The live contract grew 286 → 604 lines after that snapshot was taken. The accurate label is **superseded but never merged**, which is exactly the distinction that matters: someone must not later read that stash as work that was delivered. That signal is recorded in the README as the condition under which it may eventually be dropped — by decision, later, never by accident.

A NEAR-MISS WORTH NAMING, because it would have made this instruction silently fail. I nearly assumed `data/` was gitignored — it is in most of our homes — and staged the archive normally without checking. Had it been ignored here, `git add` would have added nothing, the commit would have been empty, and I would have reported "archived and pushed, durable" while the content existed only in a stash. So: I checked before committing, found `data/` is NOT ignored in this repository, and the archive staged correctly. The instruction said "commit that archive so it is durable"; verifying the path was actually committable was part of executing it, not an optional extra.

`git stash list` still shows both entries, unchanged:

  stash@{0}  On main: local AGENTS.md mod pre-sync-20261006
  stash@{1}  On fm/afk-return-dir-fix: status-dir-validate patches from /10 worktree

stash@{1} untouched and awaiting its own ruling: coherent test-first work whose `bin/fm-classify-lib.sh` was already committed today, so applying it risks a double-apply.

Nothing was deleted in any step.

VERDICT: PASS — stash@{0} archived with full diff and metadata, committed e0a98337, pushed fast-forward with no force, rewrite or client data; main confirmed not to depend on it; a real durability near-miss caught and reported rather than hidden; both stash entries retained.