#!/usr/bin/env bash
# fm-ticket-board.sh - one screen over the ticket system this fleet already has.
#
# Why: the Captain's to-do list is dirty and stale, so the board answers three
# questions in one place: what needs his input, what is underway, what is planned.
# The ticket system already exists (data/backlog.md is the backend file and
# tasks-axi is the CLI over it), so this view reads that system rather than
# inventing a second tracker.
#
# Data sources, all read-only:
#   1. The backlog file. Default <FM_HOME>/data/backlog.md, overridable with
#      --file so a secondmate home can point the board at its own backlog.
#   2. <data>/async-lanes.tsv, the lane registry. Columns are run_id, lane_key,
#      model, surface, task, state, output, TAB separated.
#   3. <data>/core-remediation/lanes.json, the Core programme lane manifest.
#      Each lane carries id, status, owner, artifact and question.
#   4. <state>/<id>.meta, the spawn record for a task, when one exists. It is
#      the only per-task source of harness, model and effort.
#
# The backlog file is parsed with the same rules tasks-axi applies (same bullet
# grammar, same trailing tag order, same hold kinds), so the board and the
# ticket system agree on ids, states, holds, blockers and dates. A read-only
# JSON mode does not exist for tasks-axi list or show, so the backend file is
# read directly with read-only tools.
#
# The board never closes, moves, reorders or edits a ticket. It reports, and
# the Captain decides.
#
# Board rows carry the captain-locked prefix that
# docs/todo-prefix-canonical-format.md owns:
#   [<harness>·<ModelAbbrev> <effort> @<Host>]
# The model alias table lives in bin/fm-todo-prefix-check.sh.
# A part the sources do not record prints as `unknown`. No harness, model,
# effort or host is ever invented.
#
# Usage:
#   fm-ticket-board.sh                render the board for this home
#   fm-ticket-board.sh --file PATH    render the board for another backlog file
#   fm-ticket-board.sh --full         expand every section
#   fm-ticket-board.sh --help         print this usage
#
# Home resolution follows the rest of bin/: FM_HOME selects the home, with
# FM_ROOT_OVERRIDE, FM_DATA_OVERRIDE and FM_STATE_OVERRIDE honored, so tests
# and secondmates can point the board at another home without touching the
# real one.
#
# Exit: 0 rendered, 1 usage error, 2 unreadable backlog, 3 missing tool.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SELF_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
FM_DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
FM_STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
BACKLOG="$FM_DATA/backlog.md"
FULL=0

usage() {
  cat <<'USAGE'
fm-ticket-board.sh - one screen over the existing ticket system.

Usage:
  fm-ticket-board.sh                render the board for this home
  fm-ticket-board.sh --file PATH    render the board for another backlog file
  fm-ticket-board.sh --full         expand every section
  fm-ticket-board.sh --help         print this usage

Sections, in order:
  NEEDS YOUR INPUT   tickets held on the Captain
  BLOCKED            tickets with a recorded blocked-by edge
  IN FLIGHT          tickets under way, with their lane and artifact
  READY / QUEUED     the next wave, as counts by kind and repo
  STALE              open tickets that look finished
  LANES              live lane rows from the lane registry

Exit codes:
  0  the board rendered
  1  usage error
  2  the backlog file is missing or unreadable
  3  a required tool is missing
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file)
      if [ "$#" -lt 2 ]; then
        printf 'fm-ticket-board.sh: --file needs a path\n' >&2
        usage >&2
        exit 1
      fi
      BACKLOG="$2"
      shift 2
      ;;
    --file=*)
      BACKLOG="${1#--file=}"
      shift
      ;;
    --full)
      FULL=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'fm-ticket-board.sh: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$BACKLOG" ]; then
  printf 'fm-ticket-board.sh: backlog path is empty\n' >&2
  exit 1
fi
if [ -d "$BACKLOG" ]; then
  printf 'fm-ticket-board.sh: backlog file is unreadable, it is a directory: %s\n' "$BACKLOG" >&2
  exit 2
