#!/usr/bin/env bash
# controller-resource-audit.sh - the read-only Controller resource sampler the
# documented six-hour cadence requires.
#
# Contract (dubzai-vps-resource-purge, "Controller resource cadence"):
#   It samples capacity and disposable-cache candidates every six hours, writes
#   a bounded latest report, and keeps a small event ledger. It never deletes
#   files, stops containers, kills Herdr/Pi/Senpi/lean-ctx, restarts M3, or
#   changes a deployment.
#
#   Every six hours: host identity, disk, memory/swap, load, journal size, Docker
#   summary, protected-service status, and the exact approved retention paths.
#   At 75% root usage: report CAPACITY_WARN. At 80%: report
#   CAPACITY_REVIEW_REQUIRED. At 85%: report CAPACITY_BLOCK_NEW_PLACEMENT.
#   On every run: overwrite resource-audit/latest.md and trim the event ledger;
#   never accumulate a new full snapshot per cycle.
#
# This script only reads the host and writes inside its own report directory.
# Every sample degrades to an explicit "unavailable" line rather than guessing:
# a command missing from PATH is never reported as an inactive service.
#
# Usage:
#   controller-resource-audit.sh [--report-dir DIR] [--now ISO8601]
#                               [--root-used-percent N] [--ledger-max N]
#                               [--retention-root DIR]
#                               [--extra-candidate PATH]...
#   controller-resource-audit.sh --print-verdict [--root-used-percent N]
#   controller-resource-audit.sh --next-run ISO8601
#   controller-resource-audit.sh --check-timer-unit PATH
#   controller-resource-audit.sh --help
#
# Exit codes:
#   0  the run completed, or the requested check passed
#   2  bad usage
#   3  a requested check failed (drifted cadence, missing unit)
#   4  root usage could not be measured (CAPACITY_UNMEASURABLE)
set -u

CADENCE_HOURS=6
DEFAULT_REPORT_DIR=/root/resource-audit
DEFAULT_LEDGER_MAX=50

REPORT_DIR=$DEFAULT_REPORT_DIR
LEDGER_MAX=$DEFAULT_LEDGER_MAX
RETENTION_ROOT=${HOME:-/root}
ROOT_PERCENT_OVERRIDE=
NOW=
PRINT_VERDICT=0
NEXT_RUN=
TIMER_UNIT=
EXTRA_CANDIDATES=()

usage() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "${BASH_SOURCE[0]}"
}

die_usage() {
  printf 'controller-resource-audit.sh: %s\n' "$1" >&2
  printf 'Try --help.\n' >&2
  exit 2
}

# --- the documented six-hour cadence ----------------------------------------
#
# Boundaries are 00:00, 06:00, 12:00, and 18:00 UTC. --next-run is the single
# owner of that math so the timer, the tests, and the report cannot disagree.

next_boundary() {  # <ISO8601> -> ISO8601
  local from=$1 day hour next_hour
  day=$(date -u -d "$from" +%Y-%m-%d) || die_usage "--next-run needs a parseable ISO8601 timestamp, got '$from'"
  hour=$(date -u -d "$from" +%H)
  next_hour=$(( 10#$hour / CADENCE_HOURS * CADENCE_HOURS + CADENCE_HOURS ))
  if [ "$next_hour" -ge 24 ]; then
    printf '%sT00:00:00Z\n' "$(date -u -d "$day + 1 day" +%Y-%m-%d)"
  else
    printf '%sT%02d:00:00Z\n' "$day" "$next_hour"
  fi
}

# A timer unit honours the contract when its calendar repeats exactly on the
# six-hourly boundaries and nothing else shortens the interval.
check_timer_unit() {  # <unit path>
  local unit=$1 calendar rep verdict=
  if [ ! -f "$unit" ]; then
    printf 'CADENCE_ABSENT: no timer unit at %s\n' "$unit" >&2
    return 3
  fi
  calendar=$(awk -F= '/^OnCalendar=/ { sub(/^OnCalendar=/, ""); print; exit }' "$unit")
  if [ -z "$calendar" ]; then
    printf 'CADENCE_DRIFT: %s declares no OnCalendar line\n' "$unit" >&2
    return 3
  fi
  case "$(printf '%s' "$calendar" | tr -d ' ')" in
    '*-*-*0/6:00:00'|'*-*-*00/6:00:00'|'*-*-*0,6,12,18:00:00'|'*-*-*00,06,12,18:00:00')
      verdict=CADENCE_OK
      ;;
    *)
      printf 'CADENCE_DRIFT: %s declares OnCalendar=%s, which is not the documented %sh boundary\n' \
        "$unit" "$calendar" "$CADENCE_HOURS" >&2
      return 3
      ;;
  esac
  # A repeating interval below the documented cadence would shorten it.
  rep=$(awk -F= '/^OnUnitActiveSec=|^OnUnitInactiveSec=|^OnBootSec=/ { print $2; exit }' "$unit")
  if [ -n "$rep" ] && [ "$rep" != "0" ]; then
    printf 'CADENCE_DRIFT: %s declares %s, which overrides the %sh calendar cadence\n' \
      "$unit" "$rep" "$CADENCE_HOURS" >&2
    return 3
  fi
  printf '%s: OnCalendar=%s (%s)\n' "$verdict" "$calendar" "$unit"
  return 0
}

