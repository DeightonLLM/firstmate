# The Dubz handoff channel

**What this is.** A real message channel between the fleet and the Captain. The Captain is the
only human interface to the external team (the P.K. team), so the fleet needs a place to hand
him finished messages, a way to know what he has already forwarded, and an audit trail.

It replaces the ad-hoc folder `agent-work/elevate- WP-PK-Migration status` on the Controller,
which had no naming rule, no state, no atomicity and no way to tell a forwarded message from a
pending one.

**Canonical location.** `/root/dubz-handoff` on the dubz Controller (`vmi3196300`,
`vmi3196300-dubzai-deightonllm.tailddbb4d.ts.net`). The source of truth for the tooling is
`bin/dubz-handoff.sh` in this repository; the deployed copy is that file.

## The layout

| Path | Meaning |
|---|---|
| `inbox/` | Waiting on the Captain. Read it, forward it, then `send` it. |
| `outbox/` | Waiting on the fleet. A lane picks it up, then `consume` it. |
| `sent/` | The Captain has forwarded it onward. Archive, never edited. |
| `consumed/` | The fleet has acted on it. Archive, never edited. |
| `legacy/` | The retired quick folder and anything that predates the kit. History, read-only. |
| `templates/` | Reusable message skeletons. |
| `index.tsv` | A cache of message state. Rebuildable with `index`; never authoritative. |
| `log/actions.log` | Append-only record of every post, send and consume. |

## The rules

1. **One writer per file.** A message body is immutable once written. A correction is a new
   message that carries `reply-to:` pointing at the old one.
2. **Atomic writes.** Every file is written to a `.part` name and renamed into place, so a
   reader never sees half a message and a crash never leaves a corrupt one.
3. **Never prompt.** Every command takes flags only, so the same command works from a script,
   from a lane, or from a cron job.
4. **Never delete.** `send` and `consume` move a message into an archive folder.
5. **No secrets in a message.** A message body may name a credential *path* and a *key name*.
   It may never carry a credential value, and it is never a place to move one.
6. **The index is a cache.** If it is wrong, `index` rebuilds it and `doctor` says so.

## The commands

```bash
/root/dubz-handoff/bin/dubz-handoff post \
  --dir inbox --title "Short subject" --to "the P.K. team (via the Captain)" \
  --from "HD2 firstmate (HD2Stack vmi3238503)" --body-file /path/to/body.md

/root/dubz-handoff/bin/dubz-handoff list --dir inbox
/root/dubz-handoff/bin/dubz-handoff read <id>
/root/dubz-handoff/bin/dubz-handoff send <id>        # Captain forwarded it onward
/root/dubz-handoff/bin/dubz-handoff consume <id>     # the fleet acted on it
/root/dubz-handoff/bin/dubz-handoff index            # rebuild the cache
/root/dubz-handoff/bin/dubz-handoff doctor           # layout, perms, drift, stale messages
```

`post` prints the new message id and its path. The body file is read verbatim; the header
block is generated, including a SHA-256 of the body so a later reader can tell whether a
message was altered after the fact.

## Posting from another surface

Write the body to a file, copy it across, then run `post` on the Controller. Never write a
message with a nested heredoc over SSH: a truncated pipe leaves a half message.

```bash
scp body.md root@vmi3196300-dubzai-deightonllm.tailddbb4d.ts.net:/tmp/dubz-body.md
ssh root@vmi3196300-dubzai-deightonllm.tailddbb4d.ts.net \
  /root/dubz-handoff/bin/dubz-handoff post --dir inbox --title "..." --to "..." \
  --from "..." --body-file /tmp/dubz-body.md
```

The remote `post` writes to `.part` and renames, so the message is either absent or complete.

## Checks

`doctor` is the health check. It exits non-zero when a directory is missing, a staged `.part`
leftover exists, an indexed message has no file, or a message has been waiting more than
48 hours. Run it after any migration, and before trusting `list`.
