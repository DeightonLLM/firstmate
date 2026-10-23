#!/usr/bin/env python3
"""
fm-token-collect.py — collect the Captain's token band from the two real sources.

The Captain asked for token aggregation "all account weekly and daily usage heat map
roll over etc." and then, on 2026-10-21, for "all tokens used aggregated" across
EVERY surface and EVERY account. Two real sources hold that truth, and neither was
being read whole:

  1. `quota-axi --json --full --no-credential-refresh` — the live quota window of every
     provider account (percent remaining / used, reset instants, pace, projected
     exhaustion). It is the ONLY quota source, and it is read with credential refresh
     switched off. No other network call is made.
  2. The usage ledgers — per-account token usage rows, one row per surface, account
     and day. The Controller's own ledger is `data/tracker-tokens-20261019/ledger/usage.json`.
     Every other surface publishes its own usage document (the push contract in
     `docs/token-usage-surface-contract.md`), and this collector collects them.

This script turns those into ONE document: `data/next-board-publish/token-band.json`,
the shape owned by `docs/next-board-token-and-chat-contract.md` (Contract A, v2). The
renderer is a different lane; this file only produces the document.

THE RULES THAT BIND (contract section 1):

  * null != zero. An unknown value stays `null` and is labelled. It is never summed,
    rendered or reported as `0`. The ledger says the same about itself: `null` is
    unknown, a partial day is partial, coverage must be reported.
  * One source per field. Quota comes from quota-axi, usage comes from the usage
    sources. Neither re-reduces the other's counters.
  * Fail open, never fail silently. A source that cannot be read still produces the
    document: that source's block carries `ok: false` plus an `error` string, and the
    OTHER source's data is still emitted. A surface that reported nothing is emitted
    as unknown coverage with a reason — never as a zero, and never dropped.
  * Age is not identity. The band's own `schema` says which collector wrote it, so a
    band that carries another collector's schema is recollected even when its mtime is
    fresh. Without that rule a superseded collector's band survives an install and
    keeps being published as if it were current.
  * Deterministic output. Sorted keys, sorted rows, no invented timestamps inside the
    data (only `generated_at`). With a fixed `--now` the output is byte-identical.

THE REPO ROOT IS THE SCRIPT'S OWN ROOT. `<repo-root>` is resolved from this file's
location, so running it inside a lane worktree writes inside THAT worktree and never
into the live runtime directory. A lane must never publish into the live home.

usage: fm-token-collect.py [--out PATH] [--ledger PATH] [--max-age SECONDS] [--force]
                           [--quota-json PATH] [--now ISO]
                           [--roster PATH] [--surface-dir PATH] [--surface-usage PATH]
                           [--print-schema]
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

_SELF = pathlib.Path(__file__).resolve()
REPO_ROOT = _SELF.parent.parent
# The collector is installed into the runtime directory beside the board it
# feeds, so there it sits two levels below the repo root instead of one. The
# root is resolved the same way wherever the script runs, so the installed
# copy and the tracked copy read the same ledger and write the same band.
if _SELF.parent.name == "next-board-publish":
    REPO_ROOT = _SELF.parent.parent.parent
DEFAULT_OUT_REL = "data/next-board-publish/token-band.json"
DEFAULT_LEDGER_REL = "data/tracker-tokens-20261019/ledger/usage.json"
DEFAULT_ROSTER_REL = "docs/system-context/token-usage-surfaces.json"
DEFAULT_SURFACE_DIR_REL = "data/next-board-publish/surface-usage"

SCHEMA = "firstmate-token-band/v2"
SURFACE_USAGE_SCHEMA = "firstmate-surface-usage/v1"
QUOTA_COMMAND = ["quota-axi", "--json", "--full", "--no-credential-refresh"]
QUOTA_TIMEOUT_SECONDS = 180
WINDOW_DAYS = 7
FALLBACK_TIMEZONE = "UTC"

# A row's measurement kind. `measured` came from an instrumented source;
# `reported` came from a human and is dated to the day it was reported for.
MEASURED = "measured"
REPORTED = "reported"


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


def read_json_file(path):
    """Read a JSON document. Returns `(payload, error)`; exactly one is None."""
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        return None, "unreadable at %s: %s" % (path, exc)
    try:
        return json.loads(text), None
    except ValueError as exc:
        return None, "invalid json at %s: %s" % (path, exc)


def read_ledger_payload(path):
    """Read the owner usage ledger. Returns `(payload, error)`; exactly one is None."""
    payload, error = read_json_file(path)
    if error:
        return None, "ledger %s" % error
    if not isinstance(payload, dict):
        return None, "ledger invalid at %s: not a JSON object" % path
    return payload, None


# ------------------------------------------------------------------- the quota source

def read_quota_payload(quota_json_path=None):
    """Read the quota windows.

    Returns `(payload, error)`. Exactly one of the two is None. `payload` is the parsed
    quota-axi JSON; `error` is a human string saying why the source could not be read.
    """
    if quota_json_path:
        payload, error = read_json_file(quota_json_path)
        if error:
            return None, "quota json %s" % error
        return payload, None
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


# ----------------------------------------------------------------- the surface roster

def read_roster(path):
    """Read the fleet surface roster. Returns `(payload, error)`; one of them is None."""
    payload, error = read_json_file(path)
    if error:
        return None, "surface roster %s" % error
    if not isinstance(payload, dict):
        return None, "surface roster invalid at %s: not a JSON object" % path
    return payload, None


def roster_surfaces(roster):
    """The roster's surface entries, normalised and sorted.

    Each entry keeps the aliases a source may use to name that surface: the surface
    id itself, its host, and any declared alias. A source that reports a host id is
    therefore attributed to the surface that owns that host.
    """
    rows = []
    for entry in (roster or {}).get("surfaces") or []:
        if not isinstance(entry, dict):
            continue
        surface = entry.get("surface")
        if not surface:
            continue
        aliases = set()
        for key in ("surface", "host"):
            value = entry.get(key)
            if value:
                aliases.add(str(value))
        for alias in entry.get("aliases") or []:
            if alias:
                aliases.add(str(alias))
        rows.append({
            "surface": str(surface),
            "label": str(entry.get("label") or surface),
            "host": entry.get("host"),
            "aliases": sorted(aliases),
            "role": entry.get("role"),
            "expected_providers": sorted({str(p) for p in (entry.get("expected_providers") or []) if p}),
            "collection": entry.get("collection") or {},
            "notes": entry.get("notes"),
        })
    rows.sort(key=lambda row: row["surface"])
    return rows


def resolve_surface(surfaces, observed):
    """Map an observed surface token to a roster surface id.

    Returns `(surface_id, known)`. An observed token that no roster entry claims is
    still carried - under its own name - so a row from an unrostered surface is
    counted rather than dropped. `known` is False in that case, which is how the
    band says "this reading is from a surface the roster does not name".
    """
    token = str(observed or "").strip()
    if not token:
        return None, False
    for entry in surfaces:
        if token == entry["surface"] or token in entry["aliases"]:
            return entry["surface"], True
    return token, False


def roster_provider_labels(roster):
    """Provider id -> the label the roster gives it."""
    labels = {}
    for provider, label in ((roster or {}).get("provider_labels") or {}).items():
        if provider and label:
            labels[str(provider)] = str(label)
    return labels


def roster_provider_notes(roster):
    """Provider id -> the durable reason its usage is not measurable, when there is one.

    A note here is not a guess about a number. It is the standing explanation of why
    no surface can report that provider's token counts, so an unknown coverage slot
    says WHY it is unknown instead of only that it is.
    """
    notes = {}
    for provider, note in ((roster or {}).get("provider_notes") or {}).items():
        if provider and note:
            notes[str(provider)] = str(note)
    return notes


# ------------------------------------------------------------------ the usage sources

def _row_measurement(row):
    """How a row was obtained: measured by an instrument, or reported by a human."""
    source_kind = str(row.get("source_kind") or "")
    coverage = str(row.get("coverage") or "")
    if source_kind == "operator_reported" or coverage == "reported":
        return REPORTED
    return MEASURED


def _make_row(surface, surface_host, observed_surface_known, date, account_id, provider,
              source_id, source_kind, total, observed_at, coverage, measurement, reason=None,
              origin=None, origin_path=None):
    """One usage row with its full provenance.

    A row's provenance is what makes the aggregation auditable: which surface reported
    it, which account identity it belongs to, which source produced it, and whether it
    was measured or reported by a human.
    """
    return {
        "date": date,
        "surface": surface,
        "surface_host": surface_host,
        "surface_known": observed_surface_known,
        "account_id": account_id,
        "provider": provider,
        "source_id": source_id,
        "source_kind": source_kind,
        "measurement": measurement,
        "coverage": coverage,
        "total_tokens": total,
        "observed_at": observed_at,
        "reason": reason,
        "origin": origin,
        "origin_path": origin_path,
    }


def rows_from_ledger(ledger_payload, surfaces, errors, origin_path=None):
    """The usage rows carried by a ledger document.

    Every row names the surface it came from: the row's own `surface` field when it
    has one, the ledger's declared surface otherwise. A ledger that claims one
    surface while carrying another surface's rows is not trusted - the rows win.

    Seeds are applied ONLY to the day they were reported for. A seed whose source id
    already appears among the day's rows is not applied twice: the ledger has already
    materialised it, and applying it again would double-count the operator's number.
    """
    rows = []
    if not isinstance(ledger_payload, dict):
        return rows
    ledger_surface = ledger_payload.get("surface")
    used_source_ids = set()
    for day in ledger_payload.get("days") or []:
        if not isinstance(day, dict):
            continue
        date = day.get("date")
        if not date:
            continue
        for row in day.get("accounts") or []:
            if not isinstance(row, dict):
                continue
            account_id = row.get("account_id")
            if not account_id:
                continue
            source_id = row.get("source_id")
            if source_id:
                used_source_ids.add(str(source_id))
            observed = row.get("surface") or ledger_surface
            if not observed:
                errors.append("ledger row for %s names no surface and cannot be attributed" % date)
                continue
            surface, known = resolve_surface(surfaces, observed)
            rows.append(_make_row(
                surface=surface,
                surface_host=str(observed),
                observed_surface_known=known,
                date=str(date),
                account_id=str(account_id),
                provider=row.get("provider"),
                source_id=source_id,
                source_kind=row.get("source_kind"),
                total=as_int(row.get("total_tokens")),
                observed_at=row.get("observed_at"),
                coverage=row.get("coverage"),
                measurement=_row_measurement(row),
                origin="owner_ledger",
                origin_path=origin_path,
            ))
    # Seeds: operator-reported, dated, and never re-applied as a future day.
    for seed in ledger_payload.get("seeds") or []:
        if not isinstance(seed, dict):
            continue
        date = seed.get("date")
        account_id = seed.get("account_id")
        source_id = seed.get("source_id")
        if not date or not account_id:
            errors.append("ledger seed without a date or an account cannot be applied")
            continue
        if source_id and str(source_id) in used_source_ids:
            # Already materialised as a day row. Applying it again would count the
            # operator's number twice.
            continue
        observed = seed.get("surface") or ledger_surface
        if not observed:
            errors.append("ledger seed for %s names no surface and cannot be attributed" % date)
            continue
        surface, known = resolve_surface(surfaces, observed)
        rows.append(_make_row(
            surface=surface,
            surface_host=str(observed),
            observed_surface_known=known,
            date=str(date),
            account_id=str(account_id),
            provider=seed.get("provider"),
            source_id=source_id,
            source_kind="operator_reported",
            total=as_int(seed.get("total_tokens")),
            observed_at=seed.get("observed_at"),
            coverage="reported",
            measurement=REPORTED,
            reason=seed.get("note"),
            origin="owner_ledger",
            origin_path=origin_path,
        ))
    return rows


def rows_from_surface_doc(document, surfaces, errors, origin_path=None):
    """The usage rows carried by a published surface-usage document.

    A surface publishes only its own rows. A document that names rows for another
    surface is still honoured row by row - each row is attributed to the surface its
    own `surface` field names - but the document's declared surface is the default.
    """
    rows = []
    if not isinstance(document, dict):
        return rows
    declared = document.get("surface")
    for day in document.get("days") or []:
        if not isinstance(day, dict):
            continue
        date = day.get("date")
        if not date:
            continue
        for row in day.get("accounts") or []:
            if not isinstance(row, dict):
                continue
            account_id = row.get("account_id")
            if not account_id:
                continue
            observed = row.get("surface") or declared
            if not observed:
                errors.append("published usage row for %s names no surface" % date)
                continue
            surface, known = resolve_surface(surfaces, observed)
            rows.append(_make_row(
                surface=surface,
                surface_host=str(observed),
                observed_surface_known=known,
                date=str(date),
                account_id=str(account_id),
                provider=row.get("provider"),
                source_id=row.get("source_id"),
                source_kind=row.get("source_kind"),
                total=as_int(row.get("total_tokens")),
                observed_at=row.get("observed_at"),
                coverage=row.get("coverage"),
                measurement=_row_measurement(row),
                origin="published_surface_usage",
                origin_path=origin_path,
            ))
    return rows


def merge_rows(row_groups):
    """Merge row groups into one deduplicated, deterministically ordered row list.

    A row's identity is (surface, date, account, source id). A repeated identity is
    the same reading twice - idempotent re-publication - so it is kept once. When the
    two readings disagree, the later observation wins and the conflict is reported
    instead of being silently averaged away.
    """
    merged = {}
    conflicts = []
    for rows in row_groups:
        for row in rows:
            key = (str(row["surface"]), str(row["date"]), str(row["account_id"]),
                   str(row.get("source_id") or ""))
            existing = merged.get(key)
            if existing is None:
                merged[key] = row
                continue
            if _origin_rank(row) > _origin_rank(existing):
                # The same reading from a better origin: the surface's own published
                # document outranks the Controller's earlier snapshot of it.
                merged[key] = row
                existing = row
            if existing.get("total_tokens") == row.get("total_tokens"):
                # The same reading twice. Keep the one that was kept.
                continue
            existing_stamp = parse_instant(existing.get("observed_at"))
            new_stamp = parse_instant(row.get("observed_at"))
            newer = row
            if existing_stamp is not None and new_stamp is not None and new_stamp < existing_stamp:
                newer = existing
            conflicts.append({
                "key": "|".join(key),
                "kept_total_tokens": newer.get("total_tokens"),
                "dropped_total_tokens": (existing if newer is row else row).get("total_tokens"),
                "reason": "two readings share one identity and disagree; the later observation was kept",
            })
            merged[key] = newer
    rows = list(merged.values())
    rows.sort(key=lambda row: (str(row["date"]), str(row["surface"]),
                               str(row["account_id"]), str(row.get("source_id") or "")))
    return shadow_by_origin(rows, conflicts)


# Which origin wins when the same reading arrives twice. A surface's own published
# document is its most recent statement about itself, so it outranks the Controller's
# earlier snapshot of the same account.
ORIGIN_PRIORITY = ("published_surface_usage", "owner_ledger")


def _origin_rank(row):
    """How much a row's origin is trusted when two sources carry one reading."""
    origin = str(row.get("origin") or "")
    try:
        return ORIGIN_PRIORITY.index(origin)
    except ValueError:
        return -1