fi
if [ ! -f "$BACKLOG" ]; then
  printf 'fm-ticket-board.sh: backlog file is unreadable, it does not exist: %s\n' "$BACKLOG" >&2
  exit 2
fi
if [ ! -r "$BACKLOG" ]; then
  printf 'fm-ticket-board.sh: backlog file is unreadable, it is not readable: %s\n' "$BACKLOG" >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'fm-ticket-board.sh: python3 is required to parse the backlog and was not found\n' >&2
  exit 3
fi

python3 - "$BACKLOG" "$FM_DATA" "$FM_STATE" "$FULL" <<'PY'
import json
import os
import re
import sys
from datetime import date

BACKLOG, DATA_DIR, STATE_DIR, FULL_FLAG = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
FULL = FULL_FLAG == "1"

# The directory that holds the data/ tree, so a recorded relative artifact path
# resolves against this home rather than against the current working directory.
ARTIFACT_ROOT = os.path.dirname(os.path.abspath(DATA_DIR))

UNKNOWN = "unknown"
HOLD_KINDS = ("captain", "external", "load", "parked", "future")
HARNESSES = ("pi", "codex", "claude", "opencode", "mcode", "grok", "kimi", "agy")
EFFORT_CODES = {"low": "l", "medium": "m", "high": "h", "xhigh": "xh", "max": "x"}
# The model alias table lives in bin/fm-todo-prefix-check.sh and nowhere else.
# docs/todo-prefix-canonical-format.md owns the contract that names it.
MODEL_ALIAS_TABLE = {
    "m3.1f": "minimax/MiniMax-M3.1-Flash",
    "m3.1": "minimax/MiniMax-M3.1",
    "luna6": "openai-codex/gpt-6-luna",
    "glm5.3f": "zai/glm-5.3-flash",
    "gem38f": "agy/gemini-3.8-flash-medium",
    "pi": "minimax/MiniMax-M3.1-Flash",
}
ALIAS_SPELLINGS = {
    "m31": "m3.1", "m31f": "m3.1f", "g38f": "gem38f",
}
TERMINAL_LANE_TOKENS = (
    "complete", "completed", "done", "stopped", "failed", "failure", "timeout",
    "timed", "terminal", "duplicate", "artifact", "stale", "unverified", "candidate",
)

# Titles that state a resolution are stale-board noise while the row is open.
RESOLUTION_PHRASES = (
    "no guard defect found", "no defect found", "cancelled", "canceled",
    "recovered intact", "spec recovered", "already satisfied", "already complete",
    "already done", "nothing to do", "no action needed", "obsolete", "superseded",
    "no change needed", "resolved", "clearing pass complete",
)

ARTIFACT_SUFFIXES = (
    ".md", ".json", ".zip", ".txt", ".csv", ".html", ".htm", ".sh", ".py",
    ".yaml", ".yml", ".log", ".patch", ".diff", ".png", ".jpg", ".svg",
)
PATH_RE = re.compile(r"/?(?:[A-Za-z0-9_.-]+/)*data/[A-Za-z0-9_./-]+")

ID_CHARS = r"[A-Za-z0-9][A-Za-z0-9._-]*"
RE_DONE = re.compile(r"^- \[x\] (" + ID_CHARS + r") - (.*)$")
RE_QUEUED = re.compile(r"^- \[ \] (" + ID_CHARS + r") - (.*)$")
RE_IN_FLIGHT = re.compile(r"^- \*\*(" + ID_CHARS + r")\*\* - (.*)$")

