# BR-AUD-002 — Core Distro Application Audit Report
**Task:** BR-AUD-002 | **Phase:** Phase 1 | **Campaign:** Brandon Multi-Project Infrastructure
**Generated:** 2026-08-06 | **Runtime model:** MiniMax-M2.7
**Scope:** Read-only local source audit; campaign artifacts only; no live infrastructure mutation
**Source repo:** `/root/agent-work/deightonllm-firstmate/projects/core-distro.com/`
**PRD baseline:** `Brandon-Multi-Project-Infrastructure-PRD-v3.md`

---

## Audit Summary

Core Distro is a PHP SaaS B2B lead-generation platform currently deployed on Contabo cPanel (production) and AminoVPS (Next.js staging). The application manages authenticated sessions, subscriptions, credits, business-data searches via RapidAPI, AI-powered enrichment via Replicate, CRM sync via GoHighLevel, and CSV export workflows. The application is **NOT a pharmaceutical/lab-supply catalog** as described in PRD v3 §2.1 — that description appears to be a mis-classification of the PRD; the actual application is a multi-tenant SaaS lead-generation tool that can be rebranded per product (Core Distro, CBD-Data share the same codebase).

The most significant finding is that the PRD v3 targets PostgreSQL for the primary database, but the live production system uses **MySQL/Percona 8.4** — a database engine migration would be required to align with the PRD target architecture.

---

## §1 — Runtime and Source Layout

### §1a — PHP SaaS Application

| Field | Value | Evidence |
|:------|:------|:---------|
| Repository | `DeightonLLM/core-distro-saas-clean` (main branch, HEAD `ba233e1`) | `BR-AUD-001/repository-inventory.md` §1a; confirmed via prior lane-001 worktree |
| Local staged source | `/root/agent-work/deightonllm-firstmate/projects/core-distro.com/current-core-distro/` | Direct inspection |
| Shared codebase | Core Distro and CBD-Data PHP SaaS share `core-distro-saas-clean` with per-tenant branding constants | `BR-AUD-001/repository-inventory.md` §5; `SAAS_SOURCE_OF_TRUTH_VERSION_CONTROL_AUDIT_20260711.md` |
| Production deploy host | Contabo cPanel (`business190.web-hosting.com`) — `public_html` via `core_distro` guarded helpers | `BR-AUD-001/repository-inventory.md` §1c; `BATCH_B_CORE_DISTRO_SOURCE_HANDOFF_20260802.md` §3 |
| Staging/runtime host | AminoVPS (`srv1137994-aminolifesciences`); Tailscale IP `100.69.211.43` | `BR-AUD-001/repository-inventory.md` §1d; `BR-INV-001/report.md` |
| Staging service | Next.js 15 App Router (static export); systemd unit `core-distro-staging.service`; bound to `127.0.0.1:3113` | `BR-INV-001/report.md`; `aminovps-ports.md` |
| Production Next.js port | `127.0.0.1:3117` (registered in ports manifest; not yet started) | `aminovps-ports.md`; `BR-AUD-001/repository-inventory.md` §1d |
| Next.js Git remote | **NONE** — provisioned via zip transfer on AminoVPS; no GitHub credentials on that host | `BR-AUD-001/repository-inventory.md` §1b |
| Deployment model | PHP app: cPanel file-manager deploy; Next.js: local `next build` → static export → zip → cPanel upload | Source inspection; `BR-AUD-001/repository-inventory.md` §1c |
| Canonical export artifact | `lead-engine-saas-export-20260625_canonical-geo.zip` — SHA-256 `f05e69bae3a28ce69d2dd10ad476f24ca4e1c23816ae53e24b25d7fd2cceefc7` | Lane-001 artifact; `BR-AUD-001/repository-inventory.md` §1c |

### §1b — Source File Inventory (staged snapshot)

| File | Purpose | Lines (approx.) |
|:-----|:--------|---------------:|
| `index.php` | Public landing page with auth modal, pricing, Stripe checkout | ~600 |
| `dashboard.php` | Authenticated app shell with sidebar navigation | ~850 |
| `leadlists.php` | Core application logic: search, queue, enrichment, GHL sync, CSV export | ~11,900 |
| `includes/theme_bootstrap.php` | Theme/color system and logo utilities | ~590 |
| `config/README.md` | Placeholder confirming runtime config excluded from git | — |
| `.htaccess` | Apache rewrite: www→apex, HTTP→HTTPS | — |

