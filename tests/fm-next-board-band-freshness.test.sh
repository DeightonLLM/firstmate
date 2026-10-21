#!/usr/bin/env bash
# tests/fm-next-board-band-freshness.test.sh - the live board must never serve a
# token band that a superseded collector produced.
#
# The defect this suite exists for: the token collector was upgraded to
# firstmate-token-band/v2 and installed into the runtime directory at 20:52, but
# the band document on disk was written at 20:50 by the OLD collector. The
# freshness gate only compared the band's AGE, so the new collector skipped the
# refresh ("138s old (max-age 540s)"), the publisher logged `band=ok`, and the
# live board went on serving a v1 band with no SURFACES and no COVERAGE table.
# The band was fresh-mtime and stale-content, and nothing in the publish path
# could see it.
#
# These cases prove the publish path is now closed by construction:
#   1. an install never leaves a superseded band looking fresh;
#   2. a band that matches the installed collector is left alone and the
#      publisher still reports it healthy;
#   3. the publisher reports a schema mismatch instead of a clean `band=ok`;
#   4. an install still succeeds when the collector cannot run, and leaves a
#      band the next publish recollects;
#   5. the live runtime directory is never written by this suite.
#
# Hermetic on purpose: every case builds a throwaway repo root and a throwaway
# runtime directory under a temp root, and stubs quota-axi with a local script,
# so the suite never reaches the network, never runs the live service, and
# never touches the live runtime directory.
#
# TAP: one line per case, `#` detail lines under a failure.
#
# SC2119: the shared library defines its own `pass` with a $1, and this suite's
# `pass` takes no argument. The rule fires on the bare `pass` calls below.
# shellcheck disable=SC2119
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"

# This suite creates and removes directories, so it uses the shared cleanup from
# tests/lib.sh. That cleanup falls back to a plain `rm -rf` when
# bin/fm-scratch-lib.sh is missing, and the fallback does not honour the --root
# it is handed - it would remove the repo root itself. Refuse to run rather than
# risk that.
if [ ! -r "$REPO_ROOT/bin/fm-scratch-lib.sh" ]; then
  printf 'not ok 0 - bin/fm-scratch-lib.sh is missing; the shared cleanup would remove the repo root\n' >&2
  exit 1
fi

# shellcheck source=tests/lib.sh
. "$SELF_DIR/lib.sh"

INSTALL="$REPO_ROOT/bin/fm-next-board-install.sh"
COLLECTOR="$REPO_ROOT/bin/fm-token-collect.py"
PUBLISHER="$REPO_ROOT/bin/fm-next-board-publish.py"
BUILDER="$REPO_ROOT/bin/build-next-board.py"
SERVE="$REPO_ROOT/bin/fm-tracker-view-serve.py"
ROSTER="$REPO_ROOT/docs/system-context/token-usage-surfaces.json"

# The live runtime directory the firstmate's publish service runs from. The
# suite must never write there, so it is snapshotted and compared at the end.
LIVE_RUNTIME="${FM_LIVE_RUNTIME_DIR:-/root/agent-work/deightonllm-firstmate/data/next-board-publish}"

# The ledger day the fixture reports on: today, in the ledger's own timezone, so
# the weekly window always contains it whatever day the suite runs on.
TODAY="$(TZ=Europe/London date +%F)"

CASES_RUN=0
CASE_NAME=""
CASE_FAILS=0
CASE_DETAIL=""
CASE_ASSERTIONS=0
FAILED=0
OUT=""
RC=0

start_case() {
  CASE_NAME="$1"
  CASE_FAILS=0
  CASE_DETAIL=""
  CASES_RUN=$((CASES_RUN + 1))
}

pass() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
}

fail() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
  CASE_FAILS=$((CASE_FAILS + 1))
  CASE_DETAIL="${CASE_DETAIL}  # ${1:-assertion failed}"$'\n'
}

