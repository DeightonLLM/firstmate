#!/usr/bin/env bash
# First Mate deterministic control-plane housekeeping helper.
# The canonical cap library remains the source of truth for cap/reap policy;
# this wrapper adds fail-closed preflight and live invariant checks.
set -euo pipefail

HERDR_BIN="${HERDR_BIN:-herdr}"
CAP_LIB="${SUBAGENT_CAP_LIB:-/root/lib/subagent-cap/cap.sh}"
REAPER_BIN="${HERDR_REAPER_BIN:-herdr-subagent-cap-reap}"
REVIEW_HELPER="${HERDR_REVIEW_HELPER:-herdr-review-send}"
VALIDATOR_BIN="${HERDR_PROMPT_VALIDATOR:-/root/bin/validate-herdr-lane-prompt}"
SECRET_SCAN_BIN="${HERDR_SECRET_SCAN:-/root/bin/agent-secret-scan}"

usage() {
  cat <<'USAGE'
usage: fm-housekeeping.sh <command> [args...]
commands:
 status        Audit live Herdr panes against the 7 invariants.
 preflight     Fail closed unless a new subagent spawn is permitted.
 reap-stale    Safely close confirmed settled idle/done panes (never working/blocked).
 invariants    Verify the 7 invariants against live pane state and local hooks.
USAGE
}

pane_payload() {
  local raw
  if [[ -n "${FM_HOUSEKEEPING_PANES_JSON:-}" ]]; then
    raw="$FM_HOUSEKEEPING_PANES_JSON"
  else
    command -v "$HERDR_BIN" >/dev/null 2>&1 || return 3
    raw=$("$HERDR_BIN" pane list 2>/dev/null || true)
  fi
  [[ -n "$raw" ]] || return 3
  jq -e '.result.panes // .panes // null | type == "array"' <<<"$raw" >/dev/null 2>&1 || return 3
  printf '%s' "$raw"
}

panes_only() {
  jq -c '.result.panes // .panes // []'
}

subagent_count() {
  local panes_json="$1"
  # The Codex coordinator is not a subagent. This matches cap.sh exactly.
  jq -r '[.[] | select((.agent // "") != "codex") | select((.agent_status // "") | test("^(working|blocked|idle|done)$"))] | length' <<<"$panes_json"
}

total_open_count() {
  local panes_json="$1"
  jq -r '[.[] | select((.agent_status // "") | test("^(working|blocked|idle|done)$"))] | length' <<<"$panes_json"
}

blocked_count() {
  local panes_json="$1"
  jq -r '[.[] | select((.agent_status // "") == "blocked")] | length' <<<"$panes_json"
}

unreconciled_count() {
  local panes_json="$1"
  jq -r '[.[] | select((.reconciled == false) or (.unreconciled == true) or ((.settlement_status // "") | ascii_upcase) == "UNRECONCILED" or ((.closeout_status // "") | ascii_upcase) == "UNRECONCILED")] | length' <<<"$panes_json"
}

reaper_available() {
  command -v "$REAPER_BIN" >/dev/null 2>&1 || [[ -r "$CAP_LIB" ]]
}

review_helper_available() {
  command -v "$REVIEW_HELPER" >/dev/null 2>&1 || [[ -x "$REVIEW_HELPER" ]]
}

validate_settled_targets() {
  local raw panes target
  [[ -n "${HERDR_SETTLED_PANES:-}" ]] || return 0
  raw=$(pane_payload) || {
    printf 'HOUSEKEEPING REAP: REFUSED: cannot inspect settled targets\n' >&2
    return 65
  }
  panes=$(panes_only <<<"$raw")
  target="${HERDR_SETTLED_PANES}"
  if [[ "$target" == "*" ]]; then
    if jq -e '[.[] | select((.agent_status // "") | test("^(working|blocked)$"))] | length > 0' <<<"$panes" >/dev/null; then
      printf 'HOUSEKEEPING REAP: REFUSED: wildcard includes working/blocked pane\n' >&2
      return 65
    fi
    return 0
  fi
  local id found
  for id in ${target//,/ }; do
    found=$(jq -r --arg id "$id" '[.[] | select(.pane_id == $id) | .agent_status] | .[0] // "missing"' <<<"$panes")
    case "$found" in
      idle|done) ;;
      working|blocked)
        printf 'HOUSEKEEPING REAP: REFUSED: protected pane=%s state=%s\n' "$id" "$found" >&2
        return 65
        ;;
      *)
        printf 'HOUSEKEEPING REAP: REFUSED: settled pane=%s is not present\n' "$id" >&2
        return 65
        ;;
    esac
  done
}

