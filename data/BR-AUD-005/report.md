# CBD-Data Application Audit Report

**Task:** BR-AUD-005  
**Project:** CBD-Data (cbd-data.com)  
**Phase:** Phase 1 — Application Audit  
**Audit Date:** 2026-08-05  
**Source Repository:** `/root/agent-work/deightonllm-firstmate/projects/cbd-data.com`  
**PRD Reference:** Brandon Multi-Project Infrastructure PRD v3.0

---

## Executive Summary

CBD-Data is a B2B lead generation SaaS platform that enables business search by keyword/location, automated website data acquisition, contact enrichment, lead list management, CSV export, public share links, CRM integration (GoHighLevel), and API access. The PRD targets placing scraping/enrichment/AI workloads on Hetzner while keeping the public application on Hostinger. Current evidence shows the application is running on **Namecheap shared hosting** (per platform-registry), not yet on the target infrastructure.

---

## 1. Repository Structure

| Directory/File | Purpose |
|---|---|
| `src/` | Next.js 15.3.8 frontend (marketing/public site) |
| `Leads gen saas/source/lead-gen-saas/` | PHP backend application (core SaaS functionality) |
| `app_inspect/` | Subdirectory with inspected variants (amino-data, amino-data.net, cbd-data, music-metrics) |
| `scripts/litellm_config.yaml` | LiteLLM proxy configuration for AI model routing |
| `scripts/mattermost-compose.yml` | Internal Mattermost team chat deployment |
| `watchtower/docker-compose.yml` | Container update watcher |
| `docs/operations/platform-registry.yaml` | Service inventory |

---

## 2. Runtime and Framework

| Field | Value | Source |
|---|---|---|
| **Frontend Framework** | Next.js 15.3.8 (App Router) | `package.json` |
| **Frontend Language** | TypeScript 5 | `package.json` |
| **Backend Language** | PHP >=7.4 | `composer.json` |
| **Frontend Package Manager** | pnpm | `pnpm-lock.yaml` |
| **PHP Dependencies** | stripe/stripe-php ^13.0, phpmailer/phpmailer ^6.8 | `composer.json` |
| **Database** | MySQL (PDO) | `config/database.php` |
| **Default Branch** | UNKNOWN | No git branch evidence |
| **Production Branch** | UNKNOWN | No deployment pipeline evidence in repo |
| **Build Process** | `pnpm build` → `next build` | `package.json` scripts |

---

## 3. Required Services

| Service | Type | Evidence |
|---|---|---|
| MySQL | Database | `config/database.php` — PDO connection |
| SMTP | Email | `config/app.php` — PHPMailer via `email_service.php` |
| Stripe | Payments | `stripe_webhook.php`, `create_checkout_session.php`, `create_subscription_session.php` |
| RapidAPI | Maps data + scraping | `config/rapidapi.php`, `maps_proxy.php` |
| Replicate | AI enrichment (webhook) | `webhook_scrape.php` — receives Replicate webhook callbacks |
| GoHighLevel (GHL) | CRM sync | `admin.php` — GHL import logs table, `ghl_connections`, `ghl_import_logs`, `ghl_import_items` |
| LiteLLM | AI model proxy | `scripts/litellm_config.yaml` — Gemini routing |
| **RabbitMQ** | NOT FOUND | No evidence of RabbitMQ in current codebase |
| **Redis** | NOT FOUND | No evidence of Redis in current codebase |
| **Qdrant** | NOT FOUND | No evidence of vector DB in current codebase |

---

## 4. Environment Variables (Names Only — No Values)

| Variable | Purpose | Evidence |
|---|---|---|
| `DB_HOST` | MySQL host | `config/database.php` |
| `DB_NAME` | Database name | `config/database.php` |
| `DB_USER` | Database username | `config/database.php` |
| `DB_PASS` | Database password | `config/database.php` |
| `SMTP_HOST` | SMTP server | `config/app.php` |
| `SMTP_PORT` | SMTP port | `config/app.php` |
| `SMTP_SECURITY` | SSL/TLS | `config/app.php` |
| `SMTP_USER` | SMTP username | `config/app.php` |
| `SMTP_PASS` | SMTP password | `config/app.php` |
| `STRIPE_SECRET_KEY` | Stripe API key | `config/stripe_config.php` |
| `STRIPE_PUBLIC_KEY` | Stripe public key | `config/stripe_config.php` |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook verification | `config/stripe_config.php` |
| `RAPIDAPI_KEY` | RapidAPI authentication | `config/rapidapi.php` |
| `RAPIDAPI_HOST` | RapidAPI host (maps-data.p.rapidapi.com) | `config/rapidapi.php` |
| `REPLICATE_API_KEY` | Replicate AI platform | `config/rapidapi.php` |
| `GEMINI_API_KEY` | Gemini API (for LiteLLM) | `litellm_config.yaml` |
| `APP_NAME` | Application name | `config/app.php` |
| `APP_URL` | Application URL | `config/app.php` |
| `ADMIN_EMAIL` | Admin contact | `config/app.php` |
| `SUPPORT_EMAIL` | Support contact | `config/app.php` |
| `PRIMARY_DOMAIN` | Primary domain | `config/app.php` |
| `BRAND_COLOR` | Theme color | `config/app.php` |
| `THEME_MODE` | Light/dark/system | `config/app.php` |

