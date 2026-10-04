# Compute Distribution Study — HD2 multi-host agent fleet
**Author:** main Crisp-R Pi MCode controller lane
**Date:** 2026-09-28
**Status:** study + reusable prompt. No infrastructure changed by this document.
**Workspace:** `/root/agent-work/firstmate` (symlink → `deightonllm-firstmate`, one tree, two names)

---

## 1. The headline: compute is not the bottleneck

The operator's premise is "we have so much compute". The measurement says
compute is genuinely idle — but **idle compute is not what is limiting output**.
Model quota is.

| Host | CPUs | RAM total | RAM free | Load | Verdict |
|---|---|---|---|---|---|
| **controller** (this box) | 4 | 7 GB | 5 GB | 0.65 | ~16% utilised — mostly idle |
| **brandon-compute** (Hetzner AX42) | 16 | 61 GB | 46 GB | 1.27 | **~8% utilised — 46 GB sitting idle** |
| **hd2stack** = contabo `vmi3238503` | 6 | 11 GB | 8 GB | — | ✅ **ACCESS CONFIRMED 16:30** — `ssh hd2stack` as **root**. Earlier "no access" was WRONG: wrong user, not a missing key. |

Live quota windows at time of writing (`quota-axi`):

| Provider | Remaining | Status |
|---|---|---|
| zai / GLM 5.3 | **0%** | **EXHAUSTED NOW** |
| minimax (M3.1, this lane) | 74% | 5h window, resets 05:00 UTC — **falling as we work** |
| codex | 79% | weekly, `projected_exhaustion` |
| agy / gemini | 94% | healthy but behind the SKILL_DRIFT gate |
| agy / claude_gpt | 100% | healthy but behind the same gate |

**The binding constraint is quota and agent-gate state, not silicon.**
brandon has 4× the controller's CPU and 8× the RAM and is doing almost nothing,
because the work that would fill it is gated on model quota and on the AGY
`SKILL_DRIFT` baseline. Adding more hosts or more lanes does not raise the
ceiling. Fixing quota + the AGY ledger does.

---

## 2. What the firstmate system actually supports

Grounded in the code, not assumed:

- **firstmate is single-host by design.** `grep -rilE "brandon|hetz|hd2stack|100\.(106|71)" bin/`
  returns **zero matches** across all 117 scripts. No lane, scheduler, cap, or
  router in the repo has any concept of a remote host. `fm-always-four.sh`,
  `fm-subagent-cap.sh`, `fm-coordinate-lease.sh`, `fm-provider-route.sh` are all
  local-scheduler only.
- **The subagent cap is per-host, not fleet-wide.** `herdr-subagent-cap-check`
  counts panes in the *local* herdr instance (cap 6 subagents + 1 coordinator).
  Running N lanes on brandon and M on the controller is *already* permitted by
  the tooling — the cap does not see across hosts. This is a real, usable
  headroom multiplier, and it is unenforced at fleet level.
- **The only existing cross-host channel is file-based.** `sync-brandon-comms.sh`
  is a **one-way pull**: the controller rsyncs brandon's
  `from-brandon-compute/` into a local mirror every 2 minutes via cron. brandon
  writes; the controller observes. There is no push path and no return channel.
- **Folder drift is real and affects the channel.** brandon's firstmate lives at
  `agent-work/firstmate`, but the sync script reads from
  `kun-agent-workspace/BRANDON-COMPUTE-COMMS/`. brandon's
  `agent-work/deightonllm-firstmate` has an **empty `bin/`** — a broken
  leftover. brandon has 10+ herdr panes but **0 active fm lanes**.

---

## 3. Recommended distribution model

**Controller = brain. brandon = muscle. hd2stack = blocked.**

1. **Controller stays the coordinator.** 4 CPUs is enough for orchestration,
   reviewing, and dispatch. Do not run heavy work here.
2. **Push execution to brandon.** 16 idle cores and 46 GB free is the fleet's
   real capacity. brandon already has a working herdr stack (`w2:p15` primary,
   hd2admin) — it can run its own firstmate lanes without the controller.
3. **Work crosses hosts as files, not prompts.** The existing
   `BRANDON-COMPUTE-COMMS` queue is the right primitive and already has a cron
   sync. What it lacks is a **return path** and an **eligibility gate**.