def shadow_by_origin(rows, conflicts):
    """Keep one origin per account cell.

    The same reading can reach the Controller twice: once in the owner ledger and
    once in a surface's own published document, under different source ids. Summing
    both would count one day's usage twice. One cell therefore carries one origin:
    the published document wins, and the shadowed reading is reported rather than
    dropped in silence.
    """
    groups = {}
    for row in rows:
        key = (str(row["surface"]), str(row["date"]), str(row["account_id"]))
        groups.setdefault(key, []).append(row)
    kept = []
    for key in sorted(groups):
        group = groups[key]
        origins = {str(row.get("origin") or "") for row in group}
        if len(origins) <= 1:
            kept.extend(group)
            continue
        winner = None
        for candidate in ORIGIN_PRIORITY:
            if candidate in origins:
                winner = candidate
                break
        if winner is None:
            winner = sorted(origins)[0]
        for row in group:
            if str(row.get("origin") or "") == winner:
                kept.append(row)
                continue
            conflicts.append({
                "key": "|".join(key),
                "kept_origin": winner,
                "shadowed_origin": row.get("origin"),
                "shadowed_total_tokens": row.get("total_tokens"),
                "reason": "the same account-day arrived from two sources; the owning "
                          "surface's published document was kept and the other reading was shadowed",
            })
    kept.sort(key=lambda row: (str(row["date"]), str(row["surface"]),
                               str(row["account_id"]), str(row.get("source_id") or "")))
    return kept, conflicts


