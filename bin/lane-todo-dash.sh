#!/usr/bin/env bash
# lane-todo-dash.sh - emit one self-contained offline HTML snapshot.
#
# Sources follow lane-todo-board.sh for lane discovery, task resolution, and
# status events; the remaining inputs are documented local records under FM_HOME.
# It never reads comms receipt contents, pane screens, or remote resources.
#
# Usage: lane-todo-dash.sh [OUTPUT]
# OUTPUT defaults to ./index.html. Herdr pane counts come from `herdr pane list`
# or HERDR_PANE_LIST_FILE for isolated tests; no pane screen is inspected.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SELF_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
OUT="${1:-index.html}"
TMP="${OUT}.tmp.$$"
trap 'rm -f -- "$TMP"' EXIT

html() {
  local value="$1"
  value=${value//&/\&amp;}; value=${value//</\&lt;}; value=${value//>/\&gt;}
  value=${value//\"/\&quot;}; value=${value//\'/\&#39;}
  printf '%s' "$value"
}

field() { # <file> <key>
  local file="$1" key="$2" line value
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == "$key="* ]]; then
      value="${line#*=}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      printf '%s' "$value"
      return 0
    fi
  done < "$file"
}

task_for() { # mirror lane-todo-board.sh's explicit/artifact/name/prefix precedence
  local lane="$1" file base explicit artifact parent fallback prefix=""
  explicit=$(field "$STATE/lanes/$lane.lane" task)
  artifact=$(field "$STATE/lanes/$lane.lane" artifact)
  fallback="$lane"
  if [ -n "$artifact" ]; then
    parent="${artifact%/*}"
    [ "$parent" = "$artifact" ] || fallback="${parent##*/}"
  fi
  for base in "$explicit" "$fallback" "$lane"; do
    [ -n "$base" ] || continue
    if [ -f "$STATE/$base.status" ] || [ -f "$STATE/$base.meta" ]; then printf '%s' "$base"; return; fi
  done
  for file in "$STATE/$lane"*.status "$STATE/$lane"*.meta; do
    [ -f "$file" ] || continue
    base="${file##*/}"; base="${base%.*}"
    if [ -z "$prefix" ] || [[ "$base" > "$prefix" ]]; then prefix="$base"; fi
  done
  if [ -n "$prefix" ]; then printf '%s' "$prefix"; else printf '%s' "$fallback"; fi
}

age_for() {
  local file="$1" epoch now delta
  epoch=$(stat -c %Y -- "$file" 2>/dev/null || printf '0')
  now=$(date +%s); delta=$((now - epoch)); [ "$delta" -ge 0 ] || delta=0
  if [ "$delta" -lt 60 ]; then printf '%ss ago' "$delta"
  elif [ "$delta" -lt 3600 ]; then printf '%sm ago' "$((delta / 60))"
  elif [ "$delta" -lt 86400 ]; then printf '%sh ago' "$((delta / 3600))"
  else printf '%sd ago' "$((delta / 86400))"; fi
}

last_file() {
  local direction="$1" file selected="" newest=0 epoch
  shopt -s globstar nullglob
  for file in "$FM_HOME"/BRANDON-COMPUTE-COMMS/**/*; do
    [ -f "$file" ] || continue
    [[ "${file,,}" == *hetz*"$direction"* ]] || continue
    epoch=$(stat -c %Y -- "$file" 2>/dev/null || printf '0')
    if [ "$epoch" -ge "$newest" ]; then newest="$epoch"; selected="$file"; fi
  done
  shopt -u globstar nullglob
  printf '%s' "$selected"
}

lane_status() { # <task>
  local line state=unknown
  [ -f "$STATE/$1.status" ] || { printf 'unknown'; return; }
  line=$(tail -n 1 -- "$STATE/$1.status" 2>/dev/null)
  case "$line" in
    working:*|running:*) state=working ;;
    idle:*) state=idle ;;
    "done":*) state='done' ;;
    *) state=unknown ;;
  esac
  printf '%s' "$state"
}

generated=$(date -u +%Y-%m-%dT%H:%M:%SZ)
pane_file="${HERDR_PANE_LIST_FILE:-}"
if [ -n "$pane_file" ]; then
  pane_text=$(cat -- "$pane_file" 2>/dev/null || true)
else
  pane_text=$(herdr pane list 2>/dev/null || true)
