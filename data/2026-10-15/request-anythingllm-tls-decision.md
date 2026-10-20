# Request for decision - AnythingLLM needs an HTTPS endpoint

**Correlation:** `2026-10-16-hetz-reply-priority-decisions.md`
**Captain's status:** done for tonight. He asked me to bring you this rather than make the call.

## Where it stands

The chatbot is **repointed and verified loading from our own Hetz AnythingLLM** on staging.

```
widget src   http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js
embed id     fd029baa-22fd-4a3a-b074-40c7a00daf30
workspace    Core-Distro   (created today; our instance previously had only an Elevate embed)
brand image  now staging origin, no longer core-distro.com
release      release-20261016_171018, staging 200 on all routes including /blog
```

Verified in a real browser: clicking "ASK QUESTIONS" loads our widget from Hetz with the new embed id.

## The single blocker

**Our AnythingLLM is HTTP only.** An HTTPS page cannot load an HTTP script, so the browser blocks it
as mixed content. Verbatim console error:

```
error: Access to script at 'http://100.106.6.22:3001/embed/anythingllm-chat-widget.min.js'
from origin 'https://staging.core-distro.com' blocked
```

The configuration is correct and the service is healthy. It needs TLS in front of it. I checked:
no certificate exists on this host for this service, no TLS on port 3001, and the docker-compose
declares no SSL or BASE_URL settings.

## What I need from you - one decision

**Which hostname should carry TLS for the AnythingLLM widget?**

My recommendation, and my reasoning:

```
chat.core-distro.com   A record -> 100.106.6.22   (the Hetz AnythingLLM)
                        Let's Encrypt via webroot, same pattern as the staging cert
```

Reasons:
1. It keeps Core Distro customer conversations **inside the Core Distro domain boundary**, which is
   the entire reason this migration exists. Putting the widget on an HD2-owned hostname would
   recreate exactly the cross-boundary problem we are removing.
2. It is one DNS A record and one certificate. No new infrastructure.
3. It does not expose 3001 publicly. Only 443 is added, fronted by a reverse proxy that forwards
   127.0.0.1:3001.

**Alternative if you prefer:** reuse an existing hostname already pointed at Hetz. I do not know of
one for this purpose and will not guess.

## Constraints I will hold regardless of the answer

```
never expose 11434 or 3001 directly to the internet
Ollama stays localhost-only
the TLS proxy forwards to 127.0.0.1:3001 only
no change to core-distro.com production until explicitly authorised
```

DNS and registrar changes are your gate and the Captain's, not mine. I have changed nothing of the
sort and will not without both of you.

## Two things you should know

1. **The staging host rebooted at 17:08.** Uptime was one minute when I reconnected. Staging came
   back on the same release and is healthy. I did not restart it and I cannot prove nobody else
   did. Worth an answer before that box is treated as stable.
2. **Core Distro's AnythingLLM workspace has zero documents.** The RAG is not populated. The widget
   will answer, but from an empty corpus. That is a content task, not a config one.

## What I am not asking you to decide

The `Core-Distro` embed I created is on **staging only**. Nothing about production has changed.