# --- threshold verdicts ------------------------------------------------------

verdict_for_percent() {  # <integer 0-100>
  local pct=$1
  if [ "$pct" -ge 85 ]; then
    printf 'CAPACITY_BLOCK_NEW_PLACEMENT\n'
  elif [ "$pct" -ge 80 ]; then
    printf 'CAPACITY_REVIEW_REQUIRED\n'
  elif [ "$pct" -ge 75 ]; then
    printf 'CAPACITY_WARN\n'
  else
    printf 'CAPACITY_OK\n'
  fi
}

is_measurable_percent() {  # <string>
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) [ "$1" -le 100 ] || return 1 ;;
  esac
}

measure_root_percent() {
  local line
  line=$(df -P / 2>/dev/null | awk 'NR == 2 { print $5 }') || line=
  printf '%s' "${line%\%}"
}

# --- samples -----------------------------------------------------------------
#
# Every sampler prints either its measurement or an explicit unavailable line.
# PATH lookup alone never becomes an "inactive" or "absent" claim.

sample_unavailable() {  # <command>
  printf 'unavailable (%s not found on PATH; presence not measured)\n' "$1"
}

sample_host_identity() {
  printf 'kernel: %s\n' "$(uname -srm 2>/dev/null || sample_unavailable uname)"
  printf 'host: %s\n' "$(hostname 2>/dev/null || sample_unavailable hostname)"
}

sample_disk() {
  printf 'root: %s\n' "$(df -hP / 2>/dev/null | awk 'NR == 2 { print $2 " total, " $4 " free, " $5 " used" }' || true)"
  printf 'filesystems:\n'
  df -hP 2>/dev/null | awk 'NR > 1 { printf "  %s %s used\n", $6, $5 }' || true
}

sample_memory_swap() {
  free -m 2>/dev/null | awk '/^Mem:/ { printf "memory: %s MiB total, %s MiB used, %s MiB available\n", $2, $3, $7 } /^Swap:/ { printf "swap: %s MiB total, %s MiB used\n", $2, $3 }' \
    || printf '%s\n' "$(sample_unavailable free)"
}

sample_load() {
  if [ -r /proc/loadavg ]; then
    printf 'load average: %s\n' "$(awk '{ printf "%s %s %s (1m 5m 15m)", $1, $2, $3 }' /proc/loadavg)"
  elif uptime >/dev/null 2>&1; then
    uptime
  else
    printf '%s\n' "$(sample_unavailable uptime)"
  fi
}

sample_journal_size() {
  journalctl --disk-usage 2>/dev/null \
    || printf '%s\n' "$(sample_unavailable journalctl)"
}

sample_docker_summary() {
  if ! command -v docker >/dev/null 2>&1; then
    printf '%s\n' "$(sample_unavailable docker)"
    return 0
  fi
  docker system df 2>/dev/null \
    || printf 'docker summary unavailable (docker present but "system df" is not readable)\n'
}

# Protected services are only ever READ here. Absence of systemctl on PATH is
# reported as unmeasured, never as a stopped service.
sample_protected_services() {
  local svc
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'systemctl: %s\n' "$(sample_unavailable systemctl)"
    return 0
  fi
  for svc in nginx herdr 1panel docker; do
    printf '%s: %s\n' "$svc" "$(systemctl is-active "$svc" 2>/dev/null || printf 'unknown')"
  done
}

