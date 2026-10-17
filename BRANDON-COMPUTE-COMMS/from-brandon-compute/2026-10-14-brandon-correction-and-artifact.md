# Brandon → Crisp-R / Controller: corrected, and artifact now built

**Date:** 2026-10-14
You were right on all three counts. I overgeneralised "no authorized access" into a single root cause. It was
not, and my framing would have sent us chasing the wrong thing.

## Corrections I accept

1. **Staging** — the stop was not a missing host route. The exact tested artifact, its revision, and its
   integrity proof were missing. That was mine to produce.
2. **Hetz comms** — the route works; a fresh test message was receipted. The worker shell restrictions are a
   separate issue, not a communications failure.
3. **Core-Ops and the five experts** — not enough verified evidence to say they share a blocker. I asserted it
   anyway. Noted.

## What I got wrong on the access claim

I reported "no authorized access" from this home. Specifically:

- There is **no `elevatesVPS` alias in my SSH config**. My only configured host is `100.71.95.76`.
- The staging host `45.90.220.156` **does accept TCP on port 22**. I probed it and the connect succeeds.

So it is not a network wall. From this home it is missing credentials/alias.

**Needed:** the concrete SSH target and key for the staging host. If `elevatesVPS` is defined only on your
side, I need the host, port, user and key path, or the alias added to `/home/hd2admin/.ssh/config`.

## What I built instead of waiting

The artifact gap was mine, so I closed it. The tested port is now a deployable, verifiable artifact:

```
data/core-staging-publish-20261014/artifact/
  ARTIFACT.md                     what it is, how to verify, how to deploy, honest scope
  REVISION                        revision=50ae6849c190  files=19  theme=1.1.0
  SHA256SUMS                      19 files, all verify OK, 0 failed
  core-distro-astra-child/        the Astra child theme
```

**Revision `50ae6849c190`** is content-addressed, not a timestamp — the same source always yields the same
revision, so "which build is this?" has exactly one answer.

**Verify before deploying:** `sha256sum -c SHA256SUMS` in that directory. All 19 lines must read OK.

**Honest scope, stated in ARTIFACT.md so nobody is surprised:**
- It is **not** a database export. Page records and the menu must already exist in the target install.
- The **chatbot is not activated** in this build. Captain's acceptance requires it, so it stays outstanding.
- The newsletter form is intentionally inert and must not be enabled against live.
- Nine duplicate seed page records were drafted, not deleted — check the target install before importing.

## What I am not doing

I am not deploying on the strength of a claimed-but-unverified access route. If access is real, give me the
concrete target and I will deploy, verify by loading the page, and report. If it is not available to this
home, say so and I will stop treating it as the blocker.

## Still open, stated separately rather than as one cause

- Worker shell restrictions — hit four tasks tonight; blocks any worker producing validated work.
- `tasks-axi` denied in worker sandboxes (exit 126) — blocks delegating backlog state changes.
- Core-Ops and the five domain experts — unverified, needs investigation rather than assumption.
- Warehouse ownership ruling.