Config files intentionally absent from git (excluded per `config/README.md`):
- `config/database.php` — DB connection (excluded)
- `config/stripe_config.php` — Stripe keys (excluded)
- `config/subscription_config.php` — Plan constants (excluded)
- `config/rapidapi.php` — RapidAPI credentials (excluded)
- `includes/auth.php` — Session/auth helpers (excluded)

---

## §2 — Build and Start Path

### Build Process

1. **PHP application**: No build step — PHP files are deployed directly via cPanel file-manager. Composer is present on Contabo per BR-INV-001 (`composer 2.8.12`), but no `composer.json` is present in the staged source snapshot. The application relies on bundled or core PHP extensions only.
2. **Next.js staging**: `cd /opt/core-distro-staging/current/ && npm run build` → `next build` → `output: "export"` → static HTML/CSS/JS → zipped → transferred to cPanel `public_html`
3. **Production static**: `core_distro` guarded helpers → cPanel `public_html` directory → served by Apache/mod_php

### Start Path

- **Production PHP**: Apache/mod_php on Contabo; `.htaccess` handles routing (redirect www→apex, HTTP→HTTPS)
- **Next.js staging**: `core-distro-staging.service` (systemd) → Node.js process → `127.0.0.1:3113`
- **Next.js production**: Registered at `127.0.0.1:3117`; systemd unit name **UNKNOWN**

### Ports and Service Boundaries

| Service | Host | Address | Notes |
|:--------|:-----|:--------|:------|
| Production PHP app | Contabo cPanel | Public HTTPS (443) via Cloudflare | Served from `public_html` |
| Next.js staging | AminoVPS | `127.0.0.1:3113` | Tailscale-only; systemd `core-distro-staging.service` |
| Next.js production | AminoVPS | `127.0.0.1:3117` | Registered; systemd unit **UNKNOWN**; not started |
| MySQL/Percona | AminoVPS | `127.0.0.1:3306` (implied) | Percona Server `8.4.10-10` per BR-INV-001 |
| Reverse proxy (nginx) | AminoVPS | Active per BR-INV-001 | Fronting staging and production Next.js |

**Public ports on Contabo**: Standard cPanel ports (80/443); specific internal service ports **UNKNOWN** from source inspection.

---

## §3 — Database Engine: RESOLVED — MySQL/Percona (NOT PostgreSQL)

### Resolution

**The application runs on MySQL/Percona 8.4, not PostgreSQL. This is a confirmed fact from source code inspection. The PRD v3 §8.1 targets PostgreSQL as the desired placement — a database engine migration is an outstanding architectural decision.**

### Evidence: MySQL-Specific SQL Throughout Source

| SQL Pattern | Location | Significance |
|:------------|:---------|:-------------|
| `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4` | `leadlists.php` line ~608 | MySQL-only storage engine declaration |
| `SHOW TABLES LIKE ...` | `dashboard.php` | MySQL-specific; PostgreSQL uses `pg_class` |
| `SHOW COLUMNS FROM ... LIKE ...` | `leadlists.php` line 34 | MySQL-specific; PostgreSQL uses `information_schema.columns` with different query syntax |
| `SHOW INDEX FROM ... WHERE Key_name = ...` | `leadlists.php` line 42 | MySQL-specific `SHOW` command |
| `DATE_ADD(NOW(), INTERVAL ? DAY)` | `leadlists.php` line 133 | MySQL date functions |
| `information_schema.tables WHERE table_schema = DATABASE()` | `leadlists.php` line 2095 | MySQL `information_schema` (PostgreSQL uses `information_schema.table_name` without `table_schema`) |
| `ON DUPLICATE KEY UPDATE` | `leadlists.php` line 133 | MySQL-specific upsert syntax |
| `JSON` type (JSON columns) | Multiple `ADD COLUMN` statements | MySQL 5.7+/Percona 8 JSON column support |

### PRD Target vs. Current Fact

