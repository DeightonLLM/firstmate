#!/usr/bin/env bash
# lane-todo-dash.sh - emit or serve one self-contained lane and ticket dashboard.
#
# Sources follow lane-todo-board.sh for lane discovery, task resolution, and
# status events; the remaining inputs are documented local records under FM_HOME.
# It never reads comms receipt contents, pane screens, or remote resources.
#
# Usage: lane-todo-dash.sh [OUTPUT] | serve [PORT] | review [ARTIFACT]
#        | reply MESSAGE | end | --help
# OUTPUT defaults to ./index.html. `serve` binds only the IPv4 returned by
# `tailscale ip -4` and writes feedback to state/dash-feedback.
#
# The dashboard artifact and every data source it reads are this script's own.
# Lavish supplies the interactivity layer on top of that artifact: `review`
# opens the artifact as a Lavish session and arms its chat-back poll through
# bin/fm-procevent-lavish.sh, so a comment the captain makes in the Lavish
# Conversation panel returns to the agent as a
# `procevent lavish <source-id> <sequence>` wake. `reply` is the agent-to-human
# half and `end` retires the source. This script owns only the artifact; poll
# lifecycle, durable capture, and wake publication belong to bin/fm-procevent.sh.
# Herdr pane counts
# come from `herdr pane list` or HERDR_PANE_LIST_FILE; no pane screen is inspected.
# Optional `compaction_headroom_pct=<integer 0-100>` on a lane or linked task meta
# record supplies its live headroom; the pill shows the lowest valid lane value.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SELF_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<USAGE
lane-todo-dash.sh - interactive fleet ticket dashboard

Usage:
  lane-todo-dash.sh [OUTPUT]           regenerate a self-contained HTML snapshot
  lane-todo-dash.sh review [ARTIFACT]  regenerate the artifact, open it as a
                                       Lavish session, and arm the chat-back poll
  lane-todo-dash.sh reply MESSAGE      send an agent reply into the board
  lane-todo-dash.sh end                end the session and retire the poll source

The artifact and its data sources are this script's own; Lavish layers the
Conversation panel, element annotation, and queued prompts on top of it.

  review  regenerates the artifact, runs lavish-axi on it to open or resume the
          session, then runs bin/fm-procevent-lavish.sh arm, which registers
          'lavish-axi poll <artifact>' with bin/fm-procevent.sh. Feedback comes
          back to the agent as a 'procevent lavish <id> <sequence>' wake.
  reply   runs lavish-axi reply, which exits 0 once the board accepts it.
  end     runs lavish-axi end, then retires the registered source.

ARTIFACT defaults to <FM_HOME>/.lavish/LANE-TODO-DASH.html and must keep a stable
path, because the source id is derived from its realpath; set
LANE_TODO_DASH_ARTIFACT to override it. Lavish binds 127.0.0.1 plus this host's
Tailscale IPv4 and never binds a wildcard address. Nothing is published to a
third-party host: do not use 'lavish-axi share'.

  lane-todo-dash.sh [OUTPUT]   regenerate a self-contained HTML snapshot
  lane-todo-dash.sh serve [PORT]  serve on the IPv4 address from 'tailscale ip -4'
                                 (default port: 8765)

Refresh requests rerun the generator. Feedback is written to
  $STATE/dash-feedback/<UTC timestamp>-<slug>.md

Durable user service:
  systemd-run --user --unit=lane-todo-dash --collect --working-directory='$FM_ROOT' --setenv=FM_HOME='$FM_HOME' '$SELF_DIR/lane-todo-dash.sh' serve

Serve requires tailscale and Python 3; it never binds a wildcard or non-Tailscale
address. Set LANE_TODO_DASH_PORT to override the default port.
USAGE
  exit 0
fi
DASH_ARTIFACT="${LANE_TODO_DASH_ARTIFACT:-$FM_HOME/.lavish/LANE-TODO-DASH.html}"
LAVISH_ADAPTER="$SELF_DIR/fm-procevent-lavish.sh"

require_lavish() {
  command -v lavish-axi >/dev/null 2>&1 || {
    printf 'error: lavish-axi is not installed\n' >&2
    exit 1
  }
}

require_adapter() {
  [ -f "$LAVISH_ADAPTER" ] && [ ! -L "$LAVISH_ADAPTER" ] || {
    printf 'error: missing Lavish process-to-event adapter: %s\n' "$LAVISH_ADAPTER" >&2
    exit 1
  }
}

