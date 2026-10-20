# Core Distro blog - write the ten researched posts (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort high. Worktree: /tmp/wt-blog2, branch content/blog-posts.

## The research is done. Your job is to write from it, not to research again.

Read the full research base first:
```
/home/hd2admin/kun-agent-workspace/data/blog-posts/research-base.md
```
It contains the sources actually opened, the ten topics with dates, and a detailed outline plus
internal-link plan for each. Follow those outlines. The dates are already set, 2026-01-01 through
2026-03-05.

## Hard evidence rules - these override everything else in your instincts

1. **Write only what the research base supports.** Every factual claim traces to a source that was
   actually opened and is cited in the base. If you cannot point to it, cut the claim.
2. **No invented statistics, market sizes, percentages, regulatory dates, or citations.** A wrong
   number in a published compliance post is worse than a gap. This is a real distributor selling to
   pharmacists who will be audited.
3. **The base's own verdict is explicit: it is NOT solid enough to publish compliance guidance.**
   Posts 3, 5, and 9 are compliance-adjacent. For those, write the *practical and descriptive*
   material the base supports, state clearly what is general industry practice rather than legal
   requirement, and add an explicit note that the reader must confirm requirements with their own
   compliance function. Do not write regulatory advice.
4. If you need a fact that is not in the base, mark it `[VERIFY: <what>]` in the draft rather than
   filling it in. I will resolve those.

## Voice

Read the brand rules before writing a word:
```
/home/hd2admin/kun-agent-workspace/.agents/skills/core-distro-imagery/SKILL.md
```
Apply the *tone* from it: quiet competence, no hype, no exclamation marks, mono-font treatment for
every spec and certification, real numbers only. The reader is a pharmacy owner or compliance lead
who has been burned by suppliers who overpromise.

## Images

For each post propose 2-3 Unsplash search queries and select images per the brand filter - dark
base, one warm light source, editorial, nothing bright or generic-corporate.

```
set -a; . ~/.config/unsplash/credentials; set +a
curl -sS "https://api.unsplash.com/search/photos?query=QUERY&per_page=5&client_id=$UNSPLASH_ACCESS_KEY"
```

**Never print, log, echo or write the API key into any file, report, or commit.** Read it at use
time only.

Record for each selected image: photo id, photographer name, photographer profile URL, and the
download location required by the Unsplash API guidelines. Unsplash requires attribution and a
link back. Never present a stock image as Core Distro's own product, facility, or people.

## Output

```
data/blog-posts/posts/NN-slug.md      the full post, markdown, with front-matter
data/blog-posts/IMAGE-MANIFEST.md     every image: post, query, id, photographer, URLs, license
data/blog-posts/VERIFY-LIST.md        every [VERIFY: ...] marker, consolidated
data/blog-posts/report.md             what you wrote, what you cut, what needs the Captain
```

Post front-matter: title, slug, date, description, tags, reading time, hero image reference.

## Rules

- **Write only.** No deploys, no edits to the Core Distro app, no nginx, no DNS, no production.
- Commit on `content/blog-posts`. **No merge, no push, no rebase of main.**
- `bash <script>` RUNS. `bash -c` and `python3 -c` BLOCKED - write a script file.

Report with an explicit VERDICT on whether each post is publishable as written.
Use an explicit [key=<slug>] on any blocked or needs-decision line.
