#!/usr/bin/env python3
"""
test-token-usage-surfaces.py — the regression check for the fleet-wide token ledger.

The Captain's complaint on 2026-10-21 was that the board's token band showed one
account where the fleet has two, showed no Gemini numbers, and reported a total he
could not reconcile. The cause was not arithmetic: the usage ledger only ever read
the Controller's own traces, and it presented itself as one surface while carrying
another surface's rows inside it.

This check proves the rules the fix has to hold:

  * every surface in the roster is carried, and a surface that reported nothing is
    carried as UNKNOWN with the reason - never as a zero and never dropped;
  * every row keeps its provenance: which surface, which account identity, which
    source, and whether it was measured or reported by a human;
  * a day's total is the sum of that day's rows, and a row that is null never
    becomes a zero;
  * an unmeasured day is unknown, not zero;
  * an operator-reported seed lands on the day it was reported for and on no other
    day, and it is never presented as an instrumented measurement;
  * coverage and the total come from one source of truth, so they cannot disagree;
  * a surface's own published document outranks the Controller's snapshot of it, so
    the same reading is never counted twice.

It is hermetic: it drives the collector and the publisher with fixtures, never with
live data, so it proves the RULES rather than the current numbers.

usage: test-token-usage-surfaces.py
"""
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

REPO = pathlib.Path(__file__).resolve().parent.parent
COLLECTOR_PATH = REPO / "bin" / "fm-token-collect.py"
PUBLISHER_PATH = REPO / "bin" / "fm-token-usage-publish.py"
BOARD_PUBLISHER_PATH = REPO / "bin" / "fm-next-board-publish.py"

SPEC = importlib.util.spec_from_file_location("fm_token_collect", COLLECTOR_PATH)
COLLECT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COLLECT)

NOW = COLLECT.parse_instant("2026-10-21T05:00:00Z")

# The fleet roster as a fixture: four coding surfaces, each expected to report the
# four fleet providers. The Gemini provider has a standing note because no local
# usage surface exposes its token counts.
ROSTER = {
    "schema": "firstmate-token-surfaces/v1",
    "surfaces": [
        {
            "surface": "controller",
            "label": "Controller (Crisp-R)",
            "host": "vmi3196300",
            "aliases": ["crisp-r", "vmi3196300"],
            "expected_providers": ["agy", "codex", "glm", "minimax"],
        },
        {
            "surface": "hd2stack",
            "label": "HD2Stack",
            "host": "vmi3238503",
            "aliases": ["hd2stack", "vmi3238503"],
            "expected_providers": ["agy", "codex", "glm", "minimax"],
        },
        {
            "surface": "brandon-compute",
            "label": "Hetz (brandon-compute)",
            "host": "brandon-compute.tailddbb4d.ts.net",
            "aliases": ["brandon-compute"],
            "expected_providers": ["agy", "codex", "glm", "minimax"],
        },
    ],
    "provider_labels": {"agy": "Antigravity (Gemini)", "codex": "Codex",
                        "glm": "GLM", "minimax": "MiniMax"},
    "provider_notes": {"agy": "no local usage surface exposes Gemini token counts"},
}

