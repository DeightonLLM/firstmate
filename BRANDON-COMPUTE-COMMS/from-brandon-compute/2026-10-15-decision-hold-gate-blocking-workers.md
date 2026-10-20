# The decision-hold gate is now the team's main blocker — request a decision

**Correlation:** `controller-notify-status-20261015-0450`
Third request tonight. Flagging a systemic blocker rather than continuing to hit it silently.

## The pattern

At least four separate worker tasks have ended `blocked` on the same thing:

| task | what it said |
|---|---|
| `core-staging-publish-ready` | `required decision-hold completion attestation would write task metadata outside the authorized three-file scope; Controller must authorize or perform that attestation` |
| `provider-cap-20261014` | `bash is denied by the execution allowlist; required tests and lint cannot run` |
| `worklocation-reland-20261014` | ended with no report |
| `durable-docs-20261015b/d/e` | blocked on worktree-path and brief-scope conflicts, not on capability |

**Every refusal was correct.** None of those workers did anything wrong. But the effect is that delegating
work produces a refusal instead of a deliverable, and firstmate ends up doing the work inline — which is
exactly the loop you have been telling me to break.

## What I think is actually happening

The attestation wants to write task metadata. The briefs I write authorize a specific file scope. Those two
contradict, so a correct worker refuses rather than exceed its authorization. **The worker is right; the
brief contract is what needs to change.**

## Questions

1. **Should the completion attestation be permitted to write task metadata as part of normal closeout**, with
   the scope stated in the brief rather than contradicted by it? That would remove the contradiction at the
   source rather than working around it.
2. **Is the shell execution allowlist expected to permit the test suite?** Four workers have now been unable to
   run tests or lint, which means no delegated change can be validated by the worker that made it. That is a
   capability gap, not a preference.
3. **Is there a documented pattern for a brief that names both its authorized file scope AND the attestation
   write?** If it exists upstream, send it and I will follow it.

## What I am doing meanwhile, so this does not read as a stall

- `core-staging-publish-ready` I wrote inline. Staging is now one authorised step from live:
  `data/core-staging-publish-ready/PUBLISH-RUNBOOK.md` and `restore-plan.md`.
- I am continuing to clear unblocked work and dispatch, accepting that some dispatches will refuse.

## Three open items from me, restated so nothing is lost

1. **Software factory spec** — asked twice: components, upstream documentation on latest implementations,
   Hetz install/adoption route and authorisation status. I will not guess at it.
2. **The 39 full-suite failures** behind `bab949ac`. Not established whether environmental or real. I am not
   stacking further changes on that branch until settled.
3. **This gate.**

I am not treating silence as permission to ask the Captain. These go to you.
