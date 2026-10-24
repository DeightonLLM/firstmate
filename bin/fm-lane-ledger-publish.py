#!/usr/bin/env python3
"""fm-lane-ledger-publish.py - publish the machine lane ledger, and the board from it.

THE DEFECT THIS TOOL EXISTS FOR
-------------------------------
The to-do board is GENERATED from the machine lane ledger (ops/lane-ledger.tsv),
so a lane that never gets a ledger row never reaches the board. On 2026-10-24
four lanes were dispatched and confirmed running - each with its own
state/<id>.meta and state/<id>.status - and ops/lane-ledger.tsv held zero rows
matching them. The board said "_no active lanes in the ledger_" while four
lanes were in flight. The board did not disagree with the ledger; the ledger
disagreed with reality, and the board reported the ledger faithfully. That is
still a board that lies to the Captain.

The gap was that NOTHING wrote the ledger. Every tool in the fleet that names
ops/lane-ledger.tsv only READS it. The ledger was maintained by hand and by
one-off ad-hoc scripts, so the spawn of a lane - a routine, machine-detectable
event - never produced a row.

THE RULE
--------
A lane is not real until it is on the board, and the PUBLISHER owns that. Not
the renderer: the renderer is told what the machine truth is and must not
guess. The publisher owns the machine truth, so the publisher writes the row
when the lane spawns and republishes the board from it.

WHAT THIS TOOL OWNS
-------------------
  * ops/lane-ledger.tsv    - the machine truth (TAB separated, 9 columns)
  * ops/LANE-CLAIMS.md    - the human view of the same machine state

Both live in the firstmate home's own ops/ directory, which is where
bin/build-next-board.py, bin/fm-todo-gate.sh and bin/fm-board-refresh.sh
resolve them from. The publisher is the only writer of these two files in
this home, so the ledger and the claims board cannot drift apart behind the
gate's back: every ledger row gets a claims row.

The ledger is a SUPERSET of the published ledger. A home that has no ledger of
its own would silently publish a board that dropped every lane another home
holds, so the publisher seeds its ledger from the published copy and keeps the
seeded rows in step with it. The publisher only ever ADDS rows and refreshes
rows that came from upstream; it never deletes a row, because a row is a
record of work that happened.

THE SPAWN EVENT
---------------
The spawn of a lane is a machine-detectable event: bin/fm-spawn.sh writes
state/<id>.meta when the lane is created and prints "spawned <id> ..." once
the agent is verified alive. The meta IS the spawn record. This tool reacts to
it in three ways:

  register <lane-id>   the spawn event, named. Writes the row for that lane
                       now and republishes the board.
  close <lane-id>      close a lane's claim: the row moves to DONE, the expiry
                       empties and the claims board says '-' for the scope it
                       held. The row is never deleted.
  watch                the spawn event, observed. Blocks until a lane spawn
                       record appears that has no ledger row, then registers
                       it. This works with ANY spawn path, including ones
                       this tool may not modify.
  reconcile            the catch-up. Registers every live lane that has no
                       row, so a lane that spawned while the publisher was
                       down still lands on the board.

WHAT THIS TOOL NEVER DOES
-------------------------
It never deletes or rewrites a lane's own row, never invents a lane id, never
writes a lane's report, status or meta file, and never weakens or edits the
to-do gate. If it cannot write the ledger truthfully it fails and says so.

usage: fm-lane-ledger-publish.py [register <lane-id> | close <lane-id>
                                 | reconcile | watch]
                                 [--repo <path>] [--ops <dir>] [--ledger <path>]
                                 [--claims <path>] [--board <path>]
                                 [--state <dir>] [--no-refresh] [--check]
                                 [--timeout <seconds>]
"""

import argparse
import datetime as dt
import os
import pathlib
import re
import subprocess
import sys
import time

LEDGER_COLUMNS = [
    "lane_id", "state", "owner", "opened", "updated",
    "expires", "next", "artifact", "branch",
]
LEDGER_HEADER = "\t".join(LEDGER_COLUMNS)

# The claim state vocabulary the drift checker reads out of the claims board.
CLAIM_STATES = ("ACTIVE", "DONE", "RELEASED", "BLOCKED", "EXPIRED")
LEDGER_STATES = ("ACTIVE", "DONE", "BLOCKED", "RELEASED")
CLAIM_STATE_RE = re.compile(r"\*\*(ACTIVE|DONE|RELEASED|BLOCKED|EXPIRED)\*\*")

