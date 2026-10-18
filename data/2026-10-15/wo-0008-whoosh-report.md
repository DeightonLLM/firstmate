# WO-0008 WHOOSH — existence check

**Scope:** Local, read-only searches plus public DNS/HTTP observation. No production, DNS, registrar, credentials, host login, SSH, or remote host connection was used. The public HTTPS GET was only to inspect the named website, as requested.

## Evidence

### Local repositories, workspaces, and saved work

The requested project directory contains only the two named projects:

```text
$ find /home/hd2admin/kun-agent-workspace/projects -maxdepth 2 -print
/home/hd2admin/kun-agent-workspace/projects
/home/hd2admin/kun-agent-workspace/projects/core-distro-saas-clean
/home/hd2admin/kun-agent-workspace/projects/firstmate
```

I searched every directory under `/home/hd2admin/.treehouse` for Whoosh-named paths. No hits were returned. I also searched those workspace slots for Whoosh references; hits were only Firstmate/warehouse context documents and reports, not an application repository. A source/deployment-manifest search of every workspace slot returned no hits:

```text
$ grep -RIl --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.next --include='package.json' --include='pyproject.toml' --include='Cargo.toml' --include='Dockerfile*' --include='docker-compose*.yml' --include='docker-compose*.yaml' --include='*.tf' --include='Procfile' --include='vercel.json' --include='fly.toml' --include='wrangler.toml' -i whoosh /home/hd2admin/.treehouse
exit=1
```

The home-wide `.git` directory scan for repository roots whose names contain `whoosh` returned no paths or remotes. The same scan within `.treehouse` also returned no paths or remotes. No Whoosh-named folder exists in Brandon's inbox:

```text
$ find /home/hd2admin/brandon-inbox -iname '*whoosh*' -print
[no output]
```

The preserved-work directory contains only these unrelated files:

```text
$ find /home/hd2admin/kun-agent-workspace/warehouse/preserved-work -maxdepth 1 -type f -print
/home/hd2admin/kun-agent-workspace/warehouse/preserved-work/core-stream-a-checkpoint-0924.md
/home/hd2admin/kun-agent-workspace/warehouse/preserved-work/README.md
/home/hd2admin/kun-agent-workspace/warehouse/preserved-work/core-mobile-fix.md
/home/hd2admin/kun-agent-workspace/warehouse/preserved-work/core-v3-product-acceptance-spec-0927.md
```

The local `whoosh-ops` charter says it has **no project clones**. The PRD/report material assigns `whoosh-ops` as the sole owner, but describes that as a domain assignment, not as evidence of source or a running app.

### Existing Whoosh records

The dated Whoosh warehouse (`/home/hd2admin/agent-work/firstmate/data/domain-warehouses-20260915/whooshperformance.com/`) explicitly records:

- Source repository: `UNKNOWN`; no eligible project checkout found.
- Current host/runtime/public IP: `UNKNOWN`.
- State: `BLOCKED: COORDINATES_MISSING`.
- Its `SOURCES.md` says no repository, host, IP, deployment, credentials, or runtime evidence was found.

The PRD assigned `whoosh-ops`, requires an identified approved application rather than a parked-domain response, and records no live application surface or passing application-health check. It says repository/runtime/hosting coordinates are missing. This corroborates the inventory; it does not establish that an app exists.

### DNS and public website

Verbatim output:

```text
$ getent ahosts whooshperformance.com
2.57.91.91      STREAM whooshperformance.com
2.57.91.91      DGRAM  
2.57.91.91      RAW    
exit=0

$ curl -sSIL --max-time 20 https://whooshperformance.com/
HTTP/2 200 
date: Thu, 15 Oct 2026 23:55:24 GMT
content-type: text/html
cache-control: no-store
server: hcdn
alt-svc: h3=":443"; ma=86400
x-hcdn-request-id: eb173944b4ad615d25dbfc181e9df93a-fra-edge10
exit=0
```

The public response body begins:

```html
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="robots" content="noindex, nofollow, noarchive, nosnippet"><title>Parked Domain name on Hostinger DNS system</title>
```

The resolved address and HTTP 200 therefore identify a parked Hostinger page, not a Whoosh application. They do not identify an application host or runtime.

## Conclusion

No Whoosh application repository, source/deployment manifest, runtime, deploy path, or hosting coordinates were found in the searched local inventory. The only positive findings are project ownership/documentation records and a parked domain. No coordinates can responsibly be supplied.

VERDICT: WHOOSH DOES NOT EXIST
