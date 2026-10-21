#!/usr/bin/env python3
"""
build-next-board.py — the signpost.

Builds ONE live board that says what is happening now, what is next, what only the
Captain can decide, and what residuals are still open. The point: a lane that finishes
must leave the next step visible, so no work dies at the end of a report with nobody
pointing at it.

Inputs (all read-only, all optional - missing inputs degrade, they never crash):
  <repo>/data/tracker/live-state-20261020.json   verified live states (verifier lane)
  <repo>/data/tracker/tickets.jsonl               the raw tracker
  <repo>/ops/LANE-CLAIMS.md                       the live claims board
  <repo>/ops/state/push-ledger.tsv                the push ledger (attempts)
  <repo>/data/hd2-takeover/*.md                   artifacts, scanned for residuals
  <repo>/docs/hd2-residuals/*.md                  residual registers, if present

Outputs:
  <out>/NEXT-BOARD.md          the human board
  <out>/next-board.json        the machine-readable board
  stdout                      a one-paragraph summary + the contract check

The contract: every tracked item ends in a state, and every state has a next action
with an owner. Any item that cannot be given both is reported as CONTRACT-GAP, not
hidden. That gap list is the point of the exercise.

usage: build-next-board.py --repo <path> --out <dir> [--stale-days 3] [--now ISO8601]
"""
import argparse
import collections
import datetime as dt
import json
import os
import pathlib
import re
import subprocess

STATES = ["VERIFIED-DONE", "OPEN-WORKABLE", "BLOCKED", "NEEDS-CAPTAIN-DECISION",
          "STALE-DUPLICATE", "UNVERIFIED", "CONTRACT-GAP"]

OWNER_DEFAULT = "unassigned"
NEXT_RE = re.compile(r"^\s*[-*]?\s*\**NEXT\**\s*[:：]", re.M | re.I)
VERDICT_RE = re.compile(r"^\s*VERDICT\s*:", re.M)
# The line-anchored twin of VERDICT_RE, used only to READ a verdict. VERDICT_RE's
# leading \s* can span a newline, so its match offset does not point at the verdict's
# own line; this one always does.
VERDICT_LINE_RE = re.compile(r"^[ \t]*(?:\*\*)?VERDICT[ \t]*:[ \t]*(.*)$", re.M)


def read_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None


def read_jsonl(path):
    rows = []
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        return []
    return rows


def git(repo, *args):
    p = subprocess.run(["git", "-C", repo] + list(args), capture_output=True, text=True)
    return p.stdout.strip()


BACKLOG_RE = re.compile(r"^\s*-\s*\[( |x|X)\]\s+(.*)$")


def verdict_text(text):
    """The artifact's own verdict, read from its verdict LINE.

    The old extraction took the first "VERDICT:" anywhere in the file, so an artifact
    that merely mentioned verdicts in prose won over its real verdict - e.g. a report
    whose verdict was "FAIL, must not run as written" was rendered as
    "PASS` or `VERDICT: FAIL <reason>`, two-branch stop condition."

    The detection rule stays VERDICT_RE (the contract's own regex, which the publisher
    also calls). The extraction uses a line-anchored twin, because VERDICT_RE's leading
    \\s* can span a newline and so its match offset does not reliably point at the
    verdict's own line.
    """
    match = VERDICT_LINE_RE.search(text)
    if match:
        value = match.group(1)
    else:
        fallback = VERDICT_RE.search(text)
        if not fallback:
            return ""
        value = text[fallback.end():].split("\n", 1)[0]
    value = value.strip().strip("*").strip("`").strip()
    return value[:160].strip()


