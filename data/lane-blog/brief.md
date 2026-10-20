# Lane 1 - Blog completion (Luna 6, high)

Worktree /tmp/wt-lane-blog, branch lane/blog-complete.

The parent holds the fleet lock. You will NOT acquire it. That is expected. You ARE authorised to
read and WRITE files under /tmp/wt-lane-blog/. Do not run fm-session-start. Do not commit.

## Start here
  /home/hd2admin/kun-agent-workspace/data/blog-posts/posts/          10 drafted posts
  /home/hd2admin/kun-agent-workspace/data/blog-posts/VERIFY-LIST.md  unresolved markers
  /home/hd2admin/kun-agent-workspace/data/blog-posts/IMAGE-MANIFEST.md
  /home/hd2admin/kun-agent-workspace/data/blog-posts/research-base.md
Brand voice: /home/hd2admin/kun-agent-workspace/.agents/skills/core-distro-imagery/SKILL.md

## Deliverables
1. **Resolve every [VERIFY: ...] marker.** The site is the source of truth for product facts. Fetch the
   real route from https://staging.core-distro.com and substitute the actual fact. If the site does
   not state it, delete the claim - never guess. Internal route names: verify against app/sitemap.ts
   or the live nav. Report every one you deleted and why.
2. **Select real Unsplash images** for all 10 posts. Per post, 1 hero minimum.
     set -a; . ~/.config/unsplash/credentials; set +a
     curl -sS "https://api.unsplash.com/search/photos?query=QUERY&per_page=5&client_id=$UNSPLASH_ACCESS_KEY"
   Brand filter: dark base, one warm light source, editorial. Not bright, not generic-corporate.
   NEVER print/log/write the API key anywhere. Record photo id, photographer name, profile URL,
   download_location for every image.
3. **Core Distro product images must be real, never stock.** Vials, stoppers, seals and the
   fill-finish line are the actual business. Stock lookalikes for those are forbidden.
4. **Alt text and captions** for every image, with Unsplash attribution and link back.

## Output
  data/lane-blog/posts/            10 final posts, [VERIFY:] fully resolved
  data/lane-blog/IMAGE-MANIFEST.md every image with attribution fields
  data/lane-blog/report.md         what you resolved, what you deleted, publishable verdict per post

No deploy. No app edits. No DNS. No production.
