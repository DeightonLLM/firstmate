# The bash grant was REVERTED six minutes after it was made. Three lanes died on it.

**Correlation:** `controller-bash-allowlist-UNBLOCKED-20261016`

Your unblock worked and I verified it working. **It was then reverted, and I did not notice for
eleven hours.**

## The evidence, by diff

```
02:43  config.toml.bak-bash-grant-20261016   457 bytes, contains "bash"
02:49  config.toml                          445 bytes, no "bash"

$ diff config.toml.bak-bash-grant-20261016 config.toml
21d20
<     "bash",
```

**Exactly one line removed. Nothing else changed.** Something restored the pre-grant file six minutes
after the grant.

## What it cost

```
WO-0011 staging 500 fix      BLOCKED before server inspection
WO-0012 second-signal        BLOCKED
WO-0013 inbound trust        BLOCKED
```

**And the new failure mode is worse than the old one:** `fm-session-start.sh` is itself a bash script,
so a worker cannot now run session start at all. That is a bootstrap failure, not a task failure.

## My fault, specifically

**I verified the grant once, it passed, and I stopped checking.** That is precisely the habit I have
been criticising all night - one convenient signal promoted to a standing assumption. I did not set a
watch on it and I did not re-check before dispatching three lanes against it.

**This is the sixth time that exact pattern has cost real work tonight.** I am not going to describe it
as anything else.

## What I need

Either:
1. **Re-apply `lean-ctx allow bash` and tell me who reverted it**, so it does not happen a third time; or
2. Confirm it is deliberately being reverted, and I will route worker lanes differently instead of
   dispatching work that cannot run.

**I am not re-adding it myself.** Widening a shell allowlist is your decision, and I have already been
wrong about its durability once tonight.

## Unchanged and not at risk

**The Core staging certificate is FIXED and verified from outside:**
```
notAfter Oct 14 2026 (expired) -> notAfter Jan 14 2027, https now returns 500 not 000
```
Root cause was permanent, not a one-off: certbot's `standalone` authenticator could not bind port 80
because nginx owns it. Now switched to `webroot` with an ACME location block, so future renewals work
without intervention.

**The 500 remains open** - `Element type is invalid ... got: undefined`, a React component resolving
to undefined. Backup verified at `/opt/core-distro-staging/backup-20261016-131401`, 112 files.

Aminolifesciences sites on that host: untouched.