def demote_covered_by_reported(rows, covered):
    """A reported total covers the measured subset of the SAME provider on the SAME day.

    The ledger applies this rule inside one store: a measured local subset whose
    provider already has an operator-reported total is surfaced as `unmapped` and
    is never added to the additive total, because the reported number already
    covers it. The very same reading can also arrive from another surface's own
    published document, so the rule has to hold across stores too. Without it the
    reported number and the measured subset are added together and one day's
    usage is counted twice.

    The demoted reading is REPORTED, never dropped in silence: the band carries
    it under `ledger.covered_by_reported` with its total, so a reader can see
    exactly how much is being held back and why.
    """
    reported = set()
    for row in rows:
        if row.get("measurement") == REPORTED:
            reported.add((str(row["date"]), str(row.get("provider") or "")))
    if not reported:
        return rows
    kept = []
    for row in rows:
        key = (str(row["date"]), str(row.get("provider") or ""))
        if row.get("measurement") != REPORTED and key in reported:
            covered.append({
                "key": "|".join((str(row["surface"]), str(row["date"]),
                                 str(row.get("provider") or ""), str(row["account_id"]))),
                "surface": row["surface"],
                "date": str(row["date"]),
                "provider": row.get("provider"),
                "account_id": row["account_id"],
                "source_id": row.get("source_id"),
                "covered_total_tokens": row.get("total_tokens"),
                "reason": "an operator-reported total for this provider on this day already "
                          "covers this measured subset, so the subset is shown as covered "
                          "rather than added to the total",
            })
            continue
        kept.append(row)
    covered.sort(key=lambda entry: (entry["date"], entry["surface"], entry["account_id"]))
    return kept