fi
running=$(printf '%s\n' "$pane_text" | awk 'BEGIN{IGNORECASE=1} /working|running/ && /w[0-9]+:p[[:alnum:]]+/ {n++} END{print n+0}')
declared=0
capacity="$FM_HOME/config/project-capacity"
if [ -f "$capacity" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^[[:space:]]*[^#[:space:]][^=]*=([0-9]+)[[:space:]]*$ ]]; then
      capacity_value="${BASH_REMATCH[1]}"
      declared=$((declared + capacity_value))
    fi
  done < "$capacity"
fi

mkdir -p -- "$(dirname "$OUT")"
{
  cat <<HTML
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fleet ticket dashboard</title>
<style>
:root{color-scheme:dark;--bg:#101820;--panel:#192630;--line:#30434e;--ink:#e9f0f2;--muted:#a8b9c1;--accent:#75d4c3;--warn:#ffd27a}
*{box-sizing:border-box}body{margin:0;padding:28px;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
header{display:flex;justify-content:space-between;align-items:end;gap:16px;margin:0 auto 22px;max-width:1400px}h1{margin:0;font-size:clamp(1.6rem,3vw,2.4rem)}h2{margin:0 0 14px;font-size:1.15rem}small,.muted{color:var(--muted)}main{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;max-width:1400px;margin:auto}.card{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:18px;min-width:0}.wide{grid-column:1/-1}.capacity{font-size:1.3rem;color:var(--accent);font-weight:700}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:9px 8px;border-bottom:1px solid var(--line);vertical-align:top}th{font-size:.8rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted)}td{overflow-wrap:anywhere}.state{font-weight:700;color:var(--accent)}.ticket{white-space:normal}.badge{display:inline-block;padding:2px 8px;border-radius:999px;background:#263b47;color:var(--accent)}.blocker{color:var(--warn)}.empty{color:var(--muted);font-style:italic}.receipt{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid var(--line)}.gate{font-family:ui-monospace,monospace}.status-pass{color:var(--accent)}.status-fail{color:#ff9c91}
@media(max-width:800px){body{padding:14px}main{grid-template-columns:1fr}.wide{grid-column:auto}header{align-items:start;flex-direction:column}table{font-size:.9rem}th,td{padding:7px 4px}}
</style></head><body><header><div><h1>Fleet ticket dashboard</h1><small>Local snapshot · no external resources</small></div><small>Generated <time>$generated</time></small></header><main>
HTML
  printf '<section class="card wide"><h2>Lane activity</h2><table><thead><tr><th>Lane / model</th><th>Surface / host</th><th>Task</th><th>State</th><th>Last activity</th></tr></thead><tbody>\n'
  lanes=0
  for file in "$STATE"/lanes/*.lane "$STATE"/lanes/*.todo.md; do
    [ -f "$file" ] || continue
    name="${file##*/}"; name="${name%.todo.md}"; name="${name%.lane}"
    case " ${seen:-} " in *" $name "*) continue ;; esac
    seen="${seen:-} $name"; lanes=$((lanes + 1))
    task=$(task_for "$name")
    model=$(field "$STATE/lanes/$name.lane" model); [ -n "$model" ] || model=$(field "$STATE/$task.meta" model); [ -n "$model" ] || model=unknown
    surface=$(field "$STATE/lanes/$name.lane" surface)
    [ -n "$surface" ] || surface=$(field "$STATE/$task.meta" herdr_session)
    [ -n "$surface" ] || { window=$(field "$STATE/$task.meta" window); [ -z "$window" ] || surface="${window%%:*}"; }
    [ -n "$surface" ] || {
      pane=$(field "$STATE/lanes/$name.lane" pane); [ -n "$pane" ] || pane=$(field "$STATE/$task.meta" herdr_pane_id)
      case "$pane" in *:*:*) surface="${pane%%:*}" ;; esac
    }
    [ -n "$surface" ] || surface=unknown
    status=$(lane_status "$task"); activity='(none)'
    if [ -f "$STATE/$task.status" ]; then activity=$(date -u -r "$STATE/$task.status" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '(unknown)'); fi
    printf '<tr><td>%s<br><span class="muted">%s</span></td><td>%s</td><td>%s</td><td class="state">%s</td><td>%s</td></tr>\n' "$(html "$name")" "$(html "$model")" "$(html "$surface")" "$(html "$task")" "$(html "$status")" "$(html "$activity")"
  done
  if [ "$lanes" -eq 0 ]; then printf '<tr><td colspan="5" class="empty">No registered lanes</td></tr>\n'; fi
  printf '</tbody></table></section>\n'

  printf '<section class="card wide"><h2>Tickets by priority</h2><table><thead><tr><th>Priority</th><th>Ticket</th><th>Claim</th><th>Blocker</th></tr></thead><tbody>\n'
  backlog="$FM_HOME/data/backlog.md"; priority=unassigned; ticket=""; claim=""; blocker=""; ticket_count=0
  emit_ticket() {
    [ -n "$ticket" ] || return 0
    printf '<tr><td>%s</td><td class="ticket">%s</td><td>%s</td><td class="blocker">%s</td></tr>\n' "$(html "$priority")" "$(html "$ticket")" "$(html "${claim:-unclaimed}")" "$(html "${blocker:-none}")"
    ticket_count=$((ticket_count + 1))
  }
  if [ -f "$backlog" ]; then
    ticket_re='^-[[:space:]]+\[[ xX]\][[:space:]]+(.+)$'
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" =~ ^#{1,3}[[:space:]]+(P[1-4])([[:space:]]|$) ]]; then
        emit_ticket; ticket=""; claim=""; blocker=""; priority="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ $ticket_re ]]; then
        emit_ticket; ticket="${BASH_REMATCH[1]}"; claim=""; blocker=""
      elif [[ "$line" =~ ^[[:space:]]*(claim|claimed|owner):[[:space:]]*(.*)$ ]]; then claim="${BASH_REMATCH[2]}"
      elif [[ "$line" =~ ^[[:space:]]*blocker(s)?:[[:space:]]*(.*)$ ]]; then blocker="${BASH_REMATCH[2]}"
      fi
    done < "$backlog"
    emit_ticket
  fi
  if [ "$ticket_count" -eq 0 ]; then printf '<tr><td colspan="4" class="empty">No backlog tickets found</td></tr>\n'; fi
  printf '</tbody></table></section>\n'

  printf '<section class="card"><h2>Hetz comms receipts</h2>\n'
  for direction in inbound outbound; do
    receipt=$(last_file "$direction")
    if [ -n "$receipt" ]; then
      printf '<div class="receipt"><span>%s · %s</span><span>%s</span></div>\n' "$(html "$direction")" "$(html "${receipt##*/}")" "$(html "$(age_for "$receipt")")"
    else printf '<div class="receipt"><span>%s</span><span class="empty">no receipt</span></div>\n' "$(html "$direction")"; fi
  done
  printf '</section>\n'
  printf '<section class="card"><h2>Capacity</h2><div class="capacity">Declared %s · Running %s</div><small>Running counts working panes from Herdr pane list.</small></section>\n' "$declared" "$running"

  printf '<section class="card wide"><h2>Latest gate status</h2><table><thead><tr><th>Gate</th><th>Status</th></tr></thead><tbody>\n'
  declare -A gates=() gate_ranks=()
  shopt -s nullglob
  for file in "$STATE"/*.status; do
    file_epoch=$(stat -c %Y -- "$file" 2>/dev/null || printf '0')
    line_no=0
    while IFS= read -r line || [ -n "$line" ]; do
      line_no=$((line_no + 1))
      if [[ "$line" =~ GATE[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]+([A-Za-z0-9_-]+) ]]; then
        gate_id="${BASH_REMATCH[1]}"; gate_status="${BASH_REMATCH[2]}"
        gate_rank=$(printf '%020d:%010d' "$file_epoch" "$line_no")
        if [ -z "${gate_ranks[$gate_id]:-}" ] || [[ "$gate_rank" > "${gate_ranks[$gate_id]}" ]]; then
          gates["$gate_id"]="$gate_status"; gate_ranks["$gate_id"]="$gate_rank"
        fi
      fi
    done < "$file"
  done
  shopt -u nullglob
  gate_count=0
  for gate in "${!gates[@]}"; do
    gate_count=$((gate_count + 1)); status="${gates[$gate]}"; klass='status-pass'
    [[ "${status,,}" == *fail* || "${status,,}" == *block* || "${status,,}" == *refus* ]] && klass='status-fail'
    printf '<tr><td class="gate">%s</td><td class="%s">%s</td></tr>\n' "$(html "$gate")" "$klass" "$(html "$status")"
  done
  if [ "$gate_count" -eq 0 ]; then printf '<tr><td colspan="2" class="empty">No gate status events</td></tr>\n'; fi
  printf '</tbody></table></section></main></body></html>\n'
} > "$TMP"
mv -f -- "$TMP" "$OUT"
trap - EXIT
printf 'generated: %s\n' "$OUT"
