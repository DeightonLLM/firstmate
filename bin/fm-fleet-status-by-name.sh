#!/usr/bin/env bash
# fm-fleet-status-by-name.sh - verified fleet status keyed by tab label across all homes.
#
# Emits live verified fleet state without caching:
# - Fail loudly on unreachable host.
# - Keyed by tab label (never raw pane id as crew identity; "(no label)" if missing).
# - Distinguishes idle / done / working / blocked / unknown live agent status.
# - Reports watcher liveness based on beacon age against FM_GUARD_GRACE.
# - Captures harness and model actually shown in the pane.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_GUARD_GRACE="${FM_GUARD_GRACE:-300}"

# Default hosts:
# format: name|ssh_target|home_dir
DEFAULT_HOSTS=(
  "Controller|root@100.117.47.27|/root/agent-work/deightonllm-firstmate"
  "HD2|root@100.71.95.76|/root/agent-work/deightonllm-firstmate"
  "Brandon|hd2admin@100.106.6.22|/home/hd2admin/agent-work/deightonllm-firstmate"
)

HOSTS=()

usage() {
  cat <<'USAGE'
usage: fm-fleet-status-by-name.sh [--json] [--host-override "<name>:<target>:<home>"]

Emits live verified fleet status keyed by tab label across all firstmate homes.
USAGE
}

