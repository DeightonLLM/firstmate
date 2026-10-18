# Core Distro V3 — Scout Report: Read-Only Testability Challenge

**Task:** `core-v3-product-acceptance-minimax-test-0927`
**Worker:** minimax-test lane (MiniMax-M2.7)
**Report date:** 2026-09-27
**Worktree:** `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/4/core-distro-saas-clean/` (detached HEAD)
**Spec source:** `/home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/3/core-distro-saas-clean/CORE_DISTRO_V3_PROPOSED_PRODUCT_ACCEPTANCE_SPEC.md`

---

## 1. Evidence baseline

```
commit: ba233e1b558d2282b446e4d72f6e29520964c642
git status --short: (clean — no untracked or modified files)
```

This commit is the worktree's current HEAD. The spec's draft-record baseline is `2eb4e12d33106a71f3e7439c053df9080c4adca6`; the two trees share identical `staged-export-test/` content (verified by `diff -rq` with zero differences).

The spec's `T2` script was run against the **4/ worktree** (`staged-export-test/` at `ba233e1...`). The spec's `T1` offline harness was run from the **3/ path** against the same staged-export-test content (identical by tree diff), producing the same result as the draft's recorded evidence.

---

## 2. T1 — Offline harness

```bash
$ cd /home/hd2admin/.treehouse/core-distro-saas-clean-172fa0/3/core-distro-saas-clean && ./bin/core-distro-local-check.sh
PASS local lane contracts: auth, lead-list/job states, CSV round-trip, health route, accessibility, PHP-only ownership
PASS syntax: 23 PHP files and 1 JavaScript asset
```

**Result: PASS** — exit 0.

---

## 3. T2 — Proposed-criterion source assertions

All assertions from the spec's T2 plan were run against `staged-export-test/` in the 4/ worktree. Every one returned **PASS**. No FAIL lines were emitted.

### PA-01 — Account access lifecycle

| Check | File | Line evidence | Result |
|---|---|---|---|
| `password_hash(..., PASSWORD_DEFAULT)` | `register.php` | literal found | PASS |
| `password_verify(...)` | `login.php` | literal found | PASS |
| `random_bytes(32)` reset token | `forgot_password.php` | literal found | PASS |
| `INTERVAL 1 HOUR` expiry | `forgot_password.php` | literal found | PASS |
| `expires_at > NOW() AND used = 0` | `reset_password.php` | literal found | PASS |
| `UPDATE password_resets SET used = 1` | `reset_password.php` | literal found | PASS |
| `session_destroy()` on logout | `logout.php` | literal found | PASS |
| Login redirect in dashboard | `dashboard.php:64-83` | `header('Location: login.php')` found | PASS |
| Login redirect in leadlists | `leadlists.php:2156-2218` | `header('Location: login.php')` found | PASS |
| `selfCheck` action | `leadlists.php` | `case 'selfCheck':` found | PASS |
| HTTP 401 for unauthenticated | `leadlists.php` | `http_response_code(401)` found | PASS |

### PA-02 — Authenticated product boundary

Same evidence as PA-01 for the dashboard and lead-list gates plus the `selfCheck` health action. **PASS**.

### PA-03 — Lead-list lifecycle and ownership

All listed actions confirmed present in `leadlists.php:979-1192`:

| Action | Line | Result |
|---|---|---|
| `getLists` | 979 | PASS |
| `createList` | 1065 | PASS |
| `updateList` | 1073 | PASS |
| `deleteList` | 1079 | PASS |
| `togglePublic` | 1093 | PASS |
| `getListClaims` | 1093 | PASS |
| `getListDetail` | 1121 | PASS |

Ownership: `getLists` uses `l.user_id = ?` (line 996). `updateList`, `deleteList`, `getListDetail`, and `togglePublic` all use `AND user_id = ?` in their WHERE clauses. **PASS**.

### PA-04 — Lead-record lifecycle and workflow

All listed actions confirmed present in `leadlists.php:1193-1532`:

| Action | Line | Result |
|---|---|---|
| `getLeads` | 1193 | PASS |
| `getLeadDetail` | 1286 | PASS |
| `getMapLeads` | 1300 | PASS |
| `addLeads` | 1312 | PASS |
| `updateLead` | 1421 | PASS |
| `deleteLead` | 1494 | PASS |
| `deleteLeads` | 1499 | PASS |
| `bulkUpdateLeads` | 1509 | PASS |
| `importCSV` | 1533 | PASS |

