# Receipt acceptance evidence - 2026-10-12

## Scope and method

I confirmed isolation before investigating: `git rev-parse --show-toplevel` returned `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/9/kun-agent-workspace`, not the primary checkout `/home/hd2admin/kun-agent-workspace`; `git status --short --branch` returned `## HEAD (no branch)` (clean detached HEAD). I read the scoped plan, both required diagnostic/coding skills, the current pi-subagents tool guide, the task brief, and the known outbound-receipt report using lean-ctx. I made no code changes and ran no tests, network calls, or live polling.

The plan's authority is six bounded evidence scopes and explicitly says the existing Controller owns pickup and narrow helper-permission repair; no duplicate implementation or live pilot until denial is actually reconciled. It requires published, delivered, processed, validated, and landed to remain distinct. Receipt is this lane's only scope.

## Evidence and exact mismatch

The accessible known local evidence is `/home/hd2admin/kun-agent-workspace/data/brandon-outbound-delivery/report.md` (especially lines 1-8, 15-23, 27-30, and 40-65). It documents a local sender at an earlier submitted head, with `deliver` and `verify`, private `$FM_HOME/state/outbound-orders/` receipts, SHA-256 binding, and a remote checksum receipt. Delivery is only called transferred after matching remote bytes and receipt are verified. Acceptance is inferred from exact contents in `accepted/<id>.ack`; the report explicitly says worker pickup and acceptance are unverified and all tests used a fake SSH endpoint. Test coverage listed at report lines 19-22 and 27-30 covers absent inbox, idempotent resend, mismatch/no-overwrite, unsafe IDs, transport/checksum failure, invalid ack, and accepted ack; this is not live remote evidence.

The known mismatch is therefore an evidence/semantic gap, not proof that the Controller pickup repair is missing or that a transfer succeeded: the documented local mechanism can distinguish queued, transferred, accepted, but an `accepted` receipt currently means a matching remote ack file was observed, not authenticated proof that the intended worker processed the order. The older report also records two unresolved checker questions at lines 42-61: whether durable states may regress on a later remote observation, and whether filesystem write access suffices as worker-ack authority. The supported local path today is `deliver <order-id> <local-order-file>` then `verify <order-id>` with the fixed Brandon target and receipt verification, as described in that report; it is not an authorized live pickup or polling procedure.

## Acceptance matrix

| Claim | Accept only with | Present evidence | Result |
|---|---|---|---|
| Published | immutable source/order identity and explicit destination publication evidence | Historical local sender design; no live delivery attempted | Not established for the current order |
| Delivered | matching remote payload and checksum receipt observed through the supported verifier | Fake SSH tests only, per existing report | Not established live |
| Processed / accepted | content-bound acknowledgment from the authorized worker or explicitly approved trust boundary | A matching `accepted/<id>.ack` is the implementation's observation; authority is unresolved | Not established as worker processing |
| Validated | current-code-matched behavioral regression evidence for the acceptance semantics and recovery cases | Existing report records focused fake-endpoint tests passed at that historical head, plus two unresolved findings | Not established for current code/head |
| Landed | authoritative branch/commit and landing evidence | Existing report says no PR and validation unresolved | Not landed |

## Existing-owner delta and dependencies

Smallest receipt-only delta: keep the current sender/receipt owner and Controller pickup owner unchanged; have that existing owner define the ack's authority and monotonicity semantics, then add focused executable cases for stale/missing ack after acceptance, transient verify failure after transfer, and an ack that is present but not attributable to the authorized worker. Do not build another watcher, alter Controller pickup, or create a second receipt mechanism. Admission/current-base and Controller's exact ownership artifact are prerequisites before proposing a change; no delta can be declared delivered from the evidence available here.

## Source limitation / blocker

The task specifically requires reuse of the actual Controller acknowledgment and arming instruction. Those source artifacts are under `/home/hd2admin/kun-agent-workspace`, outside this isolated checkout. Lean-ctx reported `MCP error -32602: ERROR: path escapes project root` when asked to list that primary tree. I did not switch tools to evade that access boundary. The task-provided compact plan summarizes the acknowledgment only as: pickup and narrow helper-permission diagnosis are assigned on HD2, neither delivered nor admitted; it does not include the actual acknowledgment wording, arming instruction, exact current receipt locations, or line references. Consequently I cannot faithfully report those required facts or assert the requested exact current mismatch against the actual Controller instruction. No subagent was launched because its permitted checkout does not contain those source artifacts and using it would not resolve this missing evidence.

No receipt acceptance test or live poll was run. No permanent-denial command was retried. Runtime repair, Controller pickup, delivery, acceptance, validation, and landing are not claimed. The needed unblock is for the supervisor to provide the specifically authorized acknowledgment/arming artifact within the readable evidence boundary, or route those excerpts through the established source owner; then this receipt-only comparison can be completed without reimplementing pickup.
