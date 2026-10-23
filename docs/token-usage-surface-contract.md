# Token usage surface contract — how every surface reports its tokens

Owner: this file.
It is the single shared truth between a surface that publishes its token usage and the Controller that collects it.

Context.
The Captain asked, on 2026-10-21, for "all tokens used aggregated" and for "every token, every account, every surface".
The band the live board renders could not answer that, and the reason was structural rather than arithmetic: the usage ledger only ever read the Controller's own traces, and it presented itself as one surface while carrying another surface's rows inside it.
One account therefore stood in for two accounts, the Gemini provider had no usage source at all, and two surfaces were simply absent from the picture.

This file defines how a surface reports its own token usage, and what the Controller does with those reports.
The band document itself is owned by [`next-board-token-and-chat-contract.md`](next-board-token-and-chat-contract.md) (Contract A).
The fleet roster of surfaces is [`system-context/token-usage-surfaces.json`](system-context/token-usage-surfaces.json).

## 1. The rules that bind a publisher and the collector

1. **null != zero.** An unknown value stays `null` and is labelled.
   It is never summed, rendered or reported as `0`.
   A day with no measurement is *unmeasured*, not zero.
2. **One source per field.** Usage comes from the usage sources; quota comes from `quota-axi`.
   Neither re-reduces the other's counters.
3. **A surface reports only its own usage.** A publisher never publishes another surface's rows.
4. **A seed never moves.** An operator-reported number is dated to the day it was reported for and lands on no other day.
   It is labelled as reported, never as an instrumented measurement.
5. **Fail open, never fail silently.** A surface that cannot report yields unknown coverage plus the reason.
   The other surfaces' data is still emitted.
6. **Deterministic output.** Same inputs produce byte-identical JSON: sorted keys, sorted rows, no invented timestamps inside the data.

## 2. The collection mechanism: push

The Controller cannot read another surface's disk, and it must not reach into another surface's home.
So each surface publishes a usage document and the Controller collects it.
This is the same durable-file pattern the fleet already uses for cross-surface facts (`BRANDON-COMPUTE-COMMS/`), with one difference: the payload is machine-readable JSON, not prose.

The publishing half is [`bin/fm-token-usage-publish.py`](../bin/fm-token-usage-publish.py).
The collecting half is [`bin/fm-token-collect.py`](../bin/fm-token-collect.py), which reads the Controller's own ledger plus every published document it finds.

### 2.1 Where a surface puts the document

* A surface with a filesystem the Controller can read writes the document into the Controller's collection directory: `data/next-board-publish/surface-usage/<surface>.json`.
* A surface without one writes the document into its own comms outbox and the Controller is sent the collection request over the sanctioned comms route (`docs/COMMS-CONTRACT.md`).
  The file is the delivery; the notification is not.

A surface that cannot publish leaves nothing behind.
That absence is not a failure to be hidden: the collector records the surface as unknown coverage with the reason it reported nothing.

### 2.2 How a surface publishes

```sh
python3 bin/fm-token-usage-publish.py \
  --surface hd2stack \
  --host vmi3238503 \
  --label "HD2Stack" \
  --ledger data/tracker-tokens-20261019/ledger/usage.json \
  --out data/next-board-publish/surface-usage/hd2stack.json
```

`--rows` takes a file in the same day-and-row shape for a surface that has no tracker ledger of its own.
`--now` pins the clock so the output is byte-identical for identical inputs.
Without `--out` the document is printed to stdout.

The publisher computes each day's total from the rows it publishes.
It never reuses the source ledger's day total, because that total covers every surface the source held rows for, and reusing it would publish another surface's number as this surface's.

### 2.3 The document: `firstmate-surface-usage/v1`

```json
{
  "schema": "firstmate-surface-usage/v1",
  "surface": "hd2stack",
  "host": "vmi3238503",
  "label": "HD2Stack",
  "timezone": "Europe/London",
  "generated_at": "2026-10-21T12:00:00Z",
  "accounts": [
    {"id": "codex-local-unmapped", "label": "codex local (unmapped)",
     "provider": "codex", "identity_status": "unknown_local_subset"}
  ],
  "days": [
    {
      "date": "2026-10-19",
      "total_tokens": 239478662,
      "total_status": "measured",
      "expected_providers": ["codex", "glm"],
      "accounts": [
        {"account_id": "codex-local-unmapped", "provider": "codex",
         "surface": "hd2stack", "source_id": "vmi3196300:pi:codex",
         "source_kind": "local_metadata", "coverage": "local_metadata",
         "total_tokens": 230603813, "observed_at": "2026-10-19T22:49:20+01:00"}
      ]
    }
  ],
  "seeds": [
    {"account_id": "minimax-account-1", "provider": "minimax", "date": "2026-10-19",
     "source_id": "captain-20261019-minimax-1", "total_tokens": 281720000,
     "observed_at": "2026-10-19T07:32:35+01:00",
     "note": "operator-reported; dated; never re-applied as a future day"}
  ]
}
```

Field rules:

