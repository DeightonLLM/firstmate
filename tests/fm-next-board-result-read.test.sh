#!/usr/bin/env bash
# tests/fm-next-board-result-read.test.sh - the board must read a captured result
# for its status line, never in full.
#
# The defect this suite exists for: a captured process-event result holds the
# adapter's WHOLE output. For the browser adapter that output is a DOM snapshot of
# the Captain's tracker - roughly half a megabyte per delivery, and it grows as the
# board grows. The board needs exactly one field from it: the status line the
# adapter writes in the file's session block at the head.
#
# The publisher used to read every captured result in full on every publish, to
# extract that one line. On this host that was 9.7 MB across 62 files for a single
# publish, and the cost grew with BOTH the number of deliveries and the size of the
# page each one captured. An unbounded read on a timer is how a board lane dies
# quietly.
#
# These cases prove the read is bounded, that the status line is still found
# wherever it sits in the file, and that the delivery state the board publishes is
# exactly what it was before the read was bounded:
#   1. a captured result's status line is read without reading the whole file;
#   2. a status line deeper in the file is still found;
#   3. a captured result carrying no status reports none;
#   4. the delivery state the board publishes is unchanged by the bounded read;
#   5. the live state directory is never written by this suite.
#
# Hermetic on purpose: every case builds a throwaway repo root under a temp root
# with its own fixture results, so the suite never touches the live home's state
# directory and never reads a real captured result.
#
# TAP: one line per case, `#` detail lines under a failure.
#
# SC2119: the shared library defines its own `pass` with a $1, and this suite's
# `pass` takes no argument. The rule fires on the bare `pass` calls below.
# shellcheck disable=SC2119
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"

# This suite creates and removes directories, so it uses the shared cleanup from
# tests/lib.sh. That cleanup falls back to a plain `rm -rf` when
# bin/fm-scratch-lib.sh is missing, and the fallback does not honour the --root
# it is handed - it would remove the repo root itself. Refuse to run rather than
# risk that.
if [ ! -r "$REPO_ROOT/bin/fm-scratch-lib.sh" ]; then
  printf 'not ok 0 - bin/fm-scratch-lib.sh is missing; the shared cleanup would remove the repo root\n' >&2
  exit 1
fi

# shellcheck source=tests/lib.sh
. "$SELF_DIR/lib.sh"

PUBLISHER="$REPO_ROOT/bin/fm-next-board-publish.py"

# The live state directory the firstmate's publish service reads. The suite must
# never write there, so it is snapshotted and compared at the end.
LIVE_STATE="${FM_LIVE_STATE_DIR:-/root/agent-work/deightonllm-firstmate/state}"

# The body a captured result carries behind its session block. A megabyte is
# enough to make a whole-file read obviously wrong and is quick to write.
BODY_BYTES=1048576

CASES_RUN=0
CASE_NAME=""
CASE_FAILS=0
CASE_DETAIL=""
CASE_ASSERTIONS=0
FAILED=0
OUT=""
RC=0

start_case() {
  CASE_NAME="$1"
  CASE_FAILS=0
  CASE_DETAIL=""
  CASES_RUN=$((CASES_RUN + 1))
}

pass() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
}

fail() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
  CASE_FAILS=$((CASE_FAILS + 1))
  CASE_DETAIL="${CASE_DETAIL}  # ${1:-assertion failed}"$'\n'
}

end_case() {
  if [ "$CASE_FAILS" -eq 0 ]; then
    printf 'ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
  else
    FAILED=$((FAILED + 1))
    printf 'not ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
    printf '%s' "$CASE_DETAIL"
  fi
}

assert_eq() {  # <actual> <expected> <why>
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "${3:-expected $2, got $1}"
  fi
}

assert_lt() {  # <actual> <bound> <why>
  if [ "$1" -lt "$2" ] 2>/dev/null; then
    pass
  else
    fail "${3:-expected a value under $2, got $1}"
  fi
}

# ---------------------------------------------------------------- the fixtures

# A registered source, in the shape the publisher reads it: the adapter, the
# argument count, then one argv line per argument.
write_source() {  # <path>
  cat > "$1" <<'SRC'
adapter=lavish
argc=3
argv:
lavish-axi
poll
/tmp/fixture-preview.html
SRC
}

