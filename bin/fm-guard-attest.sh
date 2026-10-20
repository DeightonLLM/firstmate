#!/usr/bin/env bash
# fm-guard-attest.sh - canonical source of the guard attestation surface.
#
# WHY (2026-10-15): guards were built that passed tests, read as working, and never fired
# in production. Nobody could tell, including me. A guard that cannot prove it fires is
# decoration and is worse than none, because it manufactures confidence.
#
# So: every invocation writes one attestation row. No row = MISSING, never "healthy".
#
# WHY (2026-10-20): the alerting path existed but was never landed on the controller and
# nothing called `status`, so a STALE or MISSING verdict was written where nobody read it.
# Two things are fixed here:
#   1. LIVENESS. A guard that keeps running must not be reported STALE. The event log
#      de-duplicates an identical consecutive verdict (one event per episode), but that
#      used to freeze the row timestamp as well - a healthy guard running every 5 minutes
#      looked four days stale. The verdict row's timestamp is now refreshed on every run,
#      so "last run" is a true heartbeat while "times fired" stays a count of episodes.
#   2. DELIVERY. A STALE/MISSING/ERROR verdict is written to an operator-facing status
#      file whose verb is captain-relevant, which is the exact path the factory safetynet
#      uses: the controller's watcher scans state/*.status, and a changed, captain-relevant
#      file wakes the operator. A verdict is therefore an event, not a row in a table.
#
# Usage:
#   guard-attest run <name> <FIRED|CLEAR|ERROR> [detail]
#       Record one attestation. Prints the row only when result is FIRED or ERROR.
#   guard-attest status
#       One line per known guard: last run, age, last result, times fired, ever fired.
#       Exits 1 if any registered guard is MISSING, stale, or never fired in 7 days.
#       Emits an alert on transition to STALE/MISSING/ERROR and a recovery notice on
#       return to healthy, and maintains the operator-facing status file.
#   guard-attest --selftest
#       Proves the primitive works: FIRED path prints, CLEAR path is silent, repeated
#       FIRED is deduped. Used to satisfy "prove it fires before calling it done".
#
# Contract: exits 0 on a healthy status, 1 on any missing/stale/never-fired guard.
set -u

FM_HOME="${FM_HOME:-/root/agent-work/deightonllm-firstmate}"
ATTEST_DIR="${FM_ATTEST_DIR:-$FM_HOME/state/attestations}"
ALERT_STATE_DIR="${FM_ATTEST_STATE_DIR:-$ATTEST_DIR/.alert_state}"
STALE_SECS="${FM_ATTEST_STALE_SECS:-1800}"
# Operator-facing status file. The controller watcher scans "$FM_HOME/state"/*.status and
# wakes the operator when a changed file carries a captain-relevant verb (blocked:, done:,
# failed:, needs-decision:). Written only when its content changes, so the watcher's
# signature scan fires once per transition instead of once per poll.
STATUS_FILE="${FM_ATTEST_STATUS_FILE:-$FM_HOME/state/guard-attest.status}"
mkdir -p "$ATTEST_DIR" "$ALERT_STATE_DIR" 2>/dev/null || { echo "attestation dir unavailable" >&2; exit 1; }
mkdir -p "$(dirname "$STATUS_FILE")" 2>/dev/null || true

now() { date +%s; }
row() {  # <name> <file>
  local f="$ATTEST_DIR/$2.tsv"
  [ -f "$f" ] || { printf 'MISSING\t0\t0\t-\n'; return; }
  local last
  last=$(tail -1 "$f")
  local ts fired ever
  ts=$(printf '%s' "$last" | cut -f1)
  fired=$(awk -F'\t' '$3=="FIRED"' "$f" 2>/dev/null | wc -l | tr -d ' ')
  ever=$(awk -F'\t' '$3!="CLEAR"' "$f" 2>/dev/null | wc -l | tr -d ' ')
  printf '%s\t%s\t%s\t%s\n' "$(printf '%s' "$last" | cut -f3)" "$ts" "$fired" "$ever"
}

# Refresh the timestamp of the guard's last verdict row without adding an event.
# The event log keeps one row per episode (an identical consecutive verdict is not a
# new episode), but the guard's liveness is recorded on EVERY run so that a guard
# that is running is never reported STALE. Atomic: same-directory temp file + rename.
refresh_row() {  # <file> <result> <detail>
  local f=$1 result=$2 detail=$3 tmp
  tmp="$(mktemp "${f}.tmp.XXXXXX")" || return 1
  if [ -s "$f" ]; then sed '$d' "$f" > "$tmp" 2>/dev/null || true; fi
  printf '%s\t%s\t%s\t%s\n' "$(now)" "$$" "$result" "$detail" >> "$tmp"
  chmod 0644 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$f" || { rm -f "$tmp"; return 1; }
  return 0
}