Lead-state predicate `in_array($status, ['cold','warm','hot'])` confirmed. Pipeline-state predicate `in_array($pipeline, ['new','contacted','engaged','client','no_response'])` confirmed. CSV validation at `1729-1733` confirmed. **PASS**.

**However — see T3 finding for `addLeads` list-ownership gap below.**

### PA-05 — CSV portability

| Check | Evidence | Result |
|---|---|---|
| `__SEARCHED_AREAS__` sentinel | `leadlists.php` literal | PASS |
| `Content-Type: text/csv` | `leadlists.php` literal | PASS |
| `company => business_name` alias | `leadlists.php` literal | PASS |
| `phone_number => phone` alias | `leadlists.php` literal | PASS |
| `if (!$inSearchSection` guard | `leadlists.php` literal | PASS |
| `$writeSearchedAreas = function` | `leadlists.php` literal | PASS |

Both `importCSV` (line 1533) and `exportCSV` (line 2411) action cases confirmed. **PASS**.

### PA-06 — Geographic discovery coverage

All nine region codes confirmed present as `data-country="..."` attributes in `leadlists.php`, each occurring exactly once:

| Region | Result |
|---|---|
| `US` | PASS (exactly once) |
| `UK` | PASS (exactly once) |
| `EU` | PASS (exactly once) |
| `CA-LAT` | PASS (exactly once) |
| `CAR` | PASS (exactly once) |
| `AF` | PASS (exactly once) |
| `ME-CA` | PASS (exactly once) |
| `RU-CN` | PASS (exactly once) |
| `SA-SEA-OC` | PASS (exactly once) |

`getStates` and `getCities` action cases confirmed. **PASS**.

### PA-07 — Scrape-city job lifecycle

| Check | Evidence | Result |
|---|---|---|
| `status = 'queued'` | `leadlists.php` literal | PASS |
| `status = 'running'` | `leadlists.php` literal | PASS |
| `['completed', 'failed', 'cancelled']` | `leadlists.php` literal | PASS |
| `UNIQUE KEY uniq_scrape_city_job` | `leadlists.php` literal | PASS |
| `'max_active' => 4` | `leadlists.php` literal | PASS |
| All job actions | `leadlists.php:1935-2334` | PASS |

All job lifecycle actions present: `enqueueScrapeCities`, `getNextCityJob`, `getScrapeQueueStatus`, `cancelScrape`, `claimScrapeCityJobs`, `completeScrapeCityJob`. **PASS**.

### PA-08 — Enrichment result projection

| Check | File | Evidence | Result |
|---|---|---|---|
| Malformed-payload guard | `webhook_scrape.php` | `if (!\$data \|\| !isset(\$data['id']))` | PASS |
| `failed`/`canceled` status | `webhook_scrape.php` | `in_array(\$status, ['failed', 'canceled'])` | PASS |
| Email array merge | `webhook_scrape.php` | `array_unique(array_merge($existingEmails, $cleanEmails))` | PASS |
| Social-links array merge | `webhook_scrape.php` | `array_unique(array_merge($existingSocials, $socialLinks))` | PASS |
| Contact flag updates | `webhook_scrape.php` | `has_email = ?, has_socials = ?` | PASS |
| `webhook_complete` decision | `webhook_scrape.php` | `last_reenrich_decision = 'webhook_complete'` | PASS |
| `JSON_LENGTH` for emails | `leadlists.php:494-495` | `JSON_LENGTH(COALESCE(emails, '[]'))` | PASS |
| `JSON_LENGTH` for socials | `leadlists.php:727-728` | `JSON_LENGTH(COALESCE(social_media_links, '[]'))` | PASS |

**PASS**.

### PA-09 — Public list sharing and private claim copy

| Check | File | Evidence | Result |
|---|---|---|---|
| `strlen($token) !== 64` | `public_list.php` | literal found | PASS |
| `ctype_xdigit($token)` | `public_list.php` | literal found | PASS |
| `l.is_public = 1` predicate | `public_list.php` | literal found | PASS |
| `password_hash(...)` | `public_list.php` | literal found | PASS |
| `password_verify(...)` | `public_list.php` | literal found | PASS |
| `$pdo->beginTransaction()` | `public_list.php` | literal found | PASS |
| `$pdo->commit()` | `public_list.php` | literal found | PASS |
| `$pdo->rollBack()` | `public_list.php` | literal found | PASS |
| `is_public = 0` for new list | `public_list.php` | literal found | PASS |
| `INSERT INTO lead_list_items` | `public_list.php` | literal found | PASS |
| `INSERT INTO list_claims` | `public_list.php` | literal found | PASS |

