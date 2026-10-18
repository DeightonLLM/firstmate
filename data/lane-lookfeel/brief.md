# Lane 11 - Fix chat widget distortion and skewed logos (Luna 6, high)

Worktree /tmp/wt-look, branch lane/lookfeel. Parent holds the fleet lock; you will not acquire it.
Expected. Read + WRITE under your worktree. No commit. No fm-session-start.

## THE CAPTAIN SAW THIS HIMSELF. It is a real defect, not a preference.
> "The chat widget box looked stretched and logos were skewed too. Ensure this has the smooth mobile
> and desktop look and feel people expect from hd2.ai."

## Where
Source on the staging box (authoritative, standalone Next.js build):
  root@100.69.211.43   ssh -o UserKnownHostsFile=/home/hd2admin/.ssh/known_hosts.elevates
  cd "/root/core distro brNDON EDIT/Core Distro Web"
Staging URL: https://staging.core-distro.com  (current release 201713, everything 200)

## 1. Chat widget is distorted in proportion
The launcher and the open panel are STRETCHED, not correctly sized.
- The widget is third-party (AnythingLLM embed) loaded via components/ChatWidgetLoader.tsx.
- The widget's own CSS is a stylesheet from the embed. Our page CSS may be overriding its sizing,
  OR the widget needs a sizing/containment wrapper on our side.
- **Determine which before changing anything.** Do not guess. Measure the rendered box.
- Fix container sizing, panel width and height, and scaling at EVERY breakpoint.
- It must open, scroll and close cleanly on mobile and desktop.

## 2. Logos are skewed - distorted aspect ratio
Assets are at public/core-distro-mark-green.png and public/core-distro-logo-white.webp (added by an
earlier lane, verified 200). The skew is a CSS/aspect-ratio problem wherever they render - navbar,
footer, favicon/meta.
- Confirm aspect ratio is preserved and sizing is consistent with the type beside it.
- Check every place they appear, not just the navbar.

## Verification - this is the part that matters
Screenshots, NOT status codes:
- real mobile 390x844 AND real desktop 1440x900
- widget CLOSED and widget OPEN at both sizes
- logo rendering at both sizes
- console clean at both sizes
- **device emulation, not just a resized desktop browser**
Report every screenshot path.

## Reference standard
https://hd2.ai is the quality bar for smoothness and finish. **Match its standard. Do not copy its
content or branding.** Staging only.

## Rules
```
STAGING ONLY. No production change to core-distro.com.
No spend, no DNS, no registrar, no credential change, no customer-data inspection.
nginx -s reload only, never restart.
Never modify /etc/nginx/sites-enabled/staging.core-distro.com beyond what is required.
close every browser tab you open and leave a page selected.
```

## Output
data/lane-lookfeel/report.md - root cause for each defect, what you changed, screenshot paths,
console state at both sizes, anything left with an explicit [key=<slug>].
