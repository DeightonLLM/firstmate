#!/usr/bin/env python3
"""
fm-token-usage-publish.py — publish THIS surface's token usage for the Controller.

The Captain asked for "all tokens used aggregated" across every surface and every
account (2026-10-21). The Controller can only aggregate what it can read, and it
cannot read another surface's disk. So each surface publishes its own usage document
and the Controller collects it. This script is the publishing half of that contract.

THE CONTRACT: `docs/token-usage-surface-contract.md`. The document it writes is
`firstmate-surface-usage/v1`; the Controller's collector reads exactly that shape.

WHAT THIS SCRIPT DOES AND DOES NOT DO

  * It reads a local usage ledger (the same shape the Controller's own tracker writes)
    and emits the rows that belong to THIS surface. It never invents a number: a day
    with no reading is published as unknown, not as zero.
  * It never publishes another surface's rows. A local ledger may hold several
    surfaces' readings; this script publishes only the one it was told to publish.
  * It never carries a seed forward. An operator-reported seed is published on the day
    it was reported for and on no other day.
  * It is deterministic: with a fixed `--now` the output is byte-identical.

WHERE A SURFACE PUTS THE RESULT

  * A surface with a shared filesystem writes the document into the collection point
    the Controller reads (`data/next-board-publish/surface-usage/` on the Controller).
  * A surface without one writes it into its own comms outbox, and the Controller is
    sent the collection request over the sanctioned comms route. The file is the
    delivery; the notification is not.

usage: fm-token-usage-publish.py --surface ID [--ledger PATH] [--rows PATH]
                                 [--host HOST] [--label TEXT] [--out PATH]
                                 [--now ISO]
"""
import argparse
import datetime as dt
import json
import os
import pathlib
import sys
import tempfile

sys.dont_write_bytecode = True

SCHEMA = "firstmate-surface-usage/v1"
FALLBACK_TIMEZONE = "UTC"


def parse_instant(text):
    """Parse an ISO-8601 instant into an aware UTC datetime, or None."""
    if not text or not isinstance(text, str):
        return None
    raw = text.strip()
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(raw)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def iso_utc(moment):
    """Format an aware datetime as `YYYY-MM-DDTHH:MM:SSZ` (UTC)."""
    return moment.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def as_int(value):
    """Return an int for a JSON number, or None. Never coerce None/absent to 0."""
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return None


def atomic_write(path, data, mode=0o644):
    """Write a file atomically. A reader never sees a half-written document."""
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix="." + path.name + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
        tmp = None
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)


def row_belongs_to(row, surface, host, ledger_surface):
    """Does this row belong to the surface being published?

    A row names its own surface, and that name is what decides. A row that names no
    surface belongs to the ledger's own surface, so it is published only when the
    ledger IS this surface.
    """
    named = row.get("surface")
    if not named:
        return str(ledger_surface or "") == str(surface)
    named = str(named)
    if named == str(surface):
        return True
    if host and named == str(host):
        return True
    return False


def build_document(source, surface, host, label, now, timezone=None):
    """Build this surface's usage document from a local ledger or rows file.

    Every day the source declared is published, even when it carries no rows: an
    unmeasured day is unknown, and the Controller has to be able to say so.

    The day's total is COMPUTED from the rows this surface published. The source's
    own day total is never carried over: it covers every surface the source held
    rows for, so reusing it would publish another surface's number as this
    surface's.
    """
    timezone = timezone or source.get("timezone") or FALLBACK_TIMEZONE
    ledger_surface = source.get("surface")
    accounts = []
    seen_accounts = set()
    for account in source.get("accounts") or []:
        if not isinstance(account, dict):
            continue
        account_id = account.get("id")
        if not account_id or account_id in seen_accounts:
            continue
        seen_accounts.add(account_id)
        accounts.append({
            "id": str(account_id),
            "label": account.get("label"),
            "provider": account.get("provider"),
            "identity_status": account.get("identity_status"),
        })
    accounts.sort(key=lambda row: row["id"])

    days = []
    for day in source.get("days") or []:
        if not isinstance(day, dict):
            continue
        date = day.get("date")
        if not date:
            continue
        rows = []
        for row in day.get("accounts") or []:
            if not isinstance(row, dict):
                continue
            account_id = row.get("account_id")
            if not account_id:
                continue
            if not row_belongs_to(row, surface, host, ledger_surface):
                continue
            rows.append({
                "account_id": str(account_id),
                "provider": row.get("provider"),
                "surface": surface,
                "source_id": row.get("source_id"),
                "source_kind": row.get("source_kind"),
                "coverage": row.get("coverage"),
                "total_tokens": as_int(row.get("total_tokens")),
                "observed_at": row.get("observed_at"),
            })
        rows.sort(key=lambda row: (str(row["account_id"]), str(row.get("source_id") or "")))
        expected = list(day.get("expected_providers") or [])
        total, status = day_total_for(rows, expected)
        days.append({
            "date": str(date),
            "total_tokens": total,
            "total_status": status,
            "expected_providers": expected,
            "accounts": rows,
        })
    days.sort(key=lambda row: row["date"])

    seeds = []
    for seed in source.get("seeds") or []:
        if not isinstance(seed, dict):
            continue
        if not seed.get("date") or not seed.get("account_id"):
            continue
        if not row_belongs_to(seed, surface, host, ledger_surface):
            continue
        seeds.append({
            "account_id": str(seed["account_id"]),
            "provider": seed.get("provider"),
            "date": str(seed["date"]),
            "source_id": seed.get("source_id"),
            "total_tokens": as_int(seed.get("total_tokens")),
            "observed_at": seed.get("observed_at"),
            "note": seed.get("note"),
        })
    seeds.sort(key=lambda row: (row["date"], row["account_id"], str(row.get("source_id") or "")))

    return {
        "schema": SCHEMA,
        "surface": surface,
        "host": host,
        "label": label or surface,
        "timezone": timezone,
        "generated_at": iso_utc(now),
        "accounts": accounts,
        "days": days,
        "seeds": seeds,
    }


