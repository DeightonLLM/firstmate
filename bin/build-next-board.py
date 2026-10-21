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
  <repo>/ops/lane-ledger.tsv                      the machine lane ledger (lanes)

The lane ledger and the claims board live in the Core repo's ops directory, which
each host installs under its own path, so both are resolved from ONE fixed search
order and the first hit wins (see ops_dir_candidates):
  <repo>/ops                    the repo's own ops directory
  /root/agent-work/ops           HD2Stack
  /root/ops                      Controller
  /home/hd2admin/ops             Hetzner (the installed Core ops directory)
  /home/hd2admin/agent-work/core-distro-saas-clean/ops
                                 Hetzner (the Core clone, the git-tracked source)
Both inputs come out of the same directory on purpose: a ledger from one copy
checked against a claims board from another reports a disagreement that is not
there. The Hetzner entries sit where the Core repo's own drift checker
(ops/bin/fm-todo-sync.sh) puts them: that checker searches /home/hd2admin/ops
before its own directory, so on the Hetzner host the board and the checker read
one input. A missing input stays a violation: it never becomes a silent pass.

The lane ledger is a TSV whose first line is a `#` comment and whose columns are:
  lane_id  state  owner  opened  updated  expires  next  artifact  branch
`state` is one of ACTIVE, DONE, BLOCKED, RELEASED. It is the machine truth: the
to-do list is GENERATED from it, never hand-written. The board records the
ledger's digest, so a third party can tell whether the board is still in step
with the machine state it was generated from.

Outputs:
  <out>/NEXT-BOARD.md          the human board
  <out>/next-board.json        the machine-readable board
  stdout                      a one-paragraph summary + the contract check

The contract: every tracked item ends in a state, and every state has a next action
with an owner. Any item that cannot be given both is reported as CONTRACT-GAP, not
hidden. That gap list is the point of the exercise.

usage: build-next-board.py --repo <path> --out <dir> [--stale-days 3] [--now ISO8601]
                          [--ledger <path>] [--todo-list]