| Dimension | PRD v3 Target | Current Fact | Gap |
|:----------|:---------------|:-------------|:----|
| Database engine | PostgreSQL | MySQL/Percona 8.4.10-10 | **ADR-006 decision required** |
| Shared cluster | One PostgreSQL cluster, one DB per project | One Percona cluster, shared across Core Distro + CBD-Data | Isolation needed |
| Role model | Per-project owner/migrate/api/ingest/readonly roles | No evidence of role separation in source | Not implemented |
| PgBouncer | Connection pooling in front of PostgreSQL | No connection pooling evidence in source | Not implemented |

---

## §4 — Environment Variables (Names Only — No Values)

The following environment variable and constant names appear in source code. **No secret values appear in any audited source file.**

| Variable Name | Type | Purpose | Config File |
|:--------------|:-----|:--------|:------------|
| `APP_NAME` | Constant | Application display name (e.g., "Core-Distro") | `config/database.php` (implied) |
| `APP_URL` | Constant | Public URL base (e.g., `https://core-distro.com`) | `config/database.php` (implied) |
| `BRAND_COLOR` | Constant | Primary brand accent hex color | `config/database.php` (implied) |
| `THEME_MODE` | Constant | Light/dark default theme | `config/database.php` (implied) |
| `STRIPE_PUBLISHABLE_KEY` | Constant | Stripe public key | `config/stripe_config.php` (excluded) |
| `STRIPE_SECRET_KEY` | Constant | Stripe secret key | `config/stripe_config.php` (excluded) |
| `STRIPE_WEBHOOK_SECRET` | Constant | Stripe webhook signature verification | `config/stripe_config.php` (excluded) |
| `STRIPE_PRICE_STARTER` | Constant | Stripe price ID for Starter plan | `config/subscription_config.php` (excluded) |
| `STRIPE_PRICE_GROWTH` | Constant | Stripe price ID for Growth plan | `config/subscription_config.php` (excluded) |
| `PLAN_STARTER_PRICE` | Constant | Starter plan numeric price (e.g., `$49`) | `config/subscription_config.php` (excluded) |
| `PLAN_GROWTH_PRICE` | Constant | Growth plan numeric price | `config/subscription_config.php` (excluded) |
| `SUPPORT_EMAIL` | Constant | Customer support email address | `config/subscription_config.php` (excluded) |
| `DB_SCHEMA_PROBE_TOKEN` | Env via `env()` | Probe token for schema introspection (read-only) | `config/database.php` |
| `RAPIDAPI_KEY` | Constant | RapidAPI key for business-data scraping provider | `config/rapidapi.php` (excluded) |
| `RAPIDAPI_HOST` | Constant | RapidAPI host header for scraping API | `config/rapidapi.php` (excluded) |
| `REPLICATE_API_KEY` | Constant | Replicate AI platform key for enrichment | `config/rapidapi.php` (excluded) |
| `GHL_API_KEY` / `ghl_api_key` | DB column + config | GoHighLevel CRM API key | `config/database.php` (implied) |
| `GHL_LOCATION_ID` / `ghl_location_id` | DB column + config | GoHighLevel location ID | `config/database.php` (implied) |

**Note**: Config files are explicitly excluded from the git repository. The canonical deployment artifacts for secrets are Coolify secret store (per PRD v3 §11.2). No `.env` files are present in the staged source.

---

## §5 — Data Classes

### §5a — Database Schema (Discovered from Source Code)