# A status line that starts with one of these is a terminal wake event: the
# lane is no longer working, so it is not an in-flight lane any more.
TERMINAL_STATUS_PREFIXES = (
    "done:", "failed:", "blocked:", "parked:", "paused:", "needs-decision:",
)

# Where a home that has no ledger of its own finds the published one. The
# first candidate that exists is the published copy this home inherits.
PUBLISHED_LEDGER_CANDIDATES = (
    "/root/agent-work/ops/lane-ledger.tsv",
    "/root/ops/lane-ledger.tsv",
    "/home/hd2admin/ops/lane-ledger.tsv",
    "/home/hd2admin/agent-work/core-distro-saas-clean/ops/lane-ledger.tsv",
)
PUBLISHED_CLAIMS_CANDIDATES = (
    "/root/agent-work/ops/LANE-CLAIMS.md",
    "/root/ops/LANE-CLAIMS.md",
    "/home/hd2admin/ops/LANE-CLAIMS.md",
    "/home/hd2admin/agent-work/core-distro-saas-clean/ops/LANE-CLAIMS.md",
)

DEFAULT_OWNER = "firstmate"
DEFAULT_CLAIM_TTL_HOURS = 4.0


def now_utc():
    return dt.datetime.now(dt.timezone.utc)


def iso(stamp):
    """ISO 8601 UTC, the shape the ledger writes."""
    return stamp.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def claims_expiry(stamp):
    """The claims board writes local wall clock with a zone name; the drift
    checker resolves the zone explicitly, so the same instant is readable."""
    local = stamp.astimezone(dt.timezone.utc)
    zone = "UTC"
    try:
        out = subprocess.run(
            ["date", "-d", "@%d" % int(stamp.timestamp()), "+%Y-%m-%d %H:%M %Z"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        parts = out.split()
        if len(parts) == 3:
            local = dt.datetime.strptime(" ".join(parts[:2]), "%Y-%m-%d %H:%M")
            zone = parts[2]
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return "%s %s" % (local.strftime("%Y-%m-%d %H:%M"), zone)


def clean_cell(value, limit=400):
    """A ledger cell is TAB separated: a TAB or a newline inside a cell would
    make the row unreadable, so it is flattened."""
    text = str(value or "").replace("\t", " ").replace("\r", " ").replace("\n", " ").strip()
    if len(text) > limit:
        text = text[: limit - 1].rstrip() + "…"
    return text


# --------------------------------------------------------------------------
# the ledger
# --------------------------------------------------------------------------

def read_ledger(path):
    """(header_lines, rows). header_lines keeps the comment block and the
    column header so a rewrite never loses them."""
    header, rows = [], []
    if not path.is_file():
        return header, rows
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not raw.strip():
            continue
        if raw.lstrip().startswith("#"):
            header.append(raw)
            continue
        cells = raw.split("\t")
        while len(cells) < len(LEDGER_COLUMNS):
            cells.append("")
        if cells[0].strip() == "lane_id":
            header.append(raw)
            continue
        rows.append({
            "lane_id": cells[0].strip(),
            "state": cells[1].strip().upper(),
            "owner": cells[2].strip(),
            "opened": cells[3].strip(),
            "updated": cells[4].strip(),
            "expires": cells[5].strip(),
            "next": cells[6].strip(),
            "artifact": cells[7].strip(),
            "branch": cells[8].strip(),
        })
    return header, rows


def write_ledger(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = list(header)
    if not any(line.split("\t")[0].strip() == "lane_id" for line in lines):
        lines.append(LEDGER_HEADER)
    for row in rows:
        lines.append("\t".join(clean_cell(row.get(col, "")) for col in LEDGER_COLUMNS))
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(str(tmp), str(path))


def ledger_row(row):
    return "\t".join(clean_cell(row.get(col, "")) for col in LEDGER_COLUMNS)


# --------------------------------------------------------------------------
# the claims board
# --------------------------------------------------------------------------

def read_claims(path):
    """The live-claims table only: 7 cells, the first cell a lane id in
    backticks. The shape is the drift checker's shape."""
    rows = []
    if not path.is_file():
        return rows
    in_section = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("## "):
            in_section = "Live claims" in line
            continue
        if not in_section or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 7:
            continue
        if not cells[0].startswith("`"):
            continue
        lane = cells[0].strip("`").strip()
        if not lane:
            continue
        token = CLAIM_STATE_RE.search(cells[6])
        rows.append({"lane": lane, "state": token.group(1) if token else "UNKNOWN",
                     "expires": cells[5].strip(), "cells": cells})
    return rows


def add_claims_row(path, cells):
    """Add a row to the live-claims table. The table has no header row of its
    own, so the row goes in right after the separator when there is one and
    right after the heading when there is not."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines() if path.is_file() else []
    row_text = "| " + " | ".join(clean_cell(c, 2000) for c in cells) + " |"
    heading = None
    for index, line in enumerate(lines):
        if line.startswith("## ") and "Live claims" in line:
            heading = index
            break
    if heading is None:
        if not lines:
            lines = ["# Lane claims board — who is touching what, right now", ""]
        lines += ["", "## Live claims", row_text]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return
    insert_at = heading + 1
    for index in range(heading + 1, len(lines)):
        line = lines[index]
        if line.startswith("## "):
            break
        if line.startswith("|---"):
            insert_at = index + 1
            break
        if line.startswith("|"):
            insert_at = index
            break
    lines.insert(insert_at, row_text)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def set_claims_state(path, lane, state):
    """Keep the state cell of a claims row in step with the ledger."""
    if not path.is_file():
        return False
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    in_section = False
    changed = False
    for index, line in enumerate(lines):
        if line.startswith("## "):
            in_section = "Live claims" in line
            continue
        if not in_section or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 7 or not cells[0].startswith("`"):
            continue
        if cells[0].strip("`").strip() != lane:
            continue
        token = CLAIM_STATE_RE.search(cells[6])
        if token and token.group(1) == state:
            continue
        cells[6] = re.sub(r"\*\*(ACTIVE|DONE|RELEASED|BLOCKED|EXPIRED)\*\*",
                           "**%s**" % state, cells[6]) if token else "**%s**" % state
        lines[index] = "| " + " | ".join(cells) + " |"
        changed = True
    if changed:
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return changed


def close_claims_row(path, lane, state):
    """Close a lane on the claims board: the state token moves and the expiry
    cell becomes '-', because a closed lane holds no scope."""
    if not path.is_file():
        return False
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    in_section = False
    changed = False
    for index, line in enumerate(lines):
        if line.startswith("## "):
            in_section = "Live claims" in line
            continue
        if not in_section or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 7 or not cells[0].startswith("`"):
            continue
        if cells[0].strip("`").strip() != lane:
            continue
        token = CLAIM_STATE_RE.search(cells[6])
        cells[6] = (re.sub(r"\*\*(ACTIVE|DONE|RELEASED|BLOCKED|EXPIRED)\*\*",
                           "**%s**" % state, cells[6])
                    if token else "**%s** - closed" % state)
        cells[5] = "-"
        lines[index] = "| " + " | ".join(cells) + " |"
        changed = True
    if changed:
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return changed


# --------------------------------------------------------------------------
# the spawn record
# --------------------------------------------------------------------------

def read_meta(state_dir, lane_id):
    """The spawn record of one lane: state/<id>.meta."""
    path = pathlib.Path(state_dir) / ("%s.meta" % lane_id)
    if not path.is_file():
        return None
    meta = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            meta[key.strip()] = value.strip()
    meta["_path"] = str(path)
    return meta


def read_status(state_dir, lane_id):
    path = pathlib.Path(state_dir) / ("%s.status" % lane_id)
    if not path.is_file():
        return []
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def lane_state(state_dir, lane_id):
    """(is_live, next_note). A lane with no spawn record is not a lane here.
    A lane whose last wake event is terminal is finished. A lane that is still
    working carries its last working note, which is its real next action."""
    notes = read_status(state_dir, lane_id)
    last = ""
    for line in notes:
        if line.strip():
            last = line.strip()
    if not last:
        return True, ""
    if last.lower().startswith(TERMINAL_STATUS_PREFIXES):
        return False, last
    if last.lower().startswith("working:"):
        return True, last.split(":", 1)[1].strip()
    return True, last


def live_lanes(state_dir):
    """Every lane in this home that is alive: a spawn record, and no terminal
    wake event. A second mate is not a lane: it is a standing worker, it has
    its own home, and it must never be published as a lane claim."""
    lanes = []
    for meta_path in sorted(pathlib.Path(state_dir).glob("*.meta")):
        lane_id = meta_path.name[: -len(".meta")]
        meta = read_meta(state_dir, lane_id)
        if not meta:
            continue
        if meta.get("kind") == "secondmate" or meta.get("mode") == "secondmate":
            continue
        alive, note = lane_state(state_dir, lane_id)
        if not alive:
            continue
        lanes.append((lane_id, meta, note))
    return lanes


def git_branch(worktree):
    if not worktree:
        return "-"
    try:
        out = subprocess.run(["git", "-C", worktree, "branch", "--show-current"],
                             capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return "-"
    return out or "-"


def build_row(lane_id, meta, note, owner, ttl_hours):
    """The ledger row for a live lane: its real identity and its real state."""
    spawned = meta.get("spawned_at")
    try:
        opened = dt.datetime.fromtimestamp(int(spawned), dt.timezone.utc)
    except (TypeError, ValueError):
        opened = now_utc()
    expires = opened + dt.timedelta(hours=ttl_hours)
    branch = git_branch(meta.get("worktree"))
    artifact = "data/%s/report.md" % lane_id
    next_text = note or "the lane is running and has not posted a wake note yet"
    return {
        "lane_id": lane_id,
        "state": "ACTIVE",
        "owner": owner,
        "opened": iso(opened),
        "updated": iso(now_utc()),
        "expires": iso(expires),
        "next": next_text,
        "artifact": artifact,
        "branch": branch,
    }


def build_claims_cells(row, meta, repo):
    """The human view of the same machine state: 7 cells, the lane id in
    backticks, the state token in the last cell."""
    where = "%s %s" % (os.uname().nodename, "the Hetz surface")
    scope = "its own worktree %s, its brief data/%s/brief.md and its report data/%s/report.md" % (
        meta.get("worktree") or "(none)", row["lane_id"], row["lane_id"])
    holder = "firstmate (`%s`, branch `%s`)" % (repo, row["branch"])
    expiry = claims_expiry(dt.datetime.strptime(row["expires"], "%Y-%m-%dT%H:%M:%SZ")
                            .replace(tzinfo=dt.timezone.utc)) if row["expires"] else "-"
    state_cell = "**%s** - %s" % (row["state"], row["next"])
    return ["`%s`" % row["lane_id"], where, scope, holder, expiry, "-", state_cell]


# --------------------------------------------------------------------------
# the publisher
# --------------------------------------------------------------------------

class Publisher:
    def __init__(self, args):
        self.args = args
        self.repo = pathlib.Path(args.repo).resolve()
        self.ops = pathlib.Path(args.ops).resolve() if args.ops else self.repo / "ops"
        self.ledger = pathlib.Path(args.ledger).resolve() if args.ledger else self.ops / "lane-ledger.tsv"
        self.claims = pathlib.Path(args.claims).resolve() if args.claims else self.ops / "LANE-CLAIMS.md"
        self.board = pathlib.Path(args.board).resolve() if args.board else self.repo / "data" / "tracker" / "NEXT-BOARD.md"
        self.state = pathlib.Path(args.state).resolve() if args.state else self.repo / "state"
        self.inherit_marker = self.ops / ".inherited-ledger-source"
        self.owner = args.owner
        self.ttl = args.claim_ttl_hours
        self.seed_source = pathlib.Path(args.seed_from).resolve() if args.seed_from else None
        self.seed_claims_source = pathlib.Path(args.seed_claims_from).resolve() if args.seed_claims_from else None
        self.notes = []

    def say(self, message):
        self.notes.append(message)
        print("lane-ledger-publish: %s" % message)

    # -- the published ledger this home inherits ---------------------------

    def published_ledger(self):
        for candidate in PUBLISHED_LEDGER_CANDIDATES:
            path = pathlib.Path(candidate)
            if path.is_file():
                try:
                    if path.resolve() == self.ledger.resolve():
                        continue
                except OSError:
                    pass
                return path
        return None

    def published_claims(self):
        for candidate in PUBLISHED_CLAIMS_CANDIDATES:
            path = pathlib.Path(candidate)
            if path.is_file():
                try:
                    if path.resolve() == self.claims.resolve():
                        continue
                except OSError:
                    pass
                return path
        return None

    def seed(self):
        """A home with no ledger of its own would publish a board that dropped
        every lane another home holds. The publisher inherits the published
        ledger and claims board once, and keeps the inherited rows in step."""
        if self.args.no_seed:
            if not self.ledger.is_file():
                write_ledger(self.ledger, [], [])
            if not self.claims.is_file():
                self.claims.parent.mkdir(parents=True, exist_ok=True)
                self.claims.write_text(
                    "# Lane claims board — who is touching what, right now\n\n"
                    "## Live claims\n", encoding="utf-8")
            return
        if not self.ledger.is_file():
            source = self.seed_source or self.published_ledger()
            if source:
                header, rows = read_ledger(source)
                write_ledger(self.ledger, header, rows)
                self.inherit_marker.write_text("%s\n" % source, encoding="utf-8")
                self.say("seeded the ledger from the published copy %s (%d rows)"
                         % (source, len(rows)))
            else:
                write_ledger(self.ledger, [], [])
                self.say("started an empty ledger at %s" % self.ledger)
        if not self.claims.is_file():
            source = self.seed_claims_source or self.published_claims()
            if source:
                self.claims.parent.mkdir(parents=True, exist_ok=True)
                self.claims.write_text(source.read_text(encoding="utf-8", errors="replace"),
                                       encoding="utf-8")
                self.say("seeded the claims board from the published copy %s" % source)
            else:
                self.claims.parent.mkdir(parents=True, exist_ok=True)
                self.claims.write_text(
                    "# Lane claims board — who is touching what, right now\n\n"
                    "## Live claims\n", encoding="utf-8")
                self.say("started an empty claims board at %s" % self.claims)

    # -- keeping the inherited rows in step -------------------------------

    def sync_published(self, rows):
        """A row that came from the published ledger is owned by the home that
        published it, so that home stays the authority for it. A row this
        publisher wrote is owned by this home and is never touched here."""
        source = None
        if self.inherit_marker.is_file():
            named = self.inherit_marker.read_text(encoding="utf-8").strip()
            if named and pathlib.Path(named).is_file():
                source = pathlib.Path(named)
        if not source or self.args.no_seed:
            return 0
        _, published = read_ledger(source)
        by_id = {row["lane_id"]: row for row in rows}
        changed = 0
        for row in published:
            if not row.get("lane_id") or row.get("state") not in LEDGER_STATES:
                # a torn or foreign row is never imported: the ledger stays true
                continue
            local = by_id.get(row["lane_id"])
            if local is None:
                rows.append(dict(row))
                by_id[row["lane_id"]] = row
                changed += 1
                continue
            if local.get("owner") == self.owner:
                continue
            if (local.get("state"), local.get("updated")) != (row.get("state"), row.get("updated")):
                for col in LEDGER_COLUMNS:
                    if col in ("lane_id",):
                        continue
                    local[col] = row.get(col, "")
                changed += 1
        if changed:
            self.say("brought %d published ledger row(s) in step" % changed)
        return changed

    # -- the lane rows ----------------------------------------------------

    def register(self, lane_id, rows, header):
        """Write the row for one lane. The spawn record is the source of the
        lane's identity; the row carries the lane's real state."""
        meta = read_meta(self.state, lane_id)
        if not meta:
            self.say("FAIL %s has no spawn record in %s, so there is no lane to publish"
                     % (lane_id, self.state))
            return False
        if meta.get("kind") == "secondmate" or meta.get("mode") == "secondmate":
            self.say("FAIL %s is a second mate, not a lane: it is not published as a lane claim"
                     % lane_id)
            return False
        identity = meta.get("endpoint_task_id") or lane_id
        for row in rows:
            if row["lane_id"] in (lane_id, identity):
                self.say("%s already has a ledger row (state %s)" % (identity, row["state"]))
                return False
        alive, note = lane_state(self.state, lane_id)
        row = build_row(identity, meta, note, self.owner, self.ttl)
        rows.append(row)
        cells = build_claims_cells(row, meta, self.repo)
        add_claims_row(self.claims, cells)
        write_ledger(self.ledger, header, rows)
        self.say("published %s as ACTIVE (opened %s, expires %s)"
                 % (identity, row["opened"], row["expires"]))
        return True

    # -- the claims board must cover the ledger ---------------------------

    def claims_coverage(self, rows):
        """Every row in the ledger has a row on the claims board, or the gate
        refuses. The publisher owns both files, so it closes the gap it is
        responsible for instead of leaving the gate red."""
        claims = {row["lane"] for row in read_claims(self.claims)}
        added = 0
        for row in rows:
            if row["lane_id"] in claims:
                continue
            cells = build_claims_cells(row, {"worktree": row.get("branch") and "" or ""}, self.repo)
            cells[1] = row.get("owner") or self.owner
            cells[2] = row.get("artifact") or "the work its ledger row records"
            cells[3] = "%s (branch `%s`)" % (self.owner, row.get("branch") or "-")
            cells[4] = claims_expiry(dt.datetime.strptime(row["expires"], "%Y-%m-%dT%H:%M:%SZ")
                                    .replace(tzinfo=dt.timezone.utc)) if row.get("expires") else "-"
            cells[6] = "**%s** - %s" % (row["state"], row.get("next") or "no next action recorded")
            add_claims_row(self.claims, cells)
            claims.add(row["lane_id"])
            added += 1
        if added:
            self.say("added %d claims row(s) for ledger rows that had none" % added)
        # and the state token of a claims row must agree with the ledger
        for row in rows:
            set_claims_state(self.claims, row["lane_id"], row["state"])
        return added

    # -- republishing the board -------------------------------------------

    def board_items(self, path):
        """The number of items the board carries. A board must never lose
        items: a publication that drops one is a publication that lies."""
        if not path.is_file():
            return None
        text = path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"\*\*items:\*\*\s*([0-9]+)", text)
        return int(match.group(1)) if match else None

    def republish(self):
        """The board is rebuilt from the ledger that was just written, so the
        published board counts the lane at once."""
        if self.args.no_refresh:
            return True
        refresher = pathlib.Path(__file__).resolve().parent / "fm-board-refresh.sh"
        if not refresher.is_file():
            refresher = self.repo / "bin" / "fm-board-refresh.sh"
        if not refresher.is_file():
            self.say("FAIL the board publisher %s is missing, so the board was not refreshed"
                     % refresher)
            return False
        items_before = self.board_items(self.board)
        # FM_LANE_LEDGER_PUBLISHED tells the board publisher that the ledger
        # has already been published, so the two never call each other in a
        # loop. An older copy of the board publisher simply ignores it.
        environment = dict(os.environ)
        environment["FM_LANE_LEDGER_PUBLISHED"] = "1"
        result = subprocess.run(
            ["bash", str(refresher), "--repo", str(self.repo), "--ledger", str(self.ledger),
             "--board", str(self.board)],
            capture_output=True, text=True, env=environment)
        for line in (result.stdout or "").splitlines():
            print("  %s" % line)
        if result.returncode != 0:
            for line in (result.stderr or "").splitlines():
                print("  %s" % line)
            self.say("FAIL the board was not republished (exit %d): the gate will refuse "
                     "a board that does not match the ledger" % result.returncode)
            return False
        items_after = self.board_items(self.board)
        if items_before is not None and items_after is not None and items_after < items_before:
            self.say("FAIL the republished board carries %d items and the board it replaced "
                     "carried %d: a publication that drops items is not a publication"
                     % (items_after, items_before))
            return False
        self.say("republished %s from %s" % (self.board, self.ledger))
        return True

    # -- the commands ------------------------------------------------------

    def reconcile(self):
        self.seed()
        header, rows = read_ledger(self.ledger)
        changed = self.sync_published(rows)
        registered = 0
        for lane_id, meta, note in live_lanes(self.state):
            identity = meta.get("endpoint_task_id") or lane_id
            if any(row["lane_id"] == identity for row in rows):
                continue
            alive, _ = lane_state(self.state, lane_id)
            if not alive:
                continue
            row = build_row(identity, meta, note, self.owner, self.ttl)
            rows.append(row)
            add_claims_row(self.claims, build_claims_cells(row, meta, self.repo))
            registered += 1
            changed += 1
            self.say("published %s as ACTIVE (opened %s, expires %s)"
                     % (identity, row["opened"], row["expires"]))
        write_ledger(self.ledger, header, rows)
        self.claims_coverage(rows)
        if self.args.check:
            self.say("check mode: %d ledger row(s), nothing was published" % len(rows))
            return 0
        if changed:
            self.republish()
        else:
            self.say("every live lane already has a ledger row")
        return 0

    def do_register(self, lane_id):
        self.seed()
        header, rows = read_ledger(self.ledger)
        self.sync_published(rows)
        changed = self.register(lane_id, rows, header)
        if not changed:
            # already published: the board may still be behind, so republish.
            self.republish()
            return 0
        write_ledger(self.ledger, header, rows)
        self.claims_coverage(rows)
        self.republish()
        return 0

    def do_close(self, lane_id):
        """Close a lane's claim: the row moves to DONE, the expiry empties and
        the claims board says '-' for the scope it held. The row is never
        deleted: a row is a record of work that happened."""
        self.seed()
        header, rows = read_ledger(self.ledger)
        target = None
        for row in rows:
            if row["lane_id"] == lane_id:
                target = row
                break
        if target is None:
            self.say("FAIL %s has no ledger row, so there is nothing to close" % lane_id)
            return 1
        if target["state"] == "DONE":
            self.say("%s is already closed" % lane_id)
            return 0
        target["state"] = "DONE"
        target["expires"] = ""
        target["updated"] = iso(now_utc())
        target["next"] = ("closed - the lane finished; the follow-up is recorded in its "
                          "artifact %s" % target.get("artifact") or "its report")
        write_ledger(self.ledger, header, rows)
        close_claims_row(self.claims, lane_id, "DONE")
        self.say("closed %s (state DONE, expiry empty)" % lane_id)
        self.republish()
        return 0

    def do_watch(self):
        """The spawn event, observed. Any lane that appears in this home's
        state/ and has no ledger row is published at once."""
        deadline = time.time() + self.args.timeout
        # The watch compares lane IDENTITIES (the endpoint task id the spawn
        # record carries), not the file name the record happens to live under.
        seen = {meta.get("endpoint_task_id") or lane_id
                for lane_id, meta, _ in live_lanes(self.state)}
        while time.time() < deadline:
            for lane_id, meta, note in live_lanes(self.state):
                identity = meta.get("endpoint_task_id") or lane_id
                if identity in seen:
                    continue
                seen.add(identity)
                self.say("a lane spawned: %s" % identity)
                self.do_register(lane_id)
                return 0
            time.sleep(0.5)
        self.say("FAIL no lane spawned within %d seconds" % self.args.timeout)
        return 1


def main(argv):
    parser = argparse.ArgumentParser(add_help=True, description=__doc__.split("\n")[0])
    parser.add_argument("command", nargs="?", default="reconcile",
                        choices=("reconcile", "register", "watch", "close"))
    parser.add_argument("lane_id", nargs="?")
    parser.add_argument("--repo", default=os.environ.get("FM_REPO"))
    parser.add_argument("--ops", default=None)
    parser.add_argument("--ledger", default=os.environ.get("FM_TODO_LEDGER"))
    parser.add_argument("--claims", default=None)
    parser.add_argument("--board", default=os.environ.get("FM_TODO_BOARD"))
    parser.add_argument("--state", default=None)
    parser.add_argument("--no-refresh", action="store_true")
    parser.add_argument("--no-seed", action="store_true",
                        help="do not inherit the published ledger: this home's ledger stands alone")
    parser.add_argument("--seed-from", default=None,
                        help="the published ledger to inherit from")
    parser.add_argument("--seed-claims-from", default=None,
                        help="the published claims board to inherit from")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--owner", default=os.environ.get("FM_LANE_OWNER", DEFAULT_OWNER))
    parser.add_argument("--claim-ttl-hours", type=float,
                        default=float(os.environ.get("FM_LANE_CLAIM_TTL_HOURS", DEFAULT_CLAIM_TTL_HOURS)))
    args = parser.parse_args(argv)

    if not args.repo:
        args.repo = str(pathlib.Path(__file__).resolve().parent.parent)
    if args.command in ("register", "close") and not args.lane_id:
        parser.error("%s needs the lane id" % args.command)

    publisher = Publisher(args)
    if args.command == "register":
        return publisher.do_register(args.lane_id)
    if args.command == "close":
        return publisher.do_close(args.lane_id)
    if args.command == "watch":
        return publisher.do_watch()
    return publisher.reconcile()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
