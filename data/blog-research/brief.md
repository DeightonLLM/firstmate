# Core Distro blog - market research, sources, and 10 backdated post plans (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort high. Worktree: /tmp/wt-blog, branch content/blog.

## Context
Core Distro is a pharmaceutical supply distribution SaaS. Site: core-distro.com. Staging is
staging.core-distro.com. The Captain wants a real blog: **ten posts, backdated from 1 January 2026.**

## Your job, in order. Do NOT skip to writing.
### 1. Market research - REAL sources only
Use `chrome-devtools-axi` (browser). Identify:
- the top 5 websites in pharmaceutical supply distribution / pharma B2B
- the top 5 websites publishing the most useful content on pharma supply chain, distribution,
  compliance, GDP, cold chain, and serialisation
For each: URL, what they cover well, and their content angles.

**Every claim needs a URL you actually opened.** If you cannot reach it, say UNREACHABLE.
**Do not write from memory. Do not invent statistics, market sizes, or citations.** A fabricated
number in a published blog post is far worse than a gap.

### 2. Topic strategy
From that research, propose **10 topics**. For each:
- working title
- the angle (why this, why now)
- target reader (procurement lead, quality/compliance officer, pharmacist, distributor)
- which researched source supports it, by URL
- suggested publish date from 1 January 2026, spread roughly weekly

### 3. Outline all 10
A real outline per post: H2/H3 structure, key points per section, and the internal links it should
point to. Enough that a writer can execute without re-researching.

### 4. Images
Unsplash credentials exist at `~/.config/unsplash/credentials`:
```
set -a; . ~/.config/unsplash/credentials; set +a
curl -sS "https://api.unsplash.com/search/photos?query=PHARMACY&per_page=5&client_id=$UNSPLASH_ACCESS_KEY"
```
**NEVER print, echo, log, or write the key into any report, file, or commit.** Read it at use time
only. Propose 3-5 candidate search queries per post and note the license and attribution
requirement (Unsplash requires photographer credit + a link back for API use).
Prefer pharmaceutical, laboratory, logistics, cold-chain, medical imagery. No stock handshakes.

## Rules
- **No fabricated sources, numbers, or citations. Ever.** Mark anything you could not verify.
- Do NOT deploy, edit the app, or touch core-distro.com or srv1137994.
- Do NOT write the full posts yet - research and outlines only, so the Captain approves first.
- Commit on `content/blog`. **No merge, no push, no rebase of main.**
- `bash <script>` RUNS. `bash -c` / `python3 -c` BLOCKED - write a script file.

## Report
data/blog-research/report.md with sources, topics, outlines, image queries, and a VERDICT on
whether the research base is solid enough to write from.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.

## NOTE on board/state files - DO NOT STALL ON THESE
A previous attempt blocked itself waiting for `BOARD.md`, `CONTROLLER_STATE.md`, and a SaaS access
inventory at `/root/agent-work/deightonllm-firstmate/`. **That path is Controller-local and
unreadable to this account. It is not a task input.**
The real files are at `/home/hd2admin/kun-agent-workspace/{BOARD.md,CONTROLLER_STATE.md}` - read them
if useful, ignore them if not. **Your job is the market research. Begin now. Do not report blocked
because an unreadable Controller path is missing.**