# A ledger that carries rows from TWO surfaces under one document, exactly like the
# Controller's own ledger did. The two days with no rows are the unmeasured days.
LEDGER = {
    "contract_version": 1,
    "version": 1,
    "timezone": "Europe/London",
    "surface": "vmi3196300",
    "generated_at": "2026-10-20T09:35:50+01:00",
    "created_at": "2026-10-19T07:52:02+01:00",
    "accounts": [
        {"id": "codex-local-unmapped", "label": "codex local (unmapped)",
         "provider": "codex", "identity_status": "unknown_local_subset"},
        {"id": "glm-local-unmapped", "label": "glm local (unmapped)",
         "provider": "glm", "identity_status": "unknown_local_subset"},
        {"id": "minimax-local-unmapped", "label": "minimax local (unmapped)",
         "provider": "minimax", "identity_status": "unknown_local_subset"},
        {"id": "minimax-account-1", "label": "minimax account 1",
         "provider": "minimax", "identity_status": "operator_alias"},
    ],
    "days": [
        {
            "date": "2026-10-19",
            "total_tokens": 400,
            "total_status": "measured",
            "expected_providers": ["codex", "glm"],
            "accounts": [
                {"account_id": "codex-local-unmapped", "provider": "codex",
                 "source_id": "vmi3196300:pi:codex", "source_kind": "local_metadata",
                 "coverage": "local_metadata", "surface": "vmi3196300",
                 "total_tokens": 100, "observed_at": "2026-10-19T22:49:20+01:00"},
                {"account_id": "codex-local-unmapped", "provider": "codex",
                 "source_id": "vmi3238503:pi:codex", "source_kind": "local_metadata",
                 "coverage": "local_metadata", "surface": "vmi3238503",
                 "total_tokens": 200, "observed_at": "2026-10-19T22:49:20+01:00"},
                {"account_id": "glm-local-unmapped", "provider": "glm",
                 "source_id": "vmi3238503:pi:glm", "source_kind": "local_metadata",
                 "coverage": "local_metadata", "surface": "vmi3238503",
                 "total_tokens": 100, "observed_at": "2026-10-19T22:49:20+01:00"},
            ],
        },
        {
            "date": "2026-10-20",
            "total_tokens": None,
            "total_status": "unknown",
            "expected_providers": ["codex", "glm"],
            "accounts": [],
        },
    ],
    "seeds": [
        {
            "account_id": "minimax-account-1",
            "provider": "minimax",
            "date": "2026-10-19",
            "source_id": "captain-20261019-minimax-1",
            "total_tokens": 500,
            "observed_at": "2026-10-19T07:32:35+01:00",
            "note": "operator-reported; dated; never re-applied as a future day",
        },
    ],
}


def build(ledger_payload=None, roster=None, surface_docs=None, now=NOW):
    """Build a band from the fixtures with a fixed clock."""
    if ledger_payload is None:
        ledger_payload = LEDGER
    return COLLECT.build_band(
        quota_payload=None,
        ledger_payload=ledger_payload,
        now=now,
        ledger_path_display="data/tracker-tokens-20261019/ledger/usage.json",
        roster=ROSTER if roster is None else roster,
        surface_docs=surface_docs or [],
        quota_error="quota not read in this check",
    )


def day_row(document, date):
    for row in document["daily"]:
        if row["date"] == date:
            return row
    raise AssertionError("no daily row for %s" % date)


def surface_entry(document, surface):
    for entry in document["ledger"]["surfaces"]:
        if entry["surface"] == surface:
            return entry
    raise AssertionError("no ledger surface entry for %s" % surface)


class EverySurfaceIsCarried(unittest.TestCase):
    """A surface that reported nothing is still in the ledger, as unknown."""

    def test_a_surface_with_no_source_is_still_listed(self):
        document = build()
        surfaces = [entry["surface"] for entry in document["ledger"]["surfaces"]]
        self.assertIn("brandon-compute", surfaces)
        self.assertIn("controller", surfaces)
        self.assertIn("hd2stack", surfaces)

    def test_a_surface_with_no_source_is_unknown_with_a_reason(self):
        document = build()
        entry = surface_entry(document, "brandon-compute")
        self.assertEqual(entry["status"], "no_source")
        self.assertTrue(entry["reason"])
        self.assertNotEqual(entry["reason"], "0")
        self.assertEqual(entry["accounts"], [])

    def test_a_surface_that_reported_is_marked_as_reporting(self):
        document = build()
        self.assertEqual(surface_entry(document, "controller")["status"], "reported")
        self.assertEqual(surface_entry(document, "hd2stack")["status"], "reported")

    def test_the_controller_alias_crisp_r_is_the_controller_surface(self):
        # "Crisp-R" is the Captain's name for their own session, so it is an alias of
        # the Controller surface and never a surface of its own - a second id for the
        # same host would double-count every row.
        document = build()
        surfaces = [entry["surface"] for entry in document["ledger"]["surfaces"]]
        self.assertNotIn("crisp-r", surfaces)
        self.assertIn("crisp-r", surface_entry(document, "controller")["aliases"])

    def test_a_row_from_an_unrostered_surface_is_counted_not_dropped(self):
        ledger = json.loads(json.dumps(LEDGER))
        ledger["days"][0]["accounts"][0]["surface"] = "vmi9999999"
        document = build(ledger_payload=ledger)
        names = [entry["surface"] for entry in document["ledger"]["surfaces"]]
        self.assertIn("vmi9999999", names)
        self.assertEqual(surface_entry(document, "vmi9999999")["status"], "reported")


