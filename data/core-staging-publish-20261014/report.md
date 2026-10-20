# Core staging hostname publication — access blocker

**Date:** 2026-10-14
**Scope:** Access preflight only. No host login, log inspection, backup, restore test, app/proxy/DNS/firewall/cPanel change, deployment, chatbot activation, or live-site probe was performed.

## Access evidence

- `getent ahostsv4 staging.core-distro.com` resolved the hostname to `45.90.220.156`.
- `curl --head --max-time 10 --silent --show-error --verbose https://staging.core-distro.com/` connected to `45.90.220.156:443`; TLS certificate validation succeeded for `staging.core-distro.com`.
- The response was `HTTP/1.1 500 Internal Server Error`, `Server: nginx`, `X-Powered-By: Next.js`, and `X-Robots-Tag: noindex, nofollow` (response time 2026-10-14 02:03:11 GMT).
- This proves the public HTTPS endpoint is reachable and currently identifies as nginx/Next.js. It does **not** establish administrative access to the host or prove the origin process behind nginx.
- No authorized SSH/console account or host-access route was provided. I did not guess a login, use another machine's credentials, or try an alternate host. Therefore the nginx-vhost and Node/Next.js logs cannot be read. The actual cause of the 500 is **unknown**; the response headers are not a diagnosis.

## Work not performed

Per the instruction to stop when host access is unavailable, no further diagnosis or replacement was attempted. No backup was made and no restore was tested, so there is no proven restore path. The WordPress port was not deployed to the hostname and the chatbot was not activated. `core-distro.com` and `elevatesci.com` were not contacted or changed; their current response/content was not verified. No DNS, proxy, firewall, or cPanel change was made. Any such change remains separately gated by the brief.

## Exact blocker / next authorized step

Provide an approved host-access route and least-privilege account for the staging host that actually serves the resolved hostname, without borrowing another host's credentials or widening privileges. Then capture the staging-vhost nginx error and Node/Next.js error output before deciding whether replacement is needed. If the hostname cannot be administered without a DNS/proxy/firewall/cPanel change, obtain the brief's separately required explicit authorization before making that change. After access and diagnosis, preserve and restore-test a backup before any deployment. Until then, the 500 cause, backup/restore readiness, WordPress publication, chatbot behavior, and live-site non-change verification remain unproven.

VERDICT: BLOCKED — staging HTTPS endpoint is reachable at 45.90.220.156 and returns nginx/Next.js HTTP 500, but no authorized host-level access was available to inspect logs; no backup, restore test, deployment, chatbot activation, or live-site verification was performed.
