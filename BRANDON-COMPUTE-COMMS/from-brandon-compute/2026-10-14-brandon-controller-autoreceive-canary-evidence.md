# Canary evidence — Controller automatic reception, full path proven

**Date:** 2026-10-14
**Surface:** Hetz (`/home/hd2admin/kun-agent-workspace`)
**Check:** `state/controller-inbox.check.sh`, registered and trust-bound

## What was wrong, verified not assumed

Captain directed me to verify the AFK restriction and the actual notification path before blaming anything.
I did, and the AFK restriction was the real cause:

```
check registered:            YES — state/controller-inbox.check-trust existed
bytes matched trust binding: YES — e864f233f4997…
state/.afk at the time:      NO
```

The previous implementation exited silently at `[[ -f "$STATE/.afk" ]] || exit 0`. The watcher sweeps
`state/*.check.sh` every `FM_CHECK_INTERVAL` (default 300s), so the poll ran correctly every sweep and
reported nothing, every sweep, for as long as the Captain was present. **File existence was never the
problem.** The directory mismatch is a real second gap, now also fixed, but it was not today's failure.

## Changes

1. **Automatic receipt no longer depends on away mode.** The `.afk` gate and its mtime filter are gone.
2. **Both documented inbound directories are watched:**
   `/home/hd2admin/controller-replies` and `BRANDON-COMPUTE-COMMS/to-brandon-compute`.
3. **Deduplicated by content hash.** The handled ledger is keyed by sha256 alone, so the same message under
   either path, or renamed, is acknowledged once.
4. **Per-sweep dedup.** A message present in both directories is reported once per sweep, not twice.
5. **Watermark instead of away-entry filter**, so unchanged mail never triggers a repeated model call.
6. **First run discloses rather than hides.** With no watermark the poll seeds to now and prints how many
   pre-existing messages it did *not* surface. On this home that was **183**. They are not lost — they are in
   the two inbox directories and readable on demand — but automatic reception starts from the seeding point.

## Protections preserved

- filename allowlist `^[A-Za-z0-9._-]+\.md$`
- refusal to follow a symlinked inbox, message, or ledger
- message re-hashed at ack time and refused if it changed after being read
- handled ledger written atomically at mode 0600
- every error path exits 0, so a broken poll can never wedge the watcher
- reports filenames and digests only, never message content

## Canary results, full path

| step | result |
|---|---|
| run 1, no watermark | `controller inbox poll seeded: 183 pre-existing message(s) not surfaced; automatic reception starts now` |
| run 2, unchanged | no output, exit 0 |
| canary written to **both** inboxes | identical content, sha256 `b8897575…8de7fa` |
| run 3, pickup | reported **exactly once** despite two copies |
| run 4, unchanged | **0 lines** — no repeated model call for unchanged mail |
| ack, first | `acknowledged: … sha256=b8897575…` |
| ack, repeat | `already-acknowledged: …` — idempotent |
| ack with wrong digest | `refused: Controller message changed after it was read` |
| content tampered after read | `refused: Controller message changed after it was read` |
| symlink to `/etc/passwd` dropped in inbox | skipped silently, contents never read or reported |

**Delivery → automatic pickup → acknowledgement all proven by observed behaviour, not by file existence.**

## Trust binding

```
state/controller-inbox.check-trust   fm-custom-check-v1
                                    b7ff55771b19a56261208ffe1fdb72c06f1321649e6b3327f8aa367b4508beb2
sha256(state/controller-inbox.check.sh)
                                    b7ff55771b19a56261208ffe1fdb72c06f1321649e6b3327f8aa367b4508beb2
```

Re-bound with `bin/fm-check-register.sh controller-inbox` after the edits, so the watcher executes the new
bytes and nothing else.

## Still open

- **183 pre-existing messages were not auto-surfaced.** They predate this fix. Tell me whether you want them
  replayed through the poll, or left readable on demand.
- **The outbound side is still manual.** Receipt now works automatically; sending is still me writing files.
  If you want acknowledgement pushed without a model call, that is a separate change and I have not made it.
- Watcher interval is still 300s, so worst-case pickup latency is ~5 minutes.