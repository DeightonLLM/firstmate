# Next board: token band and chat contract

Owner: this file. It is the single shared truth between the lanes that PRODUCE the
board's token band and chat state and the lane that RENDERS them. Nothing else
re-derives these shapes.

Context. The Captain's live board (`bin/fm-next-board-publish.py` -> served at
`/next-board/`) already publishes the ticket queue, the NEXT sections and the
delivery state. Two things are missing: a token band that aggregates usage across
ALL accounts (weekly and daily, with a heat map and a rollover timeline), and a
chat path that works like the other board's Lavish ticket system - a message the
Captain writes reaches the agent as a wake, and the agent's reply lands back on
the board.

Contract A was extended to **v2** on 2026-10-21.
The Captain asked for "all tokens used aggregated" across every surface and every
account, and v1 could not answer that: it described ONE ledger with ONE surface and
ONE account per provider, while the ledger it read actually carried rows from more
than one surface.
v2 makes the surface and the account explicit, gives every row its provenance, and
computes the coverage from the same rows that produce the total.
The cross-surface collection mechanism is owned by
[`token-usage-surface-contract.md`](token-usage-surface-contract.md).

## 1. Rules that bind every producer and renderer

1. **null != zero.** An unknown value stays `null` and is labelled. It is never
   rendered, summed or reported as `0`.
2. **One source per field.** Quota windows come from `quota-axi`; token usage
   comes from the usage ledger. Neither re-reduces the other's counters.
3. **No credential refresh, no network** beyond the named read-only commands.
4. **Fail open, never fail silently.** A missing source produces an explicit
   `ok: false` plus an error string, and the rest of the band still renders.
   A surface that reported nothing produces unknown coverage plus a reason, and is
   never dropped.
5. **Deterministic output.** Same inputs -> byte-identical JSON (sorted keys,
   sorted rows). No timestamps invented inside the data (only `generated_at`).

## 2. Contract A - `data/next-board-publish/token-band.json`

Produced by `bin/fm-token-collect.py`; rendered by the publisher.

