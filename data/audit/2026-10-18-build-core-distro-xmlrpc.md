# Core Distro XML-RPC live verification

**Date:** 2026-10-18 01:37 UTC  
**Scope:** Live, unauthenticated HTTP checks only. No production or local service configuration was changed.

## Required source review

Read before probing:
- `data/audit/2026-10-18-audit-core-distro.md`
- `BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-18-hd2-fm-domain-prds-review-verdict.md`

The source records say the exposure was found in post-mortem `b1849af` §7.2 and identify a Hostinger/nginx deny as mitigation not previously applied. That historical claim was not assumed to describe the current state.

## Current live measurement

Target resolved to `66.29.153.174`. Each request below independently received HTTP 403, `content-type: text/html`, 93 bytes, with body:

```html
<html><body><h1>403 Forbidden</h1> Request forbidden by administrative rules. </body></html>
```

Commands and results:

```text
curl -sS -k --max-time 15 -D - -o /tmp/core-xmlrpc-get.body -w '\nHTTP_CODE=%{http_code} REMOTE_IP=%{remote_ip} CONTENT_TYPE=%{content_type} BYTES=%{size_download}\n' https://core-distro.com/xmlrpc.php
=> HTTP/2 403; HTTP_CODE=403 REMOTE_IP=66.29.153.174 CONTENT_TYPE=text/html BYTES=93

curl -sS -k --max-time 15 -X OPTIONS -D - -o /tmp/core-xmlrpc-options.body -w '\nHTTP_CODE=%{http_code} REMOTE_IP=%{remote_ip} CONTENT_TYPE=%{content_type} BYTES=%{size_download}\n' https://core-distro.com/xmlrpc.php
=> HTTP/2 403; HTTP_CODE=403 REMOTE_IP=66.29.153.174 CONTENT_TYPE=text/html BYTES=93

curl -sS -k --max-time 15 -D - -o /tmp/core-xmlrpc-post.body -H 'Content-Type: text/xml' --data '<?xml version="1.0"?><methodCall><methodName>system.listMethods</methodName><params></params></methodCall>' -w '\nHTTP_CODE=%{http_code} REMOTE_IP=%{remote_ip} CONTENT_TYPE=%{content_type} BYTES=%{size_download}\n' https://core-distro.com/xmlrpc.php
=> HTTP/2 403; HTTP_CODE=403 REMOTE_IP=66.29.153.174 CONTENT_TYPE=text/html BYTES=93
```

**Conclusion:** XML-RPC is not reachable via GET, OPTIONS, or a non-mutating `system.listMethods` POST from this probe. The rule is currently effective at some administrative layer. The POST was blocked before an XML-RPC response; no method inventory was obtained.

## Main site and admin-path check

```text
curl -sS -k --max-time 20 -L -D /tmp/core-check.headers -o /tmp/core-check.body -w 'HTTP_CODE=%{http_code} EFFECTIVE_URL=%{url_effective} REMOTE_IP=%{remote_ip} CONTENT_TYPE=%{content_type} BYTES=%{size_download}\n' https://core-distro.com/
=> HTTP_CODE=200 EFFECTIVE_URL=https://core-distro.com/ REMOTE_IP=66.29.153.174 CONTENT_TYPE=text/html BYTES=73028
=> response header: server: LiteSpeed

curl -sS -k --max-time 20 -L ... https://core-distro.com/wp-login.php
=> HTTP_CODE=200, text/html, 745 bytes; response body is a “Checking your browser…” challenge page.

curl -sS -k --max-time 20 -L ... https://core-distro.com/wp-admin/
=> HTTP_CODE=200, text/html, 745 bytes; response body is the same browser-challenge page.
```

The homepage responds normally. The login/admin checks did **not** reach a login form or authenticated admin session, so admin functionality cannot be certified from these unauthenticated probes. No credentials were used. A `GET /wp-json/` returned 404 HTML, not a REST response.

The public homepage body contained no occurrences of `jetpack`, `xmlrpc`, `wp-content`, `wordpress`, `wp-json`, `woocommerce`, or `jetpack-json-api`; that is not a reliable inventory of installed plugins, server-side integrations, or scheduled publishing.

## Mutation decision, control layer, and rule prepared

No new deny rule was applied: the live endpoint already refuses the tested methods with 403. Adding another rule without identifying the active control layer would be an unverified and potentially conflicting production mutation. The live response identifies `66.29.153.174` and advertises LiteSpeed, which does not establish that Hostinger/nginx is currently the controlling layer. No Hostinger panel, origin configuration, credentials, or server logs were available in this lane. No configuration file was changed, so no config backup was created. This report is a new file; it had no pre-existing version to back up.

If the operator verifies that the active request-serving configuration is nginx, the minimal rule to add is:

```nginx
location = /xmlrpc.php {
    return 403;
}
```

Place it in the active HTTPS `server` block serving `core-distro.com`, before the generic PHP/FastCGI handler, then validate/reload through the host's supported procedure and repeat the GET/OPTIONS/`system.listMethods` probes. Do **not** paste this into an unverified Hostinger/nginx configuration: current public evidence points to a LiteSpeed response, and the actual administrative deny owner is unknown. Required access/evidence to finish attribution is the Hostinger/domain control panel or authorized access to the active origin/web-server configuration, plus relevant access/plugin/integration inventory or logs.

## Whether Core Distro uses XML-RPC

**Unknown.** A 403 proves the tested endpoint is blocked; it does not establish whether Jetpack, WordPress mobile clients, an external publisher, or scheduled publishing currently depends on XML-RPC. Homepage HTML and unauthenticated probes cannot answer that. Confirm from the WordPress plugin/integration inventory, application settings, and relevant access logs before changing policy. Since the endpoint is already blocked, preserving it blocked is the current observed behavior; if an actual client failure is reported, verify that integration before considering an exception.

## Backup and verification record

- Production/config backup: none; no production/config mutation was made.
- Report backup: none; the target report did not exist before creation.
- Verification commands: the curl commands above; report target preflight `test -e .../data/audit/2026-10-18-build-core-distro-xmlrpc.md` returned `no` before creation.
- Repository check: `git -C /home/hd2admin/kun-agent-workspace status --short` showed only pre-existing untracked `core-distro-saas-clean` and `firstmate`; `git -C ... diff --cached --name-only` returned no staged paths.
- Remaining blocked: identify the administrative rule owner and confirm actual XML-RPC clients/admin operation using authorized Hostinger/origin access and application inventory. No production rule change was needed for the measured exposed surface because the endpoint currently returns 403.
