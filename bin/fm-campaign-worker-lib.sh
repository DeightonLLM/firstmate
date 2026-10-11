#!/usr/bin/env bash
# Bounded authority envelope for a controller-registered worker.
#
# A worker may be admitted while the shared First Mate fleet lock is held by
# the controller, but only when this marker binds the fresh pane to one
# unchanged task prompt, one run, one model lane, and two exact output files.
# This library never changes fleet state and never grants spawn/steer/merge
# authority.  It is safe to source from session-start and from the fresh-agent
# launcher.

fm_campaign_worker_fail() {
  local field=${1:-unknown} message=${2:-invalid marker}
  printf 'CAMPAIGN_WORKER_AUTHORITY_INVALID field=%s reason=%s\n' "$field" "$message" >&2
  exit 69
}

fm_campaign_worker_refuse() {
  local field=${1:-unknown} message=${2:-marker creation refused}
  printf 'CAMPAIGN_WORKER_MARKER_REFUSED field=%s reason=%s\n' "$field" "$message" >&2
  exit 69
}

fm_campaign_worker_marker_path() {
  local dir=${1:-} pane=${2:-} pane_key
  [ -n "$dir" ] && [ -n "$pane" ] || return 64
  case "$dir" in /*) ;; *) return 64 ;; esac
  pane_key="${pane//[^A-Za-z0-9_.:-]/_}"
  [ -n "$pane_key" ] || return 64
  printf '%s/%s.worker\n' "${dir%/}" "$pane_key"
}

fm_campaign_worker_field() {
  local key=${1:-} marker=${2:-}
  [ -n "$key" ] && [ -r "$marker" ] || return 1
  awk -v wanted="$key" '
    index($0, wanted ":") == 1 {
      sub("^" wanted ":", "")
      print
      exit
    }
  ' "$marker"
}

fm_campaign_worker_no_newline() {
  case "${1:-}" in
    *$'\n'*|*$'\r'*) return 1 ;;
    *) return 0 ;;
  esac
}

fm_campaign_worker_safe_token() {
  local value=${1:-}
  fm_campaign_worker_no_newline "$value" || return 1
  case "$value" in
    ''|*[!A-Za-z0-9._:/-]*) return 1 ;;
    *) return 0 ;;
  esac
}

fm_campaign_worker_realpath() {
  realpath -m -- "${1:-}" 2>/dev/null
}

fm_campaign_worker_validate_paths() {
  local task_file=$1 artifact=$2 lease=$3 task_real task_dir artifact_real lease_real
  case "$task_file" in /*) ;; *) return 1 ;; esac
  case "$artifact" in /*) ;; *) return 1 ;; esac
  case "$lease" in /*) ;; *) return 1 ;; esac
  [ -f "$task_file" ] && [ ! -L "$task_file" ] || return 1
  [ ! -d "$artifact" ] && [ ! -d "$lease" ] || return 1
  [ ! -L "$artifact" ] && [ ! -L "$lease" ] || return 1
  task_real=$(realpath -e -- "$task_file" 2>/dev/null) || return 1
  task_dir=$(dirname -- "$task_real")
  artifact_real=$(fm_campaign_worker_realpath "$artifact") || return 1
  lease_real=$(fm_campaign_worker_realpath "$lease") || return 1
  case "$artifact_real" in "$task_dir"/*) ;; *) return 1 ;; esac
  case "$lease_real" in "$task_dir"/*) ;; *) return 1 ;; esac
  [ "$artifact_real" != "$task_real" ] || return 1
  [ "$lease_real" != "$task_real" ] || return 1
  [ "$artifact_real" != "$lease_real" ] || return 1
  [ -d "$(dirname -- "$lease_real")" ] || return 1
  return 0
}

fm_campaign_worker_create_marker() (
  set -e
  local marker_dir="${HERDR_CAMPAIGN_WORKER_MARKER_DIR:-/tmp/herdr-campaign-state}"
  local state="${HERDR_CAMPAIGN_WORKER_CONTROLLER_STATE:-}"
  local run_id="${HERDR_CAMPAIGN_WORKER_RUN_ID:-}"
  local task_id="${HERDR_CAMPAIGN_WORKER_TASK_ID:-}"
  local host="${HERDR_CAMPAIGN_WORKER_HOST:-}"
  local kind="${HERDR_CAMPAIGN_WORKER_KIND:-}"
  local model="${HERDR_CAMPAIGN_WORKER_MODEL:-}"
  local pane="${HERDR_CAMPAIGN_WORKER_PANE:-}"
  local task_file="${HERDR_CAMPAIGN_WORKER_TASK_FILE:-}"
  local artifact="${HERDR_CAMPAIGN_WORKER_ARTIFACT:-}"
  local lease="${HERDR_CAMPAIGN_WORKER_LEASE:-}"
  local max_seconds="${HERDR_CAMPAIGN_WORKER_MAX_SECONDS:-3600}"
  local lock_pid marker tmp now expires old

  [ "${HERDR_OPERATOR_APPROVED:-0}" = 1 ] ||
    fm_campaign_worker_refuse operator_approved missing
  [ -d "$marker_dir" ] || mkdir -p -m 700 -- "$marker_dir" 2>/dev/null ||
    fm_campaign_worker_refuse marker_dir unavailable
  chmod 700 -- "$marker_dir" 2>/dev/null ||
    fm_campaign_worker_refuse marker_dir permissions
  [ -n "$state" ] && [ -d "$state" ] ||
    fm_campaign_worker_refuse controller_state missing
  case "$state" in /*) ;; *) fm_campaign_worker_refuse controller_state not_absolute ;; esac
  [ -f "$state/.lock" ] && [ ! -L "$state/.lock" ] ||
    fm_campaign_worker_refuse controller_lock missing
  lock_pid=$(sed -n '1p' "$state/.lock" 2>/dev/null || true)
  [[ "$lock_pid" =~ ^[0-9]+$ ]] ||
    fm_campaign_worker_refuse controller_lock invalid
  fm_campaign_worker_safe_token "$run_id" || fm_campaign_worker_refuse run_id invalid
  fm_campaign_worker_safe_token "$task_id" || fm_campaign_worker_refuse task_id invalid
  fm_campaign_worker_safe_token "$host" || fm_campaign_worker_refuse host invalid
  fm_campaign_worker_safe_token "$kind" || fm_campaign_worker_refuse kind invalid
  fm_campaign_worker_safe_token "$model" || fm_campaign_worker_refuse model invalid
  fm_campaign_worker_safe_token "$pane" || fm_campaign_worker_refuse pane invalid
  case "$task_file" in /*) ;; *) fm_campaign_worker_refuse task_file not_absolute ;; esac
  case "$artifact" in /*) ;; *) fm_campaign_worker_refuse artifact not_absolute ;; esac
  case "$lease" in /*) ;; *) fm_campaign_worker_refuse lease not_absolute ;; esac
  fm_campaign_worker_validate_paths "$task_file" "$artifact" "$lease" ||
    fm_campaign_worker_refuse write_boundary not_task_scoped
  [[ "$max_seconds" =~ ^[0-9]+$ ]] &&
    [ "$max_seconds" -ge 60 ] && [ "$max_seconds" -le 604800 ] ||
    fm_campaign_worker_refuse expires invalid

  marker=$(fm_campaign_worker_marker_path "$marker_dir" "$pane") ||
    fm_campaign_worker_refuse marker_path invalid
  [ ! -e "$marker" ] || [ ! -L "$marker" ] ||
    fm_campaign_worker_refuse marker_path symlink
  if [ -f "$marker" ]; then
    old=$(fm_campaign_worker_field run_id "$marker" || true)
    [ -z "$old" ] || [ "$old" = "$run_id" ] ||
      fm_campaign_worker_refuse run_id existing_marker_mismatch
    old=$(fm_campaign_worker_field task_id "$marker" || true)
    [ -z "$old" ] || [ "$old" = "$task_id" ] ||
      fm_campaign_worker_refuse task_id existing_marker_mismatch
    old=$(fm_campaign_worker_field pane "$marker" || true)
    [ -z "$old" ] || [ "$old" = "$pane" ] ||
      fm_campaign_worker_refuse pane existing_marker_mismatch
  fi

  now=$(date +%s)
  expires=$((now + max_seconds))
  tmp="${marker}.tmp.$$"
  umask 077
  {
    printf 'version:1\n'
    printf 'run_id:%s\n' "$run_id"
    printf 'task_id:%s\n' "$task_id"
    printf 'host:%s\n' "$host"
    printf 'kind:%s\n' "$kind"
    printf 'model:%s\n' "$model"
    printf 'pane:%s\n' "$pane"
    printf 'task_file:%s\n' "$task_file"
    printf 'task_sha:%s\n' "$(sha256sum -- "$task_file" | awk '{print $1}')"
    printf 'artifact:%s\n' "$artifact"
    printf 'lease:%s\n' "$lease"
    printf 'write_boundary:artifact+lease\n'
    printf 'controller_state:%s\n' "$state"
    printf 'controller_lock_pid:%s\n' "$lock_pid"
    printf 'operator_approved:1\n'
    printf 'created:%s\n' "$now"
    printf 'expires:%s\n' "$expires"
  } > "$tmp" || {
    rm -f -- "$tmp" 2>/dev/null || true
    fm_campaign_worker_refuse marker_path write_failed
  }
  chmod 600 -- "$tmp" || {
    rm -f -- "$tmp" 2>/dev/null || true
    fm_campaign_worker_refuse marker_path permissions
  }
  mv -f -- "$tmp" "$marker" || {
    rm -f -- "$tmp" 2>/dev/null || true
    fm_campaign_worker_refuse marker_path publish_failed
  }
  printf 'CAMPAIGN_WORKER_MARKER_CREATED marker=%s run_id=%s task_id=%s pane=%s expires=%s\n' \
    "$marker" "$run_id" "$task_id" "$pane" "$expires"
)

fm_campaign_worker_validate_marker() (
  set -e
  local marker=${1:-} state=${2:-}
  local version run_id task_id host kind model pane task_file task_sha artifact lease
  local write_boundary controller_state controller_lock_pid operator_approved expires now
  local current_sha lock_pid marker_dir expected

  [ -n "$marker" ] && [ -f "$marker" ] && [ ! -L "$marker" ] ||
    fm_campaign_worker_fail marker missing_or_symlink
  marker_dir="${HERDR_CAMPAIGN_WORKER_MARKER_DIR:-$(dirname -- "$marker")}"
  [ -d "$marker_dir" ] || fm_campaign_worker_fail marker_dir missing
  [ "$(stat -c '%a' "$marker_dir" 2>/dev/null || printf 0)" = 700 ] ||
    fm_campaign_worker_fail marker_dir permissions
  [ "$(stat -c '%a' "$marker" 2>/dev/null || printf 0)" = 600 ] ||
    fm_campaign_worker_fail marker permissions
  expected=$(fm_campaign_worker_marker_path "$marker_dir" "${HERDR_CAMPAIGN_WORKER_PANE:-}") ||
    fm_campaign_worker_fail marker path_invalid
  [ "$marker" = "$expected" ] || fm_campaign_worker_fail marker path_mismatch

  version=$(fm_campaign_worker_field version "$marker")
  [ "$version" = 1 ] || fm_campaign_worker_fail version unsupported
  run_id=$(fm_campaign_worker_field run_id "$marker")
  task_id=$(fm_campaign_worker_field task_id "$marker")
  host=$(fm_campaign_worker_field host "$marker")
  kind=$(fm_campaign_worker_field kind "$marker")
  model=$(fm_campaign_worker_field model "$marker")
  pane=$(fm_campaign_worker_field pane "$marker")
  task_file=$(fm_campaign_worker_field task_file "$marker")
  task_sha=$(fm_campaign_worker_field task_sha "$marker")
  artifact=$(fm_campaign_worker_field artifact "$marker")
  lease=$(fm_campaign_worker_field lease "$marker")
  write_boundary=$(fm_campaign_worker_field write_boundary "$marker")
  controller_state=$(fm_campaign_worker_field controller_state "$marker")
  controller_lock_pid=$(fm_campaign_worker_field controller_lock_pid "$marker")
  operator_approved=$(fm_campaign_worker_field operator_approved "$marker")
  expires=$(fm_campaign_worker_field expires "$marker")

  fm_campaign_worker_safe_token "$run_id" || fm_campaign_worker_fail run_id invalid
  fm_campaign_worker_safe_token "$task_id" || fm_campaign_worker_fail task_id invalid
  fm_campaign_worker_safe_token "$host" || fm_campaign_worker_fail host invalid
  fm_campaign_worker_safe_token "$kind" || fm_campaign_worker_fail kind invalid
  fm_campaign_worker_safe_token "$model" || fm_campaign_worker_fail model invalid
  fm_campaign_worker_safe_token "$pane" || fm_campaign_worker_fail pane invalid
  [ "$host" = controller-local ] || fm_campaign_worker_fail host not_approved
  [ "$write_boundary" = artifact+lease ] || fm_campaign_worker_fail write_boundary broadened
  [ "$operator_approved" = 1 ] || fm_campaign_worker_fail operator_approved missing
  [[ "$task_sha" =~ ^[[:xdigit:]]{64}$ ]] || fm_campaign_worker_fail task_sha invalid
  [[ "$controller_lock_pid" =~ ^[0-9]+$ ]] || fm_campaign_worker_fail controller_lock invalid
  [[ "$expires" =~ ^[0-9]+$ ]] || fm_campaign_worker_fail expires invalid
  now=$(date +%s)
  [ "$expires" -gt "$now" ] || fm_campaign_worker_fail expires expired

  [ -n "$state" ] && [ -d "$state" ] || fm_campaign_worker_fail controller_state missing
  [ "$(fm_campaign_worker_realpath "$controller_state")" = "$(fm_campaign_worker_realpath "$state")" ] ||
    fm_campaign_worker_fail controller_state mismatch
  [ -f "$state/.lock" ] && [ ! -L "$state/.lock" ] || fm_campaign_worker_fail controller_lock missing
  lock_pid=$(sed -n '1p' "$state/.lock" 2>/dev/null || true)
  [ "$lock_pid" = "$controller_lock_pid" ] || fm_campaign_worker_fail controller_lock changed
  if ! declare -F fm_harness_pid_alive >/dev/null 2>&1; then
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck source=bin/fm-session-lock-lib.sh
    . "$lib_dir/fm-session-lock-lib.sh"
  fi
  fm_harness_pid_alive "$controller_lock_pid" || fm_campaign_worker_fail controller_lock not_live_verified

  [ -f "$task_file" ] && [ ! -L "$task_file" ] || fm_campaign_worker_fail task_file missing_or_symlink
  current_sha=$(sha256sum -- "$task_file" 2>/dev/null | awk '{print $1}')
  [ "$current_sha" = "$task_sha" ] || fm_campaign_worker_fail task_sha changed
  fm_campaign_worker_validate_paths "$task_file" "$artifact" "$lease" ||
    fm_campaign_worker_fail write_boundary paths_outside_task_scope

  expected="${HERDR_CAMPAIGN_WORKER_PANE:-}"
  [ -z "$expected" ] || [ "$pane" = "$expected" ] || fm_campaign_worker_fail pane mismatch
  expected="${HERDR_CAMPAIGN_WORKER_KIND:-}"
  [ -z "$expected" ] || [ "$kind" = "$expected" ] || fm_campaign_worker_fail kind mismatch
  expected="${HERDR_CAMPAIGN_WORKER_MODEL:-}"
  [ -z "$expected" ] || [ "$model" = "$expected" ] || fm_campaign_worker_fail model mismatch
  expected="${HERDR_CAMPAIGN_WORKER_RUN_ID:-}"
  [ -z "$expected" ] || [ "$run_id" = "$expected" ] || fm_campaign_worker_fail run_id mismatch
  expected="${HERDR_CAMPAIGN_WORKER_TASK_ID:-}"
  [ -z "$expected" ] || [ "$task_id" = "$expected" ] || fm_campaign_worker_fail task_id mismatch
  return 0
)
