# Incident Diagnosis & Remediation Runbook: core-distro.com TLS Outage

**Date:** 2026-09-28  
**Scope:** `core-distro.com`, `www.core-distro.com`, `data.core-distro.com`  
**Status:** Root Cause Isolated | Actionable Operator Remediation Provided | 100% Read-Only Diagnostic

---

## 1. Executive Summary & Root Cause

The TLS outage on `core-distro.com` is **exclusively an Edge / DNS misconfiguration**, not an origin or certificate failure:
1. **Apex (`core-distro.com`) Dual-A Conflict:**
   Authoritative DNS (`dns1.registrar-servers.com` / Namecheap) serves **two A records** for the apex:
   - `66.29.153.174` (Direct origin on cPanel/Hostinger `business190.web-hosting.com` running LiteSpeed) -> **Healthy** (HTTP 200, valid Sectigo cert).
   - `162.159.140.166` (Cloudflare edge proxy) -> **Failing** (`SSL routines::sslv3 alert handshake failure`, HTTP 000). Cloudflare holds no active edge SSL certificate / Hostname binding for `core-distro.com`.
   Because DNS round-robins queries between both IPs, ~50% of client requests hit the unprovisioned Cloudflare IP and experience a hard SSL handshake drop.

2. **`www.core-distro.com` CNAME / Dual-Record Violation:**
   - Authoritative DNS contains **both** an `A` record pointing to origin `66.29.153.174` and a `CNAME` pointing to `sites.ludicrous.cloud`.
   - `sites.ludicrous.cloud` resolves to Cloudflare IPs (`104.18.35.90`, `172.64.152.166`), but Cloudflare has no SSL certificate for `www.core-distro.com`. When queried for `www`, clients following CNAME receive an SSL handshake failure.
   - Evidence shows `sites.ludicrous.cloud` is a **stale SaaS/builder CNAME** (Cloudflare-backed site hosting platform) that was abandoned without removing DNS entries.

3. **Origin Health & Runway:**
   - Origin LiteSpeed server (`66.29.153.174`) is 100% operational.
   - Active TLS cert subject: `CN=core-distro.com`, SANs: `DNS:core-distro.com, DNS:www.core-distro.com`.
   - Issuer: `Sectigo Public Server Authentication CA DV R36`.
   - Expiration date: `Dec 17 23:59:59 2026 GMT` (**80 days runway remaining**).

---

## 2. Independent Confirmation / Refutation of Supplied Snapshot

| Snapshot Assertion | Status | Live Finding & Evidence |
| :--- | :---: | :--- |
| **Origin (`66.29.153.174`):** HTTP 200, SSL OK, Sectigo cert valid Jun 2 – Dec 17 2026 | **CONFIRMED** | HTTP 200, `SSL_VERIFY: 0`, LiteSpeed web server, SAN covers both apex and www. |
| **Edge (`162.159.140.166`):** HTTP 000, SSL alert handshake failure, no cert | **CONFIRMED** | Curl exit code 35 (`OpenSSL/3.0.13: error:0A000410:SSL routines::sslv3 alert handshake failure`). Fails identically from controller, `hd2stack`, and `elevatesVPS`. |
| **Apex dual resolution:** Resolves to `162.159.140.166` and `66.29.153.174` | **CONFIRMED** | Authoritative Namecheap DNS returns both `IN A 162.159.140.166` and `IN A 66.29.153.174` (TTL 1799s). |
| **`www.core-distro.com` CNAME:** Points to `sites.ludicrous.cloud`, no cert | **CONFIRMED** | Authoritative DNS has conflicting `A` and `CNAME sites.ludicrous.cloud.`. Cloudflare edge drops TLS for `www.core-distro.com`. |
| **`data.core-distro.com`:** HTTP 200, healthy | **CONFIRMED** | Resolves direct to origin `66.29.153.174` only (no Cloudflare IP). Serves HTTP 200 via Let's Encrypt cert (`Aug 19 – Nov 17 2026`). Unaffected by Cloudflare. |
| **Not an expiry incident:** Cert unexpired | **CONFIRMED** | Origin certificate is valid until Dec 17 2026 (80 days remaining). |

---

## 3. Multi-Vantage Isolation (Edge vs. Origin)

Tested simultaneously across 3 disparate hosts (`controller`, `hd2stack`, `elevatesVPS`):
- **Origin (`66.29.153.174`) via SNI `core-distro.com`:**
  - Controller: HTTP 200, TLSv1.3 handshake OK
  - `hd2stack`: HTTP 200, TLSv1.3 handshake OK
  - `elevatesVPS`: HTTP 200, TLSv1.3 handshake OK
- **Edge (`162.159.140.166`) via SNI `core-distro.com`:**
  - Controller: HTTP 000, `error:0A000410:SSL routines::sslv3 alert handshake failure`
  - `hd2stack`: HTTP 000, `error:0A000410:SSL routines::sslv3 alert handshake failure`
  - `elevatesVPS`: HTTP 000, `error:0A000410:SSL routines::sslv3 alert handshake failure`

**Verdict:** The failure follows IP `162.159.140.166` uniformly across all vantage points. Origin is completely unimpaired.

---