TAIL_DEP = re.compile(
    r"\s*(blocked-by|parent|discovered-from):\s*(" + ID_CHARS + r")"
    r"(?:\s+-\s+((?:(?!\s+(?:blocked-by|parent|discovered-from):\s).)+?))?\s*$"
)
TAIL_REPO = re.compile(r"\s*\((?:[^()]*+\s*)?repo:\s*([^)]+)\)\s*$")
TAIL_KIND = re.compile(r"\s*\(kind:\s*([^)]+)\)\s*$")
TAIL_PRIORITY = re.compile(r"\s*\(priority:\s*([0-4])\)\s*$")
TAIL_SINCE = re.compile(r"\s*\(since\s+(\d{4}-\d{2}-\d{2})\)\s*$")
TAIL_CLOSED = re.compile(r"\s*\((merged|reported|done|closed)\s+(\d{4}-\d{2}-\d{2})\)\s*$")
TAIL_HOLD_UNTIL = re.compile(r"\s*\(hold-until:\s*(\d{4}-\d{2}-\d{2})\)\s*$")
TAIL_HOLD_KIND = re.compile(r"\s*\(hold-kind:\s*(" + "|".join(HOLD_KINDS) + r")\)\s*$")
TAIL_HOLD = re.compile(r"\s*\(hold:\s*([^()]+)\)\s*$")


def extract_tags(rest):
    """Strip the trailing canonical tags off a bullet, the way tasks-axi does."""
    deps = []
    repo = None
    kind = None
    created = None
    closed = None
    priority = None
    hold_reason = None
    hold_kind = None
    hold_until = None
    title = rest
    stripping = True
    while stripping:
        stripping = False
        match = TAIL_DEP.search(title)
        if match:
            deps.insert(0, {"type": match.group(1), "id": match.group(2), "reason": match.group(3)})
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_REPO.search(title)
        if match:
            if repo is None:
                repo = match.group(1).strip()
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_KIND.search(title)
        if match:
            if kind is None:
                kind = match.group(1).strip()
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_PRIORITY.search(title)
        if match:
            if priority is None:
                priority = int(match.group(1))
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_SINCE.search(title)
        if match:
            if created is None:
                created = match.group(1)
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_CLOSED.search(title)
        if match:
            if closed is None:
                closed = match.group(2)
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_HOLD_UNTIL.search(title)
        if match:
            if hold_until is None:
                hold_until = match.group(1)
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_HOLD_KIND.search(title)
        if match:
            if hold_kind is None:
                hold_kind = match.group(1)
            title = title[: match.start()]
            stripping = True
            continue
        match = TAIL_HOLD.search(title)
        if match:
            if hold_reason is None:
                hold_reason = match.group(1).strip()
            title = title[: match.start()]
            stripping = True
            continue
    return {
        "title": title.strip(),
        "kind": kind,
        "repo": repo,
        "created": created,
        "closed": closed,
        "priority": priority,
        "hold_kind": hold_kind,
        "hold_reason": hold_reason,
        "hold_until": hold_until,
        "deps": deps,
    }


def section_state(header):
    text = header.strip().lower()
    if text == "in flight":
        return "in_flight"
    if text == "queued":
        return "queued"
    if text.startswith("done"):
        return "done"
    return None


def parse_backlog(path):
    """Read the backlog backend file and return its ticket records."""
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    tasks = []
    state = None
    saw_section = False
    index = 0
    total = len(lines)
    while index < total:
        line = lines[index]
        stripped = line.rstrip("\r")
        if stripped.startswith("##"):
            header = stripped[2:].strip()
            found = section_state(header)
            if found is not None:
                state = found
                saw_section = True
            index += 1
            continue
        bullet = None
        if state == "done":
            match = RE_DONE.match(stripped)
            if match:
                bullet = match
        elif state == "queued":
            match = RE_QUEUED.match(stripped)
            if match:
                bullet = match
        elif state == "in_flight":
            match = RE_IN_FLIGHT.match(stripped) or RE_QUEUED.match(stripped)
            if match:
                bullet = match
        if bullet is None:
            index += 1
            continue
        body = []
        cursor = index + 1
        while cursor < total:
            nxt = lines[cursor].rstrip("\r")
            if nxt.strip() == "":
                body.append("")
                cursor += 1
                continue
            if nxt.startswith(" ") or nxt.startswith("\t"):
                body.append(nxt)
                cursor += 1
                continue
            break
        while body and body[-1].strip() == "":
            body.pop()
        record = extract_tags(bullet.group(2))
        record["id"] = bullet.group(1)
        record["state"] = state
        record["body"] = "\n".join(body)
        tasks.append(record)
        index = cursor
    if not saw_section:
        raise ValueError("it holds no backlog section")
    return tasks


