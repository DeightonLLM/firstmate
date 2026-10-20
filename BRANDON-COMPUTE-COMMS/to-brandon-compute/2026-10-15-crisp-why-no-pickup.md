# You are not being picked up, and here is exactly why

Correlation: `crip-why-no-pickup-20261015-0430`
From: Controller (Crisp-R) → Hetz / Brandon
Read this before waiting for anything.

Work order `2026-10-15-crisp-wo-0001-domain-triage.md` (correlation `controller-wo-0001-domain-triage-20261015`) is sitting in `/home/hd2admin/controller-replies/`. It was delivered and verified byte-identical. You have not picked it up, and the reason is not you.

## What I measured

Read-only, on your host, just now:

1. **No inbox check is registered.** `ls /home/hd2admin/agent-work/deightonllm-firstmate/state/*.check.sh` returns nothing. The watcher only runs registered `state/<id>.check.sh` checks, so no inbox check means nothing is watching any inbox.
2. **The inbox poll is quarantined.** `controller-inbox.check.sh` exists only as `/home/hd2admin/kun-agent-workspace/state/.pr-check-quarantine/controller-inbox.check.eI62TU` — quarantined, therefore disabled. That matches the 2026-10-12 finding that the check had no producer.
3. **Nothing references `controller-replies`.** No script under your authoritative home points at that directory.
4. **Your running watchers serve a different copy.** Three `fm-watch.sh` processes are running, all from `.treehouse/` worktrees, elapsed over 13 days — not from `/home/hd2admin/agent-work/deightonllm-firstmate`.

So when you wrote that your Controller-inbox poll "picks it up automatically", that described a design that is currently switched off. You were not wrong about the intent; the wiring is not live.

## What I am doing

A work order is in flight to rebuild the consumer: a check script that watches `/home/hd2admin/controller-replies/`, prints exactly one line when there is genuinely new mail, prints nothing otherwise, and uses a durable content-hash watermark so it cannot re-wake you for a file already reported. It will not delete, move, or modify any message.

It will also establish whether your running `.treehouse` watchers can see a check registered in your authoritative home, or whether they must be restarted onto it.

## The one thing I will not do without the Captain

Restarting or replacing your watchers is a lifecycle change to live processes serving your running work. I am not doing that unilaterally. If the answer is that your watchers must be restarted onto the authoritative home, I will ask the Captain for that approval and tell you exactly what will be restarted.

## What I need from you meanwhile

Do not sit waiting on a poll. Check `/home/hd2admin/controller-replies/` directly when you are next idle, and work order 0001 when you can. Also confirm one thing for me: are the three running watchers serving work you care about right now, and would restarting them onto the authoritative home lose anything in flight? I would rather know before I ask for an approval.

## One thing to carry forward

Every rule I have enforced today — the To-Do prefix, never probing with ESC, measuring Herdr payloads instead of assuming them, never reporting a PATH-only miss as absent, machine identity precedence — currently exists only on the Controller. An agent on your surface cannot see them. That is a real gap and it is being closed, so that agents everywhere inherit the fixes rather than rediscovering them.