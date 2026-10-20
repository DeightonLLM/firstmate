# PROPOSED ONLY - Core Distro Product V3 Acceptance Specification

| Field | Value |
| --- | --- |
| Status | **Proposed and unratified** |
| Date | 2026-09-27 |
| Local evidence baseline | `2eb4e12d33106a71f3e7439c053df9080c4adca6` |
| Canonical editable source | `staged-export-test/` |
| Acceptance authority | Not identified in the available evidence |

> This document is a proposal, not a canonical product PRD, approved policy, or
> claim that Core Distro V3 is accepted. Every proposed criterion below requires
> explicit product-owner confirmation. Passing the local checks proves only the
> source contracts visible in this sanitized checkout. It does not prove runtime,
> production, infrastructure, or external-service behavior.

## 1. Purpose and authority boundary

The Core V3 gap map and its independent review agree that no canonical Core
Distro product V3 PRD or acceptance matrix was available. They also agree that
the six Core Distro checks in Brandon's infrastructure PRD section 20.1 are
infrastructure-readiness checks, not product requirements. This document fills
the documentation gap with a reviewable proposal derived from current local
source. It does not resolve the missing product authority.

No completion percentage is assigned. A product owner must ratify, amend, or
reject each proposed criterion and name the revision that becomes authoritative
before anyone uses this specification as a V3 release gate.

## 2. Evidence basis and precedence

The proposal uses the following evidence, in order of confidence:

1. Gap analysis: `/home/hd2admin/kun-agent-workspace/data/core-v3-prd-gap-map/report.md`
   dated 2026-09-26. It establishes the missing product acceptance source and
   separates Brandon infrastructure PRD section 20.1.
2. Independent review: `/home/hd2admin/kun-agent-workspace/data/core-v3-prd-gap-map-agy-review-20260926/report.md`
   dated 2026-09-26. It accepts the main gap finding and corrects path details.
3. Repository authority documents: `README.md`, `SOURCE_OF_TRUTH.md`,
   `LOCAL_DEVELOPMENT.md`, `RELEASE_METADATA.md`, and
   `SANITIZATION_MANIFEST.md`.
4. Offline harness: `bin/core-distro-local-check.sh` and
   `tests/local_lane_test.php`.
5. Current implementation under `staged-export-test/`, inspected at the local
   evidence baseline above.

The following files are context, not product authority:

- `staged-export-test/STAGING_STATUS.md` and
  `staged-export-test/RELEASE_CONTROL_AUDIT.md` describe Lawyer Data staging.
- `staged-export-test/LEAD_RATING_SYSTEM_PLAN.md` is labelled `DRAFT`.
- `staged-export-test/BRANDING_REPLACEMENT.md` contains operator replacement
  points and a Lawyer Data copy lock. It does not establish Core V3 copy policy.

Where source behavior and narrative documentation differ, this proposal records
the difference as an owner input. It does not silently turn current behavior into
policy.

## 3. Scope

### In scope

- Product contracts that can be inspected or checked from this local checkout.
- PHP and JavaScript syntax.
- Static source contracts for account access, authenticated navigation, lead
  lists, lead records, CSV portability, geographic discovery, scrape-job states,
  enrichment result handling, public list claims, and accessible feedback.
- The canonical-source boundary documented by `README.md` and
  `SOURCE_OF_TRUTH.md`.

### Out of scope

- Starting any runtime or local server.
- Deployment, DNS, HTTPS, rollback execution, or release promotion.
- Credentials, secret-bearing configuration, or production data.
- Database creation, migration, queries against a live database, persistence,
  backup, or restore.
- External APIs and services, including payment, email, maps, enrichment, GHL,
  and AnythingLLM.
- Browser automation or manual browser acceptance.
- Containers.
- Brandon infrastructure PRD section 20.1, except for the separate readiness
  inventory in section 9.

## 4. Acceptance semantics

All criteria begin in **UNRATIFIED** state.

- **RATIFIED** means the named product owner approved the exact wording, scope,
  and baseline revision.
- **PASS** means a ratified criterion met every listed pass condition at one
  recorded commit using only the required local access.
- **FAIL** means any listed pass condition failed.
- **NOT TESTED** means evidence was not run or was not retained.
- **OUT OF SCOPE** means the check requires any excluded capability in section 3.

A local V3 source-contract result may be reported only when every ratified,
in-scope criterion is `PASS`. That result must be called **local source-contract
acceptance**, not product, runtime, release, deployment, or infrastructure
acceptance.

