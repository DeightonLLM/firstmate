# LIVE BOARD — who is working

**Last update: 2026-10-17 — board reset to a true live view.**

This board shows only work in progress or blocked. Finished work leaves this file and lands in
history, the backlog, or the owning artifact. A lane marked DONE below has been reaped and its
records archived; a lane whose line cannot be reaped has its record reaped anyway, so this file
is never evidence of live work.

## LIVE NOW
- [m3.1 @ brandon] Firstmate / coordinator — working
- [unknown @ dubz] Crisp-R / HD2 controller session — not ours, protected

## OPEN, BLOCKED ON A NAMED OWNER
- [hd2 @ hd2stack] Repoint client staging chat off the HD2 endpoint — HD2 owns it. Root cause proven:
  the shipped widget carries baseApiUrl=https://llm.hd2.ai and that stream-chat route returns 404.
  Client sites must reach their own instance via their own hostname. Ticket m27.5.
- [hd2 @ hd2stack] `[key=chat-history-scroll]` — closes only once that endpoint answers a real
  message. Not spend-gated. Ticket m27.5.
- [hd2 @ hd2stack] Stash ruling — stash@{0} is an older 286-line AGENTS.md that would delete 626
  lines of the live instruction contract; stash@{1} is test-first work on fm/afk-return-dir-fix
  whose lib file was already committed today. Both intact, awaiting HD2's word.

## CLOSED THIS SESSION (history, not live)
- Lane naming enforced at spawn with grandfathered recovery; validator rejects unknown model or
  surface segments and enforces registry uniqueness of run ids. Commits 983dfee8.
- Client-infra isolation check: HD2 AnythingLLM must never serve a client endpoint, policy declared
  in docs/policy so a service move is a deliberate edit. Commit 6af1d70d. Runs PASS live.
- Reaping is automatic: teardown archives a task's state records to a dated private archive before
  removal. Dead-pane sweep classifies every pane LIVE / IDLE-BUT-HELD / DEAD-REAPABLE /
  UNKNOWN-PROVENANCE and alarms only on the third. Commit 2c071093.
- Stale skill-collision root cause removed: a `SKILL.md` inside `.agents/skills/quota-axi.bak-20261006/`
  was making a backup directory a live skill. Count is now 0.
- Widget: mobile Ask Questions key CLOSED on handler-binding evidence; panel sizing confirmed correct
  at both viewports; earlier "0x0" was the widget's own lazy-show class, not a regression.
- Port 8081 confirmed as an ACTIVE dependency of the client AnythingLLM via
  GENERIC_OPEN_AI_BASE_PATH=host.docker.internal:8081 — protected from being stopped or rebound.
- Tree landed and pushed: origin/main == local main at 2dcdded8, fast-forward, no rewrite.
  Tangle resolved; primary back on main.

## ROUTING IN FORCE
- Worker lanes: minimax/MiniMax-M2.7-highspeed. Firstmate: MiniMax-M3.1-Flash-Preview.
- M2.7 family shelf life: unavailable to new users 2026-10-19, fully retired 2026-11-18.
  Re-measure quota at intake; rotate on measured exhaustion.