def day_total_for(rows, expected_providers):
    """The day total computed from the rows this surface published.

    A day with no reading is unknown, not zero. A row with a null reading makes the
    day unknown too. A day whose rows do not cover the providers the source expected
    is partial, and a day that mixes instrumented readings with an operator's
    reported number is partial as well: its total is not one kind of number.
    """
    if not rows:
        return None, "unknown"
    totals = [row["total_tokens"] for row in rows]
    if any(total is None for total in totals):
        return None, "unknown"
    total = sum(int(value) for value in totals)
    providers = {str(row.get("provider")) for row in rows if row.get("provider")}
    reported = any(str(row.get("source_kind")) == "operator_reported" for row in rows)
    if expected_providers and not set(expected_providers).issubset(providers):
        return total, "partial"
    if reported:
        return total, "partial"
    return total, "measured"


def render_document(document):
    """Serialise the document: sorted keys, stable indent, trailing newline."""
    return json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Publish this surface's token usage document for the Controller.")
    parser.add_argument("--surface", required=True,
                        help="the surface id this document publishes (e.g. hd2stack)")
    parser.add_argument("--ledger", default=None,
                        help="the local usage ledger to publish from")
    parser.add_argument("--rows", default=None,
                        help="a rows file in the ledger's day/row shape, used when "
                             "the surface has no tracker ledger of its own")
    parser.add_argument("--host", default=None,
                        help="the host id this surface reports as")
    parser.add_argument("--label", default=None,
                        help="a human label for this surface")
    parser.add_argument("--out", default=None,
                        help="write the document here instead of printing it")
    parser.add_argument("--now", default=None,
                        help="override 'now' (ISO-8601) for a deterministic run")
    args = parser.parse_args(argv)

    if args.now:
        now = parse_instant(args.now)
        if now is None:
            print("fm-token-usage-publish: --now is not a valid ISO-8601 instant: %s" % args.now,
                  file=sys.stderr)
            return 2
    else:
        now = dt.datetime.now(dt.timezone.utc)

    source_path = args.ledger or args.rows
    if not source_path:
        print("fm-token-usage-publish: FAIL one of --ledger or --rows is required",
              file=sys.stderr)
        return 2
    try:
        raw = pathlib.Path(source_path).read_text(encoding="utf-8")
    except OSError as exc:
        print("fm-token-usage-publish: FAIL cannot read %s: %s" % (source_path, exc),
              file=sys.stderr)
        return 2
    try:
        source = json.loads(raw)
    except ValueError as exc:
        print("fm-token-usage-publish: FAIL %s is not valid JSON: %s" % (source_path, exc),
              file=sys.stderr)
        return 2
    if not isinstance(source, dict):
        print("fm-token-usage-publish: FAIL %s does not hold a JSON object" % source_path,
              file=sys.stderr)
        return 2

    host = args.host or source.get("surface") or source.get("host")
    document = build_document(source, args.surface, host, args.label, now)
    rendered = render_document(document)

    if args.out:
        atomic_write(pathlib.Path(args.out), rendered)
        print("fm-token-usage-publish: wrote %s surface=%s days=%d accounts=%d" % (
            args.out, document["surface"], len(document["days"]), len(document["accounts"])))
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    sys.exit(main())