### Required-access codes

| Code | Access |
| --- | --- |
| `L0` | Read-only access to this local checkout and standard shell tools. |
| `L1` | `L0` plus local PHP 8+ and Node.js, with no network, credentials, database, browser, or container. |

No proposed product criterion requires or permits access beyond `L1` in this
specification.

## 5. Concise proposed acceptance matrix

| ID | Proposed product outcome | Local pass evidence | Owner confirmation need | Access |
| --- | --- | --- | --- | --- |
| `PA-01` | Account access lifecycle is represented safely in source. | `T1`, `T2`; auth and reset sources | Ratify included routes and credential rules. | `L1` |
| `PA-02` | Authenticated product surfaces reject unauthenticated access. | `T1`, `T2`; dashboard and lead-list gates | Ratify the protected-surface inventory. | `L1` |
| `PA-03` | Users can manage only their own lead lists. | `T2`, `T3`; list action and ownership predicates | Ratify list operations and ownership rule. | `L0` |
| `PA-04` | Users can manage lead records and workflow fields within owned lists. | `T2`, `T3`; lead actions and ownership predicates | Ratify fields, states, and bulk operations. | `L0` |
| `PA-05` | CSV import/export preserves supported lead and searched-area data. | `T1`, `T2`; import/export source | Ratify the CSV schema and compatibility contract. | `L1` |
| `PA-06` | Add Leads exposes the nine source-observed geographic regions. | `T2`; region controls and state/city actions | Confirm the nine-region set is V3 policy. | `L0` |
| `PA-07` | Scrape-city jobs expose a bounded queued-to-terminal lifecycle. | `T1`, `T2`; queue actions and states | Ratify state names, cancellation, and concurrency intent. | `L1` |
| `PA-08` | Enrichment results update local lead contact/status projections. | `T2`; webhook and KPI source | Confirm enrichment belongs in V3 and approve its local result contract. | `L0` |
| `PA-09` | A deliberately public list can be claimed as a private copy. | `T2`, `T3`; public-list and claim source | Confirm that public sharing and both claim paths belong in V3. | `L0` |
| `PA-10` | Navigation and notifications retain the source-observed accessibility contracts. | `T1`, `T2`; index, theme, and toast source | Ratify supported languages, themes, and accessibility baseline. | `L1` |

## 6. Detailed proposed criteria

### PA-01 - Account access lifecycle

- **Proposed requirement:** Source must represent registration, login, logout,
  password-reset request, and single-use password reset. Password creation must
  use `password_hash(..., PASSWORD_DEFAULT)` and authentication must use
  `password_verify`.
- **Provenance:** `staged-export-test/INSTALL_README.md` under "Auth";
  `staged-export-test/login.php:5-54`;
  `staged-export-test/register.php:7-49`;
  `staged-export-test/forgot_password.php:8-29`;
  `staged-export-test/reset_password.php:8-56`;
  `staged-export-test/logout.php`; `tests/local_lane_test.php:35-47`.
- **Owner confirmation needed:** **Required.** Confirm that self-registration,
  email/password login, logout, and password reset are the intended V3 identity
  routes. Confirm or replace the source-observed six-character reset minimum.
- **PASS:** `T1` exits 0; `T2` finds password hashing in registration and reset,
  password verification in login, a random 32-byte reset token, a one-hour
  expiry, an unused-token predicate, a used-token update, and session
  destruction on logout.
- **FAIL:** Any required route or marker is absent, PHP syntax fails, a creation
  path stores the submitted password directly, or reset source lacks expiry and
  one-use handling.
- **Evidence path:** `tests/local_lane_test.php` output plus the source files
  listed above at the recorded commit.
- **Required access:** `L1`.

### PA-02 - Authenticated product boundary

- **Proposed requirement:** The dashboard and lead-list application must redirect
  unauthenticated users to login. The deterministic health action must return an
  unauthorized response when no authenticated identity is present.
- **Provenance:** `LOCAL_DEVELOPMENT.md` under "Local start path";
  `RELEASE_METADATA.md` under "Runtime health route";
  `staged-export-test/dashboard.php:64-83`;
  `staged-export-test/leadlists.php:17-28,2156-2218`;
  `tests/local_lane_test.php:49-52`.
