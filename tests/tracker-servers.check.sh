#!/usr/bin/env bash
# tests/tracker-servers.check.sh - live regression check for the two Controller
# tracker/dashboard HTTP servers.
#
# Contract (lane: tracker-server-harden-20261020):
#   - lane-dash-serve.service (port 4390) and tracker-view-serve.service
#     (port 8477) must BOTH exist, be enabled so they start at boot, be active
#     right now, carry a Restart= policy so a crash cannot leave the Captain's
#     browser tab dead, and carry a resource cap so one unit can never eat the
#     host.
#   - Both endpoints must answer HTTP 200 with a non-empty body.
#   - The tracker-view body served must equal the file behind its serving
#     symlink (the served content follows the live checkout).
#
# Read-only by construction: this script only READS - `systemctl show`,
# `systemctl is-enabled`, `systemctl is-active`, `curl`, `sha256sum`. It never
# starts, stops, restarts, enables, disables, or writes a unit, and it is safe
# to run repeatedly.
#
# Host-scoped, and deliberately NOT named tests/*.test.sh:
# bin/fm-test-run.sh --check-coverage requires the portable CI shard union to
# equal the tests/*.test.sh inventory EXACTLY, and a live systemd assertion
# about the Controller host cannot pass on a GitHub runner. bin/fm-lint.sh still
# lints this file (it globs tests/*.sh) and it parses under stock macOS Bash
# 3.2. Run it on the Controller: tests/tracker-servers.check.sh
#
# Exit code: 0 when every assertion passes, 1 otherwise.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- knobs (overridable so the check can be pointed at a scratch instance) ---
FM_TS_HOST=${FM_TS_HOST:-100.117.47.27}
FM_TS_DASH_PORT=${FM_TS_DASH_PORT:-4390}
FM_TS_VIEW_PORT=${FM_TS_VIEW_PORT:-8477}
FM_TS_VIEW_DIR=${FM_TS_VIEW_DIR:-/root/tracker-view}
FM_TS_CURL_TIMEOUT=${FM_TS_CURL_TIMEOUT:-10}

FM_TS_FAILURES=0

notok() {
  printf 'not ok - %s\n' "$1" >&2
  FM_TS_FAILURES=$((FM_TS_FAILURES + 1))
}

# --- preconditions -----------------------------------------------------------

command -v systemctl >/dev/null 2>&1 || {
  printf 'not ok - systemctl is not available on this host\n' >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  printf 'not ok - curl is not available on this host\n' >&2
  exit 1
}
command -v sha256sum >/dev/null 2>&1 || {
  printf 'not ok - sha256sum is not available on this host\n' >&2
  exit 1
}

# Create the scratch dir with mktemp directly, NOT with fm_test_tmproot: that
# helper installs its EXIT trap inside the command substitution, so the dir
# would be deleted on subshell exit before this script could write into it.
# Register it for the same cleanup and install the trap in THIS shell.
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/tracker-servers-check.XXXXXX")
if [ "${#FM_TEST_CLEANUP_DIRS[@]}" -eq 0 ]; then trap fm_test_cleanup EXIT; fi
FM_TEST_CLEANUP_DIRS+=("$TMPROOT")

# --- per-unit assertions -----------------------------------------------------
#
# check_unit <unit> <label> <port>
#
# Each assertion reports independently so one broken property does not hide the
# others. The unit is never touched: only its recorded state is read.

