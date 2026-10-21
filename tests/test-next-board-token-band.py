#!/usr/bin/env python3
"""
test-next-board-token-band.py — the regression check for the Captain's token band.

`bin/fm-token-collect.py` turns two real sources (the quota windows from quota-axi and
the per-account token usage ledger) into ONE document: the token band the live board
renders. The Captain asked for "our tokens agregation all account weekly and daily
usage heat map roll over etc.", and the whole point of that band is that it does not
lie: an unknown value is unknown, not zero, and a partial week says so.

This check is hermetic. It drives the collector with fixtures, never with live data, so
it proves the RULES rather than the current numbers. It is non-interactive and it exits
0 (every rule holds) or 1 (a rule broke).

It fails when:
  * an unknown ledger day is summed as zero instead of staying null;
  * the weekly rollup claims a complete total when a day in the window is missing;
  * two quota windows that share a window id are merged, or lose their distinct keys
    and labels;
  * a missing source takes the other source's data down with it;
  * the collector writes somewhere other than it was told to, skips a refresh it was
    told to make, or is not byte-identical for identical inputs.

usage: test-next-board-token-band.py
"""
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

# Importing the collector must not leave a bytecode cache behind in bin/.
sys.dont_write_bytecode = True

REPO = pathlib.Path(__file__).resolve().parent.parent
COLLECTOR_PATH = REPO / "bin" / "fm-token-collect.py"

SPEC = importlib.util.spec_from_file_location("fm_token_collect", COLLECTOR_PATH)
COLLECT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COLLECT)

NOW = COLLECT.parse_instant("2026-10-21T05:00:00Z")

# The roster the fixture is measured against. The ledger's own surface expects codex
# and glm; the roster is what turns "no reading" into a named coverage slot.
ROSTER = {
    "schema": "firstmate-token-surfaces/v1",
    "surfaces": [
        {
            "surface": "controller",
            "label": "Controller (Crisp-R)",
            "host": "vmi3196300",
            "aliases": ["crisp-r", "vmi3196300"],
            "expected_providers": ["codex", "glm"],
        },
    ],
    "provider_labels": {"codex": "Codex", "glm": "GLM"},
    "provider_notes": {},
}

# A quota payload that reports the SAME window id twice for one provider, which is
# what happens when a provider has two accounts on the same plan.
QUOTA_FIXTURE = {
    "generatedAt": "2026-10-21T05:00:00.000Z",
    "schemaVersion": 5,
    "providers": [
        {
            "provider": "agy",
            "label": "Antigravity",
            "source": "cli-rpc",
            "plan": "Google AI Pro",
            "account": {"email": "deightonbrighouse@gmail.com"},
            "accountKeys": ["default"],
            "state": {"status": "fresh", "stale": False},
            "windows": [
                {
                    "id": "gemini_weekly",
                    "label": "Gemini weekly",
                    "kind": "weekly",
                    "percentRemaining": 0,
                    "percentUsed": 100,
                    "resetsAt": "2026-10-23T22:00:13.000Z",
                    "windowSeconds": 604800,
                    "pace": {"status": "ahead", "projectedExhaustedAt": "2026-10-21T05:00:00.000Z"},
                },
                {
                    "id": "gemini_weekly",
                    "label": "Gemini weekly",
                    "kind": "weekly",
                    "percentRemaining": 76,
                    "percentUsed": 24,
                    "resetsAt": "2026-10-26T22:28:42.000Z",
                    "windowSeconds": 604800,
                    "pace": {"status": "ahead"},
                },
            ],
            "quotaSemantics": {
                "status": "known",
                "effectiveAvailability": [
                    {
                        "scope": "gemini",
                        "status": "known",
                        "limitingWindowIds": ["gemini_weekly"],
                        "runway": {
                            "status": "exhausted_now",
                            "projectedExhaustedAt": "2026-10-21T05:00:00.000Z",
                        },
                    }
                ],
            },
        },
        {
            "provider": "codex",
            "label": "Codex",
            "source": "oauth",
            "plan": "plus",
            "account": {"email": "boxedagency@gmail.com", "accountId": "602f6bbb"},
            "accountKeys": ["codex-home", "openai-codex"],
            "state": {"status": "fresh", "stale": False},
            "windows": [
                {
                    "id": "weekly",
                    "label": "week",
                    "kind": "weekly",
                    "percentRemaining": 82,
                    "percentUsed": 18,
                    "resetsAt": "2026-10-27T06:34:19.000Z",
                    "windowSeconds": 604800,
                    "pace": {"status": "ahead"},
                },
                {
                    "id": "session",
                    "label": "session",
                    "kind": "session",
                    "resetsAt": "2026-10-21T06:50:19.000Z",
                    "windowSeconds": 18000,
                    "pace": {"status": "behind"},
                },
                {
                    "id": "session",
                    "label": "session",
                    "kind": "session",
                    "percentRemaining": 40,
                    "percentUsed": 60,
                },
                {
                    # A window that reports no percentages and no reset at all. Both
                    # percentages stay null - they are unknown, not zero.
                    "id": "metered",
                    "label": "metered",
                    "kind": "monthly",
                },
            ],
            "quotaSemantics": {
                "status": "known",
                "effectiveAvailability": [
                    {
                        "scope": "all_models",
                        "status": "known",
                        "limitingWindowIds": ["session"],
                        "runway": {"status": "projected_exhaustion"},
                    }
                ],
            },
        },
        {
            "provider": "claude",
            "label": "Claude",
            "source": "unavailable",
            "accountKeys": ["default"],
            "state": {"status": "auth_required", "stale": False, "error": "credentials_missing"},
            "notSetUp": True,
            "windows": [],
            "quotaSemantics": {"status": "unknown", "effectiveAvailability": []},
        },
    ],
}