def index_cells(rows):
    """The account cells: (surface, account, date) -> the account's reading.

    A cell's value is the sum of its rows. A cell with any null row is UNKNOWN: the
    reading is incomplete, so the cell stays null rather than pretending the other
    rows were the whole truth. Absent is not zero either way.
    """
    cells = {}
    for row in rows:
        key = (str(row["surface"]), str(row["account_id"]), str(row["date"]))
        cell = cells.setdefault(key, {"value": None, "rows": [], "unknown": False})
        cell["rows"].append(row)
        total = row.get("total_tokens")
        if total is None:
            cell["unknown"] = True
        else:
            cell["value"] = (cell["value"] or 0) + int(total)
    for cell in cells.values():
        if cell["unknown"]:
            cell["value"] = None
    return cells


# --------------------------------------------------------------- the daily aggregation

def _surface_status(surfaces, rows, source_info):
    """Per-surface reporting state: did it report, and if not, why not.

    A surface that reported nothing is carried with the reason it reported nothing.
    That reason is the honest answer to "where are the other hosts' tokens".
    """
    status = {}
    for entry in surfaces:
        status[entry["surface"]] = {
            "surface": entry["surface"],
            "label": entry["label"],
            "host": entry["host"],
            "aliases": entry["aliases"],
            "role": entry["role"],
            "expected_providers": list(entry["expected_providers"]),
            "notes": entry.get("notes"),
            "has_source": False,
            "source_kind": None,
            "source_path": None,
            "observed_at": None,
            "reason": None,
            "dates": set(),
        }
    for row in rows:
        state = status.get(row["surface"])
        if state is None:
            state = {
                "surface": row["surface"], "label": row["surface"], "host": row.get("surface_host"),
                "aliases": [], "role": "unrostered", "expected_providers": [], "notes": None,
                "has_source": False, "source_kind": None, "source_path": None,
                "observed_at": None, "reason": None, "dates": set(),
            }
            status[row["surface"]] = state
        state["has_source"] = True
        state["dates"].add(str(row["date"]))
        if row.get("origin"):
            state["source_kind"] = row["origin"]
            state["source_path"] = row.get("origin_path")
            state["observed_at"] = row.get("observed_at")
    for info in source_info:
        state = status.get(info["surface"])
        if state is None:
            continue
        if info.get("status") == "ok":
            state["source_kind"] = info.get("source_kind")
            state["source_path"] = info.get("path")
            state["observed_at"] = info.get("observed_at")
        elif state["reason"] is None:
            state["reason"] = info.get("reason")
    for state in status.values():
        if not state["has_source"] and state["reason"] is None:
            state["reason"] = "no usage source has reported for this surface"
    return status


def _coverage_slots(surfaces, cells, date, status, provider_notes=None):
    """The coverage slots for one date: (surface, provider) and what is known of them.

    A slot is the unit the Captain thinks in: one provider on one surface. A slot is
    measured when at least one account of that provider on that surface has a reading
    for the date; otherwise it is unknown, and it carries the reason.
    """
    provider_notes = provider_notes or {}
    slots = {}
    for entry in surfaces:
        for provider in entry["expected_providers"]:
            slots[(entry["surface"], provider)] = {
                "expected": True, "observed": False, "measured": False, "accounts": set(),
            }
    for (surface, account_id, cell_date), cell in cells.items():
        if cell_date != date:
            continue
        for row in cell["rows"]:
            provider = row.get("provider")
            if not provider:
                continue
            key = (surface, str(provider))
            slot = slots.setdefault(key, {
                "expected": False, "observed": False, "measured": False, "accounts": set(),
            })
            slot["observed"] = True
            slot["accounts"].add(str(account_id))
            if cell["value"] is not None:
                slot["measured"] = True
    out = []
    for (surface, provider), slot in slots.items():
        measured = bool(slot.get("measured"))
        state = status.get(surface) or {}
        note = provider_notes.get(provider)
        if measured:
            reason = None
        elif not state.get("has_source"):
            reason = state.get("reason") or "no usage source has reported for this surface"
        elif note:
            reason = note
        elif date not in (state.get("dates") or set()):
            reason = "this surface reported no usage for %s" % date
        else:
            reason = "this surface reported usage on %s but none for %s" % (date, provider)
        out.append({
            "surface": surface,
            "provider": provider,
            "status": "measured" if measured else "unknown",
            "reason": reason,
            "accounts": sorted(slot["accounts"]),
        })
    out.sort(key=lambda slot: (str(slot["surface"]), str(slot["provider"])))
    return out


