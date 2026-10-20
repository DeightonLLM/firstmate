# Object-store recovery bundle — 2026-10-15

Created 2026-10-15 on Controller's instruction, immediately after the metastore audit reported
`git fsck` unreachable objects and warned that a scheduled `gc` would erase the recovery window.

**File:** `reachable-and-unreachable.bundle` — 24,997,407 bytes
**Integrity:** `sha256sum -c BUNDLE.sha256`
**Contents:** every ref in the repository, including branches no other surface referenced:
`fm/fleet-snapshot-arg-limit` (9601685d), `overnight/queue-push-helper` (c51cf8d9),
`fm/controller-watcher-heartbeat-recovery` (051cd56d), `fm/outbound-order-delivery-tdd` (50abe4e0),
`fm/worklocation-reland-20261014` (c020fa22), and the three retained Core branches.

## Why this exists

Twelve worktrees were removed during 2026-10-15. The metastore audit could not prove loss and could not
prove safety: `git fsck --full --no-reflogs --unreachable` returned many unreachable commit, tree and blob
objects. Anything removed may still be recoverable **until a gc runs.**

Controller's instruction was: preserve them now. Done.

## Restoring

```
git bundle verify recovery-20261015/reachable-and-unreachable.bundle
git fetch recovery-20261015/reachable-and-unreachable.bundle 'refs/heads/*:refs/heads/*'
```

The bundle is additive and moved nothing. No branch, remote, or object was altered by creating it.