- **Owner confirmation needed:** **Required.** Confirm that dashboard and lead
  lists are the minimum protected V3 surfaces and identify any other routes that
  must join this criterion.
- **PASS:** `T1` exits 0; `T2` finds the login redirects, `selfCheck` action, and
  unauthenticated HTTP 401 contract.
- **FAIL:** Either surface lacks its gate, the health action is missing, or the
  health action has no unauthenticated rejection marker.
- **Evidence path:** `tests/local_lane_test.php`, `staged-export-test/dashboard.php`,
  and `staged-export-test/leadlists.php` at the recorded commit.
- **Required access:** `L1`.

### PA-03 - Lead-list lifecycle and ownership

- **Proposed requirement:** An authenticated user can list, create, update,
  delete, inspect, and deliberately publish their lead lists. Non-public list
  operations must constrain records to the authenticated `user_id`.
- **Provenance:** Source-observed actions in
  `staged-export-test/leadlists.php:979-1192`, including `getLists`,
  `createList`, `updateList`, `deleteList`, `togglePublic`, `getListClaims`, and
  `getListDetail`.
- **Owner confirmation needed:** **Required.** Confirm the action inventory,
  whether public toggling belongs in V3, and whether deletion is hard deletion.
- **PASS:** `T2` finds every listed action. `T3` shows that list selection and
  mutations use the authenticated user identifier, except the separately
  ratified public-token flow in `PA-09`.
- **FAIL:** An action is absent, or a private read/update/delete query lacks the
  authenticated-user predicate.
- **Evidence path:** `staged-export-test/leadlists.php:979-1192` and the retained
  `T2`/`T3` output.
- **Required access:** `L0`.

### PA-04 - Lead-record lifecycle and workflow

- **Proposed requirement:** Within an owned list, an authenticated user can read,
  add, update, delete, and bulk-update lead records. Supported local workflow
  values are the source-observed lead states `cold`, `warm`, and `hot`, and
  pipeline states `new`, `contacted`, `engaged`, `client`, and `no_response`.
- **Provenance:** `staged-export-test/leadlists.php:1193-1532`, including
  `getLeads`, `getLeadDetail`, `getMapLeads`, `addLeads`, `updateLead`,
  `deleteLead`, `deleteLeads`, and `bulkUpdateLeads`; CSV validation at
  `staged-export-test/leadlists.php:1729-1733`.
- **Owner confirmation needed:** **Required.** Confirm the record operations,
  field allowlist, lead-state set, pipeline-state set, and whether score-driven
  state changes are accepted product behavior.
- **PASS:** `T2` finds every listed action and both state sets. `T3` shows that
  record reads and mutations use `user_id`, and that CSV input outside the
  observed state sets falls back to defined values.
- **FAIL:** An action or state is absent, a mutation accepts an unbounded field
  name, or an owned-record operation lacks the authenticated-user predicate.
- **Evidence path:** `staged-export-test/leadlists.php:1193-1532,1729-1733` and
  retained `T2`/`T3` output.
- **Required access:** `L0`.

### PA-05 - CSV portability and searched-area round trip

- **Proposed requirement:** CSV import and export must remain present; imports
  must accept the source-observed common header aliases; export/import must
  preserve searched-area city/state pairs through the `__SEARCHED_AREAS__`
  footer without requiring it for older or foreign CSVs.
- **Provenance:** `README.md` under "Contents"; `SOURCE_OF_TRUTH.md` under
  "Searched-Area Import/Export Round-Trip";
  `staged-export-test/DEFINITIVE_MANIFEST.md` under "Included Behavior";
  `staged-export-test/leadlists.php:1533-1812,2411-2535`;
  `tests/local_lane_test.php:61-64`.
- **Owner confirmation needed:** **Required.** Confirm the exported column schema,
  alias set, duplicate rule, and the searched-area footer as supported V3
  compatibility behavior.
- **PASS:** `T1` exits 0; `T2` finds both actions, CSV content type, alias
  normalization, the footer sentinel, footer parsing, and footer writing.
- **FAIL:** Either action or the sentinel is absent, import requires the optional
  footer, or searched-area source no longer reads and writes city/state pairs.
- **Evidence path:** `tests/local_lane_test.php`,
  `staged-export-test/leadlists.php:1533-1812,2411-2535`, and the recorded commit.
- **Required access:** `L1`.

### PA-06 - Geographic discovery coverage

