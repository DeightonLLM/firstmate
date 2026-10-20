# Fleet persistence provisioning attempt — 2026-10-18

## Outcome

No secondmate home was seeded and none was launched. The first authorized seed attempt stopped safely because `fm-home-seed.sh` refuses to assign an already-registered ID to a newly leased home; it requires the existing route to be retired first. The registered path does not exist, but the helper still treats the ID-to-home assignment as occupied. Per instruction, no further IDs were attempted after the first seed failed.

## Pre-seed registry evidence and backup

- Registry: `data/secondmates.md`
- Exact pre-seed backup: `data/secondmates.md.bak-20261018T013812Z`
- `cmp -s data/secondmates.md data/secondmates.md.bak-20261018T013812Z`: PASS
- SHA-256 for both pre-seed registry and backup: `cbabde6026fc202c9dc36cb28fe8c18d9ffb7065a6c6f1065432f68d343a3347`
- Registry remains byte-identical to that backup after rollback.
- Additional per-attempt pre-mutation backup: `data/secondmates.md.bak-20261018T013820Z` (made immediately before first helper invocation).
- `bin/fm-home-seed.sh validate`: exit 0, no output.

The registered IDs and old home paths were not edited manually. All six IDs already have populated charter briefs under `data/<id>/brief.md`; these were read and left unchanged.

## Attempt and verification

Command:

```sh
bash bin/fm-home-seed.sh elevate-p0-repair - --no-projects
```

Output:

```text
🌳 Setting up worktree...
🌳 Leased worktree at ~/.treehouse/kun-agent-workspace-46aafc/17/kun-agent-workspace. Run 'treehouse return ~/.treehouse/kun-agent-workspace-46aafc/17/kun-agent-workspace' to release it.
error: secondmate id elevate-p0-repair is already registered to home /home/hd2admin/.treehouse/kun-agent-workspace-46aafc/6/kun-agent-workspace; retire it before assigning /home/hd2admin/.treehouse/kun-agent-workspace-46aafc/17/kun-agent-workspace
🌳 Worktree returned to pool.
Exit code: 1
```

Post-rollback verification command:

```sh
treehouse status --json | jq -r '.[] | select(.name=="17") | "name=\(.name) status=\(.status) lease_id=\(.lease_id) lease_holder=\(.lease_holder) path=\(.path)"'; test ! -f /home/hd2admin/.treehouse/kun-agent-workspace-46aafc/17/kun-agent-workspace/.fm-secondmate-home && echo 'VERIFY marker: absent (rollback)'; test ! -f state/elevate-p0-repair.meta && echo 'VERIFY live meta: absent'; cmp -s data/secondmates.md data/secondmates.md.bak-20261018T013812Z && echo 'VERIFY registry content unchanged from pre-seed backup';
```

Output:

```text
name=17 status=available lease_id= lease_holder= path=/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/17/kun-agent-workspace
VERIFY marker: absent (rollback)
VERIFY live meta: absent
VERIFY registry content unchanged from pre-seed backup
```

## Remaining blocked

- All six homes remain unseeded: `elevate-p0-repair`, `core-ops`, `whoosh-ops`, `cbddata-ops`, `hetzner-compute`, `backup-dr`.
- Current registered home paths point at missing slots 6, 2, 3, 5, 7, and 8. `treehouse status --json` showed available pool slot 17 was acquired then successfully returned by the helper; no lease remains for that failed attempt.
- Current helper has no supported path to reseed an already-registered ID into a different leased path; its refusal explicitly says to retire the route first. Registry removal/retirement or changing helper behavior would exceed this task's boundaries. Required unblock: main firstmate must authorize and select a supported reconciliation of the stale registry-to-home mapping, then the normal seed helper can be used. Do not launch any secondmate.
- No charter/backlog/session-lock/pre-launch checklist was validated for a seeded home because no home was created.

## Changes and tests

- Created this audit record. No source code or charter brief changed. The only backup files created are the two registry copies listed above.
- Tests added/updated: none.
- Commands: `bash bin/fm-home-seed.sh validate` (passed); seed command above (failed safely with rollback); post-rollback verification above (passed).
