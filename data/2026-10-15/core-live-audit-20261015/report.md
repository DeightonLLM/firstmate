# Core / Elevate live-surface audit

**Measured:** 2026-10-15, approximately 17:49–17:50 UTC (HTTP `Date` headers and execution time). **Scope:** seven exact HTTPS roots requested. This was a live, read-only audit using GET requests only; no forms, authentication, deployment, DNS changes, or writes to any client/project were performed.

## Verdict

**VERDICT: 5 healthy, 2 broken, 0 unreachable.** “Healthy” here means an HTTP 2xx response with a normally validating certificate and a non-parked, non-error page. `whooshperformance.com` is **PARKED**. `staging.core-distro.com` is **ERRORING**: its TLS certificate is expired, and when certificate verification was bypassed solely to inspect the returned page, the origin returned HTTP 500. It is not classified as unreachable: the HTTPS endpoint accepted a connection and returned an HTTP response on the explicitly insecure diagnostic GET.

## Per-surface results

| Surface | Fresh GET status / remote IP | Actual title and observed content fingerprint | Server / generator evidence | Certificate | Classification |
|---|---|---|---|---|---|
| `https://core-distro.com` | `200`; `66.29.153.174` | `<title>Core Distro \| Pharmaceutical Supply Distribution</title>`. HTML prefix contains `/_next/static/css/...` and `/_next/static/chunks/app/page-...js`; this is a Next.js app, not WordPress. | `server: LiteSpeed`; no generator response header observed. | Valid on ordinary curl verification (`ssl_verify=0`); subject `CN = core-distro.com`; issued by Sectigo Public Server Authentication CA DV R36; leaf expiry `Dec 17 23:59:59 2026 GMT`. | HEALTHY |
| `https://elevatesci.com` | `200`; `2606:4700:3032::ac43:d673` (IPv6 remote peer returned by curl) | `<title>Elevate Life Sciences \| Research Peptides \| Elevate Life Sciences</title>`. HTML says “wholesale distributor of research-grade peptides and laboratory compounds”; meta generator is `HD2.ai - https://www.hd2.ai`. Plain HTML/CSS site; no WordPress or Next.js markers seen in the captured prefix. | `server: cloudflare`; no generator response header. HTML `<meta name="generator" content="HD2.ai - https://www.hd2.ai">`. | Valid on ordinary curl verification (`ssl_verify=0`); subject `CN = elevatesci.com`; issued by Google Trust Services, CN `WE1`; leaf expiry `Dec 10 20:27:48 2026 GMT`. | HEALTHY |
| `https://agents.elevatesci.com` | `200`; `2606:4700:3032::ac43:d673` | `<title >AnythingLLM \| Your personal LLM trained on anything</title>`. HTML references `https://anythingllm.com`, its promo image, and `/index.js`; observed AnythingLLM frontend. | `server: cloudflare`; `x-powered-by: Express`; no generator response header. | Valid on ordinary curl verification (`ssl_verify=0`); served certificate subject is `CN = elevatesci.com` (covers this host); issued by Google Trust Services, CN `WE1`; leaf expiry `Dec 10 20:27:48 2026 GMT`. | HEALTHY (HTTP/page responding; branded/product state is the observed AnythingLLM UI) |
| `https://cbd-data.com` | `200`; `68.65.123.217` | `<title>CBD-Data \| Automated B2B Lead Generation</title>`. Page HTML is a server-rendered business application; visible source includes `const stripe = null;` and inline UI styling. | `server: LiteSpeed`; `x-powered-by: PHP/8.2.34`; no generator response header observed. | Valid on ordinary curl verification (`ssl_verify=0`); subject `CN = cbd-data.com`; issued by Sectigo Public Server Authentication CA DV R36; leaf expiry `Nov 20 23:59:59 2026 GMT`. | HEALTHY |
| `https://whooshperformance.com` | `200`; `2.57.91.91` | `<title>Parked Domain name on Hostinger DNS system</title>`. Page contains `<meta name="robots" content="noindex, nofollow, noarchive, nosnippet">`; explicit Hostinger parked-domain page. | `server: hcdn`; no generator response header observed. | Valid on ordinary curl verification (`ssl_verify=0`); subject `CN = whooshperformance.com`; issued by Let's Encrypt, CN `YE2`; leaf expiry `Oct 23 20:05:19 2026 GMT`. | **PARKED / BROKEN** |
| `https://data.core-distro.com` | `200`; `66.29.153.174` | `<title>Core-Distro \| Automated B2B Lead Generation</title>`. Page describes a “Premium B2B data acquisition engine with verified emails, social profiles, and phone numbers”; app HTML comments mention tenant-driven `APP_NAME`, `APP_URL`, and `APP_OG_IMAGE`. | `server: LiteSpeed`; `x-powered-by: PHP/8.2.34`; no generator response header observed. | Valid on ordinary curl verification (`ssl_verify=0`); subject `CN = data.core-distro.com`; issued by Let's Encrypt, CN `YE1`; leaf expiry `Nov 17 00:57:25 2026 GMT`. | HEALTHY |
| `https://staging.core-distro.com` | **Verified curl:** status `000`, remote peer `45.90.220.156`, `ssl_verify=10`, exit 60; exact error: `curl: (60) SSL certificate problem: certificate has expired`. **Explicit `-k` diagnostic GET:** HTTP `500`, same remote IP. | In the explicitly insecure GET body, `<title>Core Distro \| Pharmaceutical Supply Distribution</title>` and `/_next/static/chunks/...` identify a Next.js app response. The response is an error, not a healthy staging page. | On insecure GET response: `server: nginx`; `x-powered-by: Next.js`; `X-Robots-Tag: noindex, nofollow`. | **Invalid/expired.** Served leaf subject `CN = staging.core-distro.com`, issuer Let's Encrypt, CN `YE2`; leaf expiry `Oct 14 22:31:17 2026 GMT`, before the audit. The verified curl failure confirms expiry. | **ERRORING / BROKEN** (reachable HTTP 500 only when TLS verification is bypassed) |