def parse_backlog(repo):
    """data/backlog.md is the live queue the coordinator maintains.

    Each row: - [ ] slug - Title (repo: X) (kind: ship|scout|captain|docs) (priority: N)
    (since: DATE) (hold: ...) (hold-kind: ...) blocked-by: ... (artifact: ...)
    """
    text = ""
    local = pathlib.Path(repo) / "data" / "backlog.md"
    if local.is_file():
        try:
            text = local.read_text(encoding="utf-8", errors="replace")
        except Exception:
            text = ""
    if not text.strip():
        text = git(repo, "show", "origin/main:data/backlog.md") or ""
    if not text.strip():
        return []

    out = []
    for line in text.splitlines():
        m = BACKLOG_RE.match(line)
        if not m:
            continue
        done = m.group(1).lower() == "x"
        body = m.group(2).strip()
        slug = body.split(" - ")[0].strip()
        title = body.split(" - ", 1)[1].strip() if " - " in body else body
        kind = (re.search(r"\(kind:\s*([^)]*)\)", body) or [None, "ship"])[1].strip()
        prio = (re.search(r"\(priority:\s*(\d+)\)", body) or [None, "2"])[1]
        repo_name = (re.search(r"\(repo:\s*([^)]*)\)", body) or [None, ""])[1].strip()
        since = (re.search(r"\(since:\s*([0-9-]+)\)", body) or [None, ""])[1]
        hold = (re.search(r"\(hold:\s*(.*?)\)(?:\s|\Z)", body) or [None, None])[1]
        blocked_by = (re.search(r"blocked-by:\s*([A-Za-z0-9._-]+)", body) or [None, None])[1]
        artifact = (re.search(r"\(artifact:\s*([^)]*)\)", body) or [None, None])[1]
        if hold and not blocked_by:
            blocked_by = "hold"

        if done:
            state = "VERIFIED-DONE"
        elif kind == "captain":
            state = "NEEDS-CAPTAIN-DECISION"
        elif blocked_by or hold:
            state = "BLOCKED"
        else:
            state = "OPEN-WORKABLE"

        next_action = ""
        if state == "NEEDS-CAPTAIN-DECISION":
            next_action = (hold or title)[:300]
        elif state == "BLOCKED":
            next_action = "blocked-by %s: %s" % (blocked_by or "?", (hold or title)[:220])
        elif state == "OPEN-WORKABLE":
            next_action = title
        else:
            next_action = "closed%s" % (" (artifact: %s)" % artifact if artifact else "")

        out.append({
            "slug": slug, "title": title, "priority": "P%s" % prio, "state": state,
            "next_action": next_action, "owner": "hetz-firstmate" if repo_name else "unassigned",
            "captain_question": (hold or title)[:300] if state == "NEEDS-CAPTAIN-DECISION" else None,
            "source": "backlog", "evidence": [{"cmd": "data/backlog.md",
                                                "result": "row since %s, kind %s" % (since or "?", kind)}],
        })
    return out