---

## 5. Scraping and Data Acquisition

| Field | Evidence |
|---|---|
| **Method** | RapidAPI — `maps_proxy.php` proxies to `maps-data.p.rapidapi.com` for business search; `website-scraper-api.p.rapidapi.com` for website scraping |
| **Business Search** | `maps_proxy.php` type=search → RapidAPI maps endpoint |
| **Website Scraping** | `maps_proxy.php` type=scrape → RapidAPI scraper endpoint |
| **Reviews** | `maps_proxy.php` type=reviews → RapidAPI reviews endpoint |
| **Credit Cost** | Per-call credit deduction in `api_wrapper.php` |
| **Search Logging** | `lead_list_searches` table tracks queries per list |
| **Lead Storage** | `lead_list_items` table stores scraped results with JSON fields |
| **API Keys** | RapidAPI key required; stored in `RAPIDAPI_KEY` env var |
| **Rate Limiting** | Per-user credit-based throttling; no explicit rate limit on RapidAPI calls |
| **Browser Pool** | NOT FOUND in current codebase — RapidAPI is the scraping mechanism |
| **Playwright** | NOT FOUND in current codebase |
| **Per-Domain Limits** | UNKNOWN — governed by RapidAPI policy |

---

## 6. Enrichment

| Field | Evidence |
|---|---|
| **Method** | Replicate API webhook — `webhook_scrape.php` receives async enrichment results |
| **Enrichment Data** | Email extraction from scraped HTML, social media link extraction |
| **Spam Filtering** | `webhook_scrape.php` implements extensive spam domain and pattern filtering |
| **Email Extraction** | Regex extraction with domain/pattern denylist; max 10 emails per lead |
| **Social Extraction** | Regex URL matching against Facebook, Instagram, Twitter/X, LinkedIn, YouTube, TikTok, Pinterest, Yelp |
| **Storage** | `emails` and `social_media_links` JSON columns in `lead_list_items` |
| **Status Tracking** | `enrichment_status` column: pending, failed, completed |
| **Merge Logic** | Results merged with existing data on repeated enrichment |
| **AI Workers** | NOT FOUND as persistent workers — Replicate provides async AI processing |
| **LiteLLM** | `litellm_config.yaml` present but NOT integrated into current enrichment flow |

---

## 7. AI-Agent Execution

| Field | Evidence |
|---|---|
| **AI Provider** | Replicate (webhook-based async) — used for website content extraction/enrichment |
| **Model Proxy** | LiteLLM config present (`scripts/litellm_config.yaml`) — routes to Gemini models |
| **LiteLLM Port** | UNKNOWN — LiteLLM config present but no evidence of running service or integration |
| **AI Integration** | Replicate webhook in `webhook_scrape.php`; LiteLLM is config-only (not active) |
| **GHL Automation** | Drip campaign cron (`cron_drip.php`) + GHL import/sync features in admin |

---

## 8. Queue Consumers and Background Jobs

| Field | Evidence |
|---|---|
| **Queue System** | NOT FOUND — no RabbitMQ, Redis, or database-backed queue evidence |
| **Drip Campaigns** | `cron_drip.php` — cron-based; processes GHL drip batches on schedule |
| **Job Pattern** | Synchronous request processing; enrichment via Replicate webhooks |
| **Worker Processes** | NOT FOUND — no daemon or worker script evidence |
| **Dead Letter Queue** | NOT FOUND |
| **Job State Machine** | NOT FOUND — application tracks enrichment status but no formal job states |
| **Scheduled Jobs** | `cron_drip.php` — requires `* * * * * php /path/to/cron_drip.php` cron entry |
| **Health Checks** | NOT FOUND — no `/health` endpoint in PHP application |
| **Cron Setup** | Installer (`install.php`) documents cron requirement |

---

## 9. Exports and File Storage

| Field | Evidence |
|---|---|
| **CSV Export** | `leadlists.php` — user-facing lead list display; export mechanism UNKNOWN (likely frontend CSV generation) |
| **Export Size Limit** | NOT FOUND in source |
| **File Serving** | PHP application serves files directly; no dedicated file service |
| **Storage Path** | UNKNOWN — no explicit storage path evidence in source |
| **Public Shares** | `public_list.php` + `public_token` in `lead_lists` table |
| **Backup Strategy** | NOT FOUND — no backup scripts in repository |
| **File Namespace** | NOT FOUND — no project-prefixed namespace evidence |
| **Export Retention** | UNKNOWN |