# The exact narrow allowlist the contract approves. These are REPORTED for
# review; this script deletes nothing.
retention_allowlist() {
  printf '%s\n' \
    "$RETENTION_ROOT/.antigravity/extensions/.trash|Antigravity extension-download trash|no age limit" \
    "$RETENTION_ROOT/.agy/logs|completed AGY logs|older than 7 days" \
    "$RETENTION_ROOT/.antigravity/logs|completed Antigravity logs|older than 7 days" \
    "$RETENTION_ROOT/.cursor/logs|completed Cursor logs|older than 14 days" \
    "$RETENTION_ROOT/.agy/recordings|AGY browser recording path 1|older than 2 days" \
    "$RETENTION_ROOT/.agy/browser-recordings|AGY browser recording path 2|older than 2 days"
}

path_size() {  # <path>
  if [ ! -e "$1" ]; then
    printf 'not present\n'
  elif ! command -v du >/dev/null 2>&1; then
    printf 'present; %s\n' "$(sample_unavailable du)"
  else
    du -sh "$1" 2>/dev/null | awk '{ print $1 }' || printf 'present; size not readable\n'
  fi
}

sample_retention_paths() {
  local path label age size extra
  printf 'approved allowlist (reported only; nothing is deleted):\n'
  while IFS='|' read -r path label age; do
    [ -n "$path" ] || continue
    size=$(path_size "$path")
    printf '  %s\n' "$path"
    printf '    label: %s; retention: %s; size: %s\n' "$label" "$age" "$size"
  done <<EOF
$(retention_allowlist)
EOF
  for extra in ${EXTRA_CANDIDATES+"${EXTRA_CANDIDATES[@]}"}; do
    printf '  %s\n' "$extra"
    printf '    label: off the approved allowlist; retention: REQUIRES_OPERATOR_APPROVAL; size: %s\n' \
      "$(path_size "$extra")"
  done
}

# Anything off the approved allowlist is surfaced to the operator on stdout as
# well as in the report. The audit classifies; it never acts.
report_offlist_candidates() {
  local extra
  for extra in ${EXTRA_CANDIDATES+"${EXTRA_CANDIDATES[@]}"}; do
    printf 'REQUIRES_OPERATOR_APPROVAL %s\n' "$extra"
  done
}

# --- report and ledger -------------------------------------------------------

now_iso() {
  if [ -n "$NOW" ]; then
    printf '%s\n' "$NOW"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

# Overwrite in place through a staging file. No mv, no rm: the contract forbids
# this script deleting or moving anything, including its own scratch.
write_report() {
  mkdir -p "$REPORT_DIR" || return 1
  cat > "$REPORT_DIR/latest.md.new"
  cat "$REPORT_DIR/latest.md.new" > "$REPORT_DIR/latest.md"
  return 0
}

append_ledger() {  # <timestamp> <verdict> <percent>
  local line lines
  line=$(printf '%s\t%s\troot_used_percent=%s' "$1" "$2" "$3")
  printf '%s\n' "$line" >> "$REPORT_DIR/events.log"
  lines=$(wc -l < "$REPORT_DIR/events.log" | tr -d '[:space:]')
  if [ "$lines" -gt "$LEDGER_MAX" ]; then
    tail -n "$LEDGER_MAX" "$REPORT_DIR/events.log" > "$REPORT_DIR/events.log.tail"
    cat "$REPORT_DIR/events.log.tail" > "$REPORT_DIR/events.log"
  fi
}

emit_report() {  # <percent> <verdict> <timestamp>
  local pct=$1 verdict=$2 stamp=$3
  {
    printf '# Controller resource audit (latest)\n\n'
    printf 'This file is overwritten on every run; the audit never keeps a second full snapshot.\n\n'
    printf '%s\n' "- generated: $stamp"
    printf '%s\n' '- cadence: every six hours (00:00, 06:00, 12:00, 18:00 UTC)'
    printf '%s\n' "- next run: $(next_boundary "$stamp")"
    printf '%s\n' "- root used: ${pct}%"
    printf '%s\n' "- verdict: $verdict"
    case "$verdict" in
      CAPACITY_WARN)
        printf '\n## Admitted by this verdict\n\nNo new service is placed without a fresh audit and headroom proof.\n' ;;
      CAPACITY_REVIEW_REQUIRED)
        printf '\n## Admitted by this verdict\n\nDispatch preflight remains the admission gate; cleanup stays operator-authorized.\n' ;;
      CAPACITY_BLOCK_NEW_PLACEMENT)
        printf '\n## Admitted by this verdict\n\nOnly evidence-backed low-risk cache/log review, or an explicitly approved cleanup target.\n' ;;
    esac

    printf '\n## host-identity\n\n'
    sample_host_identity

    printf '\n## disk\n\n'
    sample_disk

    printf '\n## memory-swap\n\n'
    sample_memory_swap

    printf '\n## load\n\n'
    sample_load

    printf '\n## journal-size\n\n'
    sample_journal_size

    printf '\n## docker-summary\n\n'
    sample_docker_summary

    printf '\n## protected-services\n\n'
    sample_protected_services

    printf '\n## approved-retention-paths\n\n'
    sample_retention_paths
  } | write_report
}

