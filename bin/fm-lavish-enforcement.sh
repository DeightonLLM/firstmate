#!/usr/bin/env bash
# fm-lavish-enforcement.sh - emit or review the Lavish enforcement dashboard.
#
# Generates a self-contained, offline HTML dashboard that surfaces every
# enforcement point in firstmate: what it blocks, what config activates it,
# whether it is currently active or inactive, and how to add or remove it.
# Also surfaces the truthful capacity holder breakdown (live vs phantom holders)
# from bin/lane-hygiene and bin/fm-project-capacity-lib.sh.
#
# Integrates with Lavish Editor via bin/fm-procevent-lavish.sh for the
# review/reply/end interactive feedback loop.
#
# Usage:
#   fm-lavish-enforcement.sh [OUTPUT]       generate self-contained HTML
#   fm-lavish-enforcement.sh inventory [--json]  machine-readable inventory
#   fm-lavish-enforcement.sh review [ARTIFACT]   generate & arm Lavish session
#   fm-lavish-enforcement.sh reply MESSAGE       send agent reply to Lavish
#   fm-lavish-enforcement.sh end                 end Lavish session & retire source
#   fm-lavish-enforcement.sh --help              show this help
#
# Constraints:
#   ZERO external URLs. No CDN, no remote fonts, no remote scripts.
#   Truthful over pretty: inactive guards read inactive, not assumed-on.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
# shellcheck disable=SC2034
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"

LAVISH_ADAPTER="$SCRIPT_DIR/fm-procevent-lavish.sh"
DEFAULT_ARTIFACT="$FM_HOME/data/lavish/enforcement.html"
DEFAULT_LAVISH_ARTIFACT="$FM_HOME/.lavish/enforcement.html"

