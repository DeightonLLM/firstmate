# Outbound order delivery review (2026-10-15)

## Scope and method

Read `bin/fm-outbound-order.sh` end-to-end (all 413 lines; full read plus line-numbered targeted reread), read all of `tests/fm-outbound-order.test.sh` (218 lines), and inspected `bin/fm-outbound.sh`, `bin/fm-to-controller.sh`, `bin/fm-send.sh`, `bin/fm-spawn.sh`, `bin/fm-decision-hold.sh`, and related references/search results. Checked the six supplied baseline SHA-256 values; all matched. Commands used for evidence included `sha256sum` on the six policy/context files, `lean-ctx overview`, and scoped repository searches for outbound-order and dispatch references. I did not run tests, invoke SSH/SCP, access an order system, use credentials, run tasks-axi, or change project files.

## Safety verdict

**Conditionally safe as a standalone delivery primitive, but not yet safe to wire into automatic dispatch without additional integration/operational safeguards.** Static review found the requested core protections present. This is not a live remote verification or a full adversarial audit; see UNVERIFIED items below.

- **Order-ID traversal:** rejected. `validate_id` requires `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$` (`bin/fm-outbound-order.sh:51-53`), and both CLI paths invoke it before work (`:393-407`). The remote program independently rejects characters outside `[A-Za-z0-9_-]` before constructing `$root/.../$id...` paths (`:145-154`). Thus slash, dot-dot, and leading punctuation do not reach paths. The remote-side pattern alone is looser on initial characters, but its caller-side validation prevents that in normal CLI use.
- **Remote checksum mismatch advancing state:** no such path found. The remote `commit` checks staged bytes before publication and deletes a mismatching stage (`:214-219`); it refuses a different existing order (`:220-230`), and only then writes/verifies the receipt (`:240-254`). `verify` checks the remote order and receipt before returning a state (`:259-267`). The local parser rejects remote verification errors, multiple lines, wrong digest, invalid state, and invalid warning (`:290-309`). `deliver` writes transferred/accepted only after successful commit and a verified remote state (`:347-353`). `verify` updates local receipt only after `read_remote_state` returns successfully (`:363-368`). A failed mismatch therefore does not advance the local receipt; an already-existing local state is left as it was on failure.
- **Transport failure mistaken for delivery:** no. SCP failure attempts cleanup and exits with the prior local state; the error says transport failed (`:343-346`). Commit failure likewise exits before writing transferred/accepted (`:347-349`). A successful SCP is not sufficient: remote commit and subsequent remote verification must also succeed before local advancement (`:347-353`). Ambiguous transport outcomes are not claimed delivered; they may leave an orphaned remote staging file if cleanup itself fails, which is retried best-effort only (`:343-345`).
- **Acceptance without matching acknowledgement:** no path found. The remote verifier starts at transferred and upgrades to accepted only if the ack is a regular non-symlink file whose bytes exactly equal `order_id=<id>\nsha256=<expected>\n` (`:271-281`). The expected hash has already been checked against the remote order and its checksum receipt (`:264-270`). An absent or invalid ack remains transferred (an invalid one yields `invalid-worker-ack`). Local state accepts only the parsed remote state (`:295-309`, `:350-353`, `:367-379`).
- **Write locations:** local durable receipts are under `$FM_HOME/state/outbound-orders`, with checks against symlink/non-directory `FM_HOME`, `state`, and receipt directory, mode 0700 for the receipt directory and 0600 receipt files (`:70-107`). Remote writes are under the SSH account's `$HOME/to-brandon-compute/{inbox,receipts,accepted}`; destination directories are created and checked against symlinks/non-directories (`:157-177`). **Exception:** delivery also creates a temporary snapshot under `${TMPDIR:-/tmp}` (`:319-324`), mode 0600, removed by an EXIT trap. This is an intentional transient write outside the local durable receipt directory, but it means the script does write outside its own state/remote directories. If the requirement means “no write anywhere outside these directories,” the answer is no. Temporary cleanup is best-effort through the trap. The script does not write to the selected source file.

### UNVERIFIED / residual risks

