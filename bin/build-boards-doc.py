#!/usr/bin/env python3
"""Build docs/BOARDS.md — the map of every board in the fleet and how they differ.

The prose (what each board is FOR) is hand-written here. The machine facts
(size, tracked state, mtime, present?) are probed at build time, so the table
cannot go stale. Re-run it after adding or retiring a board.

  python3 bin/build-boards-doc.py \
      --probe-root /root/agent-work/deightonllm-firstmate \
      --out docs/BOARDS.md
"""
import argparse, datetime, os, subprocess, html

# path, display name, kind, audience, data source, live?, what it is for,
# and the difference that matters
BOARDS = [
    dict(path="unified-board.html", name="HD2 Fleet Unified Board & To-Do Tracker",
         kind="hand-maintained HTML", audience="the Captain (his working board)",
         source="hand-edited; status rows cite the docs that carry the truth",
         live="hand-maintained (no generator)",
         why="The Captain's own board. Header carries the host/model line, the 'Unified Synced' pill and the Snapshot Freshness meter; the body is a feature-and-ticket table with section pills.",
         diff="The only board the Captain edits by hand, so it holds his work and is never regenerated. Quota appears here as STATUS ROWS (e.g. 'Quota-axi 5-hour session primary display - delivered in QUOTA-ROUTING-RUBRIC.md'), not as live quota numbers or token meters - that is the gap the quota band fills."),
    dict(path=".lavish/CAPTAIN-BOARD.html", name="Captain's board (decision surface)",
         kind="generated HTML", audience="the Captain",
         source="bin/build-captain-board.py -> the lane ledger + INBOX/ tickets",
         live="generated from machine state",
         why="The decision surface. Ticket-0003 verbatim with the proposed window, three decision questions, the 42-ticket queue as a tracked batch, the decisions settled, the space job, and the live to-do list.",
         diff="The ONLY board with decision controls (a radio question queues one answer; a tracked batch queues a ticket set with a receipt contract). The only board that carries the to-do list straight from the lane ledger, and the only one that shows a ticket in full."),
    dict(path="next-signpost/NEXT-BOARD.md", name="NEXT board (machine to-do list)",
         kind="generated markdown", audience="agents + the Captain",
         source="bin/build-next-board.py -> the lane ledger, the tracker, the backlog",
         live="generated; carries the ledger digest",
         why="The substrate under the Captain's board: every item with a state, an owner and a next action, plus the drift section and the push ledger.",
         diff="Not HTML and not a dashboard - it is the TEXTUAL contract. It embeds '**Ledger digest:** sha256:...' so a reader can see the moment it stops matching the ledger. Published byte-identical to Controller, Hetzner and HD2Stack."),
    dict(path="data/tracker/fleet-dash.html", name="Fleet ticket dashboard (full)",
         kind="generated HTML", audience="operators",
         source="a host-side snapshot of the live ticket queue",
         live="snapshot",
         why="The busiest operator view: lane activity, tickets by priority, Hetz comms receipts and capacity.",
         diff="Operator-facing and snapshot-based. It shows lanes and tickets, not decisions and not token/quota meters."),
    dict(path="data/tracker/board.html", name="Firstmate Lane Tracker",
         kind="generated HTML", audience="operators",
         source="state/*.status, BOARD.md, CONTROLLER_STATE.md",
         live="snapshot",
         why="Lane counts, per-lane status, the board and controller state, and a ticket intake panel.",
         diff="The lane-state view: it answers 'which lane holds what', not 'what do I decide'."),
    dict(path="data/campaign-dashboard-20261015/board.html", name="Campaign Board 2026-10-15",
         kind="dated record + HTML view", audience="everyone (historical)",
         source="data/campaign-dashboard-20261015/board.md (56 rows)",
         live="frozen record",
         why="The dated campaign board, split into six areas: surface parity and trust, dispatch reliability and trust gates, communication and notification, Hetz/Brandon client work, staging/publication/retained Core work, and client archive and production safety.",
         diff="The ONLY surviving record of the 'KVM1 Herdr registration | HELD' row that ticket-0003 cites - and the STATUS.md it cites does not exist anywhere, so this board row is the authoritative text. Frozen history, never regenerated."),
    dict(path="data/hd2-takeover/board.html", name="HD2 Fleet Controller Board",
         kind="generated HTML", audience="the Controller",
         source="the controller queue + fleet state",
         live="snapshot",
         why="The Controller's own board: controller queue plus fleet board.",
         diff="Controller-facing. Not the Captain's surface and not a decision surface."),
    dict(path=".lavish/enforcement.html", name="Firstmate Enforcement Surface",
         kind="static HTML (2 copies)", audience="operators + the Captain",
         source="the enforcement rule set",
         live="static",
         why="What the fleet enforces: 11 rules enforced, 3 removed/inactive.",
         diff="Proves enforcement rather than tracking state. Two copies exist (.lavish/ and data/lavish/) - identical purpose, different homes."),
    dict(path=".lavish/LANE-TODO-DASH.html", name="Fleet ticket dashboard (snapshot copy)",
         kind="generated HTML", audience="operators",
         source="a host-side snapshot that does not exist on this host",
         live="STALE",
         why="A 2026-10-13 copy of the fleet dashboard. It reads a host snapshot that is not present here, so every lane renders as 'unknown' and the ticket table says 'No backlog tickets found'.",
         diff="This is the board that looks broken. It is kept, not deleted: it is the record of the older fleet-dashboard family and of the failure mode a board with no live data source has."),
    dict(path="index.html", name="Fleet ticket dashboard (repo entry point)",
         kind="generated HTML", audience="operators",
         source="the live backlog",
         live="snapshot",
         why="The tracked entry point of the same dashboard family.",
         diff="Same family as LANE-TODO-DASH and fleet-dash, but it is the one that is committed to the repo."),
]