| Table | Purpose | Key Columns | Data Class |
|:------|:--------|:------------|:-----------|
| `users` | Customer accounts | `id`, `email`, `password_hash`, `credits`, `subscription_plan`, `is_admin`, `shared_for_credits`, `ghl_api_key`, `ghl_location_id`, `last_active_at` | **Confidential** (auth credentials restricted); email/name = confidential |
| `credit_transactions` | Credit purchase ledger | `user_id`, `credits`, `amount`, `transaction_id` (Stripe `payment_intent`) | **Confidential** (payment data) |
| `lead_lists` | Named lead collections | `id`, `user_id`, `name`, `is_public`, `public_token`, `icon_class`, `icon_color`, `category_group`, `category` | **Confidential** (business data) |
| `lead_list_items` | Individual lead records | `business_name`, `address`, `city`, `state`, `phone`, `website`, `emails` (JSON), `social_media_links` (JSON), `rating`, `review_count`, `types`, `latitude/longitude`, `ghl_contact_id`, `lead_score`, `status`, `pipeline_stage`, `enrichment_status`, `replicate_id` | **Confidential** (B2B contact data — name, email, phone, social) |
| `lead_list_searches` | Search history | `list_id`, `search_query`, `state_name`, `city`, `results_count`, `scrape_limit`, `duration_ms`, `provider`, `country_code`, `cached` | **Internal** (operational metadata) |
| `lead_list_search_cache` | RapidAPI response cache | `provider`, `cache_key`, `response_json`, `response_bytes`, `expires_at`, `hit_count` | **Internal** (operational; contains API response data) |
| `scrape_city_jobs` | City-scrape job queue (DB-backed) | `user_id`, `list_id`, `country`, `state_name`, `city`, `search_query`, `status` ('queued'), `run_id` | **Internal** (job queue) |
| `ghl_connections` | CRM integrations | `user_id`, `api_key`, `location_id` | **Restricted** (CRM credentials) |
| `ghl_import_logs` | CRM import jobs | `list_id`, `status`, `total_contacts`, `imported`, `drip_*` columns | **Internal** (job tracking) |
| `ghl_import_items` | CRM import item status | `lead_id`, `ghl_contact_id`, `status` | **Internal** |
| `geo_cities` | Geographic reference data | `city_name`, `state_name`, `country_code`, `population` | **Public/Reference** |
| `geo_countries` | Country reference data | `country_name`, `country_code`, `geo_region_code` | **Public/Reference** |
| `api_calls` | API usage tracking | `user_id`, `credits_used`, `scraper_model`, `url` | **Internal** |
| `migration_markers` | Schema migration flags | `marker_name` | **Internal** |

### §5b — Data Sensitivity Summary

| Data Type | Classification | Evidence |
|:----------|:--------------|:---------|
| User credentials (passwords) | **Restricted** | Password hashes stored in `users`; PHP `password_hash()` used (assumed; `includes/auth.php` excluded from snapshot) |
| Stripe payment tokens | **Restricted** | `payment_intent` stored in `credit_transactions` |
| GHL API keys | **Restricted** | Stored in `ghl_connections` and `users.ghl_api_key` |
| Business contact data (emails, phones, names) | **Confidential** | B2B lead data in `lead_list_items` |
| Lead search queries and results | **Confidential** | Business strategy data |
| Scraped data from RapidAPI | **Confidential** | Enriched business records |
| Geographic reference data | **Public** | `geo_cities`, `geo_countries` |
| Job queue state | **Internal** | `scrape_city_jobs` |

### §5c — No PHI/Regulated Data Evidence

Source code inspection reveals **no evidence of PHI, prescription data, clinical records, or regulated health information** in the Core Distro PHP SaaS application. The application stores B2B business contact data (company names, emails, phones, websites). This is consistent with the PRD v3 §2.1 note that PHI must not be assumed — the application currently does not process it.

---

## §6 — Health Checks

| Endpoint | Host | Status | Evidence |
|:---------|:-----|:-------|:---------|
| Public HTTP/HTTPS | Contabo cPanel | **UNKNOWN** from source | No health probe file in staged snapshot; cPanel uptime assumed |
| Next.js staging health | AminoVPS `127.0.0.1:3113` | **UNKNOWN** | No `/health` or `/status` route in staged Next.js source; `next.config.ts` not present in snapshot |
| Next.js production health | AminoVPS `127.0.0.1:3117` | **UNKNOWN** | Registered but not started |
| Database health | AminoVPS | **UNKNOWN** | `dashboard.php` line ~26: `$pdo->query('SELECT 1')` — in-app DB reachability check; no dedicated health endpoint |
| Queue health | In-process | **UNKNOWN** | No dedicated queue health endpoint; `scrape_city_jobs.status` checked via app logic |
| External status page | **UNKNOWN** | No evidence in source | No `status.php`, `health.php`, or monitoring agent in staged snapshot |

**Finding**: No application-level health endpoints (`/health`, `/status`) are present in the staged PHP or Next.js source. A health endpoint strategy must be designed as part of the PRD-required monitoring layer (PRD v3 §14).

---

## §7 — Migrations and Database Posture