- No test execution or real-remote exercise was authorized/performed. Whether the remote account has the required `bash`, `sha256sum`, `awk`, `cmp`, `ln`, and directory permissions is unverified; a permitted isolated fake-SSH run would establish the local behavior, and an explicitly authorized remote smoke test would be needed for actual account/tool compatibility.
- The code checks that `$HOME` itself is an absolute, non-symlink directory (`:157-162`); behavior where ancestor components of `$HOME` are symlinks, unusual remote `HOME`, concurrent writers, filesystem semantics for hard-link publication, and SSH/scp implementation compatibility were not exercised.
- The remote `verify` path is read/verification-only except that every CLI invocation calls `prepare_local_state` first, which may create/chmod local state directories (`:70-96`, `:401-407`). This is a local side effect by design.

## Relationship to `bin/fm-outbound.sh`

They solve **different outbound channels; neither replaces the other**.

- `bin/fm-outbound-order.sh` is a fixed-host, SSH/SCP order-delivery protocol with queued/transferred/accepted states, remote SHA-256 receipts, and a worker acknowledgement contract (header and `:1-21`, implementation `:213-281`). It publishes an order file to Brandon compute's `~/to-brandon-compute/` tree.
- `bin/fm-outbound.sh` sends an existing Markdown message to the Controller exchange and local `BRANDON-COMPUTE-COMMS/from-brandon-compute` mirror, while recording a content-hash loop-suppression ledger (`bin/fm-outbound.sh:1-14,17-35,51-65`). It copies bytes; it has no remote order receipt or acceptance protocol.
- `bin/fm-to-controller.sh` explicitly describes its function as Controller note transmission, not order delivery, and says transmission does not imply read/acceptance (`bin/fm-to-controller.sh:1-18,34-49`). `fm-warehouse-guard.sh` and `fm-warehouse-submit.sh` still direct Controller submissions to `fm-outbound.sh` (search results; `bin/fm-warehouse-guard.sh:30-34`, `bin/fm-warehouse-submit.sh:89-92`).

There is some conceptual overlap in that all can transmit files/messages, but their destinations, consumers, and evidence/state models differ. Replacing `fm-outbound.sh` would break the Controller-message/loop-suppression route and is not supported by the code.

## Missing dispatch integration and hook point

Repository-wide scoped search found references to `fm-outbound-order.sh` only in its own source and its test (plus test-runner registration for that test); no dispatch caller invokes it. The header itself documents only manual `deliver <order-id> <local-order-file>` and `verify <order-id>` commands (`:1-21,24-44`).

The dispatch path must explicitly create or select the finalized order payload, assign a stable validated order ID, and invoke `fm-outbound-order.sh deliver <id> <file>` **at the outbound-to-Brandon order handoff, after the order/brief is finalized and before treating the remote dispatch as sent**. Subsequent polling/reconciliation must invoke `verify <id>` and treat `transferred` as delivery only and `accepted` as worker acknowledgement—not as substitutes for completion.

Likely source files to change are:

1. The actual Controller/Hetz dispatch owner that currently assembles and hands off a Brandon order (not identified among the searched `bin/fm-spawn.sh`/`fm-send.sh` paths): add the explicit delivery call and error handling at the handoff boundary.
2. `bin/fm-brief.sh` only if the existing order format is generated there; inspection established it is the generic crew/scout brief scaffold, not a caller of this sender. Do not add transmission to brief generation unless that is the actual order producer.
3. `bin/fm-spawn.sh` only if it is confirmed to be the owner of the Brandon remote-order dispatch. Its header describes spawning direct reports/worktrees and task metadata, and scoped search found no outbound-order hook. It should not be modified merely because it has “spawn” in its name.
4. Tests for the actual dispatch owner, covering delivery failure preventing a false “sent/dispatched” outcome and acknowledgement/reconciliation semantics. The sender's test is already registered by `bin/fm-test-run.sh` (reported match at lines 119-123).

**Hook-point identity is UNVERIFIED:** available source evidence does not identify the upstream mechanism that currently sends these orders to Brandon, so naming a specific dispatch function beyond the outbound handoff would be guesswork. The exact owner would be settled by tracing the live dispatch caller/Controller-side order producer and its existing send command; then wire this utility there, not into unrelated Controller-message `fm-outbound.sh`.

## Test coverage and notable gaps

