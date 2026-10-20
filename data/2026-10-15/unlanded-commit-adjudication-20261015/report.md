# Unlanded commit adjudication (2026-10-15)

## Scope and method

Read-only inspection of current `main` (`0e8b140150917adab85c9622da4dfc2286f478c0`) and the two named commit objects. Confirmed both commits are not ancestors of `main` (`git merge-base --is-ancestor <commit> main` returned 1 for each). Created detached worktrees under `/tmp` for `main`, `9601685d`, and `c51cf8d9`; ran the relevant tests there; no project source was edited, merged, or cherry-picked. The temporary worktrees were removed after testing.

Commands included:

- `git show --format=fuller --no-ext-diff --no-renames <commit>` for the complete patches.
- `git diff --exit-code main 9601685d -- bin/fm-fleet-snapshot.sh` and the equivalent bearings command: both returned 0 (the files are byte-identical between the commit and current main).
- `git grep`/`git ls-tree` against `main` for the queue-push helper and relevant delivery paths.
- The test commands and outcomes are recorded per commit below.

## 1. `9601685d` — `fix: stream fleet JSON into jq`

**Verdict: ALREADY PRESENT. Do not land this commit to obtain its implementation; current main already has it.**

### Claimed problem and full patch contents

The parent implementation passes potentially large JSON values in `jq --argjson` command-line arguments. Large fleet/backlog input can exceed the operating system's argument-vector limit (`E2BIG`), preventing snapshot generation. The commit changes three files (78 insertions, 61 deletions):

- `bin/fm-fleet-snapshot.sh`: replaces bulk `jq --argjson` payload arguments with JSON streamed through stdin and parsed by `jq -s`, including task projections, inventory summaries, secondmate aggregation, and final snapshot assembly. Small scalar flags remain jq arguments. For example, current main lines 1304–1318 streams the six JSON documents into `jq -s`; lines 488–512 similarly stream task component JSON.
- `bin/fm-bearings-snapshot.sh`: streams the PR-row arrays and snapshot/candidate-PR inputs through jq rather than passing them as bulk JSON arguments.
- `tests/fm-fleet-snapshot-view.test.sh`: adds a 12,000-record synthetic backlog (1,692,028 bytes) and asserts that snapshot and secondmate summary output remain valid and retain all rows (current main lines 154–175).

The commit patch itself adds the same large-backlog test, and its source changes are directly represented in current main. `git diff --exit-code main 9601685d -- bin/fm-fleet-snapshot.sh` and `... -- bin/fm-bearings-snapshot.sh` both returned 0. In current main, the large-backlog test is present and executed; the final snapshot payload is streamed at `bin/fm-fleet-snapshot.sh:1304-1307`, rather than passed in `--argjson` arguments. Thus the specific defect named in the task is fixed in the current behavior. The parent of `9601685d` shows the old final `jq -n --argjson backlog ... --argjson tasks ...` construction at lines 1310 and 1318–1323.

### Test results

- `cd /tmp/fm-unlanded-main-20261015 && bash tests/fm-fleet-snapshot-view.test.sh` — **PASS**, all 16 reported checks, including the 12,000-record/1,692,028-byte test.
- `cd /tmp/fm-unlanded-960-20261015 && bash tests/fm-fleet-snapshot-view.test.sh` — **PASS**, all 16 reported checks, including the same large-backlog test.

The targeted implementation files are identical on main and the commit, and the tested behavior passed on both.

### Landing risk / recommendation

No missing runtime fix remains to land: applying this commit would be redundant for `fm-fleet-snapshot.sh` and `fm-bearings-snapshot.sh`. The test addition is already present on main as well. Treat the commit as **already present**, not as outstanding work. No new defect was observed by the tested large-backlog scenario.

## 2. `c51cf8d9` — `Add fm-brandon-queue-push helper and colocated test`

**Verdict: OBSOLETE as a proposed general-purpose delivery implementation; its code is not literally present on main.**

### Claimed problem and full patch contents

The commit adds two files only (336 insertions, no deletions):

