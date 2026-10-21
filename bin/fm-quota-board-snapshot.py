#!/usr/bin/env python3
"""fm-quota-board-snapshot.py - assemble the quota + token snapshot for the HD2 board band.

One command, one JSON document, one source of truth per field:

  * quota  -> `quota-axi --json --full --no-credential-refresh`, run locally and on
    every reachable fleet host. quota-axi is data only: it never routes and never
    mints credentials. Only non-secret identity (provider, account key, window
    label, remaining %, reset time, freshness) is carried forward.
  * tokens -> the existing usage ledger export (`usage.json`, contract version 1,
    written by `ledger/usage_ledger.py`). This collector NEVER re-reduces session
    counters and NEVER invents a second token source of truth.

Contract inherited from the ledger (`ledger/usage_ledger.py` docstring), enforced
here rather than bent:

  * null != zero. An unknown value stays null and is labelled; it is never
    rendered, summed or reported as 0.
  * Official operator-reported totals supersede overlapping local subsets; local
    subsets are exposed as unmapped detail and are never added on top of them.
  * Per-day figures are deltas against the prior-day baseline with reset epochs
    handled (the ledger already applies that; this collector never sums
    cumulative counters).
  * Pi is a runtime, not a provider: provider is resolved from evidenced
    model/provider metadata; unknown groups as `unknown`.
  * Sources are partitioned per real surface (hostname) so two hosts never
    overwrite each other. Rows are de-duplicated by (account_id, source_id), so a
    surface-independent operator-reported seed carried by two hosts is counted
    once, while two hosts' own local rows both count.
  * A corrupt store is refused, never silently reset.
  * No auth / secret / env / token-store reads. No credential material in the
    output. No network calls other than the read-only quota/ledger reads named
    above.

Usage:
    fm-quota-board-snapshot.py --out data/hd2-takeover/quota-board-snapshot.json
    fm-quota-board-snapshot.py --fleet-json fleet.json --print-summary
    fm-quota-board-snapshot.py --self-check
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import socket
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

SNAPSHOT_SCHEMA = "hd2-quota-board-snapshot/v1"
COLLECTOR_VERSION = 1
LEDGER_CONTRACT_VERSION = 1
DEFAULT_TZ = "Europe/London"
SSH_TIMEOUT = 60
QUOTA_TIMEOUT = 180

# --------------------------------------------------------------------------
# fleet definition
# --------------------------------------------------------------------------
# `ssh` is the login target; `ledger_path` is where that host keeps its usage
# ledger export (absent on hosts that never ran the collector).
DEFAULT_FLEET = [
    {
        "label": "HD2Stack",
        "ssh": None,
        "ledger_path": None,
    },
    {
        "label": "Hetzner",
        "ssh": "hd2admin@100.106.6.22",
        "ledger_path": "/root/agent-work/deightonllm-firstmate/data/tracker-tokens-20261019/ledger/usage.json",
    },
    {
        "label": "Controller",
        "ssh": "root@100.117.47.27",
        "ledger_path": "/root/agent-work/deightonllm-firstmate/data/tracker-tokens-20261019/ledger/usage.json",
    },
]

# --------------------------------------------------------------------------
# board account model - the seven REAL accounts
# --------------------------------------------------------------------------
# `quota_provider`   : the quota-axi provider whose windows describe the account.
# `quota_account_key`: when set, the account is only credited on surfaces where
#                      quota-axi reports that account key for the provider.
# `quota_window_ids` : when set, only these window ids belong to the account
#                      (the agy account carries two window families).
# `token_map`        : ledger account_id -> board account id, with the
#                      attribution level. `account` means the ledger row names
#                      this account. `local_subset` means the ledger row is the
#                      provider's local (identity-unknown) subset, which this
#                      board account IS - the GLM row is the local Pi runtime
#                      provider, not a vendor account.
# Anything the ledger reports that is not in `token_map` stays unattributed
# provider-level detail and is never folded into an account.
BOARD_ACCOUNTS = [
    {
        "id": "codex-home",
        "label": "codex-home",
        "provider": "codex",
        "provider_label": "Codex",
        "quota_provider": "codex",
        "quota_account_key": "codex-home",
        "quota_window_ids": None,
        "quota_basis": "codex provider windows, read on the surfaces where the codex-home account key is present",
        "token_map": {},
        "token_note": "no account-level token measurement exists; the codex local subset is provider-level detail and is not attributable to either codex account",
    },
    {
        "id": "openai-codex",
        "label": "openai-codex",
        "provider": "codex",
        "provider_label": "Codex",
        "quota_provider": "codex",
        "quota_account_key": "openai-codex",
        "quota_window_ids": None,
        "quota_basis": "codex provider windows, read on the surfaces where the openai-codex account key is present",
        "token_map": {},
        "token_note": "no account-level token measurement exists; the codex local subset is provider-level detail and is not attributable to either codex account",
    },
    {
        "id": "minimax-account-1",
        "label": "minimax account 1",
        "provider": "minimax",
        "provider_label": "MiniMax",
        "quota_provider": "minimax",
        "quota_account_key": None,
        "quota_window_ids": None,
        "quota_basis": "minimax provider model windows (shared provider quota); account identity is an operator alias",
        "token_map": {"minimax-account-1": "account"},
        "token_note": "operator-reported total, seeded once and dated",
    },
    {
        "id": "minimax-account-2",
        "label": "minimax account 2",
        "provider": "minimax",
        "provider_label": "MiniMax",
        "quota_provider": "minimax",
        "quota_account_key": None,
        "quota_window_ids": None,
        "quota_basis": "minimax provider model windows (shared provider quota); account identity is an operator alias",
        "token_map": {"minimax-account-2": "account"},
        "token_note": "operator-reported total, seeded once and dated",
    },
    {
        "id": "glm",
        "label": "glm (local Pi runtime)",
        "provider": "glm",
        "provider_label": "GLM",
        "quota_provider": "zai",
        "quota_account_key": None,
        "quota_window_ids": None,
        "quota_basis": "zai (Z.AI) provider windows - GLM is a local runtime, so its headroom is the vendor window",
        "token_map": {"glm-local-unmapped": "local_subset"},
        "token_note": "local Pi-runtime subset; identity is not a vendor account, so the figure is a local subset",
    },
    {
        "id": "agy-gemini",
        "label": "agy gemini",
        "provider": "agy",
        "provider_label": "Antigravity (agy)",
        "quota_provider": "agy",
        "quota_account_key": None,
        "quota_window_ids": ("gemini_5h", "gemini_weekly"),
        "quota_basis": "agy provider gemini windows (gemini_5h, gemini_weekly)",
        "token_map": {},
        "token_note": "no local token counter exists for the agy account",
    },
    {
        "id": "agy-claude-gpt",
        "label": "agy claude/gpt",
        "provider": "agy",
        "provider_label": "Antigravity (agy)",
        "quota_provider": "agy",
        "quota_account_key": None,
        "quota_window_ids": ("claude_gpt_5h", "claude_gpt_weekly"),
        "quota_basis": "agy provider claude/gpt windows (claude_gpt_5h, claude_gpt_weekly)",
        "token_map": {},
        "token_note": "no local token counter exists for the agy account",
    },
]

# Window ids whose quota-axi provider is Z.AI (GLM). Kept explicit so a future
# provider rename cannot silently repoint the GLM row.
ZAI_PROVIDER = "zai"


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------


def now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _int(value):
    """Strict integer coercion. None (unknown) never becomes 0."""
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def _f(value):
    if isinstance(value, bool) or value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def write_atomic(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".quota-board-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def ssh_capture(target, command, timeout=SSH_TIMEOUT):
    """Read-only remote command. Returns (stdout, stderr, rc)."""
    argv = [
        "ssh",
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=10",
        "-o", "StrictHostKeyChecking=accept-new",
        target,
        command,
    ]
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "", "ssh timeout after %ss" % timeout, 124
    except OSError as exc:
        return "", "ssh failed: %s" % exc, 125
    return proc.stdout, proc.stderr, proc.returncode


# --------------------------------------------------------------------------
# quota collection
# --------------------------------------------------------------------------

QUOTA_COMMAND = "quota-axi --json --full --no-credential-refresh"


def sanitize_quota(raw):
    """Reduce a quota-axi document to the non-secret fields the band needs.

    Whitelist only. `attempts`, `source`, `plan`, `credits` and every credential
    path are dropped: they are not needed and must not reach a board artifact.
    """
    providers = []
    for provider in raw.get("providers") or []:
        name = provider.get("provider")
        if not name:
            continue
        state = provider.get("state") or {}
        windows = []
        for window in provider.get("windows") or []:
            pace = window.get("pace") or {}
            windows.append(
                {
                    "id": window.get("id"),
                    "label": window.get("label"),
                    "kind": window.get("kind"),
                    "percent_remaining": _f(window.get("percentRemaining")),
                    "resets_at": window.get("resetsAt"),
                    "pace_status": pace.get("status"),
                    "pace_reason": pace.get("reason"),
                }
            )
        providers.append(
            {
                "provider": name,
                "label": provider.get("label"),
                "account_keys": list(provider.get("accountKeys") or []),
                "not_set_up": bool(provider.get("notSetUp")),
                "state": {
                    "status": state.get("status"),
                    "stale": bool(state.get("stale")),
                    "error": state.get("error"),
                },
                "windows": windows,
            }
        )
    return {
        "schema_version": raw.get("schemaVersion"),
        "generated_at": raw.get("generatedAt"),
        "providers": providers,
    }


def surface_short(label):
    """A short, stable tag for a surface (shown on the compact band rows)."""
    known = {
        "HD2Stack": "HD2",
        "Hetzner": "HETZ",
        "Controller": "CTRL",
    }
    if label in known:
        return known[label]
    text = "".join(ch for ch in str(label or "") if ch.isalnum())
    return (text[:4] or "SURF").upper()


def collect_quota_for_host(host, timeout=QUOTA_TIMEOUT):
    """Return one quota source record for a fleet host."""
    record = {
        "label": host["label"],
        "short": surface_short(host["label"]),
        "surface": host.get("surface") or socket.gethostname(),
        "origin": "local" if not host.get("ssh") else "ssh",
        "target": host.get("ssh") or socket.gethostname(),
        "ok": False,
        "schema_version": None,
        "generated_at": None,
        "providers": [],
        "error": None,
    }
    raw = None
    if host.get("quota_json"):
        # Offline / test path: read a captured quota document from disk.
        try:
            raw = json.loads(pathlib.Path(host["quota_json"]).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            record["error"] = "quota file unreadable: %s" % exc
            return record
    elif host.get("ssh"):
        stdout, stderr, rc = ssh_capture(
            host["ssh"], "hostname; %s" % QUOTA_COMMAND, timeout=timeout
        )
        if rc != 0:
            record["error"] = "remote quota-axi failed rc=%s: %s" % (rc, (stderr or stdout).strip()[:200])
            return record
        lines = stdout.splitlines()
        if lines:
            record["surface"] = lines[0].strip()
        body = "\n".join(lines[1:]).strip()
        try:
            raw = json.loads(body)
        except ValueError as exc:
            record["error"] = "remote quota-axi output is not JSON: %s" % exc
            return record
    else:
        try:
            proc = subprocess.run(
                QUOTA_COMMAND.split(),
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            record["error"] = "quota-axi timeout after %ss" % timeout
            return record
        except OSError as exc:
            record["error"] = "quota-axi failed: %s" % exc
            return record
        if proc.returncode != 0:
            record["error"] = "quota-axi rc=%s: %s" % (proc.returncode, proc.stderr.strip()[:200])
            return record
        try:
            raw = json.loads(proc.stdout)
        except ValueError as exc:
            record["error"] = "quota-axi output is not JSON: %s" % exc
            return record

    sanitized = sanitize_quota(raw)
    record["ok"] = True
    record["schema_version"] = sanitized["schema_version"]
    record["generated_at"] = sanitized["generated_at"]
    record["providers"] = sanitized["providers"]
    return record


# --------------------------------------------------------------------------
# ledger collection and merge
# --------------------------------------------------------------------------


class CorruptLedgerError(RuntimeError):
    """The ledger export exists but cannot be trusted. Never auto-reset."""


def load_ledger_document(raw, origin):
    """Validate a ledger export. A corrupt document is refused, never repaired."""
    if not isinstance(raw, dict):
        raise CorruptLedgerError("ledger export is not a JSON object (%s)" % origin)
    version = raw.get("version", raw.get("contract_version"))
    if version is None:
        raise CorruptLedgerError("ledger export has no version field (%s)" % origin)
    if not isinstance(raw.get("days"), list):
        raise CorruptLedgerError("ledger export has no days[] (%s)" % origin)
    if not isinstance(raw.get("accounts"), list):
        raise CorruptLedgerError("ledger export has no accounts[] (%s)" % origin)
    return raw


def collect_ledger_for_host(host):
    """Return one token source record for a fleet host."""
    record = {
        "label": host["label"],
        "short": surface_short(host["label"]),
        "surface": host.get("surface") or socket.gethostname(),
        "origin": "local" if not host.get("ssh") else "ssh",
        "ok": False,
        "ledger_generated_at": None,
        "latest_day": None,
        "day_count": 0,
        "timezone": DEFAULT_TZ,
        "error": None,
        "document": None,
    }
    path = host.get("ledger_json") or host.get("ledger_path")
    if not path:
        record["error"] = "no usage ledger on this surface"
        return record
    if host.get("ssh"):
        stdout, stderr, rc = ssh_capture(host["ssh"], "cat %s" % path, timeout=SSH_TIMEOUT)
        if rc != 0:
            detail = (stderr or stdout).strip()[:200]
            if "No such file" in detail or "not found" in detail:
                record["error"] = "no usage ledger on this surface"
            else:
                record["error"] = "remote ledger unreadable rc=%s: %s" % (rc, detail)
            return record
        body = stdout
    else:
        try:
            body = pathlib.Path(path).read_text(encoding="utf-8")
        except FileNotFoundError:
            record["error"] = "no usage ledger on this surface"
            return record
        except OSError as exc:
            record["error"] = "ledger unreadable: %s" % exc
            return record
    try:
        document = load_ledger_document(json.loads(body), record["label"])
    except (ValueError, CorruptLedgerError) as exc:
        record["error"] = "ledger refused: %s" % exc
        return record
    days = document.get("days") or []
    record["ok"] = True
    record["document"] = document
    record["ledger_generated_at"] = document.get("generated_at")
    record["timezone"] = document.get("timezone") or DEFAULT_TZ
    record["day_count"] = len(days)
    if days:
        record["latest_day"] = max(str(day.get("date")) for day in days if day.get("date"))
    return record


def _row_key(row):
    return (row.get("account_id"), row.get("source_id"))


def merge_ledgers(ledger_records):
    """Merge per-surface ledgers into one day series.

    * Rows are de-duplicated by (account_id, source_id): a surface-independent
      operator-reported seed carried by two hosts is ONE official total, while
      two hosts' own local rows (different source_id) both count.
    * `unmapped[]` rows are local subsets that the ledger deliberately excluded
      from the day total (an official total supersedes them). They are carried
      as unattributed detail and are NEVER added to the total.
    """
    by_date = {}
    accounts_meta = {}
    unmapped_by_date = {}

    for record in ledger_records:
        document = record.get("document")
        if not document:
            continue
        for account in document.get("accounts") or []:
            accounts_meta.setdefault(
                account.get("id"),
                {
                    "id": account.get("id"),
                    "label": account.get("label"),
                    "provider": account.get("provider"),
                    "identity_status": account.get("identity_status"),
                },
            )
        for day in document.get("days") or []:
            date = str(day.get("date"))
            entry = by_date.setdefault(
                date,
                {
                    "date": date,
                    "rows": {},
                    "surfaces": {},
                    "missing_sources": set(),
                    "unmapped": {},
                    "timezones": set(),
                },
            )
            if record.get("timezone"):
                entry["timezones"].add(record["timezone"])
            entry["surfaces"][record["surface"]] = {
                "label": record["label"],
                "day_status": day.get("total_status"),
                "missing_sources": list(day.get("missing_sources") or []),
            }
            for source in day.get("missing_sources") or []:
                entry["missing_sources"].add(source)
            for row in day.get("accounts") or []:
                entry["rows"][_row_key(row)] = {
                    "account_id": row.get("account_id"),
                    "provider": row.get("provider"),
                    "total_tokens": _int(row.get("total_tokens")),
                    "coverage": row.get("coverage"),
                    "observed_at": row.get("observed_at"),
                    "source_id": row.get("source_id"),
                    "source_kind": row.get("source_kind"),
                    "surface": row.get("surface"),
                    "origin_surface": record["surface"],
                }
            for row in day.get("unmapped") or []:
                unmapped_by_date.setdefault(date, {})[_row_key(row)] = {
                    "account_id": row.get("account_id"),
                    "provider": row.get("provider"),
                    "total_tokens": _int(row.get("total_tokens")),
                    "coverage": row.get("coverage"),
                    "source_id": row.get("source_id"),
                    "source_kind": row.get("source_kind"),
                    "surface": row.get("surface"),
                    "origin_surface": record["surface"],
                }

    series = []
    for date in sorted(by_date):
        entry = by_date[date]
        rows = list(entry["rows"].values())
        known = [row for row in rows if row["total_tokens"] is not None]
        unknown_rows = [row for row in rows if row["total_tokens"] is None]
        unmapped_rows = list(unmapped_by_date.get(date, {}).values())

        if not known:
            total = None
            status = "unknown"
        else:
            total = sum(row["total_tokens"] for row in known)
            status = "known"

        # Coverage: a surface that has a ledger but no row for this date, a row
        # whose value is unknown, or a declared missing source all make the day
        # partial. Unknown is never quietly promoted to a complete total.
        surfaces_expected = sum(1 for record in ledger_records if record.get("ok"))
        surfaces_reporting = len(entry["surfaces"])
        coverage = status
        if status == "known":
            if unknown_rows or entry["missing_sources"]:
                coverage = "partial"
            elif surfaces_expected and surfaces_reporting < surfaces_expected:
                coverage = "partial"
            else:
                coverage = "complete"

        kinds = {row["source_kind"] for row in known}
        if not known:
            source = "unknown"
        elif kinds == {"operator_reported"}:
            source = "reported"
        elif "operator_reported" in kinds:
            source = "mixed"
        else:
            source = "measured"

        by_provider = {}
        by_account = {}
        for row in known:
            by_provider.setdefault(row["provider"] or "unknown", 0)
            by_provider[row["provider"] or "unknown"] += row["total_tokens"]
            by_account.setdefault(row["account_id"], 0)
            by_account[row["account_id"]] += row["total_tokens"]

        series.append(
            {
                "date": date,
                "total_tokens": total,
                "status": status,
                "coverage": coverage,
                "source": source,
                "timezone": sorted(entry["timezones"])[0] if entry["timezones"] else DEFAULT_TZ,
                "surfaces_reporting": surfaces_reporting,
                "surfaces_with_ledger": surfaces_expected,
                "missing_sources": sorted(entry["missing_sources"]),
                "provider_totals": by_provider,
                "account_totals": by_account,
                "rows": rows,
                "unmapped": unmapped_rows,
            }
        )

    return series, accounts_meta


# --------------------------------------------------------------------------
# snapshot assembly
# --------------------------------------------------------------------------


def _window_key(window_id, resets_at):
    """Group a window by id and reset DAY.

    Two surfaces usually read the SAME window with reset instants that differ
    by seconds (each host queries the vendor separately). Grouping by the reset
    day keeps one window as one window while still keeping genuinely different
    cycles apart - the agy account has two `gemini_weekly` windows, one
    resetting on 2026-10-23 and one on 2026-10-26, and they stay separate.
    """
    if resets_at:
        stamp = str(resets_at)[:10]
    else:
        stamp = "no-reset"
    return "%s@%s" % (window_id or "unknown", stamp)


def build_account_quota(account, quota_sources):
    """Per-account quota windows, partitioned per surface."""
    provider_name = account["quota_provider"]
    window_filter = account["quota_window_ids"]
    account_key = account["quota_account_key"]

    surfaces = []
    not_set_up_surfaces = []
    for source in quota_sources:
        if not source.get("ok"):
            continue
        provider = None
        for candidate in source.get("providers") or []:
            if candidate.get("provider") == provider_name:
                provider = candidate
                break
        if provider is None:
            continue
        if provider.get("not_set_up"):
            not_set_up_surfaces.append(
                {
                    "surface": source["surface"],
                    "label": source["label"],
                    "reason": (provider.get("state") or {}).get("error") or "provider not set up",
                }
            )
            continue
        keys = provider.get("account_keys") or []
        if account_key and account_key not in keys:
            continue
        state = provider.get("state") or {}
        surfaces.append(
            {
                "surface": source["surface"],
                "label": source["label"],
                "short": source["short"],
                "account_keys": keys,
                "state": state,
                "provider": provider,
            }
        )

    # Group windows by (id, reset instant) so two windows that share an id but
    # differ in reset time stay separate - quota-axi can report both.
    grouped = {}
    order = []
    for surface in surfaces:
        provider = surface["provider"]
        state = surface["state"]
        for window in provider.get("windows") or []:
            if window_filter and window.get("id") not in window_filter:
                continue
            key = _window_key(window.get("id"), window.get("resets_at"))
            if key not in grouped:
                grouped[key] = {
                    "key": key,
                    "id": window.get("id"),
                    "kind": window.get("kind"),
                    "label": window.get("label"),
                    "resets_at": window.get("resets_at"),
                    "entries": [],
                }
                order.append(key)
            grouped[key]["entries"].append(
                {
                    "surface": surface["surface"],
                    "surface_label": surface["label"],
                    "surface_short": surface["short"],
                    "percent_remaining": window.get("percent_remaining"),
                    "resets_at": window.get("resets_at"),
                    "pace_status": window.get("pace_status"),
                    "pace_reason": window.get("pace_reason"),
                    "status": state.get("status"),
                    "stale": bool(state.get("stale")),
                    "error": state.get("error"),
                }
            )

    # A window id reported with two different reset instants needs a distinct
    # human label; otherwise both would read as the same window. The reset
    # instant is shown to the minute because two surfaces can share a calendar
    # day and still be different windows.
    id_counts = {}
    for key in order:
        id_counts[grouped[key]["id"]] = id_counts.get(grouped[key]["id"], 0) + 1
    for key in order:
        window = grouped[key]
        raw_label = window.get("label") or window.get("id") or "window"
        window["label"] = raw_label
        if id_counts.get(window.get("id"), 0) > 1:
            resets = window.get("resets_at") or ""
            stamp = resets[:10] if len(resets) >= 10 else "no reset time"
            window["label_full"] = "%s (resets %s)" % (raw_label, stamp)
        else:
            window["label_full"] = raw_label
        # Primary surface: freshest, non-null reading; fleet order breaks ties.
        entries = window["entries"]
        primary = None
        for entry in entries:
            if entry["percent_remaining"] is not None and not entry["stale"]:
                primary = entry
                break
        if primary is None:
            for entry in entries:
                if entry["percent_remaining"] is not None:
                    primary = entry
                    break
        if primary is None and entries:
            primary = entries[0]
        window["primary"] = primary
        window["other_surfaces"] = [e for e in entries if e is not primary]
        window["percent_remaining"] = primary["percent_remaining"] if primary else None
        window["resets_at"] = primary["resets_at"] if primary else window.get("resets_at")
        window["stale"] = bool(primary["stale"]) if primary else False
        window["status"] = primary["status"] if primary else None
        window["surface_label"] = primary["surface_label"] if primary else None
        window["surface_short"] = primary["surface_short"] if primary else None
        window["surface"] = primary["surface"] if primary else None
        # The primary entry is repeated at the top level for the band's meter;
        # `entries` keeps every surface for the hover detail.
        window.pop("primary", None)
        window.pop("other_surfaces", None)

    windows = [grouped[key] for key in order]
    if not surfaces:
        status = "not_set_up" if not_set_up_surfaces else "unknown"
        reason = (
            "no provider reading available on any surface"
            if not not_set_up_surfaces
            else "provider not set up on every surface"
        )
    elif not windows:
        status = "unknown"
        reason = "provider present but no quota window reported"
    else:
        status = "known"
        reason = None

    return {
        "status": status,
        "reason": reason,
        "basis": account["quota_basis"],
        "source_provider": provider_name,
        "account_key": account_key,
        "account_key_surfaces": [s["surface"] for s in surfaces],
        "surfaces": [
            {
                "surface": s["surface"],
                "label": s["label"],
                "account_keys": s["account_keys"],
                "status": (s["state"] or {}).get("status"),
                "stale": bool((s["state"] or {}).get("stale")),
                "error": (s["state"] or {}).get("error"),
            }
            for s in surfaces
        ],
        "not_set_up_surfaces": not_set_up_surfaces,
        "windows": windows,
    }


def build_account_tokens(account, series, accounts_meta):
    """Per-account per-day token usage from the ledger, plus the latest value."""
    mapping = account["token_map"]
    days = []
    latest = None
    for day in series:
        value = None
        status = "unknown"
        reason = "no ledger row for this account on this day"
        rows = []
        for row in day["rows"]:
            level = mapping.get(row["account_id"])
            if level is None:
                continue
            rows.append(row)
        if rows:
            known = [row for row in rows if row["total_tokens"] is not None]
            if known:
                value = sum(row["total_tokens"] for row in known)
                status = "known"
                reason = None
            else:
                value = None
                status = "unknown"
                reason = "ledger row present but its value is unknown"
        days.append(
            {
                "date": day["date"],
                "value": value,
                "status": status,
                "reason": reason,
                "source_kind": rows[0]["source_kind"] if rows else None,
                "coverage": rows[0]["coverage"] if rows else None,
            }
        )
        if value is not None and (latest is None or day["date"] > latest["date"]):
            identity = accounts_meta.get(sorted(mapping)[0], {}) if mapping else {}
            latest = {
                "date": day["date"],
                "value": value,
                "status": "known",
                "identity_status": identity.get("identity_status"),
                "source_kind": rows[0]["source_kind"] if rows else None,
                "coverage": rows[0]["coverage"] if rows else None,
            }

    if latest is None:
        token_status = "unknown"
        headline = None
    else:
        token_status = "known"
        headline = latest

    return {
        "status": token_status,
        "value": headline["value"] if headline else None,
        "date": headline["date"] if headline else None,
        "identity_status": headline.get("identity_status") if headline else None,
        "source_kind": headline.get("source_kind") if headline else None,
        "coverage": headline.get("coverage") if headline else None,
        "attribution": "account" if "account" in mapping.values() else ("local_subset" if mapping else "none"),
        "note": account["token_note"],
        "days": days,
    }


def build_unattributed(series, board_accounts):
    """Provider-level detail that no board account can claim.

    Two buckets, kept apart on purpose:

      * `provider_detail` - rows that ARE inside the day total but cannot be
        attributed to a named account (the codex / minimax local subsets).
      * `superseded_local_subset` - rows the ledger deliberately excluded from
        the total because an official operator-reported total supersedes them.
        They are shown as detail and are never added to any total.

    Neither bucket is ever folded into an account, so no account figure and no
    headline total is inflated by an unmapped subset.
    """
    mapped_ledger_ids = set()
    for account in board_accounts:
        mapped_ledger_ids.update(account["token_map"].keys())
    detail = {}
    for day in series:
        for row in day["rows"]:
            if row["account_id"] in mapped_ledger_ids:
                continue
            bucket = detail.setdefault(
                (row["provider"] or "unknown", "provider_detail"),
                {
                    "provider": row["provider"] or "unknown",
                    "bucket": "provider_detail",
                    "reason": "provider-level local subset; the ledger cannot attribute it to a named account, so it is never folded into an account",
                    "days": {},
                    "total": 0,
                },
            )
            if row["total_tokens"] is None:
                continue
            bucket["days"][day["date"]] = bucket["days"].get(day["date"], 0) + row["total_tokens"]
            bucket["total"] += row["total_tokens"]
        for row in day.get("unmapped") or []:
            bucket = detail.setdefault(
                (row["provider"] or "unknown", "superseded_local_subset"),
                {
                    "provider": row["provider"] or "unknown",
                    "bucket": "superseded_local_subset",
                    "reason": "local subset superseded by an official operator-reported total; it is excluded from every total and shown as detail only",
                    "days": {},
                    "total": 0,
                },
            )
            if row["total_tokens"] is None:
                continue
            bucket["days"][day["date"]] = bucket["days"].get(day["date"], 0) + row["total_tokens"]
            bucket["total"] += row["total_tokens"]
    out = []
    for key in sorted(detail):
        bucket = detail[key]
        out.append(
            {
                "provider": bucket["provider"],
                "bucket": bucket["bucket"],
                "reason": bucket["reason"],
                "total_tokens": bucket["total"],
                "days": [{"date": d, "value": v} for d, v in sorted(bucket["days"].items())],
            }
        )
    return out


def build_aggregate(series, board_accounts, accounts_meta, token_records):
    if not series:
        return {
            "day": None,
            "total_tokens": None,
            "status": "unknown",
            "coverage": "unknown",
            "source": "unknown",
            "reason": "no ledger day available on any surface",
            "account_split": [],
            "unattributed_detail": [],
            "series": [],
        }
    latest = series[-1]
    split = []
    for account in board_accounts:
        tokens = build_account_tokens(account, series, accounts_meta)
        on_day = None
        for day in tokens["days"]:
            if day["date"] == latest["date"]:
                on_day = day
                break
        split.append(
            {
                "account_id": account["id"],
                "value": on_day["value"] if on_day else None,
                "status": on_day["status"] if on_day else "unknown",
                "reason": on_day["reason"] if on_day else "no ledger row for this account on this day",
                "latest_known": {
                    "date": tokens["date"],
                    "value": tokens["value"],
                    "source_kind": tokens["source_kind"],
                    "coverage": tokens["coverage"],
                }
                if tokens["value"] is not None
                else None,
                "attribution": tokens["attribution"],
                "note": tokens["note"],
            }
        )
    unattributed = build_unattributed(series, board_accounts)
    return {
        "day": latest["date"],
        "total_tokens": latest["total_tokens"],
        "status": latest["status"],
        "coverage": latest["coverage"],
        "source": latest["source"],
        "timezone": latest["timezone"],
        "missing_sources": latest["missing_sources"],
        "reason": None
        if latest["total_tokens"] is not None
        else "every contributing ledger row is unknown; the day total is unknown, not zero",
        "account_split": split,
        "unattributed_detail": unattributed,
        "series": [
            {
                "date": day["date"],
                "total_tokens": day["total_tokens"],
                "status": day["status"],
                "coverage": day["coverage"],
                "source": day["source"],
                "surfaces_reporting": day["surfaces_reporting"],
                "surfaces_with_ledger": day["surfaces_with_ledger"],
            }
            for day in series
        ],
        "token_surfaces": [
            {
                "label": record["label"],
                "surface": record["surface"],
                "ok": record["ok"],
                "error": record["error"],
                "latest_day": record["latest_day"],
                "ledger_generated_at": record["ledger_generated_at"],
            }
            for record in token_records
        ],
    }


LEGEND = [
    {
        "key": "account_colour",
        "label": "account colour",
        "meaning": "one colour per real account. Two accounts of the same provider stay separate accounts; they are never merged, even when their readings are identical.",
    },
    {
        "key": "meter_green",
        "label": "50% or more left",
        "meaning": "the quota window has at least half its allowance remaining.",
    },
    {
        "key": "meter_amber",
        "label": "20-49% left",
        "meaning": "the window is below half but above a fifth.",
    },
    {
        "key": "meter_red",
        "label": "under 20% left",
        "meaning": "the window is nearly exhausted.",
    },
    {
        "key": "meter_grey",
        "label": "unknown",
        "meaning": "no reading was available. Unknown means the value is not known - it is never a zero. A grey meter is not an empty meter.",
    },
    {
        "key": "not_set_up",
        "label": "not set up",
        "meaning": "the provider has no credentials configured on that surface, so there is nothing to read. That is a configuration state, not a usage number.",
    },
    {
        "key": "stale",
        "label": "stale",
        "meaning": "the reading is older than the provider's own refresh, or the provider reported it as stale. The number is shown as measured but the age is flagged.",
    },
    {
        "key": "unattributed",
        "label": "provider detail",
        "meaning": "token use the ledger measures at provider level only. It is shown as detail and never added to an account, so no total is inflated.",
    },
]


def build_snapshot(quota_sources, token_records, series, accounts_meta):
    board_accounts = []
    for account in BOARD_ACCOUNTS:
        entry = {
            "id": account["id"],
            "label": account["label"],
            "provider": account["provider"],
            "provider_label": account["provider_label"],
        }
        entry["quota"] = build_account_quota(account, quota_sources)
        entry["tokens"] = build_account_tokens(account, series, accounts_meta)
        board_accounts.append(entry)

    aggregate = build_aggregate(series, BOARD_ACCOUNTS, accounts_meta, token_records)

    not_set_up = []
    not_set_up_index = {}
    for source in quota_sources:
        if not source.get("ok"):
            continue
        for provider in source.get("providers") or []:
            if not provider.get("not_set_up"):
                continue
            name = provider.get("provider")
            bucket = not_set_up_index.get(name)
            if bucket is None:
                bucket = {
                    "provider": name,
                    "label": provider.get("label"),
                    "reason": (provider.get("state") or {}).get("error") or "not set up",
                    "surfaces": [],
                }
                not_set_up_index[name] = bucket
                not_set_up.append(bucket)
            bucket["surfaces"].append(
                {"surface": source["surface"], "surface_label": source["label"]}
            )

    warnings = []
    for source in quota_sources:
        if not source.get("ok") and source.get("error"):
            warnings.append("quota unreadable on %s: %s" % (source["label"], source["error"]))
    for record in token_records:
        if not record.get("ok") and record.get("error"):
            warnings.append("token ledger unusable on %s: %s" % (record["label"], record["error"]))
    for account in board_accounts:
        if account["quota"]["status"] == "unknown":
            warnings.append("quota unknown for %s: %s" % (account["id"], account["quota"]["reason"]))

    return {
        "schema": SNAPSHOT_SCHEMA,
        "collector": {"name": "fm-quota-board-snapshot.py", "version": COLLECTOR_VERSION},
        "generated_at": now_iso(),
        "generated_from": {
            "host": socket.gethostname(),
            "surface": socket.gethostname(),
            "role": "hd2stack",
        },
        "ledger_contract_version": LEDGER_CONTRACT_VERSION,
        "timezone": DEFAULT_TZ,
        "stale_after_seconds": 21600,
        "quota_sources": [
            {
                "label": source["label"],
                "short": source["short"],
                "surface": source["surface"],
                "origin": source["origin"],
                "target": source["target"],
                "ok": source["ok"],
                "schema_version": source["schema_version"],
                "generated_at": source["generated_at"],
                "error": source["error"],
            }
            for source in quota_sources
        ],
        "token_sources": [
            {
                "label": record["label"],
                "short": record["short"],
                "surface": record["surface"],
                "origin": record["origin"],
                "ok": record["ok"],
                "ledger_generated_at": record["ledger_generated_at"],
                "latest_day": record["latest_day"],
                "day_count": record["day_count"],
                "timezone": record["timezone"],
                "error": record["error"],
            }
            for record in token_records
        ],
        "accounts": board_accounts,
        "aggregate": aggregate,
        "not_set_up": not_set_up,
        "legend": LEGEND,
        "warnings": warnings,
    }


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


LEDGER_RELATIVE_PATH = "data/tracker-tokens-20261019/ledger/usage.json"
# The ledger export lives in the firstmate home's data/ directory, which is
# gitignored and therefore absent from a fresh worktree. The canonical home on
# this host is the documented fallback so a lane worktree still reads the same
# ledger the board is built from.
CANONICAL_HOME = "/root/agent-work/deightonllm-firstmate"


def resolve_local_ledger(home):
    """First existing local ledger export, or the intended path for the error."""
    candidates = []
    env_path = os.environ.get("FM_QUOTA_BOARD_LEDGER")
    if env_path:
        candidates.append(pathlib.Path(env_path))
    candidates.append(pathlib.Path(home) / LEDGER_RELATIVE_PATH)
    candidates.append(pathlib.Path(CANONICAL_HOME) / LEDGER_RELATIVE_PATH)
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    return str(candidates[1])


def load_fleet(path, home):
    if not path:
        fleet = [dict(item) for item in DEFAULT_FLEET]
    else:
        raw = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
        fleet = raw.get("hosts") if isinstance(raw, dict) else raw
        if not fleet:
            raise SystemExit("fleet file has no hosts[]")
    for host in fleet:
        if not host.get("ssh"):
            ledger_path = host.get("ledger_path")
            if not ledger_path:
                # No explicit path: resolve the ledger export of this host.
                host["ledger_path"] = resolve_local_ledger(home)
            elif not os.path.isabs(ledger_path):
                host["ledger_path"] = str(pathlib.Path(home) / ledger_path)
    return fleet


def self_check():
    """Structural check of the collector's own contract, without any I/O."""
    problems = []
    ids = [account["id"] for account in BOARD_ACCOUNTS]
    if len(ids) != 7:
        problems.append("expected 7 board accounts, found %d" % len(ids))
    if len(set(ids)) != len(ids):
        problems.append("duplicate board account id")
    for account in BOARD_ACCOUNTS:
        if account["quota_provider"] == ZAI_PROVIDER and account["id"] != "glm":
            problems.append("zai provider mapped to a non-glm account: %s" % account["id"])
    for key, value in _flat_token_map():
        if value not in ids:
            problems.append("token map points at unknown account %s" % value)
    if problems:
        for problem in problems:
            print("self-check FAIL: %s" % problem)
        return 1
    print("self-check PASS: 7 accounts, %d ledger account mappings" % len(_flat_token_map()))
    return 0