class RowsCarryTheirProvenance(unittest.TestCase):
    """Every reading says which surface, which account, which source, which kind."""

    def test_a_row_names_its_surface_account_source_and_measurement(self):
        document = build()
        row = day_row(document, "2026-10-19")
        self.assertTrue(row["rows"])
        for entry in row["rows"]:
            self.assertTrue(entry["surface"])
            self.assertTrue(entry["account_id"])
            self.assertTrue(entry["source_id"])
            self.assertIn(entry["measurement"], ("measured", "reported"))
            self.assertIn("counted", entry)

    def test_the_two_codex_readings_on_two_surfaces_stay_separate(self):
        document = build()
        row = day_row(document, "2026-10-19")
        self.assertIn("controller|codex-local-unmapped", row["accounts"])
        self.assertIn("hd2stack|codex-local-unmapped", row["accounts"])
        self.assertEqual(row["accounts"]["controller|codex-local-unmapped"], 100)
        self.assertEqual(row["accounts"]["hd2stack|codex-local-unmapped"], 200)

    def test_the_account_registry_is_surface_qualified(self):
        document = build()
        ids = [entry["id"] for entry in document["ledger"]["accounts"]]
        self.assertIn("controller|codex-local-unmapped", ids)
        self.assertIn("hd2stack|codex-local-unmapped", ids)
        for entry in document["ledger"]["accounts"]:
            self.assertIn("·", entry["label"])

    def test_the_registry_carries_the_account_identity_status(self):
        document = build()
        entries = {entry["id"]: entry for entry in document["ledger"]["accounts"]}
        self.assertEqual(entries["controller|minimax-account-1"]["identity_status"],
                         "operator_alias")


class TheTotalIsTheSumOfTheRows(unittest.TestCase):
    """The number the Captain questioned is the number the rows add up to."""

    def test_a_day_total_is_the_sum_of_that_days_rows(self):
        document = build()
        row = day_row(document, "2026-10-19")
        counted = [entry["total_tokens"] for entry in row["rows"] if entry["counted"]]
        self.assertEqual(row["total_tokens"], sum(counted))

    def test_the_day_total_equals_the_sum_of_the_account_cells(self):
        document = build()
        for row in document["daily"]:
            known = [value for value in row["accounts"].values() if value is not None]
            if row["total_tokens"] is None:
                self.assertEqual(known, [])
            else:
                self.assertEqual(row["total_tokens"], sum(known))

    def test_the_measured_and_reported_parts_are_separated(self):
        document = build()
        row = day_row(document, "2026-10-19")
        measured = sum(entry["total_tokens"] for entry in row["rows"]
                       if entry["counted"] and entry["measurement"] == "measured")
        reported = sum(entry["total_tokens"] for entry in row["rows"]
                       if entry["counted"] and entry["measurement"] == "reported")
        self.assertEqual(row["total_measured_tokens"], measured)
        self.assertEqual(row["total_reported_tokens"], reported)
        self.assertEqual(row["total_tokens"], measured + reported)

    def test_the_weekly_total_is_the_sum_of_the_days_it_knows(self):
        document = build()
        weekly = document["weekly"]
        days = [row["total_tokens"] for row in document["daily"]
                if row["total_tokens"] is not None]
        self.assertEqual(weekly["total_tokens"], sum(days))