- **Proposed requirement:** Add Leads must expose the nine source-observed region
  codes: `US`, `UK`, `EU`, `CA-LAT`, `CAR`, `AF`, `ME-CA`, `RU-CN`, and
  `SA-SEA-OC`, with source actions for loading states/regions and cities.
- **Provenance:** `staged-export-test/DEFINITIVE_MANIFEST.md` under "Included
  Behavior"; `staged-export-test/RELEASE_CONTROL_AUDIT.md` under "Core Distro
  Comparison"; `staged-export-test/leadlists.php:1865-1934,6769-6804`.
- **Owner confirmation needed:** **Required.** Confirm that all nine codes and
  their displayed meanings are Core V3 policy. The two narrative provenance
  files originated in the reconciled Lead Engine/Lawyer Data work and are not
  independently authoritative for Core.
- **PASS:** `T2` finds each region exactly in the Add Leads selector and finds the
  `getStates` and `getCities` actions.
- **FAIL:** A ratified region is missing or duplicated in the selector, or either
  lookup action is absent.
- **Evidence path:** `staged-export-test/leadlists.php:1865-1934,6769-6804` and
  retained `T2` output.
- **Required access:** `L0`.

### PA-07 - Scrape-city job lifecycle

- **Proposed requirement:** Local source must represent enqueue, claim, status,
  completion, failure, cancellation, and deduplication for city scrape jobs.
  The source-observed lifecycle is `queued` to `running` to one of `completed`,
  `failed`, or `cancelled`.
- **Provenance:** `LOCAL_DEVELOPMENT.md` and `RELEASE_METADATA.md` acceptance
  boundary; `staged-export-test/leadlists.php:1935-2334`;
  `tests/local_lane_test.php:54-59`.
- **Owner confirmation needed:** **Required.** Confirm the state names,
  cancellation semantics, duplicate-job rule, and the source-observed global
  active-job bound before treating them as product policy.
- **PASS:** `T1` exits 0; `T2` finds enqueue, next/status, cancel, claim, and
  complete actions plus every lifecycle state and the unique-job source marker.
- **FAIL:** Any ratified action/state is absent, or source allows a job to be
  claimed without changing it from queued to running.
- **Evidence path:** `tests/local_lane_test.php`,
  `staged-export-test/leadlists.php:1935-2334`, and the recorded commit.
- **Required access:** `L1`.

### PA-08 - Enrichment result projection and contact metrics

- **Proposed requirement:** Local callback source must reject malformed payloads,
  record failed/canceled provider outcomes, merge extracted emails and social links with
  existing values, update contact flags, and mark successful projection with
  `last_reenrich_decision = 'webhook_complete'`. Lead-list metrics must derive
  email/social presence from JSON contents rather than only migration-dependent
  flags.
- **Provenance:** `README.md` and `SOURCE_OF_TRUTH.md` completed-repair sections;
  `SANITIZATION_MANIFEST.md` under "Protected Runtime Files";
  `staged-export-test/webhook_scrape.php:4-150`;
  `staged-export-test/leadlists.php:494-495,727-728,2405`.
- **Owner confirmation needed:** **Required.** Confirm that enrichment is part of
  Core V3, that the observed terminal labels and merge behavior are intended,
  and that the current filtering rules are accepted. External provider behavior
  is not proposed or tested here.
- **PASS:** `T2` finds malformed-input handling, failed and completed status
  updates, unique merging, contact-flag updates, the webhook-complete decision,
  and `JSON_LENGTH` metrics for both emails and social links.
- **FAIL:** Any local projection marker is absent or successful projection
  replaces rather than merges the existing arrays.
- **Evidence path:** `staged-export-test/webhook_scrape.php`,
  `staged-export-test/leadlists.php`, and retained `T2` output.
- **Required access:** `L0`.

### PA-09 - Public list sharing and private claim copy

- **Proposed requirement:** Source may expose a list only when a 64-character
  hexadecimal token matches a list marked public. A new or existing user may
  claim it as a new private list through a transaction; the source list remains
  owned by its original user.
- **Provenance:** Source-observed behavior in
  `staged-export-test/leadlists.php:1093-1120` and
  `staged-export-test/public_list.php:7-149`.
- **Owner confirmation needed:** **Required.** Confirm that public sharing is in
  V3, that ten preview rows and full-copy claiming are intended, and that both
  signup and login claim paths are allowed.