# A ledger with one measured day, one day whose total is unknown, and one day whose
# total is a partial one.
LEDGER_FIXTURE = {
    "contract_version": 1,
    "version": 1,
    "timezone": "Europe/London",
    "surface": "vmi3196300",
    "generated_at": "2026-10-20T09:35:50+01:00",
    "created_at": "2026-10-19T07:52:02+01:00",
    "accounts": [
        {
            "id": "codex-local-unmapped",
            "label": "codex local (unmapped)",
            "provider": "codex",
            "identity_status": "unknown_local_subset",
        },
        {
            "id": "glm-local-unmapped",
            "label": "glm local (unmapped)",
            "provider": "glm",
            "identity_status": "unknown_local_subset",
        },
    ],
    "days": [
        {
            "date": "2026-10-19",
            "total_tokens": 300,
            "total_status": "measured",
            "expected_providers": ["codex", "glm"],
            "missing_sources": [],
            "accounts": [
                {"account_id": "codex-local-unmapped", "provider": "codex", "source_id": "s1", "total_tokens": 100},
                {"account_id": "codex-local-unmapped", "provider": "codex", "source_id": "s2", "total_tokens": 50},
                {"account_id": "glm-local-unmapped", "provider": "glm", "source_id": "s3", "total_tokens": 150},
            ],
        },
        {
            "date": "2026-10-20",
            "total_tokens": None,
            "total_status": "unknown",
            "expected_providers": ["codex", "glm"],
            "missing_sources": ["codex", "glm"],
            "accounts": [],
        },
        {
            "date": "2026-10-18",
            "total_tokens": 70,
            "total_status": "partial",
            "expected_providers": ["codex", "glm"],
            "missing_sources": ["glm"],
            "accounts": [
                {"account_id": "codex-local-unmapped", "provider": "codex", "source_id": "s4", "total_tokens": 70},
            ],
        },
    ],
}


def build(**kwargs):
    """Build a band from the fixtures with a fixed clock."""
    options = {
        "quota_payload": QUOTA_FIXTURE,
        "ledger_payload": LEDGER_FIXTURE,
        "now": NOW,
        "ledger_path_display": "data/tracker-tokens-20261019/ledger/usage.json",
        "roster": ROSTER,
        "surface_docs": [],
        "quota_error": None,
        "ledger_error": None,
    }
    options.update(kwargs)
    return COLLECT.build_band(**options)


def day_row(document, date):
    for row in document["daily"]:
        if row["date"] == date:
            return row
    raise AssertionError("no daily row for %s" % date)