end_case() {
  if [ "$CASE_FAILS" -eq 0 ]; then
    printf 'ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
  else
    FAILED=$((FAILED + 1))
    printf 'not ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
    printf '%s' "$CASE_DETAIL"
  fi
}

assert_contains() {  # <substring> <why>
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    pass
  else
    fail "${2:-expected substring missing: $1}"
  fi
}

assert_not_contains() {  # <substring> <why>
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    fail "${2:-expected substring absent: $1}"
  else
    pass
  fi
}

assert_eq() {  # <actual> <expected> <why>
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "${3:-expected $2, got $1}"
  fi
}

assert_no_file() {  # <path> <why>
  if [ ! -e "$1" ]; then
    pass
  else
    fail "${2:-expected path to be gone: $1}"
  fi
}

# ---------------------------------------------------------------- the fixtures

# The ledger the collector reads: one measured day, one account.
write_ledger() {  # <path>
  cat > "$1" <<JSON
{
  "contract_version": 1,
  "version": 1,
  "timezone": "Europe/London",
  "surface": "controller",
  "generated_at": "${TODAY}T20:00:00+01:00",
  "accounts": [
    {"id": "acct-1", "label": "fixture account", "provider": "codex", "identity_status": "mapped"}
  ],
  "days": [
    {
      "date": "${TODAY}",
      "total_tokens": 1200,
      "total_status": "measured",
      "expected_providers": ["codex"],
      "missing_sources": [],
      "accounts": [
        {"account_id": "acct-1", "provider": "codex", "source_id": "s1", "total_tokens": 1200}
      ]
    }
  ]
}
JSON
}

# A band produced by the SUPERSEDED collector: schema v1, no coverage block,
# exactly the document the live board was serving.
write_stale_band() {  # <path>
  cat > "$1" <<'JSON'
{
  "schema": "firstmate-token-band/v1",
  "generated_at": "2026-10-21T20:50:05Z",
  "errors": [],
  "quota": {"ok": true, "error": null, "windows": [], "providers_without_windows": []},
  "ledger": {"ok": true, "error": null, "accounts": []},
  "daily": [],
  "weekly": {
    "start_date": "2026-10-15", "end_date": "2026-10-21",
    "days_expected": 7, "days_known": 0, "days_unknown": 7,
    "total_tokens": null, "status": "unknown", "is_floor": false, "per_account": {}
  },
  "rollover": []
}
JSON
}

# The schema a band document carries, or nothing when there is no document.
band_schema() {  # <path>
  python3 - "$1" <<'PY' 2>/dev/null || true
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        document = json.load(handle)
except Exception:
    sys.exit(0)
schema = document.get("schema") if isinstance(document, dict) else None
if isinstance(schema, str):
    print(schema)
PY
}

# The measured weekly total a band document carries, or nothing.
band_measured_total() {  # <path>
  python3 - "$1" <<'PY' 2>/dev/null || true
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        document = json.load(handle)
except Exception:
    sys.exit(0)
weekly = document.get("weekly") if isinstance(document, dict) else None
total = weekly.get("total_measured_tokens") if isinstance(weekly, dict) else None
if isinstance(total, int):
    print(total)
PY
}

# ---------------------------------------------------------------- the sandbox