def load_lane_rows(path):
    """Read the lane registry. A missing registry is not an error."""
    rows = []
    if not os.path.isfile(path):
        return rows
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n").rstrip("\r")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) < 7:
                continue
            rows.append({
                "run_id": fields[0],
                "lane_key": fields[1],
                "model": fields[2],
                "surface": fields[3],
                "task": fields[4],
                "state": fields[5],
                "output": fields[6],
            })
    return rows


def load_core_lanes(path):
    """Read the Core programme lane manifest. A missing manifest is not an error."""
    lanes = {}
    if not os.path.isfile(path):
        return lanes
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return lanes
    for lane in data.get("lanes", []) or []:
        lane_id = lane.get("id")
        if lane_id:
            lanes[lane_id] = lane
    return lanes


def read_meta(task_id):
    """Read the spawn record for a task, when this home has one."""
    path = os.path.join(STATE_DIR, task_id + ".meta")
    fields = {}
    if not os.path.isfile(path):
        return fields
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                line = line.rstrip("\n").rstrip("\r")
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                fields[key.strip()] = value.strip()
    except OSError:
        return {}
    return fields


def model_abbrev(raw):
    """Map a recorded model to its canonical alias, or None when none applies.

    The alias table and the derivation rule belong to bin/fm-todo-prefix-check.sh.
    A model that no alias claims is left unnamed rather than guessed.
    """
    value = (raw or "").strip()
    value = re.sub(r"\s*\(requested\)\s*$", "", value).strip()
    if not value:
        return None
    lowered = value.lower()
    if lowered in MODEL_ALIAS_TABLE:
        return lowered
    if lowered in ALIAS_SPELLINGS:
        return ALIAS_SPELLINGS[lowered]
    for alias, identifier in MODEL_ALIAS_TABLE.items():
        if lowered == identifier.lower():
            return alias
    match = re.match(r"(?i)^(?:minimax/)?minimax-m([0-9.]+)(?:-(.*))?$", value)
    if match:
        family = match.group(1)
        tier = (match.group(2) or "").lower()
        marker = ""
        if tier.startswith("highspeed"):
            marker = "h"
        elif tier.startswith("flash"):
            marker = "f"
        alias = "m" + family + marker
        if alias in MODEL_ALIAS_TABLE:
            return alias
    return None


def effort_code(raw):
    """Map a recorded effort word to the bare code the prefix format uses."""
    value = (raw or "").strip().lower()
    if value in EFFORT_CODES:
        return EFFORT_CODES[value]
    return None


def lane_effort(task_column):
    """Read the effort a lane registry row records next to its model."""
    match = re.search(r"\[model=([^\]]*)\]", task_column or "")
    if not match:
        return None
    for word in reversed(match.group(1).split()):
        code = effort_code(word)
        if code:
            return code
    return None


def lane_harness(lane_key):
    """Read the harness segment a lane key carries, when it carries one."""
    first = (lane_key or "").split("-")[0]
    if first in HARNESSES:
        return first
    return None


def board_prefix(harness, model, effort, host):
    """Build the captain-locked board prefix. A missing part prints unknown."""
    return "[%s·%s %s @%s]" % (
        harness or UNKNOWN,
        model or UNKNOWN,
        effort or UNKNOWN,
        host or UNKNOWN,
    )


def clip(text, width):
    """Shorten a line for the compact view without cutting a word in half."""
    flat = " ".join((text or "").split())
    if len(flat) <= width:
        return flat
    cut = flat[:width].rsplit(" ", 1)[0]
    return cut + "..."


def age_days(created):
    """Days since a recorded date, or None when no date is recorded."""
    if not created:
        return None
    try:
        stamp = date(*[int(part) for part in created.split("-")])
    except (ValueError, TypeError):
        return None
    return (date.today() - stamp).days


