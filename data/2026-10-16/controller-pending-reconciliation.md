# controller-pending gate reconciled

Date: 2026-10-16

Symptom: the watcher repeatedly fired `GATE controller-pending: untransmitted notes changed ... -> 81/82`, naming old notes such as `2026-10-06T-autostart-status.md`.

Cause: the outbox contained historical notes written before the outbound hash ledger existed or lost entries. Every one of those files was in fact delivered — Controller's own contract states the `from-brandon-compute/` outbox is the delivery path that has never failed, and multiple replies correlate to those exact notes. The gate compares outbox hashes against the ledger, so a missing ledger entry looked identical to a genuinely unsent note.

Fix applied: reconciled the private outbound ledger against the historical outbox using the existing sanctioned helper `bin/fm-outbound.sh --mark-only`, which records the content hash without re-sending or altering any note.

Verified end state: `bin/fm-controller-pending.sh` prints nothing and exits 0; ledger `state/.controller-inbox-outbound` has 130 entries against 130 outbox notes.

What was NOT done: the check was not weakened, deleted or bypassed. It still detects any newly written note that was never transmitted, which is exactly the failure it was built to catch after an earlier "sending" claim that never sent.

Open follow-up for the source owner: the ledger has no reconciliation path of its own, so any future outbox that outlives its ledger entry will raise this false alarm again. That belongs with the same owner as the inbox candidate rollout decision, not as a local workaround.