- **PASS:** `T2` finds token length/type checks, the `is_public = 1` predicate,
  password hashing/verification for the two claim paths, transactions, new-list
  creation with `is_public = 0`, item copy, and claim audit insertion. `T3`
  confirms no non-public lookup bypass is present in this flow.
- **FAIL:** A non-public list can match, token shape is not checked, a claim writes
  into the source list, or a partial claim can commit outside the transaction.
- **Evidence path:** `staged-export-test/leadlists.php:1093-1120`,
  `staged-export-test/public_list.php:7-149`, and retained `T2`/`T3` output.
- **Required access:** `L0`.

### PA-10 - Accessible navigation and notification contracts

- **Proposed requirement:** Login fields must retain associated labels; mobile
  navigation must expose its controlled drawer and expanded state; theme and
  language selectors must expose their states; informational notifications use
  status semantics, warnings/errors use alert semantics, notification close
  controls have accessible names, and reduced-motion preferences are honored.
- **Provenance:** `SOURCE_OF_TRUTH.md` under "Canonical Toast Notification
  System"; `staged-export-test/index.php:552-563,951-959,1022-1028`;
  `staged-export-test/includes/theme_bootstrap.php:491,620-655`;
  `staged-export-test/assets/saas-toast.js:3-13,49,149,264-278`;
  `staged-export-test/assets/saas-toast.css:250-257`;
  `tests/local_lane_test.php:66-76`.
- **Owner confirmation needed:** **Required.** Confirm the supported language set
  (current source exposes English, Polish, and Spanish), the light/dark theme
  contract, and the accessibility baseline. No browser or WCAG conformance claim
  is made here.
- **PASS:** `T1` exits 0; `T2` finds login labels, mobile drawer ARIA state,
  theme/language ARIA state, toast roles, dismiss label, and reduced-motion CSS.
- **FAIL:** Any ratified source marker is absent or the JavaScript syntax check
  fails.
- **Evidence path:** `tests/local_lane_test.php` and the index, theme, toast JS,
  and toast CSS source paths listed above.
- **Required access:** `L1`.

## 7. Local-only test plan

The plan is deliberately limited to the sanitized checkout. Do not start PHP,
connect a database, load a browser, use credentials, call a service, build a
container, or deploy anything while executing it.

### T0 - Record the immutable local baseline

```bash
git rev-parse HEAD
git status --short
```

**Pass:** the commit is recorded and the status contains no unexplained changes.
The acceptance record must name the exact commit; a branch name alone is not
sufficient evidence.

### T1 - Run the repository offline harness

```bash
./bin/core-distro-local-check.sh
```

**Pass:** exit 0 with both `PASS local lane contracts` and `PASS syntax`.
This currently covers all PHP syntax, the canonical toast JavaScript syntax,
and the existing source assertions for auth, access gating, job states, CSV
round-trip markers, the health route, accessibility, and PHP-only ownership.

### T2 - Run proposed-criterion source assertions

Run from the repository root:

