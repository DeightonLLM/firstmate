#!/usr/bin/env bash
# fm-provider-window.sh - deterministic vendor schedule gate.
#
# Usage:
#   fm-provider-window.sh <glm|glm-5.3-flash|minimax|m3|agy|gemini|codex>
#       [--at <unix-seconds>]
#
# The command answers only whether a provider's published time window permits
# a new request. It does not read quota, credentials, or provider catalogs and
# it never selects a model. Firstmate's quota-array procedure owns candidate
# selection after this calendar gate.
#
# Z.AI publishes peak time as Monday-Friday 14:00-18:00 Asia/Singapore, with
# off-peak model usage charged at 50% of standard. MiniMax publishes weekday
# 15:00-17:30 peak traffic but omits the timezone; this helper uses a visible,
# provisional UTC+8 interpretation (Asia/Singapore) until an operator pins a
# different supported source timezone with FM_MINIMAX_SOURCE_TZ.
set -euo pipefail

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

provider=""
provider_label=""
at_epoch=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    glm|glm-5.3-flash|glm-5.3|zai)
      [[ -z "$provider" ]] || { printf 'error: provider specified twice\n' >&2; exit 64; }
      provider=glm
      provider_label=glm
      shift
      ;;
    minimax|m3|m2.7|minimax-m3|minimax-m2.7)
      [[ -z "$provider" ]] || { printf 'error: provider specified twice\n' >&2; exit 64; }
      provider=minimax
      provider_label=minimax
      shift
      ;;
    agy|gemini|gemini-3.8-flash-medium|codex)
      [[ -z "$provider" ]] || { printf 'error: provider specified twice\n' >&2; exit 64; }
      provider=always
      provider_label=$1
      shift
      ;;
    --at)
      [[ $# -ge 2 ]] || { printf 'error: --at requires unix seconds\n' >&2; exit 64; }
      at_epoch=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown provider or option: %s\n' "$1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

[[ -n "$provider" ]] || { printf 'error: provider is required\n' >&2; usage >&2; exit 64; }

if [[ -z "$at_epoch" ]]; then
  at_epoch=$(date +%s)
fi
[[ "$at_epoch" =~ ^[0-9]+$ ]] || {
  printf 'error: --at must be non-negative unix seconds\n' >&2
  exit 64
}

source_tz=""
window_start=0
window_end=0
window_label=""
confidence=""
case "$provider" in
  glm)
    source_tz=Asia/Singapore
    window_start=$((14 * 60))
    window_end=$((18 * 60))
    window_label=14:00-18:00
    confidence=published
    ;;
  minimax)
    source_tz="${FM_MINIMAX_SOURCE_TZ:-Asia/Singapore}"
    case "$source_tz" in
      Asia/Singapore|Asia/Shanghai) ;;
      *)
        printf 'error: FM_MINIMAX_SOURCE_TZ must be Asia/Singapore or Asia/Shanghai\n' >&2
        exit 64
        ;;
    esac
    window_start=$((15 * 60))
    window_end=$((17 * 60 + 30))
    window_label=15:00-17:30
    confidence=provisional
    ;;
  always)
    printf 'PROVIDER=%s\n' "$provider_label"
    printf 'SOURCE_TZ=none\n'
    printf 'SOURCE_WINDOW=none\n'
    printf 'UK_LOCAL_TIME=%s\n' "$(TZ=Europe/London date -d "@$at_epoch" '+%Y-%m-%dT%H:%M:%S%z')"
    printf 'SCHEDULE_STATE=not_applicable\n'
    printf 'SCHEDULE_ALLOWED=1\n'
    printf 'SCHEDULE_CONFIDENCE=not_applicable\n'
    printf 'SCHEDULE_REASON=no published provider peak window configured\n'
    exit 0
    ;;
esac

source_weekday=$(TZ="$source_tz" date -d "@$at_epoch" +%u)
source_hour=$(TZ="$source_tz" date -d "@$at_epoch" +%H)
source_minute=$(TZ="$source_tz" date -d "@$at_epoch" +%M)
source_minute_of_day=$((10#$source_hour * 60 + 10#$source_minute))
source_time=$(TZ="$source_tz" date -d "@$at_epoch" '+%Y-%m-%dT%H:%M:%S%z')
uk_time=$(TZ=Europe/London date -d "@$at_epoch" '+%Y-%m-%dT%H:%M:%S%z')

state=off_peak
allowed=1
reason="outside published weekday peak window"
if [[ "$source_weekday" -le 5 ]] &&
   [[ "$source_minute_of_day" -ge "$window_start" ]] &&
   [[ "$source_minute_of_day" -lt "$window_end" ]]; then
  state=peak
  allowed=0
  reason="inside published weekday peak window"
fi
if [[ "$provider" == minimax ]]; then
  reason="$reason; MiniMax source timezone is not published, using provisional $source_tz interpretation"
fi

printf 'PROVIDER=%s\n' "$provider_label"
printf 'SOURCE_TZ=%s\n' "$source_tz"
printf 'SOURCE_TIME=%s\n' "$source_time"
printf 'SOURCE_WINDOW=%s\n' "$window_label"
printf 'UK_LOCAL_TIME=%s\n' "$uk_time"
printf 'SCHEDULE_STATE=%s\n' "$state"
printf 'SCHEDULE_ALLOWED=%s\n' "$allowed"
printf 'SCHEDULE_CONFIDENCE=%s\n' "$confidence"
printf 'SCHEDULE_REASON=%s\n' "$reason"
