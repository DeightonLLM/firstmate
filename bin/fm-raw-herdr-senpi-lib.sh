#!/usr/bin/env bash
# fm-raw-herdr-senpi-lib.sh — durable RAW_HERDR_SENPI enforcement for FirstMate
#
# Design principle: when RAW_HERDR_SENPI mode is active, FirstMate fleet lifecycle
# entrypoints (spawn, cycle, daemon, teardown) fail closed. Read-only status
# commands are unaffected. This enforces native raw Herdr + Senpi as the only
# authorized dispatch mode for setups where FirstMate project spawn/cycle/daemon
# would conflict with the coordinator's own Herdr/Pi pane management.
#
# Mode activation:
#   The mode is ACTIVE when EITHER:
#     (a) The env var RAW_HERDR_SENPI=1 is set, OR
#     (b) The durable config file exists at:
#           ${FM_CONFIG_OVERRIDE:-$FM_HOME/config}/raw-herdr-senpi.env
#         AND contains RAW_HERDR_SENPI=1
#
# The config file is the durable marker; the env var allows one-shot overrides
# for testing or emergency override without touching the config file.
#
# Enforcement:
#   - fm_raw_herdr_senpi_is_active()    — returns 0 when mode is active, 1 otherwise
#   - fm_raw_herdr_senpi_refuse_mutate() — echo error to stderr, exit 1 when active
#   - fm_raw_herdr_senpi_status_ok()     — returns 0 always (status is never blocked)
#
# Sources this library should be idempotent (safe to source multiple times).
# No side effects on source. set -u safe. All functions return exit codes
# compatible with the calling conventions used by fm-spawn.sh and fm-always-four.sh.
#
# Exit codes for refusal:
#   1 = RAW_HERDR_SENPI mode is active (mutation blocked)
#   0 = mode is not active (mutation allowed to proceed)
#
# Test escape hatch (FM_RAW_HERDR_SENPI_BYPASS=1):
#   FirstMate's own test suite must exercise the real scripts with the mode file
#   present. FM_RAW_HERDR_SENPI_BYPASS=1 makes the guard a no-op for that path
#   while preserving the real enforcement for all other callers.

# Resolve FM_HOME and FM_ROOT before any function uses them
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
_FM_ROOT_LIB="${FM_ROOT_OVERRIDE:-$(cd "$_SCRIPT_DIR/.." && pwd)}"
_FM_HOME_LIB="${FM_HOME:-${FM_ROOT_OVERRIDE:-$_FM_ROOT_LIB}}"
_CONFIG_LIB="${FM_CONFIG_OVERRIDE:-$_FM_HOME_LIB/config}"

# Exit code for the refusal. Distinct from FM_GATE_REFUSE_EXIT=3 so that
# callers can distinguish a gate-refusal from a RAW_HERDR_SENPI refusal.
RAW_HERDR_SENPI_REFUSE_EXIT=1

# fm_raw_herdr_senpi_is_active: return 0 when RAW_HERDR_SENPI mode is active.
# Checks (a) env var first (allows one-shot override), then (b) durable config file.
fm_raw_herdr_senpi_is_active() {
  # Test escape hatch — allows firstmate's own test suite to run real scripts
  # without being blocked by the mode file that exists in the test environment.
  [ "${FM_RAW_HERDR_SENPI_BYPASS:-0}" = "1" ] && return 1

  # (a) Env var override — explicit one-shot activation
  if [ "${RAW_HERDR_SENPI:-}" = "1" ]; then
    return 0
  fi

  # (b) Durable config file — presence AND content must both confirm
  local cfg="$_CONFIG_LIB/raw-herdr-senpi.env"
  if [ -f "$cfg" ]; then
    # shellcheck disable=SC1090  # config file path is determined at runtime
    . "$cfg" 2>/dev/null || true
    # Must be explicitly =1 (not just file existence)
    if [ "${RAW_HERDR_SENPI:-}" = "1" ]; then
      return 0
    fi
  fi

  return 1
}

# fm_raw_herdr_senpi_refuse_mutate: echo refusal message to stderr and exit 1
# when RAW_HERDR_SENPI mode is active. Call at the top of any fleet mutation
# entrypoint (spawn, cycle, daemon, teardown). Safe to call multiple times.
# Never blocks: status, check-eligible, help.
fm_raw_herdr_senpi_refuse_mutate() {
  local operation="${1:-fleet-mutation}"
  fm_raw_herdr_senpi_is_active || return 0

  echo "error: RAW_HERDR_SENPI mode is active — $operation is refused." >&2
  echo "       Native raw Herdr + Senpi is the authorized dispatch mode." >&2
  echo "       To enable FirstMate fleet lifecycle, remove or unset RAW_HERDR_SENPI" >&2
  echo "       in config/raw-herdr-senpi.env or unset the RAW_HERDR_SENPI env var." >&2
  exit "$RAW_HERDR_SENPI_REFUSE_EXIT"
}

# fm_raw_herdr_senpi_status_ok: always returns 0. Status commands are never blocked.
# Included so callers can use a uniform pattern: check mode, then call status_ok or
# refuse_mutate as appropriate.
fm_raw_herdr_senpi_status_ok() {
  return 0
}

# fm_raw_herdr_senpi_report: print current mode state to stdout. Used by status
# commands and the preflight helper.
fm_raw_herdr_senpi_report() {
  local cfg="$_CONFIG_LIB/raw-herdr-senpi.env"
  local env_active=0 file_active=0
  [ "${RAW_HERDR_SENPI:-}" = "1" ] && env_active=1

  if [ -f "$cfg" ]; then
    # shellcheck disable=SC1090
    . "$cfg" 2>/dev/null || true
    [ "${RAW_HERDR_SENPI:-}" = "1" ] && file_active=1
  fi

  if [ "${FM_RAW_HERDR_SENPI_BYPASS:-0}" = "1" ]; then
    echo "RAW_HERDR_SENPI: inactive (bypass flag set for test harness)"
  elif [ "$env_active" -eq 1 ]; then
    echo "RAW_HERDR_SENPI: ACTIVE (env var override)"
  elif [ "$file_active" -eq 1 ]; then
    echo "RAW_HERDR_SENPI: ACTIVE (config file: $cfg)"
  else
    echo "RAW_HERDR_SENPI: inactive"
  fi
}