- `bin/fm-brandon-queue-push.sh` (157 lines): scans every non-hidden top-level regular file in a local queue; uses a configurable SSH/SCP command and host; checks for an SSH identity and known-hosts file; copies each file to a remote staging directory; compares SHA-256; renames it into a remote inbox; and records local receipts so the same basename+content is skipped on rerun. It also has a dry-run mode. It does not itself implement a receiver acknowledgement protocol.
- `tests/fm-brandon-queue-push.test.sh` (179 lines): uses fake SSH/SCP programs to check successful transfer, checksum match, receipt/idempotence, failed-checksum handling, symlink rejection, unsafe inbox-path rejection, and current-working-directory independence. Its reported scope is explicitly fake transport, not a live remote transfer.

### Is it already in main by another route?

The helper and its colocated test are absent from the current main tree (`git ls-tree -r --name-only main -- bin/fm-brandon-queue-push.sh tests/fm-brandon-queue-push.test.sh` produced no paths), and `git grep` found no current-main invocation/reference to `fm-brandon-queue-push` or `queue-push`.

However, current main contains a more constrained outbound-order path, `bin/fm-outbound-order.sh`, with its test `tests/fm-outbound-order.test.sh`. That path sends one explicitly selected, validated order to `brandon-compute:~/to-brandon-compute/inbox`, binds it to a local order ID and checksum, refuses to overwrite an order with different bytes, verifies the remote checksum receipt, and distinguishes `queued`, `transferred`, and recipient-`accepted` states (script header lines 2–17, validation at 56–59, transfer at 338–359). This is not a byte-for-byte or interface-equivalent replacement for c51: c51 mirrors arbitrary queue files to `/home/hd2admin/brandon-inbox`, while the current path handles a selected structured order under `~/to-brandon-compute/` and supports explicit remote acknowledgement. There is no evidence in main that the generic bulk queue semantics are still called for. The current implementation is therefore a successor for the demonstrated controller-to-Brandon order-delivery need, not proof that an arbitrary queue mirror exists.

### Test results

- `cd /tmp/fm-unlanded-c51-20261015 && bash tests/fm-brandon-queue-push.test.sh` — **PASS**, `pass=18 fail=0`, using fake transport only.
- There is no `fm-brandon-queue-push` helper or its test on main, so that test cannot be run against main without introducing the commit's files (which would violate the read-only comparison). No claim is made that main passes c51's own test.
- To test the current-main delivery route that covers the documented order-transfer use case: `cd /tmp/fm-unlanded-main-20261015 && bash tests/fm-outbound-order.test.sh` — **PASS**, all 9 reported checks (checksum verification, repeat-send behavior, mismatch/overwrite refusal, path validation, transport failure, and acknowledgement handling). The c51 commit's tree has no `tests/fm-outbound-order.test.sh`, so that successor test is not runnable against c51 (`No such file or directory`).

### Risks and recommendation

Do not land c51 as-is absent a demonstrated requirement for the distinct raw-file queue mirror. The current main route is purpose-built for selected outbound orders and includes identity, integrity, non-overwrite, and acceptance state that c51 lacks. The c51 helper adds a second delivery mechanism with different directories and semantics.

Specific risks in c51's implementation, beyond the missing acknowledgement state:

- Queue-entry basenames are not restricted, yet are interpolated into remote shell commands (`mv '$tmp_remote' '$INBOX/$base'`); a filename containing a quote can break out of that quoting. The test checks symlinks but not hostile names.
- The final remote `mv` may overwrite an existing inbox filename; the code does not verify whether that destination already contains different bytes.
- `--host` is caller-controlled, and the pin check only checks that resolved identity/known-host paths exist; it does not establish an allowlist for the destination host. The fake tests do not establish live SSH behavior.
- The helper processes all non-hidden files in the queue, with no per-message size bound despite the “bounded message files” comment.

Accordingly, classify c51 as **obsolete as-is** for current-main order delivery. If an owner confirms a separate need for generic queue mirroring, treat that as a new scoped requirement and do not use this implementation without addressing the above risks. This is a recommendation only; no accept/drop decision or landing action was taken.

## Completion and decision boundary

The `decision-hold-lifecycle` skill was read and the report was semantically reviewed for unresolved choices. This report gives recommendations on the two commits but does not decide whether the Controller should accept or drop either one. The task explicitly prohibits `tasks-axi` and permits writes outside the inspection worktree only for this report and the status event, so no backlog/decision-hold mutation was attempted; the existing Controller decision remains with its owner.