def build_daily_rows(rows, cells, surfaces, status, dates, source_days=None, provider_notes=None):
    """One row per day, ascending by date.

    A day's total is the sum of that day's KNOWN account cells. A cell with a null
    reading is unknown and contributes nothing; a day with no known cell at all has a
    null total and an unknown status. The day's coverage comes from the same cells,
    so the coverage line and the total can never disagree.

    `source_days` carries what each source declared about its own days. The declared
    status is kept alongside the computed one so a source that called a day unknown
    is visible even when the rows say otherwise.
    """
    out = []
    for date in sorted(dates):
        day_cells = {}
        for (surface, account_id, cell_date), cell in cells.items():
            if cell_date != date:
                continue
            day_cells["%s|%s" % (surface, account_id)] = cell
        known = {key: cell["value"] for key, cell in day_cells.items() if cell["value"] is not None}
        unknown_cells = {key: cell for key, cell in day_cells.items() if cell["value"] is None}
        slots = _coverage_slots(surfaces, cells, date, status, provider_notes)
        measured_slots = [slot for slot in slots if slot["status"] == "measured"]
        unknown_slots = [slot for slot in slots if slot["status"] != "measured"]

        day_rows = []
        for cell in day_cells.values():
            for row in cell["rows"]:
                counted = cell["value"] is not None and row.get("total_tokens") is not None
                day_rows.append({
                    "date": row["date"],
                    "surface": row["surface"],
                    "surface_host": row.get("surface_host"),
                    "account_id": row["account_id"],
                    "provider": row.get("provider"),
                    "source_id": row.get("source_id"),
                    "source_kind": row.get("source_kind"),
                    "measurement": row.get("measurement"),
                    "coverage": row.get("coverage"),
                    "total_tokens": row.get("total_tokens"),
                    "observed_at": row.get("observed_at"),
                    "counted": counted,
                    "reason": row.get("reason"),
                })
        day_rows.sort(key=lambda row: (str(row["surface"]), str(row["account_id"]),
                                       str(row.get("source_id") or "")))

        total = sum(known.values()) if known else None
        reported_total = sum(int(row["total_tokens"]) for row in day_rows
                              if row["measurement"] == REPORTED and row["counted"])
        measured_total = sum(int(row["total_tokens"]) for row in day_rows
                              if row["measurement"] == MEASURED and row["counted"])
        if total is None:
            total_status = "unknown"
        elif unknown_slots or unknown_cells or reported_total:
            total_status = "partial"
        else:
            total_status = "measured"

        per_surface = {}
        for cell_key, cell in day_cells.items():
            surface = cell_key.split("|", 1)[0]
            entry = per_surface.setdefault(surface, {"total_tokens": 0, "accounts_known": 0,
                                                      "accounts_unknown": 0, "measured": False})
            if cell["value"] is None:
                entry["accounts_unknown"] += 1
            else:
                entry["total_tokens"] += cell["value"]
                entry["accounts_known"] += 1
                entry["measured"] = True
        for slot in slots:
            entry = per_surface.setdefault(slot["surface"], {"total_tokens": 0, "accounts_known": 0,
                                                             "accounts_unknown": 0, "measured": False})
            if slot["status"] != "measured":
                entry["accounts_unknown"] += 1

        out.append({
            "date": date,
            "total_tokens": total,
            "total_status": total_status,
            "total_measured_tokens": measured_total,
            "total_reported_tokens": reported_total,
            "source_total_status": (source_days or {}).get(date, {}).get("total_status"),
            "accounts": {key: known[key] for key in sorted(known)},
            "accounts_known": len(known),
            "accounts_unknown": len(unknown_cells),
            "coverage_slots_expected": len(slots),
            "coverage_slots_measured": len(measured_slots),
            "coverage_slots_unknown": len(unknown_slots),
            "rows": day_rows,
            "surfaces": {surface: per_surface[surface] for surface in sorted(per_surface)},
        })
    return out


def build_weekly(daily_rows, today):
    """The 7-calendar-day window ending today, in the ledger's timezone.

    It sums ONLY days with a known total. When any day in the window is unknown,
    missing or partial, `total_tokens` is a FLOOR: `is_floor: true` and
    `status: "partial"` (or `"unknown"` when nothing in the window is known). The
    renderer must say "at least N" whenever `is_floor` is true.
    """
    weekly = {
        "start_date": None,
        "end_date": None,
        "days_expected": WINDOW_DAYS,
        "days_known": 0,
        "days_unknown": WINDOW_DAYS,
        "total_tokens": None,
        "total_measured_tokens": None,
        "total_reported_tokens": None,
        "status": "unknown",
        "is_floor": True,
        "per_account": {},
        "per_account_known_days": {},
        "per_surface": {},
    }
    end = today
    start = end - dt.timedelta(days=WINDOW_DAYS - 1)
    weekly["start_date"] = start.isoformat()
    weekly["end_date"] = end.isoformat()

    by_date = {str(row["date"]): row for row in daily_rows}
    per_account = {}
    per_account_days = {}
    per_surface = {}
    total = 0
    measured_total = 0
    reported_total = 0
    days_known = 0
    days_partial = 0
    for offset in range(WINDOW_DAYS):
        day_date = (start + dt.timedelta(days=offset)).isoformat()
        day = by_date.get(day_date)
        if day is None:
            # A calendar day with no ledger entry is UNKNOWN, not zero.
            continue
        day_total = as_int(day.get("total_tokens"))
        if day_total is not None:
            total += day_total
            measured_total += int(day.get("total_measured_tokens") or 0)
            reported_total += int(day.get("total_reported_tokens") or 0)
            days_known += 1
        if day.get("total_status") == "partial":
            days_partial += 1
        for account_id, value in (day.get("accounts") or {}).items():
            per_account[account_id] = per_account.get(account_id, 0) + value
            per_account_days[account_id] = per_account_days.get(account_id, 0) + 1
        for surface, entry in (day.get("surfaces") or {}).items():
            state = per_surface.setdefault(surface, {"total_tokens": 0, "days_known": 0,
                                                     "days_partial": 0, "accounts_known": 0,
                                                     "accounts_unknown": 0})
            if day_total is not None and entry.get("measured"):
                state["total_tokens"] += int(entry.get("total_tokens") or 0)
                state["days_known"] += 1
            state["accounts_known"] += int(entry.get("accounts_known") or 0)
            state["accounts_unknown"] += int(entry.get("accounts_unknown") or 0)
            if day.get("total_status") == "partial":
                state["days_partial"] += 1

    days_unknown = WINDOW_DAYS - days_known
    weekly["days_known"] = days_known
    weekly["days_unknown"] = days_unknown
    weekly["is_floor"] = days_unknown > 0 or days_partial > 0
    if days_known == WINDOW_DAYS and days_partial == 0:
        weekly["total_tokens"] = total
        weekly["status"] = "measured"
    elif days_known > 0:
        weekly["total_tokens"] = total
        weekly["status"] = "partial"
    else:
        weekly["total_tokens"] = None
        weekly["status"] = "unknown"
    weekly["total_measured_tokens"] = measured_total if days_known else None
    weekly["total_reported_tokens"] = reported_total if days_known else None
    weekly["per_account"] = {key: per_account[key] for key in sorted(per_account)}
    weekly["per_account_known_days"] = {key: per_account_days[key] for key in sorted(per_account_days)}
    weekly["per_surface"] = {surface: per_surface[surface] for surface in sorted(per_surface)}
    return weekly


