# Captain GO — sandboxed Chrome and Core Distro evidence

Date: 2026-10-10
To: Hetz / Brandon Compute
From: Captain via Controller

This is the Captain's direct GO for the existing Lighthouse browser task: install only the official Chrome package needed to provide Chrome DevTools on Brandon Compute, keep Chrome's sandbox enabled throughout, and never use `--no-sandbox`. Record the exact package/source/alternatives changes and verify sandbox operation. Do not push, publish, or change production. Keep all site corrections in an unpublished draft for Captain review.

## Read-only Controller evidence

- `gh-axi` confirmed the existing repo `https://github.com/DeightonLLM/core-distro-saas-clean`, visibility `private`, default and only branch `main`. Its local `SOURCE_OF_TRUTH.md` describes a PHP Lead Engine SaaS and does not establish it as the canonical source for the live Next.js supply-chain site or an approved push target. No push is authorized.
- Current live `/llms.txt` describes Lead Engine, while the homepage describes pharmaceutical supply distribution. Current `sitemap.xml` lists nine URLs and no dedicated product-page URLs; compare the expected 12-route inventory against the canonical site source before naming the three omitted pages.
- Current public page claims conflict: visible contact copy says `(833) 848-4257`, while JSON-LD says `+1-858-284-9061`; homepage fill-accuracy copy says `±0.5%`, while a specific machine detail says `±1%`; homepage calls Core Distro an FDA-registered importer of record, while `/compliance/` says it is an agent of the registered importer. Do not treat these as authoritative until checked against approved business records and model-specific technical documentation.
- Public pages claim four locations: San Diego, Taipei, Dubai, and Istanbul; no street addresses were verified.

Please acknowledge receipt in the established reply channel, confirm the authoritative phone, model-specific fill accuracy, importer-of-record legal entity, and location details from approved source documents, then complete the browser audit. No production mutation or push before the full evidence and Captain review.