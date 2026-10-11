#!/usr/bin/env bash
# fm-provider-route-supervise.sh — bounded AFK supervisor integration for
# the sanitized provider-route observer (bin/fm-provider-route-watch.sh).
#
# Purpose: keep provider-route observation autonomous during AFK housekeeping
# without making it dangerous. Obtains at most one quota-axi snapshot per
# due cadence, feeds it to the existing sanitized observer, persists only
# bounded observation state under <state>/, and surfaces route changes or
# blocked evidence as a coarse supervisor-readable signal. A working task
# retains its provider, source-of-truth run ID, and lease until an explicitly
# verified safe handoff; no automatic reroute or queue mutation occurs here.
#
# Library mode (sourced by the supervise-daemon):
#   Defines fm_provider_route_supervise_tick <state>. The function:
#     1. Reads state/.provider-route-supervise-last-run to determine cadence.
#     2. If (now - last_run) < cadence (default 3600s; override via
#        FM_PROVIDER_ROUTE_SUPERVISE_CADENCE), returns 0 immediately.
#     3. Else invokes `quota-axi --no-credential-refresh --json` via a bounded
#        timeout, saves the JSON to a private bounded temp file, and invokes
#        the sanitized observer with --state-dir <state> --quota-file <temp>.
#     4. Reads back the observer's signal (NO_PRIOR / NO_CHANGE /
#        HANDOFF_PENDING / DEFER_ACTIVE_RUN) and persists it as a coarse
#        bounded token to state/.provider-route-supervise-last-signal.
#     5. Removes the private temp file.
#     6. Updates state/.provider-route-supervise-last-run on success only.
#     7. On quota or watch failure: writes a coarse observable error to
#        state/.provider-route-supervise-error, does NOT advance the cadence
#        marker (so the next tick can retry promptly), and returns 0 to keep
#        the daemon alive.
#
# Executed mode (BASH_SOURCE == $0): runs a single tick against the default
# state dir resolved from FM_STATE_OVERRIDE or $FM_HOME/state.
#
# Environment overrides (all optional):
#   FM_PROVIDER_ROUTE_SUPERVISE_CADENCE   seconds between observations
#                                          (default 3600; 0 = observe every
#                                          call, for tests only)
#   FM_PROVIDER_ROUTE_SUPERVISE_TIMEOUT   seconds allowed for quota-axi
#                                          (default 20)
#   FM_PROVIDER_ROUTE_WATCH_BIN           override the watch binary
#                                          (default: $FM_ROOT/bin/fm-provider-route-watch.sh)
#   FM_QUOTA_AXI_BIN                      override the quota-axi binary
#                                          (default: quota-axi on PATH;
#                                          npx -y quota-axi is the supported
#                                          fallback when the global CLI is
#                                          absent and FM_QUOTA_AXI_ALLOW_NPX=1)
#
# Invariants (see tests/fm-provider-route-supervise.test.sh):
#   - At most one quota-axi snapshot per due cadence.
#   - The snapshot lives in a private bounded temp file; the file is removed
#     before the function returns.
#   - The function never refreshes credentials, never moves a queue row,
#     never changes a lease, never touches a Herdr pane, never spawns a
#     process, never sleeps or schedules itself.
#   - Quota acquisition failure is a coarse observable error; the daemon
#     stays alive.

set -u

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$HELPER_DIR/.." && pwd -P)}"
WATCH_BIN="${FM_PROVIDER_ROUTE_WATCH_BIN:-$FM_ROOT/bin/fm-provider-route-watch.sh}"
SUPERVISE_CADENCE_DEFAULT=3600
SUPERVISE_TIMEOUT_DEFAULT=20

_state_root_supervise() { printf '%s' "${FM_STATE_OVERRIDE:-${FM_HOME:-$FM_ROOT}/state}"; }

_now() { date +%s; }

_resolve_quota_axi() {
  if [ -n "${FM_QUOTA_AXI_BIN:-}" ]; then
    if command -v "$FM_QUOTA_AXI_BIN" >/dev/null 2>&1; then
      printf '%s' "$FM_QUOTA_AXI_BIN"
      return 0
    fi
    printf 'quota_axi_unavailable'
    return 1
  fi
  if command -v quota-axi >/dev/null 2>&1; then
    printf '%s' "quota-axi"
    return 0
  fi
  if [ "${FM_QUOTA_AXI_ALLOW_NPX:-1}" = 1 ] && command -v npx >/dev/null 2>&1; then
    printf '%s' "npx -y quota-axi"
    return 0
  fi
  printf 'quota_axi_unavailable'
  return 1
}

# _run_quota_axi_bounded <cmd-string> <timeout>
# Word-splits the resolved command into argv, then invokes it with
# `--no-credential-refresh --json </dev/null` under a bounded watchdog
# (timeout > gtimeout > perl alarm > unbounded last resort).
_run_quota_axi_bounded() {
  local cmd_str=$1 timeout=$2 rc=0
  case "$timeout" in
    ''|*[!0-9]*|0*) timeout=$SUPERVISE_TIMEOUT_DEFAULT ;;
  esac
  # shellcheck disable=SC2086
  set -- $cmd_str
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout" "$@" --no-credential-refresh --json </dev/null 2>/dev/null
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout" "$@" --no-credential-refresh --json </dev/null 2>/dev/null
    return $?
  fi
  if command -v perl >/dev/null 2>&1; then
    perl -e 'my $t = shift; my @args = @ARGV; my $pid = fork; die "fork failed" unless defined $pid; if (!$pid) { setpgrp(0, 0); exec @args } local $SIG{ALRM} = sub { kill "TERM", -$pid; select undef, undef, undef, 0.2; kill "KILL", -$pid; exit 124 }; alarm $t; waitpid $pid, 0; exit($? >> 8)' \
      "$timeout" "$@" </dev/null 2>/dev/null
    return $?
  fi
  "$@" --no-credential-refresh --json </dev/null 2>/dev/null
  return $?
}