JSON_OUTPUT=0
HOST_OVERRIDES=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --json) JSON_OUTPUT=1; shift ;;
    --host-override)
      HOST_OVERRIDES+=("$2")
      shift 2
      ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [ ${#HOST_OVERRIDES[@]} -gt 0 ]; then
  for ho in "${HOST_OVERRIDES[@]}"; do
    IFS=":" read -r hname htarget hhome <<< "$ho"
    HOSTS+=("${hname}|${htarget}|${hhome}")
  done
else
  HOSTS=("${DEFAULT_HOSTS[@]}")
fi

command -v jq >/dev/null 2>&1 || { echo "fm-fleet-status-by-name: jq required" >&2; exit 1; }

MY_IPS=$(hostname -I 2>/dev/null || true)

run_on_host() {
  local target="$1"
  local cmd="$2"

  if [ "$target" = "localhost" ] || [ "$target" = "127.0.0.1" ] || [ "$target" = "local" ]; then
    bash -c "$cmd"
    return $?
  fi

  local host_part="${target#*@}"
  for ip in $MY_IPS; do
    if [ "$host_part" = "$ip" ]; then
      bash -c "$cmd"
      return $?
    fi
  done

  local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new)
  if [ -r "/root/.ssh/id_ed25519_1panel" ] && [[ "$target" == *"100.71.95.76"* ]]; then
    ssh_opts+=(-i "/root/.ssh/id_ed25519_1panel")
  fi

  ssh "${ssh_opts[@]}" "$target" "$cmd"
}

HOST_RESULTS=()
HAS_ERROR=0

for h in "${HOSTS[@]}"; do
  IFS="|" read -r H_NAME H_TARGET H_HOME <<< "$h"

  CHECK_SCRIPT='
set -eu
export PATH="$HOME/.local/bin:$PATH:/root/bin:/usr/local/bin"
NOW=$(date +%s)
BEACON_FILE="$1/state/.last-watcher-beat"
BEACON_AGE="missing"
if [ -f "$BEACON_FILE" ]; then
  MTIME=$(stat -c %Y "$BEACON_FILE" 2>/dev/null || stat -f %m "$BEACON_FILE" 2>/dev/null || echo 0)
  if [ "$MTIME" -gt 0 ]; then
    BEACON_AGE=$((NOW - MTIME))
  fi
fi

HERDR_BIN=$(which herdr 2>/dev/null || true)
if [ -z "$HERDR_BIN" ]; then
  for p in /root/.local/bin/herdr /home/hd2admin/.local/bin/herdr /usr/local/bin/herdr; do
    if [ -x "$p" ]; then HERDR_BIN="$p"; break; fi
  done
fi

echo "---BEACON---"
echo "$BEACON_AGE"
echo "---HERDR_BIN---"
echo "$HERDR_BIN"
echo "---TABS---"
if [ -n "$HERDR_BIN" ]; then
  "$HERDR_BIN" tab list 2>/dev/null || echo "TAB_LIST_ERR"
else
  echo "TAB_LIST_ERR"
fi
echo "---PANES---"
if [ -n "$HERDR_BIN" ]; then
  "$HERDR_BIN" pane list 2>/dev/null || echo "PANE_LIST_ERR"
else
  echo "PANE_LIST_ERR"
fi
echo "---END---"
'

  HOST_OUTPUT=""
  HOST_EXIT=0
  HOST_OUTPUT=$(run_on_host "$H_TARGET" "bash -c '$CHECK_SCRIPT' -- '$H_HOME'" 2>&1) || HOST_EXIT=$?

  if [ $HOST_EXIT -ne 0 ]; then
    echo "ERROR: Host '$H_NAME' ($H_TARGET) is unreachable: $HOST_OUTPUT" >&2
    HAS_ERROR=1
    continue
  fi

  BEACON_AGE=$(echo "$HOST_OUTPUT" | sed -n '/^---BEACON---$/,/^---HERDR_BIN---$/{//!p}' | head -n 1)
  HERDR_BIN=$(echo "$HOST_OUTPUT" | sed -n '/^---HERDR_BIN---$/,/^---TABS---$/{//!p}' | head -n 1)
  TABS_RAW=$(echo "$HOST_OUTPUT" | sed -n '/^---TABS---$/,/^---PANES---$/{//!p}')
  PANES_RAW=$(echo "$HOST_OUTPUT" | sed -n '/^---PANES---$/,/^---END---$/{//!p}')

  WATCHER_STATUS="unknown"
  if [ "$BEACON_AGE" = "missing" ]; then
    WATCHER_STATUS="missing (no beacon)"
  elif [[ "$BEACON_AGE" =~ ^[0-9]+$ ]]; then
    if [ "$BEACON_AGE" -le "$FM_GUARD_GRACE" ]; then
      WATCHER_STATUS="live (${BEACON_AGE}s old <= ${FM_GUARD_GRACE}s grace)"
    else
      WATCHER_STATUS="stale (${BEACON_AGE}s old > ${FM_GUARD_GRACE}s grace)"
    fi
  fi

  CREWS_JSON="[]"
  if [ -n "$TABS_RAW" ] && [ "$TABS_RAW" != "TAB_LIST_ERR" ] && [ -n "$PANES_RAW" ] && [ "$PANES_RAW" != "PANE_LIST_ERR" ]; then
    CREWS_JSON=$(jq -n --argjson tabs "$TABS_RAW" --argjson panes "$PANES_RAW" '
      def get_panes($tab_id): [ $panes.result.panes[] | select(.tab_id == $tab_id) ];
      [
        $tabs.result.tabs[] |
        . as $t |
        get_panes($t.tab_id) as $p |
        {
          tab_id: $t.tab_id,
          label: (if ($t.label // "") == "" then "(no label)" else $t.label end),
          tab_agent_status: ($t.agent_status // "unknown"),
          panes: [
            $p[] |
            {
              pane_id: .pane_id,
              agent: (.agent // "unknown"),
              agent_status: (.agent_status // "unknown"),
              pane_label: (.label // ""),
              terminal_title: (.terminal_title // "")
            }
          ]
        }
      ]
    ' 2>/dev/null || echo "[]")
  fi

  ENRICHED_CREWS="[]"
  TAB_COUNT=$(echo "$CREWS_JSON" | jq 'length')
  
  for ((i=0; i<TAB_COUNT; i++)); do
    TAB_ITEM=$(echo "$CREWS_JSON" | jq ".[$i]")
    TAB_ID=$(echo "$TAB_ITEM" | jq -r '.tab_id')
    TAB_LABEL=$(echo "$TAB_ITEM" | jq -r '.label')
    PANE_COUNT=$(echo "$TAB_ITEM" | jq '.panes | length')

    ENRICHED_PANES="[]"
    for ((j=0; j<PANE_COUNT; j++)); do
      P_ITEM=$(echo "$TAB_ITEM" | jq ".panes[$j]")
      P_ID=$(echo "$P_ITEM" | jq -r '.pane_id')
      P_AGENT=$(echo "$P_ITEM" | jq -r '.agent')
      P_STATUS=$(echo "$P_ITEM" | jq -r '.agent_status')

      # Read tail lines of pane from herdr
      READ_CMD="export PATH=\"\$HOME/.local/bin:\$PATH:/root/bin:/usr/local/bin\"; $HERDR_BIN pane read '$P_ID' --lines 10 2>/dev/null || true"
      PANE_READ=$(run_on_host "$H_TARGET" "$READ_CMD" 2>/dev/null || true)

      MODEL="unknown"
      if echo "$PANE_READ" | grep -q -i "Gemini 3.8 Flash"; then
        MODEL="Gemini 3.8 Flash"
      elif echo "$PANE_READ" | grep -q -i "gpt-6.1-sol"; then
        MODEL="gpt-6.1-sol"
      elif echo "$PANE_READ" | grep -q -i "GPT-6-Luna"; then
        MODEL="GPT-6-Luna"
      elif echo "$PANE_READ" | grep -q -i "claude"; then
        MODEL="Claude"
      fi

      ENRICHED_PANES=$(echo "$ENRICHED_PANES" | jq --argjson p "$P_ITEM" --arg model "$MODEL" --arg read "$PANE_READ" '
        . + [$p + {model: $model}]
      ')
    done

    # Live agent status of the crew: if tab has pane(s), take primary pane agent_status
    # If no panes attached to tab, fallback to tab_agent_status
    PRIMARY_STATUS=$(echo "$ENRICHED_PANES" | jq -r '.[0].agent_status // empty')
    if [ -z "$PRIMARY_STATUS" ] || [ "$PRIMARY_STATUS" = "null" ]; then
      PRIMARY_STATUS=$(echo "$TAB_ITEM" | jq -r '.tab_agent_status // "unknown"')
    fi

    PRIMARY_AGENT=$(echo "$ENRICHED_PANES" | jq -r '.[0].agent // empty')
    if [ -z "$PRIMARY_AGENT" ] || [ "$PRIMARY_AGENT" = "null" ]; then
      PRIMARY_AGENT="unknown"
    fi

    PRIMARY_MODEL=$(echo "$ENRICHED_PANES" | jq -r '.[0].model // empty')
    if [ -z "$PRIMARY_MODEL" ] || [ "$PRIMARY_MODEL" = "null" ]; then
      PRIMARY_MODEL="unknown"
    fi

    ENRICHED_CREWS=$(echo "$ENRICHED_CREWS" | jq \
      --arg tab_id "$TAB_ID" \
      --arg label "$TAB_LABEL" \
      --arg status "$PRIMARY_STATUS" \
      --arg harness "$PRIMARY_AGENT" \
      --arg model "$PRIMARY_MODEL" \
      --argjson panes "$ENRICHED_PANES" '
      . + [{
        tab_label: $label,
        agent_status: $status,
        harness: $harness,
        model: $model,
        panes: $panes
      }]
    ')
  done

  HOST_OBJ=$(jq -n \
    --arg host "$H_NAME" \
    --arg target "$H_TARGET" \
    --arg home "$H_HOME" \
    --arg watcher "$WATCHER_STATUS" \
    --arg beacon_age "$BEACON_AGE" \
    --argjson crews "$ENRICHED_CREWS" '
    {
      host: $host,
      target: $target,
      home: $home,
      watcher: $watcher,
      beacon_age_seconds: (if $beacon_age == "missing" then null else ($beacon_age | tonumber) end),
      crews: $crews
    }
  ')

  HOST_RESULTS+=("$HOST_OBJ")
done

if [ $HAS_ERROR -ne 0 ]; then
  exit 1
fi

ALL_HOSTS_JSON=$(printf '%s\n' "${HOST_RESULTS[@]}" | jq -s '.')

if [ "$JSON_OUTPUT" -eq 1 ]; then
  echo "$ALL_HOSTS_JSON"
  exit 0
fi

# Render Human-Readable Output
echo "# Fleet Status by Name (Live & Verified)"
echo

for ((i=0; i<${#HOST_RESULTS[@]}; i++)); do
  H_OBJ="${HOST_RESULTS[$i]}"
  H_NAME=$(echo "$H_OBJ" | jq -r '.host')
  H_TARGET=$(echo "$H_OBJ" | jq -r '.target')
  H_WATCHER=$(echo "$H_OBJ" | jq -r '.watcher')
  CREW_COUNT=$(echo "$H_OBJ" | jq '.crews | length')

  echo "## Host: $H_NAME ($H_TARGET)"
  echo "- Watcher: $H_WATCHER"
  echo

  if [ "$CREW_COUNT" -eq 0 ]; then
    echo "  (No crews/tabs active)"
    echo
    continue
  fi

  echo "| Tab Label | Live Status | Harness | Model Shown |"
  echo "| --- | --- | --- | --- |"

  for ((c=0; c<CREW_COUNT; c++)); do
    C_ITEM=$(echo "$H_OBJ" | jq ".crews[$c]")
    C_LABEL=$(echo "$C_ITEM" | jq -r '.tab_label')
    C_STATUS=$(echo "$C_ITEM" | jq -r '.agent_status')
    C_HARNESS=$(echo "$C_ITEM" | jq -r '.harness')
    C_MODEL=$(echo "$C_ITEM" | jq -r '.model')

    printf '| %s | %s | %s | %s |\n' "$C_LABEL" "$C_STATUS" "$C_HARNESS" "$C_MODEL"
  done
  echo
done
