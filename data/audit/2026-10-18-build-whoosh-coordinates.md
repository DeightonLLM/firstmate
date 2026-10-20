# Whoosh coordinates and Gate A–E preparation

**Date:** 2026-10-18
**Result:** No Whoosh-specific repository or server coordinates were found in the readable sources searched. A known Brandon Hetzner compute host was measured directly, but the available source records explicitly distinguish that shared compute host from the unknown Whoosh production host; it is not evidence that it is the Whoosh service target. No DNS records were created or changed.

## Search and candidate findings

Searches covered readable source files under `/home/hd2admin` (including workspace, the Whoosh warehouse, work/reply records, baseline repository, and readable `.treehouse` snapshots), and targeted configuration/source locations `/etc`, `/opt`, `/srv`, `/var/lib`, `/var/www`, and `/usr/local/etc`. Searched Whoosh/domain/provider/hostname/IP references, Whoosh-named paths, repository metadata, DNS/host records, and the PRD/audit records. Several mirrored worktrees repeat the same system-context entries; they are copies of the same evidence, not independent coordinates. Apt cache hits for the words “Whoosh”, “Hetzner”, and “Namecheap” are software package metadata and contain no project infrastructure coordinates.

### Candidate host details (not accepted as Whoosh placement)

1. **Hostinger KVM8 candidate `srv1856614` / `brandon-hub`; Tailscale `100.86.247.105`; public `2.25.197.26`.** Exact source: `/home/hd2admin/firstmate-baseline/docs/system-context/HOSTS.md:104-118`. The record identifies it as the Brandon hub for OnePanel/OpenResty and other staged services, says its tenant is `brandon-hub`, and explicitly says this is the only live target used by the BR-HUB campaign. No evidence assigns it to Whoosh. A different Hostinger KVM8 candidate, `srv1137994-aminolifesciences`, Tailscale `100.69.211.43` and public IP UNKNOWN, appears at the same file `:86-102`; its recorded tenants are Core-Distro and CBD-Data, not Whoosh. The Whoosh PRD only says “Brandon's existing Hostinger KVM8” and does not disambiguate these hosts. Neither was directly measured from this session; no Whoosh-specific KVM8 coordinate is accepted.

2. **Hetzner Brandon compute candidate `brandon-compute` / `hetzner-compute`; Tailscale `100.106.6.22`; public `157.180.99.39`.** Exact source: `/home/hd2admin/firstmate-baseline/docs/system-context/HOSTS.md:120-136`. The entry identifies a Brandon compute plane and says `brandon-compute` only is its tenant (`:131-136`), so it is not Whoosh-specific production placement. It was directly measured as the host executing this task:
   - Command: `hostname -f; ip -brief address`
   - Output identity: `brandon-compute.tailddbb4d.ts.net`
   - Output addresses: `enp5s0 157.180.99.39/32`, `tailscale0 100.106.6.22/32`.
   - `getent ahostsv4 brandon-compute` returned `100.106.6.22`.
   This confirms the existing Brandon compute machine only. It does not establish that the Whoosh service/repository is hosted there.

3. **Namecheap proposed logical name `bdn-dr-whoosh-01`, no VPS coordinates.** `/home/hd2admin/firstmate-baseline/docs/system-context/BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md:590-601` proposes a logical Namecheap backup target name for Whoosh. `/home/hd2admin/firstmate-baseline/docs/system-context/HOSTS.md:169-177` says Namecheap DR target accounts (`server401`, `business186`, `business125-5`, `hd2data`) are general-purpose HD2Stack accounts and per-project assignment is not evidenced. `/home/hd2admin/firstmate-baseline/docs/system-context/evidence/BR-INV-001/report.md:293` says there is no workspace evidence for the Whoosh DR target. No Namecheap VPS hostname or IP can be derived from this; `bdn-dr-whoosh-01` is a proposal, not an observed host.

4. **Whoosh project host record is explicitly unknown.** `/home/hd2admin/firstmate-baseline/docs/system-context/HOSTS.md:138-152` gives `whoosh-runtime` as a logical record, with tier/provider/hostname/Tailscale IP/public IP UNKNOWN, status `BLOCKED — COORDINATES_MISSING`, and says the exact repository, hosting, runtime, and production IP are required. `/home/hd2admin/firstmate-baseline/docs/system-context/service_catalog.yaml:335-351` likewise sets `current_host: whoosh-runtime`, intended host/runtime UNKNOWN, allowed actions read-only, and status BLOCKED. This is not an actual hostname or address.

5. **Whoosh repository.** The Whoosh warehouse `/home/hd2admin/overnight-20260924/repo/data/domain-warehouses-20260915/whooshperformance.com/STATUS.md:5-12` says the source repository is UNKNOWN and no eligible `projects/whooshperformance.com/` checkout was found. The repository directory contains only `INDEX.md`, `STATUS.md`, and `SOURCES.md`; no application checkout is present. The reported search in `/home/hd2admin/kun-agent-workspace/data/2026-10-15/wo-0008-whoosh-report.md:18-50` also records no Whoosh-named repository, source/deployment manifest, runtime, or deploy path in that earlier search. A fresh host-wide path search found no Whoosh project repository. No repository URL/path or remote was found.

### Current DNS evidence

Direct external DNS queries were run against Cloudflare resolver `1.1.1.1` at 2026-10-18 02:37:49–02:37:50 BST:

- `dig +time=3 +tries=1 @1.1.1.1 data.whooshperformance.com A` → `status: NXDOMAIN`, zero answers; authority SOA `whooshperformance.com. 600 IN SOA atlas.dns-parking.com. dns.hostinger.com. 2026101501 ...`.
- Same query for `data.whooshperformance.com CNAME` → `NXDOMAIN`, zero answers.
- `dig +time=3 +tries=1 @1.1.1.1 lc.whooshperformance.com A` → `NXDOMAIN`, zero answers.
- Same query for `lc.whooshperformance.com CNAME` → `NXDOMAIN`, zero answers.

