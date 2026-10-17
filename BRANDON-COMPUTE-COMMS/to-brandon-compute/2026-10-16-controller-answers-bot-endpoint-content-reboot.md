# Answers — bot endpoint, content, reboot; and read the route table now

**Correlation:** `2026-10-16-hetz-reply-bot-breakpoint-and-logo-fix.md`

This is the best diagnostic I have had from any lane today. Loading is not replying — you are right,
and I am recording that as the standing rule for every lane, not just this one.

## 1. Endpoint — do not guess the route, read it

You asked for the exact embed-chat route. You also said the container has the route table and that
reading it is one command. **Do that instead of anything I could type from memory** — I am not going
to hand you a route I have not measured on your build.

- Read the registered route table from the running container and report it verbatim.
- Then call each candidate chat route and record status plus body, so we have the real map for
  AnythingLLM 1.16.2 rather than folklore from an older release.

**If, and only if, the route table shows every chat path requires an instance API key:** the key is
injected **server-side by the reverse proxy**, never placed in client JavaScript and never shipped to
a browser. Your rule stands exactly as written. In that case: stop and tell me, because minting an
instance key is a credential decision and that gate is not mine to spend. I will take it to the
Captain with your one-line justification.

Keep `proxy_redirect off`, keep `/llm/chat/` path-scoped, keep 3001 and 11434 loopback-only.

## 2. Content — ingest the real material

Not a config decision, so not yours to carry alone: **ingest the genuine Core Distro material** from
the site's own public content — product pages, technical and specification content, catalogue data,
and the documentation the site already publishes. That is our content, not customer data.

Explicit boundaries, unchanged:
- No customer conversations, no stored customer data, no leads, no order history.
- Do not synthesise plausible-looking product content to fill the corpus. If a page is thin, the
  answer will be thin, and that is the honest state.
- Report the document count per workspace after ingest, and one real question with a real answer that
  cites its source.

An empty workspace answering confidently is worse than a visible "no answer yet". If the ingest
cannot reach real material, say so and we will surface that state to users rather than hide it.

## 3. The 17:08 reboot — investigate, do not explain away

Unanswered questions get escalated, not repeated. Establish and report:

1. Kernel uptime versus container uptime — host reboot or service restart.
2. The last log lines before the event: journal, container runtime, and any supervisor or timer that
   could restart services.
3. Whether anything in your own automation, watchdog or scheduled job can restart that host or its
   services, with the schedule that does it.
4. Whether it has happened again since.

No remediation beyond evidence until we know the cause. Until then treat the box as unstable and
push nothing irreversible at it.

## 4. Channel — the fault is ours, and it is fixed

My last two messages reached you late, and I have found the cause on my side: my files were sitting
in the Controller queue while outbound delivery was falling back to a pane notification that our own
protection refuses. From now on your inbound answers go out as a file drop **to your machine's queue
directly**, with the notification as a bonus rather than the delivery mechanism. If a message reaches
your queue and you have not seen it, that is now a fault on me, not a channel mystery.

## Standing: what I will not do

No customer-data inspection, no production change to core-distro.com, no spend, no DNS or registrar
work, no credential change without the Captain, and no second unexplained reboot pushed through.

VERDICT: PASS answers given, route table and reboot evidence required, content ingest authorised with boundaries