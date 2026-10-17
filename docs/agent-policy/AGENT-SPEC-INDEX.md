# Agent spec index — the one list you read before acting

Status: ACTIVE. Every agent on every surface starts here, whatever harness, model or host.
If a rule you are about to break is not listed here, you do not have it — ask rather than
assume. If a rule you are following is stale, say so rather than defending it.

Read it once. Do not re-read it every turn. It is deliberately short and points at the
owning document for anything longer.

## The seven contracts that are always in force

| Contract | Owning file | One-line rule |
|---|---|---|
| Surface identity | `/root/docs/agent-policy/SURFACE-IDENTITY.md` | Identity comes from SSH config, then Herdr's machine list, then the dispatch manifest. Never from the access inventory. A PATH-only miss is **not** proof of absence. |
| Herdr payload | `/root/docs/agent-policy/HERDR-PAYLOAD-CONTRACT.md` | Measure a field live before writing a gate that reads it. Model identity comes from foreground `argv`, not from a pane label. |
| To-Do style | `/root/docs/agent-policy/AGENT-TODO-PROMPT-STYLE.md` | Visible native To-Do list, ≥5 items, real dependency chain, exactly one in progress, with the required `[harness·model effort @Host]` prefix. Filesystem trackers are forbidden. |
| Escape control | `/root/docs/agent-policy/OPERATOR-ESCAPE-CONTROL.md` | ESC belongs to the operator. Never send it to a live agent, never use it as a probe. |
| Model routing | `/root/docs/agent-policy/HERDR_AGENT_ROUTING.md` | Route by the model visible in the live pane, not by client name or workspace label. |
| Bounded execution | `/root/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md` | Attempt, retry and no-progress limits; stop with a named classification instead of repeating unchanged work. |
| Domain routing | `/root/agent-work/warehouse/routing/DOMAIN-ROUTING.md` | Never infer an owner from a domain name, hostname, folder or label. `hetzner-compute` is compute-only. |

## Where work comes from, and where it goes

- **Tickets arrive here:** `/root/agent-work/deightonllm-firstmate/INBOX/`. Any channel, one
  inbox. Nothing is dropped; malformed input is reported, never discarded.
- **The dashboard is the queue:** `data/campaign-dashboard-20261015/board.md` (authoritative)
  and `board.html` (local view).
- **The operating model:** `/root/agent-work/deightonllm-firstmate/PLAN.md`.
- **Credentials and hosts:** `/root/agent-work/warehouse/access/SAAS_ACCESS_INVENTORY.md` —
  read it before any SaaS work; never ask the operator for a credential that is already listed.
- **Owner scope (authority):** `data/agent-scopes.tsv` on Hetz. Machine-readable. The gate
  enforces it; prose never overrides it.

## Facts that are true right now (2026-10-15)

- **Primary parallel surface is Hetz** (brandon-compute), roughly six agents per provider.
  MiniMax for implementation, Luna 6 for review/security. Rate limits are per minute:
  stagger launches, never burst. Gemini on HD2 is for Gemini-specific work.
- **KVM1 is the HD2 main WordPress site** — an HD2 surface, not a separate one, and it holds
  **no client files**. Never route client work to it or cite it as a client-files host.
- **`srv1137994` / `elevatesci-vps` is a HARD GATE.** Never touched, probed or routed to.
  The former "Aminolifesciences" company is **folded** — that name is retired in current docs;
  historical evidence filenames keep it because they are records. Elevate does not supersede it.
- **Instant Controller↔Hetz notification is live** (file first, then guarded notify, defer
  while busy, dedupe by content hash). The 5-minute catch is the only fallback.
- **Three retained Core branches are held** pending the Captain's named merge approval.

## The failures we are actually fixing

- Treating one convenient signal as the whole state. A status line, a pane label, a commit
  count, a directory listing or a backlog row is a clue, never proof. Check the machine.
- Reporting work as done because it was **sent**, **delivered**, or **claimed**. Delivery,
  reading, acceptance and activation are four separate facts.
- Fixing a guard by weakening it. When a guard blocks legitimate work, repair the guard's
  evidence source and keep the check.
- Letting a failure be swallowed while success is still reported. That bug is exactly why an
  agent believed it had been answered.

## Never, without the operator's explicit word

Spend. Registrar or DNS. Credentials or key transfer. Live production change. The
Aminolifesciences archive. Merges. Destructive or irreversible action. Fabricated or padded
work to fill capacity.