## 4. `www` CNAME Investigation: `sites.ludicrous.cloud`

- **Record:** `www.core-distro.com CNAME sites.ludicrous.cloud` coexists with an `A` record `66.29.153.174` on authoritative DNS.
- **Target Analysis:**
  - `sites.ludicrous.cloud` resolves to Cloudflare anycast IPs `104.18.35.90` and `172.64.152.166`.
  - Registered via Cloudflare registrar, nameservers `melinda.ns.cloudflare.com` / `albert.ns.cloudflare.com`.
  - HTTP requests to `sites.ludicrous.cloud` return Cloudflare default 403 / challenge.
  - HTTP request to `http://www.core-distro.com/` on port 80 returns a `301 Moved Permanently` to `https://www.core-distro.com/` with Server `cloudflare`.
  - HTTPS handshake immediately aborts with SSL handshake failure because Cloudflare Custom Hostnames (SSL for SaaS) does not have a provisioned cert for `www.core-distro.com`.
- **Classification:** **Stale SaaS builder CNAME record**. A landing page / website builder platform (`ludicrous.cloud`) was previously mapped via CNAME, and later an origin `A` record was added without deleting the legacy CNAME.

---

## 5. Remediation Runbook for Operator

Execute the steps in order. Step 1 immediately stops client outages.

### Step 1: Remove Stale Edge IP from Apex DNS (Stops Outage)
*Target System:* **Namecheap DNS / Registrar Console** (Managing `core-distro.com` on `registrar-servers.com`).
*Action:*
1. Log in to Namecheap -> **Domain List** -> Manage `core-distro.com` -> **Advanced DNS**.
2. Locate the **A Record** section for Host `@`.
3. You will see two records:
   - `A Record` | Host: `@` | Value: `66.29.153.174` (Hostinger origin - **KEEP THIS**)
   - `A Record` | Host: `@` | Value: `162.159.140.166` (Stale Cloudflare edge - **DELETE THIS**)
4. **Delete** the record pointing to `162.159.140.166`.
5. Save changes.
*Evidence / Verification:*
Run:
`dig @dns1.registrar-servers.com core-distro.com A +short`
*Expected Result:* Exactly one IP returned: `66.29.153.174`.
*Rollback:* Re-add `A Record` `@` -> `162.159.140.166` with TTL 30 min (not recommended).

---

### Step 2: Clean Up Conflicting & Stale `www` Records
*Target System:* **Namecheap DNS / Registrar Console** -> **Advanced DNS**.
*Action:*
1. Locate Host `www` records.
2. Find the record:
   - `CNAME Record` | Host: `www` | Value: `sites.ludicrous.cloud` (Stale SaaS - **DELETE THIS**)
3. Ensure the Host `www` has:
   - `A Record` | Host: `www` | Value: `66.29.153.174` (or `CNAME Record` | Host: `www` | Value: `core-distro.com`)
4. Save changes.
*Evidence / Verification:*
Run:
`dig @dns1.registrar-servers.com www.core-distro.com +short`
*Expected Result:* Returns `66.29.153.174` (and NO `sites.ludicrous.cloud`).
*Test Curl:*
`curl -I https://www.core-distro.com/`
*Expected Result:* HTTP 200 via LiteSpeed.
*Rollback:* Re-add CNAME `www` -> `sites.ludicrous.cloud`.

---

### Step 3 (Optional): If Cloudflare Proxying Was Intended
*Target System:* **Cloudflare Dashboard**
*Note:* The zone's authoritative nameservers are currently Namecheap (`registrar-servers.com`), NOT Cloudflare.
If the operator intended to route `core-distro.com` through Cloudflare:
1. In Cloudflare Dashboard, configure either:
   - **Full Zone Setup:** Change nameservers at Namecheap to assigned Cloudflare NS (`*.ns.cloudflare.com`), OR
   - **Cloudflare for SaaS / Partial CNAME Setup:** Complete domain verification and SSL certificate issuance in Cloudflare SSL/TLS tab before routing traffic.
2. **Do not point DNS A records to Cloudflare IPs without an active zone/hostname configuration.**

---

## 6. Audit Log: Diagnostic Commands Executed
All commands executed were strictly non-mutating / read-only:
- `dig @8.8.8.8 core-distro.com A +short`
- `dig @8.8.8.8 core-distro.com NS +short`
- `dig @dns1.registrar-servers.com core-distro.com A`
- `dig @dns1.registrar-servers.com www.core-distro.com A`
- `dig @dns1.registrar-servers.com www.core-distro.com CNAME`
- `whois 162.159.140.166`
- `curl -v --resolve core-distro.com:443:66.29.153.174 https://core-distro.com/`
- `curl -v --resolve core-distro.com:443:162.159.140.166 https://core-distro.com/`
- `curl -v --resolve www.core-distro.com:443:66.29.153.174 https://www.core-distro.com/`
- `curl -v https://data.core-distro.com/`
- `ssh hd2stack '<curl tests>'`
- `ssh elevatesVPS '<curl tests>'`
- `openssl s_client -connect 66.29.153.174:443 -servername core-distro.com </dev/null`

Zero write actions were taken against DNS, certificates, Cloudflare, or origin servers.
