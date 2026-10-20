# Core Distro SaaS / Aspire / GHL — GTG request

Date: 2026-10-10
To: Crisp-R / Dubz Controller
From: Brandon Firstmate
Delivery: Local outbound record only; no remote receipt or approval confirmed.

## Audit result

Bounded read-only audit completed. No code changes, credential reads, integration calls, authenticated dashboard inspection or database writes were performed. Qualified findings: `warehouse/reports/core-distro/SAAS_READINESS_SUMMARY_2026-10-10.md` in `/home/hd2admin/kun-agent-workspace`.

Public browser scout reports core-distro.com and data.core-distro.com roots load at HTTP 200; staging.core-distro.com root reports HTTP 500/application error. Private WordPress staging on Brandon is separate. Source review flags callback authenticity/correlation, GHL proxy scope and credential handling for verification; local copies are not certified as current production. Related-app records are historical. Aspire identity remains unresolved.

## Please reply without secrets

- Exact Aspire product/vendor URL, owner and intended integration/data flow.
- Authoritative deployed source/revision and domain mapping for the SaaS and public sites.
- Intended GHL locations/scopes/workflows, triggers, mapping, consent/suppression, rollback and owner.
- Approved non-production endpoint, synthetic fixtures, API budget and credential custodian; do not send keys.
- Current status of September hardening and queue-claim work, with authoritative evidence.
- Owner/status of staging.core-distro.com and intended CRM for public registration.
- Receipt and explicit scoped GTG/not-GTG, limitations and outstanding approvals. GTG must not be interpreted as blanket deployment approval.

## Existing access errors for Controller investigation

These are previously observed errors, not new connectivity tests:

1. Documented SSH hostname `vmi3196300`: `ssh: Could not resolve hostname vmi3196300: Temporary failure in name resolution`. No scp transfer occurred.
2. Local read of `/root/bin/warehouse-sync.sh`: `EACCES: permission denied`. This is a local file-access error, not proof of a remote outage.

Please provide the approved reachable hostname/address, authenticated account and destination, or an accessible authorized sync mechanism. Do not weaken authentication, expose services, or send credentials in Markdown.

No backup payload, database dump, WordPress volume, .env or wp-config.php is attached.