# A throwaway repo root with a throwaway runtime directory inside it, plus a
# quota-axi stub so nothing ever reaches the network.
new_sandbox() {
  local root fakebin
  root="$(fm_test_tmproot next-board-band)"
  mkdir -p "$root/repo/bin" "$root/repo/data/next-board-publish" \
           "$root/repo/data/tracker-tokens-20261019/ledger" \
           "$root/repo/docs/system-context" "$root/serve"
  cp "$INSTALL" "$PUBLISHER" "$COLLECTOR" "$BUILDER" "$SERVE" "$root/repo/bin/"
  cp "$ROSTER" "$root/repo/docs/system-context/token-usage-surfaces.json"
  write_ledger "$root/repo/data/tracker-tokens-20261019/ledger/usage.json"
  fakebin="$(fm_fakebin "$root")"
  cat > "$fakebin/quota-axi" <<'SH'
#!/usr/bin/env bash
# The stub quota source: it answers from a fixture and never touches the
# network. When QUOTA_STUB_MARKER names a file, it records that it was called.
if [ -n "${QUOTA_STUB_MARKER:-}" ]; then
  printf 'called\n' > "$QUOTA_STUB_MARKER"
fi
printf '%s\n' '{"generatedAt":"2026-10-21T21:00:00.000Z","schemaVersion":5,"providers":[]}'
SH
  chmod +x "$fakebin/quota-axi"
  printf '%s\n' "$root"
}

run_install() {  # <sandbox>
  local sandbox=$1
  OUT="$(PATH="$sandbox/fakebin:$PATH" bash "$sandbox/repo/bin/fm-next-board-install.sh" \
          --repo "$sandbox/repo" \
          --runtime "$sandbox/repo/data/next-board-publish" \
          --serve-root "$sandbox/serve" 2>&1)"
  RC=$?
}

run_publisher() {  # <sandbox>
  local sandbox=$1
  OUT="$(PATH="$sandbox/fakebin:$PATH" python3 "$sandbox/repo/bin/fm-next-board-publish.py" \
          --repo "$sandbox/repo" \
          --out "$sandbox/repo/data/next-board-publish" --no-refresh 2>&1)"
  RC=$?
}

# Exactly what the live unit's ExecStartPre runs, against the sandbox.
run_collector_step() {  # <sandbox>
  local sandbox=$1
  OUT="$(PATH="$sandbox/fakebin:$PATH" python3 \
          "$sandbox/repo/data/next-board-publish/fm-token-collect.py" --max-age 540 2>&1)"
  RC=$?
}

# ------------------------------------------------------------ the live directory

# The install-managed files of the live runtime directory, hashed. The publish
# timer rewrites the board's own output files every ten minutes, but it never
# rewrites these: only an install does. So this snapshot is stable, and any
# change to it means this suite reached into the live home.
live_snapshot() {
  local dir=$1 file
  [ -d "$dir" ] || { echo "absent"; return 0; }
  ( cd "$dir" && find . -mindepth 1 -maxdepth 1 -printf '%f\n' | sort )
  for file in fm-token-collect.py fm-next-board-publish.py build-next-board.py \
              fm-tracker-view-serve.py fm-next-board-chat.sh fm-next-board-feedback.sh; do
    if [ -f "$dir/$file" ]; then
      sha256sum "$dir/$file" | awk '{print $1"  "$2}'
    fi
  done
}

LIVE_BEFORE="$(live_snapshot "$LIVE_RUNTIME")"

# The schema the collector writes, established by running the collector once
# against fixtures. The suite never keeps a second copy of the schema string:
# it asks the collector.
reference_sandbox="$(new_sandbox)"
reference_out="$reference_sandbox/repo/data/next-board-publish/token-band.json"
PATH="$reference_sandbox/fakebin:$PATH" python3 "$COLLECTOR" --out "$reference_out" \
  --ledger "$reference_sandbox/repo/data/tracker-tokens-20261019/ledger/usage.json" \
  --roster "$reference_sandbox/repo/docs/system-context/token-usage-surfaces.json" \
  --force >/dev/null 2>&1
INSTALLED_SCHEMA="$(band_schema "$reference_out")"
if [ -z "$INSTALLED_SCHEMA" ]; then
  printf 'not ok 0 - the collector wrote no band, so the schema it declares is unknown\n' >&2
  exit 1
fi

# ------------------------------------------------------------------- the cases