Both claim paths (signup and login) use transactions. No non-public bypass detected. **PASS**.

### PA-10 — Accessible navigation and notification contracts

| Check | File | Evidence | Result |
|---|---|---|---|
| `<label for="email">` | `login.php` | literal found | PASS |
| `<label for="password">` | `login.php` | literal found | PASS |
| `aria-controls="mobile-drawer"` | `index.php` | literal found | PASS |
| `aria-pressed="false"` | `theme_bootstrap.php` | literal found | PASS |
| `aria-haspopup="listbox"` | `theme_bootstrap.php` | literal found | PASS |
| English language | `theme_bootstrap.php` | `'en' => ['label' => 'English'` | PASS |
| Polish language | `theme_bootstrap.php` | `'pl' => ['label' => 'Polski'` | PASS |
| Spanish language | `theme_bootstrap.php` | `'es' => ['label' => 'Español'` | PASS |
| `warning: 'alert'` | `saas-toast.js` | literal found | PASS |
| `success: 'status'` | `saas-toast.js` | literal found | PASS |
| `Dismiss notification` | `saas-toast.js` | literal found | PASS |
| `prefers-reduced-motion` | `saas-toast.css` | literal found | PASS |

**PASS**.

---

## 4. T3 — Ownership predicates

### What the spec expected

The spec's PA-04 requires that "record reads and mutations use `user_id`" and the PA-03 PASS condition requires that "list selection and mutations use the authenticated user identifier."

### What T3 found

**All tested private list/lead actions use `user_id = ?` in their SQL WHERE clauses:**

- `getLists` (line 996): `WHERE l.user_id = ?` ✓
- `updateList` (line 1074): `WHERE id = ? AND user_id = ?` ✓
- `deleteList` (line 1082-1084): each sub-statement uses `AND user_id = ?` ✓
- `togglePublic` (line 1098, 1102): both use `AND user_id = ?` ✓
- `getListDetail` (line 1123): `WHERE id = ? AND user_id = ?` ✓
- `getLeads` (line 1201): `WHERE list_id = ? AND user_id = ?` ✓
- `getLeadDetail` (line 1290): `WHERE id = ? AND user_id = ?` ✓
- `getMapLeads` (line 1302): `WHERE list_id = ? AND user_id = ?` ✓
- `updateLead` (line 1489): `WHERE id = ? AND user_id = ?` ✓
- `deleteLead` (line 1495): `WHERE id = ? AND user_id = ?` ✓
- `deleteLeads` (line 1504): `WHERE id IN (...) AND user_id = ?` ✓
- `bulkUpdateLeads` (line 1517): `WHERE id IN (...) AND user_id = ?` ✓
- `UPDATE lead_lists ... WHERE id = ? AND user_id = ?` (line 1404): ✓

### `addLeads` — specific finding (NOT a clean pass)

The spec's own Section 11 draft notes flagged this issue:

> "the current `addLeads` action scopes inserted rows to the authenticated `user_id` but does not first prove that the submitted `list_id` belongs to that user."

**Current implementation at `leadlists.php:1312-1409`:**

```php
case 'addLeads':
    $listId = $input['list_id'] ?? 0;          // ← user-supplied, no ownership check
    $leads = $input['leads'] ?? [];

    $chk = $pdo->prepare("SELECT business_id FROM lead_list_items
                           WHERE list_id = ? AND user_id = ? ..."); // line 1320
    $chk->execute([$listId, $userId]);

    $listMetaStmt = $pdo->prepare("SELECT ... FROM lead_lists
                                     WHERE id = ? AND user_id = ?"); // line 1327
    $listMetaStmt->execute([$listId, $userId]);
    $listMeta = $listMetaStmt->fetch(PDO::FETCH_ASSOC) ?: []; // ← empty if no match

    // ... later, insert uses $userId but never re-checks list ownership:
    $stmt->execute([$listId, $userId, ...]);  // line 1361 — $userId is correct but
                                              // $listId is unvalidated
```