class UnknownStaysUnknown(unittest.TestCase):
    """null is not zero, and a zero would be a lie."""

    def test_unknown_day_total_stays_null(self):
        document = build()
        row = day_row(document, "2026-10-20")
        self.assertIsNone(row["total_tokens"])
        self.assertEqual(row["total_status"], "unknown")

    def test_unknown_day_is_not_summed_as_zero(self):
        document = build()
        row = day_row(document, "2026-10-20")
        self.assertNotEqual(row["total_tokens"], 0)
        # The known day is summed whole; the unknown day adds nothing to it, and the
        # weekly rollup says so instead of pretending the week is complete.
        self.assertEqual(day_row(document, "2026-10-19")["total_tokens"], 300)
        self.assertEqual(document["weekly"]["total_tokens"], 370)

    def test_unknown_day_reports_missing_coverage(self):
        document = build()
        row = day_row(document, "2026-10-20")
        self.assertEqual(row["accounts"], {})
        self.assertEqual(row["accounts_known"], 0)
        # Two expected surface/provider readings, neither of which happened.
        self.assertEqual(row["coverage_slots_unknown"], 2)
        self.assertEqual(row["coverage_slots_measured"], 0)
        self.assertEqual(row["coverage_slots_expected"], 2)

    def test_partial_day_keeps_its_own_status(self):
        document = build()
        row = day_row(document, "2026-10-18")
        self.assertEqual(row["total_status"], "partial")
        self.assertEqual(row["total_tokens"], 70)

    def test_window_without_percentages_keeps_both_null(self):
        document = build()
        window = [w for w in document["quota"]["windows"] if w["window_id"] == "metered"][0]
        self.assertIsNone(window["percent_remaining"])
        self.assertIsNone(window["percent_used"])

    def test_window_without_projection_keeps_it_null(self):
        document = build()
        window = [w for w in document["quota"]["windows"] if w["window_id"] == "metered"][0]
        self.assertIsNone(window["projected_exhausted_at"])
        self.assertIsNone(window["resets_in_seconds"])


class WeeklyIsAFloor(unittest.TestCase):
    """A week with a hole in it is a floor, and says so."""

    def test_missing_day_makes_the_rollup_a_floor(self):
        document = build()
        weekly = document["weekly"]
        self.assertTrue(weekly["is_floor"])
        self.assertEqual(weekly["status"], "partial")
        self.assertEqual(weekly["days_expected"], 7)
        # 2026-10-18 and 2026-10-19 are known; 2026-10-20 is unknown, and 2026-10-15,
        # 16, 17 and 21 have no ledger row at all.
        self.assertEqual(weekly["days_known"], 2)
        self.assertEqual(weekly["days_unknown"], 5)
        self.assertEqual(weekly["total_tokens"], 370)

    def test_calendar_days_with_no_ledger_entry_count_as_unknown(self):
        # 2026-10-21 has no ledger row at all. It is missing, so it is unknown.
        document = build()
        weekly = document["weekly"]
        self.assertEqual(weekly["end_date"], "2026-10-21")
        self.assertEqual(weekly["start_date"], "2026-10-15")
        self.assertEqual(weekly["days_known"] + weekly["days_unknown"], 7)

    def test_a_week_with_nothing_known_is_unknown_not_zero(self):
        document = build(ledger_payload={
            "contract_version": 1,
            "timezone": "Europe/London",
            "surface": "vmi3196300",
            "generated_at": "2026-10-20T09:35:50+01:00",
            "accounts": [],
            "days": [],
        })
        weekly = document["weekly"]
        self.assertIsNone(weekly["total_tokens"])
        self.assertEqual(weekly["status"], "unknown")
        self.assertTrue(weekly["is_floor"])
        self.assertEqual(weekly["days_known"], 0)

    def test_a_complete_week_is_not_a_floor(self):
        days = [
            {
                "date": "2026-10-%02d" % day,
                "total_tokens": 10,
                "total_status": "measured",
                "expected_providers": ["codex", "glm"],
                "accounts": [
                    {"account_id": "codex-local-unmapped", "provider": "codex",
                     "source_id": "s-codex", "total_tokens": 4},
                    {"account_id": "glm-local-unmapped", "provider": "glm",
                     "source_id": "s-glm", "total_tokens": 6},
                ],
            }
            for day in range(15, 22)
        ]
        document = build(ledger_payload={
            "contract_version": 1,
            "timezone": "Europe/London",
            "surface": "vmi3196300",
            "generated_at": "2026-10-20T09:35:50+01:00",
            "accounts": [],
            "days": days,
        })
        weekly = document["weekly"]
        self.assertFalse(weekly["is_floor"])
        self.assertEqual(weekly["status"], "measured")
        self.assertEqual(weekly["total_tokens"], 70)
        self.assertEqual(weekly["days_unknown"], 0)

    def test_window_is_the_seven_days_in_the_ledger_timezone(self):
        # 23:30 UTC on the 20th is already the 21st in Europe/London.
        document = build(now=COLLECT.parse_instant("2026-10-20T23:30:00Z"))
        self.assertEqual(document["weekly"]["end_date"], "2026-10-21")
        self.assertEqual(document["weekly"]["start_date"], "2026-10-15")

    def test_per_account_sums_to_the_same_floor(self):
        document = build()
        weekly = document["weekly"]
        self.assertEqual(sum(weekly["per_account"].values()), weekly["total_tokens"])
        # The account key carries its surface, so a reading is never attributed to
        # the wrong surface.
        self.assertEqual(weekly["per_account"]["controller|codex-local-unmapped"], 220)
        self.assertEqual(weekly["per_account_known_days"]["controller|codex-local-unmapped"], 2)

    def test_several_rows_for_one_account_are_summed_into_one_cell(self):
        document = build()
        row = day_row(document, "2026-10-19")
        self.assertEqual(row["accounts"]["controller|codex-local-unmapped"], 150)
        self.assertEqual(row["accounts_known"], 2)