def collect(repo, stale_days, now):
    tracker_dir = pathlib.Path(repo) / "data" / "tracker"
    live = read_json(tracker_dir / "live-state-20261020.json")
    raw = read_jsonl(tracker_dir / "tickets.jsonl")

    items = []
    if isinstance(live, dict):
        # schema hd2-live-state/v1: the verifier lane's evidence-backed states
        live = live.get("tickets") or live.get("items") or []
    if isinstance(live, list):
        for row in live:
            items.append({
                "slug": row.get("slug") or row.get("title") or "untitled",
                "title": row.get("title") or "",
                "priority": row.get("priority") or "P2",
                "state": row.get("true_state") or "UNVERIFIED",
                "next_action": (row.get("next_action") or "").strip(),
                "owner": (row.get("owner_lane") or row.get("owner") or OWNER_DEFAULT).strip(),
                "captain_question": row.get("captain_question"),
                "source": row.get("source") or "tracker",
                "evidence": row.get("evidence") or [],
            })
    else:
        for row in raw:
            items.append({
                "slug": row.get("slug") or "untitled",
                "title": row.get("title") or "",
                "priority": row.get("priority") or "P2",
                "state": "UNVERIFIED" if not row.get("lane_state") else str(row.get("lane_state")),
                "next_action": (row.get("next_action") or "").strip(),
                "owner": (row.get("lane") or OWNER_DEFAULT).strip() or OWNER_DEFAULT,
                "captain_question": None,
                "source": "tracker",
                "evidence": [],
            })

    # A tracker row that carries a lane's own annotation is newer, more specific
    # evidence than the live-state snapshot, so it wins for that slug. A tracker
    # row that is still the intake scaffolding has nothing to say and must NOT
    # override the live-state - that is how a ticket ends up reported as
    # "await lane dispatch" when the fleet has already proved it done.
    if isinstance(live, list):
        annotated = {}
        for row in raw:
            slug = row.get("slug")
            if not slug:
                continue
            if all(not row.get(f) or row.get(f) in ("-", "None", "")
                   for f in ("lane_state", "artifact", "verdict", "evidence")):
                continue
            annotated[slug] = row
        if annotated:
            for item in items:
                row = annotated.get(item["slug"])
                if not row:
                    continue
                item["state"] = str(row.get("lane_state") or item["state"])
                item["next_action"] = (row.get("next_action") or item["next_action"]).strip()
                item["owner"] = (row.get("lane") or item["owner"]).strip() or item["owner"]
                item["evidence"] = [row.get("evidence")] if row.get("evidence") else item["evidence"]
                item["source"] = "tracker-annotation"

    # the live backlog is the real queue - merge it in, keeping tracker rows first
    backlog = parse_backlog(repo)
    seen = {i["slug"] for i in items}
    for b in backlog:
        if b["slug"] not in seen:
            items.append(b)
            seen.add(b["slug"])

    # contract check: every open item needs a next action and an owner
    for it in items:
        gaps = []
        if it["state"] in ("VERIFIED-DONE", "STALE-DUPLICATE"):
            if not it["next_action"]:
                gaps.append("no next action recorded for a closed item")
        else:
            if not it["next_action"] or it["next_action"].lower().startswith("await lane dispatch"):
                gaps.append("next action is still 'Await lane dispatch'")
            if it["owner"] in ("", OWNER_DEFAULT, "-", "None"):
                gaps.append("no owner")
        if gaps:
            it["state"] = "CONTRACT-GAP"
            it["gaps"] = gaps
        else:
            it["gaps"] = []

    # residuals: artifacts that end with a VERDICT but carry no NEXT line
    residuals = []
    art_dirs = [pathlib.Path(repo) / "data" / "hd2-takeover",
                pathlib.Path(repo) / "docs" / "hd2-residuals"]
    # A lane's own report is an artifact too. data/<lane>/report.md is where every lane
    # writes its verdict, so a report that ends with a VERDICT and no NEXT line is exactly
    # the leftover the contract is meant to surface - it must not be invisible just because
    # it lives under data/ instead of a takeover directory.
    for report in sorted((pathlib.Path(repo) / "data").glob("*/report.md")):
        art_dirs.append(report.parent)
    seen_artifacts = set()
    for d in art_dirs:
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.md")):
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            if not VERDICT_RE.search(text):
                continue
            if not NEXT_RE.search(text):
                artifact = str(f.relative_to(repo))
                if artifact in seen_artifacts:
                    continue
                seen_artifacts.add(artifact)
                residuals.append({"artifact": artifact,
                                  "verdict": verdict_text(text),
                                  "next_line": None})

    # ledger: push attempts, cleared and refused
    ledger = []
    for lp in [pathlib.Path(repo) / "ops" / "state" / "push-ledger.tsv",
               pathlib.Path("/root/ops/state/push-ledger.tsv"),
               pathlib.Path("/root/agent-work/ops/state/push-ledger.tsv")]:
        if lp.is_file():
            try:
                for line in lp.read_text(encoding="utf-8").splitlines():
                    if line.strip():
                        ledger.append(line.split("\t"))
                break
            except Exception:
                pass

    # claims board: who holds what right now
    claims = []
    for cp in [pathlib.Path(repo) / "ops" / "LANE-CLAIMS.md",
               pathlib.Path("/root/agent-work/ops/LANE-CLAIMS.md")]:
        if cp.is_file():
            try:
                for line in cp.read_text(encoding="utf-8").splitlines():
                    if line.startswith("| `") and "|" in line:
                        cells = [c.strip() for c in line.strip("|").split("|")]
                        if len(cells) >= 7 and cells[0].startswith("`"):
                            claims.append({"lane": cells[0].strip("`"), "scope": cells[2],
                                           "repo": cells[3], "state": cells[6][:120]})
                break
            except Exception:
                pass

    return items, residuals, ledger, claims


