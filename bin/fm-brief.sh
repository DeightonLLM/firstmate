#!/usr/bin/env bash
# Scaffold a crewmate brief or persistent secondmate charter at
# data/<task-id>/brief.md under the active firstmate home.
# For ordinary tasks, the standard Setup/Rules/Definition-of-done contract is
# filled in. Firstmate then replaces the {TASK} placeholder with the task
# description, acceptance criteria, and context, and may adjust other sections
# when the task genuinely deviates (e.g. working an existing external PR instead
# of shipping a new one).
# Usage: fm-brief.sh <task-id> <repo-name> [--scout] [--herdr-lab] [--harness <name>] [--worklocation <absolute-path>]
#        fm-brief.sh <task-id> --secondmate {<project>...|--no-projects}
#   --scout writes the scout contract instead: the deliverable is a report at
#   data/<task-id>/report.md (no branch, no push, no PR) and the worktree is scratch.
#   --secondmate writes a persistent secondmate charter. The project list
#   is cloned into the secondmate home, while the natural-language scope
#   tells the main firstmate when to route work there; routine churn stays in its own home;
#   captain-relevant escalations and marked from-firstmate replies append to this
#   home's status file.
#   --no-projects writes a project-less charter for a domain whose subject is the
#   firstmate repo itself (its home is a firstmate worktree, its crews take pooled
#   worktrees of the same repo). It is mutually exclusive with a project list, and
#   omitting both still fails loudly so an accidental omission is never silent.
#   Set FM_SECONDMATE_CHARTER='<charter>' to fill the charter text.
#   Set FM_SECONDMATE_SCOPE='<scope>' to write a routing scope distinct from the charter text.
#   --worklocation <absolute-path> explicitly authorizes a ship or scout brief to
#   operate in an existing external directory, amending only its normal location
#   assertion; the brief names that directory and keeps every other boundary.
#   --herdr-lab is mandatory when the task will issue Herdr lifecycle commands.
#   It adds the hard isolation contract backed by bin/fm-herdr-lab.sh.
#   The flag must be explicit because {TASK} is filled after scaffolding and the
#   caller-supplied repo string cannot reliably identify this repo. Briefs made
#   without it carry a loud declaration so an omitted contract cannot be silent.
#   --harness names the harness this brief is scaffolded for, so a
#   capability-gated mandate picks the variant that harness can actually satisfy.
#   It defaults to the effective crewmate harness resolved by bin/fm-harness.sh
#   crew - the same resolution fm-spawn.sh uses for an unflagged crewmate spawn.
#   Pass it explicitly whenever the spawn will use its own --harness, an adapter
#   profile, or a raw launch command.
# For ship tasks, the definition of done is shaped by the project's delivery mode
# (data/projects.md via fm-project-mode.sh; see the project-management skill
# and AGENTS.md task lifecycle):
#   no-mistakes  implement -> /no-mistakes pipeline -> PR -> captain merge (default)
#   direct-PR    implement -> push + open PR via gh-axi (no pipeline) -> captain merge
#   local-only   implement on branch, stop and report "ready in branch" (no push/PR);
#                captain approves, firstmate merges to local main
# Ship briefs begin with a worktree-isolation assertion before the branch step.
# Scout tasks ignore mode - their deliverable is a report, not a merge.
# Every scaffold's status protocol distinguishes the configured
# declared-external-wait verb (FM_CLASSIFY_PAUSED_VERB, default "paused") from
# "blocked:": pause for a known external wait expected to clear on its own,
# blocked when firstmate must act.
# Ship tasks include a project-memory section so durable project-intrinsic
# learnings can be committed to AGENTS.md through the project's delivery path;
# it carries the AGENTS.md authoring bar (widely useful knowledge only, pointers
# over copied detail) and has the crewmate add the fm-ensure-agents-md.sh
# self-governance section when a touched project AGENTS.md lacks it.
# Refuses to overwrite an existing brief.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "$0"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

# shellcheck source=bin/fm-marker-lib.sh
. "$SCRIPT_DIR/fm-marker-lib.sh"
# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"
# shellcheck source=bin/fm-baseline-lib.sh
. "$SCRIPT_DIR/fm-baseline-lib.sh"
PAUSED_VERB=${FM_CLASSIFY_PAUSED_VERB:-$FM_CLASSIFY_PAUSED_VERB_DEFAULT}


