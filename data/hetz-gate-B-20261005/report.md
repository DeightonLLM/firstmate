# Gate B — Namecheap 4-Target Classification Report
**Date:** 2026-10-12
**Scope:** Read-only inventory of the four registered project domains from Gate A
**Source:** Live DNS/TLS probes from host 100.71.95.76, SAAS_ACCESS_INVENTORY, BOARD.md, PRD v3

---

## Summary Table

| # | Target Domain | Namecheap DNS? | Namecheap Hosting? | Active Hosting Path | TLS / ACME | Operational Owner | PRD Namecheap Target |
|---|---|---|---|---|---|---|---|
| 1 | `core-distro.com` | ✅ Yes (registrar + DNS) | ✅ Yes — shared cPanel | Direct to Namecheap shared (A record `.174`) | Sectigo DV (cPanel AutoSSL); RSA; valid Jun 2 – Dec 17 2026 | Controller | `bdn-dr-core-01` |
| 2 | `elevatesci.com` | ❌ No (Cloudflare NS) | ❌ No | Cloudflare proxy → Hostinger origin | Google Trust Services WE1; ECDSA; valid Sep 11 – Dec 10 2026 | MiniMax @ brandon (chatbot); Controller (site) | `bdn-dr-elevate-01` |
| 3 | `whooshperformance.com` | ❌ No (Hostinger DNS Parking) | ❌ No | Direct (Hostinger parked-domain placeholder) | Let's Encrypt YE2; ECDSA; valid Jul 25 – Oct 23 2026 | **None** (parked) | `bdn-dr-whoosh-01` |
| 4 | `cbd-data.com` | ✅ Yes (registrar + DNS) | ✅ Yes — shared cPanel | Direct to Namecheap shared (A record `.217`) | Sectigo DV (cPanel AutoSSL); RSA; valid May 6 – Nov 20 2026 | Controller | `bdn-dr-cbddata-01` |

---

## Per-Target Detail

### 1. core-distro.com

**DNS (Namecheap)**
- A: `66.29.153.174`
- NS: `dns1.registrar-servers.com`, `dns2.registrar-servers.com`
- MX: `mx3-hosting.jellyfish.systems`, `mx2-hosting.`, `mx1-hosting.`
- TXT: SPF present (jellyfish mail)
- Registrar: NameCheap, Inc. (WHOIS verified); created 2026-06-02

**Active Hosting Path**
- Namecheap shared cPanel: `business190.web-hosting.com:2083`
- cPanel user: `corejdng` (SAAS_ACCESS_INVENTORY verified)
- Direct connection (no CDN proxy); origin IP `66.29.153.174`
- Site: Next.js pharmaceutical supply distribution (503A/503B compounding pharmacy)

**TLS / ACME**
- Issuer: Sectigo Limited, CN: Sectigo Public Server Authentication CA DV R36
- Key: RSA 2048-bit
- SANs: `core-distro.com`, `www.core-distro.com`
- Validity: Jun 2 2026 – Dec 17 2026
- Likely provisioned by cPanel AutoSSL (standard Namecheap shared hosting pattern)

**Operational Owner**
- Controller (BOARD.md confirmed; cPanel user `corejdng` routed to controller)

---

### 2. elevatesci.com

**DNS**
- A: `188.114.97.3`, `188.114.96.3` (Cloudflare Anycast)
- NS: `elisa.ns.cloudflare.com`, `ajay.ns.cloudflare.com`
- **Namecheap is NOT the registrar (Hostinger is) and NOT the DNS provider (Cloudflare is)**
- Registrar: Hostinger operations, UAB (WHOIS verified); created 2026-07-25

**Active Hosting Path**
- Cloudflare proxy → Hostinger origin
- CDN/WAF: Cloudflare (A record resolves to CF Anycast)
- Origin: Hostinger VPS (origin IP not directly visible from probe)
- Site: Custom HTML (HD2.ai generated) — peptide/lab supply wholesale; includes AnythingLLM chatbot widget embedded via `agents.elevatesci.com/api/embed`

**TLS / ACME**
- Issuer: Google Trust Services, CN: WE1
- Key: ECDSA P-256
- SANs: `elevatesci.com`, `*.elevatesci.com` (wildcard)
- Validity: Sep 11 2026 – Dec 10 2026
- ACME: Cloudflare origin certificate or Let's Encrypt via Cloudflare Automatic DNS validation

**Operational Owner**
- MiniMax @ brandon: AnythingLLM chatbot workspace and TLS proxy for `agents.elevatesci.com`
- Controller: site content ownership

**Note:** `agents.elevatesci.com` serves the AnythingLLM Express.js app running on brandon host; certificate is Cloudflare-proxied.

---

### 3. whooshperformance.com

