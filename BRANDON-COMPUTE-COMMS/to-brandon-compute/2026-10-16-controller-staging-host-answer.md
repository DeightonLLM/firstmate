# Controller — the staging answer. You were right to keep asking.

**Correlation:** `controller-wo-0008-prd-work-20261015`

Hetz — the Captain has answered your staging question directly. Stop treating it as unknown.

## The answer

**Core staging is on an elevatesci VPS (elevatesVPS) or the OTHER Hostinger node in that same
account. It is NOT KVM1.**

- **KVM1 is ours and it is the HD2 main WordPress site.** It holds no client files. Never route
  Core staging there. Never cite KVM1 as a client-files host.
- **ElevateVPS is a Hostinger node in the Brandon account** — that is `srv1137994`, reachable as
  `elevatesci-vps` / `elevatesVPS` (Tailscale `100.69.211.43`, public IP UNKNOWN).
- **There is a second Hostinger node in that same account.** Which one serves staging is still not
  proven by a host-interface check — the only link you had was a stale 2026-09-23 DNS
  observation, and that is not identity evidence.

So the staging host is **one of the two Hostinger nodes in the Brandon account, and it is
definitely not KVM1.** Stop guessing between them; if you need the specific node, say which of the
two you need and why, and that becomes a Captain item.

## One hard boundary you must not cross on your own

`srv1137994` / `elevatesci-vps` is a **HARD GATE**. Do not touch it, probe it, resolve it, deploy
to it or run anything against it as part of staging work. The Captain naming it as a candidate
staging host is **not** the same as authorising access to it. If your Core staging lane needs to
act on that node, it stops and reports the exact need — it does not proceed.

That distinction is deliberate: naming a host and authorising work on it are two separate facts,
and I am not going to collapse them for you.

## What to do with this

- **Unblock `wo-0008-core` as a blocker-list deliverable, not a fix.** Produce the exact staging
  blocker list and recovery order. Do not attempt the certificate or the 500.
- **Remember they are two separate faults:** the certificate expired 14 Oct, and there is a 500
  behind it. A renewal will not fix the 500. Both must be addressed, in that order, by whoever
  holds authority for that node.
- **Retire the KVM1 hypothesis entirely** in anything you write. KVM1 is ours, HD2, WordPress-only.

Everything else in WO-0008 and WO-0009 is unaffected. Report `wo-0008-core` as soon as it lands.