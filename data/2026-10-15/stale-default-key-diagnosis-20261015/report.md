# Stale `default` decision-key diagnosis

## Bottom line

There is **no `fm-decision-hold.sh` subcommand that removes a status-only stale key or subtracts a key from an existing `decision_keys` inventory**. The supported status-event way to close a genuinely cleared status-only key is to append `resolved [key=default]: <how it was cleared>` to that origin's status stream, then rerun `complete <origin> --none`. Do not use `resolve`: it is specifically for an active captain-held backlog item and routed dependent work. I did not run any such command or append such an event because this investigation is read-only.

The underlying failure is a **tool lifecycle defect exposed by state hygiene**: the classifier deliberately maps bare `blocked:` / `needs-decision:` status events to `default`, and the completion code cannot distinguish a stale status-only key from a live captain decision after the origin metadata has disappeared. A completed report and an empty captain hold do not themselves close an open status event. `--none` is correctly an attestation of the current review's semantic inventory, not a cleanup instruction for old status events or old metadata.

## Scope and method

Read the complete `bin/fm-decision-hold.sh`, the complete relevant decision-fold logic in `bin/fm-classify-lib.sh`, `.agents/skills/decision-hold-lifecycle/SKILL.md`, `docs/decision-hold-lifecycle.md`, and the focused lifecycle test fixture. Read the primary home's status record and ran read-only `tasks-axi show` for `docs-discoverability-20261015b` as a concrete example of the same error. No `complete`, `hold`, `resolve`, tasks-axi write, test, or file/state mutation was performed. This was source tracing plus read-only inspection; the five-item count is the captain's supplied scope, and I did not independently reconcile five separate task records.

## Exactly where `default` comes from

It is **not** a default command-line argument and it is not synthesized by `command_complete()` from a missing key argument. The source is the backward-compatible status-line parser:

- `bin/fm-classify-lib.sh:154-160` defines the optional syntax as `[key=<slug>]` **before the colon** and explicitly says a line without it uses key `default`.
- `bin/fm-classify-lib.sh:175-187`, `_fm_decision_key()`, returns the explicit bracketed key if present; otherwise its `*) printf 'default'` branch supplies the fallback.
- `bin/fm-classify-lib.sh:210-233` folds the entire status stream. `needs-decision` and `blocked` open/update that key (`:220-225`); `resolved` and `captain-held` close the same key (`:227-230`). An unrelated `done:` does not close it.
- The resulting key is read by `bin/fm-decision-hold.sh:309-315`; line 315 constructs the exact diagnostic `open structured decision <origin>/<key> has no captain-held inventory entry`.

Thus an unkeyed `blocked: ...` or `needs-decision: ...` event opens `default`. A bare `resolved: ...` closes `default`; alternatively the explicit form is `resolved [key=default]: ...`. The key comes from the event history's fallback, not from the literal `--none` argument. Explicit status keys must be placed before the colon; text such as `[key=some-key]` later in the note is not parsed as the key (`fm-classify-lib.sh:175-187`).

## Why `--none` does not clear it

The `complete` path is:

1. `bin/fm-decision-hold.sh:286-295`: exactly one `--none` sets `supplied=''`; it is not interpreted as a deletion request.
2. `:296-299`: any prior metadata inventory is read and unioned with the supplied keys. `sorted_key_union()` at `:131-137` is additive. So even a key already in metadata is retained, not removed by `--none`.
3. `:300-307`: each key in that inventory must already identify a durable captain hold or resolved hold.
4. `:309-318`: the script folds the status stream and refuses any still-open status key absent from the inventory. That is the exact reported error path at `:312-315`.
5. Only after these checks does it write an attestation or transfer status decisions (`:320-334`). The guard therefore fails before any completion write; `--none` cannot reach a write that would close the stale key.

The script intentionally does not infer that a decision disappeared merely because it is absent from the current report/backlog; it never reads report prose (`fm-decision-hold.sh:4-11`). The `--none` meaning is documented at `:28-32` and in `docs/decision-hold-lifecycle.md:16-21`: explicit semantic inventory, not inferred absence. This prevents a report that merely omitted an unresolved choice from silently passing the completion gate.

## Read-only evidence from the primary home

I inspected `/home/hd2admin/kun-agent-workspace/state/docs-discoverability-20261015b.status`. Its exact relevant tail is:

```text
5 resolved: preserve docs/README.md and create new docs/README-index.md [key=docs-discoverability-20261015b]
6 blocked: required decision-hold completion attestation would write task metadata outside the authorized index/report scope
7 blocked: fm-decision-hold.sh complete docs-discoverability-20261015b --none failed: open structured decision docs-discoverability-20261015b/default has no captain-held inventory entry
```

