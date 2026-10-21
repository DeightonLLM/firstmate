#!/usr/bin/env python3
"""
fm-token-collect.py — collect the Captain's token band from the two real sources.

The Captain asked for token aggregation "all account weekly and daily usage heat map
roll over etc.". Two real sources on this host hold that truth, and neither was being
read:

  1. `quota-axi --json --full --no-credential-refresh` — the live quota window of every
     provider account (percent remaining / used, reset instants, pace, projected
     exhaustion). It is the ONLY quota source, and it is read with credential refresh
     switched off. No other network call is made.
  2. `data/tracker-tokens-20261019/ledger/usage.json` — the per-account token usage
     ledger: one entry per day, each day carrying per-account rows.

This script turns those two into ONE document: `data/next-board-publish/token-band.json`,
the shape owned by `docs/next-board-token-and-chat-contract.md` (Contract A). The
renderer is a different lane; this file only produces the document.

THE RULES THAT BIND (contract section 1):

  * null != zero. An unknown value stays `null` and is labelled. It is never summed,
    rendered or reported as `0`. The ledger says the same about itself: `null` is
    unknown, a partial day is partial, coverage must be reported.
  * One source per field. Quota comes from quota-axi, usage comes from the ledger.
    Neither re-reduces the other's counters.
  * Fail open, never fail silently. A source that cannot be read still produces the
    document: that source's block carries `ok: false` plus an `error` string, and the
    OTHER source's data is still emitted.
  * Deterministic output. Sorted keys, sorted rows, no invented timestamps inside the
    data (only `generated_at`). With a fixed `--now` the output is byte-identical.

THE REPO ROOT IS THE SCRIPT'S OWN ROOT. `<repo-root>` is resolved from this file's
location, so running it inside a lane worktree writes inside THAT worktree and never
into the live runtime directory. A lane must never publish into the live home.

usage: fm-token-collect.py [--out PATH] [--ledger PATH] [--max-age SECONDS] [--force]
                           [--quota-json PATH] [--now ISO]
"""
import argparse
import datetime as dt
import json
import os
import pathlib
import subprocess
import sys
import tempfile

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - Python < 3.9 fallback
    ZoneInfo = None

sys.dont_write_bytecode = True

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_OUT_REL = "data/next-board-publish/token-band.json"
DEFAULT_LEDGER_REL = "data/tracker-tokens-20261019/ledger/usage.json"

SCHEMA = "firstmate-token-band/v1"
QUOTA_COMMAND = ["quota-axi", "--json", "--full", "--no-credential-refresh"]
QUOTA_TIMEOUT_SECONDS = 180
WINDOW_DAYS = 7
FALLBACK_TIMEZONE = "UTC"


# --------------------------------------------------------------------- small helpers

def iso_utc(moment):
    """Format an aware datetime as `YYYY-MM-DDTHH:MM:SSZ` (UTC)."""
    return moment.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


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


def as_int(value):
    """Return an int for a JSON number, or None. Never coerce None/absent to 0."""
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return None


def seconds_until(resets_at_text, now):
    """Seconds from `now` until the reset instant. Negative when already past."""
    instant = parse_instant(resets_at_text)
    if instant is None:
        return None
    return int((instant - now).total_seconds())


def relative_display(path, root):
    """Path relative to the repo root when it lives inside it, else absolute."""
    resolved = pathlib.Path(path).resolve()
    try:
        return str(resolved.relative_to(root))
    except ValueError:
        return str(resolved)


def atomic_write(path, data, mode=0o644):
    """Write a file atomically. A reader never sees a half-written band."""
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


# ------------------------------------------------------------------- the quota source