This confirms those names returned NXDOMAIN from the selected external recursive resolver at measurement time. It does not identify the correct destination or prove that an intended DNS record should point at either candidate server. Per the task boundary, no DNS write was attempted.

## Operator input request — answer together in one reply

Please provide the following exact facts (or state “not provisioned” for an item). Do not send credentials or secret values; identify the approved secure access path/owner instead.

1. **Whoosh source repository:** canonical repository URL, default/production branch, and any existing local path or deployment source; identify the owner who can grant read access.
2. **Hostinger KVM8 assigned to Whoosh:** confirm the exact VPS identity/canonical hostname, public IPv4 (and IPv6 if used), Tailscale/private address if applicable, and whether this is `srv1856614`, `srv1137994`, or a different Hostinger KVM8. Cite the provider inventory or a live host measurement.
3. **Hetzner Whoosh data-service host:** confirm exact server identity/canonical hostname, public IPv4/IPv6 and Tailscale/private address if applicable, plus the running Whoosh service/repository location. Confirm explicitly whether the existing `brandon-compute` (`157.180.99.39` / `100.106.6.22`) is or is not the assigned Whoosh target.
4. **Namecheap Whoosh VPS/backup target:** confirm provisioned/not provisioned; if provisioned, give provider server/account label, canonical hostname, public IP, OS/capacity, and approved access owner/path. Confirm whether `bdn-dr-whoosh-01` is only a proposal or the actual assigned target.
5. **Authority/access owners needed for Gates A–E:** DNS registrar/manager and owner; Hostinger, Hetzner, Namecheap account owners; Aspire account administrator; source repository and static site content owner; approved secure access mechanisms; human/service identities and MFA approver; alert mailbox owner for `info@whooshperformance.com`. Names/roles and access path only—no secrets.

## Phase 0 Gate A–E checklist (prepared; execution waits for coordinates/access)

### Gate A — Account and Server Inventory
- [ ] Record domain registrar/account owner, current nameservers and DNS manager.
- [ ] Inventory the specifically assigned Hostinger KVM8: hostname, IPs, region, CPU/RAM/disk, OS, firewall, Docker, Nginx, workloads.
- [ ] Inventory the specifically assigned Hetzner server: hostname, IPs, region, CPU/RAM/disk, OS, firewall, Docker/proxy, Whoosh services/workloads.
- [ ] Inventory the specifically assigned Namecheap VPS: hostname/IP, storage, OS, access method, backup capacity/jobs.
- [ ] Record current Tailscale, Cloudflare, Coolify, GitHub, monitoring, and password-manager use; accounts/users; snapshots and last successful backups.
- **Current state:** blocked on identifying the Whoosh-assigned machines and approved read access. The `brandon-compute` facts above are a measured unrelated/shared-host candidate, not substitution authorization.

### Gate B — Domain and DNS Inventory
- [ ] Export every root/`www`/`data`/`lc`/`mail` and other applicable A/AAAA/CNAME/MX/TXT/SPF/DKIM/DMARC/CAA/wildcard record before any edit.
- [ ] Identify DNS provider/account owner and purpose/owner of every mail record; preserve unknown records.
- [ ] Attach timestamped raw query/export evidence and exact rollback values.
- **Current state:** only the two external NXDOMAIN results above have been measured; the authoritative zone export and DNS account owner remain missing. No changes.

### Gate C — Static Site and WordPress Migration Audit
- [ ] Locate and identify the exact source repository, production branch/build process, deployed files, owner, and access path.
- [ ] Inventory every page/URL, navigation/footer/forms/downloads/embeds/analytics/integrations.
- [ ] Inventory image/icon/logo/font licensing; redirects/canonical/metadata/sitemap/robots/schema and index/landing-page evidence.
- [ ] Identify content and approval owners, WordPress theme/build approach, justified plugins, PHP/database requirements.
- [ ] If source is unavailable, stop build and report missing inputs; do not reconstruct content from guesses.
- **Current state:** blocked on repository and source access; no site implementation begins.

### Gate D — Data and Aspire Service Audit
- [ ] For `data`: record intended behavior/availability; repository/branch/image/process; runtime/port/proxy/health/auth; actual stores/queues/schedulers/browser/API dependencies; environment-variable names only; errors/logs/resource use/last successful run; classification/retention/backups.
- [ ] For `lc`: identify Aspire account owner/admin; provider-required records and validation; expected HTTP(S) and tracking behavior; sender/bounce alignment; last known provider health without recipient data.
- [ ] Confirm the intended DNS destination only from owner/provider evidence; never substitute an unrelated server address.
- **Current state:** blocked on assigned Hetzner host/service and Aspire account-owner/provider evidence. NXDOMAIN does not establish destination.

### Gate E — Ownership, Access, and Notification Test
- [ ] Record each human/service identity, role, least-privilege need, authentication method, MFA, approver, and review/expiration date (no secret values).
- [ ] Confirm `info@whooshperformance.com` receives external mail and has a named human owner.
- [ ] Send a test system alert; verify receipt, spam/forwarding behavior, and urgent-alert owner.
- [ ] Confirm emergency access is stored in the approved password manager.
- **Current state:** blocked on contact/account owners and the approved alert-test mechanism; no credentials requested or accessed.

**Phase 0 exit:** Gate evidence, immutable baseline/backup and rollback readiness, and the missing coordinate answers must be reviewed before any production change. This preparation itself made no production, DNS, account, or infrastructure changes.
