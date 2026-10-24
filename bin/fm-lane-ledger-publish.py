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

THE END OF A LANE
-----------------
A claim that is never withdrawn is a claim that never frees. Two defects
measured on 2026-10-24 made the ledger lie in the direction that hides work:

  * reconcile only ever ADDED rows. Four lanes were torn down and their
    spawn records removed, and the ledger still carried all four as ACTIVE:
    there was no code path that moved a row to DONE.
  * the always-four scheduler keeps a SLOT record, state/lane-<N>.meta,
    naming the task the slot runs, and that record survives the task. The
    publisher walked the slot record, resolved identity = the slot's
    endpoint_task_id, and published the CLOSED task as ACTIVE with a fresh
    lease. Five closed tasks were published that way.

So the end of a lane is now a machine-detectable event too:

  close <lane-id>      the teardown calls this. A teardown and a claim
                       withdrawal are ONE operation: a lane that is torn down
                       must never leave a live claim behind. The close is
                       best effort - a failed ledger close must never block a
                       legitimate teardown - and it says so loudly.
  reconcile            the catch-up for the ends that were missed. It closes
                       the row of every lane that has ENDED, and renews the
                       claim of every lane that is still alive.

THE END OF A LANE IS PROVEN, NEVER GUESSED
------------------------------------------
A close must never hide work that is still running, so the close requires
POSITIVE evidence that the lane ended:

  * the lane's own spawn record, state/<id>.meta, is GONE. A lane is
    registered by that record and the teardown is the only thing in the
    fleet that removes it, so its absence is a fact about the lane. It is
    never the absence of a status line: a lane that has not posted a wake
    event yet has no status line either, and it is still running. A lane
    that still HAS its spawn record is never closed.
  * the claim belongs to THIS home. A row this publisher did not write, and
    a row inherited from the published ledger, belong to the home that
    published them and are never closed here.

A slot record alone is never a lane. The slot names a task; the lane is the
task, and the task must be registered here. A slot whose target task has no
spawn record of its own is an EMPTY slot: it never produces a ledger row and
it never keeps a claim alive.

WHAT THIS TOOL NEVER DOES
-------------------------
It never deletes a row, never invents a lane id, never writes a lane's
report, status or meta file, never closes a claim it does not own, and never
weakens or edits the to-do gate. If it cannot write the ledger truthfully it
fails and says so.

usage: fm-lane-ledger-publish.py [register <lane-id> | close <lane-id>
                                 | reconcile | watch]
                                 [--repo <path>] [--ops <dir>] [--ledger <path>]
                                 [--claims <path>] [--board <path>]
                                 [--state <dir>] [--no-refresh] [--check]
                                 [--if-present] [--timeout <seconds>]
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