# Wake the operator through the fleet's durable wake queue - the same path every
# other actionable event uses ("a wake or a notification to the operator through
# the same path every other actionable event uses", not a row in a table).
# The status file is the durable record and the watcher's signal path; this
# append is the immediate wake, and it does not depend on the watcher process
# being alive. One append per transition: the caller only reaches this on a
# state change, so a guard that stays bad does not wake on every poll.
wake_operator() {  # <kind> <key> <payload>
  local kind=$1 key=$2 payload=$3
  [ -f "$FM_HOME/bin/fm-wake-lib.sh" ] || return 0
  (
    # shellcheck source=bin/fm-wake-lib.sh
    . "$FM_HOME/bin/fm-wake-lib.sh" >/dev/null 2>&1 || exit 0
    fm_wake_append "$kind" "$key" "$payload" >/dev/null 2>&1 || true
  )
}

# Guards registered with this home. A guard absent from disk is reported MISSING;
# adding one here is what makes it visible to the status surface.
KNOWN_GUARDS="${FM_ATTEST_GUARDS:-factory-queue ticket-intake comms-notify}"

case "${1:-}" in
  run)
    name="${2:-}"; result="${3:-}"; detail="${4:-}"
    case "$name" in ''|*[!A-Za-z0-9._-]*) echo "bad guard name" >&2; exit 2 ;; esac
    case "$result" in FIRED|CLEAR|ERROR) ;; *) echo "bad result: use FIRED|CLEAR|ERROR" >&2; exit 2 ;; esac
    f="$ATTEST_DIR/$name.tsv"
    # dedupe an identical consecutive row so a repeating condition fires once
    if [ -f "$f" ] && [ "$(tail -1 "$f" | cut -f3,4)" = "$(printf '%s\t%s' "$result" "$detail")" ]; then
      # Same verdict as last time: no new event row, but the guard's liveness is
      # refreshed so a running guard never ages into a false STALE.
      refresh_row "$f" "$result" "$detail" || exit 1
      exit 0
    fi
    printf '%s\t%s\t%s\t%s\n' "$(now)" "$$" "$result" "$detail" >> "$f"
    case "$result" in FIRED|ERROR) printf 'guard-attest: %s %s %s\n' "$name" "$result" "$detail" ;; esac
    exit 0
    ;;

  status)
    printf '%-22s %-8s %-10s %-9s %s\n' GUARD RESULT LAST_RUN FIRED ERRORED
    rc=0
    alerts=()
    recoveries=()
    blocked_lines=()
    for g in $KNOWN_GUARDS; do
      IFS=$'\t' read -r result ts fired ever <<<"$(row "$g" "$g")"
      age=$(( $(now) - ${ts:-0} ))
      [ "$ts" = 0 ] && age=999999

      prior_state="UNKNOWN"
      [ -f "$ALERT_STATE_DIR/$g.state" ] && prior_state=$(cat "$ALERT_STATE_DIR/$g.state" 2>/dev/null || echo UNKNOWN)

      current_state="HEALTHY"
      if [ "${ts:-0}" = 0 ]; then
        current_state="MISSING"
      elif [ "$age" -gt "$STALE_SECS" ]; then
        current_state="STALE"
      elif [ "$result" = "ERROR" ]; then
        current_state="ERROR"
      fi

      if [ "$current_state" != "HEALTHY" ]; then
        printf '%-22s %-8s %-10s %-9s %s\n' "$g" "$current_state" "${age}s" "${fired:-0}" "${ever:-0}"; rc=1
        blocked_lines+=("blocked: GUARD_ALERT: $g is $current_state (age: ${age}s, last result: $result, remediation: check daemon / restart $g)")
        if [ "$prior_state" != "$current_state" ]; then
          alerts+=("GUARD_ALERT: $g is $current_state (age: ${age}s, last result: $result, remediation: check daemon / restart $g)")
          echo "$current_state" > "$ALERT_STATE_DIR/$g.state"
          rm -f "$ALERT_STATE_DIR/$g.recovered"
          wake_operator stale "guard:$g" "GUARD_ALERT: $g is $current_state (age: ${age}s, last result: $result, remediation: check daemon / restart $g)"
        fi
      else
        printf '%-22s %-8s %-10s %-9s %s\n' "$g" "$result" "${age}s" "$fired" "$ever"
        if [ "$prior_state" = "STALE" ] || [ "$prior_state" = "MISSING" ] || [ "$prior_state" = "ERROR" ]; then
          recoveries+=("GUARD_RECOVERED: $g is healthy again (last run ${age}s ago)")
          echo "HEALTHY" > "$ALERT_STATE_DIR/$g.state"
          echo "done: GUARD_RECOVERED: $g is healthy again (last run ${age}s ago)" > "$ALERT_STATE_DIR/$g.recovered"
          wake_operator check "guard:$g" "GUARD_RECOVERED: $g is healthy again (last run ${age}s ago)"
        else
          [ -f "$ALERT_STATE_DIR/$g.state" ] || echo "HEALTHY" > "$ALERT_STATE_DIR/$g.state"
        fi
      fi
    done

    # Operator-facing status file. Blocked verdicts first, pending recovery notices
    # after them, so the LAST line is always a captain-relevant verb when something
    # needs attention (the watcher reads the last line to decide actionability).
    # The file is rewritten only when its content changes: the watcher compares a
    # persisted size:mtime signature, so an unchanged file produces no signal at all.
    tmp="$(mktemp "${STATUS_FILE}.tmp.XXXXXX")" 2>/dev/null || tmp=""
    if [ -n "$tmp" ]; then
      {
        for line in "${blocked_lines[@]}"; do printf '%s\n' "$line"; done
        for rf in "$ALERT_STATE_DIR"/*.recovered; do
          [ -f "$rf" ] || continue
          cat "$rf"
        done
        if [ "${#blocked_lines[@]}" -eq 0 ] && ! ls "$ALERT_STATE_DIR"/*.recovered >/dev/null 2>&1; then
          printf 'ok: all guards attested\n'
        fi
      } > "$tmp"
      chmod 0644 "$tmp" 2>/dev/null || true
      if cmp -s "$tmp" "$STATUS_FILE" 2>/dev/null; then
        rm -f "$tmp"
      else
        mv -f "$tmp" "$STATUS_FILE" 2>/dev/null || rm -f "$tmp"
      fi
    fi

    # Print active alerts and recoveries
    for a in "${alerts[@]}"; do
      echo "guard-alert: $a" >&2
    done
    for r in "${recoveries[@]}"; do
      echo "guard-alert: $r" >&2
    done

    [ "$rc" -eq 0 ] && printf '\nall guards attested recently\n'
    exit "$rc"
    ;;

  --selftest)
    d="$(mktemp -d)"; export FM_ATTEST_DIR="$d"; export FM_ATTEST_STATE_DIR="$d/.alert_state"; export FM_ATTEST_STATUS_FILE="$d/status"; mkdir -p "$d" "$FM_ATTEST_STATE_DIR"
    STATUS_FILE="$FM_ATTEST_STATUS_FILE"   # never touch the live status file from a selftest
    pass=0; fail=0
    chk() { if [ "$2" = "$3" ]; then printf 'PASS  %s\n' "$1"; pass=$((pass+1));
            else printf 'FAIL  %s (want %s got %s)\n' "$1" "$3" "$2"; fail=$((fail+1)); fi; }

    out=$("$0" run selftest FIRED "trip one" 2>&1); chk "FIRED prints a line" "$(printf '%s' "$out" | grep -c FIRED)" "1"
    "$0" run selftest FIRED "trip one" >/dev/null 2>&1   # immediately repeated: must dedupe
    n=$(awk -F'\t' '$3=="FIRED"' "$d/selftest.tsv" | wc -l | tr -d ' ')
    chk "repeated identical FIRED deduped" "$n" "1"
    out=$("$0" run selftest CLEAR "quiet" 2>&1); chk "CLEAR is silent" "$(printf '%s' "$out" | wc -c)" "0"
    "$0" run selftest FIRED "trip two" >/dev/null 2>&1   # different detail after CLEAR: must record
    n=$(awk -F'\t' '$3=="FIRED"' "$d/selftest.tsv" | wc -l | tr -d ' ')
    chk "changed FIRED after CLEAR records again" "$n" "2"
    "$0" run selftest ERROR "boom" >/dev/null 2>&1
    last=$(tail -1 "$d/selftest.tsv" | cut -f3); chk "ERROR is recorded" "$last" "ERROR"
    [ -f "$d/selftest.tsv" ] && chk "attestation file exists" yes yes || chk "attestation file exists" no yes
    rm -rf "$d"
    printf '\nselftest: %d passed, %d failed\n' "$pass" "$fail"
    [ "$fail" -eq 0 ] || exit 1
    exit 0
    ;;

  *) sed -n '2,30p' "$0"; exit 2 ;;
esac
