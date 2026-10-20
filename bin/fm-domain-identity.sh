#!/usr/bin/env bash
# bin/fm-domain-identity.sh - report, and opt-in write, the domain identity and
# the tracked-file sync state of every registered firstmate home.
#
# Usage:
#   fm-domain-identity.sh [--help] [--apply] [--force] [--home <id>]
#
# Read-only by default.
# It never mutates a project, never mutates a secondmate home without --apply,
# and never forces anything.
#
# Per registered home it reports:
#   - the context file Pi would actually load from that home's own directory
#     (first match wins, one file per directory)
#   - whether the home owns a domain identity file, and which ancestor context
#     file it inherits when it does not
#   - the tracked-file sync state against the primary's main commit
#   - the CLAUDE.md shape in that home
# It ends with one fleet verdict line and the exact reason for every failure.
#
# --apply writes a domain-specific AGENTS.override.md into a registered home.
# The write is idempotent, refuses to overwrite an existing file without
# --force, and refuses a diverged or dirty home without --force.
#
# Registered homes come from state/<id>.meta records with kind=secondmate, with
# data/secondmates.md as the home= fallback, the same discovery
# bin/fm-config-push.sh uses.
#
# Every git invocation runs through di_git, which allows only read-only
# subcommands, and a startup self-check refuses to run when this file holds any
# other git invocation.
#
# Environment overrides follow the rest of firstmate:
#   FM_HOME            active firstmate home (the sync base)
#   FM_ROOT_OVERRIDE  firstmate repo root
#   FM_STATE_OVERRIDE  state dir
#   FM_DATA_OVERRIDE  data dir
#   FM_TREEHOUSE_ROOTS colon-separated pool roots scanned for the slot census
#
# Exit codes:
#   0  every registered home is domain-scoped and in sync
#   1  at least one registered home fails, with the reason printed
#   2  usage error
set -u

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
REGISTRY="$DATA/secondmates.md"

# The Pi context-file candidate order, first match per directory wins.
# Verified in the upstream resource loader and recorded in docs/domain-identity.md.
DI_CONTEXT_CANDIDATES="AGENTS.override.md AGENTS.md AGENTS.MD CLAUDE.md CLAUDE.MD"

# The marker line that makes a file a domain identity file rather than an
# inherited note. The marker names the secondmate id the file belongs to.
DI_MARKER_PREFIX="DOMAIN-IDENTITY:"

APPLY=0
FORCE=0
ONLY_HOME=""
FAILED=0
REASON_LOG=""

usage() {
  sed -n '2,44{s/^# \{0,1\}//;p;}' "$SELF"
}

usage_error() {
  printf 'usage: fm-domain-identity.sh [--help] [--apply] [--force] [--home <id>]\n' >&2
  printf 'domain-identity: %s\n' "$1" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --home)
      [ "$#" -ge 2 ] || usage_error "--home requires an id"
      ONLY_HOME="$2"
      shift 2
      ;;
    --home=*)
      ONLY_HOME="${1#*=}"
      shift
      ;;
    *)
      usage_error "unknown argument: $1"
      ;;
  esac
done

if [ "$FORCE" -eq 1 ] && [ "$APPLY" -eq 0 ]; then
  usage_error "--force is only meaningful with --apply"
fi

# --- the read-only git guard ------------------------------------------------

# Only these git subcommands may run. Everything else is refused.
DI_GIT_READONLY="rev-parse rev-list merge-base status log show diff ls-files cat-file symbolic-ref for-each-ref diff-index diff-files"

# di_git <dir> <subcommand> [args...]
# The subcommand is the first argument after the directory, so no option can be
# smuggled in front of it, and the allowlist is checked before anything runs.
di_git() {
  local dir=$1 sub=$2 arg
  shift 2
  case " $DI_GIT_READONLY " in
    *" $sub "*) : ;;
    *)
      printf 'domain-identity: refusing non-read-only git subcommand: %s\n' "$sub" >&2
      return 3
      ;;
  esac
  for arg in "$@"; do
    case "$arg" in
      -c|--exec*|--upload-pack*|--receive-pack*|core.pager*|core.sshCommand*)
        printf 'domain-identity: refusing unsafe git argument: %s\n' "$arg" >&2
        return 3
        ;;
    esac
  done
  git -C "$dir" "$sub" "$@"
}

