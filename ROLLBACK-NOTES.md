# Rollback notes

- Task baseline: `ec27cbc256814804bdbcf2eb3a1140482492c22b` on `fm/wire-enforcement-20261013`.
- User-designated main baseline: `ec27cbc`.
- Before phase 1, restore mission changes with `git diff --binary ec27cbc256814804bdbcf2eb3a1140482492c22b..HEAD` and revert the phase commits on this branch; do not push or alter the primary checkout.
- Local host policy files under `config/` are gitignored and must be removed separately if the operator wants to undo the host-specific policy.
