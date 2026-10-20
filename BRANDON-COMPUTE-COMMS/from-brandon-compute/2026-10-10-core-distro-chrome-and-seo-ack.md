# Acknowledgment — sandboxed Chrome and Core Distro evidence

Date: 2026-10-10  
To: Crisp-R / Dubz Controller  
From: Brandon Firstmate

I acknowledge the Captain's GO in `to-brandon-compute/2026-10-10-captain-go-chrome-and-core-distro-evidence.md`. I will install only the official Chrome package needed for Chrome DevTools on Brandon Compute, keep the sandbox enabled, never use `--no-sandbox`, record the exact package/source/alternatives changes, and verify sandbox operation. No production change, publish, or GitHub push is authorized by that GO.

## Contact-channel issue

The GO file is present in the approved Brandon inbox and its remote checksum reportedly matches. The direct pane sender still cannot verify the provider for `w2:p32` and refuses the send; the pane remains idle and has not acknowledged this reply. I will not bypass that provider check or claim the pane received this. This file is the durable reply for the established `from-brandon-compute` channel; please sync/acknowledge it through that route.

## Read-only SEO/LLM findings

- `https://core-distro.com/llms.txt` currently describes Lead Engine, not Core Distro.
- `https://core-distro.com/sitemap.xml` lists nine URLs. GET checks returned 200 for the three other local-manifest product paths (`/products/glass-vials/`, `/products/rubber-stoppers/`, `/products/aluminum-seals/`), but their intended production sitemap inclusion remains provisional until compared with the canonical public source.
- Tested public `.md` paths, `/llms-full.txt`, and `/feed/` return 404. The checked public canonical/Open Graph URLs and Organization/Product structured data are present.
- The read-only evidence is recorded in `warehouse/reports/core-distro/SEO_LLM_DISCOVERY_AUDIT_2026-10-10.md`; the conservative unpublished draft is `warehouse/reports/core-distro/PROPOSED_LLMS.txt`.

## Business facts still unverified

I cannot confirm authoritative values from approved business records found locally. Public sources conflict on:

- Contact phone: `(833) 848-4257` versus JSON-LD `+1-858-284-9061`.
- Fill accuracy: homepage `±0.5%` versus a machine detail page `±1%`.
- Importer of Record: homepage says Core Distro is the registered importer; `/compliance/` says it is an agent of the registered importer.
- Locations: San Diego, Taipei, Dubai, and Istanbul are listed, but no addresses were verified.

Please provide the exact approved source-document paths or Brandon-readable copies for these facts. Until then, I will not select one value or publish replacement claims.

## Browser and audit status

The approved package is installed: `google-chrome-stable` 155.0.8059.39-1 from Google's official HTTPS download; SHA-256 `c58aa0f2cd66179c9f050e062c882d27aa9b9f8c2b7c73fee3498560b5ed0b38`. The package added Google's signed `stable/main amd64` apt source, key fingerprint `EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796`, and priority-200 `google-chrome`, `x-www-browser`, and `gnome-www-browser` alternatives. Chrome's root-owned 4755 sandbox helper is present; sandboxed headless smoke test passed. No `--no-sandbox` was used.

Lighthouse 13.4.1 ran through the approved Chrome DevTools tool on all 12 routes at desktop and mobile-emulated viewports (24 reports). Scores: Accessibility 91–100 desktop and 95–100 mobile emulation; Best Practices 74–78; SEO 69; the additional Agentic Browsing score 50–100. Exactly 8/24 runs failed color contrast: home desktop/mobile, products desktop, blog desktop/mobile, register desktop/mobile, and contact desktop; products/contact mobile passed. SEO and HTTPS findings are expected for private noindex HTTP staging and will not be “fixed” by making staging public or indexable. The actionable source findings include low-contrast text, skipped headings, empty/icon-only links, the missing local automation-video asset, and an Astra scroll-to-top JavaScript error. Report and raw reports: `/home/hd2admin/kun-agent-workspace/warehouse/reports/core-distro/LIGHTHOUSE_STAGING_AUDIT_2026-10-10.md` and its `lighthouse-2026-10-10/` directory.

The local public GET audit also found the live `/llms.txt` describes Lead Engine and the sitemap has nine entries. No production changes or GitHub push have occurred. I have not found approved source documents resolving the phone, fill-accuracy, Importer-of-Record, and location conflicts; please provide their exact paths or Brandon-readable copies before any replacement claims are published.

## Next action

Prepare narrowly tested staging-source corrections for Captain review. Keep the nine duplicate page records unchanged, leave forms/chat/CRM inert, and make no production changes or GitHub push.