require_artifact() {
  [ -f "$DASH_ARTIFACT" ] || {
    printf 'error: no dashboard artifact at %s; run review first\n' "$DASH_ARTIFACT" >&2
    exit 1
  }
}

# Open the artifact as a Lavish session and arm the one sanctioned chat-back
# loop. This script owns the artifact only; the poll's lifecycle belongs to
# bin/fm-procevent.sh, and this must never become a detached fire-and-forget
# process.
cmd_review() {
  local artifact="${1:-$DASH_ARTIFACT}"
  case "$artifact" in
    -*) printf 'usage error: artifact path must not start with a dash\n' >&2; exit 1 ;;
  esac
  require_lavish
  require_adapter
  bash "$SELF_DIR/lane-todo-dash.sh" "$artifact" >/dev/null || exit 1
  lavish-axi "$artifact"
  "$LAVISH_ADAPTER" arm "$artifact"
  exit 0
}

cmd_reply() {
  require_lavish
  [ "$#" -ge 1 ] || { printf 'usage error: reply needs a message\n' >&2; exit 1; }
  require_artifact
  lavish-axi reply "$DASH_ARTIFACT" --agent-reply "$*"
  exit 0
}

cmd_end() {
  require_lavish
  require_adapter
  require_artifact
  lavish-axi end "$DASH_ARTIFACT"
  "$LAVISH_ADAPTER" retire "$DASH_ARTIFACT"
  exit 0
}

case "${1:-}" in
  review) shift; cmd_review "$@" ;;
  reply)  shift; cmd_reply "$@" ;;
  end)    shift; cmd_end "$@" ;;
esac

if [ "${1:-}" = "serve" ]; then
  shift
  if [ "$#" -gt 1 ]; then
    printf 'usage error: serve accepts at most one TCP port\n' >&2
    exit 1
  fi
  if [ "$#" -eq 1 ] && ! [[ "$1" =~ ^[0-9]{1,5}$ ]]; then
    printf 'usage error: port must be a number from 1 through 65535\n' >&2
    exit 1
  fi
  [ "$#" -eq 0 ] || export LANE_TODO_DASH_PORT="$1"
  exec python3 "$SELF_DIR/lane-todo-dash-server.py" "$SELF_DIR/lane-todo-dash.sh"
fi
OUT="${1:-index.html}"
TMP="${OUT}.tmp.$$"
cleanup() {
  rm -f -- "$TMP"
  [ -z "${BACKLOG_TMP:-}" ] || rm -f -- "$BACKLOG_TMP"
  [ -z "${POINTERS_TMP:-}" ] || rm -f -- "$POINTERS_TMP"
}
trap cleanup EXIT

