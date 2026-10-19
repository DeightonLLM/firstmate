#!/usr/bin/env python3
"""Stage C — daily binding / persistence contract for the staged tracker updater.

Executable behaviour only. Every case runs the REAL ``usage_check.sh`` body as a
subprocess against a throwaway sandbox (temporary state dir, temporary ledger
store, temporary candidate page). Nothing here points at, reads or writes the
canonical candidate, the Controller ledger store, or any live check body.

Contract under test (from the charter):
  * "archive idempotently from safe usage sources and bind current canonical UI
    rather than clobbering it"
  * "Preserve last-good data on errors, explicit freshness/unknown coverage"
  * "No claim of automatic capture without actual scheduled-execution receipt"
  * unknown stays ``null`` and never becomes ``0``

Usage:  python3 tests/test_tracker_daily_binding.py -v
"""
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SYSTEM = os.path.dirname(HERE)

# The updater under test. ``UPDATER`` is overridable so the identical suite can be
# pointed at the SHA-pinned ORIGINAL bytes for RED evidence.
UPDATER = os.environ.get("FM_STAGED_UPDATER", os.path.join(SYSTEM, "integration", "usage_check.sh"))
# The binder under test, overridable for the same reason.
BINDER = os.environ.get("FM_STAGED_BINDER", os.path.join(SYSTEM, "integration", "bind_usage_snapshot.py"))
# Optional: the real Controller collector, used by exactly one end-to-end case.
REAL_COLLECTOR = os.environ.get(
    "FM_STAGED_REAL_COLLECTOR",
    "/root/agent-work/deightonllm-firstmate/data/tracker-tokens-20261019/ledger/usage_ledger.py",
)


def minimal_page(snapshot=None):
    """Stand-in candidate page carrying the real snapshot assignment shape."""
    literal = "window.__USAGE_SNAPSHOT__ = {\"version\":1};\n" if snapshot is None else (
        "window.__USAGE_SNAPSHOT__ = %s;\n" % json.dumps(snapshot, sort_keys=True)
    )
    return (
        "<!doctype html>\n<html><head><title>t</title></head><body>\n"
        '<div id="logo">keep me</div>\n'
        + literal
        + "/* USAGE_CORE_BEGIN */\nwindow.TrackerUsage={};\n/* USAGE_CORE_END */\n"
        "window.TrackerUsage.bindUsageSnapshot(window.__USAGE_SNAPSHOT__);\n"
        "</body></html>\n"
    )


def ledger_snapshot(days, accounts=None):
    return {
        "version": 1,
        "contract_version": 1,
        "timezone": "Europe/London",
        "generated_at": "2026-10-19T00:00:00+01:00",
        "created_at": "2026-10-13T00:00:00+01:00",
        "days": days,
        "accounts": accounts or [],
        "sources": [],
        "seeds": [],
        "surface": {},
    }


def day(date, total, status, accounts=None):
    return {"date": date, "total_tokens": total, "total_status": status, "accounts": accounts or []}


def read_snapshot(page_path):
    """Extract the bound snapshot from a page exactly as the binder wrote it."""
    with open(page_path, encoding="utf-8") as fh:
        text = fh.read()
    marker = "window.__USAGE_SNAPSHOT__"
    idx = text.index(marker)
    start = text.index("{", idx)
    depth = 0
    in_str = False
    esc = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    raw = text[start:i + 1]
                    return json.loads(
                        raw.replace("\\u003c", "<").replace("\\u003e", ">").replace("\\u0026", "&")
                    )
    raise AssertionError("unterminated snapshot literal")


STUB = '''#!/usr/bin/env python3
"""Deterministic collector stand-in: emits exactly the fixture snapshot."""
import json, os, sys

args = sys.argv[1:]
store = args[args.index("--store") + 1] if "--store" in args else None
out = args[args.index("--out") + 1] if "--out" in args else None
snap = json.load(open(os.environ["FM_STUB_SNAPSHOT"]))
if out:
    json.dump(snap, open(out, "w"))
if store:
    os.makedirs(os.path.dirname(store), exist_ok=True)
    json.dump(snap, open(store, "w"))
'''

SLOW_STUB = '''#!/usr/bin/env python3
import sys, time
time.sleep(float(sys.argv[0] and 600))
'''