---

## 10. Data Storage

| Field | Evidence |
|---|---|---|
| **Primary Database** | MySQL via PDO |
| **Schema Tool** | `install.php` — creates all tables via SQL in PHP installer |
| **Migrations** | NOT FOUND — schema changes via `install.php` + admin-side `ALTER TABLE` |
| **Key Tables** | `users`, `lead_lists`, `lead_list_items`, `lead_list_searches`, `api_keys`, `api_endpoints`, `api_calls`, `credit_transactions`, `subscription_log`, `ghl_connections`, `ghl_import_logs`, `ghl_import_items`, `password_resets` |
| **JSON Columns** | `emails`, `social_media_links`, `raw_data`, `visited_socials`, `tags`, `errors`, `input_params` |
| **Session Management** | PHP native sessions (`session_start()`) |
| **Encryption at Rest** | NOT FOUND |
| **Backup Destination** | NOT FOUND |

---

## 11. Compute Placement (PRD Target vs. Current Evidence)

| Component | PRD Target | Current Evidence | Gap |
|---|---|---|---|
| Public frontend | Hostinger | Namecheap shared (platform-registry) | **NOT MIGRATED** |
| Scraping | Hetzner | Namecheap shared | **NOT MIGRATED** |
| Enrichment workers | Hetzner | Namecheap shared | **NOT MIGRATED** |
| AI execution | Hetzner | Replicate (external SaaS) | External; Hetzner N/A |
| Database | Hostinger | Namecheap shared | **NOT MIGRATED** |
| Queue consumers | Hetzner | NOT FOUND (no queue system) | **MISSING** |
| File serving | Hostinger | Namecheap shared | **NOT MIGRATED** |
| RabbitMQ | Hetzner | NOT FOUND | **MISSING** |

**Assessment:** The application currently runs on Namecheap shared hosting. No evidence of Hetzner or Hostinger deployment. No Docker Compose definitions for the main application. The PRD target state requires significant infrastructure migration.

---

## 12. Runtime, Build, and Start Path

| Field | Evidence |
|---|---|
| **Frontend Dev** | `pnpm dev` → `next dev` (port 3000 default) |
| **Frontend Build** | `pnpm build` → `next build` |
| **Frontend Start** | `pnpm start` → `next start` |
| **Backend Runtime** | PHP >=7.4 with Apache/nginx on host |
| **PHP-FPM Port** | UNKNOWN |
| **Apache/nginx Config** | NOT FOUND in repository |
| **Systemd Unit** | NOT FOUND (Namecheap shared hosting; PHP runs under cPanel) |
| **Docker for Main App** | NOT FOUND |
| **Watchtower** | Present (`watchtower/docker-compose.yml`) for container updates |
| **Mattermost** | Internal team chat (`scripts/mattermost-compose.yml`) — unrelated to CBD-Data |
| **LiteLLM Service** | Config present; startup path NOT FOUND |

---

## 13. Ports

| Port | Service | Evidence |
|---|---|---|
| 3000 | Next.js dev (default) | `package.json` |
| 3000 | Next.js prod (default) | `package.json` |
| 8065 | Mattermost | `scripts/mattermost-compose.yml` |
| 8443 | Mattermost | `scripts/mattermost-compose.yml` |
| 3478 | Coturn (TURN) | `scripts/mattermost-compose.yml` |
| 49160-49200 | Coturn (UDP range) | `scripts/mattermost-compose.yml` |
| **Main App** | UNKNOWN | NOT FOUND — likely 80/443 on Namecheap shared |

---

## 14. Health and Migration Posture

| Field | Evidence |
|---|---|
| **Health Endpoint** | NOT FOUND — no `/health` route in PHP or Next.js |
| **Database Migration Tool** | NOT FOUND — schema changes via `install.php` + raw ALTER TABLE in admin |
| **Rollback Strategy** | NOT FOUND |
| **Install Lock** | `config/installer.lock` — prevents re-installation |
| **Environment File** | `.env` — gitignored; values NOT in repository |
| **Backup Scripts** | NOT FOUND in repository |
| **Restore Procedures** | NOT FOUND |
| **Deployment Pipeline** | NOT FOUND — manual cPanel deployment on Namecheap |
| **Coolify Integration** | NOT FOUND — no Coolify configuration for CBD-Data |

---

## 15. Project Isolation

