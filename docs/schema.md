# Warehouse record schema

These examples are deliberately small. They describe the minimum sanitized
projection and are not a license to put raw operational data in GitHub.

```yaml
run:
  run_id: CLIENT-AFK-20260916-01
  queue_ref: firstmate:data/backlog.md
  source_commit: <commit-or-null>
  created_at: <UTC-ISO-8601>
  owner: controller
  status: planned | active | blocked | complete

task:
  task_id: <stable-task-id>
  run_id: <run-id>
  source_queue_id: <existing-queue-id>
  scope: <bounded-description>
  host: <approved-host-alias>
  write_boundary: <owned-artifact-or-branch>
  lease_id: <stable-lease-id>
  status: reserved | working | blocked | accepted | terminal

evidence:
  evidence_id: <stable-evidence-id>
  task_id: <task-id>
  digest: sha256:<hex>
  path: <redacted-artifact-path>
  redaction: none | summary-only | secret-scan-passed
  checker_verdict: pending | CHECK_PASS | CHECK_BLOCKED

decision:
  decision_id: <stable-decision-id>
  run_id: <run-id>
  authority: operator | controller | independent-checker
  status: proposed | approved | rejected | blocked
  rationale_ref: <evidence-or-review-reference>
```

Required invariants:

- `task.run_id` must equal `run.run_id`.
- A live task has exactly one valid lease and one owner.
- Two leases may not claim the same task or write path.
- Evidence digests are recomputed before acceptance.
- A replay with the same stable ID and digest is a no-op; a changed digest is
  a review-required conflict.
- No field may contain a secret, token, password, private key, authenticated
  URL, raw chat transcript, or unredacted tenant data.