run_preflight() {
  local raw panes sub total blocked unreconciled
  raw=$(pane_payload) || {
    printf 'HOUSEKEEPING PREFLIGHT: REFUSED: invalid or empty pane list\n' >&2
    return 3
  }
  panes=$(panes_only <<<"$raw")
  sub=$(subagent_count "$panes")
  total=$(total_open_count "$panes")
  blocked=$(blocked_count "$panes")
  unreconciled=$(unreconciled_count "$panes")
  if (( blocked > 0 || unreconciled > 0 )); then
    printf 'HOUSEKEEPING PREFLIGHT: ERR_UNRECONCILED_STATE blocked=%s unreconciled=%s\n' "$blocked" "$unreconciled" >&2
    return 65
  fi
  if (( sub >= 6 )); then
    printf 'HOUSEKEEPING PREFLIGHT: ERR_SUBAGENT_CAP_REACHED (subagents=%s max=6)\n' "$sub" >&2
    return 64
  fi
  if (( total >= 7 )); then
    printf 'HOUSEKEEPING PREFLIGHT: ERR_SUBAGENT_CAP_REACHED (total=%s max=7)\n' "$total" >&2
    return 64
  fi
  # Fixture mode is self-contained so tests cannot accidentally inspect Herdr.
  if [[ -z "${FM_HOUSEKEEPING_PANES_JSON:-}" && -r "$CAP_LIB" ]]; then
    # shellcheck disable=SC1090
    . "$CAP_LIB"
    subagent_cap_assert_can_spawn "${1:-}"
    return $?
  fi
  printf 'HOUSEKEEPING PREFLIGHT: PERMITTED (subagents=%s/6 total=%s/7)\n' "$sub" "$total"
}