html() {
  local value="$1"
  while [[ "$value" =~ https?://[^[:space:]]+ ]]; do
    value="${value/${BASH_REMATCH[0]}/[external URL omitted]}"
  done
  while [[ "$value" =~ www\.[^[:space:]]+ ]]; do
    value="${value/${BASH_REMATCH[0]}/[external URL omitted]}"
  done
  while [[ "$value" =~ mailto:[^[:space:]]+ ]]; do
    value="${value/${BASH_REMATCH[0]}/[external URL omitted]}"
  done
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

format_bytes() {
  awk -v n="${1:-0}" 'BEGIN {
    split("B KiB MiB GiB TiB", units, " ")
    i = 1
    while (n >= 1024 && i < 5) { n /= 1024; i++ }
    if (i == 1) printf "%.0f %s", n, units[i]
    else printf "%.1f %s", n, units[i]
  }'
}

tree_bytes() {
  local path="$1" bytes
  if [ -d "$path" ] && [ ! -L "$path" ]; then
    bytes=$(du -sb -- "$path" 2>/dev/null | awk 'NR == 1 {print $1}')
  else
    bytes=$(stat -c %s -- "$path" 2>/dev/null || printf '0')
  fi
  printf '%s' "${bytes:-0}"
}

warehouse_tree() { # <directory>
  local directory="$1" child name bytes age
  local -a children=()
  [ -d "$directory" ] || return 0
  mapfile -d '' -t children < <(find "$directory" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)
  for child in "${children[@]}"; do
    name="${child##*/}"
    bytes=$(tree_bytes "$child")
    age=$(age_for "$child")
    if [ -d "$child" ] && [ ! -L "$child" ]; then
      printf '<li><details open><summary>%s <small class="muted">directory · %s · %s</small></summary><ul>\n' \
        "$(html "$name")" "$(format_bytes "$bytes")" "$(html "$age")"
      warehouse_tree "$child"
      printf '</ul></details></li>\n'
    else
      node_kind='file'
      [ ! -L "$child" ] || node_kind=pointer
      printf '<li>%s <small class="muted">%s · %s · %s</small></li>\n' \
        "$(html "$name")" "$node_kind" "$(format_bytes "$bytes")" "$(html "$age")"
    fi
  done
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

# Pull the authoritative backlog without changing the controller source. Keep
# the last complete copy on HD2 so a temporary SSH failure remains visible.
BACKLOG_CACHE="$STATE/dash-live-url-cache/backlog.md"
BACKLOG_STATUS=""
umask 077
mkdir -p -- "$(dirname "$BACKLOG_CACHE")"
chmod 700 "$(dirname "$BACKLOG_CACHE")" 2>/dev/null || :
BACKLOG_TMP="${BACKLOG_CACHE}.tmp.$$"
if ssh -o BatchMode=yes -o ConnectTimeout=5 100.117.47.27 \
  'cat -- /root/agent-work/deightonllm-firstmate/data/backlog.md' > "$BACKLOG_TMP" 2>/dev/null \
  && [ -s "$BACKLOG_TMP" ]; then
  mv -f -- "$BACKLOG_TMP" "$BACKLOG_CACHE"
  chmod 600 "$BACKLOG_CACHE" 2>/dev/null || :
  BACKLOG_STATUS="live from controller · refreshed $(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
  rm -f -- "$BACKLOG_TMP"
  if [ -f "$BACKLOG_CACHE" ]; then
    chmod 600 "$BACKLOG_CACHE" 2>/dev/null || :
    cache_epoch=$(stat -c %Y -- "$BACKLOG_CACHE" 2>/dev/null || printf '0')
    cache_now=$(date +%s)
    cache_age=$((cache_now - cache_epoch)); [ "$cache_age" -ge 0 ] || cache_age=0
    BACKLOG_STATUS="stale: ${cache_age}s · controller unavailable"
  else
    BACKLOG_STATUS="unavailable · controller unreachable and no cache"
  fi
fi
WAREHOUSE_ROOT="$(cd "$FM_HOME/.." 2>/dev/null && pwd)/warehouse"
SPINE_ROOT="$WAREHOUSE_ROOT/SPINE"
POINTERS_TMP="$STATE/dash-live-url-cache/pointers.tmp.$$"
find "$FM_HOME/data" "$SPINE_ROOT" -maxdepth 4 \
  \( -type l -o -type f \( -iname '*pointer*' -o -iname '*warehouse*' -o -iname '*spine*' \) \) \
  -print0 2>/dev/null | sort -z > "$POINTERS_TMP" || :

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
capacity_used=0
capacity_used_label='—'
if [ "$declared" -gt 0 ]; then
  capacity_used=$((running * 100 / declared))
  capacity_used_label="${capacity_used}%"
fi
compaction_headroom=""
compaction_count=0

mkdir -p -- "$(dirname "$OUT")"
{
  cat <<HTML
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fleet ticket dashboard</title>
<style>
:root{color-scheme:dark;--bg:#101820;--panel:#192630;--line:#30434e;--ink:#e9f0f2;--muted:#a8b9c1;--accent:#75d4c3;--warn:#ffd27a;--dim:var(--muted);--ok:var(--accent);--bad:#ff9c91}
*{box-sizing:border-box}body{margin:0;padding:28px;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
header{display:flex;justify-content:space-between;align-items:end;gap:16px;margin:0 auto 22px;max-width:1400px}h1{margin:0;font-size:clamp(1.6rem,3vw,2.4rem)}h2{margin:0 0 14px;font-size:1.15rem}small,.muted{color:var(--muted)}main{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;max-width:1400px;margin:auto}.card{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:18px;min-width:0}.wide{grid-column:1/-1}.capacity{font-size:1.3rem;color:var(--accent);font-weight:700}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:9px 8px;border-bottom:1px solid var(--line);vertical-align:top}th{font-size:.8rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted)}td{overflow-wrap:anywhere}.state{font-weight:700;color:var(--accent)}.ticket{white-space:normal}.badge{display:inline-block;padding:2px 8px;border-radius:999px;background:#263b47;color:var(--accent)}.blocker{color:var(--warn)}.empty{color:var(--muted);font-style:italic}.receipt{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid var(--line)}.gate{font-family:ui-monospace,monospace}.status-pass{color:var(--accent)}.status-fail{color:#ff9c91}button,select,textarea{font:inherit;color:var(--ink);background:#1e303a;border:1px solid var(--line);border-radius:7px;padding:7px 10px}button{cursor:pointer}button:hover{border-color:var(--accent)}.filters{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:12px}.filters label{display:grid;gap:3px;color:var(--muted);font-size:.85rem}details summary{cursor:pointer;color:var(--accent);font-weight:650}details[open] summary{margin-bottom:8px}.lane-detail,.ticket-detail{padding:8px;border-left:2px solid var(--line);overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit;color:var(--muted);margin:6px 0}.feedback-form{display:grid;gap:8px;margin-top:10px;max-width:680px}.feedback-form textarea{min-height:90px;resize:vertical}.feedback-status{min-height:1.4em;color:var(--accent)}.dashboard-tools{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
@media(max-width:800px){body{padding:14px}main{grid-template-columns:1fr}.wide{grid-column:auto}header{align-items:start;flex-direction:column}table{font-size:.9rem}th,td{padding:7px 4px}}
@media(min-width:401px){body{padding-right:96px !important}}
@media(max-width:400px){body{padding-right:14px !important}}
.none{color:var(--dim);font-style:italic}
#pill{position:fixed;right:0;top:50%;transform:translateY(-50%);z-index:60;background:var(--panel);border:1px solid var(--line);border-right:none;border-radius:10px 0 0 10px;padding:10px 8px;width:46px;box-shadow:-4px 0 18px rgba(0,0,0,.5);cursor:pointer;transition:width .25s ease,padding .25s ease;overflow:hidden}
#pill:hover{width:252px;padding:12px 14px}
#pill .pnum{font-size:14px;font-weight:700;text-align:center;font-variant-numeric:tabular-nums;letter-spacing:-.02em}
#pill .ptrack{height:4px;background:#010409;border-radius:3px;margin-top:7px;overflow:hidden}
#pill .pfill{height:100%;width:0;border-radius:3px;background:linear-gradient(90deg,#a371f7,#58a6ff,#3fb950);transition:width .6s ease}
#pill .detail{display:none}
#pill:hover .pnum,#pill:hover .ptrack{display:none}
#pill:hover .detail{display:block}
#pill .drow{display:flex;justify-content:space-between;gap:12px;font-size:11.5px;line-height:1.75}
#pill .dk{color:var(--dim)}
#pill .dv{font-weight:600;font-variant-numeric:tabular-nums;text-align:right}
#pill .dhead{font-size:10px;letter-spacing:.07em;text-transform:uppercase;color:var(--dim);font-weight:600;margin-bottom:7px}
#pill .deta{margin-top:7px;padding-top:7px;border-top:1px solid var(--line);font-size:12px;font-weight:600}
#pill .warn{color:var(--warn)} #pill .ok{color:var(--ok)} #pill .bad{color:var(--bad)}
@media(max-width:860px){#pill{display:none}}
</style></head><body><header><div><h1>Fleet ticket dashboard</h1><small>Local snapshot · no external resources</small></div><div class="dashboard-tools"><small>Generated <time datetime="$generated">$generated</time></small><form action="/" method="get"><button type="submit">Refresh snapshot</button></form></div></header><main>
<section class="card wide"><h2>Filters</h2><div class="filters"><label>State<select id="state-filter"><option value="">All states</option></select></label><label>Priority<select id="priority-filter"><option value="">All priorities</option></select></label><label>Host<select id="host-filter"><option value="">All hosts</option></select></label></div></section>
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
    host=$(field "$STATE/lanes/$name.lane" host); [ -n "$host" ] || host=$(field "$STATE/$task.meta" host); [ -n "$host" ] || host="$surface"
    lane_headroom=$(field "$STATE/lanes/$name.lane" compaction_headroom_pct)
    [ -n "$lane_headroom" ] || lane_headroom=$(field "$STATE/$task.meta" compaction_headroom_pct)
    if [[ "$lane_headroom" =~ ^([0-9]|[1-9][0-9]|100)$ ]]; then
      if [ "$compaction_count" -eq 0 ] || [ "$lane_headroom" -lt "$compaction_headroom" ]; then
        compaction_headroom="$lane_headroom"
      fi
      compaction_count=$((compaction_count + 1))
    fi
    status=$(lane_status "$task"); activity='(none)'; todo='(no todo file)'; status_detail='(no status events)'
    if [ -f "$STATE/$task.status" ]; then activity=$(date -u -r "$STATE/$task.status" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '(unknown)'); fi
    [ ! -f "$STATE/lanes/$name.todo.md" ] || todo=$(cat -- "$STATE/lanes/$name.todo.md")
    [ ! -f "$STATE/$task.status" ] || status_detail=$(tail -n 10 -- "$STATE/$task.status")
    printf '<tr class="lane-row" data-state="%s" data-host="%s">\n' "$(html "$status")" "$(html "$host")"
    printf '<td><details><summary>%s</summary><div class="lane-detail"><p><strong>Task:</strong> %s<br><strong>Model:</strong> %s<br><strong>Host:</strong> %s<br><strong>Surface:</strong> %s</p><strong>Latest status events</strong><pre>%s</pre><strong>To-Do</strong><pre>%s</pre></div></details></td>\n' \
      "$(html "$name")" "$(html "$task")" "$(html "$model")" "$(html "$host")" "$(html "$surface")" \
      "$(html "$status_detail")" "$(html "$todo")"
    printf '<td>%s</td><td>%s</td><td>%s</td><td class="state">%s</td><td>%s</td></tr>\n' \
      "$(html "$model")" "$(html "$surface")" "$(html "$task")" "$(html "$status")" "$(html "$activity")"
  done
  if [ "$lanes" -eq 0 ]; then printf '<tr><td colspan="5" class="empty">No registered lanes</td></tr>\n'; fi
  printf '</tbody></table></section>\n'

  printf '<section class="card wide"><h2>Tickets by priority</h2><table><thead><tr><th>Priority</th><th>Ticket</th><th>Claim</th><th>Blocker</th></tr></thead><tbody>\n'
  printf '<p class="muted">Backlog: %s</p>\n' "$(html "$BACKLOG_STATUS")"
  backlog="$BACKLOG_CACHE"; priority=unassigned; ticket=""; claim=""; blocker=""; ticket_state=open; ticket_count=0; ticket_done_count=0
  emit_ticket() {
    [ -n "$ticket" ] || return 0
    local ticket_host="all"
    case "${ticket,,}" in
      *elevate*|*staging*|*core-distro*|*whoosh*|*cbd*|*srv1137994*) ticket_host="elevate-vps" ;;
      *hetz*|*brandon*|*100.106.6.22*) ticket_host="hetzner" ;;
      *hd2*|*ttft*|*surface*|*firstmate*) ticket_host="hd2stack" ;;
      *controller*|*kvm1*) ticket_host="controller" ;;
    esac
    printf '<tr class="ticket-row" data-state="%s" data-priority="%s" data-host="%s"><td>%s</td><td class="ticket"><details><summary>%s</summary><div class="ticket-detail"><p><strong>Claim:</strong> %s<br><strong>Blocker:</strong> %s</p><form class="feedback-form" action="/feedback" method="post"><input type="hidden" name="ticket" value="%s"><label>Feedback on this ticket<textarea name="comment" maxlength="8000" required></textarea></label><button type="submit">Send feedback</button><span class="feedback-status" aria-live="polite"></span></form></div></details></td><td>%s</td><td class="blocker">%s</td></tr>\n' \
      "$(html "$ticket_state")" "$(html "$priority")" "$(html "$ticket_host")" "$(html "$priority")" "$(html "$ticket")" "$(html "${claim:-unclaimed}")" \
      "$(html "${blocker:-none}")" "$(html "$ticket")" "$(html "${claim:-unclaimed}")" "$(html "${blocker:-none}")"
    ticket_count=$((ticket_count + 1))
    if [ "$ticket_state" = 'done' ]; then ticket_done_count=$((ticket_done_count + 1)); fi
  }
  if [ -f "$backlog" ]; then
    ticket_re='^-[[:space:]]+\[([ xX])\][[:space:]]+(.+)$'
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" =~ ^#{1,3}[[:space:]]+(P[1-4])([[:space:]]|$) ]]; then
        emit_ticket; ticket=""; claim=""; blocker=""; priority="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ $ticket_re ]]; then
        emit_ticket; ticket="${BASH_REMATCH[2]}"; claim=""; blocker=""
        if [[ "${BASH_REMATCH[1]}" =~ [xX] ]]; then
          ticket_state='done'
        else
          ticket_state=open
        fi
      elif [[ "$line" =~ ^[[:space:]]*(claim|claimed|owner):[[:space:]]*(.*)$ ]]; then claim="${BASH_REMATCH[2]}"
      elif [[ "$line" =~ ^[[:space:]]*blocker(s)?:[[:space:]]*(.*)$ ]]; then blocker="${BASH_REMATCH[2]}"
      fi
    done < "$backlog"
    emit_ticket
  fi
  if [ "$ticket_count" -eq 0 ]; then printf '<tr><td colspan="4" class="empty">No backlog tickets found</td></tr>\n'; fi
  printf '</tbody></table></section>\n'
  ticket_done_pct=0
  ticket_done_label='—'
  [ "$ticket_count" -eq 0 ] || { ticket_done_pct=$((ticket_done_count * 100 / ticket_count)); ticket_done_label="${ticket_done_pct}%"; }
  capacity_class=ok
  if [ "$capacity_used" -gt 100 ]; then capacity_class=bad; elif [ "$capacity_used" -ge 80 ]; then capacity_class=warn; fi
  compaction_label='—'
  compaction_class=warn
  if [ "$compaction_count" -gt 0 ]; then
    compaction_label="${compaction_headroom}%"
    if [ "$compaction_headroom" -le 10 ]; then compaction_class=bad; elif [ "$compaction_headroom" -le 25 ]; then compaction_class=warn; else compaction_class=ok; fi
  fi
  printf '<aside id="pill" aria-label="Fleet metrics: tickets done %s"><div class="pnum">%s</div><div class="ptrack" role="progressbar" aria-label="Tickets done" aria-valuemin="0" aria-valuemax="100" aria-valuenow="%s"><div class="pfill" style="width:%s%%"></div></div><div class="detail"><div class="dhead">Fleet metrics</div><div class="drow"><span class="dk">Capacity used</span><span class="dv %s">%s</span></div><div class="drow"><span class="dk">Tickets done</span><span class="dv">%s / %s · %s</span></div><div class="drow"><span class="dk">Compaction headroom</span><span class="dv %s">%s</span></div><div class="deta">%s running · %s declared capacity</div><div class="none">%s</div></div></aside>\n' \
    "$(html "$ticket_done_label")" "$(html "$ticket_done_label")" "$ticket_done_pct" "$ticket_done_pct" \
    "$capacity_class" "$(html "$capacity_used_label")" "$ticket_done_count" "$ticket_count" "$(html "$ticket_done_label")" \
    "$compaction_class" "$(html "$compaction_label")" "$running" "$declared" \
    "$(if [ "$compaction_count" -eq 0 ]; then printf 'No live context reading reported'; fi)"
  printf '<section class="card wide"><h2>General feedback</h2><p class="muted">Feedback is saved in state/dash-feedback for agent intake.</p><form class="feedback-form" action="/feedback" method="post"><input type="hidden" name="ticket" value="General feedback"><label>Comment<textarea name="comment" maxlength="8000" required></textarea></label><button type="submit">Send feedback</button><span class="feedback-status" aria-live="polite"></span></form></section>\n'

  printf '<section class="card"><h2>Hetz comms receipts</h2>\n'
  for direction in inbound outbound; do
    receipt=$(last_file "$direction")
    if [ -n "$receipt" ]; then
      printf '<div class="receipt"><span>%s · %s</span><span>%s</span></div>\n' "$(html "$direction")" "$(html "${receipt##*/}")" "$(html "$(age_for "$receipt")")"
    else printf '<div class="receipt"><span>%s</span><span class="empty">no receipt</span></div>\n' "$(html "$direction")"; fi
  done
  printf '</section>\n'
  printf '<section class="card"><h2>Capacity</h2><div class="capacity">Declared %s · Running %s</div><small>Running counts working panes from Herdr pane list.</small></section>\n' "$declared" "$running"

  printf '<section class="card wide"><h2>Warehouse map</h2><p class="muted">SPINE = shared append-only; LOCAL = this host only, never synced.</p><ul class="warehouse-tree">\n'
  root="$FM_HOME/data/end-to-end-20261012"
  if [ -d "$root" ]; then
    bytes=$(tree_bytes "$root"); age=$(age_for "$root")
    printf '<li><details open><summary>data/end-to-end-20261012 <small class="muted">directory · %s · %s</small></summary><ul>\n' \
      "$(format_bytes "$bytes")" "$(html "$age")"
    warehouse_tree "$root"
    printf '</ul></details></li>\n'
  else
    printf '<li>data/end-to-end-20261012 <small class="muted">not present on this host</small></li>\n'
  fi
  if [ -d "$SPINE_ROOT" ]; then
    bytes=$(tree_bytes "$SPINE_ROOT"); age=$(age_for "$SPINE_ROOT")
    printf '<li><details open><summary>warehouse/SPINE <small class="muted">directory · %s · %s</small></summary><ul>\n' \
      "$(format_bytes "$bytes")" "$(html "$age")"
    warehouse_tree "$SPINE_ROOT"
    printf '</ul></details></li>\n'
  else
    printf '<li>warehouse/SPINE <small class="muted">not present on this host</small></li>\n'
  fi
  pointer_count=0
  while IFS= read -r -d '' pointer; do
    [ -n "$pointer" ] || continue
    pointer_count=$((pointer_count + 1))
    case "$pointer" in
      "$FM_HOME"/*) pointer_label="LOCAL/${pointer#"$FM_HOME"/}" ;;
      "$WAREHOUSE_ROOT"/*) pointer_label="warehouse/${pointer#"$WAREHOUSE_ROOT"/}" ;;
      *) pointer_label="${pointer##*/}" ;;
    esac
    bytes=$(tree_bytes "$pointer"); age=$(age_for "$pointer")
    printf '<li>%s <small class="muted">per-domain pointer · %s · %s</small></li>\n' \
      "$(html "$pointer_label")" "$(format_bytes "$bytes")" "$(html "$age")"
  done < "$POINTERS_TMP"
  if [ "$pointer_count" -eq 0 ]; then
    printf '<li class="muted">No per-domain warehouse pointers found</li>\n'
  fi
  printf '</ul></section>\n'

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
  cat <<'HTML'
</tbody></table></section></main>
<script>
(() => {
  const filters = {
    state: document.querySelector('#state-filter'),
    priority: document.querySelector('#priority-filter'),
    host: document.querySelector('#host-filter')
  };
  const rows = [...document.querySelectorAll('.lane-row, .ticket-row')];
  const options = {state: new Set(), priority: new Set(), host: new Set()};
  for (const row of rows) {
    if (row.dataset.state) options.state.add(row.dataset.state);
    if (row.dataset.priority) options.priority.add(row.dataset.priority);
    if (row.dataset.host && row.dataset.host !== 'all') options.host.add(row.dataset.host);
  }
  for (const name of Object.keys(filters)) {
    for (const value of [...options[name]].sort()) {
      const option = document.createElement('option'); option.value = value; option.textContent = value;
      filters[name].append(option);
    }
  }
  const applyFilters = () => {
    for (const row of rows) {
      const visible = (!filters.state.value || row.dataset.state === filters.state.value)
        && (!filters.priority.value || !row.classList.contains('ticket-row') || row.dataset.priority === filters.priority.value)
        && (!filters.host.value || row.dataset.host === 'all' || row.dataset.host === filters.host.value);
      row.hidden = !visible;
    }
  };
  Object.values(filters).forEach(filter => filter.addEventListener('change', applyFilters));
  document.querySelectorAll('.feedback-form').forEach(form => form.addEventListener('submit', async event => {
    event.preventDefault();
    const message = form.querySelector('.feedback-status');
    try {
      const response = await fetch(form.action, {method: 'POST', body: new FormData(form)});
      const result = await response.text();
      if (!response.ok) throw new Error(result || `HTTP ${response.status}`);
      message.textContent = result;
      form.reset();
    } catch (error) { message.textContent = `Could not send feedback: ${error.message}`; }
  }));
})();
</script></body></html>
HTML
} > "$TMP"
mv -f -- "$TMP" "$OUT"
rm -f -- "$POINTERS_TMP"
trap - EXIT
printf 'generated: %s\n' "$OUT"
