# WO-0008 CBD-Data: real verification results

## Scope and safety

Work was limited to `/tmp/wt-wo0008-cbddata`. No production writes, migrations, schema changes, database queries, DNS changes, registrar or deployment actions, or access to the srv1137994 / Aminolifesciences host were performed. The only production request below was an HTTPS `GET` of the public homepage.

## Measured starting point

The worktree was on the requested branch, and the initial tracked-file search showed this is the Firstmate repository, not the CBD-Data application repository:

```text
$ git -C /tmp/wt-wo0008-cbddata status --short --branch && git -C /tmp/wt-wo0008-cbddata rev-parse --show-toplevel && git -C /tmp/wt-wo0008-cbddata branch --show-current
## wo-0008/cbddata
/tmp/wt-wo0008-cbddata
wo-0008/cbddata
```

The candidate search for app manifests, app entry points, CBD-named files, and export-worker files produced:

```text
$ printf '%s\n' '--- app source candidates ---'; find /tmp/wt-wo0008-cbddata -maxdepth 3 -type f \( -name 'package.json' -o -name 'composer.json' -o -name 'artisan' -o -name 'manage.py' -o -iname '*export*worker*' -o -iname '*cbd*' \) -print; printf '%s\n' '--- CBD-Data source directories ---'; find /tmp/wt-wo0008-cbddata -maxdepth 3 -type d \( -iname '*cbd*' -o -iname '*app*' -o -iname '*worker*' \) -print
--- app source candidates ---
/tmp/wt-wo0008-cbddata/.opencode/plugins/package.json
--- CBD-Data source directories ---
/tmp/wt-wo0008-cbddata
/tmp/wt-wo0008-cbddata/.agents/skills/firstmate-codexapp
```

That lone package manifest is for an editor plugin, not the CBD-Data app. No CBD-Data verifier or export-worker implementation/entry point is present in this worktree. Therefore neither application verification nor export-worker execution could be run without leaving the required work boundary; no app/project directory outside the worktree was accessed.

## Checks and evidence

### Public homepage reachability — PASS (limited check only)

Command:

```text
curl --max-time 15 --silent --show-error --output /dev/null --write-out 'http_code=%{http_code}\nremote_ip=%{remote_ip}\ncontent_type=%{content_type}\n' https://www.cbd-data.com/
```

Verbatim output:

```text
http_code=200
remote_ip=68.65.123.217
content_type=text/html; charset=UTF-8
```

This proves only that the public homepage returned HTTP 200 from the reported remote IP at the time of the request. It does not verify application data integrity, API behavior, exports, background processing, or the export worker.

### CBD-Data application verification path — UNVERIFIED

Could not run: no CBD-Data application source or verification command is present in `/tmp/wt-wo0008-cbddata`. No production verification endpoint or credential was assumed, and no database query was attempted.

### CBD-Data export-worker path — UNVERIFIED

Could not run: no CBD-Data export-worker implementation or entry point is present in `/tmp/wt-wo0008-cbddata`. No worker was started and no production job was submitted.

## Verdict

VERDICT: The public CBD-Data homepage was reachable (HTTP 200), but the current production data/application correctness and export-worker health are UNVERIFIED because the authorized worktree contains no CBD-Data application or worker code, and production verification/export paths could not be run within the stated safety and work-boundary constraints.