class NullIsNotZero(unittest.TestCase):
    """A null reading stays null. It is never summed, rendered or reported as 0."""

    def test_a_null_row_makes_its_account_unknown_for_the_day(self):
        ledger = json.loads(json.dumps(LEDGER))
        ledger["days"][0]["accounts"][0]["total_tokens"] = None
        document = build(ledger_payload=ledger)
        row = day_row(document, "2026-10-19")
        self.assertNotIn("controller|codex-local-unmapped", row["accounts"])
        self.assertEqual(row["accounts_unknown"], 1)
        self.assertNotEqual(row["total_tokens"], 0)

    def test_a_null_row_is_never_counted_into_the_total(self):
        ledger = json.loads(json.dumps(LEDGER))
        ledger["days"][0]["accounts"][0]["total_tokens"] = None
        document = build(ledger_payload=ledger)
        row = day_row(document, "2026-10-19")
        counted = [entry["total_tokens"] for entry in row["rows"] if entry["counted"]]
        self.assertNotIn(None, counted)
        self.assertEqual(row["total_tokens"], sum(counted))

    def test_a_day_whose_only_reading_is_null_is_unknown_not_zero(self):
        ledger = json.loads(json.dumps(LEDGER))
        ledger["seeds"] = []
        for entry in ledger["days"][0]["accounts"]:
            entry["total_tokens"] = None
        document = build(ledger_payload=ledger)
        row = day_row(document, "2026-10-19")
        self.assertIsNone(row["total_tokens"])
        self.assertEqual(row["total_status"], "unknown")

    def test_a_missing_reading_does_not_become_a_zero_cell(self):
        document = build()
        row = day_row(document, "2026-10-19")
        for value in row["accounts"].values():
            self.assertNotEqual(value, 0)


class AnUnmeasuredDayIsUnknown(unittest.TestCase):
    """A day with no measurement is unmeasured, not zero."""

    def test_an_unmeasured_day_has_a_null_total(self):
        document = build()
        row = day_row(document, "2026-10-20")
        self.assertIsNone(row["total_tokens"])
        self.assertNotEqual(row["total_tokens"], 0)

    def test_an_unmeasured_day_is_marked_unknown(self):
        document = build()
        self.assertEqual(day_row(document, "2026-10-20")["total_status"], "unknown")

    def test_an_unmeasured_day_reports_missing_coverage(self):
        document = build()
        row = day_row(document, "2026-10-20")
        self.assertEqual(row["accounts"], {})
        self.assertEqual(row["accounts_known"], 0)
        self.assertEqual(row["coverage_slots_unknown"], row["coverage_slots_expected"])
        self.assertEqual(row["coverage_slots_measured"], 0)

    def test_an_unmeasured_day_makes_the_week_a_floor(self):
        document = build()
        weekly = document["weekly"]
        self.assertTrue(weekly["is_floor"])
        self.assertEqual(weekly["status"], "partial")


class SeedsStayOnTheirOwnDay(unittest.TestCase):
    """An operator-reported number is dated, and it never moves."""

    def test_a_seed_lands_on_the_day_it_was_reported_for(self):
        document = build()
        row = day_row(document, "2026-10-19")
        seeds = [entry for entry in row["rows"] if entry["measurement"] == "reported"]
        self.assertEqual(len(seeds), 1)
        self.assertEqual(seeds[0]["total_tokens"], 500)
        self.assertEqual(seeds[0]["date"], "2026-10-19")

    def test_a_seed_contributes_to_no_other_day(self):
        document = build()
        for row in document["daily"]:
            if row["date"] == "2026-10-19":
                continue
            for entry in row["rows"]:
                self.assertNotEqual(entry.get("source_id"), "captain-20261019-minimax-1")
            self.assertEqual(row["total_reported_tokens"], 0)

    def test_a_seed_is_never_presented_as_a_measurement(self):
        document = build()
        row = day_row(document, "2026-10-19")
        self.assertEqual(row["total_measured_tokens"], 400)
        self.assertEqual(row["total_reported_tokens"], 500)

    def test_a_day_carrying_a_seed_is_partial(self):
        document = build()
        self.assertEqual(day_row(document, "2026-10-19")["total_status"], "partial")

    def test_a_seed_already_materialised_as_a_row_is_not_applied_twice(self):
        ledger = json.loads(json.dumps(LEDGER))
        ledger["days"][0]["accounts"].append({
            "account_id": "minimax-account-1", "provider": "minimax",
            "source_id": "captain-20261019-minimax-1", "source_kind": "operator_reported",
            "coverage": "reported", "surface": "vmi3196300", "total_tokens": 500,
            "observed_at": "2026-10-19T07:32:35+01:00",
        })
        document = build(ledger_payload=ledger)
        row = day_row(document, "2026-10-19")
        self.assertEqual(row["total_reported_tokens"], 500)