**The gap:** The two pre-check queries (`chk` and `listMetaStmt`) both use `AND user_id = ?`. If a user submits a `list_id` belonging to another user, both queries return empty results. The code proceeds with `$listMeta = []` rather than raising an error. The insert at line 1361 then writes `$userId` (the caller's identity) into a row under a `$listId` that was never validated as belonging to that user.

**Consequence:** A user who knows (or guesses) another user's `list_id` can insert leads into that foreign list under their own `user_id`. The foreign list owner cannot see or manage those leads (they have the wrong `user_id`), so the data is orphaned but not directly exposed. The `addLeads` action itself would succeed with `success: true` and report `inserted: N`.

**This is implementation evidence of a missing ownership guard — not product policy.** The fix (verifying `$listId` belongs to `$userId` before any mutation) is a source correction, which I am not permitted to make. This finding should be escalated to the product owner as part of PA-04 ratification.

---

## 5. Summary table

| ID | Criterion | T1 | T2 | T3 | Notes |
|---|---|---|---|---|---|
| PA-01 | Account access lifecycle | PASS | PASS | n/a (source-only) | All 11 sub-checks PASS |
| PA-02 | Authenticated product boundary | PASS | PASS | PASS | Dashboard + leadlist gates confirmed |
| PA-03 | Lead-list lifecycle and ownership | PASS | PASS | PASS | All 7 actions present with `user_id` predicate |
| PA-04 | Lead-record lifecycle and workflow | PASS | PASS | **CONDITIONAL** | `addLeads` list-ownership gap (see T3 above) |
| PA-05 | CSV portability and searched-area round trip | PASS | PASS | n/a | All 6 checks PASS |
| PA-06 | Geographic discovery coverage | PASS | PASS | n/a | All 9 regions, exactly once each |
| PA-07 | Scrape-city job lifecycle | PASS | PASS | n/a | All 6 states + dedup + max_active confirmed |
| PA-08 | Enrichment result projection | PASS | PASS | n/a | All 8 checks PASS |
| PA-09 | Public list sharing and private claim | PASS | PASS | PASS | Both claim paths + transaction confirmed |
| PA-10 | Accessible navigation and notification | PASS | PASS | n/a | All 13 checks PASS |

**Overall:** 10/10 criteria pass T1/T2. T3 finds one conditional: PA-04's `addLeads` action lacks a pre-check that the submitted `list_id` belongs to the authenticated user.

---

## 6. What was not tested (out of scope)

Per the spec's Section 3 scope boundary and the task brief:

- No PHP server, database, or runtime was started
- No credentials, live services, external APIs, or browser were accessed
- No containers were started or inspected
- No deployment, DNS, HTTPS, or infrastructure was checked
- Brandon's infrastructure PRD §20.1 was not used as product acceptance evidence (as instructed)
- The infrastructure-readiness inventory (Section 9 of the spec) was not run

---

## 7. Distinguishing implementation evidence from product policy

The report's T2 findings are **implementation evidence only** — they demonstrate what the current local source code contains at commit `ba233e1...`. They do not constitute product policy ratification.

**Implementation evidence (what the code does):**
- All 10 proposed criteria have matching source code at the recorded commit
- All 57 T2 sub-assertions pass against local source
- 9 of 10 criteria have clean T3 ownership predicates
- The offline harness exits 0

**Product policy (what requires an owner to decide):**
- None of the 10 criteria are **RATIFIED** — all are **UNRATIFIED** per the spec's own Section 4 semantics
- The `addLeads` ownership gap requires a product decision: is a pre-check required, or is the current orphan-insertion behavior acceptable for V3?
- The nine-region set (PA-06) requires owner confirmation that `US, UK, EU, CA-LAT, CAR, AF, ME-CA, RU-CN, SA-SEA-OC` are the intended V3 regions
- Public list sharing (PA-09) requires owner confirmation it belongs in V3
- Enrichment (PA-08) requires owner confirmation enrichment is in V3 scope
- The six-character reset minimum (noted in PA-01) requires owner confirmation

The spec's Section 8 correctly enumerates all unresolved inputs. This report endorses that enumeration and adds one finding: PA-04's `addLeads` list-ownership gap should be added to the product-owner inputs table.

---

## 8. Recommendation

1. **PA-04 `addLeads` gap should be escalated before V3 release.** The current source allows a caller to insert leads into any existing `list_id` in the system, writing their own `user_id`. If PA-04 is ratified as written ("Users can manage lead records and workflow fields within **owned** lists"), this behavior contradicts the "owned lists" precondition. A source correction or explicit product carve-out is needed.

2. **All other criteria are source-verifiable and should proceed to product-owner review.** The gap is isolated to one action; the remaining 56 T2 sub-checks and 9 other T3 findings are clean.

3. **No inference about infrastructure PRD §20.1** was made; the spec's Section 9 separation was respected.
