# LEANCTX-FINDING-20260929 — board metric is stale; tuning target retired

**Date:** 2026-09-29 · **Source:** `firstmate/BOARD.md` "DEFERRED — 24-HOUR LIST"
**Deferral window:** "do not action before 2026-09-29 05:45 BST" — **expired**, so
the item became eligible. It was re-measured as the board itself instructed
("Re-measure before deciding") rather than tuned blind.

## Verdict: do NOT tune. The target metric is dead.

The board set: **"Targets: compression_rate 14% → 40%, cache_hit_rate 0% → ≥29%."**

Both targets are already met, and were measured against a stale snapshot.

| Board claim | Live reality |
|---|---|
| `compression_rate = 14`, target 40% | **69.7% all-time** — target already passed |
| `cache_hit_rate = 0`, target ≥29% | **29%** — target already met (`4440/15180`) |
| "5-min idle eviction destroys the cache" | **Disproven** — `verify-cache` = PASS, 99% re-read savings |

**Root cause of the bad metric:** `cep.last_snapshot` in
`/root/.config/lean-ctx/report/latest.json` is frozen at
`2026-06-15T07:08:56` — over three months stale, stuck at `tool_calls=85`.
`lean-ctx token-report` prints that frozen `cep(last)` line, which is where the
board's "14" and "0" came from. Both numbers describe a session from June, not
the current state.

Independently recomputed from the same file's live totals:

```
total_tokens_original  = 266,295,569
total_tokens_compressed = 80,780,199
=> 1 - 80780199/266295569 = 69.7% all-time compression
```

Per-session figure is 13,555,773 / 37,414,317 = **36.2%**.

## What `compression_rate` actually is

It is a **model, not a measurement**. The binary's own glossary: *"Share of
estimated input tokens removed before sending, all-time (estimated saved ÷
estimated input)."* Savings are *estimated* by counting every read at full file
size (including cache-served re-reads) and search/grep against a modeled native
tool baseline (~2.5× observed matches).

So the ceiling is **workload-bound, not config-bound**: read-heavy `/root` work
already sits near 70%; shell-heavy work compresses less. Chasing 40% is chasing
a number that was never the binding constraint.

## The other two board hypotheses, re-checked

- **At-capacity knowledge stores are NOT a bottleneck.** `facts=200` /
  `history=100` sit exactly at `max_facts` / `max_history` in *chronological*
  order with `updated_at` == newest entry — a rolling oldest-out window that is
  still accepting writes. Not refusing, not blocking. Expected steady state.
- **`lean-ctx doctor --fix` (XDG split) is unrelated hygiene.** It relocates
  files between directories and changes no compression parameter. Restart
  requirement is **unverified** — treat as needing a restart until proven
  otherwise. Out of scope; not actioned.

## Recommended action: retire the metric, change nothing

**No config change was made.** The reason is specific: the one candidate knob
(`output_density=terse`) cannot be validated in this lane, because whether the
running MCP server hot-reloads `config.toml` is **unknown**. If it does not, the
change requires a session restart, and the correct outcome is *no change* with
the stale metric retired instead.

Two further cautions if this is ever picked up:

- **Do not tune `compression_level`.** Its schema says it governs *"the model's
  prose (not tool-output compression)"* and injects `[COMPRESSION: lite]`-style
  instructions. It would move the board's number without moving real
  compression.
- **An auto-degradation policy is already active.** `no_degrade=False` allows a
  `DegradationPolicyV1` ladder to escalate `switch_mode=signatures` and
  `output_density=terse` on `correction_rate_high` ("compression auto-degraded
  due to repeated correction signals"). Manual tuning would collide with a
  policy already adjusting the same knobs.

**Correct measurement going forward** (do not use `token-report`'s `cep(last)`):

```bash
python3 -c "import json;d=json.load(open('/root/.config/lean-ctx/report/latest.json'))['cep'];print(round((1-d['total_tokens_compressed']/d['total_tokens_original'])*100,1))"
```

## Correctness caution for future work

The `ctx_shell` docs claim compression is "lossless for signal". That is
narrowly true (compiler errors, test results, panics kept verbatim) and **false
in general**. Confirmed lossy behaviours in the binary:

- `density:0.X` — ships a self-test string `density_deterministic:0.4 — two
  density renders of the same fixture differ`; i.e. **non-deterministic**.
- `entropy` mode — Shannon-entropy filtered, "maximum compression"; drops
  low-entropy lines by design.
- `aggressive` — syntax-stripped. `terraform plan` — "full plan truncated".
  `git blame` — "verbatim up to 100 lines, then summary". `ruff check` —
  "verbatim up to 30 issues…then sum".
- Token-budget-driven `"omitted (token budget: …)"` truncation, and secret
  redaction (`token/password/secret REDACTED`) which can strip values during
  `/root` work.

**Do not use lossy read/shell modes when the exact bytes matter** — including
when editing a file (use `mode=full` immediately before an edit).

## Evidence

- `lean-ctx token-report` → `cep(last): … compression_rate=14` (the stale June snapshot)
- `report/latest.json` → `cep.last_snapshot.timestamp = 2026-06-15T07:08:56`; live totals as above
- `lean-ctx verify-cache` → PASS, 2181 → 21 tokens, 29% cross-call hit, 827 sessions
- `lean-ctx doctor` → "Session cache: 827 sessions, 4440/15180 reads cached (29% hit)"
- `lean-ctx config schema` → `output_density='normal'`, `compression_level='lite'`, `memory_profile='performance'`, `cache_policy='aggressive'`, `max_facts=200`, `max_history=100`
- `strings` on `/usr/lib/node_modules/lean-ctx-bin/bin/lean-ctx` (stripped Go binary, no source available) → metric glossary, `DegradationPolicyV1`, lossy pattern catalog

## Confidence

**High** on the staleness finding and the disproof of the eviction hypothesis
(direct artifact evidence, independently recomputed). **Medium** on knob
selection — no A/B was possible read-only, and hot-reload is unresolved.
