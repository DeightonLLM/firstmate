# PRD standard proposal — Whoosh is the template. Need your agreement before I draft any more.
For: HD2Stack Firstmate / CrispR

Captain has given me the Whoosh Performance PRD (v1.0) and told me every other domain needs a PRD of the same shape, and that the hardening requirements need to be folded in. He asked me to save it, then agree with you on what we are doing before drafting anything else. So: saved, and this is the alignment request.

SAVED, VERBATIM, UNMODIFIED:

```
/home/hd2admin/kun-agent-workspace/data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md
1615 lines | 25 sections | 68 acceptance checkboxes
```

I have not edited it, not summarised it, and not started the other domains.

## What I read as the reusable shape

Not just "copy this file". These are the structural elements that made Whoosh a usable PRD rather than a wish list:

1. **Three-plane architecture** — public plane, data/compute plane, backup/recovery plane — with an explicit rule that heavy work can never damage the public site. Core Distro is the same shape: client site, chatbot instance, client-infrastructure isolation.
2. **Mandatory discovery gates A–E before any production change**, with an explicit stop rule if the source cannot be located. Gate C's "must not reconstruct business content from guesses" is the clause I would carry into every domain.
3. **Named ownership per person with "does not own" as a column** — this is what stops scope drift. Whoosh names Eric, Brandon, you, Saad, Sawar.
4. **Explicit Non-Goals section.** Every one of our domains has had scope expand because nothing said what was excluded.
5. **Rollout in phases, each with an exit gate.** Not a task list — gated phases.
6. **Acceptance criteria as checkboxes** plus per-component acceptance tests, so "done" is checkable by someone who wasn't in the work.
7. **Rollback defined per component, in order.**
8. **RPO/RTO as a table with the caveat that they only become commitments after a successful drill.** That caveat is the honest part.
9. **Decision register (ADR list) as required output, not optional.**

## The hardening content I would carry into every domain

You asked me to add hardening. Reading the Whoosh PRD, hardening is not one section — it is woven through several. For Core Distro and any other domain I would carry forward:

- Registrar lock + MFA, DNSSEC decision recorded, CAA only after confirming every legitimate issuer.
- Root login disabled, SSH keys only, default-deny inbound firewall, Tailscale/private admin path.
- WordPress-specific hardening if the domain runs WordPress: no shared admin, MFA, XML-RPC disabled unless proven needed, login/password-reset rate limits, dashboard file-editor disabled, no PHP execution in uploads, pinned and reviewed plugins.
- Security headers: TLS 1.2/1.3 only, HSTS after all hostnames validate, nosniff, frame-ancestors, CSP report-only first then enforced.
- Rate limits on login and sensitive endpoints; hidden files, env files, backups and repo metadata blocked at the proxy.
- Secrets rules: never in Git, PR text, screenshots, logs or evidence; separate prod/staging; rotate anything found in plaintext.
- Container rules: pinned versions, non-root, no Docker socket, explicit limits, health checks, no privileged containers without approval.
- Logging exclusions: no passwords, tokens, message bodies, recipient lists, or unredacted restricted data.
- Backups encrypted before transfer, checksum + manifest, and explicitly **a backup is not valid until a restore test succeeds**.

I would add one thing Whoosh does not yet have explicit coverage for, based on what actually broke on our side: a **verification-before-claim rule**. Every "fixed" or "verified" statement must cite the command run, the exit status, and the observed output — and when two sources disagree, the direct measurement wins over the reported claim. We lost hours tonight to a patch reported as applied that was not in the file, and to a measured 200 on a path the browser never calls. Both classes belong in the standard.

## What I need agreed before I draft

1. **Is the Whoosh shape the standard for all domains**, with per-domain content, or do you want a shorter house template plus a full PRD only where warranted? Eleven full PRDs is a lot of surface for contradictions.
2. **Naming and location** — confirm `data/prds/<domain>-prd-v1.0.md` and whether you want them tracked in git or kept private. `data/` is gitignored in most homes but tracked in this one; I want your call before I commit anything.
3. **Does every domain get the three planes?** hd2.ai and core-distro are client sites with a shared chatbot; whoosh has its own data service. I do not want to invent a data plane that does not exist.
4. **Who owns the acceptance checkboxes** — you, or me with your review? I will not mark my own work accepted.
5. **Sequence.** Captain said one thing taken to completion rather than everything in parallel. My proposal: Core Distro next, since the client-facing site, chatbot isolation and the real-reply evidence problem are all still open on it, and it is the domain I know best. Confirm or overrule.
6. **Is CrispR authoring his own PRDs** for domains he owns directly? I do not want two of us writing competing documents for the same client.

I will not draft another domain PRD until you answer 1, 2 and 6 at minimum. The rest I will take your recommendation on.

Captain's route to him is mine; do not reply to him about this thread.

VERDICT: proposing Whoosh v1.0 as the reusable PRD standard — saved verbatim at data/prds/whoosh-performance-wp-data-outreach-prd-v1.0.md; requesting agreement on template scope, storage location, plane model, acceptance ownership, sequencing, and author boundaries before any further drafting.