### Migration Strategy: PHP Auto-Migration (In-Application)

The application uses **in-process, lazy PHP auto-migration** rather than a formal migration tool. No Phinx, Doctrine, Alembic, or Flyway is used.

Evidence from `leadlists.php` and `dashboard.php`:
- `$pdo->query("SELECT 1 FROM <table> LIMIT 1")` — existence check
- `$pdo->exec("CREATE TABLE ...") `— create if absent
- `SHOW COLUMNS FROM <table> LIKE <column>` — column existence check
- `$pdo->exec("ALTER TABLE <table> ADD COLUMN ...") `— add if absent
- `migration_markers` table — guards one-time backfill operations

**Risks of in-process migration**:
- Race condition: two concurrent requests can both attempt the same `ALTER TABLE` simultaneously
- No rollback mechanism: `ALTER TABLE` is applied on every request until the column/table exists
- No version history: impossible to determine which schema version is deployed
- No dry-run capability: changes apply immediately

### Migration Pattern Example (from `dashboard.php`)

```php
try {
    $tableExists = $pdo->query("SHOW TABLES LIKE 'api_calls'")->rowCount() > 0;
    if (!$tableExists) {
        $pdo->exec("CREATE TABLE api_calls (...)");
    }
} catch (PDOException $e) { error_log("Table creation error: " . $e->getMessage()); }
```

### Database Posture: Single-tenant DB Serving Two Products

Per BR-AUD-001 §5 (shared repository note):
- **Core Distro and CBD-Data share the same Percona MySQL instance on AminoVPS**
- Separate databases per project (per PRD v3 §8.1) are **NOT yet implemented**
- Database isolation is an outstanding architecture decision (ADR-006)

### Schema State

| Dimension | Current State | PRD Target | Gap |
|:----------|:--------------|:-----------|:----|
| Engine | MySQL/Percona 8.4 | PostgreSQL | Migration needed |
| Isolation | Shared Percona instance | One DB per project | Separation needed |
| Connection pooling | None | PgBouncer | Tooling needed |
| Migration tool | In-process PHP | Version-controlled migration tool | Tooling needed |
| Backup | **UNKNOWN** | Per-project encrypted backups | Not evidenced |

---

## §8 — Queue and Worker Dependencies

### Queue: MySQL-backed (No RabbitMQ Currently)

The application uses a **MySQL/Percona-backed job queue** implemented via the `scrape_city_jobs` table. This is **not RabbitMQ** — RabbitMQ is a PRD v3 §7.2 target for Hetzner, not the current implementation.

| Queue Characteristic | Current Implementation | Evidence |
|:---------------------|:-----------------------|:---------|
| Queue backend | MySQL `scrape_city_jobs` table | `leadlists.php` line 675: `CREATE TABLE scrape_city_jobs` |
| Queue operations | `INSERT` (enqueue), `UPDATE status='queued/running/completed'` (dequeue) | `leadlists.php` lines 1882–1941: `case 'enqueueScrapeCities'` |
| Queue status field | `status VARCHAR(20)` — values: `'queued'`, `'running'`, `'completed'`, `'failed'`, `'paused'` | `leadlists.php` line 683 |
| Idempotency | `UNIQUE KEY uniq_scrape_city_job (user_id, list_id, country, state_name, city, search_query)` | `leadlists.php` line 691 |
| Concurrency control | `locked_at` + `run_id` columns for optimistic locking | `leadlists.php` lines 688, 1984+ |
| Dead-letter queue | **NONE** — failed jobs marked `status='failed'`; no separate DLQ | Not in schema |
| Worker process | **UNKNOWN** — PHP worker process name, location, and start mechanism not in staged source | Config files excluded |
| Scheduled jobs (cron) | **UNKNOWN** from source inspection | No cron definition in staged snapshot |

### Scrape Job Lifecycle (In-App)

```
User submits search
  → leadlists.php case 'enqueueScrapeCities'
  → INSERT into scrape_city_jobs (status='queued')
  → Worker polls scrape_city_jobs WHERE status='queued' AND locked_at IS NULL
  → Worker sets locked_at, status='running'
  → Worker calls RapidAPI
  → Worker calls webhook_scrape.php callback
  → Worker sets status='completed' or 'failed'
  → Results stored in lead_list_items
```