# di_assert_only_guarded_git
# Static self-check: every git invocation in this file must sit inside di_git.
# The allowlist is the runtime guard, and this check keeps a future edit from
# adding a second, unguarded call site.
di_assert_only_guarded_git() {
  local start end line hits=0 bad=""
  start=$(grep -n '^di_git() {' "$SELF" | head -1 | cut -d: -f1)
  end=$(awk -v s="$start" 'NR > s && /^}$/ { print NR; exit }' "$SELF")
  if [ -z "$start" ] || [ -z "$end" ]; then
    printf 'domain-identity: cannot locate the git guard in this file\n' >&2
    return 1
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    hits=$((hits + 1))
    if [ "$line" -lt "$start" ] || [ "$line" -gt "$end" ]; then
      bad="$bad $line"
    fi
  done <<EOF
$(grep -nE '(^|[[:space:];|&(])git[[:space:]]+-[A-Za-z]' "$SELF" | cut -d: -f1)
EOF
  if [ "$hits" -eq 0 ]; then
    printf 'domain-identity: this file holds no git invocation\n' >&2
    return 1
  fi
  if [ -n "$bad" ]; then
    printf 'domain-identity: unguarded git invocation on line(s):%s\n' "$bad" >&2
    return 1
  fi
  return 0
}

# --- small helpers ----------------------------------------------------------

# di_sha12 <file>: the first 12 hex characters of the file sha256, or unknown.
di_sha12() {
  local file=$1 out
  [ -f "$file" ] || {
    printf 'unknown\n'
    return 0
  }
  out=$(sha256sum "$file" 2>/dev/null | cut -c1-12)
  case "$out" in
    ''|*[!0-9a-f]*) out=unknown ;;
  esac
  printf '%s\n' "$out"
}

# di_bytes <file>: the file size in bytes, or unknown.
di_bytes() {
  local file=$1 out
  [ -f "$file" ] || {
    printf 'unknown\n'
    return 0
  }
  out=$(wc -c < "$file" 2>/dev/null | tr -d '[:space:]')
  case "$out" in
    ''|*[!0-9]*) out=unknown ;;
  esac
  printf '%s\n' "$out"
}

# di_shape <path>: symlink, import stub, regular file, or absent.
di_shape() {
  local path=$1
  if [ -L "$path" ]; then
    printf 'symlink -> %s\n' "$(readlink "$path" 2>/dev/null || printf 'unknown')"
    return 0
  fi
  if [ -f "$path" ]; then
    if grep -qE '^[[:space:]]*@AGENTS\.md' "$path" 2>/dev/null; then
      printf 'import stub'
    else
      printf 'regular file'
    fi
    return 0
  fi
  printf 'absent'
}

# di_effective_context_file <dir>: the first candidate that exists in that dir.
# This mirrors the upstream loader, which takes the first match per directory.
di_effective_context_file() {
  local dir=$1 name
  for name in $DI_CONTEXT_CANDIDATES; do
    if [ -f "$dir/$name" ]; then
      printf '%s\n' "$dir/$name"
      return 0
    fi
  done
  return 1
}

# di_ancestor_context_file <dir>: the nearest ancestor directory that holds a
# context file, because Pi loads the working directory and its parents.
di_ancestor_context_file() {
  local dir=$1 parent found
  parent=$(dirname "$dir")
  while [ -n "$parent" ] && [ "$parent" != "/" ]; do
    if found=$(di_effective_context_file "$parent"); then
      printf '%s\n' "$found"
      return 0
    fi
    dir="$parent"
    parent=$(dirname "$parent")
  done
  if found=$(di_effective_context_file "/"); then
    printf '%s\n' "$found"
    return 0
  fi
  return 1
}

# di_marker_id <file>: the id named by the domain identity marker, or empty.
di_marker_id() {
  local file=$1 out
  [ -f "$file" ] || return 1
  out=$(grep -m1 "^${DI_MARKER_PREFIX}" "$file" 2>/dev/null | sed "s/^${DI_MARKER_PREFIX}[[:space:]]*//")
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# --- home discovery ---------------------------------------------------------

# shellcheck source=bin/fm-secondmate-registry-lib.sh
. "$SCRIPT_DIR/fm-secondmate-registry-lib.sh"

declare -a DI_ID_LIST=()
declare -a DI_HOME_LIST=()
declare -a DI_SOURCE_LIST=()
declare -a DI_SCOPE_LIST=()
declare -A DI_INDEX=()

# di_registry_lookup <id>: the registry home on stdout, the scope in
# DI_LOOKUP_SCOPE.
di_registry_lookup() {
  local id=$1
  DI_LOOKUP_SCOPE=""
  secondmate_registry_line_for_id "$REGISTRY" "$id" || return 1
  DI_LOOKUP_SCOPE="$SECONDMATE_REGISTRY_SCOPE"
  printf '%s\n' "$SECONDMATE_REGISTRY_HOME"
}

# di_add_home <id> <home> <source> <scope>: fold one discovery hit into the lists.
di_add_home() {
  local id=$1 home=$2 source=$3 scope=$4 index
  if [ -n "${DI_INDEX[$id]:-}" ]; then
    index="${DI_INDEX[$id]}"
    if [ -n "$home" ]; then
      DI_HOME_LIST[index]="$home"
    fi
    case " ${DI_SOURCE_LIST[index]} " in
      *" $source "*) : ;;
      *) DI_SOURCE_LIST[index]="${DI_SOURCE_LIST[index]} $source" ;;
    esac
    if [ -z "${DI_SCOPE_LIST[index]}" ] && [ -n "$scope" ]; then
      DI_SCOPE_LIST[index]="$scope"
    fi
    return 0
  fi
  DI_INDEX[$id]="${#DI_ID_LIST[@]}"
  DI_ID_LIST+=("$id")
  DI_HOME_LIST+=("$home")
  DI_SOURCE_LIST+=("$source")
  DI_SCOPE_LIST+=("$scope")
}

