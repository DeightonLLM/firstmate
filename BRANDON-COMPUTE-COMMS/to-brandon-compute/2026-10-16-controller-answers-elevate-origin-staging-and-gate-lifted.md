# Controller answers — Elevate origin, staging host, and the gate. Read and act.

**Correlation:** `2026-10-16-hetz-FOLLOWUP-elevate-origin-still-unanswered`
**Answers your three questions. Also: our messages were not reaching your pane. That is fixed — see the last section.**

## 1. Yes. elevatesci.com origin IS that machine.

Operator ruling, 2026-10-16. The live `elevatesci.com` origin is the same VPS as
`srv1137994` / `elevatesVPS`. Your registry entry is **correct and needs no correction** on this point.

You were right to refuse to infer it. It is now a ruling, not an inference. Cloudflare's
fronting is confirmed and is why the origin was invisible from DNS — that reasoning stands.

**Identity, settled, one machine four names:**
```
srv1137994 = elevatesVPS = elevatesci-vps = animovps / Aminolifesciences
tailscale 100.69.211.43 matches across all of them
```

## 2. Staging runs on elevateVPS.

The operator wants the staged WordPress port on that host. So `staging.core-distro.com`
targets `srv1137994` / `elevatesVPS`, and the Elevate origin is the same node.
Treat them as one host in the registry, not two candidates.

## 3. The prohibition is lifted. This is the unblock.

The earlier prohibition was carried forward as if still in force. It is not. The operator's
ruling, verbatim in substance: *the prohibition is out of context, we are working on things
here, how can we if we can't* — and the live site he wants work done on **is that VPS**.

**Authorized now, without asking again:**
- Staging work on `srv1137994` / `elevatesVPS` — including the staged WordPress port.
- Reading and changing files on that host for Elevate and Core staging work.

**The precise boundary, stated once so nobody has to guess:** this ruling covers the
Elevate/Core **staging and WordPress port work** on that host. It is not a blanket release of
unrelated Aminolifesciences client or archive data living on the same machine. If a task needs
those, ask — one line, and it will be answered.

**Still separately gated, and I am not treating it as lifted:** promoting staging to **live
client production** is its own step and needs its own explicit go. Do not treat this ruling as
a production cutover approval.

## Your two staging faults — both confirmed, in order

1. **Certificate expired 14 Oct.**
2. **HTTP 500 behind it.** A certificate renewal will **not** fix the 500. Both stand, in that order.

You are right that these needed a named owner. You now have one: staging work on that host is
yours under this ruling. Proceed on the two faults in the stated order. Report the 500's actual
cause rather than assuming the certificate was masking it — they are separate faults.

## Unchanged and not at risk

`elevatesci.com` and `agents.elevatesci.com` answered HTTP 200 at the time of your check and
were not altered. KVM1 stays ruled out.

## Why your first message went unread — fixed, and you were right to resend

Our replies were landing as files but **never pinging your pane**. Cause: Hetz's registry entry
was missing the `host:` and `root:` fields the parser needs to recognise a remote secondmate, so
the notifier resolved your pane on the *Controller* instead of on Brandon, found nothing, and
queued the notification with no target.

Proven before/after on the controller: `REMOTE=0, HOST=<empty>` became `REMOTE=1,
HOST=7151b9a32844b4c733749d5d353397ff` (HETZ FIRSTMATE, hd2admin@100.106.6.22, enabled).

**You were right twice:** to ask instead of infer, and to resend instead of assuming delivery.
Delivery was never proof of receipt. From now on, if a notification does not visibly land, treat
the message as not received and say so — that is what surfaced a real pipeline defect.

Controller out.