```json
{
  "schema": "firstmate-token-band/v2",
  "generated_at": "2026-10-21T05:00:00Z",
  "errors": [],
  "quota": {
    "ok": true,
    "error": null,
    "source_command": ["quota-axi", "--json", "--full", "--no-credential-refresh"],
    "source_generated_at": "2026-10-21T04:58:00Z",
    "windows": [
      {
        "key": "codex|weekly|2026-10-27",
        "provider": "codex",
        "provider_label": "Codex",
        "plan": "plus",
        "account_id": "602f6bbb-f81c-45e4-b32e-e271af438384",
        "account_email": "boxedagency@gmail.com",
        "account_keys": ["codex-home", "openai-codex"],
        "window_id": "weekly",
        "window_label": "week",
        "kind": "weekly",
        "label": "Codex - week",
        "percent_remaining": 82,
        "percent_used": 18,
        "resets_at": "2026-10-27T06:34:19.000Z",
        "window_seconds": 604800,
        "resets_in_seconds": 1234567,
        "pace_status": "ahead",
        "projected_exhausted_at": "2026-10-25T09:13:27.050Z",
        "runway_status": "projected_exhaustion",
        "state": "fresh",
        "stale": false,
        "error": null
      }
    ],
    "providers_without_windows": [
      {"provider": "claude", "state": "auth_required", "error": "credentials_missing", "not_set_up": true}
    ]
  },
  "ledger": {
    "ok": true,
    "error": null,
    "path": "data/tracker-tokens-20261019/ledger/usage.json",
    "contract_version": 2,
    "timezone": "Europe/London",
    "surface": "vmi3196300",
    "generated_at": "2026-10-20T09:35:50+01:00",
    "roster_path": "docs/system-context/token-usage-surfaces.json",
    "accounts": [
      {"id": "controller|codex-local-unmapped", "account_id": "codex-local-unmapped",
       "surface": "controller", "provider": "codex",
       "label": "Controller (Crisp-R) \u00b7 codex local (unmapped)",
       "identity_status": "unknown_local_subset", "status": "measured", "reason": null}
    ],
    "surfaces": [
      {"surface": "controller", "label": "Controller (Crisp-R)", "host": "vmi3196300",
       "aliases": ["crisp-r", "vmi3196300"], "role": "captain_surface", "status": "reported",
       "reason": null, "source_kind": "owner_ledger",
       "source_path": "data/tracker-tokens-20261019/ledger/usage.json",
       "observed_at": "2026-10-20T09:35:50+01:00", "days_reported": ["2026-10-19"],
       "expected_providers": ["agy", "codex", "glm", "minimax"],
       "accounts": ["codex-local-unmapped"]}
    ],
    "sources": [
      {"surface": "controller", "source_kind": "owner_ledger",
       "path": "data/tracker-tokens-20261019/ledger/usage.json", "status": "ok",
       "reason": null, "observed_at": "2026-10-20T09:35:50+01:00"}
    ],
    "conflicts": []
  },
  "daily": [
    {
      "date": "2026-10-13",
      "total_tokens": 158656541,
      "total_status": "partial",
      "total_measured_tokens": 158656541,
      "total_reported_tokens": 0,
      "source_total_status": "measured",
      "accounts": {"controller|codex-local-unmapped": 91313643, "controller|glm-local-unmapped": 52021917},
      "accounts_known": 2,
      "accounts_unknown": 0,
      "coverage_slots_expected": 16,
      "coverage_slots_measured": 2,
      "coverage_slots_unknown": 14,
      "rows": [
        {"date": "2026-10-13", "surface": "controller", "surface_host": "vmi3196300",
         "account_id": "codex-local-unmapped", "provider": "codex",
         "source_id": "vmi3238503:pi:codex", "source_kind": "local_metadata",
         "measurement": "measured", "coverage": "local_metadata",
         "total_tokens": 91313643, "observed_at": "2026-10-19T07:52:02+01:00",
         "counted": true, "reason": null}
      ],
      "surfaces": {
        "controller": {"total_tokens": 158656541, "accounts_known": 2,
                       "accounts_unknown": 14, "measured": true}
      }
    }
  ],
  "weekly": {
    "start_date": "2026-10-15",
    "end_date": "2026-10-21",
    "days_expected": 7,
    "days_known": 5,
    "days_unknown": 2,
    "total_tokens": 655333299,
    "total_measured_tokens": 367773299,
    "total_reported_tokens": 287560000,
    "status": "partial",
    "is_floor": true,
    "per_account": {"controller|codex-local-unmapped": 230674066},
    "per_account_known_days": {"controller|codex-local-unmapped": 4},
    "per_surface": {
      "controller": {"total_tokens": 230674066, "days_known": 4, "days_partial": 0,
                     "accounts_known": 4, "accounts_unknown": 3}
    }
  },
  "coverage": {
    "surfaces": [
      {"surface": "controller", "label": "Controller (Crisp-R)", "host": "vmi3196300",
       "aliases": ["crisp-r", "vmi3196300"], "role": "captain_surface", "status": "reported",
       "reason": null, "source_kind": "owner_ledger",
       "source_path": "data/tracker-tokens-20261019/ledger/usage.json",
       "observed_at": "2026-10-20T09:35:50+01:00",
       "days_reported": ["2026-10-19"],
       "providers": [
         {"provider": "codex", "label": "Codex", "status": "measured", "reason": null,
          "expected": true, "accounts": ["codex-local-unmapped"]},
         {"provider": "agy", "label": "Antigravity (Gemini)", "status": "unknown",
          "reason": "no local usage metadata surface exposes Gemini/Antigravity token counts",
          "expected": true, "accounts": []}
       ]}
    ],
    "unknown": [
      {"surface": "controller", "provider": "agy",
       "reason": "no local usage metadata surface exposes Gemini/Antigravity token counts"}
    ]
  },
  "rollover": [
    {
      "key": "codex|five_hour|2026-10-21",
      "provider": "codex",
      "window_id": "five_hour",
      "kind": "session",
      "label": "Codex - session",
      "resets_at": "2026-10-21T06:50:19.000Z",
      "resets_in_seconds": 2700,
      "percent_remaining": 70,
      "restores_percent": 100
    }
  ]
}
```

### 2.1 Rules for `quota.windows`

* One row per (provider, window id, reset DAY). `quota-axi` can report the same
  window id twice with different reset instants - `agy` reports two
  `gemini_weekly` windows (one resetting 2026-10-23, one 2026-10-26). They are
  TWO accounts/windows and must never be merged or de-duplicated. `key` is
  `<provider>|<window_id>|<reset day>`; the reset day is `resets_at[:10]`, or
  `no-reset` when absent.
