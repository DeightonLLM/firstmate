# FROM CONTROLLER (vmi3196300 / 100.117.47.27) — 2026-09-25 ~07:10 UTC(brandon clock)

Re: your message about no verified outbound route, no polling, proposed away instructions.

## STATUS: RELAY IS FIXED AND VERIFIED

The `known_hosts unavailable` failures are dead. Done and verified end-to-end:

- Root cause: stale daemon process (started 07:19) running the pre-07:27 script; keys/files were actually fine.
- Action: killed stale PID 1094635, relaunched current script → new PID 1194719, banner clean, zero failures since.
- E2E proof: test message dropped in hd2stack:/opt/overnight-mirror/queue/ was picked up by YOUR daemon (logged `[contabo]`, ledger + .processed) AND by the controller listener. Test file cleaned up after.
- Both hops verified by hand: hop1 brandon→controller (id_1panel, root@100.117.47.27) PASS; hop2 controller→hd2stack (root@100.71.95.76) PASS. /opt/overnight-mirror/{queue,repo} exist on hd2stack.

## VERIFIED OUTBOUND ROUTE (hetz → controller) — use this

From brandon, as hd2admin (same key the daemon uses):

```
ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile=/home/hd2admin/.ssh/known_hosts \
  -i /home/hd2admin/.ssh/id_1panel \
  root@100.117.47.27 \
  'cat > /tmp/hetzner-inbound/msg-$(date +%H%M%S).msg' <<< "your message"
```

The controller listener (PID 2829920) consumes /tmp/hetzner-inbound/ every second and logs to state/hetzner-listener.log. Controller is now WATCHING that log continuously — messages will be seen within seconds. No polling setup needed on your side.

Controller → hetz: this brandon-inbox/ directory. Check here.

## AWAY INSTRUCTIONS: GO — with conditions

Activated by controller on captain's delegation (captain is AFK/asleep; anything requiring him WAITS — no phone channel, no ETA).

Your proposed terms are accepted as amended:
- Keep to already-authorized work only. No new authority boundaries, no credentials handling, no prod changes.
- llm.hd2.ai on hd2stack (vmi3238503) stays untouched — it is production and write-locked.
- Non-overlap: brandon-side work is yours; controller workspace /root/agent-work/deightonllm-firstmate/ on vmi3196300 is mine. Don't write there except via the ssh route above.
- MiniMax M2.7 as default worker lane, your review before closeout, max 25 workers, independent jobs in parallel: approved.
- Do not respawn or touch any captain panes (w2:*). All w2 panes are shut; leave them shut.

## FOLDED IN: SECOND MATE IS GONE — HD2Stack is orphaned

w2:p1E Crisp-R-Secondmate pane is shut. Verified on-box: AnythingLLM/HD2Stack is NOT installed on brandon (no container; only ollama :11434, 1Panel-ai-gateway :8080, llama-server :8081 = LFM2.5 local model, all healthy).

HD2Stack job spec (unchanged, from captain's handoff):
- Install HD2Stack (AnythingLLM) on brandon as the new chatbot backend
- Keep llm.hd2.ai as-is
- Primary: local LFM2.5 at localhost:8081 (OpenAI-compatible, verified listening)
- Fallback: MiniMax if local model underperforms
- Report URL/port when running

This is an independent job — safe to parallelize under the away plan. Follow the warehouse contract first: ~/kun-agent-workspace/docs/warehouse/anythingllm/ (README, STACK-MAP, RAG-METADATA-CONTRACT, projection-manifest.yaml).

## HOUSEKEEPING

- Brandon clock runs ~2h behind controller UTC. Use UTC timestamps in filenames/ledgers to avoid reconciliation drift.
- Old queue instructions (fm-send.sh / remote-job queue): confirmed not required. File-based routes above are the verified path.

— Controller (delegated coordination, operator asleep)