```bash
set -euo pipefail

need() {
  local file=$1 literal=$2
  rg -Fq -- "$literal" "$file" || {
    echo "FAIL missing in $file: $literal" >&2
    return 1
  }
}

need_once() {
  local file=$1 literal=$2 count
  need "$file" "$literal"
  count=$(rg -Fo -- "$literal" "$file" | wc -l | tr -d ' ')
  [ "$count" = 1 ] || {
    echo "FAIL expected once in $file, found $count: $literal" >&2
    return 1
  }
}

need staged-export-test/register.php 'password_hash($password, PASSWORD_DEFAULT)'
need staged-export-test/login.php "password_verify(\$password, \$user['password'])"
need staged-export-test/forgot_password.php 'random_bytes(32)'
need staged-export-test/forgot_password.php 'INTERVAL 1 HOUR'
need staged-export-test/reset_password.php 'expires_at > NOW() AND used = 0'
need staged-export-test/reset_password.php 'UPDATE password_resets SET used = 1'
need staged-export-test/logout.php 'session_destroy()'
need staged-export-test/dashboard.php "header('Location: login.php')"
need staged-export-test/leadlists.php "header('Location: login.php')"
need staged-export-test/leadlists.php "case 'selfCheck':"
need staged-export-test/leadlists.php 'http_response_code(401)'

for action in getLists createList updateList deleteList togglePublic getListClaims getListDetail \
              getLeads getLeadDetail getMapLeads addLeads updateLead deleteLead deleteLeads bulkUpdateLeads \
              importCSV exportCSV getStates getCities enqueueScrapeCities getNextCityJob \
              getScrapeQueueStatus cancelScrape claimScrapeCityJobs completeScrapeCityJob; do
  need staged-export-test/leadlists.php "case '$action':"
done

for region in US UK EU CA-LAT CAR AF ME-CA RU-CN SA-SEA-OC; do
  need_once staged-export-test/leadlists.php "data-country=\"$region\""
done

for state in "status = 'queued'" "status = 'running'" "['completed', 'failed', 'cancelled']"; do
  need staged-export-test/leadlists.php "$state"
done

need staged-export-test/leadlists.php "in_array(\$status, ['cold','warm','hot'])"
need staged-export-test/leadlists.php "in_array(\$pipeline, ['new','contacted','engaged','client','no_response'])"
need staged-export-test/leadlists.php 'UNIQUE KEY uniq_scrape_city_job'
need staged-export-test/leadlists.php "'max_active' => 4"
need staged-export-test/leadlists.php '__SEARCHED_AREAS__'
need staged-export-test/leadlists.php 'Content-Type: text/csv'
need staged-export-test/leadlists.php "'company' => 'business_name'"
need staged-export-test/leadlists.php "'phone_number' => 'phone'"
need staged-export-test/leadlists.php 'if (!$inSearchSection'
need staged-export-test/leadlists.php '$writeSearchedAreas = function'
need staged-export-test/leadlists.php "JSON_LENGTH(COALESCE(emails, '[]'))"
need staged-export-test/leadlists.php "JSON_LENGTH(COALESCE(social_media_links, '[]'))"
need staged-export-test/webhook_scrape.php "if (!\$data || !isset(\$data['id']))"
need staged-export-test/webhook_scrape.php "in_array(\$status, ['failed', 'canceled'])"
need staged-export-test/webhook_scrape.php 'array_unique(array_merge($existingEmails, $cleanEmails))'
need staged-export-test/webhook_scrape.php 'array_unique(array_merge($existingSocials, $socialLinks))'
need staged-export-test/webhook_scrape.php 'has_email = ?, has_socials = ?'
need staged-export-test/webhook_scrape.php "last_reenrich_decision = 'webhook_complete'"
need staged-export-test/public_list.php 'strlen($token) !== 64'
need staged-export-test/public_list.php 'ctype_xdigit($token)'
need staged-export-test/public_list.php 'l.is_public = 1'
need staged-export-test/public_list.php 'password_hash($password, PASSWORD_DEFAULT)'
need staged-export-test/public_list.php "password_verify(\$password, \$user['password'])"
need staged-export-test/public_list.php '$pdo->beginTransaction()'
need staged-export-test/public_list.php '$pdo->commit()'
need staged-export-test/public_list.php '$pdo->rollBack()'
need staged-export-test/public_list.php 'is_public, public_token) VALUES (?, ?, ?, 0, ?)'
need staged-export-test/public_list.php 'INSERT INTO lead_list_items (list_id, user_id, $cols)'
need staged-export-test/public_list.php 'INSERT INTO list_claims'
need staged-export-test/login.php '<label for="email">'
need staged-export-test/login.php '<label for="password">'
need staged-export-test/index.php 'aria-controls="mobile-drawer"'
need staged-export-test/includes/theme_bootstrap.php 'aria-pressed="false"'
need staged-export-test/includes/theme_bootstrap.php 'aria-haspopup="listbox"'
need staged-export-test/includes/theme_bootstrap.php "'en' => ['label' => 'English'"
need staged-export-test/includes/theme_bootstrap.php "'pl' => ['label' => 'Polski'"
need staged-export-test/includes/theme_bootstrap.php "'es' => ['label' => 'Español'"
need staged-export-test/assets/saas-toast.js "warning: 'alert'"
need staged-export-test/assets/saas-toast.js "success: 'status'"
need staged-export-test/assets/saas-toast.js 'Dismiss notification'
need staged-export-test/assets/saas-toast.css 'prefers-reduced-motion'

echo 'PASS proposed Core V3 local source assertions'
```

**Pass:** exit 0 with the final PASS line. These assertions prove presence, not
correct runtime behavior.

### T3 - Review ownership predicates locally