_write_coarse_error() {  # <state> <reason>
  local state=$1 reason=$2 now
  now=$(_now)
  # Coarse, bounded, no secrets, no quota JSON. One line.
  printf 'reason=%s at=%s\n' "$reason" "$now" > "$state/.provider-route-supervise-error"
}

_clear_coarse_error() {  # <state>
  rm -f "$1/.provider-route-supervise-error"
}

# fm_provider_route_supervise_tick <state>
#
# Returns 0 always (the daemon must NEVER abort on a route observation
# failure). Records a coarse observable error on quota / watch failure and
# preserves the cadence marker so the next tick can retry promptly. The
# signal is a passive recorder — the supervisor / operator is the consumer;
# the helper does NOT fire escalations or auto-reroute a working task.
fm_provider_route_supervise_tick() {  # <state>
  local state=$1 now last_run cadence quota_cmd rc=0 quota_out snap signal

  [ -d "$state" ] || return 0

  now=$(_now)
  cadence="${FM_PROVIDER_ROUTE_SUPERVISE_CADENCE:-$SUPERVISE_CADENCE_DEFAULT}"
  case "$cadence" in
    ''|*[!0-9]*) cadence=$SUPERVISE_CADENCE_DEFAULT ;;
  esac

  # Read last-run marker (0 when absent or unreadable).
  if [ -f "$state/.provider-route-supervise-last-run" ]; then
    last_run=$(cat "$state/.provider-route-supervise-last-run" 2>/dev/null || echo 0)
    case "$last_run" in ''|*[!0-9]*) last_run=0 ;; esac
  else
    last_run=0
  fi

  # Cadence check (0 = observe on every call, for tests).
  if [ "$cadence" -gt 0 ] && [ "$last_run" -gt 0 ] \
     && [ $((now - last_run)) -lt "$cadence" ]; then
    return 0  # Not due
  fi

  # Resolve quota-axi command.
  if ! quota_cmd=$(_resolve_quota_axi); then
    _write_coarse_error "$state" "quota_axi_unavailable"
    return 0
  fi

  # One bounded quota-axi snapshot.
  quota_out=$(_run_quota_axi_bounded "$quota_cmd" "${FM_PROVIDER_ROUTE_SUPERVISE_TIMEOUT:-$SUPERVISE_TIMEOUT_DEFAULT}") \
    || rc=$?
  if [ "${rc:-0}" -ne 0 ]; then
    _write_coarse_error "$state" "quota_snapshot_failed rc=$rc"
    return 0
  fi
  if [ -z "${quota_out:-}" ]; then
    _write_coarse_error "$state" "quota_snapshot_empty"
    return 0
  fi

  # Write to a private bounded temp file.
  snap=$(mktemp "${TMPDIR:-/tmp}/fm-supervise-snap.XXXXXX" 2>/dev/null) || {
    _write_coarse_error "$state" "mktemp_failed"
    return 0
  }
  printf '%s\n' "$quota_out" > "$snap"

  # Invoke the sanitized observer. Watch errors are coarse observable state;
  # the helper still returns 0 to keep the daemon alive.
  rc=0
  if [ ! -x "$WATCH_BIN" ]; then
    rm -f "$snap"
    _write_coarse_error "$state" "watch_binary_unavailable"
    return 0
  fi
  "$WATCH_BIN" --state-dir "$state" --quota-file "$snap" --at "$now" >/dev/null 2>&1 || rc=$?
  rm -f "$snap"
  if [ "$rc" -ne 0 ]; then
    _write_coarse_error "$state" "watch_failed rc=$rc"
    return 0
  fi

  # Read back the sanitized signal. Whitelist the bounded token set; anything
  # else is recorded as UNKNOWN (the watch script should never produce a token
  # outside this set, but the helper refuses to echo arbitrary bytes that
  # might be derived from a corrupted snapshot).
  signal=""
  if [ -f "$state/.provider-route-watch.signal" ]; then
    signal=$(cat "$state/.provider-route-watch.signal" 2>/dev/null || echo "")
  fi
  case "$signal" in
    NO_PRIOR|NO_CHANGE|HANDOFF_PENDING|DEFER_ACTIVE_RUN) ;;
    *) signal="UNKNOWN" ;;
  esac

  # Persist coarse observable state. Only the sanitized signal + epoch —
  # never the raw quota JSON, never secret-bearing fields.
  printf 'last_signal=%s\nlast_at=%s\n' "$signal" "$now" \
    > "$state/.provider-route-supervise-last-signal"
  _clear_coarse_error "$state"
  printf '%s\n' "$now" > "$state/.provider-route-supervise-last-run"

  return 0
}

# Run only when executed, not when sourced (library-mode for tests + daemon).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  state="$(_state_root_supervise)"
  mkdir -p "$state"
  fm_provider_route_supervise_tick "$state"
fi