# di_discover_homes: fills the id, home, source and scope lists.
di_discover_homes() {
  local meta id home scope
  if [ -f "$REGISTRY" ] && [ ! -L "$REGISTRY" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "- "*) : ;;
        *) continue ;;
      esac
      secondmate_registry_parse_line "$line" || continue
      di_add_home "$SECONDMATE_REGISTRY_ID" "$SECONDMATE_REGISTRY_HOME" \
        "registry" "$SECONDMATE_REGISTRY_SCOPE"
    done < "$REGISTRY"
  fi
  if [ -d "$STATE" ]; then
    for meta in "$STATE"/*.meta; do
      [ -f "$meta" ] || continue
      grep -q '^kind=secondmate$' "$meta" 2>/dev/null || continue
      id=$(basename "$meta" .meta)
      home=$(grep '^home=' "$meta" 2>/dev/null | tail -1 | cut -d= -f2- || true)
      scope=""
      if [ -z "$home" ]; then
        home=$(di_registry_lookup "$id" 2>/dev/null || true)
        scope="$DI_LOOKUP_SCOPE"
      fi
      di_add_home "$id" "$home" "meta" "$scope"
    done
  fi
}

# --- per-home measurement ---------------------------------------------------

DI_CONTEXT_FILE=""
DI_CONTEXT_SHAPE=""
DI_CONTEXT_BYTES=""
DI_OVERRIDE=""
DI_OVERRIDE_MARKER=""
DI_CLAUDE_SHAPE=""
DI_CLAUDE_BYTES=""
DI_ANCESTOR=""
DI_ANCESTOR_MARKER=""
DI_HEAD=""
DI_BRANCH=""
DI_ANCESTOR_OF_MAIN=""
DI_AHEAD=""
DI_BEHIND=""
DI_SYNC=""
DI_DIRTY=""
DI_DIRTY_LIST=""
DI_OWN_UNTRACKED=""
DI_AGENTS_SHA=""
DI_EXCLUDE_PATH=""
DI_EXCLUDED=""

# di_measure_home <home>: measure one home. Every fact is read-only.
di_measure_home() {
  local home=$1 porcelain line counts context ancestor
  DI_CONTEXT_FILE=""
  DI_CONTEXT_SHAPE="absent"
  DI_CONTEXT_BYTES="unknown"
  DI_OVERRIDE=""
  DI_OVERRIDE_MARKER=""
  DI_CLAUDE_SHAPE="absent"
  DI_CLAUDE_BYTES="unknown"
  DI_ANCESTOR=""
  DI_ANCESTOR_MARKER=""
  DI_HEAD="unknown"
  DI_BRANCH="unknown"
  DI_ANCESTOR_OF_MAIN="unknown"
  DI_AHEAD="unknown"
  DI_BEHIND="unknown"
  DI_SYNC="unknown"
  DI_DIRTY="unknown"
  DI_DIRTY_LIST=""
  DI_OWN_UNTRACKED=""
  DI_AGENTS_SHA="unknown"
  DI_EXCLUDE_PATH=""
  DI_EXCLUDED="no"

  if [ ! -d "$home" ]; then
    DI_SYNC="unknown - the home path is not a directory"
    return 1
  fi

  if context=$(di_effective_context_file "$home"); then
    DI_CONTEXT_FILE="$context"
    DI_CONTEXT_SHAPE=$(di_shape "$context")
    DI_CONTEXT_BYTES=$(di_bytes "$context")
  fi
  if [ -f "$home/AGENTS.override.md" ]; then
    DI_OVERRIDE="$home/AGENTS.override.md"
    DI_OVERRIDE_MARKER=$(di_marker_id "$home/AGENTS.override.md" 2>/dev/null || true)
  fi
  DI_CLAUDE_SHAPE=$(di_shape "$home/CLAUDE.md")
  DI_CLAUDE_BYTES=$(di_bytes "$home/CLAUDE.md")
  if ancestor=$(di_ancestor_context_file "$home"); then
    DI_ANCESTOR="$ancestor"
    DI_ANCESTOR_MARKER=$(di_marker_id "$ancestor" 2>/dev/null || true)
  fi
  if [ -f "$home/AGENTS.md" ]; then
    DI_AGENTS_SHA=$(di_sha12 "$home/AGENTS.md")
  fi

  if ! di_git "$home" rev-parse --git-dir >/dev/null 2>&1; then
    DI_SYNC="unknown - the home is not a git checkout"
    return 0
  fi

  DI_HEAD=$(di_git "$home" rev-parse HEAD 2>/dev/null || printf 'unknown')
  [ -n "$DI_HEAD" ] || DI_HEAD="unknown"
  DI_BRANCH=$(di_git "$home" symbolic-ref --short HEAD 2>/dev/null || printf 'detached HEAD')

  if [ "$PRIMARY_MAIN" != "unknown" ]; then
    if di_git "$home" rev-parse --verify --quiet "${PRIMARY_MAIN}^{commit}" >/dev/null 2>&1; then
      if di_git "$home" merge-base --is-ancestor HEAD "$PRIMARY_MAIN" 2>/dev/null; then
        DI_ANCESTOR_OF_MAIN="yes"
      else
        DI_ANCESTOR_OF_MAIN="no"
      fi
      counts=$(di_git "$home" rev-list --left-right --count "HEAD...${PRIMARY_MAIN}" 2>/dev/null || printf '')
      if [ -n "$counts" ]; then
        DI_AHEAD=$(printf '%s\n' "$counts" | awk '{print $1}')
        DI_BEHIND=$(printf '%s\n' "$counts" | awk '{print $2}')
      fi
    else
      DI_ANCESTOR_OF_MAIN="unknown - the primary main commit is not in this home's object store"
    fi
  fi

  if [ "$DI_HEAD" != "unknown" ] && [ "$PRIMARY_MAIN" != "unknown" ] && [ "$DI_HEAD" = "$PRIMARY_MAIN" ]; then
    DI_SYNC="current"
  elif [ "$DI_ANCESTOR_OF_MAIN" = "yes" ]; then
    DI_SYNC="stale - ${DI_BEHIND} commit(s) behind primary main"
  elif [ "$DI_ANCESTOR_OF_MAIN" = "no" ]; then
    DI_SYNC="diverged - ${DI_AHEAD} commit(s) only on this home, ${DI_BEHIND} commit(s) only on primary main"
  elif [ "$DI_ANCESTOR_OF_MAIN" != "unknown" ]; then
    DI_SYNC="unknown - ${DI_ANCESTOR_OF_MAIN}"
  fi

  porcelain=$(di_git "$home" status --porcelain 2>/dev/null || printf '')
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      *AGENTS.override.md) DI_OWN_UNTRACKED="$line" ;;
      *) DI_DIRTY_LIST="$DI_DIRTY_LIST$line
" ;;
    esac
  done <<EOF
$porcelain
EOF
  if [ -n "$DI_DIRTY_LIST" ]; then
    DI_DIRTY="yes"
  else
    DI_DIRTY="no"
  fi

  if exclude=$(di_git "$home" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null || printf ''); then
    if [ -n "$exclude" ] && [ -f "$exclude" ]; then
      DI_EXCLUDE_PATH="$exclude"
      if grep -q '^/AGENTS\.override\.md$' "$exclude" 2>/dev/null; then
        DI_EXCLUDED="yes"
      fi
    fi
  fi
  return 0
}

# --- the fleet report -------------------------------------------------------

DI_PRIMARY_AGENTS_SHA="unknown"
DI_PRIMARY_MAIN_SHA="unknown"
DI_CENSUS_NOTES=""

di_print_primary() {
  local porcelain count
  printf 'domain-identity: fleet startup-context report\n'
  if [ "$APPLY" -eq 1 ]; then
    printf 'mode: apply\n'
  else
    printf 'mode: read-only\n'
  fi
  printf 'primary home: %s\n' "$FM_HOME"
  printf 'primary main: %s\n' "$PRIMARY_MAIN"
  DI_PRIMARY_AGENTS_SHA=$(di_sha12 "$FM_HOME/AGENTS.md")
  printf 'primary agents.md (worktree): %s\n' "$DI_PRIMARY_AGENTS_SHA"
  if [ "$PRIMARY_MAIN" != "unknown" ]; then
    DI_PRIMARY_MAIN_SHA=$(di_git "$FM_HOME" show "${PRIMARY_MAIN}:AGENTS.md" 2>/dev/null | sha256sum | cut -c1-12)
    case "$DI_PRIMARY_MAIN_SHA" in
      ''|*[!0-9a-f]*) DI_PRIMARY_MAIN_SHA="unknown" ;;
    esac
  fi
  printf 'primary agents.md (committed main): %s\n' "$DI_PRIMARY_MAIN_SHA"
  porcelain=$(di_git "$FM_HOME" status --porcelain 2>/dev/null || printf '')
  count=$(printf '%s\n' "$porcelain" | grep -c . || true)
  case "$count" in
    ''|*[!0-9]*) count=0 ;;
  esac
  printf 'primary worktree: %s modified path(s) - the primary is the sync base and is not counted as a registered home\n' "$count"
  printf 'agent-dir context layer: %s - ' "$PI_AGENT_DIR"
  if [ -n "$PI_AGENT_DIR_FILES" ]; then
    printf '%s\n' "$PI_AGENT_DIR_FILES"
  else
    printf 'no AGENTS.md, AGENTS.override.md, CLAUDE.md, SYSTEM.md, or APPEND_SYSTEM.md\n'
  fi
}

# di_print_home <id> <home> <source>: the per-home block.
di_print_home() {
  local id=$1 home=$2 source=$3 reasons="" marker_state
  if ! di_measure_home "$home"; then
    printf '\nhome %s\n' "$id"
    printf '  path: %s\n' "$home"
    printf '  verdict: FAIL - the home path is not a directory\n'
    REASON_LOG="$REASON_LOG  $id: the home path is not a directory
"
    FAILED=1
    return 0
  fi

  printf '\nhome %s\n' "$id"
  printf '  path: %s\n' "$home"
  printf '  registered-by: %s\n' "$source"
  if [ -n "$DI_CONTEXT_FILE" ]; then
    printf '  context-file-in-home-dir: %s (%s, %s bytes)\n' \
      "$(basename "$DI_CONTEXT_FILE")" "$DI_CONTEXT_SHAPE" "$DI_CONTEXT_BYTES"
  else
    printf '  context-file-in-home-dir: none - this home directory holds no Pi context file\n'
  fi

  marker_state="absent - this home owns no domain identity file"
  if [ -n "$DI_OVERRIDE" ]; then
    if [ -n "$DI_OVERRIDE_MARKER" ]; then
      marker_state="present - the identity marker names $DI_OVERRIDE_MARKER"
    else
      marker_state="present - the file carries no domain identity marker"
    fi
  fi
  printf '  domain-identity: %s\n' "$marker_state"

  if [ -n "$DI_ANCESTOR" ]; then
    if [ -n "$DI_ANCESTOR_MARKER" ]; then
      printf '  inherited-context: %s (%s, %s bytes) - it carries the domain identity of %s, so it is not a plain note\n' \
        "$DI_ANCESTOR" "$(di_shape "$DI_ANCESTOR")" "$(di_bytes "$DI_ANCESTOR")" "$DI_ANCESTOR_MARKER"
    else
      printf '  inherited-context: %s (%s, %s bytes) - a tool note, not a domain identity file, so this home has no domain identity of its own\n' \
        "$DI_ANCESTOR" "$(di_shape "$DI_ANCESTOR")" "$(di_bytes "$DI_ANCESTOR")"
    fi
  else
    printf '  inherited-context: none\n'
  fi

  printf '  claude-md: %s (%s bytes)\n' "$DI_CLAUDE_SHAPE" "$DI_CLAUDE_BYTES"
  if [ -f "$home/data/charter.md" ]; then
    printf '  charter: %s (present, %s bytes)\n' "$home/data/charter.md" "$(di_bytes "$home/data/charter.md")"
  else
    printf '  charter: %s (absent)\n' "$home/data/charter.md"
  fi
  printf '  head: %s (%s)\n' "$DI_HEAD" "$DI_BRANCH"
  printf '  sync: %s\n' "$DI_SYNC"
  printf '  commits-ahead-of-primary-main: %s\n' "$DI_AHEAD"
  printf '  commits-behind-primary-main: %s\n' "$DI_BEHIND"
  if [ "$DI_DIRTY" = "yes" ]; then
    printf '  dirty: yes - %s\n' "$(printf '%s\n' "$DI_DIRTY_LIST" | head -5 | tr '\n' ' ')"
  else
    printf '  dirty: no\n'
  fi
  if [ -n "$DI_OWN_UNTRACKED" ]; then
    printf '  own-artifact: %s - the untracked domain identity file\n' "$DI_OWN_UNTRACKED"
    if [ "$DI_EXCLUDED" = "yes" ]; then
      printf '  local-ignore: %s ignores /AGENTS.override.md, so the tracked-file fast-forward still sees a clean home\n' "$DI_EXCLUDE_PATH"
    elif [ -n "$DI_EXCLUDE_PATH" ]; then
      printf '  local-ignore: %s does not ignore /AGENTS.override.md, so the tracked-file fast-forward will treat this home as dirty\n' "$DI_EXCLUDE_PATH"
    else
      printf '  local-ignore: unknown - the local exclude file could not be resolved\n'
    fi
  fi
  printf '  agents-md-fingerprint: %s\n' "$DI_AGENTS_SHA"

  reasons=""
  if [ -z "$DI_OVERRIDE" ]; then
    reasons="no domain identity file"
  elif [ -z "$DI_OVERRIDE_MARKER" ]; then
    reasons="the domain identity file carries no identity marker"
  elif [ "$DI_OVERRIDE_MARKER" != "$id" ]; then
    reasons="the domain identity file names $DI_OVERRIDE_MARKER, expected $id"
  fi
  case "$DI_SYNC" in
    current) : ;;
    stale*) reasons="${reasons:+$reasons; }stale against primary main (${DI_SYNC#stale - })" ;;
    diverged*) reasons="${reasons:+$reasons; }diverged from primary main (${DI_SYNC#diverged - })" ;;
    *) reasons="${reasons:+$reasons; }the sync state is unknown (${DI_SYNC})" ;;
  esac
  if [ "$DI_DIRTY" = "yes" ]; then
    reasons="${reasons:+$reasons; }dirty worktree"
  fi
  if [ -z "$reasons" ]; then
    printf '  verdict: PASS - domain-scoped and in sync with primary main\n'
  else
    printf '  verdict: FAIL - %s\n' "$reasons"
    REASON_LOG="$REASON_LOG  $id: $reasons
"
    FAILED=1
  fi
}

# --- the slot census --------------------------------------------------------

# di_print_census: the AGENTS.md fingerprint of every firstmate-home-shaped
# slot, so a stale home that is no longer registered is still visible.
#
# The census covers the pools named after the primary home's repository, because
# those pools hold this fleet's worktree slots. A pool of another repository on
# the same host is reported as skipped, never silently dropped.
di_print_census() {
  local root pool pool_name file path label fp line count index marker
  local primary_repo skipped_pools="" skipped_count=0 seen_paths="" seen_fps=""
  local -a labels=()
  local -a fps=()
  local -a markers=()
  primary_repo=$(basename "$FM_HOME")
  if [ "${#DI_TREEHOUSE_ROOTS[@]}" -eq 0 ]; then
    printf '\ncensus: skipped - no pool root to scan\n'
    return 0
  fi
  for root in "${DI_TREEHOUSE_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    for pool in "$root"/*/; do
      [ -d "$pool" ] || continue
      pool_name=$(basename "$pool")
      case "$pool_name" in
        "$primary_repo"|"$primary_repo"-*) : ;;
        *)
          skipped_count=$((skipped_count + 1))
          if [ -n "$(find "$pool" -maxdepth 3 -name AGENTS.md -type f 2>/dev/null | head -1)" ]; then
            case "$skipped_pools" in
              *" $pool_name "*) : ;;
              *) skipped_pools="$skipped_pools $pool_name" ;;
            esac
          fi
          continue
          ;;
      esac
      while IFS= read -r file; do
        [ -n "$file" ] || continue
        path=$(dirname "$file")
        [ -d "$path/bin" ] || continue
        case "$seen_paths" in
          *" $path "*) continue ;;
        esac
        seen_paths="$seen_paths $path "
        label="${path#"$root"/}"
        fp=$(di_sha12 "$path/AGENTS.md")
        marker=""
        if [ -f "$path/.fm-secondmate-home" ]; then
          marker=$(cat "$path/.fm-secondmate-home" 2>/dev/null || printf 'unknown')
        fi
        labels+=("$label")
        fps+=("$fp")
        markers+=("$marker")
      done < <(find "$pool" -maxdepth 3 -name AGENTS.md -type f 2>/dev/null | sort)
    done
  done
  if [ "${#labels[@]}" -eq 0 ]; then
    printf '\ncensus: no firstmate-home-shaped slot found under %s\n' "${DI_TREEHOUSE_ROOTS[*]}"
    if [ -n "$skipped_pools" ]; then
      printf 'census: pools skipped because they belong to another repository: %s\n' "$skipped_pools"
    fi
    return 0
  fi
  printf '\ncensus: AGENTS.md fingerprint per firstmate-home slot in the %s pools\n' "$primary_repo"
  for fp in "${fps[@]}"; do
    case "$seen_fps" in
      *" $fp "*) : ;;
      *) seen_fps="$seen_fps $fp " ;;
    esac
  done
  for fp in $seen_fps; do
    line=""
    count=0
    for index in "${!fps[@]}"; do
      if [ "${fps[$index]}" = "$fp" ]; then
        line="$line ${labels[$index]}"
        count=$((count + 1))
      fi
    done
    printf '  %s  %s slot(s):%s\n' "$fp" "$count" "$line"
  done
  printf '  %s  the primary worktree agents.md\n' "$DI_PRIMARY_AGENTS_SHA"
  printf '  %s  the primary committed main agents.md\n' "$DI_PRIMARY_MAIN_SHA"
  if [ -n "$skipped_pools" ]; then
    printf '  pools skipped because they belong to another repository: %s\n' "$skipped_pools"
  fi
  if [ "$skipped_count" -gt 0 ]; then
    printf '  pools skipped with no firstmate home: %s\n' "$skipped_count"
  fi
  for index in "${!markers[@]}"; do
    marker="${markers[$index]}"
    [ -n "$marker" ] || continue
    case "$seen_paths" in
      *" $marker "*) : ;;
    esac
    found=no
    for id in "${DI_ID_LIST[@]}"; do
      if [ "$id" = "$marker" ]; then
        found=yes
        break
      fi
    done
    if [ "$found" = no ]; then
      DI_CENSUS_NOTES="$DI_CENSUS_NOTES $marker"
    fi
  done
  if [ -n "$DI_CENSUS_NOTES" ]; then
    printf '  seeded homes outside the registered set (a seeded marker with no meta and no registry entry):%s\n' \
      "$DI_CENSUS_NOTES"
  fi
}

