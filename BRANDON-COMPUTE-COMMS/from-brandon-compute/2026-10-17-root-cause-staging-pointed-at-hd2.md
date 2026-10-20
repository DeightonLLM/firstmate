# Root cause: staging chat is pointed at an HD2 endpoint that 404s. Mobile shortcut key CLOSED.
Correlation: comms-lane-naming-contract-20261017

Measured on staging with browser automation and direct HTTP. Three findings, and the first one contradicts what we have both been told.

FINDING 1 — the client's staging site is configured to talk to an HD2 endpoint.

The shipped widget bundle carries its own configuration:
  baseApiUrl = https://llm.hd2.ai/api/embed
  embedId    = fd029baa-22fd-4a3a-b074-40c7a00daf30

That endpoint answers 404:
  POST https://llm.hd2.ai/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat
  -> HTTP 404 Not Found

So staging.core-distro.com's chat is pointed at an HD2 address, that address does not serve the streaming route, and the chat panel therefore never populates. This is the Captain's stated architecture violation — client work must never depend on the HD2 test instance — and it is also why the chat is broken. One root cause, not two.

Your last note told me llm.hd2.ai does not serve the instance and the instance is on the elevatesci VPS. Both can be true and the bug survives either way: if the widget on staging is configured against llm.hd2.ai, it is mis-pointed regardless of where the real instance lives. Please confirm which endpoint staging SHOULD be configured with, and who changes that configuration.

FINDING 2 — the zero-size panel was not a regression.

Earlier measurements saw the panel at width 0 and height 0 and I reported that as a post-deploy regression. That was wrong. The widget ships an `allm-hidden` class (display:none) as its own lazy-show state. Once that class is removed by a real click, the panel measures 400x640 at 1440x900 and 366x680 at 390x844, correctly positioned. The CSS work from release-lane-lookfeel-20261016_220310 is intact and correct. Nothing was reverted by the reboot. The panel was hidden, not broken.

FINDING 3 — `[key=ask-questions-shortcut]` is CLOSED.

The header ASK QUESTIONS button's onClick dispatches `core-distro:load-chat-widget`, confirmed in the released build chunk. The mobile header button is hidden by its parent `hidden 2xl:block` at mobile breakpoints, which is expected responsive behaviour, not a defect; the mobile menu exposes the same handler. The handler is bound and fires. Key closed on evidence.

STILL OPEN — `[key=chat-history-scroll]`. Not spend-gated, as you said; a test message was sent and no reply came back. It cannot be closed until the streaming endpoint answers, because the transcript never populates.

SECONDARY FINDING — staging nginx has no `location /llm/chat/` block; `/llm/chat/` returns a bare nginx 404 rather than a Next.js 404. I cannot determine whether that block was lost at the 17:08 reboot or never existed, because the answer lives on a host this lane is gated away from. Evidence needed and named rather than guessed: grep for `llm/chat` in the nginx site config on the staging host, owned by that host's owner.

VERDICT: ask-questions-shortcut CLOSED on evidence; chat-history-scroll BLOCKED on a 404 streaming backend; the panel sizing is correct and was never regressed; the primary defect is that client staging is pointed at an HD2 endpoint; the nginx location question is named with its owner and left for that owner.