# A captured result whose session block sits at the head, followed by a body the
# publisher has no reason to read.
write_result_with_head_status() {  # <path> <status>
  {
    printf 'session:\n'
    printf '  file: /tmp/fixture-preview.html\n'
    printf '  status: %s\n' "$2"
    printf 'prompts[1]{uid,prompt,selector,tag,text}:\n'
    head -c "$BODY_BYTES" /dev/zero | tr '\0' 'x'
    printf '\n'
  } > "$1"
}

# A captured result whose status line sits past the head, in the body. The board
# must still find it, so the bounded read may not simply stop at a prefix.
write_result_with_deep_status() {  # <path> <status>
  {
    printf 'session:\n'
    printf '  file: /tmp/fixture-preview.html\n'
    head -c "$BODY_BYTES" /dev/zero | tr '\0' 'x'
    printf '\n  status: %s\n' "$2"
  } > "$1"
}

# A captured result that carries no status at all.
write_result_without_status() {  # <path>
  {
    printf 'session:\n'
    printf '  file: /tmp/fixture-preview.html\n'
    head -c "$BODY_BYTES" /dev/zero | tr '\0' 'x'
    printf '\n'
  } > "$1"
}

# ---------------------------------------------------------------- the sandbox

# A throwaway repo root with a registered source and an empty result inbox.
new_sandbox() {
  local root
  root="$(fm_test_tmproot next-board-result-read)"
  mkdir -p "$root/repo/state/procevent" "$root/repo/state/procevent-inbox"
  write_source "$root/repo/state/procevent/lavish-fixture.source"
  printf '%s\n' "$root"
}

# ------------------------------------------------------------------- the probe

# Run the publisher's own delivery-state measurement against a sandbox root and
# report what it read from the captured results and what it concluded.
#
# The bytes are counted on the file objects themselves, so the count is what the
# publisher really pulled out of the result files - not what this probe guessed.
probe_publisher() {  # <sandbox-repo-root>
  OUT="$(python3 - "$1" "$PUBLISHER" <<'PY' 2>&1
import builtins
import collections
import importlib.util
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
publisher_path = sys.argv[2]

spec = importlib.util.spec_from_file_location("fm_next_board_publish", publisher_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

inbox = str(repo / "state" / "procevent-inbox")
counts = collections.Counter()
real_open = builtins.open
real_read_text = pathlib.Path.read_text


def is_result_path(name):
    """True for a captured-result file inside the sandbox inbox."""
    return name.startswith(inbox) and name.endswith(".result")


class Counting(object):
    """A file object that counts the bytes actually returned to the caller."""

    def __init__(self, fh):
        self._fh = fh

    def read(self, *a, **kw):
        data = self._fh.read(*a, **kw)
        counts["bytes"] += len(data)
        return data

    def readline(self, *a, **kw):
        data = self._fh.readline(*a, **kw)
        counts["bytes"] += len(data)
        return data

    def __iter__(self):
        for line in self._fh:
            counts["bytes"] += len(line)
            yield line

    def __getattr__(self, name):
        return getattr(self._fh, name)

    def __enter__(self):
        self._fh.__enter__()
        return self

    def __exit__(self, *exc):
        return self._fh.__exit__(*exc)


def hook(file, mode="r", *a, **kw):
    fh = real_open(file, mode, *a, **kw)
    if is_result_path(str(file)) and "r" in mode and "w" not in mode and "a" not in mode:
        counts["files"] += 1
        return Counting(fh)
    return fh


def read_text_hook(self, *a, **kw):
    """A whole-file read is counted too: pathlib opens through io, not builtins."""
    if is_result_path(str(self)):
        counts["files"] += 1
        data = self.read_bytes()
        counts["bytes"] += len(data)
        return data.decode("utf-8", "replace")
    return real_read_text(self, *a, **kw)


builtins.open = hook
pathlib.Path.read_text = read_text_hook
try:
    state = mod.read_delivery_state(repo)
finally:
    builtins.open = real_open
    pathlib.Path.read_text = real_read_text

last = state.get("last_result") or {}
feedback = state.get("last_feedback") or {}
print("result_bytes=%d" % counts["bytes"])
print("result_files=%d" % counts["files"])
print("total_results=%d" % state.get("total_results", 0))
print("pending_results=%d" % state.get("pending_results", 0))
print("last_sequence=%s" % last.get("sequence"))
print("last_status=%s" % last.get("status"))
print("last_feedback_status=%s" % feedback.get("status"))
PY
)"
  RC=$?
}

