---
name: core-distro-imagery
description: Core Distro brand and imagery guidelines for agents producing or sourcing images. Use when selecting, prompting, or generating imagery for core-distro.com - blogs, social posts, OG cards, hero art - or when writing Unsplash queries for Core Distro content. Locks the palette, typography, geometry, and the do/do-not rules so output matches the live site.
metadata:
  internal: true
  domain: core-distro
  applies_to: [blog, social, og-card, hero, ads, print]
---

# Core Distro imagery guidelines

Source of truth: `data/domains/core-distro/imagery-brief.md` (the full contract with Eric).
This skill is the **working subset** — read it, then read the source brief when a request needs
exact copy, a full monthly mix, or approval flow.

## What Core Distro is

Direct pharmaceutical supply distributor for **503A and 503B compounding pharmacies**. Four lines:

```
glass vials           Type I borosilicate, 2-100 ml, clear + amber, RTU + RTS, ISO 8362-1
rubber stoppers        bromobutyl + chlorobutyl, 13 mm + 20 mm
aluminum flip-off seals color-coded
automation equipment   compact fill-finish, +/-0.5% accuracy, ISO 5, 40-50 vials/min
```

Regulatory backbone: FDA-registered Importer of Record, ISO 8362-1, ISO 13485, GMP, full
documentation (COA, MSDS, TSE/BSE, sterility per lot).

Tagline: **Vials. Stoppers. Seals. Done. One Partner.**  Phone: **(833) 84-VIALS**

Buyer: a pharmacy owner or compliance lead. **They do not want hype. They want a supplier that does
not break their audit.** Optimise for quiet competence.

## Palette — lock these

| Role | Hex | Use |
|---|---|---|
| Lime accent | `#84E85C` | CTAs, badge outlines, highlight on dark, single accent on light |
| Forest dark | `#1F3F2C` | primary dark surface, hero overlays, footer |
| Forest deeper | `#16281B` | deepest sections, footer bottom |
| Mint off-white | `#F4F8F1` | light-mode background |
| Muted grey-green | `#5A6B5C` | body copy on dark |
| White | `#FFFFFF` | headline text on dark |

**One accent only per composition.** If everything is lime, nothing pops.

## Typography

```
display   Barlow Condensed Bold 700/800, all-caps, letter-spacing 0.02-0.05em
body      DM Sans 400 / 500
technical JetBrains Mono 400, uppercase, letter-spacing 0.15-0.25em
```

**Mono is non-negotiable for technical callouts** - RTU, RTS, ISO 8362-1, GMP, 503A, 503B, DSCSA,
USP <797>/<800>. It is part of the brand voice, not decoration.

## Geometry

```
corners      sharp only, max border-radius 2px
card border  1px lime at 25-40% opacity
hex pattern  30-40% opacity, section dividers and dark backgrounds ONLY, not every asset
effects      no drop shadows, no glow, no bevel
```

## Photography direction

```
setting      lab, clean room, fill-finish in motion, QA, warehouse, packaging lines
light        dark or near-black, ONE warm source (tungsten/amber rim), lime edge glow where natural
people       NONE, except a gloved hand placing a vial on a tray. faces never.
composition  tight, dramatic, editorial. medical magazine, not B2B brochure
in frame     real numbers, real specs, real packaging. no abstract metaphors.
```

**Banned cliches:** doctors in white coats, scattered pills, stethoscopes, heart-attack-red logos.

## Hard do-not

```
no red, orange, blue or any non-brand colour
no exclamation marks in copy - confident, not excited
no invented specs or numbers - if it is not on the site or in the COA, it does not go on a post
no third-party logos without written permission
no AI-generated product imagery for vial/stopper/seal/machine shots
no stock image passed off as our own product, facility, or people
no rounded corners beyond 2px
no drop shadows, glow, bevels
```

## Stock imagery — the Unsplash initiative (approved direction)

**Stock is the plan, not a compromise.** Unsplash is our sourcing route for backgrounds, lab and
clean-room context, warehouse and logistics scenes, texture and material close-ups, campaign and
seasonal mood, hero and blog imagery, and social posts across every platform.

The section 2 filter still applies hard - dark or near-black base, one warm light source, tight
editorial composition, palette that sits beside our greens. **Reject bright, white-background,
generic-corporate, and smiling-at-camera results.** Unsplash is mostly wrong for this brand, so a
filtered miss beats an unfiltered hit.

Three rules survive the change:

```
never present a stock image as our own product, facility, or people
never composite a third-party logo onto stock imagery without written permission
our own vials, stoppers, seals and the fill-finish line are still a photography shoot
        - a stock lookalike for our actual product is a credibility risk
always carry Unsplash attribution - photographer credit plus a link back, in the caption file
```

Credentials are read at use time from `~/.config/unsplash/credentials` and are **never** copied into
a report, a file, a prompt, or a commit.

Queries that fit the direction - verify every result visually before use:

```
"dark laboratory" "pharmaceutical vial" "clean room" "amber glass bottle macro"
"laboratory glassware dark" "industrial filling machine" "warehouse inventory dark"
"pharmaceutical manufacturing" "laboratory pipette dark" "medical packaging"
```

## Format specs

| Use | Size | Aspect |
|---|---|---|
| IG feed portrait (preferred) | 1080x1350 | 4:5 |
| IG feed square / carousel | 1080x1080 | 1:1 |
| IG story / reel cover | 1080x1920 | 9:16, keep 250px top and bottom clear |
| Twitter/X single | 1600x900 | 16:9 |
| Facebook landscape / OG card | 1200x630 | ~1.91:1 |
| Facebook cover | 851x315 | ~2.7:1 |

Export **2x where possible** (2160x2700 for IG portrait). PNG for type-led, JPG q90+ for photo-led,
WebP when size matters. **sRGB, screen only, no CMYK.**

## Monthly mix - 25 images

```
A product hero 6   B spec callout 4   C process/workflow 3   D compliance 3
E customer quote 2  F educational 3    G behind-the-scenes 2 H campaign/seasonal 2
```

## Scaling this to other domains

This skill is the pattern, not the exception. Each domain gets the same shape:

```
.agents/skills/<domain>-imagery/SKILL.md     working subset, loaded on demand
data/domains/<domain>/imagery-brief.md       full source brief, never abbreviated
```

Same skeleton every time: what the business is, palette, type, geometry, photography direction,
hard do-not, sourcing constraints, format specs, mix. **Never let a domain brief be written from
memory of this one** - copy the structure, re-derive the content from that domain's real brand.