class SameIdWindowsStaySeparate(unittest.TestCase):
    """Two windows that share an id are two accounts, not one row."""

    def test_both_rows_survive(self):
        document = build()
        rows = [w for w in document["quota"]["windows"] if w["window_id"] == "gemini_weekly"]
        self.assertEqual(len(rows), 2)

    def test_their_keys_differ(self):
        document = build()
        rows = [w for w in document["quota"]["windows"] if w["window_id"] == "gemini_weekly"]
        keys = sorted(row["key"] for row in rows)
        self.assertEqual(keys, ["agy|gemini_weekly|2026-10-23", "agy|gemini_weekly|2026-10-26"])

    def test_their_labels_differ_and_carry_the_reset_day(self):
        document = build()
        rows = [w for w in document["quota"]["windows"] if w["window_id"] == "gemini_weekly"]
        labels = sorted(row["label"] for row in rows)
        self.assertEqual(len(set(labels)), 2)
        for row in rows:
            self.assertTrue(row["label"].startswith("Antigravity - Gemini weekly ("))
            self.assertIn(row["resets_at"][:10], row["label"])

    def test_their_numbers_are_not_crossed_over(self):
        document = build()
        rows = {w["key"]: w for w in document["quota"]["windows"]}
        self.assertEqual(rows["agy|gemini_weekly|2026-10-23"]["percent_remaining"], 0)
        self.assertEqual(rows["agy|gemini_weekly|2026-10-26"]["percent_remaining"], 76)

    def test_every_window_key_is_unique(self):
        document = build()
        keys = [w["key"] for w in document["quota"]["windows"]]
        self.assertEqual(len(keys), len(set(keys)))

    def test_a_window_without_a_reset_gets_the_no_reset_key(self):
        document = build()
        rows = [w for w in document["quota"]["windows"] if w["window_id"] == "session"]
        no_reset = [w for w in rows if w["resets_at"] is None]
        self.assertEqual(len(no_reset), 1)
        self.assertEqual(no_reset[0]["key"], "codex|session|no-reset")

    def test_a_window_without_a_reset_is_not_a_rollover(self):
        document = build()
        self.assertTrue(all(row["resets_at"] is not None for row in document["rollover"]))
        self.assertNotIn("codex|session|no-reset", [row["key"] for row in document["rollover"]])

    def test_rollover_is_sorted_by_reset_instant(self):
        document = build()
        resets = [row["resets_at"] for row in document["rollover"]]
        self.assertEqual(resets, sorted(resets))

    def test_rollover_restores_the_window_to_full(self):
        document = build()
        self.assertTrue(all(row["restores_percent"] == 100 for row in document["rollover"]))


