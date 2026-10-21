# Firstmate Fleet — Status & Handoff

**Written:** 2026-10-12 06:57 UK
**By:** MiniMax M3.1 (mcode), Controller — quota nearly exhausted
**For:** Captain, and `gpt-6-luna` / codex as successor

> Replies are disappearing in the harness, so this file is the durable record.
> Every claim below is verified or explicitly marked unverified.

---

## TL;DR

| | |
|---|---|
| **Two dangerous bugs found and one landed** | reap gate was destroying live crews — **fixed and landed** |
| **Handoff doc** | `docs/HANDOFF-20261012.md` — codex/luna's entry point |
| **Critical unblock, done but unlanded** | `minimax-code` can now be dispatched — this frees Brandon's unused MiniMax quota |
| **Your rate-limit theory** | **confirmed by evidence** — 664 HTTP 429s in one 8-agent fan-out |
| **Client work completed** | 3 jobs done on Brandon (audit, elevatesci rename, core-distro coords) — not yet on `main` |

---

## 1. The reap gate destroyed a live crew — now fixed and landed

This was **my bug**, from `3b0da8b`, and it was serious.

**What happened:** it tore down `quota-fallback-routing-20261012` about eight minutes
after I dispatched it, while the agent was working. No work was lost only by luck — the
crew hadn't written a file yet.

**Root cause.** The gate protected a crew only if its status file's last line said
`working:`:

```bash
if [ -f "$log" ]; then last_status=$(last_status_line "$log" ...); fi
if [ -n "$last_status" ]; then ... return 0; fi   # protection block
```

A **freshly dispatched crew has no status file yet**, so `$last_status` is empty, the
entire protection block is skipped, and the gate falls straight through to teardown.
*No evidence of working* was being read as *not working*.

Worse: `AGENTS.md` and `docs/configuration.md` both say a `state/<id>.status` line is a
**wake event, not current-state truth**, and that `bin/fm-crew-state.sh` owns
reconciliation. The gate was using the wake log as truth — the documented anti-pattern.

I had praised this gate last night as "enforcement that fires without firstmate." It did
fire without firstmate. **It was enforcing the wrong rule**, and because it's automatic,
nobody had to be careless for it to break.

### The fix — landed as `d80900d`

- An **absent status file refuses**: `no status evidence; cannot prove the crew is idle`
- The recorded endpoint is classified with `fm_backend_agent_state`; **alive, ambiguous,
  unverified and unreadable all refuse** (fail closed)
- `fm-crew-state.sh` is consulted as the reconciler that owns current-state truth
- Only a positively dead/missing endpoint, or positively proven landed work, is reapable

**Verification:** RED was `PASS=11 FAIL=6` reproducing the exact data-loss cases (live crew
+ absent status destroyed; live endpoint + stale status destroyed; ambiguous endpoint
destroyed). GREEN is `PASS=17 FAIL=0` — **run on the Controller, the landing surface, not
just the crew's host.** The positive case is still proven: a verified-landed crew is still
cleanly reaped. It was not "fixed" by refusing everything.

**Live proof on HD2** immediately after landing — four real crews refused:

```
REFUSE: portable-paths-20261012        - no status evidence; cannot prove the crew is idle
REFUSE: reap-gate-live-crew-protection - endpoint is alive (alive)
REFUSE: spawn-liveness-verification    - endpoint is alive (alive)
REFUSE: spawnliveness-review           - endpoint is alive (alive)
```

---

## 2. Critical: `minimax-code` was undispatchable — DONE, needs landing

**This is why your quota was being crippled.** Not my routing judgement — a hard defect.

`minimax-code` is registered in `bin/fm-harness.sh` (lines ~96, ~109) but had **no launch
template in `bin/fm-spawn.sh`**. So every attempt failed:

```
error: unknown harness 'minimax-code'; pass a raw launch command to use an unverified adapter
```

Brandon's **own MiniMax quota sat completely unused** while every client job was forced
onto Gemini. Same class of bug as the earlier agy allowlist defect: registered in the
resolver, missing from the owner.

