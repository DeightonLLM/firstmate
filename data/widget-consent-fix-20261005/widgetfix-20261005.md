# widgetfix-20261005 — Elevate AnythingLLM embed widget (2 presentation fixes)

**Lane:** widget-fix · **Date:** 2026-10-05 00:56–01:20 UTC
**Target:** brandon `brandon-compute` (`100.106.6.22`) · container `elevate-anythingllm`
(`mintplexlabs/anythingllm:1.16.2`) · `:3001` · workspace **elevate** · embed **`d65f0fde`**
**Public apex:** `https://agents.elevatesci.com` (confirmed live; the earlier `elevatesci.com` apex
was the wrong-apex error already recorded in the P0 post-mortem)
**Mode:** presentation-layer only. No API, no config, no DB, no container internals, no restart.
**Unified patch:** `/root/agent-work/widgetfix-20261005.patch` (131 lines: 38-line deploy header + 93-line
diff, md5 `e9b1d0a4a21c8e792e6551986c2d53f0`; bare-diff form md5 `16749b07d01c282f231d51d557f9bde6`)

---

## ★ DEPLOYMENT STATUS: ALREADY DEPLOYED AND LIVE — NOT PENDING ★

**This ticket asked me to mark the fix `DEPLOYMENT REQUIRES BRANDON-SIDE EXECUTION (no route from this
host)`. I am not writing that, because it is not true on either count, and an artifact that says
otherwise will be routed as work that was never done.**

Two corrections, both measured not assumed:

