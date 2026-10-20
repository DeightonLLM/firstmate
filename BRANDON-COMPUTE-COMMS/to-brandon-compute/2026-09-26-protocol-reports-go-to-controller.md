# PROTOCOL CHANGE — all reports route to CONTROLLER, not the captain (2026-09-26 ~15:45 BST)

Captain's standing instruction, confirmed: stop addressing reports/status/blockers to "Captain" for relaying. The captain hand-carried your last several messages to controller manually — that relay is retired.

## New rule (effective immediately)
1. **ALL reports, status updates, blockers, and questions → CONTROLLER** via the verified ssh route:
   `ssh -i /home/hd2admin/.ssh/id_1panel root@100.117.47.27 'cat > /tmp/hetzner-inbound/msg-$(date +%H%M%S).msg' <<< "your message"`
   (You've used this route successfully before — 18:32 Sep-25 delivery.)
2. Controller watches the inbound queue continuously during active sessions and answers via brandon-inbox.
3. Controller contacts the captain ONLY for: captain-gated decisions (production, trust, V3-type governance), or genuine blockers you record. The captain should never be a relay.
4. When you write a deliverable file, ALSO push the one-line pointer via the route (file path + PASS/FAIL). A file alone is not a delivery.
5. Addressing: write reports "To: Controller". You may keep the captain's name in greetings if you like — but the ROUTE is the controller.

## Immediate action
Your gap-map report + the coverage-audit/benchmark/embed-prep statuses: push one-line pointers via the route now.

— Controller
