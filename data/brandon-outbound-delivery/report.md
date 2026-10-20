# Firstmate-to-Brandon outbound work-order delivery

**Status:** Awaiting a Firstmate decision on the independent checker’s ask-user finding; validation is not complete.

**Scope:** Build a tested, idempotent, checksum-verifiable sender for explicitly selected work orders to Brandon compute, with remote verification and separate queued, transferred, and accepted states.

**No live delivery was attempted.** The only live inbox observation available is the task-provided record that `to-brandon-compute/` was absent locally at 2026-10-03 04:29Z.
The current worker pickup and acceptance remain unverified.
All transfer tests used an isolated fake SSH target.

## Implementation at the submitted local head

Local commit `50abe4e064a214590d8085f914f3a295663c4607` (`feat: add checksum-verified Brandon order delivery`) adds `bin/fm-outbound-order.sh`, its executable behavior suite, a focused-test family entry, and a layout reference in `docs/configuration.md`.
The submitted worktree is clean on `fm/outbound-order-delivery-tdd`.

`bin/fm-outbound-order.sh:23-68` exposes `deliver <order-id> <local-order-file>` and `verify <order-id>`, fixes the target to `brandon-compute`, and restricts order identifiers to safe path components.
`bin/fm-outbound-order.sh:73-137` stores private local receipts under `$FM_HOME/state/outbound-orders/`, atomically updates queued/transferred/accepted state, and binds an order ID to one SHA-256 digest.
`bin/fm-outbound-order.sh:139-288` performs remote preparation, staging, no-overwrite publication, checksum receipt creation, remote inbox verification, and matching worker-ack detection.
`bin/fm-outbound-order.sh:311-381` snapshots an explicitly selected source, records queued before transport, and reports transferred only after matching remote bytes and receipt are verified.

`tests/fm-outbound-order.test.sh:91-218` exercises target pinning, an absent destination, identical resend, mismatch/no-overwrite, unsafe IDs, transport failure, checksum mismatch, invalid acknowledgements, and acceptance acknowledgements.
The tests prove behavior against a local fake SSH endpoint; they are not evidence of a live remote inbox or worker pickup.

## TDD and focused evidence

**RED:** Before the sender existed, `bash tests/fm-outbound-order.test.sh` exited 1 with `bin/fm-outbound-order.sh: No such file or directory` and `not ok - delivery to an absent inbox failed`.

**RED:** A deliberately reintroduced configurable target failed the fixed-target test with `fm-outbound-order: remote inbox preparation failed` and `not ok - configured target override changed the fixed destination` (exit 1).

**RED:** Before invalid acknowledgements were downgraded safely, the test failed with `remote acknowledgement does not match this order and checksum` and `not ok - invalid acknowledgement should preserve transferred state` (exit 1).

**GREEN/REFACTOR:** `bin/fm-test-run.sh tests/fm-outbound-order.test.sh` passed after implementation and refactoring.
The final recorded summary was `FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0 duration_ms=1163` and `FM_TEST_SUMMARY_FAMILY family=pure-contract-unit count=1 duration_ms=1128 failed=0`.
The script printed nine successful cases, including the required six failure/idempotency conditions and the queued-to-transferred-to-accepted distinction.

**Focused lint:** `bin/fm-lint.sh bin/fm-outbound-order.sh bin/fm-test-run.sh tests/fm-outbound-order.test.sh` exited 0 with `ShellCheck 0.11.0 (pinned 0.11.0)`.
`bash -n bin/fm-outbound-order.sh bin/fm-test-run.sh tests/fm-outbound-order.test.sh` and `git diff --check` also passed.

## Repository-wide checks

The full canonical `bin/fm-lint.sh` exited 1 on existing findings outside this change: `bin/fm-brief.sh:272` and `:394` (SC2006), plus `bin/fm-teardown.sh:589` and `:592` (SC2016).
It reported no finding in the changed scripts or test.

`bin/fm-doc-audience-check.sh` exited 1 because existing files are unclassified: `data/BR-AUD-002/report.md`, `data/BR-AUD-005/report.md`, `data/BR-INV-001/report.md`, and the eleven `docs/system-context/` Markdown files from `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` through `WAREHOUSE_BOUNDARIES.md`.
The changed `docs/configuration.md` is already classified as `operator-current` in `docs/documentation-audiences.json`.

## Independent checker and pipeline

The no-mistakes run was started with `--skip=push,ci` to honor the explicit no-push/no-PR/no-merge restriction.
No PR URL exists; Push and CI have not run.

No-mistakes Review first raised four task-scoped auto-fix findings, which were authorized to its pipeline worker.
A later review requested removal of an unused `fakebin/scp` shim.
Firstmate's inbox message `001.msg` explicitly authorized that exact removal, so the task worker responded with `no-mistakes axi respond --action fix --findings stale-scp-test-shim` and moved the handled message into the inbox's `handled/` directory.
The pipeline continued and is now parked at Review `fix_review`, checker head `64fbff22b726c54b529706748fc4695bc4437052`.
Its current gate reports `2 awaiting, 11 auto-fix`.
The local submitted head remains `50abe4e064a214590d8085f914f3a295663c4607`; the pipeline owns its unpublished fixes.

The independent checker requires two further decisions:

> id: `outbound-receipt-state-regression`
>
> file: `bin/fm-outbound-order.sh`
>
> description:
>
> `verify` unconditionally replaces the durable local state with the current remote observation at lines 565-566. If an accepted ack is removed after processing, or a temporary remote outage makes verification return `queued` at lines 427-453, an existing `accepted` or `transferred` receipt is downgraded. The same downgrade path exists after `deliver` at lines 544-547. The intent requires durable queued/transferred/accepted states; decide whether states must be monotonic (`queued → transferred → accepted`) or whether receipts intentionally represent only the latest remote snapshot.

> id: `worker-ack-authority-undefined`
>
> file: `bin/fm-outbound-order.sh`
>
> description:
>
> Acceptance is inferred solely from exact bytes in `accepted/<id>.ack` at lines 448-450; no ownership, worker identity, or authenticated acknowledgement is checked. Any process able to write that path can create the two lines and cause `deliver`/`verify` to persist `accepted` at lines 547 and 566 even though the worker never accepted the order. Repository instructions establish the fixed Brandon host but not the ack-authority boundary, so decide whether remote filesystem access is the trusted worker boundary or whether an authenticated worker-ack contract is required.

No response has been sent to either ask-user finding.
The independent checker has not issued a final verdict, and no-mistakes validation is unresolved rather than passed.
The pipeline's test, document, and lint steps have not yet completed.

## Required next action and limitations

Firstmate needs the captain's decision on whether receipt states are monotonic or latest-observation snapshots, and whether access to the Brandon remote filesystem is sufficient authority for a worker-acceptance acknowledgement.
After those decisions, continue the same no-mistakes run and preserve the push/CI skips.
Do not treat the 04:29Z local absence note or fake-endpoint tests as proof that a live transfer occurred or that Brandon’s worker accepted an order.