* `days[]` holds one entry per day the surface declared, including the days it carried no rows for.
  Such a day has `total_tokens: null` and `total_status: "unknown"`.
* `days[].accounts[]` holds the surface's own rows, with the provenance each row needs to be audited: which account, which provider, which source, whether the source was an instrument (`local_metadata`) or a person (`operator_reported`), and when it was observed.
* `total_status` is `"measured"` when the day's rows cover the expected providers and every reading is instrumented, `"partial"` when they do not, and `"unknown"` when there is no reading at all.
* `seeds[]` carries operator-reported numbers, each dated to the day it was reported for.

## 3. What the collector guarantees

* **One cell, one origin.** The same reading can reach the Controller twice: once in the Controller's own ledger and once in a surface's published document, under different source ids.
  Summing both would count one day's usage twice, so one account-day carries one origin: the surface's own published document wins, and the shadowed reading is reported in `ledger.conflicts` rather than dropped in silence.
* **Surface-qualified accounts.** Every account key is `<surface>|<account>`, so two surfaces holding the same local account name stay two accounts.
  This is the fix for the Captain's "we only see one codex, we have two".
* **Coverage from the totals.** The coverage slots and the totals are computed from the same rows, so the board's coverage line and its number cannot disagree.
* **Expected readings are declared, not guessed.** The roster names every coding surface and the providers each is expected to report.
  A surface that reported nothing is carried as unknown with the reason, so an absent surface is visible instead of quietly missing from the total.

## 4. What is still unknown, and why

Two kinds of unknown are carried, and they are different facts:

* **A surface that reported nothing.** Its reason is the absence of a usage source for that surface.
* **A provider this surface cannot measure.** Gemini/Antigravity is measured from the Antigravity brain transcript on the surface that runs it (section 4.2).
  A surface with no such transcript reports its agy slot as unknown, and the roster's `provider_notes` carries that standing reason, so the board says why rather than only that the number is missing.

Quota is a different field and stays where it belongs: `quota-axi` reports the Gemini windows, and the usage half of the band reports what each surface actually measured.

### 4.1 Account identity: the usage side and the quota side stay separate

The Captain ruled on 2026-10-22: keep them separate and keep them marked unknown.

The usage-side account ids and the quota-side account keys are different namespaces.
The usage side does not map onto `codex-home` or `openai-codex`, and it must not be made to.
`quota-axi` owns the quota keys; the usage ledger owns only what a surface measured locally.
A quota-side key must never be written into a usage row, and a usage-side account id must never be written into a quota record.
Every usage-side account that cannot be joined to a quota identity carries `identity_status: unknown_local_subset`, and it stays that way.
That status is visible rather than hidden, so a measured local subset is never read as a known account.
A local account id such as `codex-local-unmapped` names what was measured, not who paid for it.
Its label says the same thing in words, so a reader of the ledger sees `local (unmapped)` rather than a bare account name.
Joining a usage account to a quota identity later requires evidence, not similarity of name.
Until that evidence exists, the two sets are separate and unknown, and guessing between them is not the way to close the gap.

### 4.2 The Antigravity (Gemini) source

The band used to carry a standing reason that Gemini/Antigravity had **no local usage metadata surface anywhere in the fleet**, so `agy` was unknown on every surface.
That was wrong, and it was wrong because nobody looked at the data the surfaces already had.

Antigravity keeps one **canonical** transcript per brain session at `~/.gemini/antigravity-cli/brain/<id>/.system_generated/logs/transcript_full.jsonl`.
Each record carries `input_tokens`, `cache_read_tokens` and `output_tokens` numerically, plus `step_index`, `source`, `type` and `created_at`.

Three rules make the reading correct, and each one is a trap the naive scan falls into:

1. **Read the canonical transcript only.** The same events are kept again in `chunks/transcript/`, `chunks/transcript_full/` and `logs/transcript.jsonl`.
   Counting every file counts one event up to four times: the measured overcount on this fleet is **x2.97**.
   Measured on the Controller: 489 brain sessions carry a canonical transcript, and **zero** events exist outside it, so reading it alone loses nothing.
2. **The event identity is `(step_index, source, type, created_at)`.** The record carries no id of its own, so there is nothing else to dedup on.
3. **A day's total is `input_tokens + output_tokens + cache_read_tokens`.** The cache read is a real component of Antigravity's bill and is reported separately, so it is counted once and never added on top.

The provider is Antigravity itself, so it is `agy` — the id this roster already uses for Gemini/Antigravity.
A surface that runs no Antigravity has no agy source, and says so.

## 5. Adding a surface

Adding a surface is a deliberate operator action, exactly like adding one to the fleet roster.
Update [`system-context/token-usage-surfaces.json`](system-context/token-usage-surfaces.json) with the surface, its host, its aliases and the providers it is expected to report, and update the surface roster in `docs/SURFACE-TOPOLOGY.md` in the same change.

A surface id and an alias are the same thing to the collector: a source that reports `vmi3196300`, `crisp-r` or `controller` is attributed to the same surface.
That is why the Captain's own session name is an alias of the Controller surface and never a surface of its own: a second id for one host would double-count every row.