resolve_directory_input() {
  local name=$1 path=$2 resolved
  case "$path" in
    /*) printf '%s\n' "$path"; return 0 ;;
  esac
  resolved=$(CDPATH='' cd -- "$path" 2>/dev/null && pwd -P) || {
    echo "error: $name directory cannot be resolved: $path" >&2
    return 1
  }
  printf '%s\n' "$resolved"
}

FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME=$(resolve_directory_input FM_HOME "${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}") || exit 1
if [ -n "${FM_DATA_OVERRIDE:-}" ]; then
  DATA=$(resolve_directory_input FM_DATA_OVERRIDE "$FM_DATA_OVERRIDE") || exit 1
else
  DATA="$FM_HOME/data"
fi
if [ -n "${FM_STATE_OVERRIDE:-}" ]; then
  STATE=$(resolve_directory_input FM_STATE_OVERRIDE "$FM_STATE_OVERRIDE") || exit 1
else
  STATE="$FM_HOME/state"
fi
KIND=ship
HERDR_LAB=0
NO_PROJECTS=0
HARNESS_ARG=""
WORKLOCATION_ARG=""
POS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --scout) KIND=scout ;;
    --secondmate) KIND=secondmate ;;
    --herdr-lab) HERDR_LAB=1 ;;
    --no-projects) NO_PROJECTS=1 ;;
    --worklocation)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { echo "error: --worklocation requires an absolute directory path" >&2; exit 1; }
      WORKLOCATION_ARG=$2; shift ;;
    --harness)
      [ "$#" -ge 2 ] || { echo "error: --harness requires a value" >&2; exit 1; }
      HARNESS_ARG=$2; shift ;;
    --harness=*) HARNESS_ARG=${1#--harness=} ;;
    *) POS+=("$1") ;;
  esac
  shift
done
ID=${POS[0]}

if [ -n "$WORKLOCATION_ARG" ]; then
  case "$WORKLOCATION_ARG" in
    /*) ;;
    *) echo "error: --worklocation requires an absolute directory path" >&2; exit 1 ;;
  esac
  [ -d "$WORKLOCATION_ARG" ] || { echo "error: --worklocation directory does not exist: $WORKLOCATION_ARG" >&2; exit 1; }
  WORKLOCATION=$(resolve_directory_input worklocation "$WORKLOCATION_ARG") || exit 1
else
  WORKLOCATION=""
fi

if [ "$KIND" = secondmate ] && [ -n "$WORKLOCATION" ]; then
  echo "error: --worklocation applies only to crewmate ship or scout briefs" >&2
  exit 1
fi

if [ "$KIND" = secondmate ] && [ "$HERDR_LAB" -eq 1 ]; then
  echo "error: --herdr-lab applies only to crewmate ship or scout briefs" >&2
  exit 1
fi

if [ "$NO_PROJECTS" -eq 1 ] && [ "$KIND" != secondmate ]; then
  echo "error: --no-projects applies only to --secondmate charters" >&2
  exit 1
fi

# Append the deterministic fresh-agent baseline block that fm-session-start.sh
# enforces and tests/fm-fresh-baseline.test.sh asserts. Without it the CANONICAL
# brief generator produces briefs that fail the very contract the fleet gates on,
# which forces firstmate to hand-write briefs and trips the intent guard.
# Fail-closed: a missing required baseline file must abort brief generation.
# Validate the baseline BEFORE any brief is written, so a missing required file
# aborts generation instead of leaving a half-valid brief on disk.
prepare_baseline() {
  BASELINE_TMP="$(mktemp "${TMPDIR:-/tmp}/fm-brief-baseline.XXXXXX")" || return 2
  emit_baseline_block
}

emit_baseline_block() {
  local file digest role resolved
  local warehouse_file warehouse_preflight_file baseline_root warehouse_digest
  local -a required

  baseline_root="${FM_BASELINE_ROOT:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
  baseline_root="$(cd "$baseline_root" 2>/dev/null && pwd -P)" || {
    printf 'brief: FAIL fresh-agent baseline root is unavailable\n' >&2
    return 2
  }
  warehouse_file="$baseline_root/docs/system-context/INDEX.md"
  warehouse_preflight_file="$baseline_root/bin/fm-context-preflight.sh"
  required=("$warehouse_file" "$warehouse_preflight_file")
  for file in "${required[@]}"; do
    if [ ! -f "$file" ]; then
      printf 'brief: FAIL required fresh-agent baseline file is missing: %s\n' "$file" >&2
      return 2
    fi
    digest="$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)" || {
      printf 'brief: FAIL cannot hash required fresh-agent baseline file: %s\n' "$file" >&2
      return 2
    }
    [ -n "$digest" ] || { printf 'brief: FAIL SHA-256 tool unavailable\n' >&2; return 2; }
    if [ "$file" = "$warehouse_file" ]; then
      warehouse_digest="sha256:$digest"
    fi
  done

  {
    printf '# Fresh-agent baseline\n'
    printf 'Baseline manifest: fresh-agent-baseline/v1\n'
    # The policy-family roles resolve from this home, so a brief is never
    # pointed at another host's account home. A role with no readable home-local
    # file is declared unavailable instead of being dropped or mislabeled.
    for role in policy project-policy routing bounded lean-ctx; do
      if ! resolved="$(fm_baseline_resolve_role "$role")"; then
        fm_baseline_unavailable_line "$role"
        continue
      fi
      digest="$(sha256sum "$resolved" 2>/dev/null | cut -d' ' -f1)" || {
        printf 'brief: FAIL cannot hash required fresh-agent baseline file: %s\n' "$resolved" >&2
        return 2
      }
      [ -n "$digest" ] || { printf 'brief: FAIL SHA-256 tool unavailable\n' >&2; return 2; }
      printf '%s=%s scope=%s sha256:%s\n' "$role" "$resolved" "$(fm_baseline_scope_of "$resolved")" "$digest"
    done
    printf 'warehouse=%s %s\n' "$warehouse_file" "$warehouse_digest"
    printf 'warehouse-preflight=%s\n' "$warehouse_preflight_file"
    printf 'goal-queue=%s/data/backlog.md\n' "$FM_HOME"
    printf 'state-handoff=%s/state/.wake-queue\n' "$FM_HOME"
    printf 'Read pointers and hashes above; do not paste or inherit prior conversation history.\n'
  } > "$BASELINE_TMP"
}

# --- Harness capability gate ---------------------------------------------------
# A mandate the target harness physically cannot satisfy is a wedge, not a safety
# net: the crewmate reports `blocked:` on first contact and the captain watches a
# lane that stops every tick. The mandatory task breakdown is therefore selected
# from an explicit capability set instead of being hardcoded, keyed by harness name
# rather than by model name or a match on the CLI path. Promoting a harness into
# this list requires recorded verification evidence that it provides a To-Do List
# extension; anything unlisted, unknown, or passed as a raw launch command resolves
# to the fallback discipline below, which is never the impossible mandate.
# Evidence per entry:
#   claude            native To-Do List extension (Claude Code).
#   pi, pi-signed     pi.dev extension lineage; mcode is a documented pi.dev fork
#                     whose To-Do List extension is verified in
#                     docs/supervision-protocols/minimax-code.md.
#   grok              Claude-Code-compatible CLI (documented in fm-harness.sh), so
#                     the same extension.
#   minimax-code      verified in docs/supervision-protocols/minimax-code.md.
# Deliberately NOT listed, so NOT mandated:
#   agy               the Antigravity/Gemini CLI. A dispatched agy crewmate was
#                     observed asking to show a To-Do list it cannot produce
#                     (2026-10-11), which is this gate's reason to exist.
#   codex, opencode, kimi, and every unknown/raw-launch harness: no To-Do List
#                     extension is verified for them anywhere in this repo.
FM_HARNESS_TODO_LIST="claude grok minimax-code pi pi-signed"

harness_supports_todo_list() {
  case " $FM_HARNESS_TODO_LIST " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- lean-ctx status transport -------------------------------------------------
# The native `echo "{state}: {one short line}" >> <status file>` append is the
# default status transport. A harness whose shell is mediated by lean-ctx replace
# mode cannot use it: the lean-ctx PreToolUse hook denies native Bash commands
# that are not on its allowlist, so the append never runs, the lane writes no
# status event, and firstmate cannot see whether the lane is alive. A denied
# mandate is a wedge, not a safety net, so the brief must name a transport the
# lane can actually use. The honest fix keeps the same command and changes only
# the transport - route it through the lean-ctx MCP `ctx_shell` tool - and puts
# that exact call in the brief so the lane complies without guessing.
#
# Replace mode is host state, not repo state: the host's own harness integration
# registers the deny hook and the MCP server that publishes ctx_shell. The probe
# below reads that registration read-only. A host that registers neither keeps
# the ordinary native transport, so a brief never names a tool the lane lacks.
#
# Evidence per entry:
#   codex   the lean-ctx PreToolUse hook is registered for the Bash|Read|Grep|Glob
#           matcher in the codex host hook file, and the lean-ctx MCP server that
#           publishes ctx_shell is registered for the same host.
# Deliberately NOT listed: every other verified harness (claude, opencode, pi,
# pi-signed, grok, kimi, agy, minimax-code). None of them is mediated by
# lean-ctx replace mode, so their briefs keep the native transport unchanged.
FM_HARNESS_LEAN_CTX_REPLACE="codex"

harness_in_lean_ctx_replace_set() {
  case " $FM_HARNESS_LEAN_CTX_REPLACE " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Read-only probe of the host's harness integration for the target harness.
# Returns 0 only when that harness's shell is actually mediated by lean-ctx
# replace mode AND the MCP server that publishes ctx_shell is registered for it.
lean_ctx_replace_mode_active() {
  case "$1" in
    codex)
      local codex_home hooks_file config_file
      codex_home="${CODEX_HOME:-$HOME/.codex}"
      hooks_file="$codex_home/hooks.json"
      config_file="$codex_home/config.toml"
      [ -r "$hooks_file" ] || return 1
      [ -r "$config_file" ] || return 1
      grep -q "codex-pretooluse" "$hooks_file" 2>/dev/null || return 1
      grep -q "mcp_servers\.lean-ctx" "$config_file" 2>/dev/null || return 1
      grep -q "ctx_shell" "$config_file" 2>/dev/null || return 1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Which harness is this brief written for? An explicit --harness wins; otherwise
# defer to bin/fm-harness.sh, the harness detection authority, using the same
# crew resolution fm-spawn.sh applies to an unflagged crewmate spawn.
BRIEF_HARNESS=$HARNESS_ARG
if [ -z "$BRIEF_HARNESS" ]; then
  BRIEF_HARNESS=$("$FM_ROOT/bin/fm-harness.sh" crew 2>/dev/null || true)
  BRIEF_HARNESS=$(printf '%s' "$BRIEF_HARNESS" | tr -d '[:space:]')
fi
[ -n "$BRIEF_HARNESS" ] || BRIEF_HARNESS=unknown

# Captain-locked prefix requirement; change this one assignment if the format changes.
TODO_PREFIX_REQUIREMENT='Each item must begin at the far left with [<harness>·<ModelAbbrev> <effort> @<Host>], before any state verb or task text. Use bare effort codes h, m, l, xh, or x; omit effort only when the runtime exposes none. See data/captain.md for supported codes and host mappings. The @Host tag names where the agent runs, never what it works on; put the work target in task text.'

# Emit the mandatory task breakdown this harness can actually carry. Both variants
# name the harness and say which requirement applies, so a reading agent is never
# left guessing whether it owes a five-item To-Do tracker.
emit_todo_breakdown() {
  if harness_supports_todo_list "$BRIEF_HARNESS"; then
    IFS= read -r -d '' TODO_BREAKDOWN <<EOF || true
# Mandatory task breakdown
This requirement applies to you because your harness (\`$BRIEF_HARNESS\`) provides the To-Do List extension.
Before any investigation, edit, test, or other task action, use the harness's
To-Do List extension and create an in-depth dependency-aware tracker with at
least five checkable items: preflight, scoped discovery, bounded work/evidence,
validation, and postflight/closeout. Keep it visible and update it at every
phase change. $TODO_PREFIX_REQUIREMENT
Do not substitute prose or a filesystem TODO file. If the extension is unavailable
or the tracker has fewer than five items, append
\`blocked: To-Do List extension unavailable or incomplete\` to the status file and
stop; firstmate must not treat the task as started.
EOF
  else
    IFS= read -r -d '' TODO_BREAKDOWN <<EOF || true
# Mandatory task breakdown
This requirement applies to you because your harness (\`$BRIEF_HARNESS\`) has no To-Do List extension. The five-item To-Do tracker mandate does NOT apply to you: do not try to produce one, and do not report yourself blocked for lacking one.
This is the equivalent discipline for your harness and it is mandatory. A stale plan is the same false statement to firstmate that a stale tracker is on a To-Do-capable harness.
1. Before any investigation, edit, test, or other task action, write your plan in your first reply as at least five markdown checkbox items (\`- [ ] \`), one line each, in dependency order: preflight, scoped discovery, bounded work/evidence, validation, postflight/closeout. firstmate reads your pane, so that reply is where the plan has to be visible.
2. $TODO_PREFIX_REQUIREMENT
3. Keep it true as you work: tick an item only once its work is actually complete, and add an item whenever scope changes. Never tick an item you have not finished.
4. Report every phase change in band: append \`working: {plan item} - {one short line}\` to the status file as you enter each plan item, exactly as rule 4 requires for any material phase change, so firstmate sees the same five phases in the status record that a To-Do-capable harness shows on its board.
EOF
  fi
  TODO_BREAKDOWN=${TODO_BREAKDOWN%$'\n'}
}
emit_todo_breakdown

BRIEF="$DATA/$ID/brief.md"
[ -e "$BRIEF" ] && { echo "error: $BRIEF already exists" >&2; exit 1; }
mkdir -p "$DATA/$ID"

shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

STATUS_FILE=$(shell_quote "$STATE/$ID.status")

# The status-report transport for this scaffold. The native append is the
# default. A lean-ctx-replace-mode harness gets the identical command routed
# through the lean-ctx MCP `ctx_shell` tool, with the exact call named so the
# lane never has to work out how to reach the append.
emit_status_append_block() {
  local harness="$1"
  if harness_in_lean_ctx_replace_set "$harness" && lean_ctx_replace_mode_active "$harness"; then
    IFS= read -r -d '' STATUS_APPEND_BLOCK <<'EOF' || true
   Report status through the lean-ctx MCP `ctx_shell` tool, not native Bash: your harness runs in lean-ctx replace mode, where the lean-ctx PreToolUse hook DENIES native Bash commands that are not on its allowlist, so a native `echo ... >>` append never runs and no status event ever lands.
   Use this exact call - same command, different transport:
   ctx_shell(command="echo \"{state}: {one short line}\" >> @STATUS_FILE@")
   Reading files and running git are unaffected: the hook rewrites allowed native commands to their lean-ctx equivalents by itself.
EOF
  else
    IFS= read -r -d '' STATUS_APPEND_BLOCK <<'EOF' || true
   `echo "{state}: {one short line}" >> @STATUS_FILE@`
EOF
  fi
  STATUS_APPEND_BLOCK=${STATUS_APPEND_BLOCK//@STATUS_FILE@/$STATUS_FILE}
  # read -r -d '' keeps the heredoc's trailing newline; drop it so the rendered
  # brief stays byte-identical to the historical Bash 5 output.
  STATUS_APPEND_BLOCK=${STATUS_APPEND_BLOCK%$'\n'}
}
if [ -n "$WORKLOCATION" ]; then
  IFS= read -r -d '' SHIP_LOCATION_SETUP <<EOF || true
You are authorized to operate in the external worklocation at \`$WORKLOCATION\` instead of the disposable task worktree.

This authorization amends only the ordinary worktree-location/isolation assertion: begin task actions in \`$WORKLOCATION\` and operate only there. It does not authorize any other path, scope, or exception; every other boundary in this brief remains in force.
EOF
  IFS= read -r -d '' SCOUT_LOCATION_SETUP <<EOF || true
You are authorized to operate in the external worklocation at \`$WORKLOCATION\` instead of the disposable task worktree.

This authorization amends only the ordinary worktree-location/isolation requirement: begin task actions in \`$WORKLOCATION\` and operate only there. It does not authorize any other path, scope, or exception; every other boundary in this brief remains in force.
EOF
  SHIP_RULE2="Stay inside the authorized worklocation at \`$WORKLOCATION\`; modify nothing outside it."
  SCOUT_RULE2="Stay inside the authorized worklocation at \`$WORKLOCATION\`; the only files you may write elsewhere are the report and status file below."
else
  IFS= read -r -d '' SHIP_LOCATION_SETUP <<'EOF' || true
You are in a disposable git worktree of @REPO@, at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run `pwd -P` and `git rev-parse --show-toplevel`; both must resolve to the disposable task worktree you were launched in, such as a treehouse pool path or an Orca-managed worktree, not the primary checkout firstmate operates from.
The path check is authoritative: `git rev-parse --git-dir` and `git rev-parse --git-common-dir` can help inspect the repo, but they do not prove you are outside the primary checkout.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append `blocked: launched in primary checkout, not an isolated worktree` to the status file and stop.
EOF
  IFS= read -r -d '' SCOUT_LOCATION_SETUP <<'EOF' || true
You are in a disposable git worktree of @REPO@, at a detached HEAD on a clean default branch.
This is a SCOUT task: the deliverable is a written report, not a PR.
The worktree is your laboratory - install, run, edit, and make scratch commits freely; all of it is discarded at teardown.
The report is the only thing that survives, so anything worth keeping must be in it.
EOF
  SHIP_RULE2="Stay inside this worktree; modify nothing outside it."
  SCOUT_RULE2="Stay inside this worktree; the only files you may write outside it are the report and the status file below."
fi
SHIP_LOCATION_SETUP=${SHIP_LOCATION_SETUP%$'\n'}
SCOUT_LOCATION_SETUP=${SCOUT_LOCATION_SETUP%$'\n'}

if [ "$KIND" = secondmate ]; then
SECONDMATE_PROJECTS=""
idx=1
while [ "$idx" -lt "${#POS[@]}" ]; do
  SECONDMATE_PROJECTS="${SECONDMATE_PROJECTS}${SECONDMATE_PROJECTS:+ }${POS[$idx]}"
  idx=$((idx + 1))
done
if [ "$NO_PROJECTS" -eq 1 ]; then
  [ -z "$SECONDMATE_PROJECTS" ] || { echo "error: --no-projects cannot be combined with a project list" >&2; exit 1; }
else
  [ -n "$SECONDMATE_PROJECTS" ] || { echo "error: --secondmate requires at least one project, or --no-projects for a project-less home" >&2; exit 1; }
fi
SECONDMATE_CHARTER=${FM_SECONDMATE_CHARTER:-"{TASK}"}
SECONDMATE_SCOPE=${FM_SECONDMATE_SCOPE:-${FM_SECONDMATE_CHARTER:-"{TASK}"}}
if [ "$NO_PROJECTS" -eq 1 ]; then
  PROJECT_CLONES_BODY="None. This is a project-less domain: its subject is the firstmate repo this home lives in, so it needs no separate clones under \`projects/\`; its crews take pooled worktrees of that firstmate repo."
  PROJECT_CLONES_NOTE="This domain has no separate project clones: its subject is the firstmate repo this home lives in, and its crews take pooled worktrees of that repo."
else
  PROJECT_CLONES_BODY=$(printf '%s\n' "$SECONDMATE_PROJECTS" | tr ' ' '\n' | sed 's/^/- /')
  PROJECT_CLONES_NOTE="The projects above are local clones for work you supervise; they are not an exclusive ownership claim."
fi


SECONDMATE_HARNESS=$("$FM_ROOT/bin/fm-harness.sh" secondmate 2>/dev/null || true)
SECONDMATE_HARNESS=$(printf '%s' "$SECONDMATE_HARNESS" | tr -d '[:space:]')
[ -n "$SECONDMATE_HARNESS" ] || SECONDMATE_HARNESS=unknown
emit_status_append_block "$SECONDMATE_HARNESS"

prepare_baseline || exit 2
cat > "$BRIEF" <<EOF
You are a persistent second mate managed by the main firstmate. Work on your own; do not wait for a human.

# Charter
$SECONDMATE_CHARTER

# Routing scope
$SECONDMATE_SCOPE

# Project clones
$PROJECT_CLONES_BODY

# Operating model
You are in an isolated firstmate home. The local \`AGENTS.md\` is your job description, and your local \`data/\`, \`state/\`, \`config/\`, and \`projects/\` dirs are yours to operate.
$PROJECT_CLONES_NOTE
Delegate project work to your own crewmates with the normal firstmate lifecycle: brief, spawn, status, watcher, steer, teardown, and recovery.
Do not invent a second delegation system.
You do not generate your own work.
Act only on tasks the main firstmate routes to you.
Never start a survey, audit, or "find improvements" sweep on your own initiative; that is not your job and it is unwanted.

# Requests from the main firstmate
You are a firstmate in your own home, so an incoming message reaches you in your own chat.
You must distinguish who it is from, because the answer goes to a different place.
A request relayed to you by the main firstmate is tagged with a leading \`$FM_FROMFIRST_LABEL\` marker followed by an invisible system separator; this marker is untypable, so a human never produces it.
When a message carries that marker, do the work, then respond via the STATUS/ESCALATION path below, never only in this chat: the main firstmate does not read your chat, so a chat-only reply is lost.
Marked requests also carry a privacy-safe \`corr=<id>\` token after the marker; include that exact token in your parent status reply (or in the status pointer to a detailed doc) so the parent can correlate the answer.
Optional helper: \`bin/fm-secondmate-report.sh\` can append a correlated status line for you, but a plain \`echo\` that includes the same \`corr=<id>\` is equally valid - do not depend on the helper being present.
For a terse result, a status line is the whole answer.
For a detailed answer (an investigation, a plan, an audit), write it to a doc under your home's \`data/\` and append a status line that points to that doc - the scout-report pattern - so the main firstmate is woken and can read it.
Before treating an investigation or visual review as complete, load \`decision-hold-lifecycle\` from this home's \`.agents/skills/\` and pass its shared completion gate.
A message with NO marker is the captain typing directly into your pane: treat it as authoritative captain intervention and stay conversational exactly as you would for any captain message; do not force it onto the status path.

# Escalation to main firstmate
Handle routine work yourself.
Report only true captain-relevant outcomes or a declared external wait by appending one line:
$STATUS_APPEND_BLOCK
States: working, needs-decision, blocked, $PAUSED_VERB, done, failed.
Use \`$PAUSED_VERB: {why}\` (distinct from \`blocked:\`) only when your domain is deliberately idling on a known external wait you expect to clear on its own; use \`blocked:\` when you are stuck and need firstmate to act.
Use this only for material phase changes, a captain decision, a real blocker, a failure, or work ready for review.
This is also how you return the answer to a marked from-firstmate request above.
A marked request requires one correlated answer after the work; it does not require a separate receipt or start acknowledgement.
Never append \`working:\` merely to acknowledge receipt or announce that a marked request has started.
When a routed-work phase has a supervisor-actionable material change worth reporting under the rule above, give that reported phase a stable key.
If its first reportable event is \`working [key=<work-slug>]: {material phase}\`, use the same key on its later \`$PAUSED_VERB\`, \`done\`, \`failed\`, \`needs-decision\`, or \`blocked\` event so the earlier working phase is superseded.
When a keyed phase ends without another reportable state, append \`resolved [key=<work-slug>]: {why it is no longer active}\`.
When a decision you escalated is answered or a blocker clears and your domain resumes, append \`resolved: {how it was decided or unblocked}\` (keyed with \`[key=<slug>]\` if you opened it with one) so it is durably closed instead of resurfacing behind later unrelated events.
Routine internal supervision, heartbeats, retries, and crewmate churn stay inside your own home and must not touch that status file.

# Definition of done
You are persistent by default. Do not exit just because your queue is empty.
On startup and restart, run normal firstmate bootstrap and recovery through \`bin/fm-session-start.sh\` for your own home, but only to RECONCILE work that is already yours: in-flight crewmates, tracked backlog items, and durable watches recorded in this home.
When you have no assigned or in-flight work after that reconciliation, go idle and wait silently for the main firstmate to route you a task.
An empty queue is a healthy resting state, not a cue to invent work: never spawn a survey, audit, or any self-directed "find work" task on your own initiative.
If this charter cannot be carried out, append \`blocked: {why}\` or \`failed: {why}\` to the main status file and stop.
EOF
if [ "$SECONDMATE_CHARTER" = "{TASK}" ]; then
  cat "$BASELINE_TMP" >> "$BRIEF" || exit 2
rm -f "$BASELINE_TMP"
  echo "scaffolded: $BRIEF (secondmate charter; replace {TASK})"
else
  cat "$BASELINE_TMP" >> "$BRIEF" || exit 2
rm -f "$BASELINE_TMP"
  echo "scaffolded: $BRIEF (secondmate charter)"
fi
exit 0
fi

REPO=${POS[1]}
SHIP_LOCATION_SETUP=${SHIP_LOCATION_SETUP//@REPO@/$REPO}
SCOUT_LOCATION_SETUP=${SCOUT_LOCATION_SETUP//@REPO@/$REPO}

if [ "$HERDR_LAB" -eq 1 ]; then
HERDR_LAB_HELPER=$(shell_quote "$FM_ROOT/bin/fm-herdr-lab.sh")
# shellcheck disable=SC2016  # single quotes are deliberate: these lines are literal brief text whose backtick-wrapped $(...) and "$HERDR_LAB_SESSION" snippets must reach the reading agent verbatim, not expand at scaffold time; only the '"$VAR"' break-outs interpolate.
HERDR_SECTION=$(printf '%s\n' \
'# Herdr isolation - HARD SAFETY CONTRACT' \
'This brief was explicitly scaffolded with `--herdr-lab` because the task will drive Herdr lifecycle behavior.' \
'On Herdr 0.7.3 the API socket is not relocatable by `HERDR_CONFIG_PATH`, `XDG_CONFIG_HOME`, or `HOME`.' \
'A named non-`default` session plus a trailing `--session <name>` on every call is the only viable local isolation.' \
'' \
'1. Set `HERDR_LAB_HELPER='"$HERDR_LAB_HELPER"'` and generate the session name with `HERDR_LAB_SESSION=$("$HERDR_LAB_HELPER" name '"$ID"')`.' \
'   Install `trap '\''"$HERDR_LAB_HELPER" teardown "$HERDR_LAB_SESSION"'\'' EXIT` before provisioning, then provision only with `"$HERDR_LAB_HELPER" provision "$HERDR_LAB_SESSION"`.' \
'2. Run every task-specific non-lifecycle Herdr command through `"$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" <arguments...>`.' \
'   The helper appends the required trailing `--session "$HERDR_LAB_SESSION"`; `HERDR_SESSION` alone is never accepted as isolation.' \
'3. Teardown only through `"$HERDR_LAB_HELPER" teardown "$HERDR_LAB_SESSION"`.' \
'   It re-checks refuse-default immediately before stop and again immediately before delete, and fails closed on ambiguity.' \
'4. If an experiment requires a deliberate mid-run session stop, use only `"$HERDR_LAB_HELPER" stop "$HERDR_LAB_SESSION"`; it performs the same immediate refuse-default check.' \
'5. Forbidden commands: direct `herdr server stop`, every other server-global operation such as `herdr server live-handoff` or reload/update operations, direct `herdr session stop`, direct `herdr session delete`, and any Herdr call scoped only by ambient or inline `HERDR_SESSION`.' \
'6. The helper records the live default session before provisioning and verifies the identical fleet state after teardown.' \
'   A missing, stopped, or changed default session is a hard tripwire failure, never a cleanup warning to ignore.' \
'' \
'Never bypass the helper, even for a read-only lifecycle probe or cleanup after failure.' \
'The captain fleet uses the running `default` session.')
else
IFS= read -r -d '' HERDR_SECTION <<'EOF' || true
# Herdr lifecycle declaration - NOT ENABLED
**HARD SAFETY GATE:** this scaffold cannot inspect the task text that replaces `{TASK}` later.
If the task will start, stop, delete, restart, profile, or otherwise drive Herdr lifecycle behavior, stop and regenerate the brief with `--herdr-lab` before dispatch.
Do not add Herdr lifecycle commands to this unguarded brief by hand.
EOF
HERDR_SECTION=${HERDR_SECTION%$'\n'}
fi

if [ "$KIND" = scout ]; then
emit_status_append_block "$BRIEF_HARNESS"
prepare_baseline || exit 2
cat > "$BRIEF" <<EOF
You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
{TASK}

$HERDR_SECTION

# Setup
$SCOUT_LOCATION_SETUP

$TODO_BREAKDOWN

# Rules
1. Never push to any remote and never open a PR.
2. $SCOUT_RULE2
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
$STATUS_APPEND_BLOCK
   States: working, needs-decision, blocked, $PAUSED_VERB, done, failed.
   Each append wakes firstmate, so report sparingly: only phase changes a supervisor
   would act on and the needs-decision/blocked/paused/done/failed states. No step-by-step
   FYI progress lines; firstmate reads your pane for that.
   Staying VISIBLE is enforced in code, not merely requested here: a live crewmate that has
   appended nothing for longer than FM_CREW_VISIBILITY_STALE_SEC (default 1800s), or has never
   appended anything within FM_CREW_VISIBILITY_GRACE_SEC (default 300s) of its spawn, raises a
   \`crew-silent\` breach naming you and the elapsed silence straight to the captain
   (bin/fm-crew-visibility.sh, checked by the watcher on every cycle). So re-append a \`working:\`
   line whenever a phase runs long - the watcher absorbs those as benign, so they cost the
   captain nothing, and they are exactly what keeps you readable. A declared \`$PAUSED_VERB: {why}\`
   for an external wait ends that obligation; going quiet never does.
   Use \`$PAUSED_VERB: {why}\` - distinct from \`blocked:\` - ONLY when you are deliberately idling on a
   known external wait you expect to clear on its own (an upstream release, a rate-limit reset):
   firstmate then leaves your idle pane alone and rechecks it on a long cadence instead of
   treating it as a possible wedge. Use \`blocked:\` when you are stuck and need help.
5. If you hit the same obstacle twice, append \`blocked: {why}\` and stop; firstmate will help.
6. If a decision belongs to a human (product choices, destructive actions),
   append \`needs-decision: {summary of options}\` and stop. Firstmate will reply with the decision.
   When firstmate replies or a blocker clears and you resume, append \`resolved: {how it was decided or unblocked}\` (add the same \`[key=<slug>]\` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
7. Never stop, restart, or update the shared \`no-mistakes\` daemon - it is one instance serving
   every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
   daemon error, append \`blocked: {the daemon error}\` and stop; only firstmate manages the daemon.

# Definition of done
Write your findings to \`$DATA/$ID/report.md\`.
The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
Before reporting done, read and follow \`$FM_ROOT/.agents/skills/decision-hold-lifecycle/SKILL.md\` and pass its shared completion gate for the report and any visual review.
When the report is complete, append \`done: {one-line conclusion}\` to the status file and stop.
If your findings reveal work that should ship (e.g. you reproduced a bug and the fix is clear), say so in the report; firstmate may promote this task in place, and you would then receive mode-specific ship instructions as a follow-up message.
EOF
cat "$BASELINE_TMP" >> "$BRIEF" || exit 2
rm -f "$BASELINE_TMP"
echo "scaffolded: $BRIEF (scout; replace {TASK})"
exit 0
fi

# Ship task: shape Setup / Rule 1 / Definition of done by the project's delivery mode.
# yolo does not affect the brief because the worker never owns approval decisions;
# firstmate applies the authority contract in AGENTS.md section 7, so discard it.
read -r MODE _ <<EOF
$("$FM_ROOT/bin/fm-project-mode.sh" "$REPO")
EOF

case "$MODE" in
  direct-PR)
    SETUP2=""
    RULE1='1. Never push to the default branch (push only your `fm/'"$ID"'` branch). Never merge a PR.'
    IFS= read -r -d '' DOD <<EOF || true
# Definition of done
This project ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch and open a PR with \`gh-axi\`, then append \`done: PR {url}\` to the status file and stop.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.
EOF
    ;;
  local-only)
    SETUP2=""
    RULE1="1. Never push to any remote and never open a PR. Work only on your \`fm/$ID\` branch; firstmate handles the merge into local \`main\`."
    IFS= read -r -d '' DOD <<EOF || true
# Definition of done
This project ships **local-only**: no remote, no PR, no pipeline.
The task is complete only when committed on your branch \`fm/$ID\`. Do NOT push, do NOT open a PR, do NOT merge.
Keep your branch a clean fast-forward onto the current default branch - if \`main\` has advanced, rebase onto it so the eventual merge stays a fast-forward.
When it is implemented and committed, append \`done: ready in branch fm/$ID\` to the status file and stop.
The configured merge authority approves the ready branch, then firstmate merges it into local \`main\` through the guarded fast-forward path.
EOF
    ;;
  *)  # no-mistakes (default)
    SETUP2="
2. Run \`no-mistakes doctor\`; if it reports the repo is not initialized here, run \`no-mistakes init\`."
    RULE1='1. Never push to the default branch. Never merge a PR.'
    IFS= read -r -d '' DOD <<EOF || true
# Definition of done
The task is complete only when committed on your branch.
When you believe it is complete, append \`done: {summary}\` to the status file and stop.
Firstmate will then instruct you to run /no-mistakes to validate and ship a PR.

You drive no-mistakes by responding to its gates, not by implementing fixes.
Follow the guidance no-mistakes itself provides for the mechanics: it loads when you invoke /no-mistakes, and \`no-mistakes axi run --help\` plus the \`help\` lines in each \`axi\` response are authoritative and version-matched to the installed binary.
When starting no-mistakes, make \`--intent\` preserve all relevant content from this brief's \`# Task\` section plus every later accepted Firstmate requirement, clarification, constraint, exclusion, and supersession, carrying only each requirement's current accepted form; retain direct requirements instead of substituting a diff summary, and exclude generic operational, status, delivery, and other scaffold boilerplate unless it is task-specific.
Do not hand-edit, commit, or fix findings yourself while a run is active - the pipeline applies every fix.

Two firstmate-specific rules layer on top of that guidance:
- ask-user findings are never yours to answer: escalate to firstmate (rule 6) and stop.
  Firstmate applies the authority contract in its \`AGENTS.md\` and obtains any required captain decision.
  When the decision comes back, feed it to the gate with \`no-mistakes axi respond\` and let the pipeline apply it - do not route the question to "the user" or implement the fix yourself.
- Avoid \`--yes\`: it would silently bypass firstmate's authority check and any required captain escalation.

After /no-mistakes reports CI green (the CI-ready return point - do not wait for it to keep monitoring in the background until merge), append \`done: PR {url} checks green\` and stop. You are finished.
EOF
    ;;
esac

# read -r -d '' preserves the heredoc's trailing newline that the removed
# $(...) command substitution used to strip. Drop that one newline so generated
# briefs stay byte-identical to the historical Bash 5 output.
DOD=${DOD%$'\n'}

emit_status_append_block "$BRIEF_HARNESS"

prepare_baseline || exit 2
cat > "$BRIEF" <<EOF
You are a crewmate: an autonomous worker agent managed by firstmate. Work on your own; do not wait for a human.

# Task
{TASK}

$HERDR_SECTION

# Setup
$SHIP_LOCATION_SETUP

1. First action: create your branch: \`git checkout -b fm/$ID\`$SETUP2

$TODO_BREAKDOWN

# Rules
$RULE1
2. $SHIP_RULE2
3. Use gh-axi for GitHub operations and chrome-devtools-axi for browser operations.
4. Report status by appending one line:
$STATUS_APPEND_BLOCK
   States: working, needs-decision, blocked, $PAUSED_VERB, done, failed.
   Each append wakes firstmate, so report sparingly: only phase changes a supervisor
   would act on (setup done, bug reproduced, fix implemented, validation passed) and the
   needs-decision/blocked/paused/done/failed states. No step-by-step FYI progress lines;
   firstmate reads your pane for that.
   Staying VISIBLE is enforced in code, not merely requested here: a live crewmate that has
   appended nothing for longer than FM_CREW_VISIBILITY_STALE_SEC (default 1800s), or has never
   appended anything within FM_CREW_VISIBILITY_GRACE_SEC (default 300s) of its spawn, raises a
   \`crew-silent\` breach naming you and the elapsed silence straight to the captain
   (bin/fm-crew-visibility.sh, checked by the watcher on every cycle). So re-append a \`working:\`
   line whenever a phase runs long - the watcher absorbs those as benign, so they cost the
   captain nothing, and they are exactly what keeps you readable. A declared \`$PAUSED_VERB: {why}\`
   for an external wait ends that obligation; going quiet never does.
   A mid-task \`working:\` line (including setup complete) is nonterminal: do not end the
   turn after it; continue the same stage until a defined \`done:\` gate under Definition of done.
   Use \`$PAUSED_VERB: {why}\` - distinct from \`blocked:\` - ONLY when you are deliberately idling on a
   known external wait you expect to clear on its own (an upstream release, a rate-limit reset,
   a scheduled window): firstmate then leaves your idle pane alone and rechecks it on a long
   cadence instead of treating it as a possible wedge. Use \`blocked:\` when you are stuck and need help.
5. If you hit the same obstacle twice, append \`blocked: {why}\` and stop; firstmate will help.
6. If a decision belongs above the implementation worker (product choices, destructive actions, ask-user findings),
   append \`needs-decision: {summary of options}\` and stop. Firstmate will apply the configured authority and reply with the decision.
   When firstmate replies or a blocker clears and you resume, append \`resolved: {how it was decided or unblocked}\` (add the same \`[key=<slug>]\` if you opened it with one) so the decision or blocker is durably closed and does not keep resurfacing.
7. Never stop, restart, or update the shared \`no-mistakes\` daemon - it is one instance serving
   every lane/home, so restarting it kills other lanes' in-flight pipeline runs. On ANY no-mistakes
   daemon error, append \`blocked: {the daemon error}\` and stop; only firstmate manages the daemon.

# Project memory
If \`AGENTS.md\` or \`CLAUDE.md\` already exists, or if this task produced durable project-intrinsic knowledge, run \`$FM_ROOT/bin/fm-ensure-agents-md.sh .\` in the worktree.
Record only project knowledge useful to almost every future session.
For anything the codebase already shows, prefer a pointer to the authoritative file, command, or doc over copying the detail.
If you touch a project \`AGENTS.md\` that lacks \`## Maintaining this file\`, add that short self-governance section from \`$FM_ROOT/bin/fm-ensure-agents-md.sh\` in the same pass.
Keep it proportionate: skip \`AGENTS.md\` edits for trivial tasks that produced no durable project knowledge.

$DOD
EOF
cat "$BASELINE_TMP" >> "$BRIEF" || exit 2
rm -f "$BASELINE_TMP"
echo "scaffolded: $BRIEF (ship, mode=$MODE; replace {TASK})"