### Replicate AI Enrichment

- `REPLICATE_API_KEY` is used for AI-powered lead enrichment
- `webhook_scrape.php` receives enrichment callbacks from RapidAPI
- No evidence of dedicated AI worker service in staged source

### No RabbitMQ, Redis, or Qdrant Evidence

Source code inspection found:
- **No RabbitMQ connection, vhost, exchange, or queue declaration**
- **No Redis `REDIS_*` constants or `predis`/`phpredis` usage**
- **No Qdrant vector DB usage**
- The PRD v3 §7.2 RabbitMQ target and §7.2 Qdrant target are **not currently implemented** for Core Distro

---

## §9 — Current Placement

### Confirmed from Source and BR-AUD-001/BR-INV-001

| Component | Current Placement | Host Identity | Notes |
|:----------|:-----------------|:--------------|:------|
| PHP SaaS (production) | Contabo cPanel (`business190.web-hosting.com`) | `business190` per BR-INV-001 | Served via Cloudflare (implied); `core_distro` helpers |
| Next.js static (staging) | AminoVPS (`srv1137994-aminolifesciences`) | Tailscale IP `100.69.211.43` | `127.0.0.1:3113`; systemd |
| Next.js static (production registered) | AminoVPS | Same host | `127.0.0.1:3117`; not started |
| Database (MySQL/Percona) | AminoVPS | Same host as Next.js | Percona `8.4.10-10` |
| Reverse proxy (nginx) | AminoVPS | Same host | Active per BR-INV-001 |
| PHP runtime (Contabo) | Contabo | Per BR-INV-001 | PHP `8.4.22` |
| PHP runtime (AminoVPS) | AminoVPS | Per BR-INV-001 | PHP `8.4.22` |

### PRD Target Placement vs. Current Reality

| Layer | PRD v3 Target | Current Placement | Gap |
|:------|:--------------|:------------------|:----|
| Public web/API | Hostinger KVM8 | Contabo cPanel | **Wrong host** |
| Database | Hostinger PostgreSQL + PgBouncer | AminoVPS MySQL/Percona | **Wrong host + wrong engine** |
| Queue/workers | Hetzner RabbitMQ | AminoVPS MySQL-backed jobs | **Not yet on Hetzner** |
| Scraping/compute | Hetzner browser pools | Contabo (via RapidAPI) + AminoVPS | **Not yet on Hetzner** |
| AI enrichment | Hetzner compute | AminoVPS (via Replicate API) | **Not yet on Hetzner** |
| Backup/DR | Namecheap per project | **UNKNOWN** | **Not evidenced** |

**The current production stack is entirely different from the PRD target architecture.** The application currently runs on Contabo + AminoVPS; the PRD targets Hostinger + Hetzner. This is the core architectural gap that BR-ARCH-001 must address.

---

## §10 — Explicit Unknowns

| Item | Status | Recovery Condition |
|:-----|:-------|:------------------|
| Next.js production git remote | **UNKNOWN** — zip-only provisioning on AminoVPS | Operator must supply canonical Next.js git remote or confirm zip-only workflow |
| Next.js `next.config.ts` / build configuration | **UNKNOWN** — not in staged snapshot | Require source access |
| PHP worker process name and start mechanism | **UNKNOWN** — config files excluded from git | Require deployment documentation |
| Cron/scheduled job definitions | **UNKNOWN** — no crontab in staged source | Require host inspection or deployment docs |
| `includes/auth.php` — auth model, password hashing algorithm | **UNKNOWN** — file excluded from git | Require source access |
| `webhook_scrape.php` inbound address (scraper callback host) | **UNKNOWN** — RapidAPI calls back to `APP_URL/webhook_scrape.php`; the host of that URL is Contabo | Confirm webhook endpoint routing |
| Hetzner RabbitMQ coordinates | **UNKNOWN** — Hetzner server itself is unevidenced per BR-INV-001 | Operator must supply Hetzner coordinates; BR-AUD-002 cannot proceed on this |
| Redis usage | **UNKNOWN** — no Redis evidence in source, but PRD v3 §7.1 mentions Redis for session/cache | Confirm whether Redis is used at all currently |
| Coolify state on AminoVPS | **UNKNOWN** per BR-INV-001 | Confirm Coolify exists and state |
| Database backup configuration | **UNKNOWN** — no backup script in staged source | Confirm backup tooling and schedule |
| Health endpoints for monitoring | **UNKNOWN** — no `/health` or `/status` routes in source | Design and implement as part of PRD §14 observability |
| Cloudflare zone state (core-distro.com) | **UNKNOWN** — BR-INV-002 found no live DNS lookup evidence | BR-INV-002 evidence gap |
| Database engine migration plan | **OUTSTANDING** — PRD targets PostgreSQL; current is MySQL/Percona | ADR-006 required; cannot proceed with PRD placement without this decision |
| Project isolation (Core vs CBD-Data DB) | **NOT IMPLEMENTED** — shared Percona instance currently serves both | ADR-006 must address separation |
| Worker logs, observability | **UNKNOWN** — no structured logging evidence in source | Confirm logging implementation |
| Actual traffic and load | **UNKNOWN** — no metrics in staged source | BR-INV-001 did not include application load data |

