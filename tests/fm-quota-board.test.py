#!/usr/bin/env python3
"""Accuracy tests for the HD2 quota + aggregate token-use band.

These tests pin the ledger's own contract, not the band's cosmetics:

  * null is not zero - an unknown value stays null and is labelled;
  * unknown stays unknown and is never fabricated into a number;
  * two accounts of the same provider stay distinct accounts;
  * official operator-reported totals supersede overlapping local subsets, and
    local subsets are exposed as unmapped detail, never added on top;
  * surfaces are partitioned per host, so two hosts never overwrite each other
    and one official total carried by two hosts is counted once;
  * a corrupt ledger is refused, never silently reset;
  * a missing snapshot degrades to an explicit "not collected" state, never a
    fake zero;
  * the board keeps every element it had before the band was inserted.

Run:
    python3 tests/fm-quota-board.test.py
"""
from __future__ import annotations

import importlib.util
import json
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
COLLECTOR_PATH = REPO_ROOT / "bin" / "fm-quota-board-snapshot.py"
BINDER_PATH = REPO_ROOT / "bin" / "fm-quota-board-bind.py"
BOARD_PATH = REPO_ROOT / "unified-board.html"
SNAPSHOT_PATH = REPO_ROOT / "data" / "hd2-takeover" / "quota-board-snapshot.json"

SPEC = importlib.util.spec_from_file_location("fm_quota_board_snapshot", COLLECTOR_PATH)
COLLECTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COLLECTOR)

BINDER_SPEC = importlib.util.spec_from_file_location("fm_quota_board_bind", BINDER_PATH)
BINDER = importlib.util.module_from_spec(BINDER_SPEC)
BINDER_SPEC.loader.exec_module(BINDER)


# --------------------------------------------------------------------------
# fixtures - two surfaces, one official seed carried by both, one local
# subset that the official total supersedes.
# --------------------------------------------------------------------------

FIXTURE_QUOTA = {
    "schemaVersion": 5,
    "generatedAt": "2026-10-21T00:00:00.000Z",
    "providers": [
        {
            "provider": "codex",
            "label": "Codex",
            "accountKeys": ["codex-home", "openai-codex"],
            "state": {"status": "fresh", "stale": False, "error": None},
            "windows": [
                {
                    "id": "five_hour",
                    "label": "session",
                    "kind": "session",
                    "percentRemaining": 71,
                    "resetsAt": "2026-10-21T06:50:19.000Z",
                    "pace": {"status": "behind"},
                },
                {
                    "id": "weekly",
                    "label": "week",
                    "kind": "weekly",
                    "percentRemaining": 82,
                    "resetsAt": "2026-10-27T06:34:19.000Z",
                    "pace": {"status": "ahead"},
                },
            ],
        },
        {
            "provider": "agy",
            "label": "Antigravity",
            "accountKeys": ["default"],
            "state": {"status": "fresh", "stale": False, "error": None},
            "windows": [
                {
                    "id": "gemini_5h",
                    "label": "Gemini 5-hour",
                    "kind": "session",
                    "percentRemaining": 100,
                    "resetsAt": "2026-10-21T04:51:18.000Z",
                    "pace": {"status": "behind"},
                },
                {
                    "id": "claude_gpt_weekly",
                    "label": "Claude/GPT weekly",
                    "kind": "weekly",
                    "percentRemaining": 18,
                    "resetsAt": "2026-10-26T21:49:44.000Z",
                    "pace": {"status": "ahead"},
                },
            ],
        },
        {
            "provider": "minimax",
            "label": "MiniMax",
            "accountKeys": ["default"],
            "state": {"status": "fresh", "stale": False, "error": None},
            "windows": [
                {
                    "id": "model:general:5h",
                    "label": "general 5h",
                    "kind": "model",
                    "percentRemaining": 99,
                    "resetsAt": "2026-10-21T05:00:00.000Z",
                    "pace": {"status": "behind"},
                }
            ],
        },
        {
            "provider": "zai",
            "label": "Z.AI",
            "accountKeys": ["default"],
            "state": {"status": "fresh", "stale": False, "error": None},
            "windows": [
                {
                    "id": "five_hour",
                    "label": "session",
                    "kind": "session",
                    "percentRemaining": 99,
                    "resetsAt": "2026-10-21T07:00:21.000Z",
                    "pace": {"status": "behind"},
                }
            ],
        },
        {
            "provider": "claude",
            "label": "Claude",
            "accountKeys": ["default"],
            "notSetUp": True,
            "state": {"status": "auth_required", "stale": False, "error": "credentials_missing"},
            "windows": [],
        },
    ],
}

