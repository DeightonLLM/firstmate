# Merge packet

`bin/fm-merge-packet.sh` produces one Markdown packet for a repository and a set of candidate branches.
The packet carries everything the Captain needs to say one word, so a merge decision does not need a re-read of branch state, diffs, test evidence, and conflicts.
The Captain gives the merge word.
The packet only informs it.

## Why this exists

Every merge in a project costs the Captain a long re-read of the branch state, the diff, the test evidence, and the conflicts.
The work of assembling that evidence is mechanical, so it belongs in a tool rather than in a session that reads it by hand.

`docs/core-saas-branch-state-map.md` records the failure this tool is built against.
A previous session wrote and pushed a redundant fix because it did not first list the branches and read their commits, then spent a lane proving what was already known.
The standing rule from that file is that before writing any fix in that repository, list the branches and read their commits.
A merge packet serves the same purpose for a merge decision, because it makes the state of every candidate branch legible in one artifact before anything is written.

The per-branch structure follows the merge recommendation format already recorded in the backlog item `wo0005-3-merge-recommendation`.
That item requires a diff summary, what the change fixes in plain terms, the blast radius, test evidence with real output, a rollback plan with an exact command and a verification, a recommendation, and proven conflicts.
The packet produces those per branch, and adds the identity, the push state, the byte-identical-copy invariant check, the proposed merge order, and the single closing decision.

## Usage

```sh
bin/fm-merge-packet.sh --repo <path> --branch <branch> [<branch> ...] --out <file>
bin/fm-merge-packet.sh --repo <path> --stdin --out <file>
```

| Option | Meaning |
|---|---|
| `--repo <path>` | The repository or worktree to report on. Required. |
| `--branch <name> ...` | Branch names. Repeatable, and one flag may carry many names. |
| `--stdin` | Read additional branch names from stdin, one per line. |
| `--out <file>` | Write the packet to this file. The default is stdout. |
| `--base <ref>` | Override the detected base branch. |
| `--parity <a>=<b>` | An extra pair of paths that must stay byte-identical. Repeatable. |
| `--evidence <path>` | An extra evidence artifact to cite. Repeatable. |
| `-h`, `--help` | Print the usage and exit 0. |

Exit codes are 0 for a written packet, 1 for an error such as a missing repository or an unresolvable branch, and 2 for a usage error.
A missing repository path is reported with the exact path that was given.

## What the packet contains

The packet is a single Markdown document with these sections in this order.

1. A header with the generated-at timestamp, the host, the repository path, the remote, the base branch and its commit, and the branch count.
2. A one-screen summary table, so the whole decision can be read in one pass before any detail.
3. The method and safety statement, which states the read-only boundary and the evidence labelling rule.
4. The base branch, the base commit, and the merge base of each branch against that base.
5. One detail block per branch, each with identity, diff summary, plain-terms change summary, blast radius, the invariant check, test evidence, conflicts, rollback, and recommendation.
6. The proposed merge order, with each step proven and the tool output quoted verbatim.
7. The single decision requested, which is the last section and states what one word authorises and what it does not.

### Identity

The identity block carries the branch name, the full head commit, the subject, the author, the author date, the merge base against the base branch, the first parent of the head, the commit count ahead of the merge base, and the push state.

The push state is read with `git ls-remote --heads origin <branch>`.
`PUSHED` means the remote branch is at the same commit.
`PUSHED, REMOTE BEHIND` means the remote exists but sits at an older commit.
`NOT PUSHED` means the remote has no branch of that name, so the work exists only on this machine.
`UNKNOWN` means the remote could not be reached, and the packet says so rather than guessing.
`NO REMOTE` means the repository has no origin to compare against.

A local-only head is a genuine risk, because merging it merges work that no other machine holds.
The packet flags it in the summary table, in the identity block, and in the recommendation.

### Diff summary

