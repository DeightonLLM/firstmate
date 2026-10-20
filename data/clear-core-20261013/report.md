# Core entries and staging reality — read-only decision

## Method and current staging observation

Read the prior truth pass, available task briefs/reports/status events, the Core staging README, DEV_HANDOFF, test plan, and the PA spec challenge report/spec. I did not modify staging, the project tree, backlog, task records, or secondmate homes. `ctx_read` could not access the supervisor home due project-root containment; I used exact-path read-only reads where the brief authorized them. No browser screenshot was taken.

At 2026-10-14 01:16 UTC I queried only the authorized private staging URL with `curl -sS -I --max-time 10 http://100.106.6.22:8087/` (HTTP 200, Apache/PHP 8.3, WordPress API Link header). A read-only Python `urllib` GET checked the twelve documented routes: all twelve returned HTTP 200 and their expected titles. `/products/glass-vials-2/` returned 404. On `/about/`, `/products/`, and `/blog/`, the rendered HTML includes an `inert aria-hidden="true"` hidden fixed overlay; this is direct current evidence of the keyboard-exclusion markup, though it does not identify the overlay by a project-specific drawer selector. No screenshot/100%-zoom pixel comparison was made.

The README calls this a private preview, not production; forms are inert and chatbot absent. DEV_HANDOFF says the nine duplicate WordPress records (IDs 24–26, 35–37, 46–48) are an explicit unchanged hold, while the current public route check found one representative duplicate URL 404. That is evidence about the current route, not permission to inspect or mutate records. The 2026-10-13 test baseline is historical: 12/12 multipage GETs passed; `wp-page-records` failed on those nine duplicates; Funnel-only tests failed because Funnel was inactive; visual review was not run.

## Verdict table

| Entry | Verdict | Evidence path | One specific next action or question |
|---|---|---|---|
| `core-distro-stage-wp-multipage` | STILL NEEDS WORK | `/home/hd2admin/campaign/core-distro-stage/README.md`; `DEV_HANDOFF.md`; `test-plan.md`; current GET evidence above | Firstmate should obtain the authorized isolated visual review at desktop and mobile before calling the staging build review-complete; retain inert forms/chatbot and do not reopen the expired Funnel. |
| `core-distro-stage-scale-100pct` | STILL NEEDS WORK | `/home/hd2admin/kun-agent-workspace/data/backlog.md` entry; `/home/hd2admin/campaign/core-distro-stage/DEV_HANDOFF.md` notes screenshots/visual match remain unverified | Run the specific 100%-zoom whole-page parity comparison against the documented reference; current route/HTTP success does not prove visual parity. |
| `core-distro-stage-article-drawer-fix-20261012` | GENUINELY DONE | `/home/hd2admin/kun-agent-workspace/data/core-distro-stage-article-drawer-fix-20261012/article-drawer-fix-approval.md`; `DEV_HANDOFF.md` and its recorded `php tests/lighthouse-content-fixes.php` 34/34; current rendered hidden overlay has `inert` and `aria-hidden="true"` | Firstmate can reconcile/close the stale entry using this deployed markup and test evidence; do not change stored page content or protected duplicates. |
| `core-mobile-fix` | STILL NEEDS WORK | `/home/hd2admin/kun-agent-workspace/state/core-mobile-fix.status`; `/home/hd2admin/kun-agent-workspace/data/core-mobile-fix/brief.md` | Firstmate must review and preserve the reported uncommitted local-only changes before any landing decision; do not treat the task's `done` events as a clean committed delivery. |
| `core-stream-a-checkpoint-0924` | GENUINELY DONE | `/home/hd2admin/kun-agent-workspace/state/core-stream-a-checkpoint-0924.status`; `/home/hd2admin/kun-agent-workspace/data/core-stream-a-checkpoint-0924/launch-brief.md` | Firstmate should reconcile the ready branch/result and close the stale entry without rewriting or discarding it; status records four commits atop `2eb4e12` and smoke checks green. |
| `core-live-widget-source-0924` | NOT ACTIONABLE HERE | `/home/hd2admin/kun-agent-workspace/data/core-live-widget-source-0924/report.md`; `/home/hd2admin/kun-agent-workspace/state/core-live-widget-source-0924.status` | Ask for one current phone screenshot or exact element name: the report establishes a Next.js live page and lower-right widget, but does not confirm the reported lower-left symptom or its source owner. |

## PA-04 ownership gap and acceptance-spec implications

The spec is explicitly **proposed and unratified** (`data/core-stage-chunk4-spec-challenge/SPEC-under-review.md`, opening table and §1). Its own §11 note, independently summarized in `data/core-stage-chunk4-spec-challenge/report.md`, says `addLeads` accepts caller-supplied `list_id` without verifying that the parent list belongs to that caller; setting the inserted row's `user_id` does not establish ownership of the parent list. Therefore PA-04's “within an owned list” condition is not demonstrated by the proposed source-marker checks and cannot be accepted as passing on this evidence. It is a concrete ownership/security defect if the criterion is ratified as written, not merely missing test coverage. Do not claim a product-policy exception or silently ratify the condition.

The backlog already records the two relevant captain decisions: `core-stage-chunk4-spec-challenge-decision-pa04-owned-list-gap` and `core-stage-chunk4-spec-challenge-decision-spec-ratification-scope`. Their existing records say source correction vs confirmed exception needs owner decision, and all ten PA criteria remain unratified. Recommended priority: preserve that decision boundary, then route an authorized source correction to the Core project owner; the current report alone grants no implementation authority.

## Prioritized actions for Firstmate

1. **Protect the Core mobile local-only work**: inspect its exact local diff/state and resolve landing authority without discarding uncommitted changes. One question only if required: should the uncommitted local-only change be preserved for a follow-up or abandoned?
2. **PA-04 and spec authority**: keep the existing ownership-gap and spec-ratification decisions open; request product-owner direction on whether to correct `addLeads` ownership enforcement or document an explicit exception, and who can ratify PA-01–PA-10.
3. **Complete visual staging evidence**: run the explicitly requested 100%-zoom parity check and remaining desktop/mobile visual review through the authorized staging path; HTTP route checks alone are insufficient.
4. **Reconcile completed work**: close/resolve the article-drawer and Stream A entries only after Firstmate verifies task ownership records; Stream A is marked ready in its status event, not merged. Do not infer cleanup/landing from a `done` event.
5. **Widget diagnosis**: do not spend more effort on the old widget hypothesis without a screenshot/element identification; its report rules out the legacy PHP snapshot as authoritative for the live Next.js page.

## Evidence limits and closeout gate

Task status files for the multipage, scale, and article-drawer IDs were absent at the prescribed paths; the scale task artifact directory/report was absent. This pass therefore does not invent current task-state evidence. The staging checks were GET-only and do not establish visual parity, database contents, form/CRM behavior, or production readiness.

I read `/home/hd2admin/kun-agent-workspace/.agents/skills/decision-hold-lifecycle/SKILL.md`. The PA-04 and spec-ratification decisions already have structured backlog entries, but the skill additionally requires the authoritative owner to run the completion attestation for this report. The dispatch explicitly reserves every state change to Firstmate and allows only this report and the task status append; I therefore did not run `fm-decision-hold.sh` or modify the backlog. **Firstmate must complete that owner-only attestation before treating this investigation as lifecycle-complete.** No visual review artifact was created.