FIXTURE_LEDGER_A = {
    "version": 1,
    "contract_version": 1,
    "generated_at": "2026-10-21T00:00:00+01:00",
    "timezone": "Europe/London",
    "surface": "host-a",
    "accounts": [
        {"id": "codex-local-unmapped", "provider": "codex", "identity_status": "unknown_local_subset"},
        {"id": "minimax-account-1", "provider": "minimax", "identity_status": "operator_alias"},
        {"id": "minimax-local-unmapped", "provider": "minimax", "identity_status": "unknown_local_subset"},
    ],
    "days": [
        {
            "date": "2026-10-01",
            "total_tokens": None,
            "total_status": "unknown",
            "missing_sources": ["codex"],
            "accounts": [],
            "providers": [],
            "unmapped": [],
        },
        {
            "date": "2026-10-02",
            "total_tokens": None,
            "total_status": "unknown",
            "missing_sources": [],
            "accounts": [
                {
                    "account_id": "codex-local-unmapped",
                    "provider": "codex",
                    "total_tokens": None,
                    "coverage": "local_metadata",
                    "source_id": "host-a:codex",
                    "source_kind": "local_metadata",
                    "surface": "host-a",
                }
            ],
            "providers": [],
            "unmapped": [],
        },
        {
            "date": "2026-10-03",
            "total_tokens": 40,
            "total_status": "partial",
            "missing_sources": [],
            "accounts": [
                {
                    "account_id": "codex-local-unmapped",
                    "provider": "codex",
                    "total_tokens": 40,
                    "coverage": "local_metadata",
                    "source_id": "host-a:codex",
                    "source_kind": "local_metadata",
                    "surface": "host-a",
                },
                {
                    "account_id": "minimax-account-1",
                    "provider": "minimax",
                    "total_tokens": 90,
                    "coverage": "reported",
                    "source_id": "captain-seed",
                    "source_kind": "operator_reported",
                    "surface": "host-a",
                },
            ],
            "providers": [],
            "unmapped": [],
        },
    ],
    "seeds": [],
    "sources": [],
}

FIXTURE_LEDGER_B = {
    "version": 1,
    "contract_version": 1,
    "generated_at": "2026-10-21T00:00:00+01:00",
    "timezone": "Europe/London",
    "surface": "host-b",
    "accounts": [
        {"id": "codex-local-unmapped", "provider": "codex", "identity_status": "unknown_local_subset"},
        {"id": "minimax-account-1", "provider": "minimax", "identity_status": "operator_alias"},
        {"id": "minimax-local-unmapped", "provider": "minimax", "identity_status": "unknown_local_subset"},
    ],
    "days": [
        {
            "date": "2026-10-03",
            "total_tokens": 150,
            "total_status": "partial",
            "missing_sources": [],
            "accounts": [
                {
                    "account_id": "codex-local-unmapped",
                    "provider": "codex",
                    "total_tokens": 60,
                    "coverage": "local_metadata",
                    "source_id": "host-b:codex",
                    "source_kind": "local_metadata",
                    "surface": "host-b",
                },
                {
                    "account_id": "minimax-account-1",
                    "provider": "minimax",
                    "total_tokens": 90,
                    "coverage": "reported",
                    "source_id": "captain-seed",
                    "source_kind": "operator_reported",
                    "surface": "host-b",
                },
            ],
            "providers": [],
            "unmapped": [
                {
                    "account_id": "minimax-local-unmapped",
                    "provider": "minimax",
                    "total_tokens": 70,
                    "coverage": "local_subset_unmapped",
                    "source_id": "host-b:pi:minimax",
                    "source_kind": "local_metadata",
                    "surface": "host-b",
                }
            ],
        }
    ],
    "seeds": [],
    "sources": [],
}