"""
import argparse
import collections
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import subprocess

STATES = ["VERIFIED-DONE", "OPEN-WORKABLE", "BLOCKED", "NEEDS-CAPTAIN-DECISION",
          "STALE-DUPLICATE", "UNVERIFIED", "CONTRACT-GAP"]

# The lane ledger's state vocabulary, in the order the board shows them.
LEDGER_STATES = ["ACTIVE", "BLOCKED", "DONE", "RELEASED"]
# The states a lane can be in without the board having to guess.
LEDGER_STATE_TOKENS = ("ACTIVE", "BLOCKED", "DONE", "RELEASED")

OWNER_DEFAULT = "unassigned"
NEXT_RE = re.compile(r"^\s*[-*]?\s*\**NEXT\**\s*[:：]", re.M | re.I)
VERDICT_RE = re.compile(r"^\s*VERDICT\s*:", re.M)
CLAIM_STATE_RE = re.compile(r"\b(%s)\b" % "|".join(LEDGER_STATE_TOKENS))

# The Core repo's ops directory on the Hetzner host. The host installs it under
# its own home, and it also keeps the Core clone's working copy of the same
# files, which is the git-tracked source. The installed copy is the one this
# host's drift checker reads, and on this host it is ahead of the clone's
# committed copy, so it is searched first and the clone is the fallback.
HETZ_OPS_DIR = pathlib.Path("/home/hd2admin/ops")
HETZ_CORE_CLONE_OPS_DIR = pathlib.Path(
    "/home/hd2admin/agent-work/core-distro-saas-clean/ops")


def ops_dir_candidates(repo):
    """The Core ops directories, in the one fixed order every host agrees on.

    The lane ledger and the claims board are both resolved from this one list,
    so the two always come out of the same directory. A ledger from one copy
    checked against a claims board from another reports a disagreement that is
    not there, and a list that could drift apart is how that happens.
    """
    return [
        pathlib.Path(repo) / "ops",
        pathlib.Path("/root/agent-work/ops"),
        pathlib.Path("/root/ops"),
        HETZ_OPS_DIR,
        HETZ_CORE_CLONE_OPS_DIR,
    ]


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


# --- the machine lane ledger ------------------------------------------------

def sha256_file(path):
    try:
        with open(path, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except Exception:
        return None


def resolve_ledger(repo, explicit=None):
    """Find the lane ledger. The order is fixed so every host agrees on the source.

    An explicit path is honoured as given: if it does not exist the caller must
    see that the ledger is missing, because a missing ledger must never silently
    become a missing to-do list.

    The search order is the ops directory list, first hit wins:
      1. <repo>/ops                                    the repo's own ops dir
      2. /root/agent-work/ops                          HD2Stack
      3. /root/ops                                     Controller
      4. /home/hd2admin/ops                            Hetzner (installed)
      5. /home/hd2admin/agent-work/core-distro-saas-clean/ops
         the Hetzner host's Core clone (the git-tracked source)
    """
    if explicit:
        candidates = [pathlib.Path(explicit)]
    else:
        candidates = [d / "lane-ledger.tsv" for d in ops_dir_candidates(repo)]
    for candidate in candidates:
        try:
            if candidate.is_file():
                return candidate
        except OSError:
            continue
    return None


def parse_ts(value):
    """Parse an ISO timestamp (or a near-enough one). Returns None when it cannot."""
    if not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    parsed = None
    try:
        parsed = dt.datetime.fromisoformat(text)
    except Exception:
        for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M",
                    "%Y-%m-%d"):
            try:
                parsed = dt.datetime.strptime(value.strip(), fmt)
                break
            except Exception:
                continue
    if parsed is None:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def read_ledger(path):
    """Read the lane ledger into lane records. A missing ledger degrades to []."""
    lanes = []
    if path is None:
        return lanes
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return lanes
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cells = line.split("\t")
        # The column header is a header, not a lane. It is skipped whether it
        # carries the leading '#' or not.
        if cells[0].strip().lower().replace(" ", "_") in ("lane_id", "laneid"):
            continue
        while len(cells) < 9:
            cells.append("")
        lane_id = cells[0].strip()
        if not lane_id:
            continue
        lanes.append({
            "lane_id": lane_id,
            "state": (cells[1].strip().upper() or "UNKNOWN"),
            "owner": cells[2].strip(),
            "opened": cells[3].strip(),
            "updated": cells[4].strip(),
            "expires": cells[5].strip(),
            "next": cells[6].strip(),
            "artifact": cells[7].strip(),
            "branch": cells[8].strip(),
        })
    return lanes


def ledger_digest(path):
    """The digest of the raw ledger bytes, so a third party can detect staleness."""
    if path is None:
        return "sha256:none"
    digest = sha256_file(path)
    if digest is None:
        return "sha256:none"
    return "sha256:" + digest


def age_minutes(lane, now_dt):
    """How long a lane has been open, in minutes. None when it cannot be told."""
    opened = parse_ts(lane.get("opened"))
    if opened is None:
        return None
    return max(0, int((now_dt - opened).total_seconds() // 60))


def claim_state_token(cell):
    """The state a claims-board row claims, read from its own state cell."""
    match = CLAIM_STATE_RE.search(cell or "")
    return match.group(1) if match else ""


def compute_drift(lane_ledger, claims, ledger_path):
    """Every disagreement between the machine ledger and the claims board."""
    drift = []
    if ledger_path is None:
        return [{"kind": "no-ledger", "lane": "-",
                 "detail": "no lane ledger found - the claims board cannot be checked "
                           "against machine truth"}]
    ledger_ids = {lane["lane_id"] for lane in lane_ledger}
    claims_by_lane = {}
    for claim in claims:
        claims_by_lane.setdefault(claim["lane"], claim)
    for lane in lane_ledger:
        claim = claims_by_lane.get(lane["lane_id"])
        if claim is None:
            drift.append({"kind": "missing-claim", "lane": lane["lane_id"],
                          "detail": "in the ledger (state %s) but not on the claims board"
                                    % lane["state"]})
            continue
        claimed = claim.get("state_token") or ""
        if claimed and claimed != lane["state"]:
            drift.append({"kind": "state-mismatch", "lane": lane["lane_id"],
                          "detail": "the ledger says %s, the claims board says %s"
                                    % (lane["state"], claimed)})
    for claim in claims:
        if claim["lane"] not in ledger_ids:
            drift.append({"kind": "missing-ledger", "lane": claim["lane"],
                          "detail": "on the claims board (state %s) but not in the ledger"
                                    % (claim.get("state_token") or "unreadable")})
    return drift


BACKLOG_RE = re.compile(r"^\s*-\s*\[( |x|X)\]\s+(.*)$")


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


def collect(repo, stale_days, now, ledger_path=None):
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
                residuals.append({"artifact": str(f.relative_to(repo)),
                                  "verdict": (re.findall(r"VERDICT\s*:\s*([^\n]{0,80})", text) or [""])[0].strip(),
                                  "next_line": None})

    # ledger: push attempts, cleared and refused. Every host keeps its own copy,
    # so read them all and label the source - reading only the first one
    # understated the fleet (it showed 0 cleared while the merge lane had 37).
    # The Hetzner host's copy is /home/hd2admin/ops/state/push-ledger.tsv, which
    # is already in this list; the Core clone carries no ops/state directory.
    ledger = []
    for lp in [pathlib.Path(repo) / "ops" / "state" / "push-ledger.tsv",
               pathlib.Path("/root/ops/state/push-ledger.tsv"),
               pathlib.Path("/home/hd2admin/ops/state/push-ledger.tsv"),
               pathlib.Path("/root/agent-work/ops/state/push-ledger.tsv"),
               pathlib.Path("/root/agent-work/ops/state/push-ledger.hetzner.tsv"),
               pathlib.Path("/root/agent-work/ops/state/push-ledger.controller.tsv")]:
        if not lp.is_file():
            continue
        try:
            rows = [line.split("\t") for line in lp.read_text(encoding="utf-8").splitlines() if line.strip()]
        except Exception:
            continue
        for row in rows:
            ledger.append(row + [str(lp)])

    # claims board: who holds what right now. It is resolved from the same ops
    # directory list as the lane ledger, in the same order, so the two inputs
    # always come out of the same directory.
    claims = []
    for cp in [d / "LANE-CLAIMS.md" for d in ops_dir_candidates(repo)]:
        if cp.is_file():
            try:
                for line in cp.read_text(encoding="utf-8").splitlines():
                    if line.startswith("| `") and "|" in line:
                        cells = [c.strip() for c in line.strip("|").split("|")]
                        if len(cells) >= 7 and cells[0].startswith("`"):
                            claims.append({"lane": cells[0].strip("`"), "scope": cells[2],
                                           "repo": cells[3], "state": cells[6][:120],
                                           "state_token": claim_state_token(cells[6])})
                break
            except Exception:
                pass

    # the machine lane ledger: the source of truth the to-do list is generated from
    lane_ledger = read_ledger(ledger_path)

    return items, residuals, ledger, claims, lane_ledger


def render(items, residuals, ledger, claims, repo, now, lane_ledger=None, digest="sha256:none",
           drift=None, now_dt=None):
    lane_ledger = lane_ledger or []
    drift = drift or []
    if now_dt is None:
        now_dt = parse_ts(now) or dt.datetime.now(dt.timezone.utc)
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
    out.append("**Ledger digest:** %s" % digest)
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

    out.append("## MY TODO — the live to-do list")
    out.append("")
    out.append("> Generated from the machine lane ledger, never hand-written. The ledger is the "
               "source of truth; the claims board is secondary. ACTIVE first, then BLOCKED, then "
               "DONE, then RELEASED.")
    out.append("")
    if lane_ledger:
        for state in LEDGER_STATES:
            for lane in [l for l in lane_ledger if l["state"] == state]:
                age = age_minutes(lane, now_dt) if state == "ACTIVE" else None
                out.append("- **%s** — `%s` — next: %s — owner: %s%s" % (
                    state, lane["lane_id"],
                    lane["next"] or "(no next action recorded)",
                    lane["owner"] or OWNER_DEFAULT,
                    " — age: %dm" % age if age is not None else ""))
        for lane in [l for l in lane_ledger if l["state"] not in LEDGER_STATES]:
            out.append("- **%s** — `%s` — next: %s — owner: %s" % (
                lane["state"], lane["lane_id"],
                lane["next"] or "(no next action recorded)",
                lane["owner"] or OWNER_DEFAULT))
    else:
        out.append("_no lanes in the ledger_")
    out.append("")

    out.append("## IN FLIGHT — lanes holding a live claim right now")
    out.append("")
    active = [c for c in claims if "ACTIVE" in (c.get("state") or "").upper()]
    done_claims = [c for c in claims if "DONE" in (c.get("state") or "").upper()]
    ledger_ids = {lane["lane_id"] for lane in lane_ledger}
    active_lanes = [lane for lane in lane_ledger if lane["state"] == "ACTIVE"]
    if active_lanes:
        for lane in active_lanes:
            age = age_minutes(lane, now_dt)
            out.append("- `%s` — %s — owner: %s — age: %s" % (
                lane["lane_id"], lane["next"] or "(no next action recorded)",
                lane["owner"] or OWNER_DEFAULT,
                "%dm" % age if age is not None else "unknown"))
    else:
        out.append("_no active lanes in the ledger_")
    secondary = [c for c in active if c["lane"] not in ledger_ids]
    if secondary:
        out.append("")
        out.append("Claims board (secondary) — active, but not in the ledger:")
        for c in secondary:
            out.append("- `%s` — %s — %s" % (c["lane"], c["scope"][:90], c["state"][:110]))
    if done_claims:
        out.append("")
        out.append("Claims released this cycle:")
        for c in done_claims:
            out.append("- `%s` — %s" % (c["lane"], c["state"][:110]))
    out.append("")

    out.append("## DRIFT — ledger vs claims board")
    out.append("")
    if drift:
        for entry in drift:
            out.append("- `%s` — %s" % (entry["lane"], entry["detail"]))
    else:
        out.append("_no drift — the ledger and the claims board agree_")
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
        pending = [r for r in ledger if len(r) > 5 and r[5].lower() == "pending"]
        out.append("- attempts recorded: **%d** (cleared %d, refused %d, still pending %d)"
                   % (len(ledger), len(cleared), len(refused), len(pending)))
        by_source = collections.defaultdict(lambda: collections.Counter())
        for r in ledger:
            source = r[-1] if r else "?"
            status = r[5] if len(r) > 5 else "?"
            if status.lower() == "committed":
                kind = "cleared"
            elif status.upper().startswith("REFUSED"):
                kind = "refused"
            elif status.lower() == "pending":
                kind = "pending"
            else:
                kind = "other"
            by_source[source][kind] += 1
        for source in sorted(by_source):
            kinds = by_source[source]
            out.append("  - `%s` — %d attempt(s): %d cleared, %d refused, %d pending"
                       % (source, sum(kinds.values()), kinds.get("cleared", 0),
                          kinds.get("refused", 0), kinds.get("pending", 0)))
        if refused:
            out.append("- the refusals, and why they were right:")
            for r in refused[-6:]:
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

    verdict = "PASS" if (not gaps and not residuals and not drift) else "FAIL"
    out.append("VERDICT: %s - %d item(s) with no next action or owner, %d artifact(s) with no NEXT line, "
               "%d lane(s) drifted between the ledger and the claims board"
               % (verdict, len(gaps), len(residuals), len(drift)))
    return "\n".join(out) + "\n", counts


def render_todo_list(items, lane_ledger, drift, ledger_present):
    """The canonical to-do list: four buckets, one item per line, and a verdict.

    The ledger decides what is in flight, done or blocked; the board's own NOW and
    CAPTAIN sections supply what is startable and what only the Captain can unblock.
    Every line carries a state, a next action and an owner - a line that cannot is a
    gap, and a gap fails the list.
    """
    now_work = [i for i in items if i["state"] == "OPEN-WORKABLE"]
    captain = [i for i in items if i["state"] == "NEEDS-CAPTAIN-DECISION" or i.get("captain_question")]

    buckets = collections.OrderedDict([("DONE", []), ("IN FLIGHT", []), ("NEXT", []),
                                        ("WAITING ON CAPTAIN", [])])
    for lane in lane_ledger:
        state = lane["state"]
        entry = (lane["lane_id"], lane["next"], lane["owner"])
        if state == "ACTIVE":
            buckets["IN FLIGHT"].append(entry)
        elif state in ("DONE", "RELEASED"):
            buckets["DONE"].append(entry)
        else:
            buckets["NEXT"].append(entry)
    for item in now_work:
        buckets["NEXT"].append((item["slug"], item["next_action"], item["owner"]))
    for item in captain:
        buckets["WAITING ON CAPTAIN"].append(
            (item["slug"], item.get("captain_question") or item["next_action"] or item["title"],
             item["owner"]))

    lines = []
    gaps = 0
    for state, entries in buckets.items():
        for identifier, next_action, owner in entries:
            next_text = (next_action or "").strip() or "(no next action recorded)"
            owner_text = (owner or "").strip() or OWNER_DEFAULT
            if not (next_action or "").strip() or not (owner or "").strip():
                gaps += 1
            lines.append("%s — %s — %s — owner: %s" % (state, identifier, next_text, owner_text))

    reasons = []
    if not ledger_present:
        reasons.append("no lane ledger found, so the list cannot be generated from machine truth")
    if drift:
        reasons.append("%d lane(s) drifted between the ledger and the claims board" % len(drift))
    if gaps:
        reasons.append("%d item(s) carry no next action or no owner" % gaps)
    verdict = "FAIL" if reasons else "PASS"
    reason = "; ".join(reasons) if reasons else (
        "%d lane(s) from the ledger, no drift, every item carries a next action and an owner"
        % len(lane_ledger))
    return lines, "VERDICT: %s - %s" % (verdict, reason)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--stale-days", type=int, default=3)
    ap.add_argument("--now", default=None)
    ap.add_argument("--ledger", default=None,
                    help="the machine lane ledger (default: <repo>/ops/lane-ledger.tsv, "
                         "then /root/agent-work/ops/lane-ledger.tsv, then /root/ops/lane-ledger.tsv, "
                         "then /home/hd2admin/ops/lane-ledger.tsv, then "
                         "/home/hd2admin/agent-work/core-distro-saas-clean/ops/lane-ledger.tsv)")
    ap.add_argument("--todo-list", action="store_true",
                    help="print only the canonical to-do list and its verdict")
    args = ap.parse_args()

    now = args.now or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    repo = os.path.abspath(args.repo)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    ledger_path = resolve_ledger(repo, args.ledger)
    digest = ledger_digest(ledger_path)
    items, residuals, ledger, claims, lane_ledger = collect(repo, args.stale_days, now, ledger_path)
    drift = compute_drift(lane_ledger, claims, ledger_path)
    now_dt = parse_ts(now) or dt.datetime.now(dt.timezone.utc)
    board, counts = render(items, residuals, ledger, claims, repo, now, lane_ledger, digest,
                           drift, now_dt)
    (out / "NEXT-BOARD.md").write_text(board, encoding="utf-8")
    (out / "next-board.json").write_text(json.dumps({
        "generated": now, "repo": repo, "counts": dict(counts),
        "items": items, "residuals": residuals,
        "ledger_attempts": len(ledger), "claims": claims,
        "ledger_digest": digest, "ledger_lanes": lane_ledger, "drift": drift,
    }, indent=2), encoding="utf-8")

    if args.todo_list:
        lines, verdict_line = render_todo_list(items, lane_ledger, drift, ledger_path is not None)
        for line in lines:
            print(line)
        print(verdict_line)
        return 0

    print("NEXT board written: %s" % (out / "NEXT-BOARD.md"))
    print("counts: %s" % json.dumps(dict(counts)))
    gaps = [i for i in items if i["state"] == "CONTRACT-GAP"]
    print("contract gaps: %d, artifacts without a NEXT line: %d, drift: %d"
          % (len(gaps), len(residuals), len(drift)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