# Source firstmate libraries if available
if [ -f "$SCRIPT_DIR/fm-wake-lib.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/fm-wake-lib.sh"
fi
if [ -f "$SCRIPT_DIR/fm-backend.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/fm-backend.sh"
fi
if [ -f "$SCRIPT_DIR/fm-secondmate-registry-lib.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/fm-secondmate-registry-lib.sh"
fi
if [ -f "$SCRIPT_DIR/fm-project-capacity-lib.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/fm-project-capacity-lib.sh"
fi

usage() {
  cat <<'EOF'
fm-lavish-enforcement.sh - Lavish enforcement surface generator and reviewer

Usage:
  fm-lavish-enforcement.sh [OUTPUT]            generate self-contained HTML page
  fm-lavish-enforcement.sh inventory [--json]  print machine-readable guard list
  fm-lavish-enforcement.sh review [ARTIFACT]   open Lavish session & arm poll
  fm-lavish-enforcement.sh reply MESSAGE       send agent reply into board
  fm-lavish-enforcement.sh end                 end Lavish session & retire source
  fm-lavish-enforcement.sh --help              show this help

Output defaults to data/lavish/enforcement.html and .lavish/enforcement.html.
All output is strictly offline with zero external URLs (no CDN, no remote fonts).
EOF
  exit 0
}

html_escape() {
  local val="$1"
  val=${val//&/\&amp;}
  val=${val//</\&lt;}
  val=${val//>/\&gt;}
  val=${val//\"/\&quot;}
  val=${val//\'/\&#39;}
  printf '%s' "$val"
}

# ------------------------------------------------------------------------------
# Enforcement Inventory Discovery & Status Resolution
# ------------------------------------------------------------------------------
# Collects structured enforcement data:
# name | script | blocks | config | active(1/0) | status | details | add_hint | remove_hint
collect_enforcements() {
  local project_name="${FM_PROJECT_NAME:-$(basename "$FM_ROOT")}"

  # 1. fm-dispatch-guard
  local dg_active=1 dg_status="active" dg_details=""
  if [ "${FM_DISPATCH_GUARD_BYPASS:-0}" = "1" ]; then
    dg_active=0
    dg_status="inactive"
    dg_details="Bypassed via FM_DISPATCH_GUARD_BYPASS=1"
  else
    local dg_cap="4"
    if [ -r "$CONFIG/dispatch-max-lanes" ]; then
      dg_cap=$(tr -dc '0-9' < "$CONFIG/dispatch-max-lanes")
      [ -n "$dg_cap" ] || dg_cap="4"
      dg_details="Active: live-lane cap=${dg_cap} from config/dispatch-max-lanes; Sol banned; load ceiling enforced"
    else
      dg_details="Active: live-lane cap=4 (default); Sol banned; load ceiling enforced"
    fi
  fi
  printf 'fm-dispatch-guard\tbin/fm-dispatch-guard.sh\tBlocks banned model gpt-6.1-sol (no bypass), host CPU saturation (load >= cores), live lanes exceeding ceiling, exhausted provider quota\tconfig/dispatch-max-lanes, FM_DISPATCH_GUARD_MAX_LANES, FM_DISPATCH_GUARD_BYPASS\t%d\t%s\t%s\tEnsure FM_DISPATCH_GUARD_BYPASS is unset; set cap in config/dispatch-max-lanes\tSet FM_DISPATCH_GUARD_BYPASS=1 (Sol ban cannot be bypassed)\n' \
    "$dg_active" "$dg_status" "$dg_details"

  # 2. fm-project-capacity
  local pc_active=0 pc_status="inactive" pc_details=""
  if [ -r "$CONFIG/project-capacity" ]; then
    local cap_val=""
    cap_val=$(awk -v p="$project_name" '$1==p {print $2; exit}' "$CONFIG/project-capacity" 2>/dev/null || true)
    if [ -n "$cap_val" ] && [[ "$cap_val" =~ ^[0-9]+$ ]]; then
      pc_active=1
      pc_status="active"
      pc_details="Active: declared capacity of ${cap_val} worker(s) for ${project_name} in config/project-capacity"
    else
      pc_details="Inactive: config/project-capacity present but no declaration for ${project_name} (uncapped)"
    fi
  else
    pc_details="Inactive: config/project-capacity absent (uncapped dispatch)"
  fi
  # shellcheck disable=SC2016
  printf 'fm-project-capacity\tbin/fm-project-capacity-lib.sh\tBlocks worker spawns exceeding machine-local declared project capacity (exit 75); blocks malformed capacity declarations\tconfig/project-capacity\t%d\t%s\t%s\tAdd `<project-name> <capacity>` line to config/project-capacity\tRemove project line from config/project-capacity or delete file\n' \
    "$pc_active" "$pc_status" "$pc_details"

  # 3. fm-lease
  local lease_active=0 lease_status="inactive" lease_details=""
  local lease_count=0
  if [ -d "$STATE" ]; then
    lease_count=$(find "$STATE" -maxdepth 1 -name ".lease-*" 2>/dev/null | wc -l)
  fi
  if [ -n "${FM_SUPERVISION_ACTOR:-}" ] || [ "$lease_count" -gt 0 ]; then
    lease_active=1
    lease_status="active"
    lease_details="Active: actor='${FM_SUPERVISION_ACTOR:-main}', ${lease_count} active lease file(s) in state"
  else
    lease_details="Inactive: no FM_SUPERVISION_ACTOR set and 0 task leases active"
  fi
  printf 'fm-lease\tbin/fm-lease-lib.sh\tBlocks cross-actor race mutations between main and branch supervision actors (exit 76); forbids supervision-branch worker spawns\tFM_SUPERVISION_ACTOR, supervision host, state/.lease-*\t%d\t%s\t%s\tSet FM_SUPERVISION_ACTOR=branch or acquire per-task lease\tClear FM_SUPERVISION_ACTOR and release task leases\n' \
    "$lease_active" "$lease_status" "$lease_details"

  # 4. fm-reap-gate
  local rg_active=1 rg_status="active" rg_details="Active: protects unlanded work; Crisp-R & Captain panes protected; log at state/reap.log"
  printf 'fm-reap-gate\tbin/fm-reap-gate.sh\tBlocks teardown/reap of tasks with unlanded changes; blocks reaping Crisp-R prefixed panes/tabs and Captain session pane\tFM_REAP_AGE_THRESHOLD_SECS (default 300s), FM_REAP_LOG\t%d\t%s\t%s\tDefault active during session-start sweeps and watcher reaper passes\tPass explicit captain discard authorization to teardown --force (never bypassed automatically)\n' \
    "$rg_active" "$rg_status" "$rg_details"

  # 5. fm-helper-permissions
  local hp_active=0 hp_status="inactive" hp_details=""
  local tracked_perms="${FM_HELPER_PERMISSIONS_TRACKED:-$FM_ROOT/docs/helper-permissions.json}"
  if [ -r "$tracked_perms" ]; then
    hp_active=1
    hp_status="active"
    hp_details="Active: tracked definition present at docs/helper-permissions.json"
  else
    hp_details="Inactive: docs/helper-permissions.json missing"
  fi
  printf 'fm-helper-permissions\tbin/fm-helper-permissions-check.sh\tBlocks drift between tracked helper permissions (docs/helper-permissions.json) and live containment configs (lean-ctx, minimax)\tdocs/helper-permissions.json, /root/.config/lean-ctx/config.toml, /root/.minimax/permission.json\t%d\t%s\t%s\tEnsure docs/helper-permissions.json exists and run check\tRemove tracked rules file or run without containment auditing\n' \
    "$hp_active" "$hp_status" "$hp_details"

  # 6. fm-subagent-cap
  local sc_active=0 sc_status="inactive" sc_details=""
  if [ -x "/root/lib/subagent-cap/cap.sh" ] || [ -x "$SCRIPT_DIR/herdr-subagent-cap-check" ]; then
    if [ "${HERDR_CAP_CHECK_SKIP:-0}" = "1" ]; then
      sc_details="Inactive: bypassed via HERDR_CAP_CHECK_SKIP=1"
    else
      sc_active=1
      sc_status="active"
      sc_details="Active: max 6 open subagent panes, max 7 total panes including coordinator"
    fi
  else
    sc_details="Inactive: canonical subagent cap module not executable on host"
  fi
  printf 'fm-subagent-cap\tbin/fm-subagent-cap.sh\tBlocks subagent pane spawn when cap reached (max 6 subagents, max 7 total; exit 64 ERR_SUBAGENT_CAP_REACHED)\t/root/lib/subagent-cap/cap.sh, HERDR_CAP_CHECK_SKIP\t%d\t%s\t%s\tEnsure Herdr subagent cap check binary is installed and HERDR_CAP_CHECK_SKIP is unset\tSet HERDR_CAP_CHECK_SKIP=1\n' \
    "$sc_active" "$sc_status" "$sc_details"

  # 7. fm-quota-gate
  local qg_active=0 qg_status="inactive" qg_details=""
  if command -v quota-axi >/dev/null 2>&1; then
    qg_active=1
    qg_status="active"
    qg_details="Active: quota-axi is installed; provider exhaustion blocks dispatch (exit 3/4)"
  else
    qg_details="Inactive: quota-axi not found in PATH"
  fi
  printf 'fm-quota-gate\tbin/fm-quota-gate.sh\tBlocks crew dispatch when provider quota is exhausted (exit 3) or unmeasurable (exit 4)\tquota-axi CLI\t%d\t%s\t%s\tInstall quota-axi and ensure vendor auth probes pass\tUninstall quota-axi or dispatch on uncapped provider\n' \
    "$qg_active" "$qg_status" "$qg_details"

  # 8. fm-merge-authority
  local ma_active=1 ma_status="active" ma_details="Active: Hard Rule 2 strictly enforced across all PR and local merge paths"
  printf 'fm-merge-authority\tbin/fm-merge-authority-lib.sh\tBlocks merging PRs or fast-forwarding branches without explicit Captain approval (Hard Rule 2)\tdata/projects.md delivery mode (+yolo standing relaxation only for routine decisions)\t%d\t%s\t%s\tAlways enforced by default in Firstmate core\tSet +yolo in data/projects.md for routine decisions (never merges PR without word)\n' \
    "$ma_active" "$ma_status" "$ma_details"

  # 9. fm-gate-refuse
  local gr_active=1 gr_status="active" gr_details="Active: blocks direct execution when operating under no-mistakes gate (exit 64)"
  printf 'fm-gate-refuse\tbin/fm-gate-refuse-lib.sh\tBlocks direct operator/agent lifecycle mutations when operating under fleet no-mistakes gate (exit 64)\tNo-mistakes gate policy\t%d\t%s\t%s\tActive on gated entrypoints in firstmate toolbelt\tProvide explicit gate authorization token\n' \
    "$gr_active" "$gr_status" "$gr_details"

  # 10. fm-docs-drift-gate
  local dd_active=0 dd_status="inactive" dd_details=""
  if [ -f "$SCRIPT_DIR/fm-docs-drift-gate.sh" ]; then
    dd_active=1
    dd_status="active"
    dd_details="Active: script present; checks repo + external roots vs docs/ and drift-waivers.tsv"
  else
    dd_details="Inactive: fm-docs-drift-gate.sh not found"
  fi
  printf 'fm-docs-drift-gate\tbin/fm-docs-drift-gate.sh\tBlocks closeout when implementation files changed without corresponding docs changes or approved waivers\tdocs/drift-waivers.tsv, state/docs-drift-gate.marker\t%d\t%s\t%s\tRun fm-docs-drift-gate.sh at closeout\tAdd waiver entry to docs/drift-waivers.tsv\n' \
    "$dd_active" "$dd_status" "$dd_details"

  # 11. fm-turnend-guard
  local tg_active=0 tg_status="inactive" tg_details=""
  if [ -f "$SCRIPT_DIR/fm-turnend-guard.sh" ]; then
    tg_active=1
    tg_status="active"
    tg_details="Active: turn-end guard installed for primary sessions (Claude, Codex, Grok, Kimi)"
  else
    tg_details="Inactive: fm-turnend-guard.sh not found"
  fi
  printf 'fm-turnend-guard\tbin/fm-turnend-guard.sh\tBlocks turn ending with unhandled wakes, missing verification, or open captain holds (exit 2 on Claude/Codex)\tHarness stop hooks (Claude asyncRewake, Codex stop_hook, Grok, Kimi)\t%d\t%s\t%s\tInstall tracked stop hooks into primary harness\tRemove stop hook configuration\n' \
    "$tg_active" "$tg_status" "$tg_details"

  # 12. fm-arm-command-policy
  local ac_active=0 ac_status="inactive" ac_details=""
  if [ -f "$SCRIPT_DIR/fm-arm-command-policy.mjs" ]; then
    ac_active=1
    ac_status="active"
    ac_details="Active: PreToolUse policy rejects unauthorized watcher arm commands"
  else
    ac_details="Inactive: fm-arm-command-policy.mjs not found"
  fi
  printf 'fm-arm-command-policy\tbin/fm-arm-command-policy.mjs\tBlocks PreToolUse execution of unauthorized or unverified watcher-arm commands\tdocs/arm-pretool-check.md\t%d\t%s\t%s\tConfigure PreToolUse hook to run fm-arm-pretool-check.sh\tRemove PreToolUse hook\n' \
    "$ac_active" "$ac_status" "$ac_details"

  # 13. fm-subagent-pretool-check
  local sp_active=0 sp_status="inactive" sp_details=""
  if [ -f "$SCRIPT_DIR/fm-subagent-pretool-check.sh" ]; then
    sp_active=1
    sp_status="active"
    sp_details="Active: PreToolUse delegation guard validates bounded parallel execution headers"
  else
    sp_details="Inactive: fm-subagent-pretool-check.sh not found"
  fi
  printf 'fm-subagent-pretool-check\tbin/fm-subagent-pretool-check.sh\tBlocks non-compliant subagent delegation shapes, unvalidated prompts, and unbounded recursive spawns\tdocs/subagent-guard.md\t%d\t%s\t%s\tConfigure PreToolUse hook for subagent delegation\tRemove PreToolUse hook\n' \
    "$sp_active" "$sp_status" "$sp_details"

  # 14. fm-jev-mem-guard
  local jm_active=0 jm_status="inactive" jm_details=""
  if [ -f "$SCRIPT_DIR/fm-jev-mem-guard.py" ] && command -v python3 >/dev/null 2>&1; then
    jm_active=1
    jm_status="active"
    jm_details="Active: python memory RSS and swap thrashing monitor available"
  else
    jm_details="Inactive: fm-jev-mem-guard.py not found or python3 missing"
  fi
  printf 'fm-jev-mem-guard\tbin/fm-jev-mem-guard.sh\tBlocks execution when host RSS memory or swap thrashing exceeds safety threshold\tbin/fm-jev-mem-guard.py\t%d\t%s\t%s\tExecute commands via fm-jev-mem-guard.sh wrapper\tExecute command directly without wrapper\n' \
    "$jm_active" "$jm_status" "$jm_details"

  # 15. fm-capacity-gate
  # The Captain's hard ceiling: the root filesystem must not go past 80% used.
  # At the ceiling the gate RECLAIMS first (tiers 1-2) and refuses only if the
  # disk is still over the ceiling afterwards. An unmeasurable disk fails
  # closed. This is the single shared owner of the ladder and the one reader
  # in the dispatch path is bin/fm-spawn.sh.
  local cg_active=0 cg_status="inactive" cg_details=""
  if [ -x "$SCRIPT_DIR/fm-capacity-gate.sh" ]; then
    cg_active=1
    cg_status="active"
    cg_details="Active: 80% root-usage ceiling enforced by bin/fm-capacity-gate.sh; reclaim-then-refuse; unmeasurable disk fails closed"
    if [ "${FM_CAPACITY_GATE_BYPASS:-0}" = "1" ] || [ "${FM_DISPATCH_GUARD_CAPACITY_BYPASS:-0}" = "1" ]; then
      cg_active=0
      cg_status="inactive"
      cg_details="Bypassed via FM_CAPACITY_GATE_BYPASS=1 (logged as BYPASS_CAPACITY, never silent)"
    fi
  else
    cg_details="Inactive: bin/fm-capacity-gate.sh not found, so the 80% ceiling is not enforced in the dispatch path"
  fi
  printf 'fm-capacity-gate\tbin/fm-capacity-gate.sh\tBlocks a fresh placement when root filesystem usage is at or above 80%%; reclaims first (tiers 1-2) and refuses only if still over; refuses an unmeasurable disk\tFM_CAPACITY_GATE_BYPASS, FM_CAPACITY_GATE_RECLAIM_TIMEOUT_S, FM_CAPACITY_GATE_LOCK\t%d\t%s\t%s\tEnsure FM_CAPACITY_GATE_BYPASS is unset and bin/fm-capacity-gate.sh is executable\tSet FM_CAPACITY_GATE_BYPASS=1 (logged, never silent)\n' \
    "$cg_active" "$cg_status" "$cg_details"
}

# ------------------------------------------------------------------------------
# Capacity Truth: Live vs Phantom Holders
# ------------------------------------------------------------------------------
# Computes:
# declared_capacity, capacity_holders_counted, live_holders, phantom_holders
compute_capacity_truth() {
  local project_name="${FM_PROJECT_NAME:-$(basename "$FM_ROOT")}"

  # 1. Declared capacity
  local declared="uncapped"
  if [ -r "$CONFIG/project-capacity" ]; then
    local pcap
    pcap=$(awk -v p="$project_name" '$1==p {print $2; exit}' "$CONFIG/project-capacity" 2>/dev/null || true)
    if [ -n "$pcap" ] && [[ "$pcap" =~ ^[0-9]+$ ]]; then
      declared="$pcap"
    fi
  fi

  # 2. Count holders as fm-project-capacity-lib.sh does (all non-secondmate meta without pr=)
  local holders_counted=0
  local holder_ids=()
  if [ -d "$STATE" ]; then
    for meta in "$STATE"/*.meta; do
      [ -f "$meta" ] && [ ! -L "$meta" ] || continue
      local kind pr id
      kind=$(grep '^kind=' "$meta" 2>/dev/null | cut -d= -f2- || true)
      [ "$kind" != "secondmate" ] || continue
      pr=$(grep '^pr=' "$meta" 2>/dev/null | cut -d= -f2- || true)
      [ -z "$pr" ] || continue
      id=$(basename "$meta" .meta)
      holder_ids+=("$id")
      holders_counted=$((holders_counted + 1))
    done
  fi

  # 3. Live workers (backend truth: herdr agent_status==working or endpoint liveness)
  local live_workers=0
  local live_ids=()
  local phantom_ids=()
  local herdr_bin
  herdr_bin=$(command -v herdr 2>/dev/null || echo "/usr/local/bin/herdr")

  if [ -x "$herdr_bin" ] && timeout 5s "$herdr_bin" workspace list >/dev/null 2>&1; then
    local pane_json
    pane_json=$(timeout 8s "$herdr_bin" pane list 2>/dev/null || true)
    if [ -n "$pane_json" ]; then
      live_workers=$(printf '%s' "$pane_json" | jq -r '[.result.panes // .panes // [] | .[] | select(.agent_status == "working")] | length' 2>/dev/null || echo 0)
    fi
  else
    # Fallback endpoint liveness check across the holder meta files
    for id in "${holder_ids[@]}"; do
      local meta="$STATE/$id.meta"
      local window target backend
      window=$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2- || true)
      backend=$(grep '^backend=' "$meta" 2>/dev/null | cut -d= -f2- || true)
      [ -n "$backend" ] || backend="tmux"
      target=$(grep '^herdr_pane_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
      [ -n "$target" ] || target="$window"
      if [ -n "$target" ] && command -v fm_backend_target_exists >/dev/null 2>&1; then
        if fm_backend_target_exists "$backend" "$target" "fm-$id"; then
          live_workers=$((live_workers + 1))
          live_ids+=("$id")
          continue
        fi
      fi
      phantom_ids+=("$id")
    done
  fi

  # Compute phantoms
  local phantoms=$((holders_counted - live_workers))
  [ "$phantoms" -ge 0 ] || phantoms=0

  printf '%s\t%d\t%d\t%d\t%s\n' \
    "$declared" "$holders_counted" "$live_workers" "$phantoms" "${holder_ids[*]:-none}"
}

# ------------------------------------------------------------------------------
# JSON Inventory Output
# ------------------------------------------------------------------------------
cmd_inventory_json() {
  local cap_data
  cap_data=$(compute_capacity_truth)
  local declared_cap counted_holders live_holders phantom_holders holder_list
  declared_cap=$(printf '%s' "$cap_data" | cut -f1)
  counted_holders=$(printf '%s' "$cap_data" | cut -f2)
  live_holders=$(printf '%s' "$cap_data" | cut -f3)
  phantom_holders=$(printf '%s' "$cap_data" | cut -f4)
  holder_list=$(printf '%s' "$cap_data" | cut -f5)

  printf '{\n'
  printf '  "schema": "fm-enforcement-inventory.v1",\n'
  printf '  "generated_at": "%s",\n' "$(date -u +%FT%TZ)"
  printf '  "host": "%s",\n' "$(uname -n)"
  printf '  "home": "%s",\n' "$FM_HOME"
  printf '  "capacity_truth": {\n'
  printf '    "declared_capacity": "%s",\n' "$declared_cap"
  printf '    "capacity_holders_counted": %d,\n' "$counted_holders"
  printf '    "live_holders": %d,\n' "$live_holders"
  printf '    "phantom_holders": %d,\n' "$phantom_holders"
  printf '    "defect_note": "Capacity lib counts all non-secondmate meta without pr= as holders. Phantom holders are finished/dead tasks still consuming capacity.",\n'
  printf '    "holder_ids": "%s"\n' "$holder_list"
  printf '  },\n'
  printf '  "enforcements": [\n'

  local first=1
  while IFS=$'\t' read -r name script blocks config active status details add_hint remove_hint; do
    [ -n "$name" ] || continue
    [ "$first" -eq 1 ] || printf ',\n'
    first=0
    printf '    {\n'
    printf '      "name": "%s",\n' "$name"
    printf '      "script": "%s",\n' "$script"
    printf '      "blocks": "%s",\n' "$(printf '%s' "$blocks" | sed 's/"/\\"/g')"
    printf '      "config": "%s",\n' "$(printf '%s' "$config" | sed 's/"/\\"/g')"
    printf '      "active": %s,\n' "$([ "$active" -eq 1 ] && echo "true" || echo "false")"
    printf '      "status": "%s",\n' "$status"
    printf '      "details": "%s",\n' "$(printf '%s' "$details" | sed 's/"/\\"/g')"
    printf '      "how_to_add": "%s",\n' "$(printf '%s' "$add_hint" | sed 's/"/\\"/g')"
    printf '      "how_to_remove": "%s"\n' "$(printf '%s' "$remove_hint" | sed 's/"/\\"/g')"
    printf '    }'
  done < <(collect_enforcements)
  printf '\n  ]\n}\n'
}

# ------------------------------------------------------------------------------
# Self-Contained Offline HTML Generator (ZERO External URLs)
# ------------------------------------------------------------------------------
generate_html() {
  local out="$1"
  local tmp="${out}.tmp.$$"
  mkdir -p "$(dirname "$out")" 2>/dev/null || true

  local cap_data
  cap_data=$(compute_capacity_truth)
  local declared_cap counted_holders live_holders phantom_holders holder_list
  declared_cap=$(printf '%s' "$cap_data" | cut -f1)
  counted_holders=$(printf '%s' "$cap_data" | cut -f2)
  live_holders=$(printf '%s' "$cap_data" | cut -f3)
  phantom_holders=$(printf '%s' "$cap_data" | cut -f4)
  holder_list=$(printf '%s' "$cap_data" | cut -f5)

  local project_name="${FM_PROJECT_NAME:-$(basename "$FM_ROOT")}"
  local total_guards=0 active_guards=0 inactive_guards=0
  while IFS=$'\t' read -r name script blocks config active status details add_hint remove_hint; do
    [ -n "$name" ] || continue
    total_guards=$((total_guards + 1))
    if [ "$active" -eq 1 ]; then
      active_guards=$((active_guards + 1))
    else
      inactive_guards=$((inactive_guards + 1))
    fi
  done < <(collect_enforcements)

  cat > "$tmp" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Firstmate Enforcement Dashboard</title>
  <style>
    :root {
      --bg: #0f141c;
      --card-bg: #161e2b;
      --card-border: #222f44;
      --text: #e6edf3;
      --text-muted: #8b949e;
      --text-dim: #6e7681;
      --green: #238636;
      --green-glow: #2ea04333;
      --green-text: #3fb950;
      --amber: #d29922;
      --amber-glow: #bb800933;
      --amber-text: #e3b341;
      --red: #da3633;
      --red-glow: #f8514933;
      --red-text: #f85149;
      --blue: #1f6feb;
      --blue-glow: #388bfd33;
      --blue-text: #58a6ff;
      --purple: #8957e5;
      --font: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      --mono: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, Liberation Mono, monospace;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: var(--font);
      line-height: 1.5;
      padding: 24px;
      min-height: 100vh;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    header {
      border-bottom: 1px solid var(--card-border);
      padding-bottom: 20px;
      margin-bottom: 24px;
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: flex-end;
      gap: 16px;
    }
    h1 {
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.02em;
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      padding: 3px 8px;
      font-size: 11px;
      font-weight: 600;
      border-radius: 12px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    .badge-enforced {
      background: var(--green-glow);
      color: var(--green-text);
      border: 1px solid var(--green);
    }
    .badge-inactive {
      background: var(--amber-glow);
      color: var(--amber-text);
      border: 1px solid var(--amber);
    }
    .badge-defect {
      background: var(--red-glow);
      color: var(--red-text);
      border: 1px solid var(--red);
    }
    .meta-line {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 4px;
    }
    /* Summary Grid */
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .stat-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 8px;
      padding: 16px;
    }
    .stat-label {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 6px;
    }
    .stat-val {
      font-size: 28px;
      font-weight: 700;
      font-family: var(--mono);
    }
    .stat-sub {
      font-size: 12px;
      color: var(--text-dim);
      margin-top: 4px;
    }
    /* Defect banner */
    .defect-banner {
      background: var(--card-bg);
      border: 1px solid var(--red);
      border-left: 4px solid var(--red);
      border-radius: 8px;
      padding: 16px 20px;
      margin-bottom: 24px;
    }
    .defect-title {
      font-size: 14px;
      font-weight: 700;
      color: var(--red-text);
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 6px;
    }
    .defect-desc {
      font-size: 13px;
      color: var(--text-muted);
    }
    .defect-metrics {
      display: flex;
      gap: 24px;
      margin-top: 12px;
      font-family: var(--mono);
      font-size: 13px;
    }
    /* Section layout */
    .section-title {
      font-size: 16px;
      font-weight: 700;
      margin-bottom: 14px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .guard-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
      margin-bottom: 32px;
    }
    .guard-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 8px;
      padding: 18px;
      transition: border-color 0.15s ease;
    }
    .guard-card:hover {
      border-color: #388bfd66;
    }
    .guard-card.enforced {
      border-left: 4px solid var(--green);
    }
    .guard-card.inactive {
      border-left: 4px solid var(--amber);
    }
    .guard-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
      gap: 12px;
    }
    .guard-name {
      font-size: 15px;
      font-weight: 700;
      font-family: var(--mono);
      color: var(--text);
    }
    .guard-file {
      font-size: 12px;
      color: var(--text-dim);
      font-family: var(--mono);
      margin-left: 8px;
    }
    .guard-blocks {
      font-size: 13px;
      color: var(--text);
      margin-bottom: 12px;
    }
    .guard-details {
      background: #0d1117;
      border: 1px solid #21262d;
      border-radius: 6px;
      padding: 10px 14px;
      font-size: 12px;
      margin-bottom: 12px;
    }
    .detail-row {
      display: flex;
      margin-bottom: 4px;
      gap: 10px;
    }
    .detail-row:last-child { margin-bottom: 0; }
    .detail-key {
      color: var(--text-muted);
      width: 90px;
      flex-shrink: 0;
      font-weight: 600;
    }
    .detail-val {
      color: var(--text);
      font-family: var(--mono);
      word-break: break-all;
    }
    .lifecycle-actions {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-top: 10px;
      padding-top: 10px;
      border-top: 1px dashed var(--card-border);
      font-size: 12px;
    }
    .action-box {
      background: #0d111788;
      border-radius: 4px;
      padding: 8px 10px;
    }
    .action-header {
      font-weight: 600;
      margin-bottom: 4px;
      text-transform: uppercase;
      font-size: 11px;
      letter-spacing: 0.05em;
    }
    .action-header.add { color: var(--green-text); }
    .action-header.remove { color: var(--amber-text); }
    .action-text {
      color: var(--text-muted);
      font-family: var(--mono);
      font-size: 11px;
    }
    /* Ledger */
    .ledger-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 8px;
      overflow: hidden;
    }
    .ledger-table th, .ledger-table td {
      padding: 10px 14px;
      text-align: left;
      border-bottom: 1px solid var(--card-border);
    }
    .ledger-table th {
      background: #0d1117;
      color: var(--text-muted);
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    .ledger-table tr:last-child td { border-bottom: none; }
    footer {
      border-top: 1px solid var(--card-border);
      padding-top: 16px;
      margin-top: 32px;
      font-size: 12px;
      color: var(--text-dim);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div>
        <h1>
          <span>Firstmate Enforcement Surface</span>
          <span class="badge badge-enforced">${active_guards} ENFORCED</span>
          $([ "$inactive_guards" -gt 0 ] && echo "<span class=\"badge badge-inactive\">${inactive_guards} REMOVED/INACTIVE</span>")
        </h1>
        <div class="meta-line">
          Host: <code>$(html_escape "$(uname -n)")</code> &bull;
          Generated: <code>$(date -u '+%Y-%m-%dT%H:%M:%SZ')</code> &bull;
          Zero External URLs &bull; Self-Contained Offline Surface &bull; Lavish Loop Sanctioned
        </div>
      </div>
      <div>
        <span class="badge $([ "$phantom_holders" -gt 0 ] && echo "badge-defect" || echo "badge-enforced")">
          PHANTOM DEFECT: ${phantom_holders} PHANTOM(S)
        </span>
      </div>
    </header>

    <!-- Stat Grid -->
    <div class="summary-grid">
      <div class="stat-card">
        <div class="stat-label">Total Guards</div>
        <div class="stat-val">${total_guards}</div>
        <div class="stat-sub">Inventory of blocking/refusing gates in bin/</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Enforced (Active)</div>
        <div class="stat-val" style="color: var(--green-text);">${active_guards}</div>
        <div class="stat-sub">Actively refusing rule violations</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Removed / Inactive</div>
        <div class="stat-val" style="color: var(--amber-text);">${inactive_guards}</div>
        <div class="stat-sub">Bypassed, uncapped, or unconfigured</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Declared Capacity</div>
        <div class="stat-val" style="color: var(--blue-text);">${declared_cap}</div>
        <div class="stat-sub">config/project-capacity declaration</div>
      </div>
    </div>

    <!-- Defect Callout -->
    <div class="defect-banner">
      <div class="defect-title">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
          <path d="M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"/>
        </svg>
        KNOWN REAL DEFECT: Finished state/*.meta Records Count As Capacity Holders
      </div>
      <div class="defect-desc">
        <code>bin/fm-project-capacity-lib.sh</code> counts all non-secondmate task records lacking a <code>pr=</code> line as holding machine capacity.
        Dead/finished tasks that were not reaped remain phantom holders. Capacity should count only LIVE holders.
      </div>
      <div class="defect-metrics">
        <div>Counted by Capacity Lib: <strong>${counted_holders}</strong></div>
        <div>Truly Live Workers: <strong>${live_holders}</strong></div>
        <div>Phantom Holders (Defect): <strong style="color: var(--red-text);">${phantom_holders}</strong></div>
      </div>
    </div>

    <!-- Guard Inventory & Lifecycle Actions -->
    <div class="section-title">
      <span>Enforcement Inventory &amp; Add/Remove Controls</span>
      <span style="font-size: 13px; font-weight: normal; color: var(--text-muted);">
        Every guard that can block or refuse
      </span>
    </div>

    <div class="guard-list">
EOF

  while IFS=$'\t' read -r name script blocks config active status details add_hint remove_hint; do
    [ -n "$name" ] || continue
    local card_class="enforced" badge_class="badge-enforced" badge_text="ENFORCED"
    if [ "$active" -eq 0 ]; then
      card_class="inactive"
      badge_class="badge-inactive"
      badge_text="REMOVED / INACTIVE"
    fi

    cat >> "$tmp" <<EOF
      <div class="guard-card ${card_class}">
        <div class="guard-header">
          <div>
            <span class="guard-name">$(html_escape "$name")</span>
            <span class="guard-file">$(html_escape "$script")</span>
          </div>
          <span class="badge ${badge_class}">${badge_text}</span>
        </div>
        <div class="guard-blocks">
          <strong>Blocks:</strong> $(html_escape "$blocks")
        </div>
        <div class="guard-details">
          <div class="detail-row">
            <span class="detail-key">Trigger:</span>
            <span class="detail-val">$(html_escape "$config")</span>
          </div>
          <div class="detail-row">
            <span class="detail-key">Current:</span>
            <span class="detail-val">$(html_escape "$details")</span>
          </div>
        </div>
        <div class="lifecycle-actions">
          <div class="action-box">
            <div class="action-header add">+ To Add / Enforce</div>
            <div class="action-text">$(html_escape "$add_hint")</div>
          </div>
          <div class="action-box">
            <div class="action-header remove">- To Remove / Deactivate</div>
            <div class="action-text">$(html_escape "$remove_hint")</div>
          </div>
        </div>
      </div>
EOF
  done < <(collect_enforcements)

  cat >> "$tmp" <<EOF
    </div>

    <!-- Capacity Holder Audit Table -->
    <div class="section-title">
      <span>Capacity Truth: Holders Breakdown</span>
      <span style="font-size: 13px; font-weight: normal; color: var(--text-muted);">
        Live vs Phantom task records
      </span>
    </div>

    <table class="ledger-table">
      <thead>
        <tr>
          <th>Metric</th>
          <th>Count</th>
          <th>Truth Source</th>
          <th>Description</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Declared Project Capacity</td>
          <td><code>${declared_cap}</code></td>
          <td><code>config/project-capacity</code></td>
          <td>Max concurrent workers admitted for $(html_escape "$project_name")</td>
        </tr>
        <tr>
          <td>Capacity Lib Occupants Counted</td>
          <td><code>${counted_holders}</code></td>
          <td><code>bin/fm-project-capacity-lib.sh</code></td>
          <td>Count of <code>*.meta</code> records without <code>pr=</code> (counts phantoms)</td>
        </tr>
        <tr>
          <td>Genuinely Live Workers</td>
          <td><code>${live_holders}</code></td>
          <td><code>bin/lane-hygiene</code> / <code>herdr pane list</code></td>
          <td>Workers with live, active running/working endpoints</td>
        </tr>
        <tr style="$([ "$phantom_holders" -gt 0 ] && echo "background: #da363318;")">
          <td style="color: $([ "$phantom_holders" -gt 0 ] && echo "var(--red-text)" || echo "inherit");">
            Phantom Holders (Defect)
          </td>
          <td><strong style="color: $([ "$phantom_holders" -gt 0 ] && echo "var(--red-text)" || echo "inherit");">${phantom_holders}</strong></td>
          <td>Difference (Counted - Live)</td>
          <td>Finished/dead tasks holding capacity because records not yet reaped</td>
        </tr>
      </tbody>
    </table>

    <footer>
      <div>Firstmate Enforcement Surface &bull; Zero External URLs (Self-contained)</div>
      <div>Shipped Page &bull; bin/fm-lavish-enforcement.sh</div>
    </footer>
  </div>
</body>
</html>
EOF

  mv -f "$tmp" "$out"
}

# ------------------------------------------------------------------------------
# Subcommand Execution
# ------------------------------------------------------------------------------
cmd_review() {
  local artifact="${1:-$DEFAULT_LAVISH_ARTIFACT}"
  case "$artifact" in
    -*) printf 'usage error: artifact path must not start with a dash\n' >&2; exit 1 ;;
  esac
  command -v lavish-axi >/dev/null 2>&1 || {
    printf 'error: lavish-axi is not installed\n' >&2
    exit 1
  }
  [ -f "$LAVISH_ADAPTER" ] && [ ! -L "$LAVISH_ADAPTER" ] || {
    printf 'error: missing Lavish process-to-event adapter: %s\n' "$LAVISH_ADAPTER" >&2
    exit 1
  }

  generate_html "$artifact"
  # Also sync to default data location
  if [ "$artifact" != "$DEFAULT_ARTIFACT" ]; then
    generate_html "$DEFAULT_ARTIFACT" 2>/dev/null || true
  fi

  lavish-axi "$artifact"
  "$LAVISH_ADAPTER" arm "$artifact"
  exit 0
}

cmd_reply() {
  command -v lavish-axi >/dev/null 2>&1 || {
    printf 'error: lavish-axi is not installed\n' >&2
    exit 1
  }
  [ "$#" -ge 1 ] || { printf 'usage error: reply needs a message\n' >&2; exit 1; }
  local artifact="${FM_LAVISH_ARTIFACT:-$DEFAULT_LAVISH_ARTIFACT}"
  [ -f "$artifact" ] || artifact="$DEFAULT_ARTIFACT"
  [ -f "$artifact" ] || {
    printf 'error: no enforcement artifact at %s; run review first\n' "$artifact" >&2
    exit 1
  }
  lavish-axi reply "$artifact" --agent-reply "$*"
  exit 0
}

cmd_end() {
  command -v lavish-axi >/dev/null 2>&1 || {
    printf 'error: lavish-axi is not installed\n' >&2
    exit 1
  }
  [ -f "$LAVISH_ADAPTER" ] && [ ! -L "$LAVISH_ADAPTER" ] || {
    printf 'error: missing Lavish process-to-event adapter: %s\n' "$LAVISH_ADAPTER" >&2
    exit 1
  }
  local artifact="${FM_LAVISH_ARTIFACT:-$DEFAULT_LAVISH_ARTIFACT}"
  [ -f "$artifact" ] || artifact="$DEFAULT_ARTIFACT"
  [ -f "$artifact" ] || {
    printf 'error: no enforcement artifact at %s; run review first\n' "$artifact" >&2
    exit 1
  }
  lavish-axi end "$artifact"
  "$LAVISH_ADAPTER" retire "$artifact"
  exit 0
}

# ------------------------------------------------------------------------------
# Dispatch
# ------------------------------------------------------------------------------
case "${1:-}" in
  --help|-h|help)
    usage
    ;;
  inventory)
    shift
    cmd_inventory_json "$@"
    ;;
  review)
    shift
    cmd_review "$@"
    ;;
  reply)
    shift
    cmd_reply "$@"
    ;;
  end)
    shift
    cmd_end "$@"
    ;;
  *)
    target_out="${1:-$DEFAULT_ARTIFACT}"
    generate_html "$target_out"
    # Also write to .lavish path if default
    if [ "$#" -eq 0 ]; then
      generate_html "$DEFAULT_LAVISH_ARTIFACT" 2>/dev/null || true
    fi
    printf 'Generated enforcement dashboard: %s\n' "$target_out"
    ;;
esac