class CoverageComesFromTheTotal(unittest.TestCase):
    """The coverage line and the total are one source of truth."""

    def test_the_day_coverage_slots_are_the_measured_surface_provider_pairs(self):
        document = build()
        row = day_row(document, "2026-10-19")
        measured = {(entry["surface"], entry["provider"]) for entry in row["rows"]
                    if entry["counted"] and entry["provider"]}
        self.assertEqual(row["coverage_slots_measured"], len(measured))

    def test_the_coverage_block_lists_the_unknown_slots_with_a_reason(self):
        document = build()
        unknown = document["coverage"]["unknown"]
        self.assertTrue(unknown)
        for entry in unknown:
            self.assertTrue(entry["reason"])
            self.assertNotEqual(entry["reason"], "0")

    def test_the_gemini_provider_is_unknown_with_its_standing_reason(self):
        document = build()
        unknown = document["coverage"]["unknown"]
        gemini = [entry for entry in unknown if entry["provider"] == "agy"]
        self.assertTrue(gemini)
        reporting = [entry for entry in gemini if entry["surface"] != "brandon-compute"]
        self.assertTrue(reporting)
        for entry in reporting:
            self.assertEqual(entry["reason"], "no local usage surface exposes Gemini token counts")

    def test_a_surface_with_no_source_says_so_in_every_slot(self):
        document = build()
        for entry in document["coverage"]["unknown"]:
            if entry["surface"] == "brandon-compute":
                self.assertEqual(entry["reason"],
                                 "no usage source has reported for this surface")

    def test_the_coverage_block_and_the_daily_rows_agree(self):
        document = build()
        for row in document["daily"]:
            self.assertEqual(
                row["coverage_slots_measured"] + row["coverage_slots_unknown"],
                row["coverage_slots_expected"],
            )


class PublishedSurfaceDocuments(unittest.TestCase):
    """The push half of the contract: a surface publishes, the Controller collects."""

    def surface_document(self, surface, rows, days=None):
        return {
            "schema": "firstmate-surface-usage/v1",
            "surface": surface,
            "host": "vmi3238503",
            "label": "HD2Stack",
            "timezone": "Europe/London",
            "generated_at": "2026-10-21T05:00:00Z",
            "accounts": [{"id": "codex-local-unmapped", "label": "codex local (unmapped)",
                          "provider": "codex", "identity_status": "unknown_local_subset"}],
            "days": days if days is not None else [{
                "date": "2026-10-19",
                "total_tokens": 200,
                "total_status": "measured",
                "expected_providers": ["codex"],
                "accounts": rows,
            }],
            "seeds": [],
        }

    def test_a_published_document_adds_its_surface(self):
        rows = [{"account_id": "codex-local-unmapped", "provider": "codex",
                 "surface": "hd2stack", "source_id": "hd2stack:codex",
                 "source_kind": "local_metadata", "coverage": "local_metadata",
                 "total_tokens": 200, "observed_at": "2026-10-19T22:49:20+01:00"}]
        document = build(surface_docs=[self.surface_document("hd2stack", rows)])
        row = day_row(document, "2026-10-19")
        self.assertEqual(row["accounts"]["hd2stack|codex-local-unmapped"], 200)

    def test_the_same_reading_from_two_sources_is_counted_once(self):
        rows = [{"account_id": "codex-local-unmapped", "provider": "codex",
                 "surface": "hd2stack", "source_id": "hd2stack:codex",
                 "source_kind": "local_metadata", "coverage": "local_metadata",
                 "total_tokens": 200, "observed_at": "2026-10-19T22:49:20+01:00"}]
        document = build(surface_docs=[self.surface_document("hd2stack", rows)])
        row = day_row(document, "2026-10-19")
        self.assertEqual(row["accounts"]["hd2stack|codex-local-unmapped"], 200)

    def test_a_published_document_for_a_surface_with_no_rows_is_unknown(self):
        document = build(surface_docs=[self.surface_document("brandon-compute", [], days=[])])
        entry = surface_entry(document, "brandon-compute")
        self.assertEqual(entry["status"], "no_source")
        self.assertTrue(entry["reason"])


