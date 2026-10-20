# WORK ORDER — Q3: Repoint Core-Distro Staging Chat off HD2 Endpoint

**From:** Controller (HD2 / `vmi3238503`)  
**To:** brandon-compute First Mate (`hd2admin@100.106.6.22`)  
**Date:** 2026-10-17T15:45:00Z  
**Correlation:** `hd2-standing-queue-q3`  
**Priority:** P1 — Q3 on standing queue

---

## 1. Directive

Execute your queued task:
`[m2.7h @ brandon] Repoint client chat off the HD2 endpoint`

Per the Captain's standing queue:
> "Q3 · Core-Distro staging points at the wrong instance. The client site's widget is configured with `baseApiUrl = https://llm.hd2.ai/api/embed`, which returns 404, so the client's chat never populates. Our internal instance must never serve a client endpoint. Owner: Hetz, instructed and driven by you. Verify the fix end to end with a real reply before calling it done."

Authorization under WO-0010 holds: staging fixes on `srv1137994` are permitted (read-only diagnosis, config backup before edit, `nginx -t`, and reload). Live domains, DNS, registrar, credentials, and spend remain strictly out of scope.

---

## 2. Execution Steps

1. **Staging Nginx Proxy Configuration (`srv1137994`):**
   - Back up the active Nginx config file before any modification with a dated `.bak` suffix.
   - Configure `/api/embed/` to reverse-proxy to the local AnythingLLM instance on `127.0.0.1:3001`.
   - Validate with `nginx -t`.
   - Reload Nginx (`nginx -s reload` or systemctl).

2. **Widget Configuration on Staging:**
   - Update the widget's `baseApiUrl` to `https://staging.core-distro.com/api/embed` (own origin, never `llm.hd2.ai`).
   - Retain the client's embed ID (`fd029baa-22fd-4a3a-b074-40c7a00daf30`).

3. **End-to-End Verification with Real Reply:**
   - Probe `POST https://staging.core-distro.com/api/embed/fd029baa-22fd-4a3a-b074-40c7a00daf30/stream-chat` with a sample user query (e.g. `{"message":"hello"}`).
   - Verify HTTP 200 response and capture streaming chat tokens.
   - Verify browser rendering at 390x844 (mobile) and 1440x900 (desktop).
   - Close `[key=chat-history-scroll]` on evidence of a real reply.

---

## 3. Deliverables

Report back via `from-brandon-compute/` with:
1. Exact Nginx diff on staging host and backup path created.
2. Exact curl command and raw response showing the streaming chat route returning HTTP 200 with tokens.
3. Status of `[key=chat-history-scroll]`.
4. Artifact path on Hetz (e.g. `data/hd2-takeover/report-q3-staging-chat.md`).
5. Final `VERDICT: PASS` line upon real reply proof.
