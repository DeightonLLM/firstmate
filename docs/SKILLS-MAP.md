# Skills map - the whole pile, grouped so it can be studied

**Generated:** 2026-10-21 · **Host:** vmi3238503 (worker surface) · **Companion files:** `docs/skills-map.json` (machine-readable), `docs/skills-map.html` (single-page visual map)

**384 distinct skills** across 32 groups. 223 are loadable in this runtime. The rest are 26 fleet-only procedures, 76 skills belonging to other agent surfaces, and 58 dead entries. Every skill appears in exactly one group.

## How to use this map

The pile is grouped by **what a person is trying to do**, not by vendor or plugin, so a group reads as a job you could be handed. Read a group, learn the two or three skills in it that you will actually use, and ignore the rest until you need them.

* **Each skill** shows one line of plain English for what it does, a *use it when* line, where it lives on disk, and how to invoke it.
* **Groups are small on purpose** (5-13 skills each, except the last one, which is the dead-entries list) so a group is studyable in a sitting.
* **The four labels** are: `fleet-procedure` (lives in this repo's `.agents/skills/`, loaded by firstmate), `runtime` (loaded by the minimax/mcode runtime in this session), `host-local` (installed under a per-user directory for some agent surface), and `dead` (a dangling symlink that loads nothing).
* **Where the runtime catalogue comes from.** The set of skills this session can load is **runtime-provided, not a repo file**. It is assembled at session start from four places: the builtin catalogue at `~/.minimax/.builtin-skills/`, the plugin cache at `~/.minimax/v2/plugin-cache/official/*/skills/` (each cached plugin has a `.minimax-plugin/plugin.json` naming its skills), and the three per-user external roots the runtime discovers - `~/.claude/skills/`, `~/.codex/skills/` and `~/.agents/skills/`. A repo at `<workspace>/.agents/skills/` is a fourth root, which is why the fleet's 33 procedures load in a session whose workspace is this repo and not otherwise.
* **Machine-readable:** every row below is in `docs/skills-map.json` as `{name, group, one_liner, use_when, source, path, invocable}` plus `loadable_from`, `origin`, `copies` and `notes`. Query that file; do not scrape this document.
* **Open it:** `docs/skills-map.html` is one self-contained file with no build step and no network access. Open it directly in a browser.

## Where the skills live

| Surface | Path | What it is | Skills |
|---|---|---|---|
| Runtime builtin | `~/.minimax/.builtin-skills/` | Skills shipped with the minimax/mcode runtime. Always loaded. | 17 in the catalogue + 23 nested Lark sub-skills under `lark-tools/` |
| Runtime plugin cache | `~/.minimax/v2/plugin-cache/official/*/skills/` | Skills delivered by named plugins (Matt Pocock, pm-skills, marketing-skills, game-studio, superpowers, ...). Each has a `plugin.json` listing them. | 135 |
| Per-user agent dirs | `~/.agents/skills/`, `~/.codex/skills/`, `~/.claude/skills/` | The three external roots the runtime scans. `~/.agents/skills` holds the fleet's shared ones (`axi`, `herdr`, `quota-axi`, `no-mistakes`, `standup`, the `google-agents-cli-*` family, `ai-infra-*`). | 57 live |
| Fleet procedures | `.agents/skills/` in this repo | Firstmate's own 33 operating procedures. Loaded in any session whose workspace is this repo. | 33 |
| Fleet public skills | `skills/` in this repo | The public, installer-facing skills the repo ships to users. The runtime does not load this root, so these are catalogue-only here. | 1 (`stow`) |
| Other surfaces | `~/.senpi/agent/skills/`, `~/.gemini/`, `~/.codex/plugins/`, `~/.pi/agent/skills/` | Skills for the Senpi/RPIV, Antigravity, Codex-plugin and Pi surfaces. Real, but not loadable from this runtime. | 74 |
| Dead | `~/.claude/skills/`, `~/.codex/skills/` | Dangling symlinks into the removed `/root/gstack` tree. Nothing can load them. | 58 |

## Suggested reading order - start here

Twelve skills. Each earns its place for a specific reason, not because it is important in the abstract.

1. **`surface-first`** - Never escalate a fact to the Captain that was already on disk. It is the one skill that governs every other escalation, and it is short enough to read in a minute.
   *Never escalate to the Captain a fact that was already sitting on disk.*
2. **`no-mistakes`** - The fleet's single ship gate: review, tests, lint, docs, push, PR, CI. Everything that leaves this machine is supposed to go through it, so learn what it actually does.
   *Runs the full validation pipeline (review, tests, lint, docs, push, PR, CI) before a change leaves your hands.*
3. **`diagnostic-reasoning`** - Most stalled work is a diagnosis problem, not a coding problem. This is the fleet's own bug procedure and it is stricter than the generic debugging skills.
   *A fleet procedure for diagnosing reported bugs end-to-end-aligned with the end user.*
4. **`code-review`** - The review gate, and the cheapest quality lever there is. The builtin one is deliberately narrow: a named scope, concrete defects, no unsolicited fixes.
   *Reviews a named code scope (changes, commits, branches, PRs, files) for concrete defects.*
5. **`bearings`** - The cheapest way back into the fleet after a break: one digest of where the work actually is, instead of asking around.
   *Produces a 'pick up where I left off' digest from the fleet's live state.*
6. **`standup`** - One command sweeps every subagent, pane and inbox for status, blockers and drift. It tells you whether the fleet is off-track before you find out the hard way.
   *Runs a fleet standup across subagents, Herdr panes and comms inboxes to collect status, blockers and drift.*
7. **`quota-axi`** - This is a hard gate, not advice: it decides whether you are allowed to keep spending a provider. Learn its output before you plan any multi-model job.
   *Reports how much provider quota you actually have left, and how fast you are burning it against the reset clock.*
8. **`handover`** - If you are here at the end of a stretch, this is what leaves the home land-reaped-tidy. It is also the difference between a handover and a mess.
   *Prepares a fleet home for a Captain handover, leaving it land-reaped-tidy and never mid-merge.*
9. **`handoff`** - The companion to handover: it preserves the jobs and the session lock across a coordinator change. Two different jobs, two different skills, easily confused.
   *Prepares or receives a complete firstmate handover that preserves all jobs and the session lock.*
10. **`project-management`** - Every client-facing piece of work hangs off a project registry entry. Learning this teaches you how intake, delivery mode and consent actually work.
   *The procedure for adding, creating, cloning, removing and initializing firstmate projects.*
11. **`harness-adapters`** - The verified facts about every agent harness this fleet can spawn onto. Read it before you dispatch work, or you will guess.
   *Verified facts about each agent harness: claude, codex, opencode, pi, pi-signed, grok, kimi, agy.*
12. **`decision-hold-lifecycle`** - Stops a captain decision being quietly lost when a review closes. It is the reason the map can promise that decisions survive.
   *Completes investigations and reviews without losing an unresolved decision.*

## The groups

### Shipping code safely

*Get a change written, tested and merged without hand-waving the evidence.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `mattpocock-skills:implement` | Implements a piece of work against a spec or a set of tickets. | A spec or ticket set exists and the work is now to be done. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:prototype` | Builds a throwaway prototype to answer a design question. | You want to sanity-check whether a state model or a UI idea actually feels right. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:tdd` | Test-driven development with a red-green-refactor loop and tests worth maintaining. | You want to build a feature or fix a bug test-first, possibly with integration tests. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:to-spec` | Turns the conversation you just had into a written spec and publishes it to the issue tracker. | The discussion is done and needs writing down, without another interview. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:to-tickets` | Breaks a plan or spec into tracer-bullet tickets that declare their blocking edges. | A plan needs to become real tickets with dependencies. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `no-mistakes` | Runs the full validation pipeline (review, tests, lint, docs, push, PR, CI) before a change leaves your hands. | You want a change validated or shipped safely, or you typed /no-mistakes. | repo `.agents/skills/` | type `/no-mistakes`, or name it |
| `superpowers:executing-plans` | Executes a written implementation plan in its own session, with review checkpoints between steps. | A plan already exists and it is time to work through it. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:finishing-a-development-branch` | Decides how a completed branch gets integrated once the tests pass. | Implementation is done and you need to choose merge, PR or cleanup. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:test-driven-development` | Runs a strict test-first loop: red, green, refactor, with the test written before the code. | You are implementing any feature or fixing any bug and want the test to come first. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:using-git-worktrees` | Sets up isolated git worktrees so parallel work never shares a checkout. | You are about to start work that must not disturb the main checkout. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:writing-plans` | Writes an implementation plan you can hand to a separate session. | A multi-step change needs a written plan before anyone types code. | runtime plugin cache (`superpowers`) | name it in your request |
| `tdd-red-green-refactor` | Forces a test-first red-green-refactor loop and refuses acceptance without executable evidence. | You are changing behaviour, fixing a bug, or refactoring and want the test written first. | repo `.agents/skills/` | name it in your request |

### Reviewing and verifying work

*Have someone (or something) check the change before it counts as done.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `code-review` | Reviews a named code scope (changes, commits, branches, PRs, files) for concrete defects. | You want a defect review of a specific scope and did not ask for ordinary explanation or a fix. | `~/.minimax/.builtin-skills/` | name it in your request |
| `mattpocock-skills:code-review` | Reviews changes since a fixed point on two axes at once: repo Standards, and fidelity to the originating spec. | You want a branch or PR reviewed against both the codebase rules and what it was supposed to do. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:resolving-merge-conflicts` | Resolves a git merge or rebase conflict that is in progress. | You are mid-conflict and need it settled. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:triage` | Moves issues and external PRs through a triage state machine and writes agent-ready briefs. | There is a queue of issues or PRs and you need them categorised and briefed. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `superpowers:receiving-code-review` | Checks review feedback for technical merit before implementing any of it. | You have review comments and want them verified rather than blindly applied. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:requesting-code-review` | Packages the current change so a reviewer gets the context they need. | You want a review requested on work you have just finished. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:verification-before-completion` | Demands fresh verification evidence before any claim that work is finished. | You are about to say something is done and need the proof first. | runtime plugin cache (`superpowers`) | name it in your request |
| `typesafe:typesafe-ai` | Routes, ranks, extracts and verifies typed decisions through TypeSafe Jev instead of loose prompt-and-parse. | You are replacing an untyped LLM classifier with typed, testable decisions. | runtime plugin cache (`typesafe`) | name it in your request |

### Planning and shaping the work before you build

*Turn a vague ask into a decision you can defend, before a line of code is written.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `mattpocock-skills:ask-matt` | A router that tells you which of these skills fits your situation. | You do not yet know which skill to use. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:codebase-design` | Gives you the vocabulary for deep modules and where to put a seam. | You are designing a module interface, hunting deepening opportunities, or making code testable. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:domain-modeling` | Builds and sharpens the domain model behind a codebase. | You are arguing about terminology, editing CONTEXT.md, or writing an ADR. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:grill-me` | A hard interview aimed at sharpening a plan or design. | You want a plan sharpened by being questioned, not by more analysis. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:grill-with-docs` | The same hard interview, but it writes ADRs and a glossary as it goes. | You want the plan sharpened and the decisions recorded as you go. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:grilling` | Interrogates you relentlessly until a plan or idea survives the questioning. | You want your thinking stress-tested before you commit to it. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:improve-codebase-architecture` | Scans a codebase for deepening opportunities, presents them as an HTML report, then grills you on the one you pick. | You want a structural review of a codebase and a decision on what to fix. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:teach` | Teaches a concept or a skill inside the current workspace. | You want to be walked through something you do not know yet. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:to-questionnaire` | Turns a decision you cannot answer into a questionnaire for someone else. | You are blocked on a question only another person can answer. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:wayfinder` | Maps a huge chunk of work as decision tickets on your tracker and resolves them one at a time. | The work is bigger than one agent session can hold and you need a route through it. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `superpowers:brainstorming` | Explores intent, requirements and design before any implementation begins. | You are about to create a feature, component or behaviour change. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:writing-skills` | Writes and edits skill definitions so a procedure becomes a reusable, triggerable skill. | You are authoring or revising a SKILL.md for an agent. | runtime plugin cache (`superpowers`) | name it in your request |

### Debugging and diagnosing what broke

*Find the actual cause before you touch anything.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `ai-infra-benchmark` | Benchmarks AI-serving latency: time to first token, tokens/sec, RAG retrieval stages, chunking and proxy buffering. | You need numbers on an LLM or RAG serving stack rather than a guess. | repo `.agents/skills/` | name it in your request |
| `ai-infra-probe` *(firstmate repo only)* | Measures AI-serving and RAG latency from an explicit target and reports unknown internals as unknown. | You need a latency measurement and would rather hear 'unknown' than a guess. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `diagnostic-reasoning` *(firstmate repo only)* | A fleet procedure for diagnosing reported bugs end-to-end-aligned with the end user. | You are scoping a reported bug or acting on a diagnostic report. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `dubzai-vps-resource-purge` | Inventories and safely purges VPS disk, CPU and memory pressure, with capacity gating before any change. | You need to free resources, investigate pressure, or check a host can absorb a service. | `~/.codex/skills/` | name it in your request |
| `mattpocock-skills:diagnosing-bugs` | A diagnosis loop for hard bugs and performance regressions. | You said diagnose, debug this, or something is broken and you want it properly diagnosed. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `superpowers:systematic-debugging` | A disciplined debugging loop that finds the root cause instead of patching symptoms. | Something is broken, throwing, failing or slow and you need the real cause. | runtime plugin cache (`superpowers`) | name it in your request |

### Browser and UI QA

*Drive a real browser, look at the real pixels, and prove the UI works.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `browser-use:control-in-app-browser` | Drives the chat's built-in browser: navigate, click, type, upload, screenshot, test a local site. | You want browser automation in the panel beside the chat, on a signed-in session. | runtime plugin cache (`browser-use`) | name it in your request |
| `chrome-devtools-mcp:a11y-debugging` | Audits accessibility against web.dev guidance: semantics, ARIA, focus, tap targets, contrast. | You are checking whether a page is usable by keyboard and screen reader. | runtime plugin cache (`chrome-devtools-mcp`) | name it in your request |
| `chrome-devtools-mcp:chrome-devtools` | Drives Chrome over DevTools MCP to debug pages, inspect the network and automate the browser. | You are debugging a web page or automating browser interaction. | runtime plugin cache (`chrome-devtools-mcp`) | name it in your request |
| `chrome-devtools-mcp:debug-optimize-lcp` | Debugs and improves Largest Contentful Paint using real DevTools traces. | A page's main content is appearing too slowly and you want it measured, then fixed. | runtime plugin cache (`chrome-devtools-mcp`) | name it in your request |
| `chrome-devtools-mcp:memory-leak-debugging` | Diagnoses JavaScript and Node.js memory leaks using heap snapshot capture and comparison. | Memory is climbing, you are hitting OOM, or you want heap snapshots compared. | runtime plugin cache (`chrome-devtools-mcp`) | name it in your request |
| `chrome-devtools-mcp:troubleshooting` | Fixes DevTools MCP when it cannot list, open or navigate a page. | list_pages, new_page or navigate_page is failing on you. | runtime plugin cache (`chrome-devtools-mcp`) | name it in your request |
| `lighthouse-safe-optimization` | Runs Lighthouse-style audits without letting the fix destabilise the site. | You want a performance audit applied safely to a live page. | `~/.codex/skills/` | name it in your request |
| `saas-qa-dubz` | Runs authenticated browser QA against the DubzAi SaaS apps as a release gate. | You are qualifying a release on Core-Distro, Music Metrics or Lawyer Data. | `~/.codex/skills/` | name it in your request |

### Documents, decks, spreadsheets and notes

*Produce a file a human will actually read: Word, PDF, slides, sheets, notes.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `docx` | Creates, template-applies, edits, fills, reads, repairs and compares Word documents. | A Word document is the deliverable and you need it produced or diagnosed. | `~/.minimax/.builtin-skills/` | name it in your request |
| `obsidian-skills:json-canvas` | Maps concepts and relationships as an Obsidian JSON Canvas file. | You want a visual map of ideas, systems or relationships. | runtime plugin cache (`obsidian-skills`) | name it in your request |
| `obsidian-skills:obsidian-bases` | Creates and edits Obsidian Base views over vault data. | You want a Base view over an Obsidian vault. | runtime plugin cache (`obsidian-skills`) | name it in your request |
| `obsidian-skills:obsidian-markdown` | Writes Obsidian-flavoured Markdown with properties, links and callouts. | You are authoring notes for an Obsidian vault. | runtime plugin cache (`obsidian-skills`) | name it in your request |
| `pdf` | Generates, reformats, fills and reads PDFs, including LaTeX, Markdown-to-PDF and OCR. | A PDF is the input or the output of the task. | `~/.minimax/.builtin-skills/` | name it in your request |
| `pptx` | Reads, creates and edits PowerPoint decks while preserving their theme and layout. | A PowerPoint file is what you are producing or inspecting. | `~/.minimax/.builtin-skills/` | name it in your request |
| `slides` | Builds slide decks as a first-class deliverable rather than a converted document. | You are making a presentation for someone to present. | `~/.codex/skills/` | name it in your request |
| `spreadsheet` | Spreadsheet work in the general sense: create, read, format and convert tabular data. | You need a spreadsheet artefact and are not attached to a particular file format yet. | `~/.codex/skills/` | name it in your request |
| `visual-page` | Turns information that markdown cannot carry into a single self-contained HTML page. | The content is a diagram, comparison, timeline or layout that deserves a real page. | `~/.minimax/.builtin-skills/` | name it in your request |
| `word:docx` | The Word plugin's DOCX skill: create, template, edit, fill, read, repair and compare .docx files. | You are producing a formal Word deliverable from the Word plugin. | runtime plugin cache (`word`) | name it in your request |
| `xlsx` | Reads, edits, creates and converts spreadsheet files, including formulas, formatting and charts. | A spreadsheet file is the primary input or output. | `~/.minimax/.builtin-skills/` | name it in your request |

### Security and hardening

*Lock a host or a codebase down without locking yourself out.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `dubzai-fail-closed-security` | Enforces fail-closed handling of secrets, auth walls and reverse-proxy rules on DubzAi infra. | Any VPS, hardening or deploy task touches keys, tokens, domains or proxy rules. | `~/.codex/skills/` | name it in your request |
| `hard` | Applies repeatable, lockout-safe hardening to an Ubuntu VPS: sudo naming, key-only SSH, UFW, Fail2ban. | You are hardening a VPS and must not lock yourself out doing it. | `~/.codex/skills/` | name it in your request |
| `hd2-client-baseline` | Plans, audits and safely executes a reusable HD2 client VPS baseline with staged access and rollback. | You are standing up or auditing a client VPS against the HD2 baseline. | `~/.codex/skills/` | name it in your request |
| `hetzner-ide-ssh` | Sets up a key-only IDE SSH connection to a Hetzner VPS while keeping a break-glass route. | You are wiring a local IDE to a Hetzner box for the first time. | `~/.codex/skills/` | name it in your request |
| `hygiene` | Routine hygiene pass over the fleet: inventory, update and verify. | You want a quick sweep of what's installed and what needs updating. | `~/.claude/skills/` | name it in your request |
| `hygiene-full` | The full-surface version of the hygiene sweep, including the large fleet inventory. | You want the thorough hygiene run rather than the quick pass. | `~/.claude/skills/` | name it in your request |
| `lawyer-geo-guard` | Protects lawyer-data.com's Add Leads pages from leaking geo-sensitive information. | You are editing or auditing anything on the lawyer-data.com Add Leads flow. | `~/.codex/skills/` | name it in your request |
| `security-best-practices` | Language and framework specific secure-coding guidance to apply while writing code. | You are writing or reviewing code and want the security rules for that stack. | `~/.codex/skills/` | name it in your request |
| `security-ownership-map` | Maps which code owns which security boundary in a repository. | You need to know who owns which security-sensitive area before changing it. | `~/.codex/skills/` | name it in your request |
| `security-threat-model` | Builds a repository-grounded threat model: entry points, trust boundaries, sensitive paths. | You need to reason about what an attacker would target in this codebase. | `~/.codex/skills/` | name it in your request |
| `vps-safe-ssh-hardening` | Hardens SSH on a Linux host with a verified break-glass path left intact. | You are locking down SSH on a server that is already in production. | `~/.codex/skills/` | name it in your request |

### Deploying and hosting

*Get the thing on the internet and keep it there.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `cloudflare-deploy` | Deploys apps and infrastructure to Cloudflare Workers and Pages. | You are hosting a project on Cloudflare. | `~/.codex/skills/` | name it in your request |
| `deploy-website` | Publishes a local static site or frontend build to a public URL for the first time. | You want a local site or build live on the internet for the first time. | `~/.minimax/.builtin-skills/` | name it in your request |
| `dubzai-anythingllm-chatbot` | Applies the DubzAi/HD2 standard for embedding the AnythingLLM chatbot, especially on mobile. | You are embedding or repairing the chatbot widget on a client host page. | `~/.codex/skills/` | name it in your request |
| `edit-deployed-website` | Edits and redeploys a site that is already published, keeping its existing URL. | You are changing something that is already live. | `~/.minimax/.builtin-skills/` | name it in your request |
| `hd2-stack-astra-port` | Ports elevatesci.com or core-distro.com into an autonomous Astra WordPress build on the HD2 stack. | You want one of the HD2 sites ported, migrated or made self-running on our own infrastructure. | repo `.agents/skills/` | name it in your request |
| `hd2-wordpress` | Builds, audits, designs, maintains, QA-secures and publishes HD2.ai WordPress sites. | The site in question is HD2.ai, JungleSound or HumanRequirements on WordPress. | `~/.codex/skills/` | name it in your request |
| `namecheap-mail-dns` | Verifies and configures Namecheap DNS for a cPanel mail domain (MX, SPF, DKIM, DMARC) with a full zone snapshot. | You are changing or signing off a Namecheap mail DNS zone for client email. | `~/.codex/skills/` | name it in your request |
| `namecheap-saas-install` | Guards a Namecheap cPanel SaaS install so it cannot take the host or the mail config down. | You are installing a SaaS app on cPanel and want it done safely. | `~/.codex/skills/` | name it in your request |
| `vercel-deploy` | Deploys applications and websites to Vercel. | You are shipping to Vercel specifically. | `~/.codex/skills/` | name it in your request |
| `video-to-website` | Turns a video into a premium scroll-driven animated site with GSAP and layered choreography. | You have footage and want it to become the centerpiece of a web page. | `~/.codex/skills/` | name it in your request |

### Frontend and interface design

*Design and build interfaces that look deliberate rather than generated.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `design-md` | Generates and validates DESIGN.md token files and the CSS, Tailwind or component code derived from them. | You are working from a design spec and need tokens, CSS variables or components to match it. | `~/.codex/skills/` | name it in your request |
| `frontend-design` | Builds production-grade frontends with deliberate visual identity instead of generic AI styling. | You are asked to build a web component, page or application. | `~/.codex/skills/` | name it in your request |
| `senior-fullstack-developer:engineering-workflow` | The router for non-trivial frontend, backend and full-stack builds: what to do, in what order, with what checks. | You ask for a substantial feature to be built rather than a small edit. | runtime plugin cache (`senior-fullstack-developer`) | name it in your request |
| `senior-fullstack-developer:frontend-dev` | Implements substantial production frontend work after the workflow router picks the UI path. | The workflow has routed you to frontend work, or you name this skill directly. | runtime plugin cache (`senior-fullstack-developer`) | name it in your request |
| `senior-fullstack-developer:fullstack-dev` | Implements substantial cross-layer work: API contracts, auth, data, background jobs, uploads. | The work spans frontend and backend and you have routed to it. | runtime plugin cache (`senior-fullstack-developer`) | name it in your request |
| `superdesign:superdesign` | Designs or redesigns interfaces on the Superdesign canvas, including design systems and variants. | You want a page, flow or brand-new product designed before code exists. | runtime plugin cache (`superdesign`) | name it in your request |

### Performance and speed

*Measure first, fix the bottleneck, then verify the gain.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `performance-experts:core-web-vitals` | Core Web Vitals focused optimisation: LCP, INP and CLS. | You are chasing a specific Core Web Vitals score. | runtime plugin cache (`performance-experts`) | name it in your request |
| `performance-experts:performance` | A general performance playbook: measure, find the bottleneck, fix it, verify the gain. | Something is slow and you do not yet know which layer is responsible. | runtime plugin cache (`performance-experts`) | name it in your request |
| `performance-experts:performance-optimization` | A deeper performance optimisation workflow across the whole stack. | You have already located the problem and now want the fix applied properly. | runtime plugin cache (`performance-experts`) | name it in your request |
| `performance-experts:python-performance-optimization` | Profiles and optimises Python services for latency and memory. | A Python service is slow or leaky and you need it measured. | runtime plugin cache (`performance-experts`) | name it in your request |
| `performance-experts:swiftui-perf` | Reviews SwiftUI code for modern API use, maintainability and performance. | You are reading, writing or reviewing SwiftUI. | runtime plugin cache (`performance-experts`) | name it in your request |
| `performance-experts:vercel-react-best-practices` | Vercel's React and Next.js performance guidelines. | You are writing, reviewing or refactoring React or Next.js code. | runtime plugin cache (`performance-experts`) | name it in your request |
| `performance-experts:vercel-react-native-skills` | Vercel's React Native performance guidelines. | You are tuning a React Native app for jank and startup. | runtime plugin cache (`performance-experts`) | name it in your request |

### Delegating to another agent runtime

*Hand a hard job to a second brain and get the result back cleanly.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `codex:codex-cli-runtime` | Chooses the right Codex MCP call, sandbox, approval policy and delegation boundary. | You are handing diagnosis, planning, research, review or implementation to a local Codex. | runtime plugin cache (`codex`) | name it in your request |
| `codex:codex-prompt-engineering` | Builds compact XML contracts for Codex prompts so its output is stable. | You are writing a prompt for a Codex review, diagnosis or implementation run. | runtime plugin cache (`codex`) | name it in your request |
| `codex:codex-result-handling` | Turns a returned Codex result into ordered, verified findings without auto-fixing anything. | A Codex run has come back and you need its result read properly. | runtime plugin cache (`codex`) | name it in your request |
| `codex:codex-workflow` | The end-to-end path for using a local Codex for review, diagnosis, research or authorised repair. | You asked for a Codex review, adversarial review, diagnosis or research task. | runtime plugin cache (`codex`) | name it in your request |
| `dsh:dsh` | Starts, opens and operates a local DeepSeek Harness Web instance. | You mention DeepSeek Harness or want Harness running in the built-in browser. | runtime plugin cache (`dsh`) | name it in your request |
| `herdr` | Drives Herdr, the terminal multiplexer that hosts coding agents. | You explicitly mention Herdr and want to inspect or control panes, tabs or workspaces. | `~/.agents/skills/` | name it in your request |
| `resume-codex` | Safely continues the work from a Codex CLI or VS Code session in this workspace. | You typed /resume-codex, or you want to pick up your latest Codex work. | `~/.minimax/.builtin-skills/` | type `/resume-codex`, or name it |
| `superpowers:dispatching-parallel-agents` | Splits two or more independent tasks across separate agents. | You have independent tasks that need no shared state or sequencing. | runtime plugin cache (`superpowers`) | name it in your request |
| `superpowers:subagent-driven-development` | Runs implementation work through subagents that each get their own review. | You are executing a plan and want each task delegated and independently checked. | runtime plugin cache (`superpowers`) | name it in your request |

### Tooling and context for agents

*Manage the machinery around the model: context, memory, skills, tool interfaces.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `axi` | Defines ergonomic standards for CLIs that agents drive through the shell. | You are building, changing or reviewing any command-line tool an agent will run. | `~/.agents/skills/` | name it in your request |
| `init` | Bootstraps a repo for AI agents by generating the root AGENTS.md file from the agents.md spec. | A project has no AGENTS.md and you want agents to onboard to it automatically. | `~/.minimax/.builtin-skills/` | type `/init`, or name it |
| `lean-ctx` | Local tooling to select, shape, reuse and recover the context you hand to the model before inference. | You need to control what the model actually reads instead of dumping a whole tree at it. | `~/.codex/skills/` | name it in your request |
| `mattpocock-skills:handoff` | Compacts the current conversation into a handoff document another agent can pick up. | You need to hand a running thread to a fresh session without losing the thread. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:setup-matt-pocock-skills` | Sets up the issue tracker, triage label vocabulary and domain doc layout the other skills expect. | You are about to use the other Matt Pocock skills for the first time in a repo. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:wait-what` | Stops and re-pitches the last message because it did not land. | Your last instruction was not understood and you want it restated properly. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:wizard` | Generates an interactive bash wizard that walks a human through the steps only they can do. | You are provisioning infrastructure, setting up credentials, or driving a third-party dashboard. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mattpocock-skills:writing-for-agents` | How to write documents that agents read: skills, AGENTS.md, CLAUDE.md. | You are creating or editing a skill, AGENTS.md or CLAUDE.md. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `mcode-tools-master` | The gateway skill for multimodal generation and for discovering and calling App/Connector tools. | You need to generate or read an image/video/audio, or you need an App the tool list does not show. | `~/.minimax/.builtin-skills/` | name it in your request |
| `nowledge-mem:nowledge-mem` | Stores and retrieves cross-tool context so facts survive beyond one conversation. | You want a fact to be remembered and found again later, across tools. | runtime plugin cache (`nowledge-mem`) | name it in your request |
| `skill-creator` | Creates a new skill through a short eval-driven loop, so a repeatable workflow becomes a named skill. | You want to turn a procedure you repeat into a skill of your own. | `~/.minimax/.builtin-skills/` | name it in your request |
| `skill-refiner` | Patches an existing skill when you have evidence of a concrete flaw, and nothing else. | A skill you already use has a specific bug, stale instruction or missing case. | `~/.minimax/.builtin-skills/` | name it in your request |
| `superpowers:using-superpowers` | The entry card that says which of the superpowers skills to reach for and how to use them. | You are about to start work and want the right superpowers skill first. | runtime plugin cache (`superpowers`) | name it in your request |

### Research and fact-finding

*Go and check something properly instead of guessing.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `crawl4ai` | Crawls and extracts structured data from sites, including JavaScript-heavy pages. | You need to scrape web pages or build an extraction pipeline. | `~/.codex/skills/` | name it in your request |
| `deep-research` | Runs a five-step research routine that verifies facts against sources and writes a cited answer. | You need market, industry or technical research where the facts must be externally verified. | `~/.minimax/.builtin-skills/` | name it in your request |
| `llm-call` | Calls a configured LLM directly through a local script so you can test prompts and compare models. | You want a raw model call, a prompt test or a model comparison outside normal agent execution. | `~/.minimax/.builtin-skills/` | name it in your request |
| `mattpocock-skills:research` | Investigates a question against high-trust primary sources and saves the findings as a repo Markdown file. | You want docs or API facts gathered and the reading delegated. | runtime plugin cache (`mattpocock-skills`) | name it in your request |
| `x-link-reader` | Reads X/Twitter posts and profiles through the FxTwitter API, bypassing X's anti-bot wall. | You share an x.com link and want what it actually says. | `~/.minimax/.builtin-skills/` | name it in your request |

### Browser games

*Everything needed to design, build and playtest a game that runs in a browser tab.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `game-studio:game-playtest` | Playtests a browser game with screenshots, HUD review and structured issue finding. | You want the game smoke-tested and the issues written down. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:game-studio` | Routes early browser-game work: which stack, which workflow, which specialist next. | You are starting a browser game and have not picked a stack yet. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:game-ui-frontend` | Designs game UI surfaces: HUDs, menus, overlays and responsive layouts that protect the playfield. | You are building the interface around a game. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:phaser-2d-game` | Builds 2D browser games in Phaser, TypeScript and Vite: scenes, gameplay, cameras, sprite animation, HUD. | You want a 2D browser game on the Phaser stack. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:react-three-fiber-game` | Builds React-hosted 3D browser games with React Three Fiber and shared React state. | The game must live inside a React app. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:sprite-pipeline` | Generates and normalises 2D sprite animation strips with consistent anchors and scale. | You need consistent sprite animation frames for a browser game. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:three-webgl-game` | Builds browser-game runtimes on plain Three.js: scene control, GLB assets, loaders, physics, WebGL debugging. | You want a 3D browser game with low-level control. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:web-3d-asset-pipeline` | Prepares and optimises GLB/glTF assets: Blender cleanup, collision, LOD, compression, texture packaging. | You are shipping 3D assets into a browser game. | runtime plugin cache (`game-studio`) | name it in your request |
| `game-studio:web-game-foundations` | Sets browser-game architecture: engine choice, simulation/render split, input model, assets, save strategy. | You need the architecture settled before writing any game code. | runtime plugin cache (`game-studio`) | name it in your request |

### Video, image and multimodal generation

*Generate video, images and other media with the right prompt discipline.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `imagegen-cli` | Generates and edits raster images (illustration, texture, sprite, mockup, cutout) from the command line. | The task needs an AI-made bitmap rather than a diagram or a photo you already have. | `~/.codex/skills/` | name it in your request |
| `minimax-h3-skills:3d-animation-short-generator` | Generates a short 3D animation from a written brief. | You want a short 3D animated clip. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:brand-promo-video-generator` | Generates a branded promotional video from a logo or product brief. | You are producing promo video for a brand, product or site. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:co-op-game-intro-generator` | Generates a two-player co-op game intro or menu animation. | You are building the opening animation for a co-op game. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:h3-prompt-writing` | Writes MiniMax H3 video prompts that hold up frame by frame. | You are about to brief a H3 video generation run. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:handdrawn-live-video-generator` | Generates a surreal hand-drawn-style short video that blends with live-action space. | You want a deliberately rough, glowing, hand-drawn look. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:minimalist-product-ad-generator` | Turns product images and an ad brief into a minimalist product ad short. | You are running an e-commerce or product-launch ad video. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:music-video-subtitle-generator` | Generates an AI music video with lyric typography and emotional short-film framing. | You are producing a music video or lyric-titled short. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:paper-collage-explainer-generator` | Generates a tactile paper-collage explainer video for a topic or narration. | You want a knowledge point explained in a paper-collage visual language. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `minimax-h3-skills:papercraft-stop-motion-explainer` | Generates a handmade papercraft stop-motion explainer for science or general knowledge. | You want to teach something through tactile stop-motion visuals. | runtime plugin cache (`minimax-h3-skills`) | name it in your request |
| `video-creater:write-h3-prompts` | Writes H3 video prompts, including the writing of prompts for longer narrative pieces. | You are preparing a longer or more scripted H3 video generation. | runtime plugin cache (`video-creater`) | name it in your request |

### Product management — discovery and user insight

*Understand the customer before the roadmap does.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `pm-skills:analyze-feature-requests` | Analyses and prioritises a pile of feature requests. | Customers keep asking for things and you need to read the pattern. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:brainstorm-ideas-existing` | Brainstorms and structures new ideas on top of an existing product. | You have a product and need new ideas for it. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:brainstorm-ideas-new` | Brainstorms and structures entirely new product ideas. | You are starting from a blank page. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:dummy-dataset` | Generates realistic dummy datasets for testing and demos. | You need plausible test data that is not real customer data. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:interview-script` | Writes a structured customer interview script. | You are about to interview someone and want the questions right. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:job-stories` | Writes job stories that capture the progress a customer is trying to make. | You need to express a customer's job rather than a feature list. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:opportunity-solution-tree` | Builds an Opportunity Solution Tree linking an outcome to opportunities, solutions and experiments. | You are structuring discovery and deciding what to build next. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:summarize-interview` | Summarises an interview transcript into JTBD, satisfaction signals and action items. | A customer interview is recorded and needs processing. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:summarize-meeting` | Summarises a meeting transcript into date, participants, decisions and actions. | A meeting is recorded and you need minutes. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:user-stories` | Writes user stories to the 3 C's and INVEST, with acceptance criteria. | You are breaking a feature into backlog items. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:value-proposition` | Designs a value proposition on the 6-part JTBD template. | You need to articulate why a customer would choose you. | runtime plugin cache (`pm-skills`) | name it in your request |

### Product management — strategy and positioning

*Decide where the product is going and how it wins.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `pm-skills:ansoff-matrix` | Builds an Ansoff Matrix of growth directions. | You need a structured map of market and product growth options. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:business-model` | Generates a Business Model Canvas covering costs and revenue. | You are modelling how the business makes money. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:lean-canvas` | Generates a Lean Canvas for testing a business hypothesis. | You are testing a new venture or hypothesis cheaply. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:monetization-strategy` | Brainstorms 3-5 monetisation strategies with fit, risk and validation experiments. | You are choosing how to make money from the product. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:outcome-roadmap` | Rewrites a feature-list roadmap as outcome statements. | Your roadmap lists features and needs to state intent instead. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:pestle-analysis` | Runs a PESTLE analysis of the macro environment. | External forces are affecting the plan and you need them named. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:porters-five-forces` | Runs Porter's Five Forces on the industry. | You need to judge whether the market is worth entering. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:pre-mortem` | Pre-mortems a PRD or launch plan, sorting risks into Tigers, Paper Tigers and Elephants. | You want to stress-test a plan before you commit to it. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:pricing-strategy` | Analyses pricing models, competitor pricing, willingness to pay and elasticity. | You are setting or changing a price and need the numbers. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:product-strategy` | Builds a 9-section product strategy canvas covering vision, segments, value, metrics and defensibility. | You are defining product direction, not just features. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:product-vision` | Brainstorms an inspiring, achievable product vision that aligns the team. | You need the north star before the roadmap. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:startup-canvas` | Generates a Startup Canvas combining product strategy with a business model. | You are evaluating a new product concept end to end. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:swot-analysis` | Runs a SWOT analysis with actionable recommendations. | You need an honest read of position and surroundings. | runtime plugin cache (`pm-skills`) | name it in your request |

### Product management — planning, prioritisation and delivery

*Turn a strategy into a backlog with a defensible order of work.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `linear` | Manages Linear issues, projects and team workflows. | Your team's work lives in Linear and you need to read or change it. | `~/.codex/skills/` | name it in your request |
| `pm-skills:create-prd` | Creates a product requirements document from a problem statement. | A feature needs a PRD before anyone builds it. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:identify-assumptions-existing` | Identifies and documents the assumptions an existing product already rests on. | You are reviewing a product you did not build. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:identify-assumptions-new` | Identifies and documents the assumptions behind a brand-new product idea. | You are about to commit resources to something unproven. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:metrics-dashboard` | Defines a product metrics dashboard with key metrics, sources, visualisations and alert thresholds. | You need to decide what gets measured and when it pages you. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:prioritization-frameworks` | A reference for nine prioritisation frameworks, with formulas and when-to-use guidance. | You need to choose a prioritisation method rather than apply one. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:prioritize-assumptions` | Prioritises assumptions on an Impact x Risk matrix and proposes an experiment for each. | You have a list of assumptions and need to test the right ones first. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:prioritize-features` | Ranks feature ideas by impact, effort, risk and alignment, with a top five. | The backlog is too big and you must cut it. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:retro` | Runs a structured sprint retrospective with prioritised actions and owners. | The sprint is over and you want the learning captured. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:sprint-plan` | Plans a sprint with capacity estimation, story selection, dependencies and risk. | Sprint planning is next and you need the scope defended. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:test-scenarios` | Derives test scenarios with objectives, steps, roles and expected outcomes from user stories. | QA cases need to exist before a feature ships. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:wwas` | Writes backlog items in Why-What-Acceptance format. | You want independent, testable backlog items. | runtime plugin cache (`pm-skills`) | name it in your request |

### Product management — experiments, launch and comms

*Test the risky assumptions, then launch without surprises.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `pm-skills:brainstorm-experiments-existing` | Designs experiments for an existing product. | You have a product and need to learn from it. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:brainstorm-experiments-new` | Designs experiments for a new product idea. | You need to test a hypothesis before building. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:brainstorm-okrs` | Brainstorms and structures objectives and key results. | You are setting a period goal and need it measurable. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:release-notes` | Writes user-facing release notes grouped into features, improvements and fixes. | A release needs announcing. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:stakeholder-map` | Maps stakeholders on a power/interest grid and produces a communication plan. | A launch needs the right people talked to the right way. | runtime plugin cache (`pm-skills`) | name it in your request |
| `pm-skills:strategy-red-team` | Attacks a PRD or strategy's load-bearing assumptions and returns the cheapest test for each. | You want a plan pressure-tested before reality tests it. | runtime plugin cache (`pm-skills`) | name it in your request |

### Marketing, SEO and editorial

*Get found, get read, get bought.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `dubzai-editorial-team` | A human-style editorial team that researches, fact-checks, illustrates and packages DubzAI blog posts. | You are planning, writing or reviewing a DubzAI article. | `~/.codex/skills/` | name it in your request |
| `geo-ai-optimization` | AI discoverability work: knowledge graphs, structured data, llm.txt, citation and entity engineering. | A client wants to be found and cited by AI assistants. | `~/.codex/skills/` | name it in your request |
| `marketing-skills:analytics` | Sets up, audits and repairs analytics tracking, events and conversion measurement. | You need to know whether your tracking is actually working. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `marketing-skills:competitor-profiling` | Researches and profiles competitors from their own URLs into a structured dossier. | You need to know who you are up against and how they present themselves. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `marketing-skills:copywriting` | Writes and rewrites marketing copy for landing, pricing, feature and homepage pages. | A page's words are weak and you want them sharper. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `marketing-skills:customer-research` | Runs and synthesises customer research into ICPs, personas and jobs-to-be-done. | You need to know what customers actually say and struggle with. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `marketing-skills:launch` | Plans a launch: announcement, go-to-market, waitlist, beta and release checklist. | You are about to release something publicly. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `marketing-skills:marketing-plan` | Writes a full 13-section AARRR marketing plan or growth roadmap. | You need a complete marketing plan for a client or product. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `marketing-skills:pricing` | Reasons about pricing tiers, packaging, free tiers and value metrics. | You are setting or changing prices and want the trade-offs laid out. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `marketing-skills:seo-audit` | Audits technical and on-page SEO and diagnoses why rankings moved. | Your traffic dropped, your pages are not ranking, or you want a health check. | runtime plugin cache (`marketing-skills`) | name it in your request |
| `seo-auditor` | A dedicated SEO audit skill for site-wide technical and content review. | You want a full SEO audit rather than a marketing plan around one. | `~/.codex/skills/` | name it in your request |
| `seo-geo-intelligence-agent` | Combined traditional SEO, GEO and AI-search optimisation across search engines and AI answers. | Clients need visibility in classic search and in AI answer engines. | `~/.codex/skills/` | name it in your request |

### Google ADK agent toolkit

*Build, evaluate, deploy, observe and publish Google ADK agents.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `google-agents-cli-adk-code` | ADK Python patterns for agent types, tools, callbacks and state. | You are writing ADK agent code and need the API shapes. | `~/.agents/skills/` | name it in your request |
| `google-agents-cli-deploy` | Deploys ADK agents to Agent Runtime, Cloud Run or GKE with rollback planning. | The ADK agent is built and now it has to run somewhere. | `~/.agents/skills/` | name it in your request |
| `google-agents-cli-eval` | ADK evaluation methodology: datasets, LLM-as-judge, failure analysis. | You want to measure whether an ADK agent is good. | `~/.agents/skills/` | name it in your request |
| `google-agents-cli-observability` | Traces and logs deployed ADK agents with Cloud Trace and BigQuery analytics. | A deployed ADK agent is misbehaving in production. | `~/.agents/skills/` | name it in your request |
| `google-agents-cli-publish` | Publishes ADK agents to Gemini Enterprise and manages the Agent Registry. | The agent is built and now needs registering for others to use. | `~/.agents/skills/` | name it in your request |
| `google-agents-cli-scaffold` | Creates, enhances and upgrades an ADK agent project from templates. | You are starting an ADK project or adding CI/CD to one. | `~/.agents/skills/` | name it in your request |
| `google-agents-cli-workflow` | The full ADK lifecycle: scaffold, build, evaluate, deploy, publish, monitor. | You are building an ADK agent and want the whole path in one place. | `~/.agents/skills/` | name it in your request |

### Feishu/Lark — chat, mail, calendar and tasks

*Message, schedule and track work in Feishu/Lark.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `lark-attendance` | Queries Lark attendance records. | You need someone's own attendance history. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-calendar` | Manages Lark calendars and events, checks free/busy and books meeting rooms. | The task is scheduling. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-im` | Sends and receives Lark messages, searches chat history, manages group chats and reactions. | You need to talk to people or read a Lark conversation. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-mail` | Composes, sends, reads and files Lark email, with rules and attachments. | The task is Lark email. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-minutes` | Finds and downloads Lark Minutes recordings and their AI artefacts. | You need a Lark Minutes recording and its summary. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-task` | Creates and tracks Lark tasks and checklists, including subtasks and assignment. | The task is Lark to-dos. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-tools` | The front door to Feishu/Lark: drives the official lark-cli across every Lark capability. | Anything at all involving Feishu or Lark. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-vc` | Queries Lark video meetings and their AI artefacts: summary, action items, transcript. | You want the record of a meeting that has already happened. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-workflow-meeting-summary` | Aggregates Lark meeting minutes over a date range into a structured report. | You want a weekly meeting report out of Lark. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-workflow-standup-report` | Combines today's calendar agenda with unfinished Lark tasks into a daily summary. | You want to know what today looks like. | `~/.minimax/.builtin-skills/` | name it in your request |

### Feishu/Lark — documents, tables and knowledge base

*Read and write Lark docs, sheets, bases, drive and wiki.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `lark-base` | Operates Lark Base tables: fields, records, views, formulas, permissions. | The work is in a Lark Base multi-dimensional table. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-doc` | Creates and edits Lark documents, including images and document search. | The deliverable is a Lark document. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-drive` | Manages Lark drive files, folders, sharing, permissions and imports. | The task is files and folders in Lark drive. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-sheets` | Creates and operates Lark spreadsheets: headers, cells, rows, lookups, export. | The deliverable is a Lark spreadsheet. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-slides` | Reads and manages Lark presentation pages via XML. | The deliverable is a Lark slide deck. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-whiteboard` | Queries and edits Lark whiteboards, exporting images or node structure. | You want to read or draw a diagram inside Lark. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-wiki` | Manages Lark wiki spaces, nodes and hierarchy. | The content lives in a Lark knowledge base. | `~/.minimax/.builtin-skills/` | name it in your request |

### Feishu/Lark — platform, identity and diagrams

*The plumbing: auth, scopes, raw API, and drawing.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `lark-approval` | Manages Lark approval instances and approval tasks. | The workflow runs on Lark approvals. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-contact` | Looks up people, departments and org structure in Lark. | You need a colleague's open_id, email or team. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-event` | Subscribes to Lark events over a WebSocket and emits them as NDJSON. | You are building an event-driven Lark pipeline. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-openapi-explorer` | Digs the raw Lark OpenAPI surface out of the official docs for calls the CLI does not wrap. | No lark-* skill or lark-cli command covers what you need. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-shared` | Lark CLI setup and identity: config, auth login, scope and permission troubleshooting. | lark-cli is not set up, or a call is permission-denied. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-skill-maker` | Wraps Lark API operations into your own reusable lark-cli skill. | You keep repeating the same Lark API calls and want them packaged. | `~/.minimax/.builtin-skills/` | name it in your request |
| `lark-whiteboard-cli` | Guides whiteboard-cli diagram layout for architecture, flow, mind-map and sequence diagrams. | You are drawing a structured diagram in a Lark whiteboard. | `~/.minimax/.builtin-skills/` | name it in your request |

### Fleet procedure — the session and its memory

*How firstmate keeps a live session coherent, recap-able and handover-safe.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `afk` *(firstmate repo only)* | Sets a durable away-mode flag so the daemon self-handles routine wakes and batches only what matters. | You are stepping away, or an away-mode marker is in play. | repo `.agents/skills/` | type `/afk`, or name it; firstmate auto-loads it on its trigger |
| `ahoy` *(firstmate repo only)* | Recaps session events and unanswered decisions since your last real message. | You want a catch-up on what has happened in this session. | repo `.agents/skills/` | type `/ahoy`, or name it; firstmate auto-loads it on its trigger |
| `bearings` *(firstmate repo only)* | Produces a 'pick up where I left off' digest from the fleet's live state. | You ask for a bearings report, a morning brief, or where you left off. | repo `.agents/skills/` | type `/bearings`, or name it; firstmate auto-loads it on its trigger |
| `bootstrap-diagnostics` *(firstmate repo only)* | The playbook for every actionable line the session-start bootstrap diagnostic can print. | The startup digest prints a MISSING, TANGLE, NEEDS_GH_AUTH or similar line. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `firstmate-coding-guidelines` *(firstmate repo only)* | The rules for changing firstmate's shared tracked material: where knowledge lives, who owns it, how to style it. | You are about to edit the firstmate repo's shared, tracked content. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `fmx-respond` *(firstmate repo only)* | Handles X mode mentions, follow-ups and promised public replies. | An x-mention, x-mode-error, public-followup or milestone wake arrives. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `handoff` *(firstmate repo only)* | Prepares or receives a complete firstmate handover that preserves all jobs and the session lock. | You request a takeover, a replacement coordinator, or a startup prompt. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `handover` *(firstmate repo only)* | Prepares a fleet home for a Captain handover, leaving it land-reaped-tidy and never mid-merge. | You say handover, hand over, step away, or are about to reset the session. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `plan-page` *(firstmate repo only)* | How to write a durable execution plan page with live gauges, checkboxes and standing reminders. | You are authoring or maintaining a plan page. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `process-event-sources` *(firstmate repo only)* | The contract for registered process-to-event sources and their wakes. | You are arming a long-polling source or handling a procevent wake. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `repo:stow` *(public copy)* | The public, installer-facing stow: files durable knowledge from the conversation to a local file, and is deliberately a separate file from the firstmate-internal one. | You want the portable version of stow to ship to a user or another project. | repo `skills/` (public) | not loaded by this runtime; it ships to installers |
| `stow` *(firstmate repo only)* | Sweeps the session for uncaptured durable knowledge and files it to disk. | You typed /stow, or you are about to reset or compact the context. | repo `.agents/skills/` | type `/stow`, or name it; firstmate auto-loads it on its trigger |
| `surface-first` *(firstmate repo only)* | Never escalate to the Captain a fact that was already sitting on disk. | Before any 'I need X' or 'where is Y' message to a human authority. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |

### Fleet procedure — crewmates, projects and harnesses

*How work is dispatched, isolated, recovered and updated across the fleet.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `firstmate-codexapp` *(firstmate repo only)* | Coordinates visible Codex Desktop threads alongside firstmate without pretending they are a shell backend. | You are creating, steering or reviewing a Codex App thread for firstmate work. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `firstmate-orca` *(firstmate repo only)* | The operator checklist for the Orca runtime backend. | You are switching to Orca, supervising Orca work or debugging Orca task state. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `harness-adapters` *(firstmate repo only)* | Verified facts about each agent harness: claude, codex, opencode, pi, pi-signed, grok, kimi, agy. | You are spawning, recovering or verifying a crewmate on a harness. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `harness-update-sweep` *(firstmate repo only)* | Version-reads, compares, backs up, updates and verifies every agent harness across every surface. | You ask to update the harnesses or sweep them for a new version. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `project-management` *(firstmate repo only)* | The procedure for adding, creating, cloning, removing and initializing firstmate projects. | You are about to add, register or retire a project. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `quota-array-dispatch` *(firstmate repo only)* | Resolves a dispatch profile array from quota output, including effective headroom evidence. | A dispatch rule resolves to more than one possible profile. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `secondmate-provisioning` *(firstmate repo only)* | The reference for setting up, seeding, launching, recovering and retiring a secondmate home. | You are touching a persistent secondmate home. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `stuck-crewmate-recovery` *(firstmate repo only)* | Reconciles a stuck or missing crewmate's recorded work before escalating or relaunching. | A direct report's endpoint is dead, a wake is stale, or a crewmate has gone quiet. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `updatefirstmate` *(firstmate repo only)* | Fast-forwards firstmate and every secondmate home to origin and re-reads AGENTS.md. | You typed /updatefirstmate or want the whole tree on the latest code. | repo `.agents/skills/` | type `/updatefirstmate`, or name it; firstmate auto-loads it on its trigger |

### Fleet procedure — decisions, quota and brand

*Decide well, keep the ledger honest, stay on brand.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `ask-user-authority` *(firstmate repo only)* | Distinguishes a correction within accepted intent from a contract expansion that needs the Captain. | You have an ask-user finding and must decide whether to act or escalate. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `core-distro-imagery` *(firstmate repo only)* | The Core Distro brand palette, typography and image rules, so output matches the live site. | You are selecting, prompting or sourcing imagery for core-distro.com. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `decision-hold-lifecycle` *(firstmate repo only)* | Completes investigations and reviews without losing an unresolved decision. | You are about to close out work that exposed a decision the Captain still owes. | repo `.agents/skills/` | name it; firstmate auto-loads it on its trigger |
| `quota-axi` | Reports how much provider quota you actually have left, and how fast you are burning it against the reset clock. | You need to know whether it is safe to keep spending a provider, or what your remaining runway is. | repo `.agents/skills/` | name it in your request |
| `standup` | Runs a fleet standup across subagents, Herdr panes and comms inboxes to collect status, blockers and drift. | You typed /standup, or you want a status check, blocker sweep or scope-drift review. | repo `.agents/skills/` | type `/standup`, or name it |

### On this host only — Senpi / RPIV surface

*A separate coding-agent surface's skills. Not loadable from this runtime.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `pi:gbrain-herdr-loop` *(other surface)* | A GBrain-backed autonomous Herdr/Pi dispatch loop: claim tasks, store results, coordinate with other workers. | You are building an autonomous loop or coordinating a multi-agent campaign. | `~/.pi/agent/skills/` | not loadable from this runtime |
| `senpi:annotate-guidance` *(other surface)* | Writes architecture.md guidance files under .rpiv/guidance/ to onboard an AI assistant to a codebase. | You want an agent onboarded to a codebase through the shadow guidance tree. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:annotate-inline` *(other surface)* | Writes CLAUDE.md files next to the source they describe, documenting architecture per directory. | You want CLAUDE.md guidance living alongside the code. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:architecture-review` *(other surface)* | Reviews a module layer by layer against a fixed 10-dimension checklist and triages each finding. | You want a structured structural review of a module. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:blueprint` *(other surface)* | Plans a complex feature as vertical slices with a developer checkpoint between each slice. | A feature is too big for one pass and needs a phased plan. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:changelog` *(other surface)* | Regenerates the [Unreleased] section of every affected CHANGELOG.md from the commits since the last tag. | You are preparing a release or drafting changelog entries. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:code-review` *(other surface)* | Runs parallel specialist agents over a diff, branch or PR and audits it against peer code. | You want a code review of pending changes, a branch, a PR or a diff. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:commit` *(other surface)* | Groups staged and unstaged changes into logical git commits with descriptive messages. | You want the changes committed properly, in more than one commit if that fits. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:context-mode` *(other surface)* | Routes large-output processing through context-mode tools instead of Bash and cat. | Tool output may exceed about twenty lines and you need it handled efficiently. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:create-handoff` *(other surface)* | Compacts the current task, decisions, in-flight changes and open questions into one handoff file. | The session is getting large or you want to hand work to another session. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:ctx-doctor` *(other surface)* | Runs context-mode diagnostics: runtimes, hooks, FTS5, plugin registration, npm and marketplace versions. | context-mode is misbehaving, or you want /context-mode:ctx-doctor. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:ctx-index` *(other surface)* | Indexes a file or directory into context-mode's FTS5 knowledge base so later searches are precise. | You want a path searchable by context-mode, or you typed /context-mode:ctx-index. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:ctx-insight` *(other surface)* | Opens the context-mode Insight dashboard: tool usage, error rate, parallel work patterns, project focus. | You want usage analytics on how you have been working. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:ctx-search` *(other surface)* | Searches context-mode's FTS5 knowledge base for previously indexed project content or session memory. | You want to retrieve something already indexed, or you typed /context-mode:ctx-search. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:ctx-stats` *(other surface)* | Shows how much context window context-mode saved this session. | You want the context savings number for this session. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:ctx-upgrade` *(other surface)* | Updates context-mode from GitHub and repairs its hooks and settings. | context-mode needs updating, or you typed /context-mode:ctx-upgrade. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:design` *(other surface)* | Designs a feature as vertical slices with per-slice verification and an independent final review. | You are designing before you implement, and want the design artefact. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:discover` *(other surface)* | Interviews you one question at a time and synthesises a Feature Requirements Document. | A feature's intent and requirements are not yet written down. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:explore` *(other surface)* | Compares solution options for a change with pros, cons, trade-offs and a recommended path. | You are weighing approaches and want them compared side by side. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:frontend-design` *(other surface)* | Injects tailored visual design direction for frontend work. | You are building a page or a full layout and want design guidance applied. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:frontend-testing-debugging` *(other surface)* | Tests, debugs and improves rendered frontend apps: dev servers, UI regressions, interaction bugs, console errors, responsive layout. | You are testing or fixing a rendered frontend app and need it looked at in a browser. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:implement` *(other surface)* | Executes an approved implementation plan phase by phase, verifying each phase against its criteria. | A phased plan exists and you want it carried out. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:plan` *(other surface)* | Turns a design artefact into a phased implementation plan with parallel phases and success criteria. | A design exists and you want the plan written from it. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:research` *(other surface)* | Answers structured research questions about a codebase with parallel analysis agents and writes a research doc. | You need to understand an area of the codebase properly. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:resume-handoff` *(other surface)* | Reviews and summarises a handoff document, and only continues work when you explicitly authorise it. | You picked up a handoff document from another session. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:revise` *(other surface)* | Updates an existing implementation plan in place after feedback, discovery or a constraint change. | A plan needs adjusting rather than rewriting. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:roadmap-manager` *(other surface)* | Organises, tracks and updates project tasks, roadmaps and TODO items. | You are managing the project roadmap or task list. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:validate` *(other surface)* | Replays each phase's success criteria against the working tree and writes a validation report. | Implementation is claimed done and you want it checked against the plan. | `~/.senpi/agent/skills/` | not loadable from this runtime |
| `senpi:vps-operations` *(other surface)* | Checks VPS system health, logs, service status and running containers. | You need the operational state of a VPS. | `~/.senpi/agent/skills/` | not loadable from this runtime |

### On this host only — Antigravity / Gemini CLI surface

*Google Antigravity's own skill set. Not loadable from this runtime.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `agy:agy-customizations` *(other surface)* | Explains how the Antigravity customization system works and how to author skills, rules, plugins, hooks and MCP servers. | You need to know how Antigravity loads customizations, or you are creating one. | `~/.gemini/` | not loadable from this runtime |
| `agy:antigravity-guide` *(other surface)* | A guide, quick reference and sitemap for Antigravity: the CLI, the IDE, the SDK, slash commands and customizations. | You need to know how to use, configure or extend Antigravity. | `~/.gemini/` | not loadable from this runtime |
| `agy:automation` *(other surface)* | Designs and creates a scheduled background automation, such as a daily summary. | You want a recurring task that runs without you. | `~/.gemini/` | not loadable from this runtime |
| `agy:create-security-implementation-plan` *(other surface)* | Writes a security verification plan for new code or for fixing a scanner finding. | You are generating new code or fixing a vulnerability the scanner reported. | `~/.gemini/` | not loadable from this runtime |
| `agy:determine-threat-model` *(other surface)* | Builds a threat model: entry points, trust boundaries, sensitive data paths and review priorities. | You need to reason about what an attacker would target here. | `~/.gemini/` | not loadable from this runtime |
| `agy:generate-security-audit-report` *(other surface)* | Writes a walkthrough audit report of the vulnerabilities found and fixed in a session. | You want the security outcome of a coding session documented. | `~/.gemini/` | not loadable from this runtime |
| `agy:generative_ui` *(other surface)* | Renders rich interactive HTML widgets inline in the chat or as standalone artefacts. | The answer needs to be an interactive widget, chart or walkthrough, not text. | `~/.gemini/` | not loadable from this runtime |
| `agy:migrate-workflows` *(other surface)* | Migrates legacy workflow files into modern skills, archiving the originals safely. | You have old workflow files and want them turned into skills. | `~/.gemini/` | not loadable from this runtime |
| `agy:permissioned-github` *(other surface)* | How to interact with GitHub and ask for permission when the environment blocks a command. | A GitHub command fails because of environment restrictions. | `~/.gemini/` | not loadable from this runtime |
| `agy:plugin` *(other surface)* | How to create, enable, disable and uninstall plugins that bundle skills, agents, rules, MCP servers and hooks. | You are packaging or managing a plugin as one unit. | `~/.gemini/` | not loadable from this runtime |
| `agy:run-poc` *(other surface)* | Builds a proof-of-concept that demonstrates whether a security fix actually holds. | A vulnerability was fixed and you want proof it is no longer exploitable. | `~/.gemini/` | not loadable from this runtime |
| `agy:run-security-scanner` *(other surface)* | Scans source files for vulnerabilities such as XSS, SQL injection, hardcoded secrets and other CWE classes. | You want source scanned for common security defects. | `~/.gemini/` | not loadable from this runtime |
| `agy:run-workflow` *(other surface)* | Writes and runs a dynamic workflow script that fans work out across many agents. | The task splits into many independent or staged pieces of agent work. | `~/.gemini/` | not loadable from this runtime |
| `agy:scan_dependencies` *(other surface)* | The exclusive authority for package safety: validates any new dependency before it is allowed in. | Before any new package is imported or added to dependencies. | `~/.gemini/` | not loadable from this runtime |
| `agy:securecoder-persona` *(other surface)* | Defines the SecureCoder agent's role and workflow rules for fixing vulnerabilities. | You clicked Fix All with Agent in the SecureCoder panel. | `~/.gemini/` | not loadable from this runtime |
| `agy:securecoder_generation` *(other surface)* | SecureCoder's generation rules: how it writes the fix code itself. | You are the SecureCoder agent generating a remediation patch. | `~/.gemini/` | not loadable from this runtime |
| `agy:ui-plugin-navigation` *(other surface)* | Finds relevant UI plugin panels and surfaces a one-click pill to open them in the side pane. | A running UI plugin panel would help with what you are doing. | `~/.gemini/` | not loadable from this runtime |

### On this host only — Codex plugins and system skills

*Codex CLI's bundled plugin and system skills. Not loadable from this runtime.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `codex:create-pet` *(other surface)* | Creates, repairs, validates, previews and uploads an animated v2 pet in ChatGPT Work mode. | You are making a custom mascot or sprite sheet for ChatGPT Pets. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex:imagegen` *(other surface)* | Generates and edits raster images: illustrations, textures, sprites, mockups, transparent cutouts. | You need an AI-made bitmap rather than a diagram or an existing photo. | `~/.codex/skills/` | not loadable from this runtime |
| `codex:openai-docs` *(other surface)* | Answers questions about Codex itself: models, pricing, skills, settings, automations and troubleshooting. | The question is about how Codex works, or 'you' means Codex. | `~/.codex/skills/` | not loadable from this runtime |
| `codex:pets` *(other surface)* | Lists, inspects, selects, downloads and deletes animated pets in ChatGPT Work mode. | You want to see or manage the pets you already have. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex:plugin-management` *(other surface)* | Discovers plugins, inspects their permissions and dependencies, and connects or removes them. | You ask about plugins, or a task needs an external app the current tools cannot reach. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex:review-agent` *(other surface)* | Performs a read-only, defect-first review of a named code change and returns every actionable finding. | Another agent delegates a review of uncommitted changes, a diff or a commit. | `~/.codex/skills/` | not loadable from this runtime |
| `codex:sites` *(other surface)* | Builds, edits and publishes Sites: landing pages, portfolios, dashboards, trackers and hosted tools. | You want a website built, edited, remixed or managed with Sites hosting. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex:skill-creator` *(other surface)* | Creates or updates a Codex skill with appropriately scoped instructions and supporting resources. | You are authoring or revising a Codex skill. | `~/.codex/skills/` | not loadable from this runtime |
| `codex:skill-installer` *(other surface)* | Installs Codex skills into $CODEX_HOME/skills from a curated list or a GitHub repo path. | You want to list installable skills or install one from a repo. | `~/.codex/skills/` | not loadable from this runtime |
| `codex:update-pet` *(other surface)* | Inspects, validates, previews, repairs and updates an existing custom pet. | You have a pet that needs fixing or changing. | `~/.codex/plugins/` | not loadable from this runtime |

### On this host only — Codex business-document templates

*Ready-made Word/PPT/sheet templates for common business artefacts.*

| Skill | What it does | Use it when | Where it lives | How to invoke |
|---|---|---|---|---|
| `codex-tpl:artifact-template-analytics-dashboard` *(other surface)* | Create a spreadsheet using the Analytics Dashboard template and its retained reference file. | Use when the user selects or names Analytics Dashboard. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-business-review` *(other surface)* | Create a presentation using the Business Review template and its retained reference file. | Use when the user selects or names Business Review. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-design-report` *(other surface)* | Create a document using the Design Report template and its retained reference file. | Use when the user selects or names Design Report. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-experiment-analysis` *(other surface)* | Create a document using the Experiment Analysis template and its retained reference file. | Use when the user selects or names Experiment Analysis. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-financial-budget` *(other surface)* | Create a spreadsheet using the Financial Budget template and its retained reference file. | Use when the user selects or names Financial Budget. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-investment-committee-memo` *(other surface)* | Create a document using the Investment Committee Memo template and its retained reference file. | Use when the user selects or names Investment Committee Memo. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-legal-memorandum` *(other surface)* | Create a document using the Legal Memorandum template and its retained reference file. | Use when the user selects or names Legal Memorandum. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-market-trends-report` *(other surface)* | Create a presentation using the Market Trends Report template and its retained reference file. | Use when the user selects or names Market Trends Report. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-minimal-letterhead` *(other surface)* | Create a document using the Minimal Letterhead template and its retained reference file. | Use when the user selects or names Minimal Letterhead. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-operating-calendar` *(other surface)* | Create a spreadsheet using the Operating Calendar template and its retained reference file. | Use when the user selects or names Operating Calendar. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-operating-review` *(other surface)* | Create a presentation using the Operating Review template and its retained reference file. | Use when the user selects or names Operating Review. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-project-kickoff` *(other surface)* | Create a presentation using the Project Kickoff template and its retained reference file. | Use when the user selects or names Project Kickoff. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-project-tracker` *(other surface)* | Create a spreadsheet using the Project Tracker template and its retained reference file. | Use when the user selects or names Project Tracker. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-sales-pipeline` *(other surface)* | Create a spreadsheet using the Sales Pipeline template and its retained reference file. | Use when the user selects or names Sales Pipeline. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-simple-dark-mode` *(other surface)* | Create a presentation using the Simple Dark Mode template and its retained reference file. | Use when the user selects or names Simple Dark Mode. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-simple-light-mode` *(other surface)* | Create a presentation using the Simple Light Mode template and its retained reference file. | Use when the user selects or names Simple Light Mode. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-strategy-memorandum` *(other surface)* | Create a document using the Strategy Memorandum template and its retained reference file. | Use when the user selects or names Strategy Memorandum. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-system-design` *(other surface)* | Create a document using the System Design template and its retained reference file. | Use when the user selects or names System Design. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-team-alignment` *(other surface)* | Create a presentation using the Team Alignment template and its retained reference file. | Use when the user selects or names Team Alignment. | `~/.codex/plugins/` | not loadable from this runtime |
| `codex-tpl:artifact-template-three-statement-forecast` *(other surface)* | Create a spreadsheet using the Three-Statement Forecast template and its retained reference file. | Use when the user selects or names Three-Statement Forecast. | `~/.codex/plugins/` | not loadable from this runtime |

### On this host only — dead entries (dangling symlinks)

*Directories that LOOK like skills but point at a tree that no longer exists.*

58 dangling `SKILL.md` symlinks pointing into the removed `/root/gstack` tree. They are directories, they show up in `ls`, and nothing can load them. Listed once each:

```
  _gstack-command (host-local-cc)  autoplan (host-local-cc)  benchmark (host-local-cc)  benchmark-models (host-local-cc)  browse (host-local-cc)    canary (host-local-cc)    careful (host-local-cc)   codex (host-local-cc)
  connect-chrome (host-local-cc)  context-restore (host-local-cc)  context-save (host-local-cc)  cso (host-local-cc)       design-consultation (host-local-cc)  design-html (host-local-cc)  design-review (host-local-cc)  design-shotgun (host-local-cc)
  devex-review (host-local-cc)  diagram (host-local-cc)   document-generate (host-local-cc)  document-release (host-local-cc)  freeze (host-local-cc)    gstack (host-local-codex)  gstack-upgrade (host-local-cc)  gstack-upgrade (host-local-codex)
  guard (host-local-cc)     health (host-local-cc)    investigate (host-local-cc)  ios-clean (host-local-cc)  ios-design-review (host-local-cc)  ios-fix (host-local-cc)   ios-qa (host-local-cc)    ios-sync (host-local-cc)
  land-and-deploy (host-local-cc)  landing-report (host-local-cc)  learn (host-local-cc)     make-pdf (host-local-cc)  office-hours (host-local-cc)  office-hours (host-local-codex)  open-gstack-browser (host-local-cc)  pair-agent (host-local-cc)
  plan-ceo-review (host-local-cc)  plan-design-review (host-local-cc)  plan-devex-review (host-local-cc)  plan-eng-review (host-local-cc)  plan-tune (host-local-cc)  qa (host-local-cc)        qa-only (host-local-cc)   retro (host-local-cc)
  review (host-local-cc)    scrape (host-local-cc)    setup-browser-cookies (host-local-cc)  setup-deploy (host-local-cc)  setup-gbrain (host-local-cc)  ship (host-local-cc)      skillify (host-local-cc)  spec (host-local-cc)
  sync-gbrain (host-local-cc)  unfreeze (host-local-cc)
```

## Overlap and conflicts - the honest part

This is not a tidy library. The pile is messy in four specific ways, and the
grouping above does not hide any of them.

### 1. Same name, different skill

These share a directory or catalogue name but are genuinely different
procedures. Pick deliberately - they are not interchangeable.

| Name | The copies | Which one wins |
|---|---|---|
| `code-review` | the runtime builtin, `mattpocock-skills:code-review`, and the Senpi surface | **the builtin** for a local diff you want defect-checked. `mattpocock-skills:code-review` if you want a two-axis Standards-and-Spec review against a fixed point. The Senpi one runs parallel specialist agents over a diff and belongs to another surface. |
| `handoff` | the fleet's own `handoff`, and `mattpocock-skills:handoff` | **the fleet's `handoff`** for a coordinator takeover (it preserves the jobs and the session lock). `mattpocock-skills:handoff` only compacts a conversation. Same word, different job. |
| `implement` | `mattpocock-skills:implement`, `senpi:implement` | **`mattpocock-skills:implement`** implements a spec or ticket set. `senpi:implement` executes a phased plan out of `.rpiv/artifacts/plans/` and is not loadable here. |
| `research` | `mattpocock-skills:research`, `senpi:research` | **`mattpocock-skills:research`** researches a question against primary sources and writes a repo Markdown file. `senpi:research` answers codebase questions with parallel agents and is not loadable here. |
| `frontend-design` | `~/.codex/skills/frontend-design`, `senpi:frontend-design` | **the `~/.codex` one** for building a production frontend. The Senpi copy only injects visual design guidance. |
| `skill-creator` | the runtime builtin, `codex:skill-creator` | **the builtin** for Mavis skills. `codex:skill-creator` is the Codex CLI's own skill authoring and is not loadable here. |
| `docx` | the builtin `docx`, the `word:docx` plugin | **the builtin** unless you specifically want the Word plugin's variant. The two files are near-identical (11382 vs 11329 bytes) and do the same thing. |
| `code-review` / `research` / `implement` on the Senpi surface | `~/.senpi/agent/skills/` | These are a separate coding surface's skills. They are listed under "On this host only" and are not invocable from this runtime. |
| `stow` | the repo's internal `.agents/skills/stow/` and the public `skills/stow/` | The repo keeps **two** `stow` skills on purpose. `skills/stow/` is the public, installer-facing one: standalone, no private paths, no environment branching, `user-invocable: true`. `.agents/skills/stow/` is the firstmate-internal one: it knows about `state/`, the captain, and internal conventions, and carries `metadata: internal: true`. They are different files with different content and both are deliberate. The maintainer comment in each says so. |

### 2. Near-duplicates that are worth knowing about

* **Three `code-review` skills and two `grill` skills.** `mattpocock-skills:grilling`,
  `mattpocock-skills:grill-me` and `mattpocock-skills:grill-with-docs` are three
  variants of one idea: interview the user hard until the plan survives. `grill-with-docs`
  additionally writes ADRs and a glossary as it goes. Take one, not all three.
* **`superpowers:brainstorming` vs `mattpocock-skills:grilling`.** Both are "work out
  what you actually want before building". `brainstorming` is the gentler, broader
  upstream skill; `grilling` is the adversarial interview.
* **`superpowers:test-driven-development` vs `mattpocock-skills:tdd` vs
  `tdd-red-green-refactor`.** Three TDD skills. The fleet's own `tdd-red-green-refactor`
  is the one that governs fleet work, because it demands executable evidence before
  acceptance and stops cleanly when TDD cannot be demonstrated.
* **`no-mistakes` vs `superpowers:verification-before-completion`.** `no-mistakes` is the
  whole pipeline; `verification-before-completion` is the last gate inside it. They do
  not conflict, but running only the second and skipping the first is a common mistake.
* **Six `pm-skills` families that all produce canvases.** `lean-canvas`, `startup-canvas`,
  `business-model`, `product-strategy` and `swot-analysis` overlap heavily in output
  shape. `startup-canvas` is the one that merges the other two.
* **Two identical SEO audits.** `marketing-skills:seo-audit` and `seo-auditor` cover the
  same ground; `seo-auditor` is the longer, more technical one and `seo-geo-intelligence-agent`
  extends into GEO and AI answer engines. `geo-ai-optimization` is the deepest of the three.

### 3. Drift between copies

The same skill is installed in more than one place, and the copies are no longer the
same file. The repo copy is the maintained one; the host copies have fallen behind.

* **`standup`** - the repo copy names `M3.1F` in its example table; the copies under
  `~/.agents/skills/` and `~/.gemini/` still name the retired `M2.7`. One byte of drift,
  but it means the host copies teach a retired model name. The repo copy wins.
* **`namecheap-mail-dns`** - the repo copy is only a **trigger stub**: it says "load the
  canonical skill from `~/.codex/skills/namecheap-mail-dns/SKILL.md`". The canonical skill
  is the `~/.codex` copy (3054 bytes vs 489). Not a conflict, but the repo entry is a
  pointer, not the skill.
* **`no-mistakes`, `quota-axi`, `tdd-red-green-refactor`, `ai-infra-benchmark`,
  `hd2-stack-astra-port`, `axi`, `lean-ctx`** are byte-identical everywhere they appear.
  Those are safe: any copy behaves the same.

### 4. Dead entries - directories that look like skills and load nothing

`~/.claude/skills/` and `~/.codex/skills/` contain **58 dangling symlinks** whose target
directory, `/root/gstack`, no longer exists. Every `gstack-*` entry, plus `ship`, `qa`,
`review`, `spec`, `retro`, `freeze`, `unfreeze`, `pair-agent`, `learn` and their siblings,
point at files that were deleted. They show up as directories, they show up in a `ls`,
and no runtime can load them. This is the single biggest source of the "it is a mess"
feeling: roughly a third of the visible pile on disk is inert.

### 5. Contradictions worth knowing about

* **Two "code review" philosophies.** The builtin `code-review` explicitly says it is
  *not* for ordinary explanation, debugging or fix requests. `mattpocock-skills:code-review`
  explicitly runs two parallel sub-agents. Asking "review this" without saying which
  will produce different work; ask for the one you want by name.
* **`superpowers:brainstorming` says "You MUST use this before any creative work"**, while
  `mattpocock-skills:grilling` treats the interview as optional. If both are loaded they
  will both fire. They are compatible in content but redundant in trigger.
* **`skill-creator` says do not use it to improve an existing skill; use `skill-refiner`.**
  These two are a genuine pair, not an overlap - use `skill-refiner` when you have evidence
  of a concrete defect in a skill.
* **`surface-first` (fleet) argues you must never escalate a fact you could read off disk.**
  Several other skills - `lark-shared`, `hetzner-ide-ssh`, `vps-safe-ssh-hardening` -
  all depend on that rule to keep a human out of the loop. Where they conflict, the
  fleet's `surface-first` is the authority.
* **`mattpocock-skills:setup-matt-pocock-skills` is a prerequisite**, not an optional
  extra: the other Matt Pocock skills expect the tracker and label vocabulary it sets up.


## Method and coverage

* **How the inventory was taken.** Every `SKILL.md` under the roots above was read and its YAML front-matter parsed properly (block scalars such as `>-` included), not scraped line by line. The runtime catalogue was taken from the session's own available-skills list and reconciled against disk: all 200 catalogue entries resolve to a file, and no file was left out of the map.
* **Identity.** Two files are the same skill when their bytes are identical, or when the drift table above says so. Two skills that merely share a name are listed separately, and the one that is not in this runtime's catalogue gets a surface-qualified name (`senpi:code-review`, `codex:skill-creator`, ...) so the map never silently conflates them.
* **What is not in the map.** No skill was invented, renamed or guessed from a directory name. If a front-matter description was missing or ambiguous, the `SKILL.md` body was read before writing the one-liner. `surface-first` has no front-matter at all - it is a plain Markdown file in the repo - so its line was taken from its own heading.
* **What was not changed.** This is a catalogue, not a cleanup. No skill was modified, moved or deleted, and no dead entry was removed.

