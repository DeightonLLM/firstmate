#!/usr/bin/env bash
# Behavior tests for fm-next-board-chat.sh and fm-next-board-feedback.sh - the
# live board's Lavish ticket chat and the durable wake that carries a board
# message to the agent.
#
# Coverage: status with no session, status with a live session, status with a
# dead poll runner and pending results, reply with no session, reply into a
# live session, reply after the session ended, review with Lavish stubbed out,
# review with a missing artifact, end retiring the registered source, the
# feedback wake appending exactly one queue record, two different messages
# producing two different wakes, and the refused feedback files.
#
# Self-contained on purpose: every case builds a throwaway FM_HOME and stubs
# lavish-axi, so these tests never open a real Lavish session, never touch the
# network, and never read or write the real firstmate home. The real adapter
# and the real procevent runner still execute, so the registration under test
# is the genuine one the sanctioned owner writes.
#
# TAP: one line per case, `#` detail lines under a failure.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"
CHAT="$REPO_ROOT/bin/fm-next-board-chat.sh"
FEEDBACK="$REPO_ROOT/bin/fm-next-board-feedback.sh"
ADAPTER="$REPO_ROOT/bin/fm-procevent-lavish.sh"

TMP_ROOT=""
CASES_RUN=0
CASE_NAME=""
CASE_FAILS=0
CASE_DETAIL=""
CASE_ASSERTIONS=0
FAILED=0
OUT=""
RC=0

# shellcheck disable=SC2329 # Invoked by the EXIT trap below, not by name.
cleanup() {
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf -- "$TMP_ROOT"
  fi
}
trap cleanup EXIT

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

# Fixed-string assertions: reply bodies and paths can contain glob characters,
# so every needle is matched literally.
assert_has() {  # <substring> <why>
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    pass
  else
    fail "${2:-expected substring missing: $1}"
  fi
}

assert_lacks() {  # <substring> <why>
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    fail "${2:-unexpected substring present: $1}"
  else
    pass
  fi
}

# An assertion over a captured string rather than over the last command output.
assert_str_has() {  # <string> <substring> <why>
  if printf '%s\n' "$1" | grep -qF -- "$2"; then
    pass
  else
    fail "${3:-expected substring missing: $2}"
  fi
}

assert_status() {  # <expected> <why>
  if [ "$1" = "$RC" ]; then
    pass
  else
    fail "${2:-expected exit $1, got $RC}"
  fi
}

assert_eq() {  # <actual> <expected> <why>
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "${3:-expected [$2], got [$1]}"
  fi
}

assert_file() {  # <path> <why>
  if [ -f "$1" ]; then
    pass
  else
    fail "${2:-expected file to exist: $1}"
  fi
}

assert_no_file() {  # <path> <why>
  if [ -f "$1" ]; then
    fail "${2:-expected file to be absent: $1}"
  else
    pass
  fi
}

assert_file_has() {  # <path> <literal> <why>
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
    pass
  else
    fail "${3:-expected literal missing from $1: $2}"
  fi
}

# A stub lavish-axi records every invocation as one tab-separated CALL line, so
# a test can assert on the exact argv the controller hands to Lavish. It also
# reports a session URL the way the real tool does, so the controller's parser
# is exercised rather than bypassed.
write_lavish_stub() {  # <home>
  local home="$1"
  mkdir -p "$home/fakebin"
  cat > "$home/fakebin/lavish-axi" <<'STUB'
#!/usr/bin/env bash
{ printf 'CALL'; printf '\t%s' "$@"; printf '\n'; } >> "${LAVISH_STUB_LOG:?}"
case "${1:-}" in
  reply)
    printf 'reply accepted\n'
    exit 0
    ;;
  end)
    printf 'session ended\n'
    exit 0
    ;;
esac
printf 'Lavish session: http://127.0.0.1:4387/session/%s\n' "${LAVISH_STUB_SESSION:-stub-session-0001}"
exit 0
STUB
  chmod +x "$home/fakebin/lavish-axi"
}

new_home() {  # <name> -> prints a fresh throwaway home
  local home
  home="$TMP_ROOT/home-$1"
  mkdir -p "$home/state" "$home/data/next-board-publish"
  printf '<html><body>the published board</body></html>\n' \
    > "$home/data/next-board-publish/index.html"
  printf '%s' "$home"
}

