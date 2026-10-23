#!/usr/bin/env bash
# launcher-template.sh - a scheduler launcher for ONE lane half on ONE surface.
#
# Copy this file, fill in the FOUR variables marked FILL IN, and start it with:
#
#   FM_AFK_LAUNCH_ENTRY=~/bin/<your-launcher>.sh \
#   FM_HOME=<firstmate home> \
#   FM_STATE_OVERRIDE=<this half's own state dir> \
#   FM_SUPERVISOR_BACKEND=tmux FM_SUPERVISOR_TARGET=firstmate:0 \
#   bash bin/fm-afk-launch.sh start
#
# NEVER start the daemon with nohup, & or disown: the launcher creates a tracked,
# non-visible terminal that it records and can tear down by exact id.
#
# WHY EVERYTHING IS IN ENV HERE AND NOT IN THE SCHEDULER SOURCE:
#   the lane configuration of a half is reversible - delete this file, stop the
#   daemon, and the scheduler is byte-identical to before it. A half that needs
#   a source edit needs a reason strong enough to change fleet behaviour, and
#   that reason is written in the lane's artifact with a backup.
#
# MEASURED 2026-10-23 on Hetz (brandon-compute), the working values:
#   harness minimax-code / model minimax/MiniMax-M3.1-Flash  -> the MiniMax half
#   harness codex        / model openai-codex/gpt-6-luna      -> the Luna half
# Both halves ran on ONE host at the same time, each with its own data/ and
# state/, at 6 lanes apiece: 12 concurrent lanes, no ceiling raised.

set -u

# ---------------------------------------------------------------- FILL IN ----
HARNESS="minimax-code"                 # minimax-code | codex | claude | grok | kimi | opencode
MODEL="minimax/MiniMax-M3.1-Flash"      # the id the SERVICE serves - see verify-fleet.sh
ACCOUNT_CEILING=6                      # the per-ACCOUNT ceiling, not the host's total
TARGET=6                                # concurrent lanes in this half
SEQUENCE="001 002 003 004 005 006"     # lane ids; give a second half its own range
# ---------------------------------------------------------------------------

FIRSTMATE_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
HALF_ROOT="/home/hd2admin/<surface>-half"   # FILL IN: this half's own directory
WORKSPACE="${HALF_ROOT}/work"

# The firstmate HOME stays the surface's: the dispatch guard reads its config and
# its second-mate registry from there, and fm-spawn resolves projects/<repo> from
# there. Only this half's own data/ and state/ are redirected - that isolation is
# what keeps two halves on one host from colliding on lane ids, metas, briefs,
# the in-flight set or the queue.
export FM_HOME="$FIRSTMATE_HOME"
export FM_DATA_OVERRIDE="${HALF_ROOT}/data"
export FM_STATE_OVERRIDE="${HALF_ROOT}/state"

export FM_ALWAYS_FOUR_TARGET="$TARGET"
export FM_ALWAYS_FOUR_SEQUENCE="$SEQUENCE"
export FM_ALWAYS_FOUR_HARNESS="$HARNESS"
export FM_ALWAYS_FOUR_WORKER_MODEL="$MODEL"
export FM_ALWAYS_FOUR_CHECKER_MODEL="$MODEL"
export FM_ALWAYS_FOUR_CHECKER_SLOT="lane-$(echo "$SEQUENCE" | awk '{print $NF}')"
export FM_ALWAYS_FOUR_POLL_SECS=30
export FM_ALWAYS_FOUR_MAX_ATTEMPTS=3
export FM_ALWAYS_FOUR_SCAFFOLD_BRIEF=1
export FM_ALWAYS_FOUR_MINT_LANE_KEY=1

# The backend that owns the panes. herdr on a shared surface; tmux where the
# pane helpers are the tmux ones.
export FM_BACKEND=herdr

# The per-account lane ceiling. The guard binds a CREDENTIAL ACCOUNT, so two
# surfaces sharing an account share one ceiling - read it from the account, not
# from the host.
export FM_DISPATCH_GUARD_MAX_PROVIDER_LANES="$ACCOUNT_CEILING"
export FM_DISPATCH_GUARD_MAX_LANES=12

# A route guard that refuses this half's harness (for example a "free route
# only" rule) is bypassed ONLY for this half, and only with the Captain's
# reason recorded in the lane's artifact. Remove this line to restore the
# refusal.
export FM_DISPATCH_GUARD_ROUTE_BYPASS=1

# The worktree settle window. MEASURED 2026-10-23: at full width, `treehouse
# get` took longer than the 60 s default to move the spawn pane into its
# worktree, the wait expired, and the spawn was reported FAILED while the
# worktree and the worker were created anyway - so the lane slot kept its old
# task and the daemon retried the same row. The default is unchanged for every
# other host; raise it only where it was measured.
export FM_TREEHOUSE_SETTLE_SECS=180

# mcode, codex, pi and herdr live in ~/.local/bin and the node bin, which a
# non-login shell's PATH does not carry. The fleet's spawn path calls them by
# name.
export PATH="$HOME/.local/bin:$HOME/.nvm/versions/node/v22.23.2/bin:$PATH"

mkdir -p "$FM_DATA_OVERRIDE" "$FM_STATE_OVERRIDE"

cd "$WORKSPACE"
exec "$FIRSTMATE_HOME/bin/fm-always-four.sh" daemon
