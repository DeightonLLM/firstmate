# How to Register a Client or Project Warehouse

Use this procedure to establish a distinct client/project document boundary and
register only its sanitized operational pointer in the HD2 System Context
warehouse. It does not authorize data migration or service deployment.

## Prerequisites

- Exact client and project identifiers, accountable owner, and approved source
  repository or storage root.
- Data classification, permitted locations, retention, and deletion owner.
- Named access groups and a break-glass recovery path; record secret-store
  pointers only, never secret values.
- A per-client backup/restore design with key custody and accepted RPO/RTO.
- An approved test plan proving one client cannot list, retrieve, export, or
  restore another client's documents.

If an item is missing, record the warehouse as `UNKNOWN` or `BLOCKED`; do not
create a placeholder path or share an existing workspace by default.

## Steps

1. **Pin the tenant.** Record client ID, project ID, source-of-truth repository,
   storage owner, and exact data root. For Brandon, register Core Distro,
   Elevate, Whoosh, and CBD-Data separately.
2. **Separate storage and access.** Use a client/project-owned repository or
   document store with explicit read/write groups. Do not place client content
   in the HD2 system index or a mixed campaign folder.
3. **Classify and protect data.** Record allowed data types, retention,
   deletion, encryption, and secret-store references. Never record secret
   values in Markdown, YAML, prompts, logs, or evidence.
4. **Bind AI retrieval to the tenant.** For AnythingLLM or another RAG service,
   prove workspace authorization, document enumeration, retrieval, embeddings,
   vector collections, backup, and deletion are project-scoped. Otherwise use
   separate instances until isolation is demonstrated and approved.
5. **Prove recovery.** Back up the client boundary independently, restore an
   approved representative fixture, and record measured RPO/RTO and key
   custody. A provider snapshot or shared-service backup is not proof of
   per-client recovery.
6. **Register a minimal system pointer.** Update the system Markdown first,
   then its YAML mirror. Record owner, tenant/project ID, root pointer, data
   class, status, freshness, and evidence. Keep `evidence_paths` inside the
   system warehouse repository; mark sibling-workspace references as external
   `sources` only.
7. **Validate and retain the gate.** Run system preflight and client-specific
   negative-isolation and restore tests. Missing identity, backup, key custody,
   or authorization remains a blocker; do not promote it to `KNOWN` or
   `DELIVERED`.

## Verification

A registration is ready only when system preflight passes, evidence paths
resolve within their declared repository, the client owner approves the data
boundary, cross-tenant deny tests pass, and restore proof meets accepted RPO/RTO.
An inventory or workspace label alone is not sufficient.

## Troubleshooting

- **Evidence path points outside the repository:** move no data; correct the
  local evidence path or keep the sibling artifact as a marked external source.
  Never use `../` or an absolute path in `evidence_paths`.
- **Tenant or workspace identity is unknown:** leave it `UNKNOWN`; do not route
  documents to a shared default.
- **Backup or restore owner is missing:** keep deployment/migration gated until
  provider, encryption/key custody, retention, RPO/RTO, and restore acceptance
  are approved.

## Related

- [Warehouse boundary model](WAREHOUSE_BOUNDARIES.md)
- [System Context index](INDEX.md)
- [Service catalog](SERVICE_CATALOG.md)