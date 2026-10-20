# Core Distro production chatbot isolation lane — 2026-10-18

## Outcome

**BLOCKED before any production mutation.** The live production apex still references the HD2-internal endpoint. Production chatbot configuration was not changed, no deployment was attempted, and no DNS or WordPress cutover was performed.

## Finding and live measurements

The supplied isolation probe identifies the embedded chatbot in live Core Distro HTML. Fresh public GET measurements confirmed:

- `curl -fsSL https://core-distro.com/` — HTTP 200; HTML title `Core Distro | Pharmaceutical Supply Distribution`; returned HTML contained 4 occurrences of `llm.hd2.ai` and the internal host `HD2.ai`.
- The served embed block uses ID `0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`, `data-base-api-url="https://llm.hd2.ai/api/embed"`, and loads `https://llm.hd2.ai/embed/anythingllm-chat-widget.min.js`.
- Production widget JS GET: HTTP 200, `application/javascript; charset=UTF-8`.
- Production GET `https://llm.hd2.ai/api/embed/0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`: HTTP 200, but `text/html; charset=utf-8` (not evidence of a valid embed config response).
- Staging apex GET: HTTP 200. Its rendered page preloads a same-origin widget script at `https://staging.core-distro.com/llm/chat/api/embed/anythingllm-chat-widget.min.js`; that script returned HTTP 200, `application/javascript; charset=UTF-8`.
- Staging GET `https://staging.core-distro.com/llm/chat/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30`: HTTP 404, `text/plain; charset=utf-8`.
- The available staging evidence (`data/2026-10-15/reply-endpoint-resolved.md`) identifies the staging API prefix as `https://staging.core-distro.com/llm/chat/api` and the staging embed ID as `fd029baa-22fd-4a3a-b074-40c7a00daf30`; it describes a browser-verified chat response through a `POST .../stream-chat`, not a GET config endpoint. This does not establish that the production AnythingLLM widget can be repointed by changing its API base URL, nor that the staging widget/config is compatible with the production WordPress page.

## Configuration location and source status

The production chatbot configuration is present in the HTML served by `https://core-distro.com/` as an AnythingLLM embed script block. The actual editable source (WordPress page/database, theme/plugin, or deployment artifact) and its deployment procedure were **not identified**. The available local static checkout at `/home/hd2admin/agent-work/core-distro-saas-clean/current-core-distro/index.html` is not evidence that it owns the current production WordPress HTML; it still contains the old HD2 embed and cannot safely be assumed to be the live source of truth.

## Blocker and exact unblocking condition

A production write must not be made until the production owner identifies and authorizes the exact chatbot-only WordPress/source configuration and supported deployment operation, and confirms a production-compatible configuration using the measured staging endpoint/embed. The staging GET 404 plus the distinct staging frontend/widget implementation make a blind copy of staging's endpoint or embed ID unsafe; the current evidence does not supply a valid exact replacement or prove production widget compatibility.

Unblock by the production owner supplying the exact writable file/WordPress setting and its approved deploy/save command, plus an affirmative authorization limited to that chatbot setting. Then back up that exact target immediately before editing, change only that setting, deploy through the approved operation, and verify the public apex, script, and a valid embed/chat request. No command to write production is safe to run with the current evidence.

## Policy checker

Command: `bash bin/fm-client-infra-isolation-check.sh`

Result: exit status 1. `core-distro.com` and `www.core-distro.com` each report `ERROR: ASSET VIOLATION ... https://llm.hd2.ai`; the other seven checked domains report no internal endpoint reference and remain as measured in this run (Elevate and agents domains resolve to Cloudflare; CBD resolves to 68.65.123.217; Whoosh resolves to 2.57.91.91). No policy or other-domain configuration was changed.

## Backups, changes, and validation record

- Production/config backup: **none** — no production source/config target was identified and no production configuration was mutated. No backup was staged because there was no identified writable target to back up safely.
- Repository code, staging, production site, DNS, WordPress, proxy, and service: unchanged by this lane.
- This audit artifact was newly created; no prior artifact existed to copy. No existing file was overwritten.
- Validation commands used: `curl` GETs above; `bash bin/fm-client-infra-isolation-check.sh` (failed as expected while violations remain); `git diff --cached --name-only` (empty; no staged files).
- Existing unrelated worktree changes were observed and left untouched: `.github/workflows/ci.yml` and its backup, `bin/fm-ci-required-gate.sh` and backup, `tests/fm-ci-required-gate.test.sh.bak-*`, plus untracked `core-distro-saas-clean` and `firstmate` symlinks.

## Residual risk

The public production page continues to load the HD2-internal widget and can submit client chatbot traffic to `llm.hd2.ai`. The isolation check remains red until the production-owned source is safely identified and a compatible, authorized replacement is deployed.