## Request/evidence details

The following command made a real GET to each named origin, followed redirects, captured response headers, and emitted curl’s status and actual connected remote peer. No DNS lookup or cached address was substituted for `remote_ip`.

```sh
for h in core-distro.com elevatesci.com agents.elevatesci.com cbd-data.com whooshperformance.com data.core-distro.com staging.core-distro.com; do
  curl -sS -L --max-time 25 -D - -o /dev/null \
    -w 'CURL_META status=%{http_code} remote_ip=%{remote_ip} remote_port=%{remote_port} url=%{url_effective} ssl_verify=%{ssl_verify_result}\\n' "https://$h"
done
```

Observed status/peer pairs in that run: `core-distro.com 200 / 66.29.153.174`; `elevatesci.com 200 / 2606:4700:3032::ac43:d673`; `agents.elevatesci.com 200 / 2606:4700:3032::ac43:d673`; `cbd-data.com 200 / 68.65.123.217`; `whooshperformance.com 200 / 2.57.91.91`; `data.core-distro.com 200 / 66.29.153.174`; staging emitted curl error 60 and `status=000 remote_ip=45.90.220.156 ... ssl_verify=10`.

The staging distinction was measured with a separate GET, bypassing certificate verification only to learn whether an HTTP server response existed:

```sh
curl -skS -L --max-time 25 -D - -o /dev/null \
  -w 'CURL_META status=%{http_code} remote_ip=%{remote_ip} remote_port=%{remote_port} url=%{url_effective} ssl_verify=%{ssl_verify_result}\\n' \
  https://staging.core-distro.com
```

Raw response: `HTTP/1.1 500 Internal Server Error`, `Server: nginx`, `X-Powered-By: Next.js`, followed by `CURL_META status=500 remote_ip=45.90.220.156 remote_port=443 ... ssl_verify=20`. The earlier, certificate-verifying request’s raw diagnostic was `curl: (60) SSL certificate problem: certificate has expired` and status `000`; therefore normal curl did not complete an HTTPS HTTP transaction.

The page titles were collected by fresh GETs (staging inspected with `-k` because ordinary verification rejects its expired certificate):

```sh
curl -skS -L --max-time 25 "https://$h" | grep -o -m1 -E '<title[^>]*>[^<]*</title>'
```

The returned title strings are transcribed in the table. Page identity fingerprints were taken from the raw HTML prefixes returned by GET, including Next.js chunk paths on core and staging, the Elevate `meta generator`, the AnythingLLM public meta tags, the CBD/data titles and PHP headers, and the literal Hostinger parked-domain title and `noindex` directive.

Leaf/chain certificate evidence was collected from a fresh TLS handshake accompanying a GET using curl’s `%{certs}` output:

```sh
curl -skS --max-time 20 -o /dev/null -w '%{certs}' "https://$h" \
  | grep -E '^(Subject:|Issuer:|Start date:|Expire date:)' | head -12
```

The verification result in the ordinary GET command was `0` for the six non-staging surfaces. Staging’s ordinary GET failed with curl exit 60; its cert dates and issuer were inspected separately with `-k`, which is why the report explicitly marks it invalid rather than treating the insecure diagnostic as certificate validation. The issuing CA reported in the table is the immediate issuer of each leaf certificate, not the root CA.

## Recommendation

Treat Whoosh as a parked domain rather than a functioning site. Treat staging as both TLS-expired and application-erroring (HTTP 500); its failure is not a connection refusal or an unreachable host. No remediation was performed or attempted. All five remaining surfaces returned HTTP 200 with normally validating TLS during this measurement window.

## Closeout limitation

The report contains no unresolved product or captain choice: its recommendations are observational and do not authorize remediation. I read the required `decision-hold-lifecycle` skill. Its completion procedure requires running the originating-home `bin/fm-decision-hold.sh complete --none` attestation when no unresolved decision exists. That would write the originating backlog/decision state, but this task explicitly forbids project writes and permits only this report and the prescribed status file. I therefore did not run that mutating command and cannot truthfully claim the shared completion gate passed. The evidence report is complete; supervisor closeout remains blocked on resolving this read-only-vs-attestation boundary.
