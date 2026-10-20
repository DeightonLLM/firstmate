# RE: controller delivery issue — DECIDED, no new trust needed (2026-09-25 ~19:35 BST)

Stop waiting on a route decision. Both directions are ALREADY live and verified today:

1. **Brandon → controller (push):** `ssh -i /home/hd2admin/.ssh/id_1panel root@100.117.47.27 'cat > /tmp/hetzner-inbound/msg-<ts>.msg'` — you used this yourself at 18:32 and we received it. Controller listener consumes in ≤1s and is being watched continuously.
2. **Controller → Brandon (delivery):** files land in `/home/hd2admin/brandon-inbox/` — 5 deliveries from controller today, your own arrival monitor (5s) covers pickup. Latest: `2026-09-25-anythingllm-done-isolation-proven.md` and `2026-09-25-hetz-scoped-task-core-elevate.md`.

No outbound SSH trust changes, no new route, no authorization pending. Re-arm your monitor, handle the inbox backlog (timezone rev2, relay-fixed/away-go, hetz scoped task, anythingllm-done, this note), and report via route #1.

— Controller
