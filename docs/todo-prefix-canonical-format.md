# Canonical To-Do prefix and lane-key format

Status: ACTIVE.
Owner: this document owns the canonical format for this repository.
Machine checker: `bin/fm-todo-prefix-check.sh`.
Tests: `tests/fm-todo-prefix-check.test.sh`.

This contract replaces three competing formats that were live at once.
The adopted format is the one that is machine-enforced across surfaces, because it is the only one that survives the round trip to the other host's tracker.
The competing forms are listed under "Rejected legacy formats" below.

## Canonical board row prefix

Every To-Do board row starts with this prefix:

    [<harness>·<ModelAbbrev> <effort> @<Host>]

- `<harness>` is the real harness that runs the work.
- `<ModelAbbrev>` is a documented short alias for the exact model identifier.
- `<effort>` is the measured effort token, or the literal `unknown` when the effort is not measurable.
- `<Host>` is the host where the owner RUNS, not the remote target being investigated.

The owner role is NOT part of the prefix.
It is stated in the task text instead, so the prefix stays machine-checkable on every surface.

A complete row looks like this:

    [mcode·m3.1f m @brandon] Reconcile worker results - running

## Canonical lane key

Lane keys, including the `lane_key` column of the async lane registry, use:

    <harness>-<model>-<host>-<task>

Lowercase, no spaces.
The task segment may contain hyphens and dots.
Example: `pi-luna6-brandon-theme-whoosh`.

## Model alias table

The alias table lives in exactly one place, `bin/fm-todo-prefix-check.sh`, and maps each alias to its exact catalog identifier.

| Alias | Exact catalog identifier |
|---|---|
| `m3.1f` | `minimax/MiniMax-M3.1-Flash` |
| `m3.1` | `minimax/MiniMax-M3.1` |
| `luna6` | `openai-codex/gpt-6-luna` |
| `glm5.3f` | `zai/glm-5.3-flash` |
| `gem38f` | `agy/gemini-3.8-flash-medium` |
| `pi` | `minimax/MiniMax-M3.1-Flash`, the Pi session default model, kept as a legacy alias |

Alternate spellings resolve to the same canonical alias: `m31`, `m31f`, `g38f`.
The cross-surface tracker writes its own abbreviations as `G38F` and `M31`, so the checker accepts those spellings in a board prefix.

## Tokens

Harness tokens: `pi`, `codex`, `claude`, `opencode`, `mcode`, `grok`, `kimi`, `agy`.

Effort tokens: `unknown`, the bare codes `l`, `m`, `h`, `xh`, `x`, and the spelled-out `low`, `medium`, `high`, `xhigh`, `max`.
`max` is accepted by the checker but is only dispatched on explicit captain preference.
`x` is accepted as a bare code without this document asserting which named level it maps to.
Use `unknown` when the effort was not measured, never a guess.

Host tokens: any hostname token.
This fleet uses `brandon` (this host, `157.180.99.39`), `hd2stack`, `controller` and `elevate`.
The host segment is a hostname, so a new host needs no code change.

## Case policy

A board prefix matches its harness, model alias and host tokens case-insensitively, because the cross-surface tracker's own worked example is `[agy·G38F m @HD2]`.
A lane key is an identifier and stays lowercase and canonical.

## Rejected legacy formats

Each of these is rejected by the checker with a message naming the expected canonical shape.

| Legacy form | Example | Why it is rejected |
|---|---|---|
| Owner role inside the prefix | `[mcode·luna6 m @brandon \| worker] do the work` | The owner role is not part of the canonical prefix. State it in the task text. |
| Owner and host only | `[controller @ brandon] reconcile evidence - running` | No harness and model segment. |
| Model and surface only | `[m3.1f @ brandon] widget fix - working` | No harness, model abbreviation or effort token. |
| No effort token | `[mcode·luna6 @brandon] missing effort` | The effort token is mandatory, or the literal `unknown`. |
| Legacy lane key | `m3.1f-hd2-build` | A lane key needs a harness segment. |

## The checker

    bin/fm-todo-prefix-check.sh "<board row>" ["<board row>" ...]
    bin/fm-todo-prefix-check.sh --stdin < rows.txt
    bin/fm-todo-prefix-check.sh --lane-key "<lane-key>"
    bin/fm-todo-prefix-check.sh --registry <path.tsv>
    bin/fm-todo-prefix-check.sh --self-check <dispatch-config.json>
    bin/fm-todo-prefix-check.sh --alias-table
    bin/fm-todo-prefix-check.sh --help

Exit codes:

- `0` every checked input is valid.
- `1` one or more inputs are invalid, and the offending input is named on stderr.
- `2` a usage error, or a fatal `--self-check` alias gap.

`--alias-table` prints the alias table as `<alias><TAB><exact catalog identifier>` lines, one per alias in table order.
It is read-only and always exits 0.
It exists so the exact catalog identifier behind each alias is readable from outside the script that owns the table.

The checker never edits or fixes its input.
It only validates and reports.

## Registry mode

`--registry` validates a lane registry in the `data/async-lanes.tsv` shape:

    run_id<TAB>lane_key<TAB>model<TAB>surface<TAB>task<TAB>state<TAB>output

Comment lines beginning with `#` and blank lines are skipped.
Every data row must have exactly 7 TAB-separated fields.
The `lane_key` column must satisfy the canonical lane-key format, and its model segment must agree with the `model` column.
Run id identity rules are not owned here; `bin/fm-lane-naming-check.sh` owns those.

## Self-check mode

`--self-check` binds the hardcoded alias table to a dispatch config.
It derives the lane-key alias for every configured MiniMax model id and fails with exit 2 when a configured MiniMax model has no alias in the table.
Aliases that no configured model derives are reported on stdout as informational warnings and never change the exit code.
This mirrors `bin/fm-lane-naming-check.sh --self-check` so the two checks cannot contradict.

The derivation rule, one canonical statement:

    minimax/MiniMax-M<family>[-<tier>]  ->  family + tier-marker
    tier-marker: 'highspeed' -> 'h', 'flash' -> 'f', bare or unrecognised -> ''
    minimax/MiniMax-M3.1-Flash  -> m3.1f
    minimax/MiniMax-M3.1        -> m3.1

Other providers have no derivation rule and are out of scope for this binding.

## Boundaries and unverified points

- The cross-surface tracker and its own `fm-todo-prefix-check.sh` live on the other host and cannot be read from here.
  Its exact alias list and effort vocabulary are therefore unverified from this repository.
  This contract adopts the format shape that host documents and keeps this repository's own alias table.
- The captain note dated 2026-10-20 asks for visible To-Do titles to start with the concrete proposed action rather than a repeated harness, model and host prefix.
  That direction is recorded and is not resolved here.
  The checker enforces the canonical prefix on any row it is given, and a row without the prefix is rejected.
  A deliberate action-first title is a deviation this checker will report, so decide it before running the checker over the live board.
- The owner-role segment of the earlier format is not lost, it moves into the task text.