Worse, **`config/crew-dispatch.json` on Brandon still enforced the superseded 2026-10-11
ruling**, whose default was `agy` / `gemini-3.1-pro-high` — the *most expensive* Gemini
tier. That profile silently routed all client work onto the Gemini provider.

### Fixes applied

1. **`config/crew-dispatch.json` on Brandon rewritten** — default is now
   `minimax-code` / `minimax/MiniMax-M3.1-Flash-Preview` (Brandon's own quota).
   The MiniMax route is light-work-only. Gemini is reserved for genuinely hard reasoning and is not
   the default. Each rule carries the reason it exists.
2. **`bin/fm-spawn.sh`** — added a `minimax-code` case to `launch_template()` and to
   `model_flag_for_harness()`. Verified resolving:

```
template:  mcode __MODELFLAG__"$(__OPINPUT__ encode launch-brief < __BRIEF__)"
modelflag: --model "minimax/MiniMax-M3.1-Flash-Preview"
```

**Not yet committed** — a crew was dispatched for this and died on the Gemini quota wall
mid-task, so I did it directly. It needs a scoped review and landing.

Note: `mcode` takes the brief as a **positional argument**, not a flag, and has no
autonomous-permission flag — permissions come from `permissionMode` in the user's own
`config.yaml`, so none was added.

---

## 3. Your rate-limit theory: CONFIRMED

You said the binding constraint on Hetz is per-minute rate limits, not compute, and that
6–7 agents is the sensible max. Evidence from your own 8-agent run — one `gpt-6.1-sol`
parent fanning out to `gpt-6-luna` + `minimax-m31-flash-preview` children, in a single
session:

```
model:gpt-6-luna                 2038 mentions
model:minimax-m31-flash-preview  1027
model:gpt-6.1-sol                  247   (the parent)
RATE-LIMIT HITS:  429 × 664,  "rate limit" × 121
```

**664 HTTP 429s.** It *felt* smooth only because the harness absorbed the retries. Host
capacity is not the limiter: **16 cores, 44 GiB available, 315 GiB disk free.**

### The cap, made durable and enforced

The ceiling was hardcoded to `4` and only reachable via an env var — so a host whose real
limit is a rate limit could not raise it without me remembering to export a variable on
every spawn. **That is not an enforced setting.**

Landed `1ad17ff`: resolution is now **env var → `config/dispatch-max-lanes` → 4**,
with malformed/empty values falling back to the default rather than refusing everything.

```
cap="${FM_DISPATCH_GUARD_MAX_LANES:-}"
if [ -z "$cap" ] && [ -n "${FM_HOME:-}" ] && [ -r "${FM_HOME}/config/dispatch-max-lanes" ]; then
  cap=$(tr -dc '0-9' < "${FM_HOME}/config/dispatch-max-lanes")
fi
case "$cap" in ''|*[!0-9]*) cap=4 ;; esac
```

Verified `PASS=52` (existing) + `PASS=4` (new), with RED proved by running the new test
against the pre-change guard. **Brandon's ceiling is set to `7`** and resolves with no env
var set. Rationale recorded in `data/captain.md`: past ~7 you buy retries, not throughput.

---

## 4. Automated model hopping — it already exists

I did **not** build a scheduler, because the owner already exists.

**`docs/PROVIDER-ROUTING.md`** (312 lines) already documents: per-provider quota scope,
published vendor facts, MiniMax M3 quota semantics, model vs CLI-adapter distinction, a
**selection procedure**, a **safe-handoff observer (read-only)**, **AFK supervisor
integration**, and an explicit **"Active failover and the Hetzner / live-integration
limitation"** section.

Scripts behind it: `fm-provider-route.sh`, `fm-provider-route-watch.sh`,
`fm-provider-route-supervise.sh`, `fm-provider-window.sh`, `fm-luna-quota-gate.sh`,
`fm-quota-axi-lib.sh`.

**Building a parallel mechanism beside this is the night's defining failure.** The next
step is to *extend* `PROVIDER-ROUTING.md`'s handoff so a model change carries the locks
with it, scheduled against UK time. Read the "Active failover and the Hetzner limitation"
section first — it already names a limitation you would otherwise rediscover.

---

## 5. Client work completed on Brandon

All three done, all correct, **none yet on `main`**:

1. **`cbd-local-source-config-audit-20261012`** — local offline audit of
   `projects/cbd-data.com/`, zero production calls.
2. **`elevatesci-canonical-20261012`** — you ruled **`elevatesci.com` canonical**. The
   warehouse **directory was renamed**, and `INDEX/STATUS/SOURCES/REPORT.md` plus the PRD
   were corrected. (8 files carried the wrong spelling.)
3. **`core-distro-coordinates-doc-20261012`** — coordinates documented, including a trap
   worth knowing: **the Controller's `/etc/hosts` overrides `agents.core-distro.com` to
   `127.0.0.1`**, so local probes silently return a local service. Any future check must
   use `dig @1.1.1.1` or `curl --resolve`.

```
data.core-distro.com   = 66.29.153.174   HTTP 200, PHP/8.2.34  -> AS22612 Namecheap, Phoenix AZ
agents.core-distro.com = 161.97.120.4    HTTP 401, nginx/1.24.0, Basic realm "Core-Distro Agents Dashboard"
core-distro.com        = 66.29.153.174
```

**Production is on Namecheap, not the PRD's Hostinger/Hetzner target.** Documented,
deliberately **not** resolved — you ordered ADR-first for core-distro.

---

## 6. Calm — diagnosed, not yet fixed

Your read was right and my first explanation was imprecise. Corrected:

- **Your Hetz pi genuinely has calm.** Its cwd (`/home/hd2admin/kun-agent-workspace`)
  **contains `.pi/extensions/fm-calm.ts`**, and `kun-agent-workspace/config/calm` is `on`.
  No `FM_*` vars needed — the extension falls back to its own root. That works.
- **Spawned crews don't get it** because their pi runs with cwd `/root/agent-work`, which
  has no `.pi/extensions/`, and `/root/.pi/extensions/` doesn't exist either.
- Brandon had **no `config/calm` at all** — created, `on`.

The accurate statement is not "the extension never loads" but "**it loads in directories
that contain `.pi/extensions/`; yours does, a crew's does not.**"

The fix — loading it through the explicit spawn chain so cwd stops mattering, plus a
`CALM OK` / `CALM MISSING` check — is briefed with a **HARD CONSTRAINT** fencing your
session: change only the spawned-crew dispatch path, never `~/.pi`, `.bashrc`,
`kun-agent-workspace/**`, or `.pi/extensions/fm-calm.ts` behaviour. Your pi has no spawn
meta and never passes through `fm-spawn.sh`, so it cannot be affected — and a regression
test must prove an interactively-launched pi resolves calm exactly as it does today.

**Nothing I changed touched your session.** The only file I created was
`agent-work/deightonllm-firstmate/config/calm` — a different home from yours.

---

## 7. Quota position at handoff

```
codex   all_models  96%   through_reset
zai     all_models  91%   five_hour
agy     gemini      22%   PROJECTED EXHAUSTION within the hour
minimax general     17%   PROJECTED EXHAUSTION
```

`agy claude_gpt` is 100%. **Gemini is the fastest-emptying window**, which is exactly why
routing Brandon's light work to its own MiniMax quota matters so much.

---

## 8. DO NOT LAND — `spawn-liveness-verification`

Reviewed and returned **`APPROVE_WITH_CHANGES`, all three concerns UNSAFE**:

1. **`C1 UNSAFE`** — `FM_TEST_AGENT_STATE_OVERRIDE` is read from the **ambient
   environment** on the live dispatch/recovery path (`fm-backend.sh:889`), with **no log
   and no whitelist**. A dead agent can be made to report `alive`. That defeats the gate's
   entire purpose.
2. **`C2 UNSAFE`** — the 10s default is untested against a real boot (test 5 *injects*
   `alive`). A slow-but-healthy agent gets a typed **false negative**. I observed real `pi`
   boot on HD2 taking clearly longer than 10s — treehouse get, lean-ctx banner, agent
   boot.
3. **`C3 UNSAFE`** — `exit 1` **leaks the created pane and worktree** on tmux/herdr/
   zellij/cmux (`spawn_abort_cleanup` covers orca/projection/locks only). Tests manually
   reap, hiding it.

Required before landing: log + whitelist the seam; raise the default timeout and fail fast
**only** on definitive dead/missing, treating the deadline as unproven with artifacts
retained; roll back the created endpoint and worktree on definitive-dead failure.

---

## 9. Open research

**`fm-minimax-regional-pricing-20261012`** — running on Brandon. Answering whether MiniMax
pricing or rate limits differ by region, specifically Singapore/China vs UK/EU, so the
fleet can hand off to codex as those regions come online.

**Do not act on a regional price before that report lands.** A confident wrong number
would send the fleet to the wrong region. The brief requires published-fact vs inference
to be distinguished and forbids inventing a price.

---

## 10. Blocked / deliberately not done

| Item | Why |
|---|---|
| **whooshperformance.com** | Stays blocked. No repo, host, runtime or IP exists anywhere. You'll supply coordinates. |
| **elevatesci host/runtime/source** | Ownership still unknown. Spelling is closed; ownership is not. |
| **SaaS parity / music-metrics.com** | Deferred by your order, "for another day". |
| **core-distro architecture** | ADR-first per your order. Documented, not resolved. |
| **cbd-data migration** | You chose "migrate to the PRD's Hostinger/Hetzner target". Intent is authorised; **execution is not.** A live migration needs a written plan and rollback, and no data/host move without separate explicit authorisation at the moment of execution. Authorising intent is not authorising execution. |
| **Brandon scout teardown** | Refused by the unresolved-decision gate — **correct behaviour.** Its Captain questions must be inventoried via `bin/fm-decision-hold.sh` first. Do not force it. |

---

## 11. Next steps, in order

1. **Review + land the `minimax-code` launch template** (uncommitted, verified resolving).
   This is the highest-value item — it frees Brandon's unused quota immediately.
2. **Review + land the 3 completed Brandon client jobs.**
3. **Re-dispatch the quota-fallback build** — lost twice (once to the reap bug, once to the
   Gemini wall). Extend `fm-dispatch-guard.sh` Rule 4 from *refuse* to *fallback*.
4. **Land `plan-page-harden`** — done, correct RED evidence, `10 pass / 0 fail`.
5. **Calm roll-out**, with the hard constraint protecting your session.
6. **`stale-worktree-guard`** — modifies `fm-spawn.sh` **and** `fm-dispatch-guard.sh`.
   Riskiest thing in the fleet. Review last, most carefully.
7. **Extend `PROVIDER-ROUTING.md`** for automated lock-carrying handoffs on UK time.
8. **HD2 watcher** was ~30 min stale at handoff — rearm it.

---

## 12. How to work here

- Read **`docs/scripts.md`** before building anything. It indexes every script and its
  owner. Building beside an existing owner has been tonight's defining failure.
- **Scope every review to an explicit file list** and make it **write the verdict before
  exploring**. Three unscoped reviewers burned 400k–1.5M tokens and returned nothing.
- **Verify on the landing surface** (the Controller), not only the crew's host.
- **TDD:** failing test first, shown RED, against a **fresh worktree**.
- **Report crews by tab label**, never raw pane ids. Model leads on the left:
  `GLM REVIEW · HD2 · fm-<task-id>`, `agy GEMINI · BRANDON · fm-<task-id>`.
- Herdr's `agent` field is derived from the harness and **cannot be renamed**; the model
  rides in the **tab label**, applied **at spawn**.
- Never production-write without explicit authorisation. Never bypass a production-write
  gate. Never disable the secret scanner to make a tool boot.
- Never `--force` teardown. Never discard unlanded work.