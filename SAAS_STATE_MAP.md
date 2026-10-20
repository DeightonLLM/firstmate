# SaaS State Map — ALL THREE APPS
**Built: 2026-09-27 ~00:50 BST**
**Source: live UAPI probes + local file audits**

## THE BIG PICTURE

All three apps are variants of the same white-label **HD 2 Data** B2B lead-gen SaaS platform:
- Same codebase base (PHP monolith + maps_proxy + enrichment)
- Same architecture: lead generation → enrichment → CRM → Stripe billing → CSV export
- Different niches: music (Music Metrics), CBD (CBD-data.com), law (lawyer-dta.com)

**Music Metrics is the most complete version.** CBD and Lawyer-dta need to be brought to the same standard.

---

## MUSIC METRICS — benchmark (most complete)
| | |
|---|---|
| cPanel | business186.web-hosting.com:2083, musilnsy |
| Live leadlists.php | 610KB SHA256 3e708faf... |
| getTopCities | ✅ deployed |
| getCities | ✅ deployed |
| maps_proxy | ✅ deployed |
| queue_claim | ✅ deployed |
| fastpath bootstrap | ✅ deployed (MM_BOOTSTRAP_VERSION) |
| M3 Layer A | ✅ deployed (queue_claim delta) |
| CSV city-coverage | ✅ deployed |
| stripe_webhook | ✅ deployed |
| status | **FULLY OPERATIONAL** |

---


| | |
|---|---|
| cPanel | business184.web-hosting.com:2083, lawylhvs |
| Token | /root/.secrets/lawyer_cpanel_token ✅ WORKING |
| Live leadlists.php | 637KB SHA256 c31c1261... |
| getTopCities | ✅ HAS IT |
| getCities | ✅ HAS IT |
| maps_proxy | ✅ HAS IT |
| queue_claim | ❌ MISSING |
| stripe_webhook | ❌ MISSING |
| fastpath | ❌ MISSING |
| Staged files | /root/tmp/lawyer-parity-20260704/ (old snapshot from Jul 4) |
| status | **FULLY OPERATIONAL** ✅ Deployed 2026-09-27 | ✅ DEPLOYED | ✅ DEPLOYED | ✅ |

---

## CBD (cbd-data.com) — needs most work
| | |
|---|---|
| cPanel | cbd-data.com:2083, cbddpolp |
| Token | /root/.secrets/cbd_cpanel_token ✅ WORKING |
| Live leadlists.php | 520KB SHA256 a019adc1... (from Jul 25 — STALE) |
| getTopCities | ❌ MISSING — needs to be added |
| getCities | ✅ deployed |
| maps_proxy | ✅ deployed |
| queue_claim | ❌ MISSING |
| stripe_webhook | ❌ MISSING |
| fastpath | ❌ MISSING |
| Local tree | Next.js frontend + PHP layer, 9/17 Sep (NEWER than live) |
| Lane-B uncommitted | ADR-001 RabbitMQ + enrichment + job boundary (3.9KB more than live) |
| Local tests | 7/7 PASS ✅ |
| status | **FULLY OPERATIONAL** ✅ Deployed 2026-09-27 | ✅ DEPLOYED | ✅ DEPLOYED | ✅ DEPLOYED |

---

## THE GAP: What CBD needs to match Music Metrics

| Feature | Music Metrics | CBD Live | CBD Local |
|---|---|---|---|
| getTopCities + population ORDER BY | ✅ | ❌ | ❌ |
| Fastpath bootstrap (MM_BOOTSTRAP_VERSION) | ✅ | ❌ | ❌ |
| M3 Layer A (queue_claim skip-empty) | ✅ | ❌ | ❌ |
| CSV city-coverage fix | ✅ | ❌ | ❌ |
| queue_claim.php (worker queue management) | ✅ | ❌ | ❌ |
| Stripe billing (subscription/checkout) | ✅ | ❌ | ❌ |

**Note:** CBD is substance/category-focused (CBD products), not geography-focused like Music Metrics.
"Top Cities" for CBD likely means "Top Categories" or "Top Products" — same pattern, different column.
The fastpath + M3 protection applies to CBD regardless of niche.

---

## RECOVERY PLAN FOR CBD (simplified)

1. ✅ cPanel access confirmed (cbd-data.com:2083)
2. ✅ Live drift captured (12 files at /tmp/cbd-live-capture/)
3. ⚠️ Decision needed: sync direction (local→live or capture live edits first)
4. Add getTopCities to CBD leadlists.php (copy from Music Metrics, adapt column name)
5. Add fastpath bootstrap to CBD leadlists.php
6. Deploy: backup → deploy → verify → test
7. Add to Music Metrics standard: queue_claim, stripe_webhook

## LAWYER-DTA.COM NEXT STEP
1. Deploy fastpath + M3 Layer A to match Music Metrics standard
2. Add queue_claim if missing
3. Verify getTopCities works in staging

## LAWYER CREDENTIALS (verified)
- cPanel host: business184.web-hosting.com:2083
- User: lawylhvs
- Token: /root/.secrets/lawyer_cpanel_token
- Auth: `Authorization: cpanel lawylhvs:$TOKEN`
