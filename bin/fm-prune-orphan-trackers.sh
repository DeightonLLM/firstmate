#!/usr/bin/env bash
# Prune watcher dedup trackers (.seen-*, .stale-*, .hb-*) whose task is provably gone.
#
# These files are the watcher's "already reported" memory. When a task is reaped
# outside teardown, its trackers survive forever and keep a dead window in the
# stale detector, which re-wakes firstmate on a phantom crew.
#
# SAFETY: a tracker is only archived when the task has NO meta, NO status file,
# and NO backlog record. Anything with a second signal proving it exists is kept.
# Nothing is deleted - files move to data/2026-10-15/orphan-trackers/.
set -u
FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
STATE="$FM_HOME/state"
DEST="$FM_HOME/data/2026-10-15/orphan-trackers"
mkdir -p "$DEST"

kept=0
moved=0

for f in "$STATE"/.*; do
  b=$(basename "$f")
  case "$b" in .|..) continue ;; esac

  t=$(printf '%s' "$b" | sed -E 's/^\.seen-(.*)_(status|turn-ended)$/\1/; s/^\.stale-(.*)$/\1/; s/^\.(hb-surfaced)-?(.*)$/\2/')

  if [ -z "$t" ]; then kept=$((kept + 1)); continue; fi

  if [ -f "$STATE/$t.meta" ] || [ -f "$STATE/$t.status" ]; then
    kept=$((kept + 1))
    continue
  fi

  if command -v tasks-axi >/dev/null 2>&1 && tasks-axi show "$t" >/dev/null 2>&1; then
    kept=$((kept + 1))
    continue
  fi

  mv "$f" "$DEST/" 2>/dev/null && moved=$((moved + 1))
done

printf 'kept=%s archived=%s\n' "$kept" "$moved"