BAD_EXPORT_STUB = '''#!/usr/bin/env python3
"""Collector stand-in that completes but exports an unreadable snapshot."""
import os, sys

args = sys.argv[1:]
out = args[args.index("--out") + 1] if "--out" in args else None
if out:
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w").write("{ this is not a contract-v1 snapshot")
'''


class Sandbox:
    """A disposable state dir + ledger dir + candidate page for one check body."""

    def __init__(self, root, collector, days, throttle="300", collect_timeout="20", bind_timeout="20",
                 extra_snapshot=None):
        self.root = root
        self.state = os.path.join(root, "state")
        self.data = os.path.join(root, "data")
        self.ledger = os.path.join(root, "ledger")
        self.bin = os.path.join(root, "bin")
        os.makedirs(os.path.join(self.state), exist_ok=True)
        os.makedirs(self.data, exist_ok=True)
        os.makedirs(os.path.join(self.ledger, "data"), exist_ok=True)
        os.makedirs(self.bin, exist_ok=True)
        self.candidate = os.path.join(self.data, "candidate-preview.html")
        self.ledger_json = os.path.join(self.ledger, "usage.json")
        self.store = os.path.join(self.ledger, "data", "ledger.json")
        self.last_run = os.path.join(self.state, ".tracker-usage.last-run")
        self.last_ok = os.path.join(self.state, ".tracker-dashboard.last-ok")
        self.stale = os.path.join(self.state, ".tracker-dashboard.stale")
        with open(self.candidate, "w", encoding="utf-8") as fh:
            fh.write(minimal_page())
        snap = extra_snapshot or ledger_snapshot(days)
        with open(self.ledger_json, "w", encoding="utf-8") as fh:
            json.dump(snap, fh)
        with open(self.store, "w", encoding="utf-8") as fh:
            json.dump(snap, fh)
        self.snapshot_path = os.path.join(root, "stub-snapshot.json")
        with open(self.snapshot_path, "w", encoding="utf-8") as fh:
            json.dump(snap, fh)
        self.collector = collector
        if collector == "stub":
            self.collector_path = os.path.join(self.bin, "usage_ledger.py")
            with open(self.collector_path, "w", encoding="utf-8") as fh:
                fh.write(STUB)
        elif collector == "slow":
            self.collector_path = os.path.join(self.bin, "usage_ledger.py")
            with open(self.collector_path, "w", encoding="utf-8") as fh:
                fh.write(SLOW_STUB)
        elif collector == "bad-export":
            self.collector_path = os.path.join(self.bin, "usage_ledger.py")
            with open(self.collector_path, "w", encoding="utf-8") as fh:
                fh.write(BAD_EXPORT_STUB)
        elif collector == "real":
            self.collector_path = REAL_COLLECTOR
        elif collector == "missing":
            self.collector_path = os.path.join(self.bin, "does-not-exist.py")
        else:
            self.collector_path = collector
        self.env = dict(os.environ)
        self.env.update({
            "FM_USAGE_STATE_DIR": self.state,
            "FM_USAGE_LEDGER_DIR": self.ledger,
            "FM_USAGE_LEDGER": self.ledger_json,
            "FM_USAGE_STORE": self.store,
            "FM_USAGE_CANDIDATE": self.candidate,
            "FM_USAGE_COLLECTOR": self.collector_path,
            "FM_USAGE_BINDER": BINDER,
            "FM_USAGE_THROTTLE": throttle,
            "FM_USAGE_COLLECT_TIMEOUT": collect_timeout,
            "FM_USAGE_BIND_TIMEOUT": bind_timeout,
            "FM_STUB_SNAPSHOT": self.snapshot_path,
        })

    def run(self, timeout=120, expect_rc=0):
        proc = subprocess.run(["bash", UPDATER], env=self.env, capture_output=True, text=True, timeout=timeout)
        if expect_rc is not None and proc.returncode != expect_rc:
            raise AssertionError("updater rc=%d stdout=%r stderr=%r" % (proc.returncode, proc.stdout, proc.stderr))
        return proc

    def bad_export_collector(self):
        path = os.path.join(self.bin, "bad_export_ledger.py")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(BAD_EXPORT_STUB)
        return path

    def set_snapshot(self, days):
        snap = ledger_snapshot(days)
        with open(self.snapshot_path, "w", encoding="utf-8") as fh:
            json.dump(snap, fh)
        return snap

    def stat(self):
        st = os.stat(self.candidate)
        return (st.st_ino, st.st_mtime_ns, st.st_size)

    def bytes_sha(self):
        import hashlib
        with open(self.candidate, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()

    def clear_throttle(self):
        try:
            os.unlink(self.last_run)
        except FileNotFoundError:
            pass


DAY_HISTORY = [
    day("2026-10-17", 5014524, "measured", [{"account_id": "a", "source_kind": "measured", "total_tokens": 5014524}]),
    day("2026-10-18", 25749837, "partial", [{"account_id": "b", "source_kind": "measured", "total_tokens": 25749837}]),
]
DAY_UNKNOWN = day("2026-10-18", None, "unknown")
DAY_REPORTED = day("2026-10-19", 287560000, "partial", [
    {"account_id": "minimax-account-1", "source_kind": "operator_reported", "total_tokens": 281720000,
     "source_id": "seed-20261019-minimax-account-1", "observed_at": "2026-10-19T09:00:00+01:00"},
    {"account_id": "minimax-account-2", "source_kind": "operator_reported", "total_tokens": 5840000,
     "source_id": "seed-20261019-minimax-account-2", "observed_at": "2026-10-19T09:00:00+01:00"},
])


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="fm-daily-bind.")
        self.addCleanup(shutil.rmtree, self.tmp, True)

    @staticmethod
    def read_bytes(path):
        with open(path, "rb") as fh:
            return fh.read()

    @staticmethod
    def read_text(path):
        with open(path, encoding="utf-8") as fh:
            return fh.read()


