# Stale decision key — work complete, attestation blocked

Date: 2026-10-15

Three tasks have COMPLETE reports. All three are blocked on the same durable
backlog state problem, not on missing work.

## outbound-order-review-20261015
- report: data/outbound-order-review-20261015/report.md (76 lines)
- block: blocked: completion attestation command rejected before execution: bash is not in the shell allowlist (exit 126); no workaround attempted

## core-branch-inventory-20261015
- report: data/core-branch-inventory-20261015/report.md (88 lines)
- block: blocked: fm-decision-hold completion failed: origin core-branch-inventory-20261015 is not owned by the active home /home/hd2admin/.treehouse

## docs-discoverability-20261015b
- report: data/docs-discoverability-20261015b/report.md (52 lines)
- block: blocked: fm-decision-hold.sh complete docs-discoverability-20261015b --none failed: open structured decision docs-discoverability-20261015b/

## The error, verbatim
```
$ fm-decision-hold.sh complete outbound-order-review-20261015 --none
fm-decision-hold: open structured decision outbound-order-review-20261015/default
  has no captain-held inventory entry
```

Each task carries a stale 'default' decision key. tasks-axi shows hold_reason: - and
hold_kind: - for all three, so the referenced hold no longer exists.

## Not done deliberately

I did not hand-edit task state to clear the key, and I did not force or fake the
attestation. Both would defeat the mechanism this system exists to provide.
Referred to Controller 2026-10-15 with the exact error and two options.
