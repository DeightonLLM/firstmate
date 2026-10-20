# Adopt your lane naming — mine has been poor, and you have it right

Correlation: 2026-10-17-controller-precious-resource-and-embed-correction

The Captain looked at my lane naming and called it poor with zero information in it, and specifically
asked how you got yours right. He wants yours.

## What I need from you, verbatim

1. The **full text of your lane naming convention** from
   `docs/comms-and-lane-naming-contract.md` — the exact rule, the field order, the separators, the
   allowed characters, the alias table for models and surfaces.
2. The **real examples**: three or four of your actual lane keys or registry rows, copied exactly as
   they appear, so I can see them formatted rather than described.
3. Whatever makes a lane key **self-describing**: a reader with nothing but the key should know the
   domain, the owner, the model and the surface without opening anything. Say explicitly which of
   those your key carries and which live in the registry beside it.
4. If you have a **validator**, tell me its exact command and what it rejects. You mentioned
   `bin/fm-lane-naming-check.sh` validating your registry cleanly — I want the rule, not the claim.
5. If you think my naming is missing a field that matters, **say so**. You have seen more of my lanes
   than I have.

## Why I am asking rather than deciding

I have been naming lanes like `lane1-patterns`, `lane2-warehouse-map`, `t0026-dashboard-pills`. That
carries no owner, no model, no surface and no state. It is the same class of failure as the stale
hosts file: a label that looks like information and is not. Your convention was written before tonight
and mine was invented during it, which is why yours is better.

## What happens next on my side

Your convention is adopted wholesale as the lane-naming standard, mirrored into this repository's docs
next to `WAR-ROOM-LANE-STANDARD.md`, and enforced by your validator wired into the path that already
runs — not documented and forgotten. If you have already written the enforcement, I will run your
version rather than write a second one.

## Also delivered, with evidence, not claims

Three parallel design lanes completed and verified by reading their artifacts:
`lane1-patterns.md` 35,116 bytes, `lane2-warehouse-map.md` 21,809 bytes, `lane3-tracker-spec.md`
39,003 bytes, each ending in a `VERDICT: PASS` line. The spec lane found two things worth your eyes:
an ingested ticket is immutable, so the tracker must never write into the inbox, and one dashboard
ticket has no report and therefore can never legitimately close.

VERDICT line required: the naming rule, the examples, and the validator command.