run_chat() {  # <home> [args...] -> sets OUT and RC
  local home="$1"
  shift
  OUT=$(FM_HOME="$home" LAVISH_STUB_LOG="$home/lavish-calls.log" \
        PATH="$home/fakebin:$PATH" bash "$CHAT" "$@" 2>&1)
  RC=$?
}

run_feedback() {  # <home> [args...] -> sets OUT and RC
  local home="$1"
  shift
  OUT=$(FM_HOME="$home" bash "$FEEDBACK" "$@" 2>&1)
  RC=$?
}

source_id_of() {  # <home>
  bash "$ADAPTER" source-id "$1/data/next-board-publish/index.html" 2>/dev/null
}

write_feedback() {  # <home> <name> <ticket> <comment>
  local home="$1" name="$2" ticket="$3" comment="$4"
  mkdir -p "$home/state/next-board-feedback"
  {
    printf '# Board feedback\n\n'
    printf -- '- Timestamp: 2026-10-21T05:12:00Z\n'
    printf -- '- Ticket: %s\n' "$ticket"
    printf -- '- Source: form\n\n'
    printf '## Comment\n\n'
    printf '> %s\n' "$comment"
  } > "$home/state/next-board-feedback/$name"
}

queue_records() {  # <home>
  local home="$1"
  [ -f "$home/state/.wake-queue" ] || return 0
  cat -- "$home/state/.wake-queue"
}

if [ ! -f "$CHAT" ] || [ ! -f "$FEEDBACK" ]; then
  start_case "the board chat scripts exist"
  fail "missing $CHAT or $FEEDBACK"
  end_case
  printf '1..%d\n' "$CASES_RUN"
  printf '# fm-next-board-chat: %d cases failed\n' "$FAILED"
  exit 1
fi

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-next-board-chat.test.XXXXXX") || {
  printf 'Bail out! cannot create temp root\n'
  exit 1
}

# --- help -------------------------------------------------------------------

start_case "--help documents the four commands and exits 0"
home=$(new_home help)
run_chat "$home" --help
assert_status 0 "--help should succeed"
assert_has "review" "--help should document review"
assert_has "reply" "--help should document reply"
assert_has "end" "--help should document end"
assert_has "status" "--help should document status"
end_case

# --- status with no session -------------------------------------------------

start_case "status with no session says there is no session and invents no URL"
home=$(new_home nosession)
write_lavish_stub "$home"
run_chat "$home" status
assert_status 0 "status must succeed without a session"
assert_has "session: none" "status must say there is no session"
assert_has "session url: none" "status must say there is no session URL"
assert_has "last delivery: none" "status must say no delivery happened"
assert_has "pending results: 0" "status must report the pending count"
assert_lacks "http://" "status must not invent a session URL"
end_case

start_case "status on a machine with no board artifact still reports the truth"
home=$(new_home noartifact)
rm -f "$home/data/next-board-publish/index.html"
run_chat "$home" status
assert_status 0 "status must degrade, not fail"
assert_has "session: none" "status must say there is no session"
assert_has "source id: unknown" "status must not invent a source id"
assert_lacks "http://" "status must not invent a session URL"
end_case

# --- reply with no session --------------------------------------------------

start_case "reply with no session fails cleanly and never calls Lavish"
home=$(new_home replynosession)
write_lavish_stub "$home"
run_chat "$home" reply "the agent speaks"
assert_status 1 "reply must refuse without a session"
assert_has "run review first" "reply must say which command to run"
assert_no_file "$home/lavish-calls.log" "reply must not call Lavish without a session"
assert_no_file "$home/state/next-board-session.json" "a refused reply must not record a session"
end_case

# --- review -----------------------------------------------------------------

start_case "review opens the session, arms the source, and records the session"
home=$(new_home review)
write_lavish_stub "$home"
run_chat "$home" review
assert_status 0 "review should succeed with a stubbed Lavish"
assert_has "opened: http://127.0.0.1:4387/session/stub-session-0001" \
  "review must report the URL Lavish returned"
assert_file "$home/state/next-board-session.json" "review must record the session"
assert_file_has "$home/state/next-board-session.json" '"schema": "firstmate-next-board-session/v1"' \
  "the session record must carry the contract schema"
assert_file_has "$home/state/next-board-session.json" '"armed": true' \
  "the session record must say the source is armed"
assert_file_has "$home/state/next-board-session.json" '"session_id": "stub-session-0001"' \
  "the session record must carry the session id Lavish returned"
