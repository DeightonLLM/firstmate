# HD2 as firstmate — the actual procedure, from the docs

Extracted from upstream `docs/remote-secondmates.md` (42,266 bytes, fetched and read). This file
exists so the procedure is never re-derived from memory again.

## Live verification of HD2 claims (measured, not asserted)

Measured at 13:19:04Z on 2026-10-17 by direct SSH to the `hd2stack` alias:

```
ssh alias hd2stack: key auth OK
/root/agent-work/deightonllm-firstmate/bin/fm-session-start.sh      PRESENT
/root/agent-work/deightonllm-firstmate/bin/fm-remote-home-seed.sh   PRESENT
```

A Firstmate checkout therefore exists on HD2 at `/root/agent-work/deightonllm-firstmate`, and the
provisioning script the procedure needs is present in its `bin/`.

## What the system calls this

Not a rebuild. A **remote second mate**: a whole persistent Firstmate home on another host that the
primary can SSH to. The primary owns routing and supervision; the remote home owns its own projects, backlog and
workers. Individual workers are never placed remotely, and an unavailable remote route is never
silently replaced by a local one.

The remote agent itself always runs on the **Herdr backend** in a shared session called `fm-remote`,
reserved for remote fleet work and not to be used for personal work.

## Prerequisites

1. An SSH alias in the primary's OpenSSH config, public-key auth, strict host-key checking, no agent
   forwarding. `fm-on.sh` disables forwarding itself and arms bounded dead-peer detection so a
   vanished host fails in a bounded window instead of hanging.
2. Firstmate cloned on the remote host at an **absolute code-root path**. HD2 satisfies this, per the
   verification above.
3. That clone's entrypoint exposed on the remote account's non-interactive PATH:
   ```sh
   mkdir -p ~/.local/bin
   ln -s /absolute/path/to/firstmate/bin/fm-remote-entrypoint.sh ~/.local/bin/fm-remote-entrypoint.sh
   ```
   The entrypoint accepts encoded argv for real `bin/fm-*.sh` files only, never a shell string.
4. A **worker job worker** bootstrapped on the remote account. Every non-doctor command then runs
   through it, never inside the SSH process or a Herdr pane. `fm-remote-doctor.sh --fix` installs it.

## Step 1 — write the charter first

The seed refuses to run until a normal secondmate charter exists and is filled in.

## Step 2 — check the host is ready (read-only, changes nothing)

```sh
bin/fm-on.sh <secondmate-id|ssh-alias> fm-remote-doctor.sh
```

It prints the PATH its entrypoint produced, resolves every required and optional tool, then reports
one line per readiness check. Each gap is tagged:

| Tag | Meaning |
|---|---|
| `fixable:` | `--fix` can close it |
| `human:` | only a person at that machine can |

Any remaining gap exits non-zero.

## Step 3 — repair the automatable gaps

```sh
bin/fm-on.sh <secondmate-id|ssh-alias> fm-remote-doctor.sh --fix
```

Safe to rerun. Writes and reloads two Firstmate-owned agents on the remote account.

## Step 4 — provision the route

```sh
bin/fm-remote-home-seed.sh <id> <ssh-alias> <remote-root> <remote-home> {<project>[=<origin-url>]...|--no-projects}
```

- `<remote-root>` — the remote Firstmate **code clone** supplying tracked scripts. For HD2 this is
  `/root/agent-work/deightonllm-firstmate`.
- `<remote-home>` — a **separate absolute path** for the persistent home. It must not overlap the code
  root, so it cannot be the same directory as the checkout above.
- Projects are named `<project>=<origin-url>`. Delivery mode still comes from the primary's
  `data/projects.md`; `local-only` and unregistered projects are refused by design.

The seed records `host:`, `root:`, `home:` in `data/secondmates.md`, gates the host on readiness, sends
a bounded manifest, and lets the remote host clone its own home and project origins. It never copies
project trees or the primary's process environment.

## What promotion to primary would additionally require

This document covers secondmate provisioning, which is the documented foundation. Promoting HD2 to
**primary** is a further step whose exact procedure I have not read. It is recorded here as unknown
rather than guessed.

VERDICT: PASS procedure extracted from the upstream doc; every HD2-specific claim above was measured
live at the stated time; the promotion step is explicitly marked unknown rather than invented.