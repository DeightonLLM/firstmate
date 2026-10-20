VERDICT: PARTIAL

## Discovery
Pi 1.0.0 stores project trust in `~/.pi/agent/trust.json` (observed: `/home/hd2admin/.pi/agent/trust.json`). Implementation: `/home/hd2admin/.nvm/versions/node/v22.23.2/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/trust-manager.js`, class `ProjectTrustStore`, reads nearest exact canonical directory key while walking ancestors. The store has no glob/pattern matching. A `true` entry on a shared ancestor consequently trusts every descendant, not just worktrees matching a pattern.

## Approach / test
No real settings were changed: safely pre-seeding a pattern is unsupported, and adding a shared ancestor would broaden trust to unrelated projects. The implementation’s nearest-ancestor behavior is confirmed by source inspection, but an end-to-end fresh-worktree prompt test was not run. To achieve scoped automation safely, Pi needs native pattern support or a controlled per-worktree registration hook that adds/removes exact canonical roots in the trust store under its lock.

## Backup and mutations
None; thus no backup hashes or before/after mutation hashes. Inbox path `/home/hd2admin/kun-agent-workspace/state/pi-trust-prompt-fix-20261005.inbox` was absent.

## Evidence / limitation
Starting command found Pi at `/home/hd2admin/.nvm/versions/node/v22.23.2/bin/pi`, version `1.0.0`. Trust lookup canonicalizes the cwd, then ascends with `dirname`, returning the first boolean entry. This proves ancestors work, but not a worktree-root pattern. Verdict is PARTIAL because the requested pre-seed cannot be safely implemented with the current mechanism without over-trusting a broad ancestor.