def render(items, residuals, ledger, claims, repo, now):
    counts = collections.Counter(i["state"] for i in items)
    by = collections.defaultdict(list)
    for i in items:
        by[i["state"]].append(i)

    now_work = [i for i in items if i["state"] in ("OPEN-WORKABLE",)]
    captain = [i for i in items if i["state"] == "NEEDS-CAPTAIN-DECISION" or i.get("captain_question")]
    blocked = [i for i in items if i["state"] == "BLOCKED"]
    gaps = [i for i in items if i["state"] == "CONTRACT-GAP"]
    unverified = [i for i in items if i["state"] == "UNVERIFIED"]
    done = [i for i in items if i["state"] in ("VERIFIED-DONE", "STALE-DUPLICATE")]

    def prio(i):
        order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
        return (order.get(str(i["priority"]).upper(), 9), i["slug"])

    out = []
    out.append("# NEXT BOARD — the signpost")
    out.append("")
    out.append("**Generated:** %s  ·  **repo:** `%s`  ·  **items:** %d" % (now, repo, len(items)))
    out.append("")
    out.append("> The rule: every item has a state, every open item has a next action and an owner. "
               "A lane that finishes without leaving the next step visible has failed the contract, "
               "and this board says so out loud in **CONTRACT-GAP** rather than letting it go quiet.")
    out.append("")
    out.append("Sources: `data/tracker/live-state-20261020.json` (verified states, when present), "
               "`data/tracker/tickets.jsonl`, and the live queue `data/backlog.md`.")
    out.append("")
    out.append("| state | count |")
    out.append("|---|---|")
    for s in STATES:
        out.append("| `%s` | %d |" % (s, counts.get(s, 0)))
    out.append("")

    out.append("## IN FLIGHT — lanes holding a live claim right now")
    out.append("")
    active = [c for c in claims if "ACTIVE" in (c.get("state") or "").upper()]
    done_claims = [c for c in claims if "DONE" in (c.get("state") or "").upper()]
    if active:
        for c in active:
            out.append("- `%s` — %s — %s" % (c["lane"], c["scope"][:90], c["state"][:110]))
    else:
        out.append("_no active claims_")
    if done_claims:
        out.append("")
        out.append("Claims released this cycle:")
        for c in done_claims:
            out.append("- `%s` — %s" % (c["lane"], c["state"][:110]))
    out.append("")

    out.append("## NOW — work a lane can start today, no further authority needed")
    out.append("")
    if now_work:
        out.append("| prio | item | done looks like | owner |")
        out.append("|---|---|---|---|")
        for i in sorted(now_work, key=prio):
            out.append("| %s | `%s` | %s | %s |" % (i["priority"], i["slug"],
                                                     (i["next_action"] or "").replace("|", "/")[:150],
                                                     i["owner"]))
    else:
        out.append("_none_")
    out.append("")

    out.append("## ONLY THE CAPTAIN CAN UNBLOCK — one question each")
    out.append("")
    if captain:
        for i in sorted(captain, key=prio):
            q = i.get("captain_question") or i["next_action"] or i["title"]
            out.append("- **%s** (`%s`, %s) — %s" % (i["title"][:110], i["slug"], i["priority"], q))
    else:
        out.append("_none_")
    out.append("")

    out.append("## BLOCKED — blocker and recovery condition")
    out.append("")
    if blocked:
        for i in sorted(blocked, key=prio):
            out.append("- `%s` (%s) — %s" % (i["slug"], i["priority"], (i["next_action"] or i["title"])[:200]))
    else:
        out.append("_none_")
    out.append("")

    out.append("## CONTRACT-GAP — items with no next action or no owner (the rot this board exists to expose)")
    out.append("")
    if gaps:
        for i in sorted(gaps, key=prio):
            out.append("- `%s` (%s) — %s" % (i["slug"], i["priority"], "; ".join(i["gaps"])))
    else:
        out.append("_none_ — every item has a next action and an owner_")
    out.append("")

    out.append("## UNVERIFIED — no independent check yet (a claim is not a fact)")
    out.append("")
    if unverified:
        for i in sorted(unverified, key=prio)[:25]:
            out.append("- `%s` (%s) — %s" % (i["slug"], i["priority"], (i["next_action"] or i["title"])[:160]))
        if len(unverified) > 25:
            out.append("- _…and %d more_" % (len(unverified) - 25))
    else:
        out.append("_none_")
    out.append("")

    out.append("## CLOSED")
    out.append("")
    if done:
        for i in sorted(done, key=prio)[:25]:
            out.append("- `%s` — %s" % (i["slug"], (i["next_action"] or i["title"])[:140]))
        if len(done) > 25:
            out.append("- _…and %d more_" % (len(done) - 25))
    else:
        out.append("_none_")
    out.append("")

    out.append("## RESIDUALS — artifacts that end with a VERDICT but no NEXT line")
    out.append("")
    if residuals:
        for r in residuals:
            out.append("- `%s` — verdict: %s" % (r["artifact"], r["verdict"] or "(unstated)"))
    else:
        out.append("_none_")
    out.append("")

    out.append("## PUSH LEDGER — every attempt, cleared or refused")
    out.append("")
    if ledger:
        refused = [r for r in ledger if len(r) > 5 and r[5].upper().startswith("REFUSED")]
        cleared = [r for r in ledger if len(r) > 5 and r[5].lower() == "committed"]
        out.append("- attempts recorded: **%d** (cleared %d, refused %d)" % (len(ledger), len(cleared), len(refused)))
        for r in refused[-5:]:
            out.append("  - refused: %s %s %s — %s" % (r[0], r[1], r[3], r[5][:120]))
    else:
        out.append("_no ledger found_")
    out.append("")

    out.append("## LIVE CLAIMS — who holds what right now")
    out.append("")
    if claims:
        for c in claims:
            out.append("- `%s` — %s — %s" % (c["lane"], c["scope"][:80], c["state"][:80]))
    else:
        out.append("_no claims board found_")
    out.append("")

    verdict = "PASS" if (not gaps and not residuals) else "FAIL"
    out.append("VERDICT: %s - %d item(s) with no next action or owner, %d artifact(s) with no NEXT line"
               % (verdict, len(gaps), len(residuals)))
    return "\n".join(out) + "\n", counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--stale-days", type=int, default=3)
    ap.add_argument("--now", default=None)
    args = ap.parse_args()

    now = args.now or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    repo = os.path.abspath(args.repo)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    items, residuals, ledger, claims = collect(repo, args.stale_days, now)
    board, counts = render(items, residuals, ledger, claims, repo, now)
    (out / "NEXT-BOARD.md").write_text(board, encoding="utf-8")
    (out / "next-board.json").write_text(json.dumps({
        "generated": now, "repo": repo, "counts": dict(counts),
        "items": items, "residuals": residuals,
        "ledger_attempts": len(ledger), "claims": claims,
    }, indent=2), encoding="utf-8")

    print("NEXT board written: %s" % (out / "NEXT-BOARD.md"))
    print("counts: %s" % json.dumps(dict(counts)))
    gaps = [i for i in items if i["state"] == "CONTRACT-GAP"]
    print("contract gaps: %d, artifacts without a NEXT line: %d" % (len(gaps), len(residuals)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
