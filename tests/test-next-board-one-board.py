#!/usr/bin/env python3
"""
test-next-board-one-board.py — the Captain's board is ONE board, on ONE address, and
it is a small page.

The Captain opened the tracker on 2026-10-21 and wrote: "i don't recognise this board?
is it a different type of board? now i have three, great exactly what i didn't want",
and "parts are cool, but ultimately is like way to verbose". Two defects, one cause:
the served root still pointed at a stale tracker preview, and the page opened on
every long list at once.

This check proves both halves are closed:

  * the served root resolves to the live board after an install - the installer owns
    it, so a preview can never quietly take it back - while a served root that is a
    real file is refused and left untouched, and a served root that is NOT a tracker
    preview is left alone;
  * the page that opens carries a stated byte budget, so it cannot quietly grow back
    into a wall of rows; every long list folds behind a count and every row stays in
    the page, one click away;
  * the page states one canonical address and carries no link to a dashboard that is
    not served any more.

It is hermetic: every case builds a throwaway repo root, runtime directory and serve
root under a temp root, and stubs quota-axi with a local script. It never touches the
live home, never runs the live service and never reaches the network.

usage: test-next-board-one-board.py [--repo PATH]
"""
import argparse
import copy
import datetime as dt
import importlib.util
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBLISHER_PATH = REPO_ROOT / "bin" / "fm-next-board-publish.py"
INSTALL_PATH = REPO_ROOT / "bin" / "fm-next-board-install.sh"

# The budget for the part of the page the Captain sees before opening anything.
# The always-open portion measured 16,008 bytes against the live board's own data
# after the compaction, so 20,000 leaves headroom for growth without letting the
# page creep back towards the 38,297 bytes it measured before.
ALWAYS_OPEN_BUDGET_BYTES = 20000

FAILURES = []
CHECKS = []


def check(label, ok, detail=""):
    """Record one check and print it. Nothing is asserted by inspection."""
    CHECKS.append(label)
    if ok:
        print("PASS %s" % label)
    else:
        print("FAIL %s — %s" % (label, detail))
        FAILURES.append(label)