The diff is taken against the merge base of the branch and the base branch, not against the branch point of the last commit.
The base branch is detected, never hardcoded.
The detection order is the remote HEAD symbolic ref, then `origin/main`, then `origin/master`, then a local `main`, then a local `master`.
`--base` overrides the detection.

The summary lists every changed file with its status and its insertion and deletion counts, plus a total.

### What it changes, in plain terms

This section is derived from the actual diff content and the commit message, never from the branch name.
It carries the commit subjects on the branch, and for each changed file the regions the diff hunks touch and a small sample of the representative added and removed lines.
The region list comes from the diff hunk headers, so a change in a named function or region is named as such.

### Blast radius

The blast radius names the changed files and the changed line count, and it names the files that more than one branch in the same packet changes, because those are the files where the branches collide.
It also lists the other tracked files in the repository that reference the changed files by name or by path, which is the practical dependency signal.
In the Core Distro repository, a change to `staged-export-test/leadlists.php` is referenced by dozens of tracked files, including the deploy tooling and the evidence record.

### Invariant check: copies that must stay byte-identical

This is the most important check in the packet.

Some repositories carry the same file in two places, and the two copies must stay byte-identical.
In the Core Distro repository, `staged-export-test/leadlists.php` and `current-core-distro/leadlists.php` must stay byte-identical, and that invariant is recorded in `data/core-remediation/plan.md`.

The packet finds these groups automatically.
It lists the tracked files of the base commit, groups them by file name, and keeps the groups whose members share one blob in the base commit.
A group is reported for a branch when the branch changes at least one of its members, because that is what breaks parity.
`--parity <a>=<b>` adds an explicit group, for a pair the repository does not express by name.

For each group, the packet reports the sha256 of every copy as it exists on that branch, computed from the git object rather than from the working tree.
The verdict is `HOLDS` when every copy is present and the digests are equal, and `BROKEN` when a copy is missing or the digests differ.
A broken parity produces a `DO NOT MERGE` recommendation, because merging that branch breaks the invariant.

### Test evidence

The packet never runs a test suite.
Running one is slow, and it mutates fixtures, so the packet lists the tests and the commands and leaves the run to the reader.

The packet finds the test files in the branch tree, the test files that reference a changed file, and the test files that the branch itself adds.
For each it gives the direct run command, inferred from the file extension, and it separates the aggregate runner scripts in the repository.
It also cites the recorded evidence artifacts in the repository that mention the changed files.

Every row is labelled with its provenance.
`INHERITED FROM A REPORT` means the result is the prior record and the artifact path is cited.
`NOT RUN BY THIS PACKET` means the test exists and was not executed here.
A branch with no test that touches its changed files gets the `MERGE AFTER TEST EVIDENCE` recommendation, and the packet says plainly that this is a gap in the evidence rather than a pass.

### Conflicts

Every conflict claim is proven with `git merge-tree --write-tree --messages <a> <b>`, and the tool output is quoted verbatim, including the conflict stage lines and the `CONFLICT (content)` lines.
The return code is reported next to the verdict.
A return code of 0 is `CLEAN`, a return code of 1 is `CONFLICTING`, and anything else is `UNTESTED`.
The packet never implies a clean merge that was not proven.

The all-branches verdict is one of `CLEAN`, `CONFLICTING`, or `UNTESTED`.
It is `CLEAN` only when every step of the proposed order merged clean in sequence.
It is `CONFLICTING` when the sequential merge hit a conflict.
It is `UNTESTED` when the sequential merge could not be completed.

### Rollback

The rollback block gives the exact undo command for the proposed merge order, both before and after the merge is pushed, and the exact commands to verify that the rollback worked.
The verification is the working tree status, the top commit, and the diff against the base commit, which must not list the files the branch changed.

### Recommendation