# --- the domain identity file -----------------------------------------------

# di_render_override <id> <home> <scope>: the domain identity file content.
# One sentence per line, no timestamps, so a re-run is byte identical.
di_render_override() {
  local id=$1 home=$2 scope=$3
  [ -n "$scope" ] || scope="unknown, because this home has no registry scope entry"
  printf '# Domain identity for the %s secondmate home.\n' "$id"
  printf '%s %s\n' "$DI_MARKER_PREFIX" "$id"
  printf 'This home is the %s secondmate home at %s.\n' "$id" "$home"
  printf 'Its domain scope is: %s.\n' "$scope"
  printf 'The full scope text for this home is the %s entry in the primary data/secondmates.md.\n' "$id"
  printf 'Its charter is %s.\n' "$home/data/charter.md"
  printf 'This home is not the primary firstmate home.\n'
  printf "The primary's AGENTS.md and data/secondmates.md are authoritative for the fleet.\n"
}

# di_first_sentence <text>: the first sentence of a scope text.
di_first_sentence() {
  local text=$1 first
  first=$(printf '%s\n' "$text" | sed 's/\..*$//')
  [ -n "$first" ] || first="$text"
  printf '%s\n' "$first"
}

# di_apply_home <id> <home> <scope>: write the domain identity file.
di_apply_home() {
  local id=$1 home=$2 scope=$3 target content current diff_out exclude
  target="$home/AGENTS.override.md"
  content=$(di_render_override "$id" "$home" "$(di_first_sentence "$scope")")

  if [ -f "$target" ]; then
    current=$(cat "$target" 2>/dev/null || printf '')
    if [ "$current" = "$content" ]; then
      printf '  apply: unchanged - %s already holds this domain identity\n' "$target"
      return 0
    fi
    printf '  apply: the existing %s differs, so the overwrite needs --force\n' "$target"
    diff_out=$(diff -u --label "current $target" --label "proposed $target" \
      <(printf '%s\n' "$current") <(printf '%s\n' "$content") 2>&1 || true)
    if [ -n "$diff_out" ]; then
      printf '%s\n' "$diff_out"
    fi
    if [ "$FORCE" -eq 0 ]; then
      printf '  apply: refused - re-run with --force to overwrite\n'
      FAILED=1
      return 1
    fi
  else
    if [ "$DI_SYNC" != "current" ] || [ "$DI_DIRTY" = "yes" ]; then
      printf '  apply: refusing to write into a home that is not clean and current\n'
      printf '  apply: sync: %s\n' "$DI_SYNC"
      printf '  apply: dirty: %s\n' "$DI_DIRTY"
      if [ "$FORCE" -eq 0 ]; then
        printf '  apply: refused - re-run with --force to write anyway\n'
        FAILED=1
        return 1
      fi
    fi
  fi

  if [ ! -w "$home" ]; then
    printf '  apply: error - %s is not writable\n' "$home"
    FAILED=1
    return 1
  fi
  if ! printf '%s\n' "$content" > "$target"; then
    printf '  apply: error - could not write %s\n' "$target"
    FAILED=1
    return 1
  fi
  printf '  apply: wrote %s\n' "$target"

  if exclude=$(di_git "$home" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null || printf ''); then
    if [ -n "$exclude" ]; then
      if [ ! -f "$exclude" ]; then
        if ! mkdir -p "$(dirname "$exclude")" 2>/dev/null; then
          printf '  apply: warning - could not create %s\n' "$exclude"
          return 0
        fi
        : > "$exclude" 2>/dev/null || true
      fi
      if grep -q '^/AGENTS\.override\.md$' "$exclude" 2>/dev/null; then
        printf '  apply: the local ignore is already present in %s\n' "$exclude"
      elif printf '/AGENTS.override.md\n' >> "$exclude" 2>/dev/null; then
        printf '  apply: the local ignore /AGENTS.override.md was added to %s\n' "$exclude"
      else
        printf '  apply: warning - could not add the local ignore to %s\n' "$exclude"
      fi
    fi
  fi
  return 0
}