check_unit() {
  local unit=$1 label=$2 port=$3
  local load_state enabled_state active_state restart_policy
  local memory_max cpu_quota body http_code

  load_state=$(systemctl show "$unit" -p LoadState --value 2>/dev/null || true)
  if [ "$load_state" = "loaded" ]; then
    pass "$label: unit $unit exists and is loaded"
  else
    notok "$label: unit $unit does not exist (LoadState=${load_state:-<empty>})"
    return 0
  fi

  enabled_state=$(systemctl is-enabled "$unit" 2>/dev/null || true)
  if [ "$enabled_state" = "enabled" ]; then
    pass "$label: unit $unit is enabled (starts at boot)"
  else
    notok "$label: unit $unit is not enabled (is-enabled=${enabled_state:-<empty>})"
  fi

  active_state=$(systemctl is-active "$unit" 2>/dev/null || true)
  if [ "$active_state" = "active" ]; then
    pass "$label: unit $unit is active"
  else
    notok "$label: unit $unit is not active (is-active=${active_state:-<empty>})"
  fi

  restart_policy=$(systemctl show "$unit" -p Restart --value 2>/dev/null || true)
  case "$restart_policy" in
    ''|no)
      notok "$label: unit $unit has no Restart= policy (Restart=${restart_policy:-<empty>})"
      ;;
    *)
      pass "$label: unit $unit carries a Restart= policy (Restart=$restart_policy)"
      ;;
  esac

  memory_max=$(systemctl show "$unit" -p MemoryMax --value 2>/dev/null || true)
  case "$memory_max" in
    ''|infinity)
      notok "$label: unit $unit has no memory cap (MemoryMax=${memory_max:-<empty>})"
      ;;
    *)
      pass "$label: unit $unit carries a memory cap (MemoryMax=$memory_max bytes)"
      ;;
  esac

  # CPUQuotaPerSecUSec is the modern spelling; CPUQuota is the legacy alias
  # that systemd still maps onto it. Either being finite satisfies the cap.
  cpu_quota=$(systemctl show "$unit" -p CPUQuotaPerSecUSec --value 2>/dev/null || true)
  if [ -z "$cpu_quota" ]; then
    cpu_quota=$(systemctl show "$unit" -p CPUQuota --value 2>/dev/null || true)
  fi
  case "$cpu_quota" in
    ''|infinity)
      notok "$label: unit $unit has no CPU cap (CPUQuotaPerSecUSec=${cpu_quota:-<empty>})"
      ;;
    *)
      pass "$label: unit $unit carries a CPU cap (CPUQuotaPerSecUSec=$cpu_quota)"
      ;;
  esac

  body="$TMPROOT/body-$port"
  http_code=$(curl -s -o "$body" -w '%{http_code}' --max-time "$FM_TS_CURL_TIMEOUT" \
    "http://$FM_TS_HOST:$port/" 2>/dev/null || true)
  if [ "$http_code" = "200" ]; then
    pass "$label: endpoint http://$FM_TS_HOST:$port/ answers HTTP 200"
  else
    notok "$label: endpoint http://$FM_TS_HOST:$port/ answered HTTP ${http_code:-<none>}, expected 200"
  fi
  if [ -s "$body" ]; then
    pass "$label: endpoint http://$FM_TS_HOST:$port/ returned a non-empty body"
  else
    notok "$label: endpoint http://$FM_TS_HOST:$port/ returned an empty or unwritten body"
  fi
}

check_unit lane-dash-serve.service "lane-dash" "$FM_TS_DASH_PORT"
check_unit tracker-view-serve.service "tracker-view" "$FM_TS_VIEW_PORT"

# --- served-body integrity ---------------------------------------------------
#
# The tracker-view server serves a symlink into the live primary checkout, so
# the bytes on the wire must equal the bytes of the file behind the symlink.

view_body="$TMPROOT/body-$FM_TS_VIEW_PORT"
if [ -s "$view_body" ]; then
  served_sha=$(sha256sum "$view_body" | cut -d' ' -f1)
  if [ -e "$FM_TS_VIEW_DIR/index.html" ]; then
    target=$(readlink -f "$FM_TS_VIEW_DIR/index.html" 2>/dev/null || true)
    if [ -n "$target" ] && [ -f "$target" ]; then
      target_sha=$(sha256sum "$target" | cut -d' ' -f1)
      if [ "$served_sha" = "$target_sha" ]; then
        pass "tracker-view: served body matches the file behind the symlink (sha256=$served_sha)"
      else
        notok "tracker-view: served body sha256=$served_sha differs from $target sha256=$target_sha"
      fi
    else
      notok "tracker-view: cannot resolve $FM_TS_VIEW_DIR/index.html to a readable file"
    fi
  else
    notok "tracker-view: $FM_TS_VIEW_DIR/index.html is missing"
  fi
else
  notok "tracker-view: no body captured for the served-body integrity check"
fi

# --- verdict -----------------------------------------------------------------

if [ "$FM_TS_FAILURES" -eq 0 ]; then
  printf 'ok - all tracker-server assertions passed\n'
  exit 0
fi

printf 'not ok - %s tracker-server assertion(s) failed\n' "$FM_TS_FAILURES" >&2
exit 1
