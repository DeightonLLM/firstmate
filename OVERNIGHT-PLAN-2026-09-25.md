# OVERNIGHT PLAN — 2026-09-25 (controller: vmi3196300 / 100.117.47.27)

Operator AFK/asleep. Controller coordinates; hetz away-plan executes brandon-side work.

## STATE AT HANDOFF (all verified on-box, not from docs)

- **Contabo relay: FIXED + VERIFIED.** Stale daemon (pre-07:27 script) killed; relaunched PID 1194719. E2E test message flowed hd2stack queue → brandon daemon → controller listener. Zero failures since restart. (Brandon clock ~2h behind controller UTC — use UTC in ledgers.)
- **Timezone convention (operator-set 2026-09-25, rev2):** ALL THREE hosts — controller, hd2stack, AND brandon — run **Europe/London (UK time, BST/GMT)**. NOT raw UTC, NOT Berlin, NOT US zones. Brandon switched via sudo at 18:30 UTC / 19:30 BST. Stamp filenames/ledgers/messages in UK time and label the zone, e.g. `2026-09-25T19:30+01:00 BST`.
- **Comms: two-way, file-based, verified.**
  - hetz→controller: `ssh -i ~/.ssh/id_1panel root@100.117.47.27 'cat > /tmp/hetzner-inbound/msg-<ts>.msg'` (controller listener consumes in ≤1s; log: state/hetzner-listener.log — being watched)
  - controller→hetz: `/home/hd2admin/brandon-inbox/` (reply sent: `2026-09-25-controller-relay-fixed-away-go.md`, daemon-logged 07:03)
- **All w2 panes SHUT** (incl. w2:p1E secondmate, w2:p15 captain's agent). Leave shut. No pane respawn without operator.
- **HD2Stack: NOT installed on brandon.** Only ollama :11434, ai-gateway :8080, llama-server :8081 (LFM2.5). Job spec folded into hetz away-plan.
- **warehouse-sync.sh: BUGFIXED** (pull dest `$TMP/` → `$TMP/docs/`; RED 09:04 fail → GREEN 09:05, 8 files → controller + hetz).

## ACTIVE: HETZ AWAY PLAN — GO (activated on operator delegation)

Terms accepted: authorized work only; MiniMax M2.7 default lane; hetz agent reviews; ≤25 workers; non-overlap (brandon-side = hetz, controller workspace = controller); llm.hd2.ai prod on vmi3238503 untouched; no captain panes; anything needing Dubz waits (no phone channel, no ETA).

Queue (independent, parallelizable):
1. **HD2Stack install on brandon** — AnythingLLM; primary LFM2.5 localhost:8081, MiniMax fallback; per warehouse `anythingllm/` contract (STACK-MAP, RAG-METADATA-CONTRACT, projection-manifest.yaml); report URL/port.
2. Hetz agent's own proposed jobs per its away instructions (authorized scope only).

## CONTROLLER LANES (mine, non-overlapping)

1. **Watch** `state/hetzner-listener.log` — answer hetz messages via brandon-inbox within bounded time.
2. **Warehouse sync cadence** — rerun `bash /root/bin/warehouse-sync.sh` after accepted warehouse writes.
3. **Relay health check** — if listener log shows fresh FAIL lines, re-verify hops 1/2 by hand before touching anything.
4. **Review** hetz away-plan outputs against warehouse contracts on delivery; corrections via brandon-inbox only.

## STOP CONDITIONS (hard)

- Any new authority boundary, credential handling, prod deployment, or destructive action → STOP, log, wait for operator.
- llm.hd2.ai / vmi3238503 AnythingLLM prod is read-only from here.
- No new panes (herdr/tmux) anywhere without explicit operator authorization.

## MORNING REPORT CHECKLIST (for Dubz)

- Relay uptime since 07:00 UTC-ctrl (expect zero FAIL lines post-restart)
- HD2Stack status: installed? URL/port? local-model primary verified?
- Hetz away-plan: jobs accepted/reviewed, evidence paths
- Warehouse sync: file counts, any divergences
- Anything that waited on the captain
