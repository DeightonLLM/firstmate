# Hetz: Controller's gate work and where Hetz stands

**Date:** 2026-10-15
**Purpose:** state plainly what Controller is gating, what he is not, and how Hetz will operate against it.
**No decision requested.** Written so the alignment is durable rather than something I re-derive each turn.

## What Controller gates

Observed directly across the 2026-10-14 and 2026-10-15 replies, not inferred:

| Gate | What it means in practice |
|---|---|
| **Warehouse** | Controller owns it. Hetz does not write to the canonical warehouse or its mirror. Hetz submits named Markdown through its outbox with source paths, revision, test evidence and intended destination. Controller reviews and mirrors accepted material. |
| **Credentials and host access** | `ssh elevatesVPS` is Controller-side. No key transfer is authorized or underway. Hetz will not guess a username, key or alias. |
| **Production mutation** | Staging-only publication authorization is retained, bounded by tested-artifact integrity and safe backup/restore validation. It is explicitly not authority over live core-distro.com, elevatesci.com, DNS, registrar, billing or credential stores. |
| **Artifact acceptance** | Revision `50ae6849c190` is acknowledged *as reported*, not independently accepted. Hetz's 19/19 is a self-report. |
| **Implementation ownership** | Hetz must not spawn duplicate owners for `provider-cap` or `--worklocation` while their owners exist. |
| **Permission widening** | No blanket bash allowance or sandbox bypass is granted. Each denial needs an exact command, error, policy owner, source location and test entry point. |

## What Controller is not doing

- He is not sending private keys, creating credentials, or supplying a username.
- He is not deploying Core staging. The target still returned 500 at last observation.
- He is not granting production mutation authority.
- He is not treating his own MiniMax `models.json` repair as proof Hetz's restrictions changed.

## What Controller has corrected me on

Recorded because each is a real error, not a formality:

1. **"Single cause" framing.** I claimed one root cause unified every blocker. He refused it. Different
   blockers have different owners. He requires them listed individually.
2. **Host identity.** I compared a DNS answer against a Tailscale address and reported two hosts. They are
   the same machine, `srv1137994.hstgr.cloud`. Different address families, same host.
3. **Evidence lagging reality.** My canary report described the poll as fixed while omitting the outbound
   ledger change that the canary itself had exposed. He asked for follow-up evidence rather than accepting it.

## The distinction he keeps enforcing

**Receipt ≠ acknowledgment ≠ acceptance.** Three separate facts.

- He *receiving* a file proves transfer.
- He *acknowledging* proves he read it.
- He *accepting* is a separate judgement he makes, and may withhold.

Hetz has been treating receipt as progress. That is wrong and it inflated several status reports tonight.

## Where Hetz stands

**Owns:** Brandon/client work, on Hetz runtime credentials, with its own isolation and evidence discipline.

**Does not own:** the warehouse, staging deployment, live core-distro.com, elevatesci.com, DNS, credential
issuance, or merge approval for the preserved Core branches.

**Operating rules Hetz accepts going forward:**

1. Nothing is claimed done without evidence that it landed. `ready in branch` is not delivery.
2. File existence is never proof. Load the page, run the test, read the log.
3. Blockers are listed individually, each with its own owner and its own next step.
4. Local reports stay outside the warehouse; intended destination goes in the outbox.
5. Outbound messages go through `bin/fm-outbound.sh`, so Brandon's own mail is never mistaken for a reply.
6. No duplicate implementation owners. Report the existing owner's state instead.
7. Nothing is deleted, discarded, force-overwritten or reset without explicit authority.
8. When a check fails, report the refusal and stop. Do not improvise around a gate.
9. Hetz does not ask the Captain for facts already answered upstream.

## Where Hetz is behind

Stated plainly rather than buried:

- Two Core branches remain unlanded. Kept per instruction; **merge approval has not been given and is not
  assumed.**
- The staging artifact is a theme only. No database/page/menu state, chatbot inactive, no target
  backup/restore exercised.
- Worker execution denials are unresolved and no blanket permission is requested. Each is documented with
  its exact denial, owner, source and test entry.
- Five domain experts reportedly cannot read their own files. **Unverified** — I withdrew the single-cause
  claim and have not re-investigated.

## One correction owed back to Controller

His reply says the canary report "does not yet include the outbound hash-ledger change." True, and that
follow-up evidence is being sent separately. It covers `bin/fm-outbound.sh`,
`state/.controller-inbox-outbound`, the 38 pre-marked outbound files, and the re-proof that outbound no
longer self-triggers the poll while genuine Controller mail still surfaces.