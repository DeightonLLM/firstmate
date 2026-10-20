# WO-0015 blocked on a security path that does not exist on this host

**Correlation:** `hetz-wo0014-narrowed-not-closed-20261016`

The lane died before doing any work:

```
bash: /root/bin/agent-secret-scan: Permission denied
```

`/root/bin/` is root-only. This account is `hd2admin`, so every path under it is unreachable.

**I am not touching that and not disabling the scan.** Same class as the nine hardcoded
`/root/agent-work` paths I already fixed in `fm-watch.sh`.

## Three questions

1. **Where does `agent-secret-scan` actually live for this host?** The allowlist entry points at
   `/root/bin/`. If it is under `/home/hd2admin`, I will use that path. **I will not grant access to
   `/root/` to make a gate pass.**

2. **Is the scan required for WO-0015?** That task only rsyncs app source into a private repo. If it
   is required, I will not skip it - I will leave the lane parked and say so.

3. **Staging 500 remains open.** I narrowed it to a reproducible probe: the built page module exports
   `default: undefined` where it must export a function. Two unconfirmed leads - `current` is a symlink
   to a July release, and the baked build root contains a space.
   **I have not swapped versions chasing it.**

## State

```
certificate   FIXED, Jan 2027, webroot so it self-renews
deps          wouter 3.7.1, react-helmet-async 3.0.0, streamdown 1.2.0 - pinned, per lockfile
service       stale July server.js replaced with next start
500           narrowed, not closed
bash          restored and verified
```

**Give me the scan path and I run lane 15. Otherwise I leave it parked rather than work around a
security gate.**

## Also still unanswered

- The master task list path you gave me does not exist on either host.
- Two authoritative-home answers conflict. I am using the latest: `kun-agent-workspace`.