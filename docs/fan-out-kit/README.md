# Fan-out kit — bring a surface up as a working lane host

Everything here is copy-and-run. It exists so that the next surface does not have to rediscover
what the Hetz cycle measured on 2026-10-23.

**Read `docs/FLEET-SOP-2026-10-23.md` first.** This kit is the practical half of it.

| File | What it is |
|---|---|
| `new-surface-checklist.md` | the ordered steps, with the measurement that closes each one |
| `launcher-template.sh` | a scheduler launcher with four variables to fill in |
| `lane-brief-template.md` | the brief contract that actually gets work out of an agent |
| `traps.md` | every failure measured this cycle: how it presents, how to detect it, the fix |
| `verify-fleet.sh` | read-only census of a surface: lanes, workers, daemons, quota |

## The four variables

Every surface answers these before it can run a lane:

1. **harness** — `minimax-code`, `codex`, `pi`, `claude`, `grok`, `kimi`, `opencode` (the
   always-four scheduler refuses `pi` and `agy` by policy).
2. **model** — the exact id the **service** serves, verified with a distinctive-token reply, not
   with a catalog line. Some services reject the provider-qualified form of their own id.
3. **account ceiling** — the per-provider ceiling binds the **credential account**, not the host.
4. **the half's own roots** — `FM_DATA_OVERRIDE` and `FM_STATE_OVERRIDE` for anything that is not
   the surface's first half.

## The shape of the bring-up

```
copy the launcher  ->  fill four variables  ->  dry-run one cycle  ->  real cycle
      ->  prove the workers are WORKING (not merely alive)  ->  census  ->  close the loop
```

The dry run matters: it shows which rows the scheduler would pick, and it will show a
duplicate-row defect immediately (every lane printing the same task is the bug, not a coincidence).

## Rules that travel with the kit

- Configuration lives in the **launcher**, in ENV. Never in the scheduler source.
- The daemon is started through `bin/fm-afk-launch.sh` — a tracked, non-visible terminal. Never
  `nohup`, `&` or `disown`.
- Every mutation gets a `.bak-<tag>-<date>` backup, named in the artifact.
- A lane is not done until its artifact exists with a `VERDICT:` last line.
- Prove the route with a **token reply**. CLI acceptance is not service.