start_case "an install does not leave a superseded band fresh"
sandbox="$(new_sandbox)"
runtime="$sandbox/repo/data/next-board-publish"
write_stale_band "$runtime/token-band.json"
# A fresh mtime on a stale document: exactly what the live board was serving.
touch "$runtime/token-band.json"
run_install "$sandbox"
assert_eq "$RC" "0" "the install succeeds"
# The band on disk is either regenerated by the installed collector, or it is
# invalidated so that the next collector run recollects it. Either way it is not
# the superseded document any more.
stale_schema="$(band_schema "$runtime/token-band.json")"
if [ -z "$stale_schema" ]; then
  pass
  CASE_DETAIL="${CASE_DETAIL}  # the superseded band was invalidated"$'\n'
elif [ "$stale_schema" = "$INSTALLED_SCHEMA" ]; then
  pass
  CASE_DETAIL="${CASE_DETAIL}  # the superseded band was regenerated"$'\n'
else
  fail "the band still carries schema $stale_schema"
fi
# And the publish-time collector step produces a current band.
run_collector_step "$sandbox"
assert_eq "$RC" "0" "the publish-time collector step succeeds"
assert_eq "$(band_schema "$runtime/token-band.json")" "$INSTALLED_SCHEMA" \
  "the next publish collects a band from the installed collector"
assert_eq "$(band_measured_total "$runtime/token-band.json")" "1200" \
  "the recollected band carries the fixture's own reading, not the old document"
end_case

start_case "a band that matches the installed collector is left alone and stays healthy"
sandbox="$(new_sandbox)"
runtime="$sandbox/repo/data/next-board-publish"
cp "$COLLECTOR" "$runtime/fm-token-collect.py"
run_collector_step "$sandbox"
assert_eq "$RC" "0" "the first collector run succeeds"
assert_eq "$(band_schema "$runtime/token-band.json")" "$INSTALLED_SCHEMA" \
  "the band on disk carries the installed collector's schema"
before_sum="$(sha256sum "$runtime/token-band.json" | awk '{print $1}')"
before_mtime="$(stat -c %Y "$runtime/token-band.json")"
# The healthy path must not go looking for the network either.
export QUOTA_STUB_MARKER="$sandbox/quota-was-called"
run_install "$sandbox"
assert_eq "$RC" "0" "the install succeeds"
assert_eq "$(sha256sum "$runtime/token-band.json" | awk '{print $1}')" "$before_sum" \
  "the matching band is left byte-identical"
assert_eq "$(stat -c %Y "$runtime/token-band.json")" "$before_mtime" \
  "the matching band is not even rewritten"
assert_no_file "$sandbox/quota-was-called" \
  "the install did not call out for a quota reading it did not need"
unset QUOTA_STUB_MARKER
run_publisher "$sandbox"
assert_eq "$RC" "0" "the publish succeeds"
assert_contains "band=ok" "the publisher still reports a healthy band"
end_case

start_case "the publisher reports a schema mismatch instead of a clean band=ok"
sandbox="$(new_sandbox)"
runtime="$sandbox/repo/data/next-board-publish"
write_stale_band "$runtime/token-band.json"
cp "$COLLECTOR" "$runtime/fm-token-collect.py"
run_publisher "$sandbox"
assert_eq "$RC" "0" "the publish still succeeds: a defect is reported, not fatal"
assert_not_contains "band=ok" "a mismatched band is never reported as healthy"
assert_contains "band=mismatch" "the publisher names the mismatch"
OUT="$(cat "$runtime/index.html")"
assert_contains "superseded collector" "the board itself carries the defect"
end_case

start_case "the install succeeds when the collector cannot run, and leaves a band the next publish recollects"
sandbox="$(new_sandbox)"
runtime="$sandbox/repo/data/next-board-publish"
write_stale_band "$runtime/token-band.json"
# The collector the install will copy cannot run.
printf 'this is not python(\n' > "$sandbox/repo/bin/fm-token-collect.py"
run_install "$sandbox"
assert_eq "$RC" "0" "the install still succeeds"
assert_no_file "$runtime/token-band.json" \
  "the band is not left in a state that looks fresh"