def artifact_exists(path):
    """True when a recorded artifact path exists on disk."""
    if os.path.isabs(path):
        return os.path.exists(path)
    return os.path.exists(os.path.join(ARTIFACT_ROOT, path))


def artifact_paths(task):
    """Artifact and report paths the ticket records, in the order they appear."""
    text = task["title"] + "\n" + task["body"]
    found = []
    for match in PATH_RE.finditer(text):
        path = match.group(0).rstrip("/").rstrip(".,;:")
        if not path or path in found:
            continue
        if not (path.endswith(ARTIFACT_SUFFIXES) or artifact_exists(path)):
            continue
        found.append(path)
    convention = "data/%s/report.md" % task["id"]
    if convention not in found and artifact_exists(convention):
        found.append(convention)
    return found


def artifact_dirs(paths):
    """Directory prefixes an artifact path points at, specific enough to match."""
    dirs = []
    for path in paths:
        if path.endswith(ARTIFACT_SUFFIXES):
            base = os.path.dirname(path)
        else:
            base = path
        if not base or base in ("data", "."):
            continue
        if not re.search(r"data/[^/]+", base):
            continue
        if base not in dirs:
            dirs.append(base)
    return dirs


def lane_matches(task, lane_rows):
    """Lane rows that claim this ticket, by id or by an artifact path prefix."""
    exact = []
    by_path = []
    dirs = artifact_dirs(artifact_paths(task))
    for row in lane_rows:
        haystack = " ".join([row["lane_key"], row["task"], row["output"]])
        if re.search(r"(?<![A-Za-z0-9._-])" + re.escape(task["id"]) + r"(?![A-Za-z0-9._-])", haystack):
            exact.append(row)
            continue
        output = row["output"].strip()
        for base in dirs:
            if output.startswith(base + "/") or ("/" + base + "/") in output:
                by_path.append(row)
                break
    return exact, by_path


def lane_is_live(state):
    """A lane row is live when its state does not start with a terminal token."""
    token = (state or "").strip().split("-")[0].lower()
    if not token:
        return False
    return token not in TERMINAL_LANE_TOKENS


def hold_active(task):
    """A hold is active while the ticket is open and any hold-until date is in the future."""
    if not task["hold_reason"]:
        return False
    if task["state"] == "done":
        return False
    if task["hold_until"]:
        try:
            until = date(*[int(part) for part in task["hold_until"].split("-")])
        except (ValueError, TypeError):
            return True
        return until > date.today()
    return True


def lane_list(rows):
    """Name the lane rows that claim a ticket, capped so one row cannot flood."""
    shown = [row["lane_key"] for row in rows[:3]]
    text = ", ".join(shown)
    if len(rows) > 3:
        text += " and %d more" % (len(rows) - 3)
    return text


def task_prefix(task, lane_rows):
    """Build a ticket row prefix from the spawn record, then a matching lane row.

    The spawn record wins. A lane row that names the ticket id wins next.
    A lane row that owns the artifact path the ticket records is the last source.
    Every part is taken from a recorded value, and a part no source records
    prints as unknown.
    """
    meta = read_meta(task["id"])
    harness = meta.get("harness") or None
    model = model_abbrev(meta.get("model"))
    effort = effort_code(meta.get("effort"))
    host = None
    exact, by_path = lane_matches(task, lane_rows)
    for row in exact + by_path:
        if harness is None:
            harness = lane_harness(row["lane_key"])
        if model is None:
            model = model_abbrev(row["model"])
        if effort is None:
            effort = lane_effort(row["task"])
        if host is None and row["surface"].strip():
            host = row["surface"].strip().lower()
    return board_prefix(harness, model, effort, host)


def lane_prefix(row):
    """Build a lane row prefix from the lane key and the registry columns."""
    harness = lane_harness(row["lane_key"])
    model = model_abbrev(row["model"])
    effort = lane_effort(row["task"])
    host = row["surface"].strip().lower() if row["surface"].strip() else None
    return board_prefix(harness, model, effort, host)