def read_quota_payload(quota_json_path=None):
    """Read the quota windows.

    Returns `(payload, error)`. Exactly one of the two is None. `payload` is the parsed
    quota-axi JSON; `error` is a human string saying why the source could not be read.
    """
    if quota_json_path:
        try:
            text = pathlib.Path(quota_json_path).read_text(encoding="utf-8")
        except OSError as exc:
            return None, "quota json unreadable at %s: %s" % (quota_json_path, exc)
        try:
            return json.loads(text), None
        except ValueError as exc:
            return None, "quota json invalid at %s: %s" % (quota_json_path, exc)
    try:
        proc = subprocess.run(
            QUOTA_COMMAND,
            capture_output=True,
            text=True,
            timeout=QUOTA_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return None, "quota-axi failed to run: %s" % exc
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return None, "quota-axi exited %d: %s" % (proc.returncode, detail[-1] if detail else "no output")
    try:
        return json.loads(proc.stdout), None
    except ValueError as exc:
        return None, "quota-axi returned invalid json: %s" % exc


def _effective_availability(provider):
    """The provider's effectiveAvailability entries, as a list (never None)."""
    semantics = provider.get("quotaSemantics") or {}
    entries = semantics.get("effectiveAvailability") or []
    return [entry for entry in entries if isinstance(entry, dict)]


def _runway_entry(provider, window_id):
    """The effectiveAvailability entry that speaks for this window.

    Primary rule (contract 2.1): the entry whose `limitingWindowIds` names the window.
    Fallback: the entry whose own `runway.limitingWindowId` names the window, which is
    how a provider reports the runway of a window that bounds the whole account.
    Returns None when no entry applies - the window then carries `runway_status: null`,
    which is unknown, not zero.
    """
    entries = _effective_availability(provider)
    for entry in entries:
        if window_id in (entry.get("limitingWindowIds") or []):
            return entry
    for entry in entries:
        runway = entry.get("runway") or {}
        if runway.get("limitingWindowId") == window_id:
            return entry
    return None


def _provider_state(provider):
    state = provider.get("state") or {}
    return state


def _window_label(provider_label, window_label, reset_day, duplicated):
    """`<provider label> - <window label>`.

    When one provider reports the same window id more than once, the label carries the
    reset day so the two rows are distinguishable on screen.
    """
    label = "%s - %s" % (provider_label, window_label)
    if duplicated:
        label = "%s (%s)" % (label, reset_day)
    return label


def build_quota_block(payload, now, error=None):
    """Build the `quota` block of Contract A.

    One row per (provider, window id, reset day). quota-axi can report the same window
    id twice with different reset instants - those are TWO accounts/windows and are
    never merged or de-duplicated here.
    """
    block = {
        "ok": False,
        "error": None,
        "source_command": list(QUOTA_COMMAND),
        "source_generated_at": None,
        "windows": [],
        "providers_without_windows": [],
    }
    if payload is None:
        block["error"] = error or "quota source unavailable"
        return block

    block["ok"] = True
    block["source_generated_at"] = payload.get("generatedAt")

    rows = []
    without_windows = []
    for provider in payload.get("providers") or []:
        if not isinstance(provider, dict):
            continue
        provider_id = provider.get("provider")
        provider_label = provider.get("label") or provider_id
        plan = provider.get("plan")
        state = _provider_state(provider)
        state_status = state.get("status")
        state_stale = state.get("stale")
        state_stale = bool(state_stale) if state_stale is not None else False
        state_error = state.get("error")
        account = provider.get("account") or {}
        account_id = account.get("accountId")
        account_email = account.get("email")
        account_keys = provider.get("accountKeys") or []

        windows = [w for w in (provider.get("windows") or []) if isinstance(w, dict)]
        if not windows:
            without_windows.append({
                "provider": provider_id,
                "state": state_status,
                "error": state_error,
                "not_set_up": bool(provider.get("notSetUp")) if provider.get("notSetUp") is not None else False,
            })
            continue

        id_counts = {}
        for window in windows:
            wid = window.get("id")
            id_counts[wid] = id_counts.get(wid, 0) + 1

        used_keys = {}
        for window in windows:
            window_id = window.get("id")
            window_label = window.get("label") or window_id
            resets_at = window.get("resetsAt")
            reset_day = resets_at[:10] if isinstance(resets_at, str) and resets_at else "no-reset"
            key = "%s|%s|%s" % (provider_id, window_id, reset_day)
            if key in used_keys:
                # Same provider, same window id, same reset day. Still two rows: they
                # are never merged. The key gets a stable ordinal so both survive.
                used_keys[key] += 1
                key = "%s|%d" % (key, used_keys[key])
            else:
                used_keys[key] = 1

            pace = window.get("pace") or {}
            runway_entry = _runway_entry(provider, window_id)
            runway = (runway_entry or {}).get("runway") or {}
            projected = pace.get("projectedExhaustedAt")
            if projected is None:
                projected = runway.get("projectedExhaustedAt")

            rows.append({
                "key": key,
                "provider": provider_id,
                "provider_label": provider_label,
                "plan": plan,
                "account_id": account_id,
                "account_email": account_email,
                "account_keys": list(account_keys),
                "window_id": window_id,
                "window_label": window_label,
                "kind": window.get("kind"),
                "label": _window_label(provider_label, window_label, reset_day, id_counts.get(window_id, 0) > 1),
                "percent_remaining": as_int(window.get("percentRemaining")),
                "percent_used": as_int(window.get("percentUsed")),
                "resets_at": resets_at,
                "window_seconds": as_int(window.get("windowSeconds")),
                "resets_in_seconds": seconds_until(resets_at, now),
                "pace_status": pace.get("status"),
                "projected_exhausted_at": projected,
                "runway_status": runway.get("status"),
                "state": state_status,
                "stale": state_stale,
                "error": state_error,
            })

    # Deterministic order: provider, then window id, then reset instant. Two rows of
    # the same window id sit next to each other so the pair is easy to read.
    rows.sort(key=lambda row: (str(row["provider"]), str(row["window_id"]),
                               str(row["resets_at"] or ""), row["key"]))
    without_windows.sort(key=lambda row: str(row["provider"]))
    block["windows"] = rows
    block["providers_without_windows"] = without_windows
    return block


def build_rollover(windows):
    """The rollover timeline: one row per quota window, sorted by reset instant.

    A window with no `resets_at` is not a rollover and is omitted. A rollover returns
    its window to full, so `restores_percent` is 100.
    """
    rows = []
    for window in windows:
        resets_at = window.get("resets_at")
        if not resets_at:
            continue
        rows.append({
            "key": window.get("key"),
            "provider": window.get("provider"),
            "window_id": window.get("window_id"),
            "kind": window.get("kind"),
            "label": window.get("label"),
            "resets_at": resets_at,
            "resets_in_seconds": window.get("resets_in_seconds"),
            "percent_remaining": window.get("percent_remaining"),
            "restores_percent": 100,
        })
    rows.sort(key=lambda row: (str(row["resets_at"]), str(row["key"])))
    return rows


# ------------------------------------------------------------------ the ledger source

def read_ledger_payload(path):
    """Read the usage ledger. Returns `(payload, error)`; exactly one is None."""
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        return None, "ledger unreadable at %s: %s" % (path, exc)
    try:
        return json.loads(text), None
    except ValueError as exc:
        return None, "ledger invalid json at %s: %s" % (path, exc)


def _ledger_accounts(payload):
    """The ledger's account registry, as a list of plain dicts."""
    rows = []
    for account in payload.get("accounts") or []:
        if not isinstance(account, dict):
            continue
        rows.append({
            "id": account.get("id"),
            "label": account.get("label"),
            "provider": account.get("provider"),
            "identity_status": account.get("identity_status"),
        })
    rows.sort(key=lambda row: str(row["id"]))
    return rows


def _day_account_cells(day):
    """Per-account totals for one ledger day.

    A day can hold SEVERAL rows for ONE account (different `source_id`s); they are
    summed into that account's day cell. A row whose total is null makes that
    account UNKNOWN for the day - the cell stays null rather than pretending the
    other rows were the whole truth. Rows under `unmapped` are not part of the day's
    measured total, so they are not part of the account map either.
    """
    totals = {}
    unknown = set()
    for row in day.get("accounts") or []:
        if not isinstance(row, dict):
            continue
        account_id = row.get("account_id")
        if not account_id:
            continue
        total = as_int(row.get("total_tokens"))
        if total is None:
            unknown.add(account_id)
            continue
        totals[account_id] = totals.get(account_id, 0) + total
    for account_id in unknown:
        totals.pop(account_id, None)
    return totals, unknown


def _expected_account_ids(ledger_accounts, day):
    """The accounts this day expected to measure.

    The ledger states which providers it expected (`expected_providers`); the registry
    maps a provider to its account ids. Those accounts, plus any account actually seen
    in the day's rows, are the candidates for coverage.
    """
    expected_providers = day.get("expected_providers")
    if not expected_providers:
        return set()
    expected = set(expected_providers)
    return {
        account["id"] for account in ledger_accounts
        if account.get("id") and account.get("provider") in expected
    }


def build_ledger_block(payload, path_display, error=None):
    """Build the `ledger` block of Contract A."""
    block = {
        "ok": False,
        "error": None,
        "path": path_display,
        "contract_version": None,
        "timezone": None,
        "surface": None,
        "generated_at": None,
        "accounts": [],
    }
    if payload is None:
        block["error"] = error or "ledger source unavailable"
        return block
    block["ok"] = True
    block["contract_version"] = as_int(payload.get("contract_version"))
    block["timezone"] = payload.get("timezone")
    block["surface"] = payload.get("surface")
    block["generated_at"] = payload.get("generated_at")
    block["accounts"] = _ledger_accounts(payload)
    return block


def build_daily_rows(payload):
    """One row per ledger day, ascending by date.

    A day whose total is null stays null with `total_status: "unknown"`; a partial
    day keeps `total_status: "partial"`. An account with no reading for that day is
    simply absent from the map - absent is not zero.
    """
    rows = []
    if payload is None:
        return rows
    ledger_accounts = _ledger_accounts(payload)
    for day in payload.get("days") or []:
        if not isinstance(day, dict):
            continue
        cells, unknown = _day_account_cells(day)
        seen = set(cells) | unknown
        candidates = _expected_account_ids(ledger_accounts, day) | seen
        accounts_known = len(cells)
        accounts_unknown = len(candidates - set(cells))
        total = as_int(day.get("total_tokens"))
        if total is None:
            total_status = day.get("total_status") or "unknown"
        else:
            total_status = day.get("total_status") or "measured"
        rows.append({
            "date": day.get("date"),
            "total_tokens": total,
            "total_status": total_status,
            "accounts": {key: cells[key] for key in sorted(cells)},
            "accounts_known": accounts_known,
            "accounts_unknown": accounts_unknown,
        })
    rows.sort(key=lambda row: str(row["date"]))
    return rows


def build_weekly(payload, today):
    """The 7-calendar-day window ending today, in the ledger's timezone.

    It sums ONLY days with a known total. When any day in the window is unknown or
    missing, `total_tokens` is a FLOOR: `is_floor: true` and `status: "partial"` (or
    `"unknown"` when nothing in the window is known). The renderer must say "at least
    N" whenever `is_floor` is true.
    """
    weekly = {
        "start_date": None,
        "end_date": None,
        "days_expected": WINDOW_DAYS,
        "days_known": 0,
        "days_unknown": WINDOW_DAYS,
        "total_tokens": None,
        "status": "unknown",
        "is_floor": True,
        "per_account": {},
        "per_account_known_days": {},
    }
    if payload is None:
        return weekly

    end = today
    start = end - dt.timedelta(days=WINDOW_DAYS - 1)
    weekly["start_date"] = start.isoformat()
    weekly["end_date"] = end.isoformat()

    by_date = {}
    for day in payload.get("days") or []:
        if isinstance(day, dict) and day.get("date"):
            by_date[day["date"]] = day

    per_account = {}
    per_account_days = {}
    total = 0
    days_known = 0
    for offset in range(WINDOW_DAYS):
        day_date = (start + dt.timedelta(days=offset)).isoformat()
        day = by_date.get(day_date)
        if day is None:
            # A calendar day with no ledger entry is UNKNOWN, not zero.
            continue
        day_total = as_int(day.get("total_tokens"))
        if day_total is not None:
            total += day_total
            days_known += 1
        cells, _unknown = _day_account_cells(day)
        for account_id, value in cells.items():
            per_account[account_id] = per_account.get(account_id, 0) + value
            per_account_days[account_id] = per_account_days.get(account_id, 0) + 1

    days_unknown = WINDOW_DAYS - days_known
    weekly["days_known"] = days_known
    weekly["days_unknown"] = days_unknown
    weekly["is_floor"] = days_unknown > 0
    if days_known == WINDOW_DAYS:
        weekly["total_tokens"] = total
        weekly["status"] = "measured"
    elif days_known > 0:
        weekly["total_tokens"] = total
        weekly["status"] = "partial"
    else:
        weekly["total_tokens"] = None
        weekly["status"] = "unknown"
    weekly["per_account"] = {key: per_account[key] for key in sorted(per_account)}
    weekly["per_account_known_days"] = {key: per_account_days[key] for key in sorted(per_account_days)}
    return weekly


# ------------------------------------------------------------------- the whole band

def build_band(quota_payload, ledger_payload, now, ledger_path_display,
                quota_error=None, ledger_error=None):
    """Assemble the Contract A document from whatever the two sources gave us."""
    quota = build_quota_block(quota_payload, now, error=quota_error)
    ledger = build_ledger_block(ledger_payload, ledger_path_display, error=ledger_error)
    daily = build_daily_rows(ledger_payload)
    weekly = build_weekly(ledger_payload, _local_today(now, ledger_payload))
    rollover = build_rollover(quota.get("windows") or [])

    errors = []
    if not quota.get("ok"):
        errors.append("quota: %s" % quota.get("error"))
    if not ledger.get("ok"):
        errors.append("ledger: %s" % ledger.get("error"))

    return {
        "schema": SCHEMA,
        "generated_at": iso_utc(now),
        "errors": errors,
        "quota": quota,
        "ledger": ledger,
        "daily": daily,
        "weekly": weekly,
        "rollover": rollover,
    }


def _local_today(now, ledger_payload):
    """Today, in the ledger's timezone.

    The weekly window is the 7 calendar days ending today in the ledger's timezone,
    so 'today' must be the ledger's today, not UTC's.
    """
    name = (ledger_payload or {}).get("timezone") or FALLBACK_TIMEZONE
    if ZoneInfo is not None:
        try:
            return now.astimezone(ZoneInfo(name)).date()
        except Exception:
            pass
    return now.astimezone(dt.timezone.utc).date()


def render_document(document):
    """Serialise the band: sorted keys, stable indent, trailing newline."""
    return json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


# ------------------------------------------------------------------------- the CLI

def output_is_fresh(path, max_age_seconds, now):
    """True when the existing output is younger than the bound."""
    if max_age_seconds is None:
        return False
    try:
        stat = os.stat(path)
    except OSError:
        return False
    age = (now.timestamp() - stat.st_mtime)
    return age < max_age_seconds


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Collect the Captain's token band from quota-axi and the usage ledger.")
    parser.add_argument("--out", default=None,
                        help="output path (default: <repo-root>/%s)" % DEFAULT_OUT_REL)
    parser.add_argument("--ledger", default=None,
                        help="usage ledger path (default: <repo-root>/%s)" % DEFAULT_LEDGER_REL)
    parser.add_argument("--max-age", type=float, default=None,
                        help="skip the refresh when the existing output is younger than this many seconds")
    parser.add_argument("--force", action="store_true",
                        help="ignore --max-age and refresh even when the output is fresh")
    parser.add_argument("--quota-json", default=None,
                        help="read the quota payload from this local file instead of running quota-axi")
    parser.add_argument("--now", default=None,
                        help="override 'now' (ISO-8601) for a deterministic run")
    args = parser.parse_args(argv)

    if args.now:
        now = parse_instant(args.now)
        if now is None:
            print("fm-token-collect: --now is not a valid ISO-8601 instant: %s" % args.now,
                  file=sys.stderr)
            return 2
    else:
        now = dt.datetime.now(dt.timezone.utc)

    out_path = pathlib.Path(args.out).resolve() if args.out else (REPO_ROOT / DEFAULT_OUT_REL)
    ledger_path = pathlib.Path(args.ledger).resolve() if args.ledger else (REPO_ROOT / DEFAULT_LEDGER_REL)

    if not args.force and output_is_fresh(out_path, args.max_age, now):
        try:
            stat = os.stat(out_path)
            age = int(now.timestamp() - stat.st_mtime)
        except OSError:
            age = 0
        print("fm-token-collect: skipped refresh, %s is %ds old (max-age %ds)" % (
            out_path, age, int(args.max_age)))
        return 0

    quota_payload, quota_error = read_quota_payload(args.quota_json)
    ledger_payload, ledger_error = read_ledger_payload(ledger_path)

    document = build_band(
        quota_payload,
        ledger_payload,
        now,
        relative_display(ledger_path, REPO_ROOT),
        quota_error=quota_error,
        ledger_error=ledger_error,
    )
    atomic_write(out_path, render_document(document))

    weekly = document["weekly"]
    total = weekly["total_tokens"]
    if total is None:
        weekly_text = "unknown"
    elif weekly["is_floor"]:
        weekly_text = "at least %d (floor)" % total
    else:
        weekly_text = "%d" % total
    print("fm-token-collect: wrote %s quota=%s windows=%d providers_without_windows=%d "
          "ledger=%s days=%d weekly=%s days_known=%d/%d errors=%d" % (
              out_path,
              "ok" if document["quota"]["ok"] else "failed",
              len(document["quota"]["windows"]),
              len(document["quota"]["providers_without_windows"]),
              "ok" if document["ledger"]["ok"] else "failed",
              len(document["daily"]),
              weekly_text,
              weekly["days_known"],
              weekly["days_expected"],
              len(document["errors"]),
          ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
