# The real blocker behind tonight's refusals: a stale `default` decision key

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`

I have been reporting the decision-hold completion gate as a blocker all night. I now have the exact error
and it is neither a gate defect nor, in the end, my briefing.

## The exact error

```
$ fm-decision-hold.sh complete outbound-order-review-20261015 --none
fm-decision-hold: open structured decision outbound-order-review-20261015/default
  has no captain-held inventory entry
```

Three tasks carry it:

| task | report | lines | error |
|---|---|---|---|
| `outbound-order-review-20261015` | present | 76 | same |
| `core-branch-inventory-20261015` | present | 88 | same |
| `docs-discoverability-20261015b` | present | 52 | same |

**The work is DONE in all three cases.** The reports exist and are complete. The block is a stale
`default` decision key left on each task, referencing a captain hold that no longer exists in the backlog:
`tasks-axi show` returns `hold_reason: -` and `hold_kind: -` for all three.

## How I misdiagnosed this, three times, in order

1. **"My briefs conflict with the gate."** Partly true — the authorised file scope did exclude the metadata
   the attestation writes. That diagnosis was correct and the fix is to include the metadata in the brief.
2. **"The gate is blocking the team."** Wrong. The gate was refusing because of stale state, not policy.
3. **"Workers are being obstructive."** Wrong, and unfair to them. Every one of them refused correctly and
   reported the exact reason rather than working around it.

**The workers behaved correctly every single time. I was the one misreading the failure.**

## What I need

The stale `default` key on these three task ids is durable backlog state. I will not hand-edit task state or
force the attestation, because that is exactly the kind of state surgery this system exists to prevent.

**Options as I see them, for you to pick:**
- you clear the stale key on those three ids, and I attest and close them immediately;
- or you tell me the supported command to retire a decision key that has no surviving hold, and I run it.

## Also still open from me

- **`--worklocation` is incomplete.** It amends the brief, not the tool sandbox, which still refuses paths
  outside the isolated worktree. Two workers hit this tonight.
- **Shell allowlist denies test execution** to workers, including `/bin/bash`. Four workers could not run
  tests. That is a capability gap no correct briefing removes.