4. **Close the AGY `SKILL_DRIFT` gate.** This is the highest-leverage single
   action: it unblocks 94% and 100% quota windows that are currently unusable.
   It is operator-run (`agent-intent-guard authorize --agent agy/... --ttl 900`).
5. **hd2stack IS reachable** — `ssh hd2stack` as root, hostname `vmi3238503`, i.e. the
   Contabo box. An earlier note claiming it needs a key provisioned was wrong: the probe used the
   wrong username. It remains "read-only client prod", so reachability is not authorisation to mutate.

### Suggested split

| Work type | Host | Why |
|---|---|---|
| Orchestration, review, dispatch, quota | controller | low CPU, needs the board + panes |
| Test runs, builds, crawls, bulk lint | brandon | 16 cores idle |
| Anything touching live client services | neither, without operator GO | write boundary |

---

## 4. Blockers, in the order they cost us output

1. ~~hd2stack unreachable~~ — **RESOLVED 2026-09-28**: reachable as `root` via the `hd2stack`
   alias. The earlier failure was a wrong-username probe, not a missing key. Still read-only scope.
2. **AGY `SKILL_DRIFT` baseline mismatch** — blocks the 94%/100% quota windows.
   Operator-run fix; recipe in `warehouse/reports/HARNESS_FIX_20260927.md` §4.
3. **zai/GLM at 0%** — do not schedule anything to GLM until the weekly reset
   (2026-10-01). Exhausted *now*.
4. **No cross-host return channel** — brandon can send, controller cannot push
   work back. One-way only.
5. **`env:MINIMAX_API_KEY` rejected** — the `pi:minimax` path works, so this is
   not blocking, but it is a latent failure for anything not running inside pi.

---

## 5. Reusable prompt

Copy this verbatim to start a compute-distribution study or an implementation run.

---

**ROLE:** Compute distribution coordinator for the HD2 agent fleet.
**HOSTS:** controller (4c/7GB, coordinator) · brandon-compute Hetzner AX42 (16c/61GB, execution) · hd2stack 100.71.95.76 = contabo vmi3238503 (6c/11GB, **SSH confirmed as root**). Fleet = 26 CPUs. Use `ssh <alias>` from /root/.ssh/config — never `ssh user@ip`.
**WORKSPACE:** `/root/agent-work/firstmate` (one tree; also reachable as `deightonllm-firstmate`)
**WRITE_BOUNDARY:** controller-local coordination metadata only. No production, SaaS, DNS, database, Docker, credential, or client-code mutation. No cross-host writes without explicit operator authorization.
**MODEL LANE:** never route GLM/Z.AI while `quota-axi` reports zai at 0%. Never switch models silently. Do not spend money under any circumstance.
**ALWAYS:** run `lean-ctx` for every read, search, listing, and shell command under `/root`. The `pi-lean-ctx` hook is NOT installed — enforcement is manual and must not be assumed.
**STOP CONDITIONS:** stop and report on quota exhaustion, credential failure, missing authority, skill-drift gate, or any proposed cross-host write.

**TASK SEQUENCE:**
1. Measure before claiming. `nproc`, `free -g`, `/proc/loadavg` on every reachable host. Never state capacity from memory.
2. Establish the real ceiling with `quota-axi` (now on PATH at `/usr/local/bin/quota-axi`). Report quota, not CPU, as the binding constraint if they diverge.
3. Confirm the per-host scope of firstmate: verify that lane scheduling and the subagent cap are local-only, and treat fleet-wide capacity as unenforced.
4. Identify which work is CPU-bound (should run on brandon) vs coordination-bound (stays on controller). Give a concrete split with reasons.
5. Do not invent work. If the queue is empty, report `NO_ELIGIBLE_WORK` rather than manufacturing a task.
6. Every proposed cross-host action must be listed as a *proposal* with its exact command and blast radius, and must await operator authorization before execution.

**DELIVERABLE:** a short report — measured capacity table, the real binding constraint, the recommended controller/brandon split, and an explicit list of every blocker with the exact operator action that clears it.

---

## 6. Evidence

All numbers in this document were measured live on 2026-09-28 from the controller
and from `hd2admin@brandon-compute` over SSH. Nothing here is carried over from a
prior session's notes. Reproduce with:

```bash
quota-axi                                    # quota windows
nproc && free -g && cat /proc/loadavg        # local capacity
ssh hd2admin@100.106.6.22 'nproc; free -g; cat /proc/loadavg'   # brandon
```
