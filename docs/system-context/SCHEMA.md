# System-Context Warehouse — Schema (v1, 2026-09-15)

This schema defines the machine-readable YAML records in `hosts.yaml`,
`service_catalog.yaml`, and `prd_traceability.yaml`. The companion Markdown
files (`HOSTS.md`, `SERVICE_CATALOG.md`, `PRD_TRACEABILITY.md`) are the
human-readable authority for every record. YAML is generated from, and
validated against, the Markdown; YAML never overrides the Markdown.

A record that does not satisfy the schema is rejected by
`bin/fm-context-preflight.sh`. Stale records (older than the freshness
window) are rejected even when structurally valid.

## Common record fields

Every record carries these fields:

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Stable identifier (lowercase, hyphen-separated) |
| `status` | enum | yes | `KNOWN`, `PARTIAL`, `UNKNOWN`, `BLOCKED` |
| `last_verified` | date (ISO-8601) | yes | Last date the record was reviewed against source evidence |
| `freshness_days` | int | yes | Maximum allowed age of `last_verified` before the record is considered stale |
| `evidence_paths` | list of string | yes | Repository-relative source paths that resolve inside the warehouse repo; external sibling-workspace references belong in `sources`, never here |
| `sources` | list of string | yes | At least one human-readable source pointer (report path, manifest row, ADR) |
| `notes` | string | no | Free-form context, optional |

`status` semantics:

- `KNOWN` — All required fields populated with cited source.
- `PARTIAL` — Some fields populated; remaining fields use `UNKNOWN` placeholder and `sources` is partial.
- `UNKNOWN` — Identifier recognised, but no source-backed data is available yet.
- `BLOCKED` — A blocking dependency prevents resolution (e.g., missing coordinates, operator input).

## hosts.yaml — Host record

```yaml
- id: string                     # stable identifier
  provider: string               # hostinger | contabo | hetzner | aminovps | namecheap | local | UNKNOWN
  alias: string                  # operator alias (may be empty)
  canonical_hostname: string     # documented hostname or UNKNOWN
  tailscale_ip: string | UNKNOWN
  public_ip: string | UNKNOWN
  role: string                   # one short role sentence; UNKNOWN if not documented
  tier: enum                     # HD2_IN_HOUSE | BRANDON_LEGACY_VPS | BRANDON_HUB | KVM1_HOSTINGER | HETZNER_COMPUTE | LOCAL
  tenants: list of string        # project IDs that own software on this host; empty if NONE
  evidence_paths: list of string
  sources: list of string
  last_verified: date
  freshness_days: int
  notes: string
```

`tier` values and what they mean (do not invent new tiers):

- `HD2_IN_HOUSE` — HD2/Contabo infrastructure (controller, HD2stack, HD2.ai edge).
- `BRANDON_LEGACY_VPS` — Brandon legacy AminoVPS / Elevate legacy VPS.
- `BRANDON_HUB` — Brandon hub host (PostgreSQL, Redis, Qdrant, LiteLLM, OpenResty/OnePanel).
- `KVM1_HOSTINGER` — KVM1 Hostinger node (HD2.ai / brandon edge candidate).
- `HETZNER_COMPUTE` — Hetzner compute plane (scraping, workers, queues).
- `LOCAL` — Local controller context (this host).

## service_catalog.yaml — Service record

```yaml
- id: string
  platform_owner: string         # deightonllm | brandon | elevate | UNKNOWN
  tenant_or_client: string       # core-distro | cbd-data | elevate | whoosh | hd2 | brandon-hub | brandon-compute | music-metrics | lawyer | UNKNOWN
  brand_or_domain: string        # primary brand or domain, or UNKNOWN
  current_host: string | UNKNOWN # host id from hosts.yaml, or UNKNOWN
  intended_host: string | UNKNOWN
  runtime: enum                  # container | systemd | php-fpm | node | python | static | UNKNOWN
  allowed_actions: list of enum  # read | local-build | mock-test | staging-deploy | production-deploy | live-mutate | UNKNOWN
  evidence_paths: list of string
  sources: list of string
  last_verified: date
  freshness_days: int
  status: enum                   # KNOWN | PARTIAL | UNKNOWN | BLOCKED
  notes: string
```

`allowed_actions` values:

- `read` — Read-only audit, no mutation.
- `local-build` — Build artefacts locally without remote call.
- `mock-test` — Run tests with mocks and no live call.
- `staging-deploy` — Deploy to a staging environment only.
- `production-deploy` — Deploy to a production target.
- `live-mutate` — Modify a running live service.

Records must never include credential material, secret tokens, or API keys;
the preflight rejects any record that contains a secret pattern.

## prd_traceability.yaml — PRD item record

```yaml
- id: string
  prd_section: string            # PRD section or capability name
  scope: string                  # elevate | core-distro | cbd-data | whoosh | hub | compute | cross-project | platform
  status: enum                   # DELIVERED | EVIDENCED | IN_PROGRESS | BLOCKED | UNKNOWN
  blocker: enum                  # NONE | COORDINATES_MISSING | AUTHORIZATION | OPERATOR_INPUT | DEPENDENCY | UNKNOWN
  evidence_paths: list of string
  sources: list of string
  last_verified: date
  freshness_days: int
  notes: string
```

`status` semantics:

- `DELIVERED` — Customer-facing release is live and verified end-to-end.
- `EVIDENCED` — Working software/runtime evidence exists but PRD-wide acceptance is not proven.
- `IN_PROGRESS` — Active implementation or audit is underway.
- `BLOCKED` — A named blocker prevents further progress.
- `UNKNOWN` — Not enough source to classify; do not invent.

A `DELIVERED` claim without an evidence path is a schema violation and is
rejected by the preflight. `BLOCKED` and `UNKNOWN` must each carry a
`blocker` field with a non-`NONE` value.
