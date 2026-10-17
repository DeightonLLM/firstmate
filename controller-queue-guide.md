# Your Link to the Controller — Queue Listener

> This is written from YOUR perspective (Hetzner agent side).

## What exists right now

The controller has a dedicated "HETZ LISTENER" tab with a live pane watching
for your messages. When you send something, it appears instantly in that pane.
The controller sees it and reacts without you needing to wait or ask.

## What YOU need to do to send a message

### Fastest (instant, no SSH needed if you have local FIFO access)

If you can write to the controller's local FIFO directly:

```bash
cat > /tmp/hetzner-to-controller.queue << 'EOF'
[YOUR MESSAGE HERE]
EOF
```

This appears in the listener pane immediately — no delay.

### Via Contabo mirror (recommended from Hetzner)

The Contabo machine (`hd2stack`) mirrors the queue directory. Write a `.msg`
file there and the controller picks it up within 30 seconds:

```bash
ssh hd2stack "cat > /opt/overnight-mirror/queue/hetzner-$(date +%H%M%S).msg" << 'EOF'
[YOUR MESSAGE — can be multiple lines]

Include what you need:
- task status (done / blocked / working)
- what you need from the controller or captain
- any permission wall you hit
- what you just completed
EOF
```

### Via direct scp to controller (if Contabo is slow)

```bash
scp /path/to/message.txt root@100.106.6.22:/tmp/hetzner-to-controller.queue
```

## What to send — practical examples

**When you complete something:**
```
done: staging CSS rollout complete, staging.core-distro.com verified ✅
```

**When you're blocked:**
```
blocked: cannot reach animovps Tailscale — need controller to check
```

**When you need a decision:**
```
need-decision: staging build has prerender crash on /blog route
Options: (A) fix the route (B) exclude from export (C) skip staging verify
Please advise.
```

**When you need the controller to know something:**
```
info: AnythingLLM runtime is read-only as agreed
info: staging deploy path is zip → cPanel on animovps
```

## What the controller does when they see your message

The controller:
1. Reads your message from the listener pane
2. Acts on it — dispatches work, checks status, updates artifacts
3. Sends a reply back to you via the workspace file `controller-reply.md`
4. Or pings you on the listener queue if urgent

Check `controller-reply.md` in your workspace after sending a message.

## What NOT to send

- Secrets, credentials, API keys
- Production deployment commands (those are always captain-gated)
- Anything that changes the live client application without explicit approval

## Always-on rule

The listener pane is persistent. You can send at any time — don't wait for
the controller to ask. If you're blocked for more than a few minutes, send
a message. If you complete something, send a message. The controller is
watching.

## Quick reference (bookmark this)

| Need | Action |
|------|--------|
| Report done | Write to Contabo queue `.msg` file |
| Report blocked | Write to Contabo queue `.msg` file |
| Need decision | Write to Contabo queue `.msg` file |
| Check reply | Read `controller-reply.md` in workspace |
| Urgent | Write to local FIFO if you have access |

## File locations (your side)

- Your workspace: `~/kun-agent-workspace/`
- Info packet: `~/kun-agent-workspace/hetzner-info-packet.md`
- Controller reply: `~/kun-agent-workspace/controller-reply.md`
- Queue on Contabo: `hd2stack:/opt/overnight-mirror/queue/`
- Local FIFO (controller side): `root@100.106.6.22:/tmp/hetzner-to-controller.queue`

Last updated: 2026-09-24 by controller (secondmate)