# --- run --------------------------------------------------------------------

PRIMARY_MAIN="unknown"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-}"
PI_AGENT_DIR_FILES=""
declare -a DI_TREEHOUSE_ROOTS=()

di_assert_only_guarded_git || exit 2

if [ -z "$PI_AGENT_DIR" ]; then
  if [ -n "${HOME:-}" ]; then
    PI_AGENT_DIR="$HOME/.pi/agent"
  else
    PI_AGENT_DIR="unknown"
  fi
fi
if [ -d "$PI_AGENT_DIR" ]; then
  for name in AGENTS.override.md AGENTS.md AGENTS.MD CLAUDE.md CLAUDE.MD SYSTEM.md APPEND_SYSTEM.md; do
    if [ -f "$PI_AGENT_DIR/$name" ]; then
      PI_AGENT_DIR_FILES="$PI_AGENT_DIR_FILES $name"
    fi
  done
  PI_AGENT_DIR_FILES="${PI_AGENT_DIR_FILES# }"
fi

if [ -n "${FM_TREEHOUSE_ROOTS:-}" ]; then
  IFS=':' read -r -a DI_TREEHOUSE_ROOTS <<< "$FM_TREEHOUSE_ROOTS"
elif [ -n "${HOME:-}" ]; then
  DI_TREEHOUSE_ROOTS=("$HOME/.treehouse")