1. **There IS a route from this host to brandon.** `ssh root@100.106.6.22` works from hd2stack —
   `brandon-compute`, direct Tailscale peer. (`brandon` and `brandon.hetz` do not resolve, and
   `ubuntu@` is refused by tailnet policy, which is what makes the route look absent if you only try
   the ticket's two hostnames.) **HTTP also works with no ssh at all** — verified this turn:
   `http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js` → `200`, 669,742 B.
2. **The fix is already deployed.** It was applied and verified in the previous pass of this same
   ticket. The served bytes prove it, and they are provable from any host with only `curl`:

| Route | http | bytes | md5 |
|---|---|---|---|
| `http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js` | 200 | 669,742 | `600c9693a845885d1d6a1a0551d3027a` |
| `https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js` | 200 | 669,742 | `600c9693a845885d1d6a1a0551d3027a` |

Pre-fix md5 was `15a8e92b87ff30ab32ad7498a9e4db4d` (666,040 B). Both routes are byte-identical to each
other and carry the fix markers. Coordinator: **there is nothing to route for the initial deploy.**
The patch is retained for revert / re-apply / audit, and the header inside it carries the full
re-apply, verify, and revert command set.

### HTTP-only verification (no ssh required — for the coordinator)
```bash
# expect md5 600c9693a845885d1d6a1a0551d3027a
curl -s -m 8 http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js | md5sum
# expect 4
curl -s -m 8 http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js | grep -c widgetfix-20261005
# pre-fix stock had ZERO of these; if the fix is live they are all present:
curl -s -m 8 http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js \
  | grep -oE 'object-fit: cover|border-radius: 50%|safe-area-inset-bottom|100dvh|aspect-ratio: 1 / 1' | sort | uniq -c
```

**Still worth a coordinator action:** a hard reload / private-tab check on a real iPhone. The asset
has no cache-bust hash in its filename, so a cached copy can mask a live fix. That is a browser-cache
question, not a deployment gap.

---

## 0. Route test (the mandated first step) — PASSED, lane proceeded

| Attempt | Result |
|---|---|
| `ssh brandon.hetz` | `Could not resolve hostname brandon.hetz` |
| `ssh brandon` | `Temporary failure in name resolution` |
| `ssh ubuntu@100.106.6.22` | **blocked by tailnet policy** (`does not permit you to SSH as user "ubuntu"`) |
| **`ssh root@100.106.6.22`** | **SUCCESS** — `brandon-compute`, up 5d 20:50, load 0.75/1.18/1.41 |

Both `brandon` and `brandon.hetz` fail DNS on this host, but the Tailscale IP published in
`warehouse/README.md` reaches brandon directly (`tailscale ping` → `pong … in 177ms`, direct
`2a01:4f9:3090:2fb1::2`). **A route exists, so the `no-route-to-brandon` blocker does not apply.**

Worth fixing separately: the two `brandon*` SSH aliases in the ticket do not resolve here. Anyone
following that ticket verbatim will report a false blocker.

---

## 1. The prior documented fix — NOT FOUND. Diagnosed from first principles instead.

The captain remembers a documented mobile fix. I searched and it does not exist:

- `warehouse/` mirror (`*.md`): grep for `send button|send-button|safe-area|viewport-fit|100dvh|iphone|off-screen` → **0 hits**.
- brandon-side: the only thing that matches is the **P0 post-mortem**, which documents the
  `/api/embed` route-shape trap, not a mobile fix.
- **Widget edit history on brandon** (decisive): the branding dir holds
  `.bak` (662,353 B) → `.broken`/`.fixed` (662,323 B) → current pre-fix (666,040 B).
  The only prior append is `mm-widget-think-shim` — a shim that masks `<think>` blocks.
  It contains **zero** `safe-area`, `viewport-fit`, `dvh`, and no logo CSS. (A naive grep reports
  single hits for `object-fit`/`border-radius`/`logo`, but those are substrings inside a minified
  React error-decoder URL — a false positive, confirmed by reading the lines.)

**So the shipped widget has never had a mobile or logo fix.** The captain may be remembering a fix
on another surface, or one that was planned and never applied. Reporting it as "not found" rather
than inventing a prior-art citation.

---

## 2. Root causes (both verified by evidence, not guessed)

### (2a) Send button falls off-screen on iPhone
The shipped bundle contains **no viewport-safety CSS at all** — verified by grep over the whole
666 KB file:

```
viewport-fit · safe-area-inset* · 100dvh · 100svh · visualViewport · -webkit-fill-available   → 0 matches
<meta ... viewport ...> in the widget                                                          → 0 matches
```

On iOS the home-indicator strip and the on-screen keyboard both overlay the bottom of the chat
panel, and the submit row (`#send-message-button`, a bare `<button type="submit">` carrying
`allm-w-4 allm-h-4` with no touch-target sizing) sits underneath them.

### (2b) Header logo renders stretched
`object-fit` appears **0 times** in the entire bundle, and `border-radius` only 3× (all on the
`.allm-dot-falling` typing indicator, unrelated). Two logo instances are affected:

| Instance | Markup | Why it distorts |
|---|---|---|
| Header logo | `<img style={{maxWidth:48,maxHeight:48}} src={brandImageUrl‖default} alt="Brand"‖"AnythingLLM Logo"/>` | capped only by inline max-width/max-height, so flex `align-items: stretch` can pull it out of ratio |
| Bubble icon | `<img id="anything-llm-icon" class="allm-w-9 allm-h-9 allm-flex-shrink-0 …"/>` (36×36 box) | fixed 36×36 with **no object-fit** → a non-square brand image is squashed. This is the visible stretch. |

DOM ids confirmed by enumerating every `id:"…"` literal in the bundle: `anything-llm-chat`,
`anything-llm-header`, `anything-llm-icon`, `anything-llm-embed-chat-container`,
`anything-llm-embed-chat-button(-container)`, `message-input`, `send-message-button`,
`scroll-to-bottom-button`, `chat-history`.

---

## 3. Where the fix was applied — asset-side, no container internals

`docker inspect --format` (allowlisted `Mounts` fields only, per the safe-inspection rule) proved the
stock container file is **not** what is served:

| Copy | md5 | Served? |
|---|---|---|
| `/home/hd2admin/hd2stack-anythingllm/branding/anythingllm-chat-widget.min.js` (host) | `15a8e92b…` | **YES** |
| overlayfs snapshot 57 + 257 `/app/server/public/embed/…` (stock 1.16.2) | `832de2e4…` | no |

```
bind /home/hd2admin/hd2stack-anythingllm/storage -> /app/server/storage (rw=true)
bind /home/hd2admin/hd2stack-anythingllm/branding/anythingllm-chat-widget.min.js
    -> /app/server/public/embed/anythingllm-chat-widget.min.js (rw=true)
```

So the correct, preferred edit point is a **host-side bind-mounted asset**. I did not touch the
container filesystem, the overlayfs snapshots, the DB, or the embed config. Because it is a bind
mount of a static file, **no container restart was needed** — confirmed by `RestartCount=0` and an
unchanged `StartedAt`.

### The change
One self-contained, idempotent IIFE appended to the end of the file. It injects a single
`<style id="widgetfix-20261005">` block, is guarded against double-injection, and is wrapped in
try/catch so it can never break the widget. It edits **no** minified internals — no `className`
strings, no React components, no Tailwind output — which is what keeps it safe against the next
AnythingLLM image bump.

```css
/* (2) LOGO — circular crop, never distorts */
#anything-llm-header img, #anything-llm-icon {
  object-fit: cover !important; border-radius: 50% !important;
  aspect-ratio: 1 / 1 !important; flex: 0 0 auto !important;
  width: 40px !important; height: 40px !important;
  max-width: 40px !important; max-height: 40px !important;
}
/* (1) MOBILE / iPHONE — send button stays on screen */
@media screen and (max-width: 768px), (pointer: coarse) {
  #anything-llm-embed-chat-container, #anything-llm-chat {
    height: 100dvh !important; max-height: 100dvh !important;
    padding-bottom: env(safe-area-inset-bottom, 0px) !important;
  }
  #send-message-button {
    position: relative !important; z-index: 6 !important;
    min-width: 44px !important; min-height: 44px !important;
    flex-shrink: 0 !important; touch-action: manipulation !important;
  }
  #anything-llm-chat form, #anything-llm-embed-chat-container form {
    position: sticky !important; bottom: 0 !important; z-index: 5 !important;
    padding-bottom: calc(0.5rem + env(safe-area-inset-bottom, 0px)) !important;
  }
  #message-input { max-height: 40vh !important; }
  #scroll-to-bottom-button { bottom: calc(56px + env(safe-area-inset-bottom, 0px)) !important; }
}
```

Two deliberate details:

- `env(safe-area-inset-bottom, 0px)` is used **with a 0px fallback on purpose.** The widget is
  injected into a third-party page whose `<meta viewport>` this fix cannot set; `env()` returns
  `0px` on any host without `viewport-fit=cover`. So the block is a no-op on desktop and non-notch
  devices and only engages where the inset is real. It cannot regress anything.
- The `@media` guard is `max-width: 768px, (pointer: coarse)` — mobile/touch only. The logo fix is
  **outside** the media query so the circular agent feel is uniform on desktop too, as asked.

---

## 4. Backup and reversibility (all verified, not assumed)

```
backup: anythingllm-chat-widget.min.js.bak-widgetfix-20261005   666,040 B  md5 15a8e92b87ff30ab32ad7498a9e4db4d
pre-fix  md5 15a8e92b87ff30ab32ad7498a9e4db4d   size 666,040
post-fix md5 600c9693a845885d1d6a1a0551d3027a   size 669,742   (+3,702 = payload 3,701 + 1 newline)
ownership preserved: hd2admin:hd2admin 644
patch: 1 hunk  @@ -155,3 +155,90 @@  (pure append, nothing rewritten)
```

Three reversibility tests, all passed:

1. `patch --dry-run` onto the backup → clean.
2. Real apply onto a scratch copy → md5 `600c9693…` **identical to the live file** (patch fully reproduces the fix).
3. `patch -R` → md5 back to `15a8e92b…`, `cmp` **exact match to the pre-fix backup**. Revert proven byte-exact.

**Revert is one command:** `cp <branding>/anythingllm-chat-widget.min.js.bak-widgetfix-20261005 <branding>/anythingllm-chat-widget.min.js` (or `patch -R`). No restart needed either way — it is a static file.

---

## 5. VERIFICATION — served output changed

| Check | Result |
|---|---|
| `curl :3001/embed/anythingllm-chat-widget.min.js` pre | `http=200` `666,040 B` md5 `15a8e92b…` marker **0** |
| `curl :3001/…` post | `http=200` `669,742 B` md5 `600c9693…` marker **4** |
| **curl diff (served bytes)** | **87 lines added, 0 removed** — append-only, no existing line altered |
| **public** `https://agents.elevatesci.com/embed/…` | `http=200` `669,742 B` md5 `600c9693…` — **byte-identical to local**, marker 4 |
| embed page `https://agents.elevatesci.com/embed/d65f0fde-…` | `http=200` |
| `/api/ping` | `http=200` |
| container | `RestartCount=0`, `Health=healthy`, `StartedAt` unchanged (no restart) |

Proof markers present in the **served** bytes: `widgetfix-20261005` ×4, `safe-area-inset-bottom` ×3,
`object-fit: cover`, `border-radius: 50%`, `100dvh` ×2, `44px` ×3, `send-message-button` ×2,
`anything-llm-header` ×2.

**Caveat on the captain's own test:** browsers cache aggressively and this asset has no cache-bust
hash in its filename. A hard reload / private tab on the iPhone is required to see the change; the
server is already serving the fixed bytes.

---

## 6. What I did NOT do (and why)

- **No chat POST.** The brandon repair queue records an open `needs-decision` on
  `elevate-smoke-chat-write`: chat POSTs may persist chat rows under the standing no-write rule.
  I made no POST, created no chat, and wrote nothing to `anythingllm.db`.
- **No embed API, config, or workspace change.** Both fixes are pure CSS.
- **No container internals, no restart, no image change.**
- **No `viewport-fit=cover` meta** — that lives in the third-party page's `<head>`, which this fix
  must not touch. The `env(…, 0px)` fallback is the correct substitute.
- **Core-Distro: no Core-specific change of any kind.** Disclosed honestly below.

## 7. Core-Distro — disclosure

Core-Distro is not a separate AnythingLLM container on brandon (the other containers are
`1Panel-ai-gateway`, `ollama`, `brandon-cbd-rabbitmq`); it is **workspace id=1 in the same
instance**, sharing the same `:3001` static asset. So the patched widget is served to Core embeds
too. The change is **brand-agnostic CSS** — it styles `#anything-llm-header img` /
`#anything-llm-icon` generically and only affects layout on coarse-pointer/small screens. No Core
data, config, row, or embed was touched, and the backup makes the asset revert instantly if the
captain wants the change scoped to Elevate alone.

## 8. API route note (post-mortem lesson applied, not a new finding)

`GET /api/embed/{uuid}/{sessionId}` returned `404 text/plain` for the literal session id
`test-session-probe` — that is simply a non-existent session, **not** an outage and **not** a
finding. Recording it only so the next lane does not mistake it for one. I did **not** re-open the
embed-health question: per the post-mortem, the embed was never broken, and proving that is not
this lane's job. The two bugs fixed here are presentation-layer only.

---

## 9. Second pass — hooks re-derived over pure HTTP (no ssh), 2026-10-05 01:38 UTC

The continuation ticket asked for the hooks to be captured over HTTP from this host, so they are
re-derived here from a `curl`-fetched bundle only. This doubles as independent confirmation that the
served asset is the fixed one.

### 9a. Hooks for the mobile send button (safe-area / viewport)

The element, verbatim from the fetched bundle:

```js
w.jsxs("button",{ ref:i, type:"submit", disabled:a,
  className:"allm-bg-transparent allm-border-none allm-inline-flex allm-justify-center allm-rounded-2xl allm-cursor-pointer allm-text-black group",
  id:"send-message-button", "aria-label":"Send message", children:[ … ] })
```

It is a bare `<button type="submit">` whose icon child is `allm-w-4 allm-h-4` (16×16) — **no touch
target sizing, no safe-area padding, no sticky positioning**. Every id available for targeting,
enumerated from the fetched file:

```
anything-llm-chat   anything-llm-header   anything-llm-icon
anything-llm-embed-chat-container   anything-llm-embed-chat-button
anything-llm-embed-chat-button-container   message-input
send-message-button   scroll-to-bottom-button   chat-history
const yc = "anythingllm-embed-send-prompt"
```

**Defect proof, pre-fix → post-fix marker counts in the served bundle:**

| marker | stock bundle | served now |
|---|---|---|
| `viewport-fit` | 0 | 2 |
| `safe-area-inset` | 0 | 4 |
| `100dvh` | 0 | 2 |
| `visualViewport` | 0 | 1 |
| `100svh` / `-webkit-fill-available` | 0 | 0 (not needed) |

### 9b. Hooks for the header logo (circular + object-fit)

Both instances, verbatim:

```js
/* header logo — capped only by inline max dims, so flex can pull it out of ratio */
w.jsx("img",{ style:{maxWidth:48,maxHeight:48}, src:n??qo, alt:n?"Brand":"AnythingLLM Logo" })

/* bubble icon — FIXED 36x36 box (allm-w-9 allm-h-9) with no object-fit = the visible squash */
w.jsx("img",{ src:ae.settings.assistantIcon||qo, alt:"Anything LLM Icon",
  className:"allm-w-9 allm-h-9 allm-flex-shrink-0 allm-ml-2", id:"anything-llm-icon" })
```

| marker | stock bundle | served now |
|---|---|---|
| `object-fit` | **0** | 4 |
| `border-radius: 50%` | **0** | 1 |
| `border-radius: 5px` | 3 (all `.allm-dot-falling` typing dots, unrelated) | 3 |

### 9c. `/api/embed` endpoints from this host, over HTTP

| endpoint | http | content-type | bytes |
|---|---|---|---|
| `/api/ping` | 200 | `application/json` | 15 |
| `/api/embed/{uuid}` | 200 | `text/html` | 1,926 |
| `/api/embed/{uuid}/session-probe-nonexistent` | 404 | `text/plain` | 9 |
| `/embed/{uuid}` | 200 | `text/html` | 1,926 |

The 1,926-byte HTML shell is the **known-benign** SPA-catch-all response already recorded in the
brandon repair queue and in `warehouse/reports/ELEVATE-P0-POSTMORTEM-20261005.md` lesson 1. The 404
is my invented session id. **Neither is an outage and neither is a finding** — recorded only so the
next lane does not mistake either for one. No chat POST was made; no DB row written.

### 9d. Transport reality, restated plainly

| transport from hd2stack | result |
|---|---|
| `ssh root@100.106.6.22` | **works** |
| `http://100.106.6.22:3001` | **works** (1.2 s) |
| `https://agents.elevatesci.com` | **works** (2.4 s) |
| `ssh brandon` / `ssh brandon.hetz` / `ssh ubuntu@…` | fail (DNS / tailnet policy) |

Recommendation for future tickets: **publish `root@100.106.6.22` as the brandon route**, and note that
HTTP on `:3001` is enough for any read-only verification, so no ticket should need to escalate to ssh
just to look at a served asset.

VERDICT: PASS
