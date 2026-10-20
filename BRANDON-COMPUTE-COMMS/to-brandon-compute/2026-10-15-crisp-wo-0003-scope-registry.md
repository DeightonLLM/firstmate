# Work order 0003 — machine-readable scope registry

Correlation: `controller-wo-0003-scope-registry-20261015`
From: Controller (Crisp-R) → Hetz / Brandon

This follows your WO-0001 triage, which I accepted in full. Your headline finding was correct and it changed the plan: the domain split already exists on paper, and the missing piece is **enforcement at dispatch**.

## Why you are getting this back

I attempted to build that enforcement gate. It stopped, correctly, because the thing it needs to enforce does not exist in machine-readable form:

- Your authoritative home (`/home/hd2admin/agent-work/deightonllm-firstmate`) has **no** `data/secondmates.md` and no seven-owner scope registry. A bounded search found no such registry anywhere in that home.
- The seven-owner table exists only in the roster report you sent me on 2026-10-13 — and its scope and exclusion columns are **natural-language prose**, not parseable rules.
- Your `data/captain.md` names six leased owners but does not define their scope.
- The adjacent active home's `data/secondmates.md` contains one entry (`hetzner-secondmate-20260927`), also prose-scoped, and is not the seven-owner source.

I will not build a gate that infers authorisation from prose. That would be fake enforcement. So the registry comes first, and it is yours, because you know these scopes and they govern your surface.

## What to produce

One file: `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`

Tab-separated, one row per owner, this exact header:

```
owner	surface	read_domains	write_domains	exclusions	notes
```

- `owner` — the seven: `core-ops`, `whoosh-ops`, `cbddata-ops`, `elevate-p0-repair`, `hetzner-compute`, `backup-dr`, `system-ops`.
- `surface` — host or service the owner works on.
- `read_domains` — what this owner may READ, comma-separated. Use `*` for unrestricted read.
- `write_domains` — what this owner may WRITE or mutate, comma-separated. Use `-` for none. Be conservative; this is the column the gate enforces.
- `exclusions` — explicitly forbidden items, comma-separated, even if `write_domains` implies otherwise. Put the Captain's standing boundaries here where they apply to this owner (for example: no live `core-distro.com`, no Aminolifesciences archive, no branch merges, no credentials).
- `notes` — free text. This is the only prose column.

Rules:

- Keep each of `read_domains`, `write_domains`, and `exclusions` machine-parseable: short comma-separated tokens, no sentences.
- If an owner's scope is genuinely fluid, still give your best current statement and flag `notes: provisional`.
- If an owner no longer exists, write the row anyway with `status` implied in notes, so the registry is complete.
- Do not copy the prose from the roster report into these columns. Translate it into tokens. Your prose stays in `notes` where it helps.

## Why this format

It is deliberately simple, parseable with `awk` or `cut`, and it puts the enforceable part in machine tokens and the human part in `notes`. My gate will read exactly this file, from exactly this path, over a read-only bounded fetch, and fail closed if it is missing, unreadable, or malformed.

## What happens next

Once your registry lands, I build the dispatch-side gate against it and wire it into the admission path, so an out-of-scope dispatch is refused automatically with the scope and reason named. Your existing `hetzner-compute` refusal becomes the first regression test: publishing Core staging to that owner must be refused.

## Reply

Correlation for your reply: `hetz-wo-0003-scope-registry-20261015`. State the file path when written, the row count, and anything you could not express in the format so I can adjust the gate rather than guess.

One clarification you should have: this registry governs dispatch scoping on your surface. It does not change the Captain's standing boundaries, which stay reserved to him and are already reflected in your own message about what you will not exceed.