class T01IdempotentArchiveIsNotAClobber(Base):
    """'archive idempotently ... rather than clobbering it' — an unchanged ledger
    must leave the already-bound page byte-, inode- and mtime-identical."""

    def test_unchanged_ledger_leaves_the_bound_page_completely_untouched(self):
        box = Sandbox(self.tmp, "stub", DAY_HISTORY)
        first = box.run()
        self.assertIn("REFRESHED", first.stdout, first.stdout + first.stderr)
        after_first = box.stat()
        sha_first = box.bytes_sha()
        self.assertEqual(read_snapshot(box.candidate)["days"][0]["date"], "2026-10-17")

        box.clear_throttle()
        second = box.run()
        self.assertIn("REFRESHED", second.stdout, second.stdout + second.stderr)
        self.assertEqual(
            box.bytes_sha(), sha_first,
            "unchanged ledger produced different bound bytes",
        )
        self.assertEqual(
            box.stat(), after_first,
            "unchanged ledger clobbered the bound page (inode/mtime changed): %r -> %r" % (after_first, box.stat()),
        )

    def test_changed_ledger_does_rebind_and_preserves_page_surroundings(self):
        box = Sandbox(self.tmp, "stub", DAY_HISTORY)
        box.run()
        self.assertIn(b"keep me", self.read_bytes(box.candidate))
        box.clear_throttle()
        box.set_snapshot(DAY_HISTORY + [DAY_REPORTED])
        proc = box.run()
        self.assertIn("REFRESHED", proc.stdout)
        snap = read_snapshot(box.candidate)
        self.assertEqual([d["date"] for d in snap["days"]], ["2026-10-17", "2026-10-18", "2026-10-19"])
        self.assertEqual(snap["days"][2]["total_tokens"], 287560000)
        self.assertIn(b"keep me", self.read_bytes(box.candidate))


