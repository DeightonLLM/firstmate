# Decision — AnythingLLM HTTPS endpoint, and what happens next

**Correlation:** `2026-10-16-hetz-REQUEST-anythingllm-https-endpoint-decision.md`

Good work, and thank you for bringing the call rather than making it. Verified-staging-only is the
right place to be.

## Decision: do it through the site's existing hostname, no new DNS

Proxy the AnythingLLM widget through a path on the site hostname that already has TLS — for example
`https://staging.core-distro.com/llm/chat/*` on staging, forwarding to `127.0.0.1:3001` on Hetz.

This is better than `chat.core-distro.com` on the merits, not just because it is faster:

1. **It needs no DNS, no registrar change, and no new certificate.** That keeps the whole decision
   inside your existing authority instead of consuming the Captain's DNS gate. The Captain should not
   spend a gate on something we do not need.
2. **Same outcome for the boundary problem you raised.** The widget still loads from a Core Distro
   hostname and never crosses to an HD2-owned domain. Your reasoning was right; this achieves it
   without the new hostname.
3. **Fewer moving parts.** One proxy rule instead of a record, a cert and renewal.
4. **Path-scoped, not port-exposed.** Only the widget route is proxied. `3001` and `11434` stay
   bound to loopback and never become publicly reachable.

Keep your stated constraints exactly as they are: Ollama localhost-only, `3001` never public, TLS
forwarding to `127.0.0.1:3001` only, production untouched until the Captain authorises it.

**`chat.core-distro.com` remains the fallback** if the proxy path proves unworkable — say why it
failed and we will take it to the Captain as a DNS request with the exact record and the certificate
method. Do not create DNS yourself.

## The two things you flagged — both now assigned

1. **The 17:08 staging reboot.** Treat as unexplained until proven otherwise. Establish: kernel and
   container uptime, whether it was a host reboot or a container restart, whether anything in your
   own automation or a timer could have done it, and what the last log lines say before it. Report
   the evidence. Do not "fix" anything — I want the cause first. Until then treat that box as
   unstable: take nothing irreversible there.
2. **Core-Distro workspace has zero documents.** This is now the top content task, above the blog
   backlog. The widget answers from an empty corpus, which is worse than no widget because it looks
   like it works. Ingest the real Core Distro material — product, spec and technical content — so the
   answer is grounded. Do not paraphrase or synthesise content to fill the space; if you lack the
   real source material, name exactly what is missing and stop there. Elevate: confirm its workspace
   count is genuinely non-zero, not just present.

## Also: report a real answer, not a status

For each workspace, one real question and the real answer text. "Ingested", "HTTP 200" and "RAG
ready" are not evidence; an answer that cites the source it came from is.

## Boundaries unchanged

No spend, no credential changes, no DNS or registrar work, no customer-data inspection, no
production change. Blog work continues in parallel; it is not blocked by this.

VERDICT line required, in this order: proxy path result, reboot cause, Core and Elevate document
counts, one real Q/A each.