def main():
    try:
        tasks = parse_backlog(BACKLOG)
    except OSError as exc:
        print("fm-ticket-board.sh: backlog file is unreadable: %s (%s)" % (BACKLOG, exc), file=sys.stderr)
        return 2
    except ValueError as exc:
        print("fm-ticket-board.sh: backlog file is unreadable: %s (%s)" % (BACKLOG, exc), file=sys.stderr)
        return 2
    lane_rows = load_lane_rows(os.path.join(DATA_DIR, "async-lanes.tsv"))
    core_lanes = load_core_lanes(os.path.join(DATA_DIR, "core-remediation", "lanes.json"))
    by_id = {task["id"]: task for task in tasks}

    open_tasks = [task for task in tasks if task["state"] != "done"]
    captain = [task for task in tasks if hold_active(task) and task["hold_kind"] == "captain"]
    captain.sort(key=lambda task: (task["created"] or "9999-99-99", task["id"]))
    blocked = [task for task in open_tasks if any(dep["type"] == "blocked-by" for dep in task["deps"])]
    in_flight = [task for task in tasks if task["state"] == "in_flight"]
    queued = [task for task in tasks if task["state"] == "queued"]
    held = [task for task in tasks if hold_active(task)]
    held_queued = [task for task in queued if hold_active(task)]
    blocked_queued = [task for task in queued if any(dep["type"] == "blocked-by" for dep in task["deps"])]
    blocked_queued_ids = set(task["id"] for task in blocked_queued)
    ready = [
        task for task in queued
        if not hold_active(task)
        and not any(dep["type"] == "blocked-by" for dep in task["deps"])
    ]
    ready.sort(key=lambda task: (task["priority"] if task["priority"] is not None else 9, task["id"]))
    held_and_blocked = [task for task in queued
                        if hold_active(task) and task["id"] in blocked_queued_ids]
    held_only = [task for task in queued
                 if hold_active(task) and task["id"] not in blocked_queued_ids]
    blocked_only = [task for task in queued
                    if not hold_active(task) and task["id"] in blocked_queued_ids]

    stale = []
    for task in open_tasks:
        reasons = []
        lowered = task["title"].lower()
        for phrase in RESOLUTION_PHRASES:
            if re.search(r"(?<![a-z])" + re.escape(phrase) + r"(?![a-z])", lowered):
                reasons.append('title states a resolution ("%s")' % phrase)
                break
        for path in artifact_paths(task):
            if path.endswith("/report.md") and artifact_exists(path):
                reasons.append("report exists on disk while still %s: %s" % (task["state"], path))
                break
        if reasons:
            stale.append((task, reasons))
    stale.sort(key=lambda entry: (entry[0]["created"] or "9999-99-99", entry[0]["id"]))

    live_lanes = [row for row in lane_rows if lane_is_live(row["state"])]

    out = []
    out.append("=== ticket board ===")
    out.append("backlog: %s" % BACKLOG)
    out.append("tickets: %d total | %d in flight | %d queued | %d done | %d held | %d captain-held"
               % (len(tasks), len(in_flight), len(queued),
                  len(tasks) - len(in_flight) - len(queued), len(held), len(captain)))

    out.append("")
    out.append("== NEEDS YOUR INPUT (%d) ==" % len(captain))
    if not captain:
        out.append("  (nothing is held on the Captain)")
    for task in captain:
        title = task["title"] if FULL else clip(task["title"], 90)
        ask = task["hold_reason"] or ""
        ask = ask if FULL else clip(ask, 110)
        waited = age_days(task["created"])
        waiting = "waiting unknown" if waited is None else "waiting %dd" % waited
        out.append("%s %s - %s | ask: %s | %s"
                   % (task_prefix(task, lane_rows), task["id"], title,
                      ask if ask else "no recorded question", waiting))

    out.append("")
    out.append("== BLOCKED (%d) ==" % len(blocked))
    if not blocked:
        out.append("  (no ticket carries a blocked-by edge)")
    for task in blocked:
        out.append("%s %s - %s" % (task_prefix(task, lane_rows), task["id"], task["title"]))
        for dep in task["deps"]:
            if dep["type"] != "blocked-by":
                continue
            blocker = by_id.get(dep["id"])
            lane = core_lanes.get(dep["id"])
            if lane:
                owner = lane.get("owner") or UNKNOWN
                status = lane.get("status") or UNKNOWN
                source = "core lane"
            elif blocker:
                owner = blocker.get("kind") or UNKNOWN
                status = blocker.get("state") or UNKNOWN
                source = "ticket"
            else:
                owner = UNKNOWN
                status = UNKNOWN
                source = "not in the backlog or the core lane manifest"
            out.append("    blocker: %s | owner: %s | status: %s | source: %s"
                       % (dep["id"], owner, status, source))
            if dep.get("reason"):
                out.append("    reason: %s" % (dep["reason"] if FULL else clip(dep["reason"], 150)))

    out.append("")
    out.append("== IN FLIGHT (%d) ==" % len(in_flight))
    if not in_flight:
        out.append("  (nothing is in flight)")
    for task in in_flight:
        out.append("%s %s - %s" % (task_prefix(task, lane_rows), task["id"], task["title"]))
        exact, by_path = lane_matches(task, lane_rows)
        lane = core_lanes.get(task["id"])
        if exact:
            out.append("    lane: %s" % lane_list(exact))
        elif by_path:
            out.append("    lane: %s (artifact path match)" % lane_list(by_path))
        elif lane:
            out.append("    lane: %s (core lane, status %s)" % (lane.get("id"), lane.get("status") or UNKNOWN))
        else:
            out.append("    lane: none recorded")
        paths = artifact_paths(task)
        if paths:
            for path in paths[: (len(paths) if FULL else 2)]:
                mark = "exists" if artifact_exists(path) else "missing"
                out.append("    artifact: %s (%s)" % (path, mark))
        else:
            out.append("    artifact: none recorded")

    out.append("")
    out.append("== READY / QUEUED (%d ready of %d queued) ==" % (len(ready), len(queued)))
    out.append("  queued %d = ready %d + held %d + blocked %d + held and blocked %d"
               % (len(queued), len(ready), len(held_only), len(blocked_only), len(held_and_blocked)))
    if ready:
        by_kind = {}
        by_repo = {}
        for task in ready:
            by_kind[task.get("kind") or UNKNOWN] = by_kind.get(task.get("kind") or UNKNOWN, 0) + 1
            by_repo[task.get("repo") or UNKNOWN] = by_repo.get(task.get("repo") or UNKNOWN, 0) + 1
        out.append("  by kind: %s" % ", ".join("%s %d" % (key, by_kind[key]) for key in sorted(by_kind)))
        out.append("  by repo: %s" % ", ".join("%s %d" % (key, by_repo[key]) for key in sorted(by_repo)))
        shown = ready if FULL else ready[:5]
        for task in shown:
            out.append("  %s %s - %s" % (task_prefix(task, lane_rows), task["id"], task["title"]))
        if len(shown) < len(ready):
            out.append("  (%d more ready tickets, use --full)" % (len(ready) - len(shown)))
    else:
        out.append("  (no ready ticket)")

    out.append("")
    out.append("== STALE (%d) ==" % len(stale))
    out.append("  open tickets that look finished. This view closes nothing.")
    if not stale:
        out.append("  (no stale ticket detected)")
    for task, reasons in stale:
        out.append("%s %s - %s" % (task_prefix(task, lane_rows), task["id"], task["title"]))
        for reason in reasons:
            out.append("    why: %s" % reason)

    out.append("")
    out.append("== LANES (%d live of %d rows) ==" % (len(live_lanes), len(lane_rows)))
    if not lane_rows:
        out.append("  (no lane registry found)")
    for row in (lane_rows if FULL else live_lanes):
        out.append("%s %s - %s" % (lane_prefix(row), row["lane_key"], row["state"]))
    if not FULL and live_lanes:
        out.append("  (%d terminal lane rows hidden, use --full)" % (len(lane_rows) - len(live_lanes)))

    print("\n".join(out))
    return 0


sys.exit(main())
PY