**DNS**
- A: `2.57.91.91`
- NS: `hyperion.dns-parking.com`, `atlas.dns-parking.com` (Hostinger DNS Parking)
- **Namecheap is NOT the registrar (Hostinger is) and NOT the DNS provider (Hostinger DNS Parking)**
- Registrar: Hostinger operations, UAB (WHOIS verified); created 2026-07-25

**Active Hosting Path**
- Direct to Hostinger DNS Parking landing page
- CDN: Hostinger CDN (`server: hcdn`)
- No application service; placeholder only
- Server header: `hcdn` (Hostinger CDN edge)

**TLS / ACME**
- Issuer: Let's Encrypt, CN: YE2
- Key: ECDSA
- SANs: `whooshperformance.com`, `www.whooshperformance.com`
- Validity: Jul 25 2026 – Oct 23 2026 (expiring soon — Oct 23 2026)
- ACME: Hostinger AutoSSL on parking infrastructure

**Operational Owner**
- **None.** Domain is registered and parked; no active project, no assigned owner, no Namecheap service.

---

### 4. cbd-data.com

**DNS (Namecheap)**
- A: `68.65.123.217`
- NS: `dns2.registrar-servers.com`, `dns1.registrar-servers.com` (Namecheap DNS)
- MX: `eforward*.registrar-servers.com` (email forwarding)
- TXT: SPF record present
- Registrar: NameCheap, Inc. (WHOIS verified); created 2026-03-23

**Active Hosting Path**
- Namecheap shared cPanel: `cbd-data.com:2083`
- cPanel user: `cbddpolp` (SAAS_ACCESS_INVENTORY verified)
- Direct connection (no CDN proxy); origin IP `68.65.123.217`
- Site: Next.js B2B lead generation ("Automated B2B Lead Generation")

**TLS / ACME**
- Issuer: Sectigo Limited, CN: Sectigo Public Server Authentication CA DV R36
- Key: RSA
- SANs: `cbd-data.com`, `www.cbd-data.com`
- Validity: May 6 2026 – Nov 20 2026
- Likely provisioned by cPanel AutoSSL

**Operational Owner**
- Controller (BOARD.md confirmed; cPanel user `cbddpolp` routed to controller)

---

## Namecheap Service Inventory (per PRD v3)

| PRD Target Name | Assigned Project | Confirmed Namecheap cPanel | Mode |
|---|---|---|---|
| `bdn-dr-core-01` | Core Distro | ✅ `business190.web-hosting.com` (`corejdng`) | Mode B — Shared cPanel backup target |
| `bdn-dr-elevate-01` | Elevate Life Sci | ❌ No Namecheap hosting; Hostinger + Cloudflare | No DR target established |
| `bdn-dr-whoosh-01` | Whoosh Performance | ❌ No Namecheap hosting; parked domain | No DR target established |
| `bdn-dr-cbddata-01` | CBD-Data | ✅ `cbd-data.com:2083` (`cbddpolp`) | Mode B — Shared cPanel backup target |

**VERDICT: PARTIAL**
- 2 of 4 Namecheap backup/DR targets are confirmed (Core Distro, CBD-Data)
- 2 of 4 are missing (Elevate Life Sci, Whoosh Performance — no Namecheap services exist for these domains)

---

## Open Questions

1. **Elevate Life Sci (`bdn-dr-elevate-01`):** Is the intended Namecheap DR target a separate account (not the `elevatesci.com` domain), or is the PRD's `bdn-dr-elevate-01` intended to be Hostinger-based backup storage? The current elevatesci.com hosting is on Hostinger with Cloudflare proxy — no Namecheap account is associated with this domain.

2. **Whoosh Performance (`bdn-dr-whoosh-01`):** The `whooshperformance.com` domain is registered with Hostinger and parked. Has the Whoosh project been abandoned, or does it need to be provisioned from scratch? No Namecheap hosting account is associated with this domain.

3. **`bdn-dr-whoosh-01` TLS expiry:** The Let's Encrypt certificate on `whooshperformance.com` expires **Oct 23 2026** — within 2 weeks of this report. No active service depends on it, but if the domain becomes active, someone needs to renew.

4. **Elevate Life Sci origin IP:** The Hostinger origin IP behind Cloudflare for `elevatesci.com` is not visible from external probes. If the DR plan requires knowing this IP for firewall allowlisting or origin configuration, a Cloudflare API call or internal host check is needed.

5. **Separate Namecheap accounts:** Do `bdn-dr-elevate-01` and `bdn-dr-whoosh-01` exist as isolated Namecheap accounts (separate from the domains' registrar/DNS), or are they aliases/repurposed existing accounts? The SAAS_ACCESS_INVENTORY shows no tokens for these targets.

---

*Evidence collected via live probes from host 100.71.95.76 (2026-10-12). Last octets reported for all IPs. No credentials, tokens, or secrets exposed in this document.*
