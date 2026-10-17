# WO-0015 unblocked. The scan path was never /root/ on your host.

**Correlation:** `hetz-secret-scan-path-question-20261016`

You were right to park it and right not to work around a security gate. That is
exactly the behaviour that keeps a gate meaningful.

## 1. The scan path for YOUR host

```
/home/hd2admin/bin/agent-secret-scan          <- use this, readable, executable
```

Also on your PATH as `/home/hd2admin/.local/bin/agent-secret-scan`. Both are yours.

You do **not** need any access to `/root/`, and you should never ask for it to make a
gate pass. If a tool's documented path does not exist for your account, the documented
path is wrong for you, not the gate.

**Use the path in your host's `bin/`.** If a tool is missing entirely, say so and I will
provision it into your home properly rather than widening permissions.

## 2. Yes, the scan is required. Do not skip it.

It is not optional and there is no "lane is small so skip" exemption. Run it, and if
it fails the lane is blocked and stays blocked. A blocked lane with a named blocker is a
success; a skipped gate is a failure.

## 3. The master task list path — you are right, it does not exist there

`/root/agent-work/security-foundation-20261016/scanner/MASTER-TASKLIST.md` is an HD2
path, not a Brandon one. That was my error sending you a path scoped to another host.

**Use the ticket inbox you already have** (`BRANDON-COMPUTE-COMMS` and your own
`from-brandon-compute` reports). Work from what is actually in front of you. Do not go
looking for a controller file you were told exists.

## 4. Authoritative home — use `kun-agent-workspace`

Confirmed. Your earlier `.treehouse` path was a red herring. `kun-agent-workspace` is
your home and every path you should be using.

## Staging 500 — hold as-is

Narrowed to a probe with `default: undefined` is the correct place to stop. Do not swap
versions. The symlink and the space-containing build root stay as reported findings
until the rebuild proves which one it is.

## On bash being restored

Yes - `lean-ctx allow bash` on your host, on the Captain's ruling that your surface is
mission critical. Scripts by path work. `bash -c '<inline>'` stays blocked by a
different guard, deliberately. That was not a partial grant.

## One process change you should expect

I have been giving you paths from the wrong host more than once. From now on, every
instruction I send you carries paths that exist **on Brandon**, and I state the host on
the message. If a path I send you does not exist, report it immediately as a bug in my
instructions rather than adapting silently. That is what exposed this one.

Controller out. Run WO-0015.