# Fixture-only Firstmate inbox reliability candidate

This directory contains an isolated candidate copied from `state/controller-inbox.check.sh`; it is not installed, wired, or deployed. All inbox routes, state overrides, temporary files, and test resets are rooted under this directory. The test preflight checks path resolution and symlinks before running the poll. Never point this fixture at live inboxes or state.

## Run the deterministic checks

From any directory:

```bash
cd /home/hd2admin/kun-agent-workspace/data/luna6-inbox-candidate-20261016
bash -n controller-inbox.baseline.sh controller-inbox.candidate.sh test-candidate.sh
POLL_OVERRIDE="$PWD/controller-inbox.baseline.sh" bash test-candidate.sh
bash test-candidate.sh
TEST_MIGRATION=1 bash test-candidate.sh
```

The baseline invocation is intentionally expected to exit nonzero: its four RED assertions are real behavior failures (repeat notification, no pending inspection, old-mtime arrival, and repeat delivery of identical content across routes). The same-sweep cross-route duplicate assertion passes on the baseline. The candidate invocation must pass all 12 behavioral assertions. The migration invocation must pass all four checks, including expected candidate exit code 3 for the blocked migration. `RED.log`, `GREEN.log`, and `MIGRATION.log` record the executed outputs. `final.patch` is the candidate implementation diff against the isolated, path-rewritten baseline copy; source digest evidence is in `source-pin.txt`.

## Candidate semantics and limits

- Initial bootstrap counts unique historical content and records it as excluded from routine notifications, not acknowledged. No historical message is automatically marked handled. `--pending` is an explicit manual inspection and can show excluded historical messages still lacking an exact-byte acknowledgement.
- New content is found by content identity rather than mtime. A stable digest produces at most one routine notification across routes and repeated polls. Changed bytes produce a distinct digest; an acknowledgement with the earlier digest is refused.
- `--pending` lists current, unhandled, non-outbound content until its exact bytes are acknowledged. This provides durable discoverability only; it does **not** implement automatic resumption, notification wiring, watcher integration, or model-call orchestration.
- A pre-existing watermark without the candidate's initialization record returns an explicit migration-blocked diagnostic and exit 3 without changing the watermark, notification ledger, or handled ledger. The correct treatment of unseen messages in an existing-watermark installation requires an owner decision. No replay, implicit migration, or silent acknowledgement is attempted.
- These are proposed fixture semantics, not an approved rollout contract. There is no live activation, settings edit, network call, credential use, deployment, service, daemon, or transport change. Product ownership must decide migration treatment, whether/how `--pending` is integrated, and rollout approval before any separate wiring work.
