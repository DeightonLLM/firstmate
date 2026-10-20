# Lane 5 - Unsplash image selection, corrected filter (Luna 6, medium)

Worktree /tmp/wt-lane-images, branch lane/blog-images. Parent holds the fleet lock; you will not
acquire it. Expected. Read + WRITE under your worktree. No commit. No fm-session-start.

## Why you exist
The previous lane delivered all 10 posts with ZERO [VERIFY] markers - good work - but selected no
images, because its filter `dark warehouse warm light editorial` was too literal. **The Unsplash API
is healthy and returns hundreds of results.** Verified just now: `pharmaceutical laboratory` = 168
results. The blocker was the filter, not the API, and not credentials.

## Posts to illustrate
  /home/hd2admin/kun-agent-workspace/data/lane-blog-out/posts/   10 final posts
  /home/hd2admin/kun-agent-workspace/data/lane-blog-out/report.md

## Corrected criteria - these are WIDE on purpose
Search 2-3 times per post with concrete queries. Examples that DO return results:
  pharmaceutical laboratory, medical packaging, vial manufacturing, clean room, laboratory glassware,
  pharmaceutical supply chain, warehouse logistics, healthcare distribution, medical supplies,
  laboratory technician, quality control laboratory, medicine production

Select an image when it is: editorial, not a logo, not obviously a different company's product,
not a stock-photo handshake, not a smiling-model-ad feel. Warm OR cool lighting is fine. Bright is
fine if the subject is genuine. **Prefer an image over no image** - an unattributed slot blocks
publishing, which is worse than a merely acceptable picture.

## Hard prohibitions - unchanged
NEVER use stock as Core Distro's actual vials, stoppers, seals or fill-finish line. Those are the
real business; a lookalike misrepresents it. Generic lab/warehouse/logistics context is fine.
NEVER print, log, or write the API key anywhere.

## API
     set -a; . ~/.config/unsplash/credentials; set +a
     curl -sS "https://api.unsplash.com/search/photos?query=QUERY&per_page=5&client_id=$UNSPLASH_ACCESS_KEY"

## Output
  data/lane-images/IMAGE-MANIFEST.md   per post: query used, photo id, photographer name,
        photographer profile URL, download_location, alt text, caption with Unsplash attribution
  data/lane-images/report.md           which posts have heroes and which still do not

Every selected image MUST have a real id, a real photographer and a real download_location. If you
cannot retrieve those fields, do not list the image as selected. Never fabricate attribution.
