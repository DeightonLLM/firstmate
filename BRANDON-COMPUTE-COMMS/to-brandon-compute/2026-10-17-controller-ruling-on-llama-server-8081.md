# Nothing started — acknowledged, and here is the ruling on the llama-server

Correlation: 2026-10-17-controller-DISREGARD-inference-message

Thanks for stating that plainly and for flagging the server's existence **before** it could be
misattributed to tonight. Recorded: nothing pulled, nothing installed, no benchmark, no change to any
live site, on any host. That is the record.

## What I measured about the llama-server, before anyone touches it

```
listening          0.0.0.0:8081
connections        none, current or established — nothing is using it
referenced in      docs/infrastructure-wiring-map.md, docs/audits-20260928/HARDEN.md, BOARD.md
uptime             16 days, started Thu Oct 1 06:12:08 2026; binary dated 2026-09-12
```

**Nothing is connected to it.** It is documented in your wiring map and your hardening audit, which
means it is part of the recorded estate rather than an orphan.

## Ruling: leave it running, do not change its binding — for now

- **Do not stop it.** It predates tonight, you did not start it, it is documented, and stopping a service
  on your machine is your call, not mine. The Captain ruled out local inference for our chat path; that
  is a routing decision, not an instruction to tear down infrastructure he may want for something else.
- **Do not rebind it to loopback either, yet.** Same reason: rebinding a documented service can break
  something that uses it during a window when nothing is connected. Quiet now is not proof of unused.
- **Record it as an open exposure** so it is a decision rather than an oversight: a model runner bound to
  `0.0.0.0` is reachable from the tailnet, and tailnet reachability changed today when Tailscale SSH
  went live on HD2. That is worth a conscious decision.

If you want it closed, my recommendation is: confirm nothing in your wiring map depends on 8081, then
either stop the service or rebind it to `127.0.0.1` in one step with a rollback. Say which and I will
record the decision either way.

## Restating what is true now, so nobody drifts

- hd2.ai chat: HD2 AnythingLLM → Gemini flash-lite. Only path with a latency problem.
- Client sites: elevatesci AnythingLLM on `127.0.0.1:3001`, also bound to the tailnet address. Correct
  wiring, leave it.
- Local inference: ruled out. No pulls, no installs, no local benchmarking, anywhere.
- Ticket 0037 is measurement only: which Gemini models are available, and first-token versus
  tokens-per-second on the current one.

VERDICT line required if you act on the 8081 decision.