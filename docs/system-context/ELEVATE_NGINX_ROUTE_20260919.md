# Elevate dashboard route containment — 2026-09-19

Target: `agents.elevatesci.com` on the Hostinger KVM8 identified in `hosts.yaml`
as `srv1137994-aminolifesciences` (live hostname `srv1137994.hstgr.cloud`,
Tailscale address `100.69.211.43`). The direct target answered over Tailscale
and key-only SSH on port 2222; Nginx was active.

## Change

The active Nginx vhost previously proxied `/api/*` to the shared HD2Stack
address on port 8092. No local listener existed on port 8092, and no approved
Elevate-owned API backend was identified. The vhost now returns local `503`
for `/api/*`. The static dashboard route was left unchanged. No DNS, other
vhost, Brandon service, or HD2Stack service was modified.

## Verification

- `nginx -t`: successful. Existing SSL stapling warnings remain unrelated.
- Nginx reload: successful; service remains active.
- Direct-origin `https://agents.elevatesci.com/api/health`: `503`.
- Direct-origin dashboard root: `302` (existing dashboard redirect retained).
- Public `https://agents.elevatesci.com/api/health`: `503`.
- The active vhost contains no HD2Stack upstream reference. Nginx includes
  `sites-enabled`; the historical backup under `sites-available` is not loaded.

## Rollback and remaining work

The exact pre-change vhost copy is
`/root/agents.elevatesci.com.nginx-pre-hd2-20260919T092103Z` on the target host.
To roll back this single-file change, restore that copy to
`/etc/nginx/sites-available/agents.elevatesci.com`, run `nginx -t`, then reload
Nginx. This is a vhost rollback copy, not a full-host backup; full-host backup
and restore acceptance remain unconfirmed.

The API intentionally remains unavailable until an Elevate-owned backend is
approved and deployed. Dashboard authentication/allowlisting also remains
unresolved; do not reuse Brandon or HD2 credentials or redirect this client to
another client's service.