assert_file_has "$home/lavish-calls.log" "CALL"$'\t'"$home/data/next-board-publish/index.html" \
  "review must open the published board with lavish-axi"
source_id=$(source_id_of "$home")
assert_file "$home/state/procevent/$source_id.source" \
  "review must register the chat-back source with the procevent runner"
end_case

start_case "review refuses a missing board artifact and never calls Lavish"
home=$(new_home noboard)
write_lavish_stub "$home"
rm -f "$home/data/next-board-publish/index.html"
run_chat "$home" review
assert_status 1 "review must refuse without a published board"
assert_has "no published board artifact" "review must say the board is missing"
assert_no_file "$home/lavish-calls.log" "review must not call Lavish without a board"
assert_no_file "$home/state/next-board-session.json" "a refused review must not record a session"
end_case

# --- status with a live session ---------------------------------------------

start_case "status reports a registered but not running poll runner truthfully"
home=$(new_home deadrunner)
write_lavish_stub "$home"
run_chat "$home" review
assert_status 0 "review should succeed"
run_chat "$home" status
assert_status 0 "status must succeed"
assert_has "session: open" "status must report the open session"
assert_has "poll runner: not running" "status must not claim a runner that is not there"
assert_has "pending results: 0" "status must report the pending count"
assert_has "last delivery: none" "status must report no delivery"
assert_lacks "poll runner: alive" "status must never claim a live runner it cannot see"
end_case

start_case "status counts pending results and the last acknowledged delivery"
home=$(new_home pending)
write_lavish_stub "$home"
run_chat "$home" review
source_id=$(source_id_of "$home")
mkdir -p "$home/state/procevent-inbox"
printf 'session:\n  status: feedback\n' > "$home/state/procevent-inbox/$source_id.2.result"
printf 'lavish\n' > "$home/state/procevent-inbox/$source_id.2.adapter"
printf 'handled\n' > "$home/state/procevent-inbox/$source_id.2.handled"
printf 'session:\n  status: feedback\n' > "$home/state/procevent-inbox/$source_id.3.result"
printf 'lavish\n' > "$home/state/procevent-inbox/$source_id.3.adapter"
run_chat "$home" status
assert_status 0 "status must succeed"
assert_has "pending results: 1" "status must count the unacknowledged result"
assert_has "last delivery: " "status must report the acknowledged delivery"
assert_has "(seq 2)" "the last delivery must name the acknowledged sequence"
end_case

# --- reply into a live session ----------------------------------------------

start_case "reply delivers into the session and leaves a board copy"
home=$(new_home reply)
write_lavish_stub "$home"
run_chat "$home" review
assert_status 0 "review should succeed"
run_chat "$home" reply --ticket "0042-some-slug" "the board chat is live"
assert_status 0 "reply should succeed"
assert_file_has "$home/lavish-calls.log" "CALL"$'\t'"reply"$'\t'"$home/data/next-board-publish/index.html"$'\t'"--agent-reply-file" \
  "reply must use the documented lavish-axi reply form"
copy=$(find "$home/state/next-board-feedback/replies" -name '*.md' | head -1)
assert_file "$copy" "reply must leave a copy for the board"
assert_file_has "$copy" "# Board reply" "the reply copy must carry its own heading"
assert_file_has "$copy" "- Ticket: 0042-some-slug" "the reply copy must carry the ticket"
assert_file_has "$copy" "- Source: agent" "the reply copy must say who wrote it"
assert_file_has "$copy" "## Comment" "the reply copy must use the board's comment heading"
assert_file_has "$copy" "the board chat is live" "the reply copy must carry the reply body"
end_case

start_case "reply after the session ended refuses instead of faking a delivery"
home=$(new_home replyended)
write_lavish_stub "$home"
run_chat "$home" review
run_chat "$home" end
assert_status 0 "end should succeed"
run_chat "$home" reply "too late"
assert_status 1 "reply must refuse after the session ended"
assert_has "run review" "reply must say how to get a session again"
end_case

# --- end --------------------------------------------------------------------

start_case "end ends the session and retires the registered source"
home=$(new_home end)
write_lavish_stub "$home"
run_chat "$home" review
source_id=$(source_id_of "$home")
assert_file "$home/state/procevent/$source_id.source" "review must register the source"
run_chat "$home" end
assert_status 0 "end should succeed"
assert_file_has "$home/lavish-calls.log" "CALL"$'\t'"end"$'\t'"$home/data/next-board-publish/index.html" \
  "end must close the Lavish session"