def build_fixture_snapshot(tmpdir):
    """Run the collector over offline fixtures and return (snapshot, paths)."""
    quota_path = pathlib.Path(tmpdir) / "quota.json"
    ledger_a = pathlib.Path(tmpdir) / "ledger-a.json"
    ledger_b = pathlib.Path(tmpdir) / "ledger-b.json"
    fleet_path = pathlib.Path(tmpdir) / "fleet.json"
    out_path = pathlib.Path(tmpdir) / "snapshot.json"
    quota_path.write_text(json.dumps(FIXTURE_QUOTA), encoding="utf-8")
    ledger_a.write_text(json.dumps(FIXTURE_LEDGER_A), encoding="utf-8")
    ledger_b.write_text(json.dumps(FIXTURE_LEDGER_B), encoding="utf-8")
    fleet_path.write_text(
        json.dumps(
            {
                "hosts": [
                    {
                        "label": "Host A",
                        "ssh": None,
                        "quota_json": str(quota_path),
                        "ledger_json": str(ledger_a),
                    },
                    {
                        "label": "Host B",
                        "ssh": None,
                        "quota_json": str(quota_path),
                        "ledger_json": str(ledger_b),
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    result = subprocess.run(
        [
            sys.executable,
            str(COLLECTOR_PATH),
            "--fleet-json",
            str(fleet_path),
            "--out",
            str(out_path),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise AssertionError("collector failed on fixtures: %s" % result.stderr)
    return json.loads(out_path.read_text(encoding="utf-8")), out_path


def board_text():
    return BOARD_PATH.read_text(encoding="utf-8")


def strip_band(html):
    """Remove the two inserted regions, leaving the board as it was."""
    html = re.sub(
        r"[ \t]*/\* HD2_QUOTA_BAND_CSS_BEGIN \*/.*?[ \t]*/\* HD2_QUOTA_BAND_CSS_END \*/\n",
        "",
        html,
        flags=re.S,
    )
    html = re.sub(
        r"[ \t]*<!-- HD2_QUOTA_BAND_BEGIN -->\n.*?[ \t]*<!-- HD2_QUOTA_BAND_END -->\n",
        "",
        html,
        flags=re.S,
    )
    return html


class FixtureSnapshotTest(unittest.TestCase):
    """Contract rules, proven against deterministic offline fixtures."""

    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.snapshot, cls.snapshot_path = build_fixture_snapshot(cls._tmp.name)
        merged, _ = COLLECTOR.merge_ledgers(
            [
                {"ok": True, "surface": "host-a", "label": "Host A", "timezone": "Europe/London",
                 "document": FIXTURE_LEDGER_A},
                {"ok": True, "surface": "host-b", "label": "Host B", "timezone": "Europe/London",
                 "document": FIXTURE_LEDGER_B},
            ]
        )
        cls.merged = {day["date"]: day for day in merged}
        cls.accounts = {account["id"]: account for account in cls.snapshot["accounts"]}
        cls.series = {day["date"]: day for day in cls.snapshot["aggregate"]["series"]}

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    # -- null is not zero ---------------------------------------------------
    def test_unknown_day_total_is_null_not_zero(self):
        day = self.series["2026-10-01"]
        self.assertIsNone(day["total_tokens"], "a day with no known rows must not total 0")
        self.assertEqual(day["status"], "unknown")
        self.assertEqual(day["coverage"], "unknown")

    def test_null_row_stays_null_not_zero(self):
        day = self.series["2026-10-02"]
        self.assertIsNone(day["total_tokens"])
        rows = {row["account_id"]: row for row in self.merged["2026-10-02"]["rows"]}
        self.assertIsNone(rows["codex-local-unmapped"]["total_tokens"])

    def test_unknown_is_labelled_with_a_reason(self):
        for account in self.snapshot["accounts"]:
            for day in account["tokens"]["days"]:
                if day["value"] is None:
                    self.assertTrue(day["reason"], "an unknown value must carry a reason: %r" % day)
                    self.assertEqual(day["status"], "unknown")

    def test_no_fabricated_zero_anywhere(self):
        for account in self.snapshot["accounts"]:
            for day in account["tokens"]["days"]:
                if day["value"] == 0:
                    self.fail("a zero must come from a measured row, not from an unknown: %r" % day)
        for entry in self.snapshot["aggregate"]["account_split"]:
            if entry["value"] == 0:
                self.assertNotEqual(entry["status"], "unknown")

    # -- the two codex accounts stay distinct --------------------------------
    def test_the_two_codex_accounts_are_separate_accounts(self):
        self.assertIn("codex-home", self.accounts)
        self.assertIn("openai-codex", self.accounts)
        self.assertNotEqual(
            self.accounts["codex-home"]["quota"]["account_key"],
            self.accounts["openai-codex"]["quota"]["account_key"],
        )
        self.assertEqual(len(self.snapshot["accounts"]), 7)

    def test_identical_codex_readings_do_not_merge_the_accounts(self):
        codex_home = self.accounts["codex-home"]
        openai_codex = self.accounts["openai-codex"]
        self.assertEqual(
            [w["percent_remaining"] for w in codex_home["quota"]["windows"]],
            [w["percent_remaining"] for w in openai_codex["quota"]["windows"]],
            "the fixture gives both codex accounts the same readings",
        )
        # identical numbers, still two rows, and neither is folded into the other
        self.assertNotEqual(codex_home["id"], openai_codex["id"])
        self.assertIsNone(codex_home["tokens"]["value"])
        self.assertIsNone(openai_codex["tokens"]["value"])

    # -- official totals supersede local subsets -----------------------------
    def test_official_total_supersedes_the_local_subset(self):
        day = self.series["2026-10-03"]
        # 40 (host a codex) + 60 (host b codex) + 90 (the official seed, once)
        self.assertEqual(day["total_tokens"], 190)
        superseded = [
            detail
            for detail in self.snapshot["aggregate"]["unattributed_detail"]
            if detail["bucket"] == "superseded_local_subset"
        ]
        self.assertTrue(superseded, "the superseded local subset must be exposed as detail")
        self.assertEqual(superseded[0]["total_tokens"], 70)
        self.assertEqual(superseded[0]["provider"], "minimax")

    def test_the_official_seed_is_counted_once_across_surfaces(self):
        day = self.merged["2026-10-03"]
        seed_rows = [row for row in day["rows"] if row["source_id"] == "captain-seed"]
        self.assertEqual(len(seed_rows), 1, "one official total carried by two surfaces is counted once")
        self.assertEqual(day["total_tokens"], 190)

    def test_two_host_local_rows_both_count(self):
        day = self.merged["2026-10-03"]
        local = [row for row in day["rows"] if row["provider"] == "codex"]
        self.assertEqual(len(local), 2)
        self.assertEqual(sum(row["total_tokens"] for row in local), 100)

    def test_local_subset_detail_is_never_added_to_an_account(self):
        for account in self.snapshot["accounts"]:
            self.assertNotEqual(account["id"], "minimax-local-unmapped")
        minimax = self.accounts["minimax-account-1"]
        self.assertEqual(minimax["tokens"]["value"], 90)

    # -- surfaces are partitioned -------------------------------------------
    def test_each_surface_keeps_its_own_rows(self):
        day = self.merged["2026-10-03"]
        surfaces = {row["surface"] for row in day["rows"]}
        self.assertEqual(surfaces, {"host-a", "host-b"})

    # -- not set up vs unknown ----------------------------------------------
    def test_not_set_up_is_recorded_separately_from_unknown(self):
        not_set_up = {entry["provider"] for entry in self.snapshot["not_set_up"]}
        self.assertIn("claude", not_set_up)
        self.assertTrue(self.snapshot["not_set_up"][0]["reason"])

    # -- corrupt ledger is refused ------------------------------------------
    def test_a_corrupt_ledger_is_refused_not_reset(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            corrupt = pathlib.Path(tmpdir) / "corrupt.json"
            corrupt.write_text('{"version": 1, "days": "not-a-list"}', encoding="utf-8")
            before = corrupt.read_bytes()
            record = COLLECTOR.collect_ledger_for_host({"label": "Host C", "ssh": None, "ledger_json": str(corrupt)})
            self.assertFalse(record["ok"])
            self.assertIn("refused", record["error"])
            self.assertEqual(corrupt.read_bytes(), before, "the corrupt store must not be rewritten")

    def test_a_missing_ledger_is_reported_not_invented(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            record = COLLECTOR.collect_ledger_for_host(
                {"label": "Host D", "ssh": None, "ledger_json": str(pathlib.Path(tmpdir) / "nope.json")}
            )
            self.assertFalse(record["ok"])
            self.assertIn("no usage ledger", record["error"])

    # -- the collector is regenerable and self-checking ----------------------
    def test_collector_self_check_passes(self):
        result = subprocess.run(
            [sys.executable, str(COLLECTOR_PATH), "--self-check"], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_snapshot_records_when_and_where_it_was_generated(self):
        self.assertTrue(self.snapshot["generated_at"])
        self.assertTrue(self.snapshot["generated_from"]["host"])
        self.assertEqual(self.snapshot["schema"], "hd2-quota-board-snapshot/v1")

    def test_snapshot_carries_no_credential_material(self):
        raw = json.dumps(self.snapshot).lower()
        for needle in ("access_token", "refresh_token", "api_key", "secret", "password", "authorization"):
            self.assertNotIn(needle, raw, "the snapshot must not carry %s" % needle)


class BoardTest(unittest.TestCase):
    """The board: additive insert, self-contained, honest when empty."""

    @classmethod
    def setUpClass(cls):
        cls.html = board_text()
        cls.stripped = strip_band(cls.html)

    def test_the_band_is_present(self):
        self.assertIn('id="quota-band"', self.html)
        self.assertIn('id="qb-tiles"', self.html)
        self.assertIn('id="qb-legend"', self.html)
        self.assertIn('id="qb-pop"', self.html)

    def test_the_band_is_self_contained(self):
        band = self.html[self.html.index("<!-- HD2_QUOTA_BAND_BEGIN -->") : self.html.index("<!-- HD2_QUOTA_BAND_END -->")]
        self.assertNotIn("http://", band)
        self.assertNotIn("https://", band)
        self.assertNotIn("<script src", band)
        self.assertNotIn("@import", band)
        self.assertNotIn("fetch(", band)

    def test_no_existing_board_markup_was_removed(self):
        # The Captain's board, as it was before this lane (sha256 recorded).
        baseline = pathlib.Path(
            pathlib.os.environ.get(
                "FM_QUOTA_BOARD_BASELINE", "/root/agent-work/deightonllm-firstmate/unified-board.html"
            )
        )
        if baseline.is_file():
            self.assertEqual(
                self.stripped,
                baseline.read_text(encoding="utf-8"),
                "the board minus the band must equal the board as it was",
            )
        for marker, expected in (
            ("<tr", 33),
            ('class="pill', 92),
            ("<table", 3),
            ('class="stat-card"', 9),
            ('class="filters"', 1),
            ('id="staleness-box"', 1),
            ('id="pulse"', 1),
            ("<footer>", 1),
        ):
            self.assertGreaterEqual(
                self.html.count(marker),
                expected,
                "marker %s must not have been removed" % marker,
            )

    def test_the_freshness_meter_and_logo_are_untouched(self):
        self.assertIn('id="staleness-box"', self.stripped)
        self.assertIn("Snapshot Freshness", self.stripped)
        self.assertIn("HD2 Fleet Unified Board &amp; To-Do Tracker", self.stripped)
        self.assertIn('id="feature-requests"', self.stripped)
        self.assertIn('id="filter-state"', self.stripped)

    def test_the_legend_explains_unknown_and_not_set_up(self):
        legend = self.html[self.html.index('id="qb-legend"') : self.html.index('id="qb-tiles"')]
        self.assertIn("unknown", legend)
        self.assertIn("not set up", legend)
        self.assertIn("never a zero", legend)

    def test_the_legend_matches_the_snapshot_legend_keys(self):
        if not SNAPSHOT_PATH.is_file():
            self.skipTest("no snapshot on disk")
        snapshot = json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))
        html_keys = set(re.findall(r'data-legend-key="([^"]+)"', self.html))
        for entry in snapshot["legend"]:
            self.assertIn(entry["key"], html_keys)

    def test_a_missing_snapshot_degrades_to_an_explicit_state(self):
        self.assertIn('id="qb-empty"', self.html)
        self.assertIn("not collected yet", self.html)
        self.assertIn("unknown", self.html)
        # the fallback must never render a zero as if it were measured
        self.assertIn("'unknown'", self.html)
        self.assertIn("isNumber", self.html)

    def test_the_hover_panel_is_keyboard_reachable(self):
        self.assertIn("tile.setAttribute('tabindex', '0')", self.html)
        self.assertIn("tile.addEventListener('focus'", self.html)
        self.assertIn("tile.addEventListener('mouseenter'", self.html)
        self.assertIn("Previous days", self.html)

    def test_each_account_gets_its_own_colour(self):
        colours = set(re.findall(r"'([a-z0-9-]+)':\s*'#[0-9a-f]{6}'", self.html))
        for account in (
            "codex-home",
            "openai-codex",
            "minimax-account-1",
            "minimax-account-2",
            "glm",
            "agy-gemini",
            "agy-claude-gpt",
        ):
            self.assertIn(account, colours)


class BindTest(unittest.TestCase):
    """The binder: idempotent, fail-closed, and never able to close the script."""

    def _board_copy(self, tmpdir):
        target = pathlib.Path(tmpdir) / "board.html"
        target.write_text(board_text(), encoding="utf-8")
        return target

    def test_binding_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            target = self._board_copy(tmpdir)
            snapshot = pathlib.Path(tmpdir) / "snap.json"
            snapshot.write_text(
                json.dumps({"schema": "hd2-quota-board-snapshot/v1", "generated_at": "x"}), encoding="utf-8"
            )
            first = subprocess.run(
                [sys.executable, str(BINDER_PATH), "--snapshot", str(snapshot), "--html", str(target)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            after_first = target.read_text(encoding="utf-8")
            second = subprocess.run(
                [sys.executable, str(BINDER_PATH), "--snapshot", str(snapshot), "--html", str(target)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(second.returncode, 0)
            self.assertIn("already current", second.stdout)
            self.assertEqual(after_first, target.read_text(encoding="utf-8"))

    def test_binding_refuses_a_wrong_schema(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            target = self._board_copy(tmpdir)
            before = target.read_text(encoding="utf-8")
            snapshot = pathlib.Path(tmpdir) / "snap.json"
            snapshot.write_text(json.dumps({"schema": "nope"}), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(BINDER_PATH), "--snapshot", str(snapshot), "--html", str(target)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertEqual(before, target.read_text(encoding="utf-8"), "the board must be untouched")

    def test_binding_refuses_a_board_without_the_anchor(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            target = pathlib.Path(tmpdir) / "board.html"
            target.write_text("<html><body>nothing here</body></html>", encoding="utf-8")
            snapshot = pathlib.Path(tmpdir) / "snap.json"
            snapshot.write_text(json.dumps({"schema": "hd2-quota-board-snapshot/v1"}), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(BINDER_PATH), "--snapshot", str(snapshot), "--html", str(target)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("anchor", result.stderr + result.stdout)

    def test_a_script_payload_cannot_close_the_script_element(self):
        payload = BINDER.escaped_payload({"schema": "x", "evil": "</script><script>alert(1)</script>"})
        self.assertNotIn("</script", payload)
        self.assertIn("\\u003c", payload)


if __name__ == "__main__":
    unittest.main(verbosity=2)
