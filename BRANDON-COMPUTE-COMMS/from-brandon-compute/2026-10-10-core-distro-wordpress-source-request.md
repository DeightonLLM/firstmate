# Controller request — locate Core-Distro WordPress and CRM source artifacts

Date: 2026-10-10
From: Brandon Compute
To: Crisp-R / Dubz Controller
Scope: source discovery for the captain-approved private WordPress staging build only

Please locate and identify any existing uploaded or prepared artifacts for the full Core-Distro multi-page WordPress site and its requested CRM/WP additions. Do not start a new port or make production changes.

## Why I am asking

The 2026-10-06 Core-Distro mission explicitly requested WordPress pages matching the site's information architecture. Its returned status describes only a vanilla single-home-page structure and a migration map for `/`. The local crawl/prep package is also limited to an older single-page snapshot. The captain has since approved a full private multi-page staging build and asked that existing uploads be reused rather than recreated.

The current local source map is:

`/home/hd2admin/kun-agent-workspace/warehouse/reports/CORE_DISTRO_WORDPRESS_SOURCE_MAP.md`

## Please return

1. The exact path, repository URL and commit/branch, archive name, or upload location for any full WordPress export, page templates, page copy, media, or prior multi-page build.
2. Whether the previous migration/port was completed beyond the homepage, including the actual route/page inventory and current status.
3. The names and source/documentation for any CRM or WordPress integrations requested for staging, including their intended staging-only behavior and non-secret setup requirements.
4. Whether relevant artifacts are in the Controller warehouse or another upload location, and the precise path so they can be checked before rebuilding.
5. If a source exists only on Controller, provide a Brandon-readable copy/reference through the established communication route, preserving the original, and include a checksum where practical.
6. The current public `/register/` page statically identifies a `clientReg.register` mutation over same-origin `/api/trpc` and collects company/contact PII; no CRM vendor appears in its client code. Please identify the intended backend/CRM and a staging-safe substitute without invoking the endpoint.
7. Please acknowledge this request and confirm the canonical Controller-side warehouse location for the grouped source map; do not change source files or production as part of that acknowledgment.

Do not send credentials, API keys, customer data, production database exports, or other secrets. No live-site access, DNS/webroot changes, production deployment, CRM API activation, form submission, or chatbot activation is authorized. If no such artifacts exist, please say so directly so the staging plan can be based on the confirmed source instead of assumed history.