---

## §11 — Source vs. PRD Reconciliation

### What the PRD Gets Right About Core Distro

- ✅ Four projects including Core Distro — confirmed
- ✅ Public web + authenticated portal — confirmed (`index.php` + `dashboard.php`)
- ✅ File handling (public/private, uploads, exports) — confirmed via `public_list.php` and CSV export logic
- ✅ Background search and enrichment jobs — confirmed via `scrape_city_jobs` queue and RapidAPI integration
- ✅ Lead data as confidential — confirmed via schema and data class analysis
- ✅ No PHI in current state — confirmed via source inspection
- ✅ Stripe for payments — confirmed via `stripe_config.php` references and Stripe Checkout integration
- ✅ CRM integration (GHL) — confirmed via `ghl_connections` table and import logic

### What the PRD Gets Wrong or Needs Updating

- ❌ **"pharmaceutical and laboratory supply/distribution"** (§2.1) — This description does not match the actual application. Core Distro is a **B2B lead-generation SaaS** with search-by-category, email/phone/social enrichment, CSV export, and CRM sync. The PRD description appears to mischaracterize the product.
- ❌ **PostgreSQL target** (§8.1) — Current implementation is MySQL/Percona 8.4. ADR-006 is required to decide whether to migrate to PostgreSQL or document an approved exception.
- ❌ **RabbitMQ on Hetzner** (§7.2) — Current implementation uses MySQL-backed job queue. RabbitMQ is not yet implemented.
- ❌ **Redis** (§7.1) — No Redis evidence in source. Session management may use PHP default (files/database).
- ❌ **Hostinger KVM8 as public/API host** (§7.1) — Current production is on Contabo cPanel.
- ❌ **Qdrant** (§7.2) — No vector DB usage in Core Distro (may apply only to CBD-Data).

### Key Discrepancy: Product Description

> **PRD v3 §2.1 states**: "pharmaceutical and laboratory supply/distribution, including product inquiries, quotes, partnerships, vials, bottles, caps, laboratory plastics, and packaging."

> **Source code shows**: A multi-tenant B2B lead-generation SaaS that searches for businesses by category/location, enriches them with contact data, and allows CRM integration and CSV export. The product is brand-agnostic — the same codebase serves Core Distro and CBD-Data with different `APP_NAME` and `BRAND_COLOR` constants.

**This discrepancy should be escalated to Eric/Dubz for product clarification before architecture finalization.**

---

## §12 — Stop Condition Check

| Check | Result |
|:------|:-------|
| No live SSH, API, DNS, or server inspection | ✅ No live infrastructure access |
| No credentials read or exposed | ✅ All config files excluded from git; no `.env` in staged source |
| No infrastructure mutated | ✅ Read-only discovery pass |
| All findings drawn from local workspace artifacts | ✅ Source files, BR-AUD-001, BR-INV-001, PRD v3 |
| One bounded discovery pass completed | ✅ |
| PostgreSQL vs MySQL resolved | ✅ **MySQL/Percona confirmed; ADR-006 required** |
| Facts separated from PRD assumptions | ✅ Current state vs. PRD target clearly labeled |

**Stop condition: CLEAR — proceeding to validation and commit.**
