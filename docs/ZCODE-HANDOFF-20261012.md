# ZCODE HANDOFF — firstmate fleet, 2026-10-12 07:07 UK

You are ZCode (codex/gpt-6-luna family), taking over from the MiniMax M3.1 session
whose quota is nearly spent. **Everything you need is in the repo**, on `main`, at
parity `0 0` on all three hosts. This file is your entry point; two deeper docs are
named below and you should read both.

**The repo:** `/root/agent-work/deightonllm-firstmate` (Controller, root@100.117.47.27)
Synced and at `4332670` on: Controller, HD2 (`root@100.71.95.76`), Brandon
(`hd2admin@100.106.6.22`, path `/home/hd2admin/agent-work/deightonllm-firstmate`).

---

## Read these, in order

1. `docs/HANDOFF-20261012.md` — the full handoff: what landed, how each was verified,
   what is deliberately NOT done and why.
2. `docs/FLEET-STATUS-20261012.md` — the detailed status: every defect found tonight,
   its fix, and its proof.
3. `docs/scripts.md` — **before building anything.** It indexes every script and its
   owner. Building beside an existing owner has been the defining failure of this
   session; do not repeat it.
4. `data/captain.md` (gitignored, per-host) — the Captain's standing rulings. Read the
   whole file; the newest sections are at the bottom.

---

## The state in one table

| Commit | What | Proof |
|---|---|---|
| `40a4b87` | execution authority on every launch brief | fresh crew worktree |
| `3b0da8b` | enforced reap gate (session-start + per-wake) | — |
| `1ad17ff` | lane ceiling resolves from `config/dispatch-max-lanes` (env → config → 4) | PASS=52 + PASS=4, RED proved |
| `d80900d` | **reap gate no longer reaps a crew whose idleness cannot be proven** | PASS=17 FAIL=0 on the Controller; live: 4 crews refused `endpoint is alive` |
| `00c83d2` | handoff doc | — |
| `2583d79` | **`minimax-code` dispatchable** | PROVEN LIVE on Brandon: pane ran `M3.1-Flash-Preview`, routing smoke test PASSED |
| `b8f793f` | `elevatesci.com` is canonical (Captain ruling) | PRD corrected |
| `bdee791` | core-distro coordinates verified + `fm-coord-drift-check.sh` enforcement | 4/4 tests, incl. unresolvable-host → fail |
| `4332670` | brandon-compute hardware live-verified; rate-limit ceiling documented | raw load/cores only — a CPU % is NOT derivable from load average |

---

## The five things that will bite you if you skip this section

1. **The reap gate used to destroy live crews.** `d80900d` is the fix. It is landed on
   all hosts. If you see a reaped task with no status file, that was the old defect.
   Never re-introduce "no status file = not working".
2. **`minimax-code` was undispatchable** because `fm-harness.sh` registered it but
   `fm-spawn.sh` had no launch template. Fixed in `2583d79`. **Brandon's dispatch
   profile now defaults to `minimax-code`/`MiniMax-M3.1-Flash-Preview` — Brandon's own
   quota.** Do not route Brandon client work to Gemini; its per-minute rate limits are
   the fastest-emptying window observed (664 HTTP 429s in one 8-agent fan-out).
   Gemini is hard-reasoning-only now.
3. **Hetz's lane ceiling is a RATE-LIMIT cap, not a compute cap.** It is 7, set in
   Brandon's `config/dispatch-max-lanes`, enforced by `fm_dispatch_guard_lane_cap`.
   Raising it on compute reasoning buys retries, not throughput. 16 cores / 44 GiB free
   is not the constraint.
4. **`mcode` on Brandon needed `permissionMode: bypassPermissions`** in
   `~/.minimax/config.yaml` — without it, an unattended crew deadlocks on its first
   approval prompt and the pane looks idle. If Brandon crews "stop", check for a
   pending approval prompt first. Backup at `config.yaml.bak-20261012-perm`.
5. **Region-hopping to Singapore is a dead end.** MiniMax has exactly two regions:
   `cn` and `global`. Singapore routes to Global. API rate limits are **identical**
   across both regions; only China *subscription* pricing is cheaper (~68–70%, a
   purchasing decision, not a capacity one). Hop on the **quota-window** axis (5h
   rolling, 7d weekly) — that is where capacity actually lives. Evidence:
   `data/minimax-regional-pricing-20261012/report.md` on Brandon (full report).

---

## Open work, in priority order

1. **Quota-fallback routing** — attempted twice, lost twice (once to the reap-gate bug,
   once to the Gemini quota wall). Extend `bin/fm-dispatch-guard.sh` Rule 4 from
   *refuse* to *fallback*: Gemini first for Hetz hard work, MiniMax M2.7 light-only,
   cross-host quota only once a model is genuinely empty. **Never weaken a threshold;
   never add a bypass.** Full brief survived at
   `data/quota-fallback-routing-20261012/brief.md` on HD2.
2. **Land the three completed Brandon client jobs** — `cbd-local-source-config-audit`,
   `elevatesci-canonical`, `core-distro-coordinates-doc`. All three crews returned
   `done`. The CBD audit report lives in gitignored `data/` on Brandon, so it will not
   propagate — decide whether `data/domain-warehouses-20260915/` should be tracked.