def claims_expiry_text(iso_text):
    """The expiry cell of a claims row, for the expiry the ledger records.
    The claims board writes local wall clock with a zone name and the drift
    checker resolves the zone explicitly, so the same instant is readable.
    A claim that holds no scope expires at nothing: '-'."""
    if not iso_text:
        return "-"
    try:
        stamp = dt.datetime.strptime(str(iso_text), "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=dt.timezone.utc)
    except (TypeError, ValueError):
        return "-"
    return claims_expiry(stamp)


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


def set_claims_state(path, lane, state, expiry=None):
    """Keep the state cell of a claims row in step with the ledger. When an
    expiry is given it keeps the expiry cell in step too.

    THE EXPIRY CELL IS THE FIFTH, the one the live claims board writes and
    the one a human reads to know when a scope frees up. The sixth cell stays
    '-': that is the shape the drift checker reads, and it is the shape the
    board has always had.
    """
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
        state_cell = (re.sub(r"\*\*(ACTIVE|DONE|RELEASED|BLOCKED|EXPIRED)\*\*",
                              "**%s**" % state, cells[6])
                      if token else "**%s**" % state)
        if state_cell != cells[6]:
            cells[6] = state_cell
            changed = True
        if expiry is not None and cells[4] != expiry:
            cells[4] = expiry
            changed = True
        lines[index] = "| " + " | ".join(cells) + " |"
    if changed:
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return changed


def close_claims_row(path, lane, state):
    """Close a lane on the claims board: the state token moves and the expiry
    cell becomes '-', because a closed lane holds no scope. Both expiry cells
    are cleared: the fifth is the one a human reads, the sixth is the shape
    the drift checker reads."""
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
        cells[4] = "-"
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


def is_secondmate(meta):
    """A second mate is not a lane: it is a standing worker with its own home,
    and it must never be published as a lane claim."""
    if not meta:
        return False
    return meta.get("kind") == "secondmate" or meta.get("mode") == "secondmate"


def lane_state(state_dir, lane_id, fallback_id=None):
    """(is_live, next_note). A lane with no spawn record is not a lane here.
    A lane whose last wake event is terminal is finished. A lane that is still
    working carries its last working note, which is its real next action.

    The lane's own wake events live in state/<lane-id>.status. A lane SLOT
    (state/lane-<N>.meta) keeps only the scheduler's own binding events, so
    the slot's log is the FALLBACK for a lane that has no task log yet - the
    same order bin/fm-always-four.sh resolves a lane's log in."""
    notes = read_status(state_dir, lane_id)
    if not notes and fallback_id:
        notes = read_status(state_dir, fallback_id)
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


def lane_identities(state_dir):
    """(lanes, aliases).

    lanes   {identity: (meta, own_id)} - every lane REGISTERED in this home.
             A lane is registered by its OWN spawn record, state/<id>.meta.
    aliases {identity: [own_id, ...]} - the slot records that NAME that lane.

    The always-four scheduler keeps a SLOT record, state/lane-<N>.meta, that
    names the task the slot runs. A slot record is a REFERENCE to a lane, not
    a lane: it resolves to the identity its endpoint_task_id names, so the
    slot record and the task's own record are one lane, not two.
    """
    state_dir = pathlib.Path(state_dir)
    metas = {}
    for meta_path in sorted(state_dir.glob("*.meta")):
        own_id = meta_path.name[: -len(".meta")]
        meta = read_meta(state_dir, own_id)
        if not meta or is_secondmate(meta):
            continue
        metas[own_id] = meta
    lanes = {}
    aliases = {}
    for own_id, meta in metas.items():
        identity = meta.get("endpoint_task_id") or own_id
        if identity == own_id:
            lanes[identity] = (meta, own_id)
        else:
            aliases.setdefault(identity, []).append(own_id)
    return lanes, aliases


def live_lanes(state_dir):
    """Every lane in this home that is alive: a lane that is REGISTERED here,
    and no terminal wake event.

    A slot record alone never makes a lane. The always-four scheduler keeps
    state/lane-<N>.meta naming the task a slot runs, and that record survives
    the task it names. Before this, the publisher walked that slot record,
    resolved identity = meta.get("endpoint_task_id"), and published the TASK
    as ACTIVE with a fresh lease - naming work that was already closed. Five
    closed tasks were published that way on 2026-10-24.

    So a slot is only the lane it names when the task it names is REGISTERED
    here, with a spawn record of its own. A slot whose target task has no
    spawn record is an EMPTY slot: it must never produce a ledger row, and it
    must never keep a claim alive.
    """
    lanes, aliases = lane_identities(state_dir)
    out = []
    for identity, (meta, own_id) in lanes.items():
        slots = aliases.get(identity) or []
        alive, note = lane_state(state_dir, identity,
                                 fallback_id=slots[0] if slots else None)
        if not alive:
            continue
        out.append((identity, meta, note))
    return out


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
    expiry = claims_expiry_text(row["expires"])
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
        # The teardown copies a lane's own state into data/teardown-archives/
        # <lane-id>/<date>/ before it removes the lane's spawn record, so an
        # archive here is the durable witness that a lane ended in THIS home.
        self.archives = self.repo / "data" / "teardown-archives"
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

    def inherit_source(self):
        """The published ledger this home inherited, or None. A row that came
        from there belongs to the home that published it, so this home never
        withdraws its claim."""
        if self.args.no_seed or not self.inherit_marker.is_file():
            return None
        named = self.inherit_marker.read_text(encoding="utf-8").strip()
        if not named:
            return None
        path = pathlib.Path(named)
        return path if path.is_file() else None

    def inherited_identities(self):
        """The lane ids the inherited published ledger carries. A row that is
        one of these belongs to the home that published it."""
        source = self.inherit_source()
        if source is None:
            return set()
        _, published = read_ledger(source)
        return {row["lane_id"] for row in published if row.get("lane_id")}

    def sync_published(self, rows):
        """A row that came from the published ledger is owned by the home that
        published it, so that home stays the authority for it. A row this
        publisher wrote is owned by this home and is never touched here."""
        source = self.inherit_source()
        if source is None:
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

    def resolve_lane(self, lane_id):
        """(identity, meta) for the lane named by lane_id, or (None, None).

        A lane is named by its own id, or by a slot that runs it. A slot that
        names a task that is not registered here is an EMPTY slot: there is no
        lane behind it, so it resolves to nothing.
        """
        meta = read_meta(self.state, lane_id)
        if not meta:
            return None, None
        if is_secondmate(meta):
            return None, None
        identity = meta.get("endpoint_task_id") or lane_id
        if identity == lane_id:
            return identity, meta
        target = read_meta(self.state, identity)
        if not target or is_secondmate(target):
            return None, None
        return identity, target

    def register(self, lane_id, rows, header):
        """Write the row for one lane. The spawn record is the source of the
        lane's identity; the row carries the lane's real state."""
        meta = read_meta(self.state, lane_id)
        if not meta:
            self.say("FAIL %s has no spawn record in %s, so there is no lane to publish"
                     % (lane_id, self.state))
            return False
        if is_secondmate(meta):
            self.say("FAIL %s is a second mate, not a lane: it is not published as a lane claim"
                     % lane_id)
            return False
        identity = meta.get("endpoint_task_id") or lane_id
        if identity != lane_id:
            # A SLOT record naming a task: the lane is the task, and the task
            # must be registered here. An empty slot publishes nothing.
            target = read_meta(self.state, identity)
            if not target:
                self.say("FAIL %s is an empty slot: it names %s, which has no spawn record "
                         "of its own, so there is no lane to publish"
                         % (lane_id, identity))
                return False
            meta = target
        for row in rows:
            if row["lane_id"] in (lane_id, identity):
                self.say("%s already has a ledger row (state %s)" % (identity, row["state"]))
                return False
        alive, note = lane_state(self.state, identity, fallback_id=lane_id)
        if not alive:
            self.say("FAIL %s is not a live lane: its last wake event is terminal" % identity)
            return False
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
            cells[4] = claims_expiry_text(row.get("expires"))
            cells[6] = "**%s** - %s" % (row["state"], row.get("next") or "no next action recorded")
            add_claims_row(self.claims, cells)
            claims.add(row["lane_id"])
            added += 1
        if added:
            self.say("added %d claims row(s) for ledger rows that had none" % added)
        # and the state token AND the expiry of a claims row must agree with
        # the ledger: the drift checker refuses a board whose scope frees up
        # at a different instant than the ledger says.
        for row in rows:
            set_claims_state(self.claims, row["lane_id"], row["state"],
                             claims_expiry_text(row.get("expires")))
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

    # -- withdrawing and renewing a claim ---------------------------------

    def closed_next(self, row):
        """The note a closed lane carries. ONE shape, so a claim withdrawn by
        the teardown and a claim withdrawn by the catch-up read the same."""
        artifact = row.get("artifact") or ""
        if artifact:
            return ("closed - the lane finished; the follow-up is recorded in its "
                    "artifact %s" % artifact)
        return "closed - the lane finished; there is no follow-up recorded"

    def close_row(self, row, reason):
        """Move one row to DONE: the state, the empty expiry, the note and the
        updated stamp. The row is never deleted: a row is a record of work
        that happened."""
        row["state"] = "DONE"
        row["expires"] = ""
        row["updated"] = iso(now_utc())
        row["next"] = self.closed_next(row)
        close_claims_row(self.claims, row["lane_id"], "DONE")
        self.say("closed %s (state DONE, expiry empty): %s" % (row["lane_id"], reason))
        return True

    def teardown_witness(self, identity):
        """The durable record that a lane ended in THIS home, or None. The
        teardown copies the lane's own state into data/teardown-archives/
        <lane-id>/<date>/ before it removes the lane's spawn record."""
        archive = self.archives / identity
        if not archive.is_dir():
            return None
        stamps = sorted(p.parent.name for p in archive.glob("*/meta") if p.is_file())
        if not stamps:
            return None
        return "the teardown archive %s/%s records it" % (identity, stamps[-1])

    def close_ended_lanes(self, rows, live_identities):
        """Withdraw the claim of every lane that has ended.

        A row is closed when the lane it names is no longer REGISTERED in this
        home AND this home owns the claim.

        THE POSITIVE EVIDENCE that the lane ended is the lane's own spawn
        record being GONE. A lane is registered by state/<id>.meta, and the
        teardown is the only thing in the fleet that removes that record, so
        its absence is a FACT about the lane - never a guess. It is never the
        absence of a status line: a lane that has not posted a wake event yet
        has no status line either, and it is still running. A lane that still
        HAS its spawn record is never closed here, so a close can never hide
        work that is still running.

        A row this home does not own is never closed, and neither is a row
        inherited from the published ledger: that row belongs to the home
        that published it, and that home stays the authority for it.
        """
        inherited = self.inherited_identities()
        closed = 0
        for row in rows:
            if row["state"] != "ACTIVE":
                continue
            identity = row["lane_id"]
            if row.get("owner") != self.owner:
                continue
            if identity in inherited:
                continue
            if identity in live_identities:
                continue
            if (self.state / ("%s.meta" % identity)).is_file():
                # Still registered: the lane may be running. Never close it.
                continue
            witness = self.teardown_witness(identity)
            reason = ("its spawn record is gone" if witness is None
                      else "its spawn record is gone and %s" % witness)
            self.close_row(row, reason)
            closed += 1
        return closed

    def renew_row(self, row, note):
        """Renew the claim of a lane that is still alive.

        A claim that is still being worked must never lapse: the drift
        checker reads a lapsed ACTIVE claim as a violation, so the lease is
        pushed forward while the lane lives. The lease moves at most once a
        minute, so a publisher that runs every minute does not churn the
        ledger on every cycle.
        """
        target = now_utc() + dt.timedelta(hours=self.ttl)
        try:
            current = dt.datetime.strptime(row.get("expires") or "", "%Y-%m-%dT%H:%M:%SZ").replace(
                tzinfo=dt.timezone.utc)
        except (TypeError, ValueError):
            current = None
        if current is not None and target - current < dt.timedelta(seconds=60):
            return False
        row["updated"] = iso(now_utc())
        row["expires"] = iso(target)
        if note:
            row["next"] = note
        return True

    # -- the commands ------------------------------------------------------

    def reconcile(self):
        self.seed()
        header, rows = read_ledger(self.ledger)
        changed = self.sync_published(rows)
        live = live_lanes(self.state)
        live_identities = {identity for identity, _meta, _note in live}
        # Withdraw the claim of every lane that has ended. A lane that is
        # still alive is never closed here: its claim is renewed below.
        changed += self.close_ended_lanes(rows, live_identities)
        for identity, meta, note in live:
            row = None
            for candidate in rows:
                if candidate["lane_id"] == identity:
                    row = candidate
                    break
            if row is None:
                row = build_row(identity, meta, note, self.owner, self.ttl)
                rows.append(row)
                add_claims_row(self.claims, build_claims_cells(row, meta, self.repo))
                changed += 1
                self.say("published %s as ACTIVE (opened %s, expires %s)"
                         % (identity, row["opened"], row["expires"]))
                continue
            if row["state"] != "ACTIVE" or row.get("owner") != self.owner:
                continue
            if self.renew_row(row, note):
                changed += 1
                self.say("renewed the claim of %s (expires %s)" % (identity, row["expires"]))
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
        deleted: a row is a record of work that happened.

        --if-present makes "there is nothing to close" a success rather than a
        failure. The teardown uses it: a lane that never held a claim has
        nothing stale to withdraw, and that is not an error worth shouting
        about. A close that FAILS is still a failure, and it is still loud.
        """
        if not self.ledger.is_file():
            self.say("%s has no claim to close: there is no ledger at %s"
                     % (lane_id, self.ledger))
            return 0 if self.args.if_present else 1
        self.seed()
        header, rows = read_ledger(self.ledger)
        target = None
        for row in rows:
            if row["lane_id"] == lane_id:
                target = row
                break
        if target is None:
            self.say("%s has no ledger row, so there is nothing to close" % lane_id)
            return 0 if self.args.if_present else 1
        if target["state"] == "DONE":
            self.say("%s is already closed" % lane_id)
            return 0
        self.close_row(target, "it was closed on request")
        write_ledger(self.ledger, header, rows)
        self.republish()
        return 0

    def do_watch(self):
        """The spawn event, observed. Any lane that appears in this home's
        state/ and has no ledger row is published at once."""
        deadline = time.time() + self.args.timeout
        # The watch compares lane IDENTITIES (the endpoint task id the spawn
        # record carries), not the file name the record happens to live under.
        seen = {identity for identity, _meta, _note in live_lanes(self.state)}
        while time.time() < deadline:
            for identity, meta, note in live_lanes(self.state):
                if identity in seen:
                    continue
                seen.add(identity)
                self.say("a lane spawned: %s" % identity)
                self.do_register(identity)
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
    parser.add_argument("--if-present", action="store_true",
                        help="with close: a lane that holds no claim is not an error")
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
