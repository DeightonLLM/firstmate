# The Hetz harness is bespoke — read before changing anything

**This is not a stock Pi install.** Roughly 2,200 lines of local TypeScript sit on top of the
upstream `@earendil-works/pi-coding-agent`. Nothing here is in a package registry. If you change
one of these files, you change the harness, not just a config value.

**Treat every file below as load-bearing.** There is no upstream copy to diff against and no test
suite that would catch a regression before it reaches a live session.

## Where the code lives

Two locations, and the distinction matters — they have different blast radii.

```
/home/hd2admin/kun-agent-workspace/.pi/extensions/     TRACKED in firstmate, ships to other homes
/home/hd2admin/.pi/agent/extensions/                    LOCAL, gitignored, machine-specific
```

A change to the first directory propagates to every secondmate home on next update. A change to
the second affects only this machine. **Know which one you are in before you edit.**

## Firstmate extensions (tracked)

```
fm-primary-pi-watch.ts        518   watcher bridge: wake queue, supervision cycle, lock ownership
fm-calm.ts                    348   home-persistent transcript presentation toggle
fm-primary-turnend-guard.ts   162   refuses a turn that would end while work is in flight
fm-secondmate-guard.ts        121   PreToolUse: a secondmate may never take the controller's seat
lib/fm-calm-working-ship.ts   255   Calm layout rules
lib/fm-calm-operational-user-layout.ts  145
lib/fm-calm-visibility.ts      96
lib/fm-calm-assistant-layout.ts 68
```

`fm-secondmate-guard.test.sh` sits beside the guard it tests. Run it after touching that guard.

## Local extensions (this machine only)

```
herdr-agent-state.ts   261   herdr-installed: pane liveness and agent state
herdr-lane-status.ts    75   human-readable model labels: M3.1 / Luna / Sol / GLM53
m3-early-compaction.ts  65   M3-specific early compaction at 50%
pi-lean-ctx/            --   lean-ctx MCP bridge, persistent session cache
todo.ts.disabled-20261009      deliberately disabled, do not re-enable casually
```

## The two mechanisms that fight each other

**This is the single most important thing to understand here.** M3 compaction is controlled
twice, and they were configured inconsistently.

```
settings.json  compaction.modelOverrides   a RESERVE, in tokens
m3-early-compaction.ts  COMPACT_AT = 0.50  a FRACTION of the window used
```

The extension fires first because it triggers on a fraction while the built-in setting expresses
itself as response-reserve tokens. A 800,000-token reserve on a 1,050,000-token window reserved
76% of the window and compacted at roughly 20% used — that is why compaction appeared to fire far
too early.

`m3-early-compaction.ts` explains itself: it exists because inflating `reserveTokens` for every
model is worse than a model-specific extension. **It is a deliberate design choice, not a
workaround.** Compaction at 50% was aligned to `AGENTS.md` `CONTEXT_HANDOFF_DUE` and to
`herdr-m3-early-compaction` (`HERDR_M3_COMPACT_AT`, default 50). A prior value of 0.40 matched the
registry but not the operator's stated 50% target, and was corrected.

**If you change one of these, check the other.** They are the same decision expressed twice.

## Model routing, and what the "1M" actually means

```
Firstmate     M3.1 high (Mode B)
Workers       openai-codex/gpt-6-luna, medium/high effort
Review        M3.1 high
pi-codex-fast extension is Codex-only; M3.1 cannot enter fast mode through it
```

The 1M figure is `contextWindow` in `models.json`. It is not headroom: `maxTokens` is 128,000, and
compaction is measured against the window, not against that output ceiling.

## Regeneration and resets

```
models.json      backed up before M3.1 registration; a stale pair exists as *.bak-pre-m31-*
settings.json    backed up before each compaction change
lean-ctx config  backed up before each allowlist change
```

**Take a backup before editing, and name it with a timestamp.** There are several generations of
these files on disk and they are the only record of what the previous value was.

## Things that are deliberately the way they are

- `todo.ts.disabled-20261009` — disabled on purpose. Re-enabling changes every session.
- Pi needs a **restart** for extension, model, and settings changes to take effect. Reading the
  new value in the file does not mean it is loaded.
- `herdr-lane-status.ts` matches models on an exact label map, not a substring. A broad substring
  match was the original bug and mislabelled every model.
- Ollama listens on `127.0.0.1:11434` only. Public exposure is a separate authorised decision and
  has not been made.

## Before you change a file here

1. Identify which directory: tracked and machine-wide, or local and this-machine-only.
2. Back up with a timestamp.
3. Check whether a second mechanism encodes the same decision.
4. Restart Pi, then verify the live value — not the value in the file.
5. Confirm the lane you care about still runs: M3.1, and Luna workers, at their expected settings.