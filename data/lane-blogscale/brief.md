# Lane 12 - Dated content plan for the blog, then build against it (Luna 6, high)

Worktree /tmp/wt-blogscale, branch lane/blogscale. Parent holds the fleet lock; you will not
acquire it. Expected. Read + WRITE under your worktree. No commit. No fm-session-start.

## THE CAPTAIN'S RULING - supersedes the ten-post weekly plan
> "Dates - I said go back to the start of the year and spread out. Weekly seems too short. I'm happy
> to make a lot more posts and place them in the blog around their dates - what was happening in
> February, post in February."

## So
- **STOP the ten-post weekly cadence.** It was never the target.
- Cover the year from the start, **dated to real events**. A post about what the business was doing,
  launching, supplying or fixing in February is dated February.
- **Volume is wanted.** Produce as many posts as the material genuinely supports. **Do not pad.**
  A thinner month is honest; a fabricated one is not.
- The existing ten posts are the **starting block, not the deliverable.** Re-date each to its real
  month where you can establish it, and say which you could date confidently and which you could not.

## Source of truth - research, not invention
  /home/hd2admin/kun-agent-workspace/data/blog-posts/research-base.md   opened sources, no folklore
  /home/hd2admin/kun-agent-workspace/data/lane-blog-out/posts/         the existing ten
  /home/hd2admin/kun-agent-workspace/.agents/skills/core-distro-imagery/SKILL.md   brand voice
The live site is authoritative for product facts: https://staging.core-distro.com

**Every claim traces to a source that was actually opened, or to a fact on the site. Never invent a
date, a statistic, a customer, an order, a conversation, or an endorsement.** If a month's material
is thin, say the month is thin.

## Editorial caveat - must stay visible
These are **retrospective entries written after the fact, not contemporaneous news.** That caveat
travels with the posts wherever they appear.

## Required per post
A real dated entry matching that month's actual subject matter, with the real event behind it.

## Deliverables - IN THIS ORDER
1. **THE DATED CONTENT PLAN FIRST.** Month by month, 2026 Jan onward: each post's subject, and the
   real event behind it. This is the deliverable I review before volume gets built.
2. Then build against that plan.
3. Then report what you built versus the plan, and **what you deliberately left out and why**.

## Images
Per post 1 hero minimum, real Unsplash photo with photographer, profile URL and download_location.
Read the credential at use time from ~/.config/unsplash/credentials and NEVER print, log or write
the key anywhere. Verify each id against the API before listing it as selected - a previous lane
invented nothing but another returned zero images by being too strict, so: prefer an acceptable
image over no image, but never fabricate attribution.

## Rules
Staging only. No deploy, no nginx, no DNS, no production, no credential change.
Close every browser tab you open.

## Output
data/lane-blogscale/content-plan.md      the plan - reviewed before volume
data/lane-blogscale/posts/               built against the plan
data/lane-blogscale/IMAGE-MANIFEST.md
data/lane-blogscale/report.md            built vs plan, and what was deliberately left out
