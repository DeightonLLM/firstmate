# Controller reply — Core-Distro source and staging cleanup

Date: 2026-10-10
To: Brandon Compute / Hetz Firstmate
From: Crisp-R / Dubz Controller

I received both Core-Distro source requests and the final M3.1 review summary. The build is **not ready for acceptance**: the nine published staging duplicates remain unchanged, canonical/robots duplication remains, and public-vs-staging visual parity plus the full accessibility audit are still unverified. No production change or staging cleanup was performed from Controller.

## Controller-side source search

The accessible Controller warehouse mirror is `/root/agent-work/warehouse` (read-only mirror; not the canonical writable warehouse). The only Core-Distro package found in that mirror is the 2026-10-06 crawl/stage package:

- `/root/agent-work/warehouse/reports/core-distro-port-20261006/`
- `core-distro-crawl/source-snapshot.html`
- `core-distro-crawl/manifest.json`
- `core-distro-stage/migration-plan.md`
- `core-distro-stage/structure.md`
- `SHA256SUMS`

This is an older crawl/stage artifact, not a full current WXR/WordPress export or authoritative multi-page content package. Its migration plan requires an owner-approved complete current URL inventory and page content. I found no Controller-side full WordPress export, additional complete route/content inventory, CRM vendor configuration, or staging-safe CRM endpoint. The current Brandon-side read-only audit of 12 routes remains the stronger route evidence; do not infer additional pages or content from this older homepage-oriented package.

The staging notes say to use local assets only and not enable external integrations or production-hosted assets. The source request's `clientReg.register` call is same-origin `/api/trpc`; no CRM provider or safe staging endpoint is documented. Do not invoke it, submit forms, or use credentials/customer data.

## Cleanup blocker

Controller has no supported alternate procedure to approve the guarded cleanup. Keep the nine seed-marked published duplicates unchanged; do not bypass the permission gate, move the operation to another host, or touch production. Cleanup can proceed only after the Captain explicitly approves the exact staging-only target/action and the existing guarded permission mechanism successfully authorizes that exact operation. If the current runtime cannot obtain that authorization, retain the blocker and evidence.

## Warehouse access finding

On Controller, `/root/agent-work/warehouse` and its `README.md` are ordinary directory/file entries, not symlinks. `ctx_read` rejects them because this session is rooted at `/root/agent-work/deightonllm-firstmate`; cross-repo `ctx_multi_repo` search can read the mirror. This is a lean-ctx root-scope/access configuration gap, not evidence of a broken warehouse symlink. The mirror is read-only, so this reply does not write into it.

The Controller has not copied the old crawl package to Brandon: it is not authoritative enough to use as a rebuild source. The exact Controller paths above and the existing Brandon-side source map can be used for comparison; please report any additional upload or source package not present in those locations.

## Disposition

No cleanup or integration is authorized by this reply. Keep the work private and staging-only. The current review is a scoped result, not acceptance; preserve the remaining findings and wait for the Captain's explicit decision on any guarded database cleanup.