assert_no_file "$home/state/procevent/$source_id.source" "end must retire the registered source"
assert_file_has "$home/state/next-board-session.json" '"armed": false' \
  "the session record must say the source is no longer armed"
assert_file_has "$home/state/next-board-session.json" '"ended_at": "' \
  "the session record must say when the session ended"
run_chat "$home" status
assert_has "session: ended" "status must report the ended session"
end_case

# --- the feedback wake ------------------------------------------------------

start_case "the feedback script appends exactly one wake record"
home=$(new_home wake)
write_feedback "$home" "20261021T051200Z-0042-some-slug.md" "0042-some-slug" "please reply on the board"
run_feedback "$home" "$home/state/next-board-feedback/20261021T051200Z-0042-some-slug.md"
assert_status 0 "the feedback wake should succeed"
records=$(queue_records "$home")
assert_eq "$(printf '%s\n' "$records" | grep -c .)" "1" "exactly one queue record must be appended"
assert_str_has "$records" "	signal	" "the wake record must be a signal record"
assert_str_has "$records" "next-board-feedback.20261021T051200Z-0042-some-slug." \
  "the wake key must name the message"
assert_str_has "$records" "0042-some-slug" "the wake must carry the ticket"
assert_str_has "$records" "please reply on the board" "the wake must carry the message"
end_case

start_case "two different board messages produce two different wakes"
home=$(new_home twowakes)
write_feedback "$home" "20261021T051200Z-0042-first.md" "0042-first" "the first message"
write_feedback "$home" "20261021T051201Z-0043-second.md" "0043-second" "the second message"
run_feedback "$home" "$home/state/next-board-feedback/20261021T051200Z-0042-first.md"
run_feedback "$home" "$home/state/next-board-feedback/20261021T051201Z-0043-second.md"
records=$(queue_records "$home")
assert_eq "$(printf '%s\n' "$records" | grep -c .)" "2" "two messages must append two records"
keys=$(printf '%s\n' "$records" | cut -f4 | sort -u | wc -l)
assert_eq "$keys" "2" "the two wakes must carry different keys"
end_case

start_case "the same board message keeps one wake key"
home=$(new_home onekey)
write_feedback "$home" "20261021T051200Z-0042-same.md" "0042-same" "the same message"
run_feedback "$home" "$home/state/next-board-feedback/20261021T051200Z-0042-same.md"
first=$(queue_records "$home" | cut -f4)
run_feedback "$home" "$home/state/next-board-feedback/20261021T051200Z-0042-same.md"
second=$(queue_records "$home" | cut -f4 | tail -1)
assert_eq "$second" "$first" "the same message must keep the same wake key"
end_case

start_case "the feedback script refuses a missing file and appends nothing"
home=$(new_home refusemissing)
write_feedback "$home" "20261021T051200Z-0042-some-slug.md" "0042-some-slug" "a message"
run_feedback "$home" "$home/state/next-board-feedback/does-not-exist.md"
assert_status 1 "a missing feedback file must be refused"
assert_has "no board feedback file" "the refusal must say the file is missing"
assert_eq "$(queue_records "$home" | grep -c .)" "0" "a refused file must append no wake"
end_case

start_case "the feedback script refuses a directory and appends nothing"
home=$(new_home refusedir)
mkdir -p "$home/state/next-board-feedback"
run_feedback "$home" "$home/state/next-board-feedback"
assert_status 1 "a directory must be refused"
assert_has "readable regular file" "the refusal must say what is wrong"
assert_eq "$(queue_records "$home" | grep -c .)" "0" "a refused file must append no wake"
end_case

start_case "the feedback script refuses an empty file and appends nothing"
home=$(new_home refuseempty)
mkdir -p "$home/state/next-board-feedback"
: > "$home/state/next-board-feedback/20261021T051200Z-empty.md"
run_feedback "$home" "$home/state/next-board-feedback/20261021T051200Z-empty.md"
assert_status 1 "an empty feedback file must be refused"
assert_has "empty" "the refusal must say the file is empty"
assert_eq "$(queue_records "$home" | grep -c .)" "0" "a refused file must append no wake"
end_case

printf '1..%d\n' "$CASES_RUN"
printf '# fm-next-board-chat: %d cases, %d assertions, %d failed\n' \
  "$CASES_RUN" "$CASE_ASSERTIONS" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