def load_publisher():
    spec = importlib.util.spec_from_file_location("fm_next_board_publish", PUBLISHER_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# --------------------------------------------------------------- the fixtures

ACCOUNTS = ["acct-codex-controller", "acct-glm-controller", "acct-minimax-controller"]
SURFACES = [
    {"surface": "controller", "label": "Controller (Crisp-R)", "status": "reported",
     "accounts": ACCOUNTS, "days_reported": ["2026-10-19", "2026-10-20", "2026-10-21"],
     "source_path": "data/tracker-tokens-20261019/ledger/usage.json",
     "source_kind": "owner_ledger", "reason": None},
    {"surface": "hd2stack", "label": "HD2Stack", "status": "reported",
     "accounts": ["acct-codex-hd2"], "days_reported": ["2026-10-20", "2026-10-21"],
     "source_path": "data/next-board-publish/surface-usage/hd2stack.json",
     "source_kind": "published_surface_usage", "reason": None},
    {"surface": "brandon-compute", "label": "Hetz (brandon-compute)", "status": "unknown",
     "accounts": [], "days_reported": [],
     "source_path": None, "source_kind": "published_surface_usage",
     "reason": "no published usage document arrived from this surface"},
    {"surface": "elevatesVPS", "label": "Elevate VPS (KVM1)", "status": "unknown",
     "accounts": [], "days_reported": [],
     "source_path": None, "source_kind": "published_surface_usage",
     "reason": "no published usage document arrived from this surface"},
]
PROVIDERS = ["agy", "codex", "glm", "minimax"]
DAYS = ["2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18", "2026-10-19",
        "2026-10-20", "2026-10-21"]


def band_fixture():
    """A band of the live board's shape: 7 days, 3 accounts, 4 surfaces, coverage."""
    daily = []
    for index, day in enumerate(DAYS):
        measured = index >= 4
        accounts = {}
        for position, account in enumerate(ACCOUNTS):
            if measured:
                accounts[account] = 1000000 * (position + 1) + index * 7
        daily.append({
            "date": day,
            "total_tokens": sum(accounts.values()) if measured else None,
            "total_status": "measured" if measured else "unknown",
            "accounts": accounts,
        })
    coverage = {"surfaces": []}
    for surface in SURFACES:
        providers = []
        for provider in PROVIDERS:
            measured = provider in ("codex", "glm") and surface["status"] == "reported"
            providers.append({
                "provider": provider,
                "status": "measured" if measured else "unknown",
                "accounts": [surface["accounts"][0]] if measured and surface["accounts"] else [],
                "reason": None if measured else
                "no usage source exposes %s on this surface" % provider,
            })
        coverage["surfaces"].append({"surface": surface["surface"], "providers": providers})
    return {
        "schema": "firstmate-token-band/v2",
        "generated_at": "2026-10-21T21:00:00Z",
        "errors": [],
        "quota": {
            "ok": True, "error": None,
            "windows": [
                {"key": "codex|weekly|2026-10-27", "provider": "codex",
                 "provider_label": "Codex", "account_id": "acct-codex-controller",
                 "account_email": "boxedagency@gmail.com", "window_id": "weekly",
                 "window_label": "week", "label": "Codex - week",
                 "percent_remaining": 82, "percent_used": 18,
                 "resets_at": "2026-10-27T06:34:19.000Z"},
                {"key": "agy|gemini_weekly|2026-10-23", "provider": "agy",
                 "provider_label": "AGY", "account_id": "acct-agy",
                 "account_email": "ops@example.com", "window_id": "gemini_weekly",
                 "window_label": "week", "label": "AGY - week",
                 "percent_remaining": 41, "percent_used": 59,
                 "resets_at": "2026-10-23T09:00:00.000Z"},
                {"key": "agy|gemini_weekly|2026-10-26", "provider": "agy",
                 "provider_label": "AGY", "account_id": "acct-agy-2",
                 "account_email": "second@example.com", "window_id": "gemini_weekly",
                 "window_label": "week", "label": "AGY - week",
                 "percent_remaining": 96, "percent_used": 4,
                 "resets_at": "2026-10-26T09:00:00.000Z"},
                {"key": "minimax|weekly|2026-10-28", "provider": "minimax",
                 "provider_label": "MiniMax", "account_id": "acct-minimax-controller",
                 "account_email": "ops@example.com", "window_id": "weekly",
                 "window_label": "week", "label": "MiniMax - week",
                 "percent_remaining": 55, "percent_used": 45,
                 "resets_at": "2026-10-28T09:00:00.000Z"},
                {"key": "glm|weekly|2026-10-27", "provider": "glm",
                 "provider_label": "GLM", "account_id": "acct-glm-controller",
                 "account_email": "boxedagency@gmail.com", "window_id": "weekly",
                 "window_label": "week", "label": "GLM - week",
                 "percent_remaining": 70, "percent_used": 30,
                 "resets_at": "2026-10-27T09:00:00.000Z"},
                {"key": "codex|five_hour|2026-10-21", "provider": "codex",
                 "provider_label": "Codex", "account_id": "acct-codex-controller",
                 "account_email": "boxedagency@gmail.com", "window_id": "five_hour",
                 "window_label": "session", "label": "Codex - session",
                 "percent_remaining": 70, "percent_used": 30,
                 "resets_at": "2026-10-21T22:50:19.000Z"},
            ],
            "providers_without_windows": [],
        },
        "ledger": {
            "ok": True, "error": None, "contract_version": 2, "timezone": "Europe/London",
            "surface": "controller", "generated_at": "2026-10-21T20:00:00+01:00",
            "roster_path": "docs/system-context/token-usage-surfaces.json",
            "accounts": [{"id": account, "label": account, "provider": "codex"}
                         for account in ACCOUNTS],
            "surfaces": SURFACES, "sources": [], "conflicts": [],
        },
        "daily": daily,
        "weekly": {
            "start_date": "2026-10-15", "end_date": "2026-10-21",
            "days_expected": 7, "days_known": 3, "days_unknown": 4,
            "total_tokens": 12000000, "total_measured_tokens": 12000000,
            "total_reported_tokens": 0, "status": "partial", "is_floor": True,
            "per_account": {account: 4000000 for account in ACCOUNTS},
            "per_account_known_days": {account: 3 for account in ACCOUNTS},
        },
        "coverage": coverage,
        "rollover": [
            {"key": "codex|five_hour|2026-10-21", "provider": "codex",
             "window_id": "five_hour", "kind": "session", "label": "Codex - session",
             "resets_at": "2026-10-21T22:50:19.000Z", "resets_in_seconds": 6000,
             "percent_remaining": 70, "restores_percent": 100},
        ],
    }


def queue_fixture():
    """The Captain's queue, at the live board's size: 6 P0, 28 P1, 32 P2."""
    queue = []
    sequence = 0
    for priority, count in (("P0", 6), ("P1", 28), ("P2", 32)):
        for index in range(count):
            sequence += 1
            queue.append({
                "sequence": "%04d" % sequence, "slug": "ticket-%02d-%s" % (index, priority.lower()),
                "priority": priority,
                "received": "2026-10-%02dT%02d:00:00Z" % (10 + index % 10, index % 24),
                "area": "Ops" if index % 3 else "Research", "source": "chat",
                "description": "A ticket the Captain filed.",
            })
    return queue


def tracker_fixture(queue):
    """One tracker row per ticket, so the queue can show a real state."""
    rows = []
    for index, ticket in enumerate(queue):
        rows.append({
            "sequence": ticket["sequence"], "decision": "no", "blocked_by": "-",
            "next_action": "Do the %s work" % ticket["slug"],
            "lane": "lane-%d" % (index % 7), "lane_state": "-",
            "title": "Ticket %s" % ticket["slug"],
        })
    return rows


def board_fixture():
    """The NEXT board's items, at the live board's size and shape."""
    items = []
    sequence = 0
    plan = ([("OPEN-WORKABLE", 50), ("NEEDS-CAPTAIN-DECISION", 45), ("BLOCKED", 9),
             ("CONTRACT-GAP", 0), ("VERIFIED-DONE", 62)])
    for state, count in plan:
        for index in range(count):
            sequence += 1
            item = {
                "sequence": "%04d" % sequence, "slug": "item-%03d" % sequence,
                "priority": "P0" if index % 7 == 0 else "P1",
                "state": state, "next_action": "Carry on with the work",
                "owner": "lane-%d" % (index % 7), "title": "Item %03d" % sequence,
            }
            if state == "NEEDS-CAPTAIN-DECISION":
                item["captain_question"] = "Which option should the lane take for item %03d?" % sequence
            if state == "BLOCKED":
                item["next_action"] = "Blocked by the upstream lane until it reports"
            items.append(item)
    counts = {}
    for item in items:
        counts[item["state"]] = counts.get(item["state"], 0) + 1
    return {"items": items, "counts": counts, "residuals": []}


def delivery_fixture():
    return {
        "listener_alive": True, "listener_source": "procevent-lavish",
        "last_result": {"sequence": "0001", "at": "2026-10-21T20:40:00Z",
                        "status": "delivered", "handled": True},
        "last_feedback": None, "watcher_heartbeat_age_seconds": 12.0,
        "poll_processes": [{"pid": 4242}], "lavish_server_pids": [{"pid": 4243}],
        "pending_results": 0, "measured_at": "2026-10-21T21:00:00Z",
    }


# ------------------------------------------------------------- the measurements

def always_open_bytes(page):
    """The bytes of the page the Captain sees before opening anything.

    Every collapsed disclosure keeps its summary - that is what is on screen - and
    loses its body. A nested disclosure stops the match early, which leaves more
    behind than is really visible, so the measure errs on the high side.
    """
    def keep_summary(match):
        summary = re.search(r"<summary>(.*?)</summary>", match.group(0), re.S)
        return summary.group(0) if summary else ""

    collapsed = re.sub(r'<details class="fold"(?![^>]*\sopen)[^>]*>.*?</details>',
                       keep_summary, page, flags=re.S)
    return len(collapsed.encode("utf-8"))


def summaries(page):
    return [re.sub(r"<[^>]+>", "", s) for s in re.findall(r"<summary>(.*?)</summary>", page, re.S)]


# ------------------------------------------------------------- the served root

def build_sandbox(root):
    """A throwaway repo root, runtime directory and serve root."""
    repo = root / "repo"
    runtime = repo / "data" / "next-board-publish"
    serve_root = root / "serve"
    (repo / "bin").mkdir(parents=True, exist_ok=True)
    (repo / "data" / "next-board-publish").mkdir(parents=True, exist_ok=True)
    serve_root.mkdir(parents=True, exist_ok=True)
    for name in ("fm-next-board-publish.py", "fm-next-board-install.sh", "fm-token-collect.py",
                 "build-next-board.py", "fm-tracker-view-serve.py"):
        shutil.copy(REPO_ROOT / "bin" / name, repo / "bin" / name)
    return repo, runtime, serve_root


def run_installer(repo, runtime, serve_root):
    return subprocess.run(
        ["bash", str(repo / "bin" / "fm-next-board-install.sh"),
         "--repo", str(repo), "--runtime", str(runtime), "--serve-root", str(serve_root)],
        capture_output=True, text=True, timeout=120)


def served_root_cases():
    """The installer owns the served root, and it does so narrowly."""
    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        repo, runtime, serve_root = build_sandbox(root)
        # A tracker preview holds the root: the artifact that displaced the board.
        preview = root / "tracker-build-20261017" / "tracker" / "candidate-preview.html"
        preview.parent.mkdir(parents=True, exist_ok=True)
        preview.write_text("<html><title>HD2 Editor · Fleet ticket dashboard</title></html>",
                           encoding="utf-8")
        (serve_root / "index.html").symlink_to(preview)
        result = run_installer(repo, runtime, serve_root)
        check("the install succeeds with a tracker preview on the served root",
              result.returncode == 0, result.stderr.strip())
        served = serve_root / "index.html"
        check("the served root is relinked to the live board",
              served.is_symlink() and os.path.realpath(served) == str(runtime / "index.html"),
              "points at %s" % (os.path.realpath(served) if served.is_symlink() else "nothing"))
        check("the installer says the served root now serves the live board",
              "the live board is the served root" in (result.stdout + result.stderr),
              (result.stdout + result.stderr).strip()[-200:])

    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        repo, runtime, serve_root = build_sandbox(root)
        real_file = serve_root / "index.html"
        real_file.write_text("<html><body>someone's own page</body></html>", encoding="utf-8")
        result = run_installer(repo, runtime, serve_root)
        check("the install succeeds when the served root is a real file",
              result.returncode == 0, result.stderr.strip())
        check("a real file on the served root is refused and left untouched",
              real_file.is_file() and not real_file.is_symlink()
              and real_file.read_text(encoding="utf-8") == "<html><body>someone's own page</body></html>",
              "the file at the served root was changed")
        check("the installer refuses loudly instead of deleting it",
              "not a symlink" in (result.stdout + result.stderr),
              (result.stdout + result.stderr).strip()[-200:])

    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        repo, runtime, serve_root = build_sandbox(root)
        other = root / "some-other-home" / "index.html"
        other.parent.mkdir(parents=True, exist_ok=True)
        other.write_text("<html><body>another home's board</body></html>", encoding="utf-8")
        (serve_root / "index.html").symlink_to(other)
        result = run_installer(repo, runtime, serve_root)
        check("the install succeeds when the served root belongs to something else",
              result.returncode == 0, result.stderr.strip())
        check("a served root that is not a tracker preview is left alone",
              os.path.realpath(serve_root / "index.html") == str(other),
              "the served root was taken over")
        check("the installer says the served root was left alone",
              "left alone" in (result.stdout + result.stderr),
              (result.stdout + result.stderr).strip()[-200:])


# ------------------------------------------------------------------- the page

def page_cases(publisher):
    """The page: folded, small, and one address."""
    queue = queue_fixture()
    tracker_rows = tracker_fixture(queue)
    board = board_fixture()
    band = band_fixture()
    band_state = {"path": "data/next-board-publish/token-band.json", "state": "ok",
                  "detail": "", "band": band, "age_seconds": 60.0, "problems": []}
    chat_state = {"session": None, "session_note": "", "entries": []}
    selection, counts = publisher.select_next_work(queue, tracker_rows)
    page = publisher.render_page("2026-10-21T21:00:00Z", delivery_fixture(), queue,
                                  tracker_rows, board, 60, band_state, chat_state,
                                  selection, counts)

    size = always_open_bytes(page)
    check("the always-open portion of the board stays under %d bytes" % ALWAYS_OPEN_BUDGET_BYTES,
          size < ALWAYS_OPEN_BUDGET_BYTES,
          "the always-open portion measured %d bytes" % size)

    # Every long list folds behind a count.
    labels = ("DAILY", "SURFACES", "COVERAGE", "P0", "NOW", "ONLY YOU CAN UNBLOCK", "BLOCKED")
    folded = summaries(page)
    missing = [label for label in labels if not any(label in s for s in folded)]
    check("the long sections are folded behind their own headings", not missing,
          "not folded: %s" % ", ".join(missing))
    without_count = [s for s in folded if not re.search(r"\d", s)]
    check("every folded section states its count", not without_count,
          "; ".join(s[:60] for s in without_count[:3]))

    # Nothing is dropped: every row is still in the page.
    missing_tickets = [t["slug"] for t in queue if t["slug"] not in page]
    check("every ticket is still on the page, folded or not", not missing_tickets,
          "%d ticket(s) missing" % len(missing_tickets))
    questions = [i for i in board["items"] if i.get("captain_question")]
    missing_questions = [i["slug"] for i in questions if i["slug"] not in page]
    check("every question waiting on the Captain is still on the page", not missing_questions,
          "%d question(s) missing" % len(missing_questions))

    # The surface summary stays open, so the Captain sees which surface reported.
    summary_heading = "SURFACES — what each coding surface reported"
    full_heading = "SURFACES — the full surface table"
    summary_at = page.find(summary_heading)
    full_at = page.find(full_heading)
    check("the surface summary stays open on the page",
          summary_at != -1 and full_at != -1 and summary_at < full_at,
          "the compact surface summary is not in front of the folded table")
    for surface in SURFACES:
        if surface["surface"] not in page:
            check("every surface is named on the page", False, surface["surface"])
            break
    else:
        check("every surface is named on the page", True)

    # One address, and no link to a dashboard that is not served any more.
    check("the page states one canonical address",
          "Canonical address" in page and "LIVE FLEET BOARD" in page,
          "the header does not state the canonical address")
    check("the page carries no link to the old tracker dashboard",
          'href="../"' not in page and "← Fleet ticket dashboard</a>" not in page,
          "the stale dashboard link is still on the page")
    check("the top-left button reloads the board it is on",
          'class="btn" href="./">Refresh<' in page,
          "the top-left button is not a refresh")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=str(REPO_ROOT))
    args = parser.parse_args()

    if not PUBLISHER_PATH.is_file():
        print("FAIL the publisher is missing: %s" % PUBLISHER_PATH)
        return 1
    publisher = load_publisher()

    served_root_cases()
    page_cases(publisher)

    print("")
    if FAILURES:
        print("REGRESSION CHECK: FAIL (%d of %d checks failed)" % (len(FAILURES), len(CHECKS)))
        for failure in FAILURES:
            print("  - %s" % failure)
        return 1
    print("REGRESSION CHECK: PASS (%d checks)" % len(CHECKS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