class OneSourceFailingDoesNotSinkTheOther(unittest.TestCase):
    """A missing source is reported, never silent, and never contagious."""

    def test_missing_ledger_yields_ok_false_while_quota_still_renders(self):
        document = build(ledger_payload=None, ledger_error="ledger unreadable at /x: boom")
        self.assertFalse(document["ledger"]["ok"])
        self.assertEqual(document["ledger"]["error"], "ledger unreadable at /x: boom")
        self.assertTrue(document["quota"]["ok"])
        self.assertTrue(document["quota"]["windows"])
        self.assertEqual(document["daily"], [])
        self.assertIsNone(document["weekly"]["total_tokens"])
        self.assertEqual(document["errors"], ["ledger: ledger unreadable at /x: boom"])

    def test_missing_quota_yields_ok_false_while_ledger_still_renders(self):
        document = build(quota_payload=None, quota_error="quota-axi exited 1: nope")
        self.assertFalse(document["quota"]["ok"])
        self.assertEqual(document["quota"]["error"], "quota-axi exited 1: nope")
        self.assertTrue(document["ledger"]["ok"])
        self.assertTrue(document["daily"])
        self.assertEqual(document["weekly"]["total_tokens"], 370)
        self.assertEqual(document["errors"], ["quota: quota-axi exited 1: nope"])

    def test_both_sources_missing_still_produces_a_document(self):
        document = build(quota_payload=None, ledger_payload=None,
                         quota_error="quota down", ledger_error="ledger down")
        self.assertEqual(document["schema"], "firstmate-token-band/v2")
        self.assertEqual(len(document["errors"]), 2)

    def test_a_provider_without_windows_is_kept_with_its_state(self):
        document = build()
        without = document["quota"]["providers_without_windows"]
        self.assertEqual(len(without), 1)
        self.assertEqual(without[0]["provider"], "claude")
        self.assertEqual(without[0]["state"], "auth_required")
        self.assertEqual(without[0]["error"], "credentials_missing")
        self.assertTrue(without[0]["not_set_up"])

    def test_the_document_carries_the_contract_shape(self):
        document = build()
        self.assertEqual(
            sorted(document.keys()),
            ["coverage", "daily", "errors", "generated_at", "ledger", "quota", "rollover",
             "schema", "weekly"],
        )
        self.assertEqual(document["schema"], "firstmate-token-band/v2")
        self.assertEqual(
            document["quota"]["source_command"],
            ["quota-axi", "--json", "--full", "--no-credential-refresh"],
        )
        window = document["quota"]["windows"][0]
        self.assertEqual(
            sorted(window.keys()),
            [
                "account_email", "account_id", "account_keys", "error", "key", "kind", "label",
                "pace_status", "percent_remaining", "percent_used", "plan", "projected_exhausted_at",
                "provider", "provider_label", "resets_at", "resets_in_seconds", "runway_status",
                "stale", "state", "window_id", "window_label", "window_seconds",
            ],
        )
        self.assertEqual(
            sorted(document["weekly"].keys()),
            [
                "days_expected", "days_known", "days_unknown", "end_date", "is_floor",
                "per_account", "per_account_known_days", "per_surface", "start_date", "status",
                "total_measured_tokens", "total_reported_tokens", "total_tokens",
            ],
        )
        self.assertEqual(
            sorted(document["daily"][0].keys()),
            [
                "accounts", "accounts_known", "accounts_unknown", "coverage_slots_expected",
                "coverage_slots_measured", "coverage_slots_unknown", "date", "rows",
                "source_total_status", "surfaces", "total_measured_tokens", "total_reported_tokens",
                "total_status", "total_tokens",
            ],
        )