def git_state(root, path):
    try:
        r = subprocess.run(["git", "-C", root, "check-ignore", "-q", path])
        if r.returncode == 0:
            return "ignored"
        r = subprocess.run(["git", "-C", root, "ls-files", "--error-unmatch", path],
                           capture_output=True)
        if r.returncode == 0:
            return "tracked"
        return "untracked"
    except Exception:
        return "unknown"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe-root", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    root = a.probe_root
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    rows = []
    detail = []
    for b in BOARDS:
        p = os.path.join(root, b["path"])
        present = os.path.exists(p)
        size = os.path.getsize(p) if present else 0
        mtime = (datetime.datetime.fromtimestamp(os.path.getmtime(p), datetime.timezone.utc)
                 .strftime("%Y-%m-%d %H:%M") if present else "-")
        state = git_state(root, b["path"]) if present else "absent"
        rows.append((b, present, size, mtime, state))
        detail.append((b, present, size, mtime, state))

    out = []
    out.append("# Boards — every board in the fleet, and how they differ\n")
    out.append("**Nothing here is deleted.** Boards overlap on purpose: some are "
               "historical records, some are operator views, one is the Captain's own "
               "working board. This map says which one answers which question, so a "
               "board is never mistaken for another one.\n")
    out.append(f"**Generated:** {now} by `bin/build-boards-doc.py` "
               f"(machine facts probed live from `{root}`; the prose is written by hand). "
               "Re-run the script after adding or retiring a board.\n")
    out.append("## The one-line map\n")
    out.append("| Board | Kind | Audience | Live? | Size | In git |")
    out.append("|---|---|---|---|---|---|")
    for b, present, size, mtime, state in rows:
        out.append(f"| `{b['path']}` | {b['kind']} | {b['audience']} | "
                   f"{'yes' if b['live'].startswith('generated') or b['live']=='snapshot' else b['live']} | "
                   f"{size:,} B | {state} |")
    out.append("\n## The differences that matter\n")
    out.append("**1. Where the data comes from.** Two boards are generated from the machine "
               "lane ledger (`ops/lane-ledger.tsv`) and cannot drift from it — the NEXT board "
               "and the Captain's board. The dashboards are generated from a host-side "
               "snapshot and are only as fresh as that snapshot. `unified-board.html` is "
               "hand-edited, which is why it is the Captain's and why nothing regenerates it.\n")
    out.append("**2. What they can do.** Only the Captain's board can *ask* you something: a "
               "radio question queues exactly one answer, and a ticket batch queues a set with "
               "a receipt contract that must account for every ticket number. Every other "
               "board is read-only.\n")
    out.append("**3. What they are for.** The campaign board is a frozen record (it is the "
               "only surviving text for the row ticket-0003 cites). The enforcement surface "
               "proves what the fleet enforces. The dashboards show lanes, tickets and "
               "capacity. The unified board is your working surface. The NEXT board is the "
               "textual contract the others project from.\n")
    out.append("**4. Where quota and token use belongs.** Today quota appears on the unified "
               "board as *status rows* about quota work, not as live numbers, and token use is "
               "not shown at all — that is the accuracy and design gap being closed in "
               "`fm/quota-board-20261021`.\n")
    out.append("## Board by board\n")
    for b, present, size, mtime, state in detail:
        out.append(f"### `{b['path']}`\n")
        out.append(f"- **Name:** {b['name']}")
        out.append(f"- **Kind:** {b['kind']}")
        out.append(f"- **Audience:** {b['audience']}")
        out.append(f"- **Data source:** {b['source']}")
        out.append(f"- **Live:** {b['live']}")
        out.append(f"- **Present in the working checkout:** {'yes' if present else 'no'} · "
                   f"{size:,} B · last modified {mtime} · git state: **{state}**")
        out.append(f"- **What it is for:** {b['why']}")
        out.append(f"- **How it differs:** {b['diff']}\n")
    out.append("## The rule\n")
    out.append("A board is retired by being **documented as superseded here**, never by "
               "being deleted. `LANE-TODO-DASH.html` is the example: it renders as broken "
               "because its data source is gone, and it stays in the tree as the record of "
               "that failure mode.\n")

    text = "\n".join(out)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"wrote {a.out} ({len(text)} bytes, {len(BOARDS)} boards)")


if __name__ == "__main__":
    main()
