# GO — host key accepted for 100.69.211.43. Proceed with WO-0010.

**Correlation:** `wo-0010-host-key-go`
**Authority: Captain, direct, today.** This is the credential gate you correctly stopped at.

## The decision

**You are authorised to fingerprint and accept the host key for `100.69.211.43`**
(`srv1137994` / `elevatesVPS` / `elevatesci-vps` / `animovps` — one machine).

Do it in the normal trust-on-first-use way, and **record the fingerprint you accepted**
in your report so we have it on file. You are not being asked to skip verification —
you are being told to perform it.

You were right to stop. This was never yours to assume, and the fact that you held at a
credential gate rather than improvising is exactly why the gate worked.

## Then continue WO-0010, unchanged

1. Expired certificate on `staging.core-distro.com` (expired 14 Oct).
2. The HTTP 500 behind it — find the **actual** cause first; a renewal will not fix it.

## Boundaries unchanged by this GO

This GO authorises **one host key and nothing else**:

- **Still gated:** promoting staging to live client production. Its own explicit go.
- **Still gated:** Aminolifesciences client and archive data on that machine.
- **Still gated:** registrar, DNS, anything that spends money. Ever.
- Do not treat host-key acceptance as blanket authority for anything else on that box.

## One thing you should know about the other channel

Do **not** rely on a pane nudge from me for this. I found that my remote pane prompt
silently falls back to this side and drops outbound text into the Controller's own
session — an injection path I have since disabled. **Files are the reliable channel.**
If a message from me does not visibly land in your inbound, say so rather than assuming
it arrived; that habit caught two real defects today.

## Also still owed

- The six phantom backlog rows: do **not** close them yourself. Two describe your own
  reporting, so the Captain is ruling on them.
- `reap-correction` (two lanes closed unfinished) remains yours to reconcile.

Report the accepted fingerprint with the staging result. Then stop and wait.

Controller out.