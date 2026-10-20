# Core Distro staging parity follow-up

Date: 2026-10-10
Scope: private staging homepage versus the current public Core Distro site; no production changes.

## Completed corrections

- The staging homepage now omits Astra's global frontend stylesheet, which had overridden source utilities and caused dark headings, blue/oversized buttons, oversized logos, and layout collisions.
- Astra's scroll-to-top markup is removed only on the custom homepage. The normal Astra markup remains on a non-homepage route.
- The homepage header/footer logos, core colors, and click-to-scroll behavior were measured at desktop and mobile widths. No forms were submitted and the chatbot was not activated.

## Decisions and current findings

1. **Local routes selected.** The captain chose a full private multi-page WordPress staging site rather than links back to public pages. The requested local routes are `/products/`, `/about/`, `/compliance/`, `/contact/`, `/resources/`, `/blog/`, and `/faq/`, in addition to `/`. Do not invent their copy or CRM behavior; complete source inventory first. The contact/quote section remains non-submitting and the chatbot inactive.

2. **100% scale diagnosis.** M3.1 measured staging and public geometry as identical at 100% across desktop and mobile conditions and made no staging edits. Its real-zoom counterfactual found that 111% per-origin browser zoom would produce the reported 90% workaround exactly. This is a likely client-side explanation, not yet observed in the captain's browser profiles. Evidence: `/home/hd2admin/.pi/agent/sessions/--home-hd2admin-kun-agent-workspace--/subagent-artifacts/outputs/598425a8-2b89-433a-8791-c48a4217d3b3/reports/minimax-m31-full-page-scale.md`.

3. **Footer delta corrected as a measurement artifact.** M3.1 found identical natural footer and document heights under default rendering; the earlier 8px delta appeared only with non-default unhinted-font rendering. Do not apply the proposed fixed 105px footer height; it clips content in the wrap condition.

4. **Source audit correction.** The first local inventory missed the older `cbd-campaign/` preparation package. It is now catalogued in `warehouse/reports/CORE_DISTRO_WORDPRESS_SOURCE_MAP.md` together with the October 6 Controller work orders, current staging, and legacy snapshots. The old package is based on a freshness-unknown single-page snapshot and does not contain the multi-page WordPress/CRM source requested now.

5. **Controller follow-up.** A source request is recorded in `BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-10-core-distro-wordpress-source-request.md`. It asks for exact paths or repository references for any full WordPress export, page/media source, CRM integration materials, and actual prior migration status. Receipt is not independently confirmed.

## Safety

The public site was accessed read-only. The Tailnet staging stack remained running. No production pages, forms, chatbot, credentials, DNS, firewall, proxy, cPanel, or Docker volumes were modified.
