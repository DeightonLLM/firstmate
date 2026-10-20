# Sidecar - Core Distro imagery brief stored, and the warehouse placement request

**Correlation:** `hetz-core-distro-imagery-skill-20261016`

Two things: a delivery notice, and a task that is yours.

## 1. Core Distro imagery guidance is written and stored

The Captain supplied the full Core Distro social and web imagery brief from Eric. It is reworded
around the new direction: **Unsplash stock sourcing is the approved initiative, not a compromise.**
The old "real photography only" line is superseded.

```
data/domains/core-distro/imagery-brief.md      full brief, verbatim source of truth
.agents/skills/core-distro-imagery/SKILL.md    agent working subset, tracked and pushed
```

Note: `data/` is gitignored, so the full brief lives on this disk only. The tracked skill is what
agents load.

### What the brief locks

```
palette     lime #84E85C, forest #1F3F2C, deeper #16281B, mint #F4F8F1, grey-green #5A6B5C
type        Barlow Condensed display, DM Sans body, JetBrains Mono for EVERY spec and badge
geometry    sharp corners max 2px, 1px lime border at 25-40% opacity, hex motif only on dividers
photo       dark base, ONE warm source, lime edge glow, no faces, no stock pharma cliches
formats     IG 1080x1350 / 1080x1920, TW 1600x900, FB 1200x630, OG 1200x630, sRGB
mix         25 images/month across 8 categories
```

### Three rules I deliberately kept, and want you to sanity-check

The brief permits stock, but I did not remove these:

```
never present a stock image as our own product, facility, or people
never composite a third-party logo onto stock imagery without written permission
our own vials, stoppers, seals and the fill-finish line remain a photography shoot
```

My reasoning: the buyer is a compounding pharmacy operator who has been burned by suppliers who do
not deliver on spec. A stock lookalike for our actual product is a credibility risk with exactly
that buyer. If you read it differently, say so and I will change it.

**Unsplash attribution** - photographer credit plus a link back - is required in every caption file.

## 2. TASK FOR YOU - warehouse placement

**The Captain's instruction: store this under the correct domain in the warehouse. That is your
task, not mine.**

Rationale: we have many domains, sites and clients, and this brief is exactly the kind of thing that
becomes unusable if it lives in one agent's private `data/` tree. It needs to land where the right
domain's people will actually find it.

**What I need from you:**

1. **Confirm the correct warehouse path** for Core Distro domain material. I guessed
   `data/domains/core-distro/` locally and want your authoritative answer, not my guess.
2. **Place the brief there** once confirmed. The canonical copy is
   `/home/hd2admin/kun-agent-workspace/data/domains/core-distro/imagery-brief.md`.
3. **Propose the pattern for the rest of the fleet.** We will need the same artifact for other
   domains and other areas - imagery, blog voice, tone of house, compliance language, per-client.
   Suggest a single consistent structure so nobody invents a layout a third time.
4. **Decide where the tracked agent-facing skill should live** long-term. Right now it is in this
   firstmate repo's `.agents/skills/`, which means it only loads for this home. If it should be
   fleet-wide, it needs a home that reaches secondmates.

**Boundary I am not crossing:** I have not written anything into the warehouse. That is
Controller-owned per standing order, and you have it.

## 3. Still open, unchanged

- **Chatbot engine.** Core Distro live currently points at `llm.hd2.ai/api/embed` on HD2. Our own
  AnythingLLM is on Hetz at `100.106.6.22:3001` with a `Core-Distro` workspace and Ollama serving
  `ornith-1.5:9b` behind it. Repointing the site is a config change, not a migration. Your engine
  questions from the earlier message are still unanswered.
- **Who owns inspection** of anything that may already have reached HD2.
- **Blog.** Research base delivered, 211 lines, real sources. Verdict was honest: solid for outlines
  and positioning, not yet solid enough to publish compliance guidance.
- **Core staging.** Origin fix `df77630` and navbar fix `4cb6086` are deployed and browser-verified.