def build_coverage(surfaces, status, provider_labels, rows, provider_notes=None):
    """The fleet coverage: which surfaces and providers are covered, and what is not.

    This is the answer to "which accounts are covered and which are unknown". It is
    computed from the same rows that produce the totals, so the two can never drift.
    A provider that a surface is expected to use but never reported is listed as
    unknown with the reason, never as a zero.
    """
    provider_notes = provider_notes or {}
    observed = {}
    for row in rows:
        provider = row.get("provider")
        if not provider:
            continue
        key = (str(row["surface"]), str(provider))
        entry = observed.setdefault(key, {"accounts": set(), "measured": False, "dates": set()})
        entry["accounts"].add(str(row["account_id"]))
        entry["dates"].add(str(row["date"]))
        if row.get("total_tokens") is not None:
            entry["measured"] = True

    entries = []
    for surface in sorted(status):
        state = status[surface]
        providers = {}
        for provider in state.get("expected_providers") or []:
            providers[provider] = {"expected": True, "observed": False, "measured": False,
                                    "accounts": set()}
        for (row_surface, provider), entry in observed.items():
            if row_surface != surface:
                continue
            slot = providers.setdefault(provider, {"expected": False, "observed": False,
                                                    "measured": False, "accounts": set()})
            slot["observed"] = True
            slot["measured"] = slot["measured"] or entry["measured"]
            slot["accounts"] |= entry["accounts"]
        provider_rows = []
        for provider in sorted(providers):
            slot = providers[provider]
            if slot["measured"]:
                reason = None
            elif not state.get("has_source"):
                reason = state.get("reason") or "no usage source has reported for this surface"
            elif provider_notes.get(provider):
                reason = provider_notes[provider]
            else:
                reason = "no reading for %s on any day this surface reported" % provider
            provider_rows.append({
                "provider": provider,
                "label": provider_labels.get(provider, provider),
                "status": "measured" if slot["measured"] else "unknown",
                "reason": reason,
                "expected": slot["expected"],
                "accounts": sorted(slot["accounts"]),
            })
        entries.append({
            "surface": surface,
            "label": state.get("label") or surface,
            "host": state.get("host"),
            "aliases": state.get("aliases") or [],
            "role": state.get("role"),
            "status": "reported" if state.get("has_source") else "no_source",
            "reason": state.get("reason"),
            "source_kind": state.get("source_kind"),
            "source_path": state.get("source_path"),
            "observed_at": state.get("observed_at"),
            "days_reported": sorted(state.get("dates") or set()),
            "providers": provider_rows,
        })
    return {
        "surfaces": entries,
        "unknown": [
            {
                "surface": entry["surface"],
                "provider": provider["provider"],
                "reason": provider["reason"],
            }
            for entry in entries
            for provider in entry["providers"]
            if provider["status"] != "measured"
        ],
    }


def build_account_registry(status, source_accounts, rows, cells):
    """The fleet's account registry: one entry per (surface, account) cell.

    The cell id is `<surface>|<account>`, which is the key every map in the band uses,
    so a reading is never attributed to the wrong surface. The label carries the
    surface, because two surfaces can hold the same local account name.
    """
    registry = {}
    for row in rows:
        cell_key = "%s|%s" % (row["surface"], row["account_id"])
        if cell_key in registry:
            continue
        account_id = str(row["account_id"])
        source = source_accounts.get(account_id) or {}
        surface_label = (status.get(row["surface"]) or {}).get("label") or row["surface"]
        registry[cell_key] = {
            "id": cell_key,
            "account_id": account_id,
            "surface": row["surface"],
            "provider": row.get("provider") or source.get("provider"),
            "label": "%s · %s" % (surface_label, source.get("label") or account_id),
            "identity_status": source.get("identity_status"),
            "status": "measured",
            "reason": None,
        }
    for cell_key, entry in registry.items():
        surface, account_id = cell_key.split("|", 1)
        readings = [cell for (cell_surface, cell_account, _date), cell in cells.items()
                    if cell_surface == surface and cell_account == account_id]
        if not any(cell["value"] is not None for cell in readings):
            entry["status"] = "unknown"
            entry["reason"] = "no reading for this account on any reported day"
    return [registry[key] for key in sorted(registry)]


# --------------------------------------------------------------- the whole band