field() {  # <key>
  printf '%s\n' "$OUT" | sed -n "s/^$1=//p" | head -1
}

# ------------------------------------------------------------ the live directory

# The live state directory, hashed. The publish timer reads the result files but
# never rewrites them, so this snapshot is stable, and any change to it means
# this suite reached into the live home.
live_snapshot() {
  local dir=$1 file
  [ -d "$dir" ] || { echo "absent"; return 0; }
  ( cd "$dir" && find . -mindepth 1 -maxdepth 1 -printf '%f\n' | sort )
  for file in procevent-inbox/*.result; do
    [ -f "$dir/$file" ] && sha256sum "$dir/$file" | awk '{print $1"  "$2}'
  done
}

LIVE_BEFORE="$(live_snapshot "$LIVE_STATE")"

# ------------------------------------------------------------------- the cases

start_case "a captured result's status line is read without reading the whole file"
sandbox="$(new_sandbox)"
write_result_with_head_status "$sandbox/repo/state/procevent-inbox/lavish-fixture.1.result" "feedback"
probe_publisher "$sandbox/repo"
assert_eq "$RC" "0" "the publisher's delivery measurement runs"
assert_eq "$(field result_files)" "1" "the one captured result is opened"
assert_lt "$(field result_bytes)" 65536 \
  "the status line is read from a bounded prefix, not from the whole file"
assert_eq "$(field last_status)" "feedback" "the status line is still found"
end_case

start_case "a status line deeper in the file is still found"
sandbox="$(new_sandbox)"
write_result_with_deep_status "$sandbox/repo/state/procevent-inbox/lavish-fixture.1.result" "browser_disconnected"
probe_publisher "$sandbox/repo"
assert_eq "$RC" "0" "the publisher's delivery measurement runs"
assert_eq "$(field last_status)" "browser_disconnected" \
  "a status line past the head is still found, so the read is bounded but not blind"
end_case

start_case "a captured result carrying no status reports none"
sandbox="$(new_sandbox)"
write_result_without_status "$sandbox/repo/state/procevent-inbox/lavish-fixture.1.result"
probe_publisher "$sandbox/repo"
assert_eq "$RC" "0" "the publisher's delivery measurement runs"
assert_eq "$(field last_status)" "(unstated)" \
  "a result with no status line reports none, exactly as a whole-file read did"
end_case

start_case "the delivery state the board publishes is unchanged by the bounded read"
sandbox="$(new_sandbox)"
inbox="$sandbox/repo/state/procevent-inbox"
write_result_with_head_status "$inbox/lavish-fixture.1.result" "feedback"
write_result_without_status "$inbox/lavish-fixture.2.result"
write_result_with_deep_status "$inbox/lavish-fixture.3.result" "browser_disconnected"
# Only the first delivery was handled, so the other two are still pending.
: > "$inbox/lavish-fixture.1.handled"
probe_publisher "$sandbox/repo"
assert_eq "$RC" "0" "the publisher's delivery measurement runs"
assert_eq "$(field total_results)" "3" "every captured result is counted"
assert_eq "$(field pending_results)" "2" "the unhandled results are still reported pending"
assert_eq "$(field last_sequence)" "3" "the last delivery is the highest sequence"
assert_eq "$(field last_status)" "browser_disconnected" \
  "the last delivery carries the status read from deep in the file"
assert_eq "$(field last_feedback_status)" "feedback" \
  "the last feedback carries the status read from the head of its file"
end_case

start_case "the live state directory is never written by this suite"
assert_eq "$(live_snapshot "$LIVE_STATE")" "$LIVE_BEFORE" \
  "the live state directory is exactly as it was before the suite ran"
end_case

# ------------------------------------------------------------------- the report

printf '\n1..%d\n' "$CASES_RUN"
printf '# %d cases, %d assertions, %d failed\n' "$CASES_RUN" "$CASE_ASSERTIONS" "$FAILED"
if [ "$FAILED" -ne 0 ]; then
  printf 'REGRESSION CHECK: FAIL (%d of %d cases failed)\n' "$FAILED" "$CASES_RUN"
  exit 1
fi
printf 'REGRESSION CHECK: PASS (%d cases, %d assertions)\n' "$CASES_RUN" "$CASE_ASSERTIONS"
exit 0