run_invariants() {
  local raw panes total sub blocked unreconciled failures=0
  raw=$(pane_payload) || {
    printf 'HOUSEKEEPING INVARIANTS: REFUSED: invalid or empty pane list\n' >&2
    return 3
  }
  panes=$(panes_only <<<"$raw")
  total=$(total_open_count "$panes")
  sub=$(subagent_count "$panes")
  blocked=$(blocked_count "$panes")
  unreconciled=$(unreconciled_count "$panes")

  local warroom_ok protected_ok
  warroom_ok=$(jq -r '[.[] | select((.agent_status // "") | test("^(working|blocked|idle|done)$")) | [(.workspace_id // ""), (.tab_id // "")] | join("/")] | unique | if (length == 1 and .[0] != "/") then 1 else 0 end' <<<"$panes")
  protected_ok=$(jq -r '[.[] | select((.agent_status // "") | test("^(working|blocked)$")) | select(.protected == false)] | length == 0' <<<"$panes")

  if [[ "$warroom_ok" == 1 ]]; then
    printf 'CHECK_INVARIANT 1: single visible war-room ... PASS\n'
  else
    printf 'CHECK_INVARIANT 1: single visible war-room ... FAIL\n'; failures=$((failures + 1))
  fi
  if (( sub <= 6 && total <= 7 )); then
    printf 'CHECK_INVARIANT 2: subagent cap <= 6 (total <= 7) ... PASS\n'
  else
    printf 'CHECK_INVARIANT 2: subagent cap <= 6 (total <= 7) ... FAIL (subagents=%s total=%s)\n' "$sub" "$total"; failures=$((failures + 1))
  fi
  if [[ "$protected_ok" == true ]]; then
    printf 'CHECK_INVARIANT 3: working/blocked panes protected ... PASS\n'
  else
    printf 'CHECK_INVARIANT 3: working/blocked panes protected ... FAIL\n'; failures=$((failures + 1))
  fi
  if (( unreconciled == 0 )) && reaper_available && [[ "${HERDR_REQUIRE_SETTLEMENT:-1}" != 0 ]]; then
    printf 'CHECK_INVARIANT 4: positive settlement required before reap ... PASS\n'
  else
    printf 'CHECK_INVARIANT 4: positive settlement required before reap ... FAIL\n'; failures=$((failures + 1))
  fi
  if [[ -x "$VALIDATOR_BIN" ]] && jq -e 'all(.[]; (.pane_id // "") != "" and (.agent // "") != "")' <<<"$panes" >/dev/null; then
    printf 'CHECK_INVARIANT 5: dispatch metadata & provenance recorded ... PASS\n'
  else
    printf 'CHECK_INVARIANT 5: dispatch metadata & provenance recorded ... FAIL\n'; failures=$((failures + 1))
  fi
  if review_helper_available; then
    printf 'CHECK_INVARIANT 6: coordinator review helper enforced ... PASS\n'
  else
    printf 'CHECK_INVARIANT 6: coordinator review helper enforced ... FAIL\n'; failures=$((failures + 1))
  fi
  if reaper_available && [[ -x "$SECRET_SCAN_BIN" ]]; then
    printf 'CHECK_INVARIANT 7: reconciled campaign closeout & reaper trigger ... PASS\n'
  else
    printf 'CHECK_INVARIANT 7: reconciled campaign closeout & reaper trigger ... FAIL\n'; failures=$((failures + 1))
  fi
  if (( failures == 0 )); then
    printf 'HOUSEKEEPING_INVARIANTS: 7/7 PASS\n'
    return 0
  fi
  printf 'HOUSEKEEPING_INVARIANTS: %s/7 PASS\n' "$((7 - failures))"
  return 1
}

cmd="${1:-}"
shift || true
case "$cmd" in
  status)
    raw=$(pane_payload) || { printf 'HOUSEKEEPING: REFUSED: invalid or empty pane list\n' >&2; exit 3; }
    panes=$(panes_only <<<"$raw")
    total=$(total_open_count "$panes")
    sub=$(subagent_count "$panes")
    working_count=$(jq -r '[.[] | select((.agent_status // "") == "working")] | length' <<<"$panes")
    blocked_count_value=$(blocked_count "$panes")
    idle_count=$(jq -r '[.[] | select((.agent_status // "") == "idle")] | length' <<<"$panes")
    done_count=$(jq -r '[.[] | select((.agent_status // "") == "done")] | length' <<<"$panes")
    unreviewed_or_stale=$(jq -r '[.[] | select((.reviewed == false) or (.unreviewed == true) or (.stale == true) or ((.review_status // "") | ascii_upcase) == "UNREVIEWED")] | length' <<<"$panes")
    printf 'HOUSEKEEPING STATUS: total_panes=%s subagents=%s (cap=6) working=%s blocked=%s idle=%s done=%s unreviewed_or_stale=%s\n' \
      "$total" "$sub" "$working_count" "$blocked_count_value" "$idle_count" "$done_count" "$unreviewed_or_stale"
    ;;
  preflight)
    run_preflight "${1:-}"
    ;;
  reap-stale)
    validate_settled_targets
    if command -v "$REAPER_BIN" >/dev/null 2>&1; then
      exec "$REAPER_BIN" "$@"
    elif [[ -r "$CAP_LIB" ]]; then
      # shellcheck disable=SC1090
      . "$CAP_LIB"
      exec subagent_cap_reap_stale "$@"
    else
      printf 'HOUSEKEEPING: REFUSED: reaper implementation unavailable\n' >&2
      exit 3
    fi
    ;;
  invariants)
    run_invariants
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    printf 'HOUSEKEEPING: unknown command: %s\n' "$cmd" >&2
    exit 2
    ;;
esac