| Field | Evidence |
|---|---|---|
| **Isolation Model** | Per-user isolation (users table); per-list isolation (lead_lists table) |
| **Multi-Tenant Prefix** | NOT FOUND — no project-code prefixes in schema |
| **Cross-Project Access** | NOT FOUND — application is single-tenant per deployment |
| **Network Isolation** | NOT FOUND — runs on Namecheap shared hosting |
| **Credential Isolation** | Per-user API keys (`api_keys` table) |
| **Backup Isolation** | NOT FOUND — no multi-project backup evidence |

**Assessment:** Current application lacks project-level isolation constructs. PRD requires strict project isolation (network, credentials, database, queues, files, logging, backups).

---

## 16. Explicit Unknowns

1. **Live deployment state:** No evidence of actual running processes or port bindings beyond Namecheap shared hosting record
2. **LiteLLM integration:** Config exists but no evidence of integration into enrichment flow or running service
3. **Export mechanism:** CSV export behavior not fully traced to backend endpoint
4. **File storage path:** Actual storage location for uploads/exports not documented
5. **Production branch:** Git branch/deploy target unknown
6. **Metrics/observability:** No Prometheus, Grafana, or logging pipeline evidence
7. **Backup target:** Where backups go on Namecheap not documented
8. **Docker for main app:** No Dockerfile or compose for CBD-Data application itself
9. **Worker concurrency:** No evidence of concurrent worker limits or backpressure handling
10. **Actual RabbitMQ requirement:** No queue system found — may need to be introduced per PRD

---

## 17. PRD Target State vs. Current State Summary

| PRD Requirement | Current State | Action Required |
|---|---|---|
| Public app on Hostinger | On Namecheap shared | Migration required |
| Scraping/AI on Hetzner | RapidAPI + Replicate (external) | Architecture decision needed |
| RabbitMQ per-project vhosts | No queue system | Introduce RabbitMQ |
| Hetzner browser pools | Not found | Implement if RapidAPI insufficient |
| Project-isolated databases | Single database, no prefix | Restructure per PRD |
| LiteLLM as AI gateway | Config only | Integrate or document decision |
| Tailscale network | Not implemented | Configure network |
| Coolify deployment | Not configured | Set up Coolify resources |
| Health endpoints | Not found | Implement health checks |
| Backup to Namecheap DR | Not configured | Configure per-project backups |
| Container hardening | Not applicable (shared hosting) | Dockerize application |

---

## 18. Data Sensitivity Classification

| Data Class | Evidence | Classification |
|---|---|---|
| User accounts | `users` table | Confidential |
| Credit card data | Stripe handles; not stored | N/A |
| Business lead data | `lead_list_items` table (names, addresses, phones, emails, websites) | Confidential |
| Social profiles | `social_media_links` JSON | Confidential |
| API credentials | Per-user `api_keys` table | Restricted |
| System secrets | `.env` file | Restricted |
| Public lists | `lead_lists.is_public` + `public_token` | Public |

---

## 19. Evidence Index

| Evidence | Path |
|---|---|
| Platform registry | `docs/operations/platform-registry.yaml` |
| Package.json (frontend) | `package.json` |
| Composer.json (backend) | `Leads gen saas/source/lead-gen-saas/composer.json` |
| Database config | `Leads gen saas/source/lead-gen-saas/config/database.php` |
| RapidAPI config | `Leads gen saas/source/lead-gen-saas/config/rapidapi.php` |
| Stripe config | `Leads gen saas/source/lead-gen-saas/config/stripe_config.php` |
| Maps proxy (scraping) | `Leads gen saas/source/lead-gen-saas/maps_proxy.php` |
| API wrapper | `Leads gen saas/source/lead-gen-saas/api_wrapper.php` |
| Replicate webhook | `Leads gen saas/source/lead-gen-saas/webhook_scrape.php` |
| Admin panel | `Leads gen saas/source/lead-gen-saas/admin.php` |
| Installer (schema) | `Leads gen saas/source/lead-gen-saas/install.php` |
| Cron drip | `Leads gen saas/source/lead-gen-saas/cron_drip.php` |
| LiteLLM config | `scripts/litellm_config.yaml` |
| Mattermost compose | `scripts/mattermost-compose.yml` |
| Watchtower compose | `watchtower/docker-compose.yml` |
| PRD | `/root/agent-work/BRANDON REWORK/Brandon-Multi-Project-Infrastructure-PRD-v3.md` |

---

## 20. Rollback Procedure

If this audit commit needs to be reverted:

```bash
cd /root/agent-work/deightonllm-firstmate
git revert <task-commit-hash>
```

Target: Remove only the scoped artifacts:
- `data/BR-AUD-005/report.md`
- `BRANDON REWORK/evidence/BR-AUD-005/cbddata-application-audit.md`

---

*Report generated by Codex coordinator lane for BR-AUD-005. Findings are based on local repository inspection only. Live behavior requires separate verification.*
