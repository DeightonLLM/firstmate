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

## 1. Rules that bind every producer and renderer

1. **null != zero.** An unknown value stays `null` and is labelled. It is never
   rendered, summed or reported as `0`.
2. **One source per field.** Quota windows come from `quota-axi`; token usage
   comes from the usage ledger. Neither re-reduces the other's counters.
3. **No credential refresh, no network** beyond the named read-only commands.
4. **Fail open, never fail silently.** A missing source produces an explicit
   `ok: false` plus an error string, and the rest of the band still renders.
5. **Deterministic output.** Same inputs -> byte-identical JSON (sorted keys,
   sorted rows). No timestamps invented inside the data (only `generated_at`).

## 2. Contract A - `data/next-board-publish/token-band.json`

Produced by `bin/fm-token-collect.py`; rendered by the publisher.

```json
{
  "schema": "firstmate-token-band/v1",
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
    "path": "data/tracker-tokens-20261019/ledger/usage.json",
    "contract_version": 1,
    "timezone": "Europe/London",
    "surface": "vmi3196300",
    "generated_at": "2026-10-20T09:35:50+01:00",
    "accounts": [
      {"id": "codex-local-unmapped", "label": "codex local (unmapped)", "provider": "codex", "identity_status": "unknown_local_subset"}
    ]
  },
  "daily": [
    {
      "date": "2026-10-13",
      "total_tokens": 158656541,
      "total_status": "measured",
      "accounts": {"codex-local-unmapped": 91313643, "glm-local-unmapped": 52021917},
      "accounts_known": 2,
      "accounts_unknown": 0
    }
  ],
  "weekly": {
    "start_date": "2026-10-15",
    "end_date": "2026-10-21",
    "days_expected": 7,
    "days_known": 5,
    "days_unknown": 2,
    "total_tokens": 655333299,
    "status": "partial",
    "is_floor": true,
    "per_account": {"codex-local-unmapped": 230674066},
    "per_account_known_days": {"codex-local-unmapped": 4}
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

### 2.2 Rules for `daily` and `weekly`

* `daily` is one row per ledger day, ascending by date, from
  `data/tracker-tokens-20261019/ledger/usage.json` (`days[]`).
* A ledger day whose `total_tokens` is `null` stays `null` with
  `total_status: "unknown"`. A day with a partial total keeps
  `total_status: "partial"`.
* `accounts` maps each ledger account id to that day's total for that account.
  A day can hold SEVERAL rows for one account (different `source_id`s); they are
  summed into that account's day cell. An account with no reading for that day is
  simply absent from the map - absent is not zero.
* `weekly` covers the 7 calendar days ending today (ledger timezone). It sums
  only days with a known total. When any day in the window is unknown or
  missing, `total_tokens` is a FLOOR: `is_floor: true` and
  `status: "partial"` (or `"unknown"` when nothing in the window is known). The
  renderer must say "at least N" whenever `is_floor` is true.
* `per_account` is the same floor logic per account, with
  `per_account_known_days` saying how many of the 7 days actually carried that
  account.

### 2.3 Rules for `rollover`

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
