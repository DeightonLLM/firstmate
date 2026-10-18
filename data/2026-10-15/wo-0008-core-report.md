# WO-0008 lane 4 — CORE-DISTRO staging blockers and ticket 0017

## Ticket 0017 — artifact checksum result

Command run against the exact requested on-disk directory:

```text
cd /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact && sha256sum -c SHA256SUMS
```

Verbatim output:

```text
core-distro-astra-child/assets/about-pharma-v3.webp: OK
core-distro-astra-child/assets/automation-machine-v2.webp: OK
core-distro-astra-child/assets/compliance-quality-v2.webp: OK
core-distro-astra-child/assets/core-distro-logo.webp: OK
core-distro-astra-child/assets/favicon.ico: OK
core-distro-astra-child/assets/hero-lab-v2.webp: OK
core-distro-astra-child/assets/site.css: OK
core-distro-astra-child/assets/stage-compat.css: OK
core-distro-astra-child/assets/stage-interactions.js: OK
core-distro-astra-child/assets/vials-packaging-v2.webp: OK
core-distro-astra-child/astra-tokens.css: OK
core-distro-astra-child/front-page.php: OK
core-distro-astra-child/functions.php: OK
core-distro-astra-child/page.php: OK
core-distro-astra-child/partials/cd-page-footer.php: OK
core-distro-astra-child/partials/cd-page-header.php: OK
core-distro-astra-child/public-homepage-body.html: OK
core-distro-astra-child/stage-content-fixes.php: OK
core-distro-astra-child/style.css: OK
```

**Counts: 19 OK, 0 FAILED.** This verifies each current file matches the digest in the colocated `SHA256SUMS`; it does not prove those bytes are identical to the artifact previously reported as revision `50ae6849c190`. That limitation is still true, so ticket 0017 remains **NOT ACCEPTED** on identity. The manifest is generated from these same files and is not an independent historical reference.

Identity would require a trustworthy prior byte-level reference, such as a previously recorded/signed manifest whose digest is independently tied to revision `50ae6849c190`, an authoritative Git tree/commit object for the exact artifact, or a content-addressed/archive copy with independently recorded hashes. Comparing against a freshly generated manifest alone cannot establish historical identity.

## Scope and evidence limits

- The requested artifact was read and checksummed. No staging host was contacted or inferred; **staging host: UNKNOWN**.
- The task's current-state input reports an expired certificate, HTTP 500 behind TLS, and an inactive chatbot. These were not independently re-probed in this lane because the serving host is unresolved. The local outage note `docs/CORE-DISTRO-SSL-OUTAGE-20260928.md` contains older observations from 2026-09-28 (including a then-valid certificate and healthy origin); it is stale relative to the current task input and is not evidence of today's live state.
- No DNS, registrar, credential, deployment, production, service, or application writes were made. No retained-branch merges were started.

## Blockers

| Blocker | Evidence | Dependency | What unblocks it |
|---|---|---|---|
| Staging-serving host/instance is unresolved | No authoritative host identifier or mapping was supplied for this lane. Historical names, DNS, PTR, and aliases are explicitly not valid evidence for resolving it. | Blocks every host-specific read, certificate inspection, service diagnosis, and recovery step. | An authoritative current control-plane/inventory record identifying the exact staging host and application instance, plus an operator-confirmed read-only access path. Until then it remains UNKNOWN. |
| Certificate expired | Current task input reports expiry; not independently measured here because target host is unknown. | Exact host/vhost and served certificate chain must be identified before renewal or deployment can even be planned. | After host identity is established: read-only capture of served chain, SAN/expiry, vhost binding, and renewal ownership. Actual issuance/install/reload requires separate authorization; this lane made no such change. |
| HTTP 500 behind TLS | Current task input reports HTTP 500; no response or server-side evidence was captured in this lane. | Exact host and application instance; then correlate request/path/time with application and web-server logs. | Host identity and authorized read-only diagnostics that locate the failing component and establish a reproducible health check. Any service/app change requires separate authorization. |
| Chatbot inactive | Current task input reports the chatbot inactive; no independent process/health evidence was collected because the host is unknown. | Host/app identity and the HTTP 500 diagnosis; availability cannot be restored or validated before identifying the failing component. | Host identity, read-only runtime/health evidence, and an authorized recovery plan. Validate an application-level chat response after any separately authorized fix. |
| Ticket 0017 artifact identity unproven | The exact on-disk checksum check passed 19/19 against its colocated manifest, but no independent prior hash/tree/archive reference was available in the evidence inspected. | Independent reference must bind the prior artifact bytes to `50ae6849c190`. | Supply or locate a trustworthy pre-existing signature/hash record, authoritative commit/tree, or independently hashed archive tied to that revision; then compare all files. |

## Dependency-first recovery order

1. **Resolve host identity from an authoritative current source.** Keep it UNKNOWN until that evidence is supplied; do not use DNS, PTR, or aliases. Also establish the exact app/vhost instance and permitted read-only access path.
2. **Collect read-only baseline evidence on that exact instance.** Capture the served certificate chain and vhost mapping, the HTTP 500 response details, relevant app/web-server logs, and chatbot process/health state. This distinguishes transport/certificate trouble from the backend failure.
3. **Diagnose the HTTP 500 and inactive chatbot from correlated evidence.** Determine whether they share a cause and define a non-production-impacting recovery plan. No repair is authorized by this report.
4. **Only after separate authorization, recover certificate and application/service in their evidenced dependency order.** Re-check TLS and HTTP response, then perform an application-level chatbot health/conversation check. This lane did not perform or authorize those writes.
5. **Resolve ticket 0017 independently using a trusted historical identity reference.** Re-compare the artifact against it; the current checksum success alone does not close the identity finding.

## VERDICT

**VERDICT: The staging blocker list and dependency order are reachable as a bounded evidence report, and the artifact self-check is reachable (19/19 OK); staging recovery and acceptance of ticket 0017's historical byte identity are NOT reachable today. The serving host remains UNKNOWN.**