def build_band(quota_payload, ledger_payload, now, ledger_path_display,
               roster=None, surface_docs=None, quota_error=None, ledger_error=None,
               roster_error=None, surface_sources=None):
    """Assemble the Contract A document from whatever the sources gave us.

    `roster` is the fleet surface roster: it names every coding surface and the
    providers each is expected to report, so a surface that reported nothing shows
    up as unknown coverage instead of quietly missing from the total. `roster=None`
    declares NO expectations, which is a different band from a roster that expects
    nothing - the CLI always passes the fleet roster.
    """
    quota = build_quota_block(quota_payload, now, error=quota_error)
    surfaces = roster_surfaces(roster)
    provider_labels = roster_provider_labels(roster)
    provider_notes = roster_provider_notes(roster)

    errors = []
    if not quota.get("ok"):
        errors.append("quota: %s" % quota.get("error"))
    if not ledger_payload:
        errors.append("ledger: %s" % (ledger_error or "ledger source unavailable"))
    if roster_error:
        errors.append("roster: %s" % roster_error)

    ledger_rows = rows_from_ledger(ledger_payload, surfaces, errors, ledger_path_display) if ledger_payload else []
    doc_rows = []
    source_accounts = {}
    for entry in (surface_docs or []):
        if isinstance(entry, tuple):
            document, origin_path = entry
        else:
            document, origin_path = entry, None
        doc_rows.extend(rows_from_surface_doc(document, surfaces, errors, origin_path))
        for account in document.get("accounts") or []:
            if isinstance(account, dict) and account.get("id"):
                source_accounts.setdefault(str(account["id"]), account)
    for account in (ledger_payload or {}).get("accounts") or []:
        if isinstance(account, dict) and account.get("id"):
            source_accounts.setdefault(str(account["id"]), account)
    rows, conflicts = merge_rows([ledger_rows, doc_rows])

    covered = []
    rows = demote_covered_by_reported(rows, covered)

    source_info = list(surface_sources or [])
    status = _surface_status(surfaces, rows, source_info)

    cells = index_cells(rows)

    dates = set(str(row["date"]) for row in rows)
    # A day a source declared but carried no rows for is UNMEASURED, not absent: it
    # belongs in the band as an unknown day, so the coverage line can say so.
    source_days = {}
    source_documents = ([ledger_payload] if ledger_payload else []) + [
        entry[0] if isinstance(entry, tuple) else entry for entry in (surface_docs or [])]
    for document in source_documents:
        for day in document.get("days") or []:
            if not isinstance(day, dict) or not day.get("date"):
                continue
            dates.add(str(day["date"]))
            source_days.setdefault(str(day["date"]), {})["total_status"] = day.get("total_status")
    daily = build_daily_rows(rows, cells, surfaces, status, sorted(dates), source_days, provider_notes)
    weekly = build_weekly(daily, _local_today(now, ledger_payload))
    rollover = build_rollover(quota.get("windows") or [])
    coverage = build_coverage(surfaces, status, provider_labels, rows, provider_notes)
    accounts = build_account_registry(status, source_accounts, rows, cells)

    ledger = {
        "ok": bool(ledger_payload),
        "error": None if ledger_payload else (ledger_error or "ledger source unavailable"),
        "path": ledger_path_display,
        "contract_version": 2,
        "timezone": (ledger_payload or {}).get("timezone"),
        "surface": (ledger_payload or {}).get("surface"),
        "generated_at": (ledger_payload or {}).get("generated_at"),
        "roster_path": None,
        "accounts": accounts,
        "surfaces": [],
        "sources": [],
        "conflicts": conflicts,
        "covered_by_reported": covered,
    }
    for entry in coverage["surfaces"]:
        ledger["surfaces"].append({
            "surface": entry["surface"],
            "label": entry["label"],
            "host": entry["host"],
            "aliases": entry["aliases"],
            "role": entry["role"],
            "status": entry["status"],
            "reason": entry["reason"],
            "source_kind": entry["source_kind"],
            "source_path": entry["source_path"],
            "observed_at": entry["observed_at"],
            "days_reported": entry["days_reported"],
            "expected_providers": [provider["provider"] for provider in entry["providers"]],
            "accounts": sorted({row["account_id"] for row in rows if row["surface"] == entry["surface"]}),
        })
    for info in source_info:
        ledger["sources"].append({
            "surface": info.get("surface"),
            "source_kind": info.get("source_kind"),
            "path": info.get("path"),
            "status": info.get("status"),
            "reason": info.get("reason"),
            "observed_at": info.get("observed_at"),
        })
    ledger["sources"].sort(key=lambda row: (str(row["surface"]), str(row["path"])))

    return {
        "schema": SCHEMA,
        "generated_at": iso_utc(now),
        "errors": errors,
        "quota": quota,
        "ledger": ledger,
        "daily": daily,
        "weekly": weekly,
        "coverage": coverage,
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

def output_age_seconds(path, now):
    """How old the output file is in seconds, or None when it cannot be read."""
    try:
        stat = os.stat(path)
    except OSError:
        return None
    return now.timestamp() - stat.st_mtime


def band_schema(path):
    """The schema the band document on disk carries, or None when it cannot be read.

    The schema IS the producer's identity: a band written by a superseded
    collector carries that collector's schema, whatever its mtime says.
    """
    payload, error = read_json_file(path)
    if error or not isinstance(payload, dict):
        return None
    schema = payload.get("schema")
    return schema if isinstance(schema, str) else None


def output_is_fresh(path, max_age_seconds, now, expected_schema=None):
    """True only when the existing output is young enough AND this collector wrote it.

    Age alone is not identity. A band produced by a superseded collector can carry a
    fresh mtime while its content belongs to the old collector — that is exactly how
    the live board kept serving a v1 band after the v2 collector had been installed.
    The band's own `schema` is the producer's identity, so a band that does not carry
    this collector's schema is never skipped: it is recollected.
    """
    if max_age_seconds is None:
        return False
    age = output_age_seconds(path, now)
    if age is None or age >= max_age_seconds:
        return False
    if expected_schema is None:
        expected_schema = SCHEMA
    return band_schema(path) == expected_schema


def load_surface_documents(surface_dir, explicit_paths, errors):
    """The published surface-usage documents the Controller collects.

    Returns `(documents, source_info)`. A document that is missing, malformed or
    carries the wrong schema is reported, not skipped: a surface that published
    nothing usable is unknown coverage with a reason.
    """
    documents = []
    source_info = []
    candidates = []
    if surface_dir:
        directory = pathlib.Path(surface_dir)
        if directory.is_dir():
            for path in sorted(directory.glob("*.json")):
                candidates.append((path, None))
        elif directory.exists():
            errors.append("surface usage directory is not a directory: %s" % directory)
    for path in (explicit_paths or []):
        candidates.append((pathlib.Path(path), None))

    seen = set()
    for path, _ in candidates:
        resolved = str(path)
        if resolved in seen:
            continue
        seen.add(resolved)
        payload, error = read_json_file(path)
        if error:
            source_info.append({
                "surface": path.stem,
                "source_kind": "published_surface_usage",
                "path": resolved,
                "status": "failed",
                "reason": "published usage document %s" % error,
                "observed_at": None,
            })
            continue
        if not isinstance(payload, dict):
            source_info.append({
                "surface": path.stem,
                "source_kind": "published_surface_usage",
                "path": resolved,
                "status": "failed",
                "reason": "published usage document %s is not a JSON object" % path,
                "observed_at": None,
            })
            continue
        schema = payload.get("schema")
        if schema != SURFACE_USAGE_SCHEMA:
            source_info.append({
                "surface": payload.get("surface") or path.stem,
                "source_kind": "published_surface_usage",
                "path": resolved,
                "status": "failed",
                "reason": "published usage document %s has schema %s, expected %s" % (
                    path, schema, SURFACE_USAGE_SCHEMA),
                "observed_at": payload.get("generated_at"),
            })
            continue
        documents.append((payload, resolved))
        source_info.append({
            "surface": payload.get("surface") or path.stem,
            "source_kind": "published_surface_usage",
            "path": resolved,
            "status": "ok",
            "reason": None,
            "observed_at": payload.get("generated_at"),
        })
    return documents, source_info


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Collect the Captain's token band from quota-axi and the usage ledgers.")
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
    parser.add_argument("--roster", default=None,
                        help="surface roster path (default: <repo-root>/%s)" % DEFAULT_ROSTER_REL)
    parser.add_argument("--surface-dir", default=None,
                        help="directory of published surface usage documents (default: <repo-root>/%s)"
                             % DEFAULT_SURFACE_DIR_REL)
    parser.add_argument("--surface-usage", action="append", default=None,
                        help="one published surface usage document to collect (repeatable)")
    parser.add_argument("--print-schema", action="store_true",
                        help="print the schema this collector writes and exit")
    args = parser.parse_args(argv)

    if args.print_schema:
        # The one place the schema is spelled out. Everything that needs to know
        # what this collector writes - the install script, the publisher - asks
        # here instead of keeping a second copy of the string.
        print(SCHEMA)
        return 0

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
    roster_path = pathlib.Path(args.roster).resolve() if args.roster else (REPO_ROOT / DEFAULT_ROSTER_REL)
    surface_dir = pathlib.Path(args.surface_dir).resolve() if args.surface_dir else (REPO_ROOT / DEFAULT_SURFACE_DIR_REL)

    if not args.force and args.max_age is not None:
        age = output_age_seconds(out_path, now)
        if output_is_fresh(out_path, args.max_age, now):
            print("fm-token-collect: skipped refresh, %s is %ds old (max-age %ds) schema=%s" % (
                out_path, int(age or 0), int(args.max_age), SCHEMA))
            return 0
        if age is not None and age < args.max_age:
            # Young enough to skip, but not written by this collector. The band is
            # recollected: a document from a superseded collector is never served
            # just because it happens to be new enough.
            sys.stderr.write(
                "fm-token-collect: refreshing, %s carries schema %s and this collector writes %s - "
                "a band from a superseded collector is never served\n" % (
                    out_path, band_schema(out_path) or "none", SCHEMA))

    errors = []
    quota_payload, quota_error = read_quota_payload(args.quota_json)
    ledger_payload, ledger_error = read_ledger_payload(ledger_path)
    roster, roster_error = read_roster(roster_path)
    surface_docs, surface_info = load_surface_documents(surface_dir, args.surface_usage, errors)

    ledger_source_info = []
    if ledger_payload:
        ledger_source_info.append({
            "surface": ledger_payload.get("surface"),
            "source_kind": "owner_ledger",
            "path": relative_display(ledger_path, REPO_ROOT),
            "status": "ok",
            "reason": None,
            "observed_at": ledger_payload.get("generated_at"),
        })

    document = build_band(
        quota_payload,
        ledger_payload,
        now,
        relative_display(ledger_path, REPO_ROOT),
        quota_error=quota_error,
        ledger_error=ledger_error,
        roster=roster,
        surface_docs=surface_docs,
        roster_error=roster_error,
        surface_sources=ledger_source_info + surface_info,
    )
    document["errors"].extend(errors)
    document["ledger"]["roster_path"] = relative_display(roster_path, REPO_ROOT)
    atomic_write(out_path, render_document(document))

    weekly = document["weekly"]
    total = weekly["total_tokens"]
    if total is None:
        weekly_text = "unknown"
    elif weekly["is_floor"]:
        weekly_text = "at least %d (floor)" % total
    else:
        weekly_text = "%d" % total
    surfaces = document["ledger"]["surfaces"]
    reported = sum(1 for surface in surfaces if surface["status"] == "reported")
    print("fm-token-collect: wrote %s schema=%s quota=%s windows=%d providers_without_windows=%d "
          "ledger=%s days=%d surfaces=%d/%d weekly=%s days_known=%d/%d errors=%d" % (
              out_path,
              SCHEMA,
              "ok" if document["quota"]["ok"] else "failed",
              len(document["quota"]["windows"]),
              len(document["quota"]["providers_without_windows"]),
              "ok" if document["ledger"]["ok"] else "failed",
              len(document["daily"]),
              reported,
              len(surfaces),
              weekly_text,
              weekly["days_known"],
              weekly["days_expected"],
              len(document["errors"]),
          ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