Those last two unkeyed `blocked:` events each open/update `default`; the second records the failing completion attempt itself. I also read `tasks-axi show docs-discoverability-20261015b --full` from the primary home. Its real output includes:

```text
state: in_flight
blocked: no
held: no
hold_reason: "-"
hold_kind: "-"
kind: scout
```

There is no captain hold in this task's `tasks-axi show` output, matching the failure's “no captain-held inventory entry.” Its `state/docs-discoverability-20261015b.meta` was absent on read. This is one directly inspected instance, not evidence that every one of the five has identical status history.

A separate direct `tasks-axi show outbound-order-review-20261015 --full` from this disposable worktree returned:

```text
error: "Task \"outbound-order-review-20261015\" not found in this backlog"
code: NOT_FOUND
```

The primary-home `tasks-axi show` also returned NOT_FOUND for that ID in the observed environment. I therefore do **not** claim to have independently verified that named item's live hold fields; I rely on the captain-supplied reproduction for that item.

## Supported retirement path and its boundary

`bin/fm-classify-lib.sh:154-160` documents bare `resolved:` as closing the legacy `default` key, and `:220-230` implements that close in the status fold. Therefore, when the underlying blocker/decision has actually been cleared, the status protocol's supported retirement event is:

```text
resolved [key=default]: <truthful explanation of how the stale status-only blocker was cleared>
```

Append it through the owning task's normal status-event channel; then retry `fm-decision-hold.sh complete <origin> --none`. It must not be used to conceal a real unresolved captain choice. The no-key form `resolved: ...` also closes `default` under the legacy grammar.

There is **no `fm-decision-hold.sh` command for this status-only retirement**. `resolve` is not an alternative: its header documents that it resolves only after a durable captain decision is linked to dependent work (`:36-39`), and the implementation requires a decision file and routed task (`:370-403`), verifies the hold is active (`:403`), and requires each routed task to be blocked by that hold (`:413-430`). With no captain-held backlog item, it is inapplicable and must not fabricate a captain answer. If stale `default` is already in `decision_keys=` metadata, `--none` also preserves it by union and `verify_hold_durable` will reject the absent hold (`:296-307`); there is no supported inventory-pruning command in this script either.

## Defect versus usage versus hygiene

**Classification: tool defect, with stale status-state hygiene as the trigger; not a user usage error.**

Evidence for the defect: the help/header explicitly supports post-teardown completion using the surviving report and holds (`fm-decision-hold.sh:28-34`), but `origin_open_decisions()` only suppresses old decisions when metadata exists and can establish a terminal state (`:143-158`). If metadata has been removed, it returns the raw open-status fold (`:145-148`), without an equivalent terminal/archive decision. The post-teardown branch then rejects the stale key at `command_complete():309-318`. The existing regression test only proves the terminal exception **while metadata exists**: `tests/fm-decision-hold-lifecycle.test.sh:382-400` leaves an open `default` in the raw fold, has `done:` last, and expects `complete --none` to pass for a non-secondmate with metadata. It does not cover the same terminal status after teardown removes metadata.

State hygiene is also part of the immediate cause: after a blocker is genuinely cleared, the status stream must receive its matching `resolved` event. In the inspected sample, later unkeyed `blocked:` events reopen `default`, including the gate failure itself. But the tool's advertised post-teardown flow has no metadata left to filter terminal history and no `fm-decision-hold` cleanup verb, so this is not fixed by simply retrying `--none`. The accurate conclusion is not “the user should have supplied a key”: the parser intentionally assigns `default` to unkeyed status events, while `--none` means no keys supplied for this review and preserves prior inventory.

## Recommendation

For the existing status-only stale keys, first establish that no real captain decision remains, then close each key with the normal `resolved [key=default]: ...` status event and retry the report completion attestation. Do not run `resolve` for nonexistent holds and do not manufacture a captain decision or a `captain-held` transfer. Separately, fix/test the lifecycle defect: post-teardown completion needs a supported way to distinguish terminal, stale status-only entries from live unresolved decisions without restoring deleted task metadata or weakening the semantic inventory check. Add a regression with a terminal `done:` record and open default key after metadata has been removed.

I read `.agents/skills/decision-hold-lifecycle/SKILL.md`. Its shared completion gate requires running `complete`; this scout's explicit READ ONLY boundary forbids the required mutation, so no completion attestation was attempted. The report is written, but the shared completion gate remains unpassed for firstmate to reconcile under its authority.