# --- entry -------------------------------------------------------------------

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report-dir)
      [ "$#" -ge 2 ] || die_usage "--report-dir needs a directory"
      REPORT_DIR=$2
      shift 2
      ;;
    --retention-root)
      [ "$#" -ge 2 ] || die_usage "--retention-root needs a directory"
      RETENTION_ROOT=$2
      shift 2
      ;;
    --now)
      [ "$#" -ge 2 ] || die_usage "--now needs an ISO8601 timestamp"
      NOW=$2
      shift 2
      ;;
    --root-used-percent)
      [ "$#" -ge 2 ] || die_usage "--root-used-percent needs a number"
      ROOT_PERCENT_OVERRIDE=$2
      shift 2
      ;;
    --ledger-max)
      [ "$#" -ge 2 ] || die_usage "--ledger-max needs a number"
      LEDGER_MAX=$2
      shift 2
      ;;
    --extra-candidate)
      [ "$#" -ge 2 ] || die_usage "--extra-candidate needs a path"
      EXTRA_CANDIDATES+=("$2")
      shift 2
      ;;
    --print-verdict)
      PRINT_VERDICT=1
      shift
      ;;
    --next-run)
      [ "$#" -ge 2 ] || die_usage "--next-run needs an ISO8601 timestamp"
      NEXT_RUN=$2
      shift 2
      ;;
    --check-timer-unit)
      [ "$#" -ge 2 ] || die_usage "--check-timer-unit needs a unit path"
      TIMER_UNIT=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *) die_usage "unknown argument '$1'" ;;
  esac
done

if [ -n "$NEXT_RUN" ]; then
  next_boundary "$NEXT_RUN"
  exit 0
fi

if [ -n "$TIMER_UNIT" ]; then
  check_timer_unit "$TIMER_UNIT"
  exit $?
fi

case "$LEDGER_MAX" in
  ''|*[!0-9]*) die_usage "--ledger-max must be a positive integer, got '$LEDGER_MAX'" ;;
esac
[ "$LEDGER_MAX" -gt 0 ] || die_usage "--ledger-max must be greater than zero"

PCT=$ROOT_PERCENT_OVERRIDE
if [ -z "$PCT" ]; then
  PCT=$(measure_root_percent)
fi

if ! is_measurable_percent "$PCT"; then
  printf 'CAPACITY_UNMEASURABLE: root usage could not be measured (got %s)\n' "${PCT:-empty}" >&2
  exit 4
fi

VERDICT=$(verdict_for_percent "$PCT")

if [ "$PRINT_VERDICT" -eq 1 ]; then
  printf '%s\n' "$VERDICT"
  exit 0
fi

STAMP=$(now_iso)
mkdir -p "$REPORT_DIR" || die_usage "cannot create report dir $REPORT_DIR"
emit_report "$PCT" "$VERDICT" "$STAMP" || die_usage "cannot write report in $REPORT_DIR"
append_ledger "$STAMP" "$VERDICT" "$PCT"
report_offlist_candidates
printf '%s root_used_percent=%s report=%s/latest.md\n' "$VERDICT" "$PCT" "$REPORT_DIR"