def _flat_token_map():
    pairs = []
    for account in BOARD_ACCOUNTS:
        for ledger_id, level in account["token_map"].items():
            pairs.append((ledger_id, account["id"]))
    return pairs


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--out",
        default=None,
        help="snapshot path (default: <home>/data/hd2-takeover/quota-board-snapshot.json)",
    )
    parser.add_argument("--fleet-json", default=None, help="fleet definition JSON")
    parser.add_argument("--home", default=None, help="firstmate home (default: repo root)")
    parser.add_argument("--print-summary", action="store_true", help="print a short human summary")
    parser.add_argument("--self-check", action="store_true", help="structural contract check only")
    parser.add_argument("--quota-timeout", type=int, default=QUOTA_TIMEOUT)
    args = parser.parse_args(argv)

    if args.self_check:
        return self_check()

    here = pathlib.Path(__file__).resolve().parents[1]
    home = pathlib.Path(args.home).resolve() if args.home else here
    out = pathlib.Path(args.out) if args.out else home / "data" / "hd2-takeover" / "quota-board-snapshot.json"

    fleet = load_fleet(args.fleet_json, home)

    quota_sources = []
    token_records = []
    for host in fleet:
        quota_sources.append(collect_quota_for_host(host, timeout=args.quota_timeout))
        token_records.append(collect_ledger_for_host(host))

    series, accounts_meta = merge_ledgers(token_records)
    snapshot = build_snapshot(quota_sources, token_records, series, accounts_meta)

    write_atomic(out, json.dumps(snapshot, indent=2, sort_keys=True, ensure_ascii=False) + "\n")

    if args.print_summary:
        aggregate = snapshot["aggregate"]
        print("snapshot: %s" % out)
        print("generated_at: %s from %s" % (snapshot["generated_at"], snapshot["generated_from"]["host"]))
        print(
            "aggregate: %s tokens on %s (%s/%s)"
            % (
                aggregate["total_tokens"],
                aggregate["day"],
                aggregate["coverage"],
                aggregate["source"],
            )
        )
        for account in snapshot["accounts"]:
            quota = account["quota"]
            windows = ", ".join(
                "%s %s" % (w["label"], "unknown" if w["percent_remaining"] is None else "%g%%" % w["percent_remaining"])
                for w in quota["windows"]
            ) or quota["status"]
            tokens = account["tokens"]
            print(
                "  %-16s %-8s quota: %-28s tokens: %s"
                % (
                    account["id"],
                    account["provider"],
                    windows,
                    ("%s on %s" % (tokens["value"], tokens["date"])) if tokens["value"] is not None else "unknown",
                )
            )
        for warning in snapshot["warnings"]:
            print("  warning: %s" % warning)
    return 0


if __name__ == "__main__":
    sys.exit(main())
