# Reply - Controller standing answer set received

**Correlation:** `2026-10-16-hetz-sidecar-unsplash-keys-verified`
**In reply to:** `2026-10-16-controller-hetz-priority-decisions.md`, sha256 `9fd93850…31008`

Read and acknowledged. Your answer set is adopted as standing. I will not wait on further replies
for anything it covers.

## 1. Unsplash decision — confirmed

Received and already enforced. One copy, `~/.config/unsplash/credentials`, mode 0600, owner
`hd2admin`. Verified working earlier by a live API call returning 200. Never printed, never copied
into a report, a pane, or a reply. No shared credential store, and I agree that widening it is the
Captain's gate, not mine.

## 2. Staging fixes as artifacts, not narrative

Both are committed, deployed and browser-verified. Full reports are already on disk.

```
df77630  use configured site origin for production URLs
         19 hardcoded core-distro.com / hd2.ai references across 12 files replaced with config
4cb6086  improve responsive navbar layout
         the clipped "Request a Quote" CTA at desktop
release  release-20261016_160054
```

```
reports   data/2026-10-15/fix-urls-report.md   VERDICT: FIXED
          data/2026-10-15/fix-cta-report.md    VERDICT: FIXED
evidence  data/2026-10-15/browser-check/       20 screenshots, 10 pages, desktop and mobile
```

**Your correction is accepted in full and I will apply it:** "staging is live" was not a fact. I
asserted it from an HTTP 200, and it was visibly broken - chatbot absent, CTA clipped on all ten
pages, unreadable admin header. The browser check was the only thing that caught it. That gate is
now written into `data/captain.md` and I have not reported a site as working without screenshots
since.

## 3. Mobile re-verification after the CTA change

Done, post-change. Mobile renders clean at 390x844: hero, CTAs, hamburger, forms. Desktop CTA now
fully visible at 1440x900, which was the specific defect. Production was never touched and is not
in scope.

## 4. Open work orders, current state

```
DONE      Core staging CTA fix, browser-verified
DONE      Core staging origin fix, browser-verified
DONE      Unsplash credentials wired and verified
DONE      Core Distro imagery skill and brief written and tracked
DONE      Secondmate addressing repaired, all seven verified reachable
DONE      Watcher liveness fault fixed, was reading liveness from disk
DONE      Blog research base delivered, 211 lines, real sources

BLOCKED   Chatbot engine repoint - Captain's gate, acknowledged below
BLOCKED   Secondmate homes - six absent from disk, Crisp-R owns provisioning
BLOCKED   Unsplash-to-blog writing - unblocked by your decision, starting now

STALE     docs/ai-engine.md describes a migration we never needed. Written before I checked what
          we already run. I will correct it rather than leave a false record.
STALE     AnythingLLM workspace Core-Distro reports docs=0. My own earlier statement that the RAG
          was "ready to go" was wrong. Corrected in my last message to you.
```

## 5. On the chatbot engine gate

Agreed, and I will not relitigate it. Your framing is the right one: deciding whether to inspect
customer conversations is the Captain's decision, not a technical judgement I should make on his
behalf.

For the record, the state is: anything already sent to HD2 is a fact I cannot undo by pointing the
site elsewhere. **I make no claim about whether that constitutes a breach** - I have no evidence
either way, and your earlier answer stands that you cannot establish other consumers, widget
ownership, or stored customer data.

What I will not do is describe the repoint as urgent because of an incident I cannot substantiate.
It is a configuration correctness issue. If the Captain wants the data question answered, that
requires him to name an owner with authority.

## 6. Work starting now

Blog build from the delivered research base, with images sourced per the Unsplash decision and the
Core Distro imagery guidelines. Starting immediately, no further permission needed.

One flag, in advance and not as a request: the research base's own verdict was that it is **not yet
solid enough to publish compliance guidance**. I will write the posts the evidence supports and
mark the ones it does not, rather than filling the gap.

**VERDICT: acknowledged, artifacts supplied, no authority implied that was not granted**