# The next publish recollects it: with a working collector in place, the
# publish-time collector step produces a current band.
cp "$COLLECTOR" "$runtime/fm-token-collect.py"
run_collector_step "$sandbox"
assert_eq "$RC" "0" "the publish-time collector step succeeds"
assert_eq "$(band_schema "$runtime/token-band.json")" "$INSTALLED_SCHEMA" \
  "the next publish collects a band from the installed collector"
end_case

start_case "the live runtime directory is never written by this suite"
assert_eq "$(live_snapshot "$LIVE_RUNTIME")" "$LIVE_BEFORE" \
  "the live runtime directory is exactly as it was before the suite ran"
end_case

# The incident itself, replayed end to end: the runtime directory holds a
# collector that declares the superseded schema and a band that collector
# wrote. The deploy installs the current collector, and the next publish must
# not serve the superseded band.
start_case "the incident replays cleanly: a superseded band never reaches the board"
sandbox="$(new_sandbox)"
runtime="$sandbox/repo/data/next-board-publish"
# The superseded collector: the same collector, declaring the older schema.
sed 's/^SCHEMA = "firstmate-token-band\/v2"$/SCHEMA = "firstmate-token-band\/v1"/' \
  "$COLLECTOR" > "$sandbox/repo/bin/fm-token-collect.py"
cp "$sandbox/repo/bin/fm-token-collect.py" "$runtime/fm-token-collect.py"
# The band that collector wrote, and the fresh mtime it left behind.
PATH="$sandbox/fakebin:$PATH" python3 "$runtime/fm-token-collect.py" --out "$runtime/token-band.json" \
  --force >/dev/null 2>&1
assert_eq "$(band_schema "$runtime/token-band.json")" "firstmate-token-band/v1" \
  "the superseded collector wrote a v1 band"
# The publish-time collector step keeps it: the band is fresh enough to skip.
run_collector_step "$sandbox"
assert_eq "$(band_schema "$runtime/token-band.json")" "firstmate-token-band/v1" \
  "the superseded collector skips the refresh and keeps its own band"
# Now the deploy: the current collector is installed over it.
cp "$COLLECTOR" "$sandbox/repo/bin/fm-token-collect.py"
run_install "$sandbox"
assert_eq "$RC" "0" "the deploy succeeds"
assert_eq "$(band_schema "$runtime/token-band.json")" "$INSTALLED_SCHEMA" \
  "the deploy leaves no superseded band on the publish path"
# The next publish: the collector step keeps it current, and the board carries
# the tables the v1 band was missing.
run_collector_step "$sandbox"
assert_eq "$RC" "0" "the publish-time collector step succeeds"
assert_eq "$(band_schema "$runtime/token-band.json")" "$INSTALLED_SCHEMA" \
  "the publish-time collector step keeps the band current"
run_publisher "$sandbox"
assert_eq "$RC" "0" "the publish succeeds"
assert_contains "band=ok" "the publisher reports a healthy band"
OUT="$(cat "$runtime/index.html")"
assert_contains "SURFACES" "the board carries the SURFACES table"
assert_contains "COVERAGE" "the board carries the COVERAGE table"
end_case

# ------------------------------------------------------------------- the report

printf '\n1..%d\n' "$CASES_RUN"
printf '# %d cases, %d assertions, %d failed\n' "$CASES_RUN" "$CASE_ASSERTIONS" "$FAILED"
if [ "$FAILED" -ne 0 ]; then
  printf 'REGRESSION CHECK: FAIL (%d of %d cases failed)\n' "$FAILED" "$CASES_RUN"
  exit 1
fi
printf 'REGRESSION CHECK: PASS (%d cases, %d assertions)\n' "$CASES_RUN" "$CASE_ASSERTIONS"
exit 0