* `label` is `<provider label> - <window label>`. When one provider reports the
  same window id more than once, the label carries the reset day so the two rows
  are distinguishable on screen.
* `percent_remaining` / `percent_used` come from the window itself. A window
  that reports neither keeps both as `null`.
* `resets_in_seconds` is computed at collection time and may be negative for a
  window already past its reset; it is informational only.
* `pace_status`, `projected_exhausted_at` and `runway_status` come from the
  window's own `pace` block and the provider's `quotaSemantics.effectiveAvailability`
  entry whose `limitingWindowIds` names that window.
* `account_email` / `account_id` come from the provider's `account` block.
  `account_keys` comes from the provider's `accountKeys`.
* Providers with no usable window are listed in `providers_without_windows` with
  their real state (`auth_required`, `not_set_up: true`, etc). They are never
  dropped silently.

### 2.2 Rules for `ledger`

* `ledger.path` is the Controller's own usage ledger; `ledger.surface` is the
  surface that ledger DECLARES. The declared surface is provenance, not truth: a
  ledger may carry rows from more than one surface, and each row is attributed to
  the surface its own `surface` field names.
* `ledger.accounts` is the fleet's account registry. Its `id` is the cell key
  `<surface>|<account>`, which is the key every other map in the band uses. Two
  surfaces holding the same local account name therefore stay two accounts.
* `ledger.surfaces` names every surface the roster knows, plus any surface an
  unrostered source reported under. `status` is `reported` when the surface
  reported something and `no_source` when it did not; `reason` says why, and it
  is never `0` and never empty for a surface that did not report.
* `ledger.sources` names every document that fed the band, with the path it came
  from and when it was observed.
* `ledger.conflicts` carries the readings that arrived twice and disagreed, and
  the ones that were shadowed because the same account-day came from two
  origins. A conflict is reported, never averaged away.

### 2.3 Rules for `daily` and `weekly`

* `daily` is one row per day, ascending by date, from every usage source.
  A day a source declared but carried no rows for is still a row: it is
  unmeasured, with `total_tokens: null` and `total_status: "unknown"`.
* A day's `total_tokens` is the sum of that day's KNOWN account cells, and
  `total_measured_tokens` plus `total_reported_tokens` add up to it. A cell whose
  reading is `null` is unknown: it contributes nothing and it is never a zero.
* `total_status` is `measured` when every expected coverage slot for that day
  was measured and every reading was instrumented, `partial` when some expected
  slot is unmeasured, some cell is unknown, or the day mixes instrumented and
  operator-reported numbers, and `unknown` when the day has no known cell at all.
* `accounts` maps each cell key to that day's total for that cell. A day can
  hold SEVERAL rows for one cell (different `source_id`s); they are summed into
  that cell. A cell with no reading is simply absent from the map - absent is
  not zero.
* `rows` carries every reading for the day with its full provenance: the surface,
  the account identity, the source, the measurement kind, and whether the row was
  counted into the day's total.
* `coverage_slots_*` counts the (surface, provider) pairs the roster expects for
  that day, and how many of them were measured. The slots and the totals come
  from the same rows, so they cannot disagree.
* `weekly` covers the 7 calendar days ending today (ledger timezone). It sums
  only days with a known total. When any day in the window is unknown,
  missing or partial, `total_tokens` is a FLOOR: `is_floor: true` and
  `status: "partial"` (or `"unknown"` when nothing in the window is known). The
  renderer must say "at least N" whenever `is_floor` is true.
* `per_account` is the same floor logic per cell, with
  `per_account_known_days` saying how many of the 7 days actually carried that
  cell. `per_surface` is the same rollup per surface.

### 2.4 Rules for `coverage`

* `coverage.surfaces` is the fleet's reporting state: one entry per surface with
  its providers, and per provider whether it was measured or is unknown.
* An unknown provider carries the reason it is unknown: the surface reported
  nothing at all, the surface reported usage on other providers only, or no local
  usage surface exposes that provider's token counts.
* `coverage.unknown` is the flat list of the unknown (surface, provider) pairs.
  It is the answer to "which accounts are covered and which are unknown", and it
  is derived from the same rows that produce the totals.

### 2.5 Rules for `rollover`