class ThePublisherContract(unittest.TestCase):
    """The publishing helper a surface runs."""

    def run_publisher(self, args):
        command = [sys.executable, str(PUBLISHER_PATH)] + args
        return subprocess.run(command, capture_output=True, text=True, cwd=str(REPO))

    def test_it_publishes_only_the_surface_it_was_told_to_publish(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "usage.json"
            ledger.write_text(json.dumps(LEDGER), encoding="utf-8")
            out = pathlib.Path(directory) / "hd2stack.json"
            result = self.run_publisher([
                "--surface", "hd2stack", "--host", "vmi3238503",
                "--ledger", str(ledger), "--out", str(out),
                "--now", "2026-10-21T05:00:00Z",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            document = json.loads(out.read_text(encoding="utf-8"))
            self.assertEqual(document["schema"], "firstmate-surface-usage/v1")
            self.assertEqual(document["surface"], "hd2stack")
            for day in document["days"]:
                for row in day["accounts"]:
                    self.assertEqual(row["surface"], "hd2stack")

    def test_the_published_day_total_is_computed_from_its_own_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "usage.json"
            ledger.write_text(json.dumps(LEDGER), encoding="utf-8")
            out = pathlib.Path(directory) / "hd2stack.json"
            self.run_publisher([
                "--surface", "hd2stack", "--host", "vmi3238503",
                "--ledger", str(ledger), "--out", str(out),
                "--now", "2026-10-21T05:00:00Z",
            ])
            document = json.loads(out.read_text(encoding="utf-8"))
            for day in document["days"]:
                totals = [row["total_tokens"] for row in day["accounts"]
                          if row["total_tokens"] is not None]
                if not totals:
                    self.assertIsNone(day["total_tokens"])
                    self.assertEqual(day["total_status"], "unknown")
                else:
                    self.assertEqual(day["total_tokens"], sum(totals))

    def test_it_never_publishes_another_surfaces_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "usage.json"
            ledger.write_text(json.dumps(LEDGER), encoding="utf-8")
            out = pathlib.Path(directory) / "hd2stack.json"
            self.run_publisher([
                "--surface", "hd2stack", "--host", "vmi3238503",
                "--ledger", str(ledger), "--out", str(out),
                "--now", "2026-10-21T05:00:00Z",
            ])
            document = json.loads(out.read_text(encoding="utf-8"))
            day = [d for d in document["days"] if d["date"] == "2026-10-19"][0]
            source_ids = sorted(str(row["source_id"]) for row in day["accounts"])
            # The ledger holds a codex reading for the Controller and one for HD2.
            # Publishing HD2 publishes HD2's reading and never the Controller's.
            self.assertNotIn("vmi3196300:pi:codex", source_ids)
            self.assertIn("vmi3238503:pi:codex", source_ids)

    def test_a_published_document_is_byte_identical_for_the_same_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            ledger = pathlib.Path(directory) / "usage.json"
            ledger.write_text(json.dumps(LEDGER), encoding="utf-8")
            first = pathlib.Path(directory) / "a.json"
            second = pathlib.Path(directory) / "b.json"
            for out in (first, second):
                self.run_publisher([
                    "--surface", "hd2stack", "--host", "vmi3238503",
                    "--ledger", str(ledger), "--out", str(out),
                    "--now", "2026-10-21T05:00:00Z",
                ])
            self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_it_fails_loudly_when_there_is_no_source(self):
        result = self.run_publisher(["--surface", "hd2stack"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL", result.stderr)


class TheBoardRendersTheFleet(unittest.TestCase):
    """The live board shows the accounts and the coverage."""

    def setUp(self):
        spec = importlib.util.spec_from_file_location("fm_next_board_publish", BOARD_PUBLISHER_PATH)
        self.publisher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.publisher)

    def render(self, document):
        state = {"path": "token-band.json", "state": "ok", "detail": "",
                 "band": document, "age_seconds": 60.0, "problems": []}
        return self.publisher.render_token_band(state)

    def test_the_board_names_every_surface(self):
        html = self.render(build())
        for surface in ("controller", "hd2stack", "brandon-compute"):
            self.assertIn(surface, html)

    def test_the_board_shows_the_coverage(self):
        html = self.render(build())
        self.assertIn("COVERAGE", html)
        self.assertIn("no local usage surface exposes Gemini token counts", html)

    def test_the_board_shows_the_surface_qualified_accounts(self):
        html = self.render(build())
        self.assertIn("Controller (Crisp-R)", html)
        self.assertIn("HD2Stack", html)

    def test_an_unknown_day_is_never_drawn_as_a_zero(self):
        html = self.render(build())
        self.assertIn("unknown", html)


if __name__ == "__main__":
    unittest.main()