The suite has nine cases (`tests/fm-outbound-order.test.sh:69-218`): fixed target cannot be redirected by environment; absent remote destination is created and verified; identical resend is idempotent; different existing order is not overwritten; `../` ID is rejected before remote access; SCP failure leaves queued state; corrupt staged payload is rejected; mismatching acknowledgement remains transferred; matching acknowledgement advances to accepted.

It does **not** cover the following distinct behaviors/boundaries:

1. ID validation boundaries other than `../`: empty/too-long IDs, leading underscore/hyphen, dots, whitespace, control characters, Unicode, and accepted edge IDs (letters/digits/underscore/hyphen, lengths 1 and 64).
2. `verify` with missing, malformed, symlink, extra-line, wrong-version, wrong-order-ID, invalid-hash, or invalid-state local receipts; nor unsafe local `FM_HOME`, state, or receipt-directory variants (including symlink and non-directory cases).
3. Unreadable/non-regular/symlink source files; source changing during snapshot; missing checksum tools; checksum utility errors or malformed checksum output.
4. Remote `$HOME` invalid/non-absolute/symlink, pre-existing symlink/non-directory root/inbox/receipts/accepted components, and symlink/non-regular order, receipt, stage, or ack files.
5. Failures in remote prepare, directory creation, SCP cleanup, commit, file hashing, receipt write/chmod/link, and post-commit verification; tests assert SCP failure and staged-byte mismatch but not these other transport/remote failure points.
6. Existing matching remote order with missing or mismatching remote receipt; existing matching receipt; a mismatching pre-existing receipt; hard-link race/competing publisher; and behavior after remote order/receipt changes between deliver and verify.
7. Remote verify returning queued when both order and receipt are absent, and one-present/one-absent combinations; remote order digest mismatch; checksum receipt mismatch; remote output malformed/multiline/extra fields/wrong digest/unknown state/unknown warning.
8. Ack acceptance edge cases: wrong order ID with correct digest, correct ID/wrong digest, missing final newline, extra line/bytes, empty ack, symlink/directory ack, and ack present while order/receipt is absent or invalid. The suite covers only a deliberately mismatching digest and the exact happy-path ack.
9. Receipt transitions across repeated calls and failures: queued -> transferred -> accepted, invalid ack followed by valid ack, accepted receipt later observed without ack, remote disappearance after transfer, and ensuring a failed attempt does not alter a prior transferred/accepted local receipt.
10. Concurrent delivery/verify of the same or different IDs, order-ID reuse with changed source bytes, random/PID temp-name collision, and interrupted process cleanup.
11. Temporary snapshot permissions/location/cleanup, TMPDIR edge cases, and whether cleanup failures leave private payload data behind.
12. CLI argument-count/help behavior, unsupported subcommands, and behavior on non-Bash or unsupported platform tools.
13. Integration behavior: no test proves any actual dispatch path invokes this sender, waits for successful verified transfer, retains/reconciles the order ID, or uses `verify`/ack state. The suite is isolated fake SSH/SCP only; it does not test the real remote.

The list describes uncovered cases identified from the source and suite, not a claim that these are all conceivable defects.

## Recommendation

Keep the utility separate from `fm-outbound.sh`. Before enabling dispatch use, identify the authoritative Brandon order producer/handoff, wire delivery there with explicit failure handling, then add integration-level tests for that caller. The source-level protections for the requested ID, checksum, transport, and acknowledgement questions look sound; actual remote compatibility and the dispatch hook remain unverified. Decide whether the temporary snapshot under TMPDIR satisfies the intended write-scope policy before adoption.

## Completion-gate limitation

I read and followed `.agents/skills/decision-hold-lifecycle/SKILL.md`. This report contains findings/recommendations and no unresolved captain choice identified by this review. However, the required shared completion attestation was **not run**: `bin/fm-decision-hold.sh complete` writes `decisions_reviewed`/`decision_keys` into task metadata and may append to task status (`bin/fm-decision-hold.sh:277-337`), while the dispatch boundary expressly forbids changing any file other than this report and the prescribed status file. Running it would violate that read-only boundary. The captain/firstmate must perform or authorize the completion attestation through the proper owner before treating the scout as fully closed.