class CommandLineBehaviour(unittest.TestCase):
    """The collector writes where it was told, and only when it should."""

    def run_collector(self, args, cwd=None):
        command = [sys.executable, str(COLLECTOR_PATH)] + args
        return subprocess.run(command, capture_output=True, text=True, cwd=cwd or str(REPO))

    def write_fixtures(self, directory):
        quota_path = pathlib.Path(directory) / "quota.json"
        ledger_path = pathlib.Path(directory) / "usage.json"
        quota_path.write_text(json.dumps(QUOTA_FIXTURE), encoding="utf-8")
        ledger_path.write_text(json.dumps(LEDGER_FIXTURE), encoding="utf-8")
        return str(quota_path), str(ledger_path)

    def test_it_writes_a_contract_document_where_told(self):
        with tempfile.TemporaryDirectory() as directory:
            quota_path, ledger_path = self.write_fixtures(directory)
            out = pathlib.Path(directory) / "nested" / "token-band.json"
            result = self.run_collector([
                "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                "--now", "2026-10-21T05:00:00Z",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            document = json.loads(out.read_text(encoding="utf-8"))
            self.assertEqual(document["schema"], "firstmate-token-band/v2")
            self.assertEqual(document["generated_at"], "2026-10-21T05:00:00Z")
            self.assertEqual(document["weekly"]["total_tokens"], 370)
            self.assertTrue(document["weekly"]["is_floor"])

    def test_the_summary_line_says_the_weekly_number_is_a_floor(self):
        with tempfile.TemporaryDirectory() as directory:
            quota_path, ledger_path = self.write_fixtures(directory)
            out = pathlib.Path(directory) / "token-band.json"
            result = self.run_collector([
                "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                "--now", "2026-10-21T05:00:00Z",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(result.stdout.strip().splitlines()), 1)
            self.assertIn("floor", result.stdout)
            self.assertIn("at least 370", result.stdout)

    def test_the_summary_line_reports_a_failed_source(self):
        with tempfile.TemporaryDirectory() as directory:
            quota_path, _ = self.write_fixtures(directory)
            out = pathlib.Path(directory) / "token-band.json"
            result = self.run_collector([
                "--out", str(out), "--ledger", str(pathlib.Path(directory) / "nope.json"),
                "--quota-json", quota_path, "--now", "2026-10-21T05:00:00Z",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("ledger=failed", result.stdout)
            document = json.loads(out.read_text(encoding="utf-8"))
            self.assertFalse(document["ledger"]["ok"])
            self.assertTrue(document["quota"]["windows"])

    def test_the_output_is_byte_identical_for_the_same_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            quota_path, ledger_path = self.write_fixtures(directory)
            first = pathlib.Path(directory) / "a.json"
            second = pathlib.Path(directory) / "b.json"
            for out in (first, second):
                result = self.run_collector([
                    "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                    "--now", "2026-10-21T05:00:00Z",
                ])
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_a_fresh_output_is_left_alone_under_max_age(self):
        with tempfile.TemporaryDirectory() as directory:
            quota_path, ledger_path = self.write_fixtures(directory)
            out = pathlib.Path(directory) / "token-band.json"
            first = self.run_collector([
                "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                "--now", "2026-10-21T05:00:00Z",
            ])
            self.assertEqual(first.returncode, 0, first.stderr)
            before = out.read_bytes()
            second = self.run_collector([
                "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                "--now", "2026-10-21T05:00:00Z", "--max-age", "3600",
            ])
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertIn("skipped refresh", second.stdout)
            self.assertEqual(out.read_bytes(), before)

    def test_force_refreshes_a_fresh_output(self):
        with tempfile.TemporaryDirectory() as directory:
            quota_path, ledger_path = self.write_fixtures(directory)
            out = pathlib.Path(directory) / "token-band.json"
            self.run_collector([
                "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                "--now", "2026-10-21T05:00:00Z",
            ])
            before = out.read_bytes()
            result = self.run_collector([
                "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                "--now", "2026-10-21T05:00:00Z", "--max-age", "3600", "--force",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("skipped refresh", result.stdout)
            self.assertEqual(out.read_bytes(), before)

    def test_it_does_not_write_outside_the_directory_it_was_told(self):
        with tempfile.TemporaryDirectory() as directory:
            quota_path, ledger_path = self.write_fixtures(directory)
            out = pathlib.Path(directory) / "token-band.json"
            result = self.run_collector([
                "--out", str(out), "--ledger", ledger_path, "--quota-json", quota_path,
                "--now", "2026-10-21T05:00:00Z",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            # The default output path is never touched when --out is given.
            default_out = REPO / "data" / "next-board-publish" / "token-band.json"
            self.assertTrue(str(default_out).startswith(str(REPO)))
            self.assertFalse(str(out).startswith(str(REPO)))

    def test_the_default_output_lives_under_the_scripts_own_repo_root(self):
        self.assertEqual(COLLECT.REPO_ROOT, REPO)
        self.assertEqual(
            COLLECT.REPO_ROOT / COLLECT.DEFAULT_OUT_REL,
            REPO / "data" / "next-board-publish" / "token-band.json",
        )


if __name__ == "__main__":
    unittest.main()