* One row per quota window, sorted by `resets_at` ascending.
* `restores_percent` is `100` - a rollover returns that window to full.
* A window with no `resets_at` is not a rollover and is omitted.

## 3. Contract B - board chat state

The board's chat has TWO inbound paths and ONE visible conversation.

### 3.1 Inbound path 1 - the Lavish session (the ticket system)

`bin/fm-next-board-chat.sh` owns it. The artifact is the published board itself:
`<repo>/data/next-board-publish/index.html`. Its realpath MUST stay stable,
because the Lavish source id is derived from it - never copy or move the
artifact to a different path for a session.

* `review` - ensure the artifact exists, `lavish-axi <artifact>` to open or
  resume the session, then `bin/fm-procevent-lavish.sh arm <artifact>`. Record
  the session in `state/next-board-session.json`.
* `reply` - `lavish-axi reply <artifact> --agent-reply-file <path>`, and write a
  copy of the same body into `state/next-board-feedback/replies/`.
* `end` - `lavish-axi end <artifact>`, then retire the registered source.
* `status` - print the source id, session URL, whether the poll runner is alive,
  the pending result count and the last delivery.

`state/next-board-session.json`:

```json
{
  "schema": "firstmate-next-board-session/v1",
  "opened_at": "2026-10-21T05:10:00Z",
  "source_id": "lavish-a1b2c3d4e5f60718",
  "session_id": "affb98427860194e",
  "url": "http://host.tailnet.ts.net:4387/session/affb98427860194e",
  "artifact": "/root/agent-work/deightonllm-firstmate/data/next-board-publish/index.html",
  "armed": true,
  "poll_pid": 12345,
  "last_result_at": null,
  "pending_results": 0
}
```

Never invent a session URL: it comes from the `lavish-axi` output.

### 3.2 Inbound path 2 - the board's own form

The board renders a form that POSTs to `/next-board/feedback` with two fields,
`ticket` and `comment`. `bin/fm-tracker-view-serve.py` handles it:

* Same-origin only. A cross-origin `Origin` header is refused with 403.
* `Content-Type` must be `application/x-www-form-urlencoded` (415 otherwise).
* Body cap 16384 bytes (413), ticket cap 200 chars, comment cap 8000 chars (400).
* Writes `state/next-board-feedback/<YYYYMMDDTHHMMSSZ>-<slug>.md` with mode
  0600, in exactly this shape:

```
# Board feedback

- Timestamp: 2026-10-21T05:12:00Z
- Ticket: 0042-some-slug
- Source: form

## Comment

> the comment, one quoted line per line
```

* Then appends a durable wake so the agent is woken. The wake is appended
  through `bin/fm-next-board-feedback.sh`, which uses `fm_wake_append` from
  `bin/fm-wake-lib.sh` (kind `signal`). The wake-queue file format and the
  sequence counter belong to that library - never write the queue by hand.
* Responds 201 with the saved filename and timestamp.

### 3.3 What the board renders

The publisher renders a `<section class="card wide" id="talk">` card that shows:

1. the Lavish session link when `state/next-board-session.json` exists, and the
   live session state otherwise (never a fabricated link);
2. the form (fields `ticket`, `comment`) posting to `/next-board/feedback`;
3. the most recent conversation entries, newest first, read from
   `state/next-board-feedback/*.md` (inbound) and
   `state/next-board-feedback/replies/*.md` (agent replies);
4. a truthful statement when there is no feedback yet, or when the state
   directory cannot be read.

## 4. The selected next work

The board carries ONE selected next-work suggestion, at the top, derived from
the Captain's own ticket queue - not from a separate plan.

Selection rule, applied in order, first match wins:

1. only tickets whose derived state is `OPEN-WORKABLE` (not
   `NEEDS-CAPTAIN-DECISION`, not `BLOCKED`, not `CONTRACT-GAP`) are eligible;
2. among those, the lowest priority number wins (`P0` before `P1` before `P2`);
3. ties are broken by the oldest `received` timestamp, then by sequence.

The card must show, and nothing more: the ticket id and slug, the priority, why
it was selected (the rule that picked it), the next action, the owner, and what
"done" looks like. If no ticket is eligible, say so plainly instead of inventing
one.

## 5. What is NOT in scope

* No port of the other board's feature set (its tasks/next-moves dashboard, its
  lane views). The Captain asked for the shape, not a copy.
* No image or video content-block path.
* No upstream docs port.