class T02DurableHistoryAndNullSemantics(Base):
    """Day rollover must add the new day without dropping prior history, and
    unknown must stay ``null`` — never ``0``."""

    def test_rollover_adds_the_new_day_and_keeps_every_prior_day(self):
        box = Sandbox(self.tmp, "stub", DAY_HISTORY)
        box.run()
        box.clear_throttle()
        box.set_snapshot(DAY_HISTORY + [DAY_REPORTED])
        box.run()
        first_dates = [d["date"] for d in read_snapshot(box.candidate)["days"]]

        box.clear_throttle()
        box.set_snapshot(DAY_HISTORY + [DAY_REPORTED, day("2026-10-20", 12345, "measured")])
        box.run()
        snap = read_snapshot(box.candidate)
        self.assertEqual([d["date"] for d in snap["days"]], first_dates + ["2026-10-20"])
        self.assertEqual(snap["days"][-1]["total_tokens"], 12345)
        self.assertEqual(snap["version"], 1)
        self.assertEqual(snap["timezone"], "Europe/London")

    def test_unknown_day_binds_as_null_and_never_as_zero(self):
        box = Sandbox(self.tmp, "stub", [DAY_UNKNOWN])
        box.run()
        bound = read_snapshot(box.candidate)["days"][0]
        self.assertIsNone(bound["total_tokens"], "unknown day bound as a number")
        self.assertEqual(bound["total_status"], "unknown")

    def test_measured_zero_is_preserved_as_zero(self):
        box = Sandbox(self.tmp, "stub", [day("2026-10-14", 0, "measured")])
        box.run()
        bound = read_snapshot(box.candidate)["days"][0]
        self.assertEqual(bound["total_tokens"], 0)
        self.assertIsNotNone(bound["total_tokens"])

    def test_reported_seed_is_not_replayed_onto_a_later_day(self):
        leaked = dict(DAY_REPORTED)
        leaked["date"] = "2026-10-20"
        box = Sandbox(self.tmp, "stub", [leaked])
        proc = box.run()
        self.assertIn("REFRESHED", proc.stdout)
        bound = read_snapshot(box.candidate)["days"][0]
        self.assertEqual(bound["accounts"], [], "stale operator seed was replayed onto a later day")
        self.assertIsNone(bound["total_tokens"])


class T03LastGoodRetention(Base):
    """Any failure keeps the previously bound page byte-identical and signals."""

    def test_failed_collect_retains_last_good_and_signals_stale(self):
        box = Sandbox(self.tmp, "stub", DAY_HISTORY)
        box.run()
        good_sha = box.bytes_sha()
        good_stat = box.stat()
        good_ok = self.read_text(box.last_ok)

        box.clear_throttle()
        box.env["FM_USAGE_COLLECTOR"] = os.path.join(self.tmp, "bin", "does-not-exist.py")
        proc = box.run()
        self.assertTrue(proc.stdout.startswith("STALE "), proc.stdout)
        self.assertIn("collector missing", proc.stdout)
        self.assertEqual(box.bytes_sha(), good_sha, "last-good page changed on failure")
        self.assertEqual(box.stat(), good_stat, "last-good page was clobbered on failure")
        self.assertEqual(self.read_text(box.last_ok), good_ok,
                         "last-ok advanced despite a failed archive")
        self.assertTrue(os.path.exists(box.stale))
        with open(box.stale, encoding="utf-8") as fh:
            self.assertIn("collector missing", fh.read())

    def test_unreadable_export_retains_last_good_and_signals_stale(self):
        box = Sandbox(self.tmp, "stub", DAY_HISTORY)
        box.run()
        good_sha = box.bytes_sha()
        good_stat = box.stat()
        box.clear_throttle()
        # The collector runs and "succeeds" but exports a corrupt snapshot: the
        # binder must fail closed and the previously bound page must survive.
        box.env["FM_USAGE_COLLECTOR"] = box.bad_export_collector()
        proc = box.run()
        self.assertTrue(proc.stdout.startswith("STALE "), proc.stdout)
        self.assertEqual(box.bytes_sha(), good_sha, "corrupt export changed the last-good page")
        self.assertEqual(box.stat(), good_stat, "corrupt export clobbered the last-good page")

    def test_missing_binder_retains_last_good_and_signals_stale(self):
        box = Sandbox(self.tmp, "stub", DAY_HISTORY)
        box.run()
        good_sha = box.bytes_sha()
        box.clear_throttle()
        box.env["FM_USAGE_BINDER"] = os.path.join(self.tmp, "bin", "no-binder.py")
        proc = box.run()
        self.assertTrue(proc.stdout.startswith("STALE "), proc.stdout)
        self.assertIn("binder missing", proc.stdout)
        self.assertEqual(box.bytes_sha(), good_sha)