3. **Calm for spawned crews** — diagnosed, not fixed. Your/Controller pi gets calm
   because cwd contains `.pi/extensions/`; spawned crews' cwd does not. Brief at
   `data/calm-reaches-fresh-agents-20261012/brief.md` on HD2, **with a HARD CONSTRAINT:
   never touch the Captain's own interactive pi, `~/.pi`, `.bashrc`, or
   `kun-agent-workspace/**`.** Change only the spawned-crew dispatch path.
4. **`spawn-liveness-verification` — DO NOT LAND AS-IS.** All three review concerns
   were UNSAFE: ambient `FM_TEST_AGENT_STATE_OVERRIDE` can flip the live dispatch
   verdict (no log, no whitelist); 10s default timeout gives false negatives on real
   boots; `exit 1` leaks the pane and worktree. Fix all three first.
5. **`plan-page-harden`** — done, correct RED evidence, `10 pass / 0 fail`. Needs
   review and landing.
6. **`stale-worktree-guard`** — modifies `fm-spawn.sh` AND `fm-dispatch-guard.sh`.
   Riskiest unlanded work in the fleet. Review last, most carefully.
7. **Extend `docs/PROVIDER-ROUTING.md`** for automated lock-carrying handoffs on the
   quota-window axis. It already owns a safe-handoff observer and AFK integration —
   extend, never duplicate.
8. **HD2 watcher** was stale at handoff — rearm (`bin/fm-watch.sh` with `FM_HOME` set).

---

## Blocked / deliberate non-goals

| Item | Why |
|---|---|
| whooshperformance.com | No repo/host/runtime/IP exists anywhere. Captain supplies coordinates. |
| elevatesci host/runtime ownership | Spelling is closed (canonical: elevatesci.com); ownership is not. |
| music-metrics.com SaaS | Captain deferred: "for another day". |
| core-distro architecture | ADR-first, per Captain order. Facts recorded; conflict NOT resolved. |
| cbd-data migration | Intent authorised (to PRD's Hostinger/Hetzner target). **Execution is NOT** — a live migration needs a written plan and rollback, and separate explicit authorisation at the moment of execution. |
| Brandon scout teardown | Refused by the unresolved-decision gate — correct. Inventory via `bin/fm-decision-hold.sh` first. Do not force. |

---

## The session lock — read before your first action

- Run `bin/fm-session-start.sh` FIRST. It acquires the per-home session lock.
- The lock is currently held by the outgoing MiniMax session (pid-bound). The Captain said he will hand you the lock **when ready** — that means he closes the old session, not that you take it.
- If the lock is **refused: remain read-only**. No spawning, steering, merging, wake-draining, supervision repair, checkout repair, or any fleet mutation. Report the exact diagnostic and wait.
- Read-only time is not dead time: read the entry-point docs, run `quota-axi`, verify host state, plan. Those are all allowed.
- **Never break, delete, force, or work around the lock.** It is the fleet's single-writer guarantee. Two writers on one home is how work gets destroyed.

## Rules of the house

- **TDD:** failing test first, shown RED, against a **fresh worktree** — not the primary
  checkout. A test that never went red proves nothing.
- **Verify on the landing surface** (the Controller), not only on the crew's host.
- **Scope every review** to an explicit file list, and **write the verdict before
  exploring.** Three unscoped reviewers burned 400k–1.5M tokens and returned nothing;
  a scoped one returned a real verdict for $0.009.
- **Never production-write without explicit Captain authorisation.** Never bypass a
  production-write gate. Never disable the secret scanner to make a tool boot.
- **Never `--force` teardown. Never discard unlanded work.**
- **Report crews by tab label**, never raw pane ids. Model leads on the left:
  `GLM REVIEW · HD2 · fm-<task-id>`, `agy GEMINI · BRANDON · fm-<task-id>`,
  `minimax M3.1 · BRANDON · fm-<task-id>`. Herdr's `agent` field cannot be renamed; the
  model rides in the tab label, applied **at spawn**.
- **One job in flight through review→land at a time.** Relay each agent's result
  individually as it lands — the Captain reads them as they come.
- **Per-host quota is absolute.** Never dispatch one host's work against another host's
  account.
- **Never use `gpt-6.1-sol` for spawned workers.** `~/.codex/config.toml` defaults to
  it; always pin `--model`.
- Reviewers must be a **different model family** from the worker.
- Check `quota-axi --json` at every intake, before resolving any dispatch profile.

---

## Quick commands

```bash
# Fleet quota
quota-axi --json

# Rearm a host watcher (FM_HOME first!)
cd <host-repo> && export FM_HOME=<host-repo> && nohup bin/fm-watch.sh >/tmp/fm-watch.log 2>&1 &

# Reap sweep (safe: refuses anything unproven)
FM_HOME=<host-repo> bin/fm-reap-gate.sh --sweep

# Label a crew tab at spawn (herdr agent field cannot be renamed)
herdr tab rename <tab_id> "<MODEL> · <HOST> · fm-<task-id>"

# Spawn on Brandon's own quota (the default profile resolves this)
bin/fm-spawn.sh <task-id> <repo> --harness minimax-code --model minimax/MiniMax-M3.1-Flash-Preview --backend herdr
```

---

*Handover complete. The Captain is asleep; keep working end to end, do not stop, and
relay each result as it lands.*