```bash
rg -n "case '(getLists|createList|updateList|deleteList|togglePublic|getListDetail|getLeads|getLeadDetail|getMapLeads|addLeads|updateLead|deleteLead|deleteLeads|bulkUpdateLeads|importCSV|exportCSV)'|user_id = \?" \
  staged-export-test/leadlists.php

rg -n "public_token|is_public = 1|beginTransaction|commit\(|rollBack\(|INSERT INTO list_claims" \
  staged-export-test/public_list.php
```

**Pass:** a reviewer records that each private list/lead read and mutation is
constrained by the authenticated user identifier, and that the only proposed
public exception matches `PA-09`. Presence of `user_id = ?` somewhere in the
file is not enough; review each listed action.

### T4 - Record results without expanding scope

The local acceptance record must contain:

- exact commit SHA;
- ratified specification revision;
- product owner and confirmation date;
- command, exit status, and complete stdout/stderr for `T1` and `T2`;
- reviewer name/date and action-by-action result for `T3`;
- one row per criterion with `PASS`, `FAIL`, or `NOT TESTED`;
- explicit statement that runtime, database, browser, services, deployment,
  infrastructure, and AnythingLLM were not tested.

## 8. Product-owner inputs still required

| Input | Why it is unresolved | Required disposition |
| --- | --- | --- |
| Acceptance authority | No canonical product PRD or owner-approved matrix is present. | Name the approving owner/role and ratification record. |
| V3 baseline | Current source behavior is evidence, not policy. | Name the exact commit/release to which the ratified spec applies. |
| Candidate criteria `PA-01` to `PA-10` | Each was distilled from local docs/source. | Ratify, amend, or reject each row. |
| Brand and language policy | Core-specific copy and supported-language requirements are absent. | Supply approved copy/brand source and the required language set. |
| Public list policy | Source contains tokenized preview and copy-on-claim behavior only. | Confirm inclusion, preview limit, and claim paths. |
| Lead scoring | A draft plan exists and current source contains scoring code. | Confirm whether scoring is V3, then provide approved formula/tier policy or exclude it. |
| Admin, billing, API keys/dashboard, and GHL | Source contains these surfaces, but no product acceptance authority establishes their V3 scope. Some depend on excluded external services. | Identify which are V3 product requirements and commission separate criteria. |
| Evidence retention | No canonical product acceptance evidence directory is present. | Name the repository or controlled evidence location and retention convention. |

Until these inputs are resolved, this proposal cannot support a statement that
Core Distro V3 is product-complete.

## 9. Separate infrastructure-readiness inventory

Brandon's `BRANDON_MULTI_PROJECT_INFRASTRUCTURE_PRD_V3.md` section 20.1 lists
the following Core Distro infrastructure checks:

1. Public site loads over HTTPS.
2. Quote/contact submission is durable.
3. Uploaded or downloadable documents respect authorization.
4. Any lead-enrichment job uses the Core queue and Core credentials only.
5. Core data does not appear in another project's database, logs, files, or
   backup.
6. Core backup restores successfully.

These are **not** product criteria in this specification. They require excluded
runtime, deployment, credential, database, external-system, isolation, or
restore access. The gap map records them separately as unknown or blocked. A
pass or failure in sections 5 through 7 must not change their status, and an
infrastructure result must not be counted as product acceptance.

## 10. Ratification block

This block is intentionally blank until an authorized owner acts.

| Field | Required value |
| --- | --- |
| Product owner / approving role | _Unresolved_ |
| Decision | _Ratify / amend / reject_ |
| Approved criteria and exclusions | _Unresolved_ |
| Applicable commit or release | _Unresolved_ |
| Evidence location | _Unresolved_ |
| Approval date and durable reference | _Unresolved_ |

Editing this table without a durable owner decision does not ratify the
specification.

## 11. Drafting validation record

On 2026-09-27, before this proposal was committed, the offline harness was run
at `2eb4e12d33106a71f3e7439c053df9080c4adca6` and returned:

```text
PASS local lane contracts: auth, lead-list/job states, CSV round-trip, health route, accessibility, PHP-only ownership
PASS syntax: 23 PHP files and 1 JavaScript asset
```

This is drafting evidence only. It does not ratify a criterion or constitute a
V3 product acceptance result.

A read-only `T3` review also found that the current `addLeads` action scopes
inserted rows to the authenticated `user_id` but does not first prove that the
submitted `list_id` belongs to that user. If `PA-04` is ratified as written, the
recorded baseline would not pass its owned-list condition without further
evidence or a source correction. No application source was changed during this
draft.