One line per branch, with the reasons beneath it.
The vocabulary is `MERGE NOW`, `MERGE AFTER <branch>`, `MERGE AFTER PUSH`, `MERGE AFTER CONFLICT RESOLUTION`, `MERGE AFTER CONFLICT PROOF`, `MERGE AFTER TEST EVIDENCE`, and `DO NOT MERGE`.

The first applicable rule sets the verdict, and every applicable reason is listed underneath, so nothing is hidden by the verdict.

1. A broken byte-identical parity gives `DO NOT MERGE`.
2. A branch whose own merge step conflicts gives `MERGE AFTER CONFLICT RESOLUTION`.
3. A branch whose own merge step could not be proven gives `MERGE AFTER CONFLICT PROOF`.
4. A branch with no test evidence gives `MERGE AFTER TEST EVIDENCE`.
5. A branch that is not first in the proposed order gives `MERGE AFTER <the branch before it>`.
6. A head that is not on the remote gives `MERGE AFTER PUSH`.
7. Anything else gives `MERGE NOW`.

### Proposed merge order

The order merges the smallest contested change first, so every intermediate state is the smallest possible increment on the base and stays shippable.
A branch is contested when more than one branch in the packet changes it.
The order is built greedily and only accepts a branch that merges clean against the accumulated state, so every step in the published order is proven rather than assumed.
The packet shows the verdict and the return code for each step, and the verbatim tool output for each step.

### The single decision requested

The last section is a delimited block that states what one word from the Captain authorises and what it does not authorise.
It authorises the merge commits for the listed branches, in the proposed order, and the push of those merge commits.
It does not authorise a deployment, a production database change, a credential rotation, work in another repository, a merge of anything not listed, a history rewrite, or an edit to the reported code.
Merge authority is the Captain's alone, and the packet does not widen it.

## The read-only boundary

The script is a reporter.
It never runs `git merge`, `git rebase`, `git checkout`, `git reset`, `git stash`, `git cherry-pick`, or `git push`.
It never writes to the target repository, and it never touches a project working tree.

The conflict proof is the one part that needs git to write something, because `git merge-tree --write-tree` materialises the merged tree.
The script runs that proof with `GIT_OBJECT_DIRECTORY` redirected to a temporary directory and `GIT_ALTERNATE_OBJECT_DIRECTORIES` pointing at the real object store, so the merged tree and the temporary merge commits land in the temporary directory and the real repository receives nothing.
The temporary directory is removed when the run ends.

The test suite proves this rather than asserting it.
It captures the fixture HEAD, the fixture working tree status, the reachable commit count, and the total object count before and after a run that exercises every code path, and it requires all four to be unchanged.

## Verification

```sh
shellcheck --norc --external-sources -- bin/fm-merge-packet.sh tests/fm-merge-packet.test.sh
bash tests/fm-merge-packet.test.sh
```

`bin/fm-lint.sh` is the single owner of the repository shell-lint definition, and it runs the same flags over `bin/*.sh`, `bin/backends/*.sh`, and `tests/*.sh`.

The test suite builds its own fixture repositories under a temporary root and never asserts against a real project.
It covers the branch and head identity, the parity check in both directions, the conflict verdict in both directions, the not-pushed flag, the rollback commands, the closing decision section, the stdin mode, the missing repository path, the unknown branch, the required section list, and the no-mutation proof.

## Limits

The packet reports git state and the evidence recorded in the repository.
It does not run a test suite, it does not judge whether a change is correct, and it does not replace the Captain's review of the behaviour change itself.
Its conflict verdicts are merge verdicts, not behavioural verdicts.
A clean merge of two branches that change the same behaviour in different ways still merges clean, and the packet will not pretend otherwise.
The recommendation is a reading of the evidence, not an authorisation.

## Landing note

`docs/merge-packet.md` must be classified in `docs/documentation-audiences.json` before it is tracked.
The audience check compares the tracked prose surface against that inventory and fails on an unclassified file, so the file needs an entry with the `operator-current` audience when this change is landed.