class T04ThrottleStampsCompletedWorkNotAnAttempt(Base):
    """``.tracker-usage.last-run`` must attest a COMPLETED run.

    An attempt that is interrupted (the watcher stops the check, the host is
    restarted, the process is killed) performs no archival and emits no signal.
    Stamping the throttle before the work makes the next poll silently skip for
    the whole window, which is how a timed-out daily binding disappears with no
    evidence at all.
    """

    def test_interrupted_run_leaves_no_throttle_stamp(self):
        box = Sandbox(self.tmp, "slow", DAY_HISTORY, collect_timeout="300")
        proc = subprocess.Popen(["bash", UPDATER], env=box.env, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True)
        # Wait until the body has definitely started the (sleeping) collector.
        deadline = time.time() + 30
        while time.time() < deadline and not os.path.exists(box.last_run):
            if proc.poll() is not None:
                break
            time.sleep(0.05)
        self.assertIsNone(proc.poll(), "updater exited before it could be interrupted")
        proc.send_signal(signal.SIGTERM)
        proc.communicate(timeout=30)
        self.assertFalse(
            os.path.exists(box.last_run),
            "interrupted run stamped the throttle: an archive that never completed is "
            "attested as a completed run, so the next poll silently skips it",
        )

    def test_next_poll_after_an_interrupted_run_actually_runs_and_signals(self):
        box = Sandbox(self.tmp, "slow", DAY_HISTORY, collect_timeout="300")
        proc = subprocess.Popen(["bash", UPDATER], env=box.env, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True)
        time.sleep(1.5)
        proc.send_signal(signal.SIGTERM)
        proc.communicate(timeout=30)
        # Operator / next watcher poll, immediately, with a short timeout.
        box.env["FM_USAGE_COLLECT_TIMEOUT"] = "2"
        box.env["FM_USAGE_BIND_TIMEOUT"] = "2"
        try:
            os.unlink(box.last_run)
        except FileNotFoundError:
            pass
        follow = box.run()
        self.assertTrue(
            follow.stdout.strip() != "",
            "the poll after an interrupted run produced no signal at all: the daily "
            "archive silently stopped (stdout=%r stderr=%r)" % (follow.stdout, follow.stderr),
        )

    def test_a_completed_run_does_stamp_the_throttle_and_the_next_poll_is_silent(self):
        box = Sandbox(self.tmp, "stub", DAY_HISTORY)
        first = box.run()
        self.assertIn("REFRESHED", first.stdout)
        self.assertTrue(os.path.exists(box.last_run), "a completed run must stamp the throttle")
        second = box.run()
        self.assertEqual(second.stdout, "", "throttled poll must stay silent")
        self.assertEqual(second.stderr, "")

    def test_a_completed_failure_stamps_the_throttle_so_polls_stay_quiet(self):
        box = Sandbox(self.tmp, "missing", DAY_HISTORY)
        first = box.run()
        self.assertTrue(first.stdout.startswith("STALE "), first.stdout)
        self.assertTrue(os.path.exists(box.last_run), "a completed STALE must stamp the throttle")
        second = box.run()
        self.assertEqual(second.stdout, "", "throttled poll after a completed STALE must stay silent")


class T05EndToEndRealCollector(Base):
    """One real-collector case: the staged body drives the ACTUAL CLI contract
    over the real read-only session roots, into a throwaway store."""

    @unittest.skipUnless(os.path.isfile(REAL_COLLECTOR), "real Controller collector not present")
    def test_real_collector_collect_export_bind_round_trip(self):
        box = Sandbox(self.tmp, "real", DAY_HISTORY, collect_timeout="180")
        proc = box.run(timeout=300)
        self.assertIn("REFRESHED", proc.stdout, proc.stdout + proc.stderr)
        snap = read_snapshot(box.candidate)
        self.assertEqual(snap["version"], 1)
        self.assertEqual(snap["timezone"], "Europe/London")
        self.assertTrue(snap["days"], "real collector produced no days")
        with open(box.store, encoding="utf-8") as fh:
            store = json.load(fh)
        self.assertEqual(store["version"], 1)
        self.assertIn("contract_version", store)
        for d in snap["days"]:
            if d["total_status"] == "unknown":
                self.assertIsNone(d["total_tokens"], "unknown day bound as a number: %r" % d)


if __name__ == "__main__":
    unittest.main(verbosity=2)