else
  DI_TREEHOUSE_ROOTS=()
fi

if di_git "$FM_HOME" rev-parse --git-dir >/dev/null 2>&1; then
  PRIMARY_MAIN=$(di_git "$FM_HOME" rev-parse --verify --quiet "refs/heads/main^{commit}" 2>/dev/null || printf 'unknown')
fi
[ -n "$PRIMARY_MAIN" ] || PRIMARY_MAIN="unknown"

di_print_primary

di_discover_homes

HOME_COUNT=0
for index in "${!DI_ID_LIST[@]}"; do
  id="${DI_ID_LIST[$index]}"
  home="${DI_HOME_LIST[$index]}"
  source_tokens="${DI_SOURCE_LIST[$index]}"
  source="$source_tokens"
  scope="${DI_SCOPE_LIST[$index]}"
  if [ -n "$ONLY_HOME" ] && [ "$ONLY_HOME" != "$id" ]; then
    continue
  fi
  case " $source " in
    *" meta "*) source="state/<id>.meta (kind=secondmate)" ;;
    *) source="" ;;
  esac
  case " $source_tokens " in
    *" registry "*)
      if [ -n "$source" ]; then
        source="$source and data/secondmates.md registry"
      else
        source="data/secondmates.md registry"
      fi
      ;;
  esac
  [ -n "$source" ] || source="unknown"
  if [ -z "$home" ]; then
    printf '\nhome %s\n' "$id"
    printf '  registered-by: %s\n' "$source"
    printf '  verdict: FAIL - no home path is recorded for this secondmate\n'
    REASON_LOG="$REASON_LOG  $id: no home path is recorded for this secondmate
"
    FAILED=1
    HOME_COUNT=$((HOME_COUNT + 1))
    continue
  fi
  di_print_home "$id" "$home" "$source"
  HOME_COUNT=$((HOME_COUNT + 1))
  if [ "$APPLY" -eq 1 ]; then
    di_apply_home "$id" "$home" "$scope"
  fi
done

if [ "$HOME_COUNT" -eq 0 ] && [ -n "$ONLY_HOME" ]; then
  printf '\ndomain-identity: no registered home with the id %s\n' "$ONLY_HOME"
  exit 2
fi

di_print_census

printf '\n'
if [ "$HOME_COUNT" -eq 0 ]; then
  printf 'no registered secondmate home was found\n'
  printf 'FLEET VERDICT: PASS - 0 registered homes found, nothing to attest\n'
  exit 0
fi
if [ "$FAILED" -eq 0 ]; then
  printf 'FLEET VERDICT: PASS - all %s registered home(s) are domain-scoped and in sync with primary main %s\n' \
    "$HOME_COUNT" "$PRIMARY_MAIN"
  exit 0
fi
printf 'FLEET VERDICT: FAIL - at least one registered home is not domain-scoped or not in sync\n'
printf '%s' "$REASON_LOG"
exit 1
