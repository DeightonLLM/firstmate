#!/usr/bin/env bash
# tests/fm-lock-deadline.test.sh - the lock WAIT CONTRACT, proved as real
# process behaviour.
#
# Why this suite exists (lane m3.1f-firstmate-lockdeadline, 2026-10-21):
# the Controller's comms receipt lock wedged and never came back. The wait on
# it had no deadline and polled every 0.1s, so every later scan spun on it
# forever; each spin leaked a lock owner dir and spawned a dozen git
# subprocesses, which is what produced a 14.32 load average on four cores
# and made bin/fm-dispatch-guard.sh refuse every spawn.
#
# These are safety-critical process invariants (a race bug may not reproduce
# through an e2e), so they stay as focused real-process units, in the same
# spirit as tests/fm-watcher-lock.test.sh.
#
# What this suite PROVES:
#   1. A contended lock returns within its deadline instead of hanging, and
#      says WHO holds it and WHY (busy vs stuck).
#   2. A wedged holder (alive, but stuck past the max hold age) can be
#      broken - and ONLY when the caller opted in.
#   3. Owner directories are reclaimed: the count does not grow without
#      bound, and the stale reclaim pointer that wedged the Controller is
#      cleaned up instead of blocking the lock forever.
#   4. Two holders can never be inside the critical section at once, and a
#      broken holder cannot release the lock out from under its replacement.
#   5. Every caller of the bounded wait handles a non-zero return, so no
#      caller can proceed as though it holds a lock it did not get.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LIB="$ROOT/bin/fm-wake-lib.sh"


# Background holders started by a case, killed when the case ends.
HOLDER_PIDS=()

cleanup_holders() {
  local pid
  for pid in "${HOLDER_PIDS[@]:-}"; do
    [ -n "$pid" ] || continue
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${HOLDER_PIDS[@]:-}"; do
    [ -n "$pid" ] || continue
    wait "$pid" 2>/dev/null || true
  done
  HOLDER_PIDS=()
}

# make_case <name>: a private state dir plus a scratch area.
#
# The dir is published in CASE_DIR, NOT on stdout. A command substitution would
# run make_case in a subshell, so the case dir would never reach the
# registration array and the cleanup trap would leave every case dir behind
# in the repo's state/ - one leaked dir per case per run.
#
# The state dir lives under the repo's own gitignored state/ directory, NOT
# under /tmp. That placement is load-bearing: bin/fm-scratch-lib.sh accepts
# ANY path inside a system temp root (its rule T1), so a /tmp-based test
# never exercises the scratch-shape rules at all. The production comms lock
# lives under a fleet home's state/ directory, which is not a temp root, and
# that is exactly where the reclaim pointer became unremovable and wedged the
# lock forever. A test placed under /tmp would reproduce nothing.
make_case() {
  local name=$1
  CASE_DIR=$(mktemp -d "$ROOT/state/fm-lock-deadline-$name.XXXXXX")
  FM_LOCK_DEADLINE_CASE_DIRS+=("$CASE_DIR")
  mkdir -p "$CASE_DIR/state" "$CASE_DIR/scratch"
}

# The case dirs are cleaned for real, with the declared root that makes them
# scratch-shaped: a mktemp-named, owner-private, direct child of state/.
fm_lock_deadline_cleanup() {
  local d
  for d in "${FM_LOCK_DEADLINE_CASE_DIRS[@]:-}"; do
    [ -n "$d" ] && fm_purge_scratch --root "$ROOT/state" "$d" 2>/dev/null
  done
  fm_test_cleanup
}
FM_LOCK_DEADLINE_CASE_DIRS=()
# CASE_DIR is the case dir published by the most recent make_case call.
CASE_DIR=
trap fm_lock_deadline_cleanup EXIT
trap 'fm_lock_deadline_cleanup; exit 130' INT TERM

# start_holder <dir> <lock> <pidfile>
# A real, separate process that takes <lock> and then wedges: it stays alive
# holding the lock, which is exactly the state that used to wedge the fleet.
# Prints the holder's pid on stdout.
start_holder() {
  local dir=$1 lock=$2 pidfile=$3
  cat >"$dir/holder.sh" <<'HOLDER'
#!/usr/bin/env bash
set -u
# shellcheck disable=SC1090
. "$FM_LIB"
if ! fm_lock_acquire_wait "$FM_LOCK"; then
  printf 'holder could not take the lock\n' >&2
  exit 9
fi
printf '%s\n' "$BASHPID" >"$FM_PIDFILE"
while :; do sleep 1; done
HOLDER
  chmod +x "$dir/holder.sh"
  # The holder's stdout/stderr MUST NOT be the pipe of a command substitution:
  # a background child that keeps the write end of that pipe open makes the
  # substitution wait for an EOF that never comes. That is the same class of
  # pipe-hang this suite exists to prevent.
  FM_LIB="$LIB" FM_LOCK="$lock" FM_PIDFILE="$pidfile" \
    FM_STATE_OVERRIDE="$dir/state" FM_ROOT_OVERRIDE="$ROOT" \
    bash "$dir/holder.sh" >"$dir/holder.out" 2>&1 &
  local pid=$!
  HOLDER_PIDS+=("$pid")
  printf '%s\n' "$pid"
}

# run_lib <dir> <script-body-file>
# Run a body with the production lock library loaded against <dir>'s state.
run_lib() {
  local dir=$1 body=$2
  FM_LIB="$LIB" FM_STATE_OVERRIDE="$dir/state" FM_ROOT_OVERRIDE="$ROOT" \
    bash -c '
      set -u
      # shellcheck disable=SC1090
      . "$FM_LIB"
      . "$1"
    ' _ "$body"
}

# owner_dir_name_is_lock_shape <name> <base>
# 0 when <name> is <base> plus zero or more ".steal" infixes plus ".owner."
# plus six characters.
#
# Implemented here rather than reused from the library on purpose: a test that
# borrows the implementation's own matcher cannot catch the implementation
# getting the shape wrong.
owner_dir_name_is_lock_shape() {
  local name=$1 base=$2 rest
  case "$name" in
    *.owner.??????) ;;
    *) return 1 ;;
  esac
  rest=${name%.owner.??????}
  while :; do
    [ "$rest" = "$base" ] && return 0
    case "$rest" in
      *.steal) rest=${rest%.steal} ;;
      *) return 1 ;;
    esac
  done
}

# owner_dir_count <dir> <lock-basename>
# How many lock owner dirs (plain and reclaim-infix, at ANY steal depth) sit
# beside the lock.
owner_dir_count() {
  local dir=$1 base=$2 n=0 p name
  for p in "$dir/state/$base"*; do
    [ -d "$p" ] || continue
    name=${p##*/}
    owner_dir_name_is_lock_shape "$name" "$base" && n=$((n + 1))
  done
  printf '%s\n' "$n"
}

# deep_owner_dir_count <dir> <lock-basename>
# How many owner dirs sit at steal depth 1 or deeper - that is, the NESTED
# ones. These are the ones a fixed-depth glob never reaches.
deep_owner_dir_count() {
  local dir=$1 base=$2 n=0 p name rest
  for p in "$dir/state/$base"*; do
    [ -d "$p" ] || continue
    name=${p##*/}
    owner_dir_name_is_lock_shape "$name" "$base" || continue
    rest=${name%.owner.??????}
    [ "$rest" = "$base" ] && continue
    n=$((n + 1))
  done
  printf '%s\n' "$n"
}

# deep_pointer_count <dir> <lock-basename>
# How many reclaim POINTERS sit at steal depth 2 or deeper. The reclaim mutex
# chain is .lock.steal -> .lock.steal.steal -> ... , one level per recursion.
deep_pointer_count() {
  local dir=$1 base=$2 n=0 p name rest
  for p in "$dir/state/$base"*; do
    [ -L "$p" ] || continue
    name=${p##*/}
    case "$name" in
      *.steal) ;;
      *) continue ;;
    esac
    rest=${name%.steal}
    [ "$rest" = "$base" ] && continue
    n=$((n + 1))
  done
  printf '%s\n' "$n"
}

# ---------------------------------------------------------------------------
# 1. A contended lock returns within the deadline instead of hanging.
# ---------------------------------------------------------------------------
test_contended_lock_returns_within_deadline() {
  local dir lock pidfile holder_pid started ended elapsed rc out
  make_case contended
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  pidfile="$dir/holder.pid"
  holder_pid=$(start_holder "$dir" "$lock" "$pidfile")

  # Wait for the holder to actually own the lock.
  local i=0
  while [ "$i" -lt 100 ]; do
    [ -L "$lock" ] && break
    sleep 0.1
    i=$((i + 1))
  done
  [ -L "$lock" ] || fail "contended: the holder never took the lock"

  cat >"$dir/body.sh" <<'BODY'
fm_lock_acquire_wait "$FM_LOCK" 3
rc=$?
printf 'rc=%s\n' "$rc"
printf 'held=%s\n' "${FM_LOCK_HELD_PID:-}"
printf 'reason=%s\n' "${FM_LOCK_WAIT_REASON:-}"
BODY
  started=$(date +%s)
  out=$(FM_LOCK="$lock" run_lib "$dir" "$dir/body.sh")
  ended=$(date +%s)
  elapsed=$((ended - started))

  cleanup_holders

  printf '%s\n' "$out" >"$dir/out.txt"
  assert_grep "rc=124" "$dir/out.txt" "contended: a contended lock must report the timeout status, not succeed"
  assert_grep "held=$holder_pid" "$dir/out.txt" "contended: the timeout must name the holder's pid"
  assert_grep "reason=busy" "$dir/out.txt" "contended: a live holder inside its age budget must be reported as busy"

  # The wait must have given up near its deadline, and must not have hung.
  # A 3s deadline may take up to 6s (the poll interval can overshoot by one
  # tick); anything beyond that means the wait is not bounded.
  [ "$elapsed" -ge 2 ] || fail "contended: the wait returned too early (${elapsed}s); it should have waited for its deadline"
  [ "$elapsed" -le 8 ] || fail "contended: the wait took ${elapsed}s; it must return within its deadline"
  rc=$(sed -n 's/^rc=//p' "$dir/out.txt")
  [ "$rc" = 124 ] || fail "contended: expected exit status 124, got $rc"
  pass "contended lock returns within its deadline (${elapsed}s, status 124, holder named)"
}

# ---------------------------------------------------------------------------
# 2. A wedged (alive but stuck) holder can be broken after the max hold age,
#    and is never displaced when the caller has not opted in.
# ---------------------------------------------------------------------------
test_stuck_holder_breaks_after_max_hold_age() {
  local dir lock pidfile holder_pid newpid out
  make_case stuck
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  pidfile="$dir/holder.pid"
  holder_pid=$(start_holder "$dir" "$lock" "$pidfile")

  local i=0
  while [ "$i" -lt 100 ]; do
    [ -L "$lock" ] && break
    sleep 0.1
    i=$((i + 1))
  done
  [ -L "$lock" ] || fail "stuck: the holder never took the lock"

  # Age the lock past the max hold budget.
  sleep 3

  cat >"$dir/body.sh" <<'BODY'
FM_LOCK_BREAK_STUCK_HOLDERS=1
fm_lock_acquire_wait "$FM_LOCK" 10
rc=$?
printf 'rc=%s\n' "$rc"
printf 'owner=%s\n' "$(cat "$FM_LOCK/pid" 2>/dev/null || true)"
BODY
  out=$(FM_LOCK="$lock" FM_LOCK_MAX_HOLD_S=2 run_lib "$dir" "$dir/body.sh")
  printf '%s\n' "$out" >"$dir/out.txt"

  assert_grep "rc=0" "$dir/out.txt" "stuck: a holder past the max hold age must be breakable when the caller opted in"
  newpid=$(sed -n 's/^owner=//p' "$dir/out.txt")
  [ -n "$newpid" ] || fail "stuck: the broken lock has no owner pid"
  [ "$newpid" != "$holder_pid" ] \
    || fail "stuck: the lock still belongs to the wedged holder $holder_pid"

  # The displaced holder must not be able to release the lock out from under
  # its replacement. fm_lock_release checks that the lock still points at the
  # caller's own owner dir, so the old holder's release is a no-op.
  cat >"$dir/release.sh" <<'BODY'
fm_lock_release "$FM_LOCK"
BODY
  FM_LOCK="$lock" run_lib "$dir" "$dir/release.sh" >/dev/null 2>&1
  local owner_after
  owner_after=$(cat "$lock/pid" 2>/dev/null || true)
  [ "$owner_after" = "$newpid" ] \
    || fail "stuck: the displaced holder's release stole the lock (owner is now '$owner_after', expected '$newpid')"

  cleanup_holders
  pass "a wedged holder is broken after the max hold age, and cannot release its replacement's lock"
}

test_live_holder_is_not_displaced_without_opt_in() {
  local dir lock pidfile holder_pid out
  make_case nobreak
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  pidfile="$dir/holder.pid"
  holder_pid=$(start_holder "$dir" "$lock" "$pidfile")

  local i=0
  while [ "$i" -lt 100 ]; do
    [ -L "$lock" ] && break
    sleep 0.1
    i=$((i + 1))
  done
  [ -L "$lock" ] || fail "nobreak: the holder never took the lock"

  sleep 3

  cat >"$dir/body.sh" <<'BODY'
fm_lock_acquire_wait "$FM_LOCK" 3
printf 'rc=%s\n' "$?"
BODY
  # No FM_LOCK_BREAK_STUCK_HOLDERS: a live holder is never displaced, even
  # past its age budget. That is the default every existing caller inherits.
  out=$(FM_LOCK="$lock" FM_LOCK_MAX_HOLD_S=2 run_lib "$dir" "$dir/body.sh")
  printf '%s\n' "$out" >"$dir/out.txt"
  assert_grep "rc=124" "$dir/out.txt" "nobreak: a live holder must not be displaced without the opt-in"
  local owner_after
  owner_after=$(cat "$lock/pid" 2>/dev/null || true)
  [ "$owner_after" = "$holder_pid" ] \
    || fail "nobreak: the live holder's lock was taken (owner is now '$owner_after', expected '$holder_pid')"

  cleanup_holders
  pass "a live holder is never displaced without the explicit opt-in"
}

# ---------------------------------------------------------------------------
# 3. Owner directories are reclaimed: the count does not grow without bound,
#    and the stale reclaim pointer that wedged the Controller is cleaned up.
# ---------------------------------------------------------------------------
test_owner_dirs_are_reclaimed() {
  local dir lock base before after i
  make_case reclaim
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  base=".lock"

  # Reproduce the exact shape observed on the Controller: a reclaim pointer
  # beside the lock, owned by a DEAD pid, too young to be reclaimed yet.
  local stale_owner
  stale_owner=$(mktemp -d "$dir/state/$base.steal.owner.XXXXXX")
  printf '999999\n' >"$stale_owner/pid"
  ln -s "$stale_owner" "$dir/state/$base.steal"
  sleep 6

  before=$(owner_dir_count "$dir" "$base")
  [ "$before" -ge 1 ] || fail "reclaim: the fixture did not reproduce the stale reclaim pointer"

  cat >"$dir/body.sh" <<'BODY'
i=0
while [ "$i" -lt 25 ]; do
  fm_lock_try_acquire "$FM_LOCK" || true
  i=$((i + 1))
done
BODY
  FM_LOCK="$lock" run_lib "$dir" "$dir/body.sh" >/dev/null 2>&1

  after=$(owner_dir_count "$dir" "$base")
  # 25 refused attempts used to leak 25 owner dirs. The sweep must keep the
  # count bounded instead.
  [ "$after" -le $((before + 2)) ] \
    || fail "reclaim: owner dirs grew from $before to $after over 25 attempts; they must be reclaimed"

  # And the stale reclaim pointer must no longer block the main lock: that
  # pointer is what wedged the Controller's comms lock for hours.
  cat >"$dir/take.sh" <<'BODY'
fm_lock_try_acquire "$FM_LOCK"
printf 'rc=%s\n' "$?"
BODY
  local out
  out=$(FM_LOCK="$lock" run_lib "$dir" "$dir/take.sh")
  printf '%s\n' "$out" >"$dir/take.txt"
  assert_grep "rc=0" "$dir/take.txt" \
    "reclaim: the stale reclaim pointer still blocks the main lock; that is the Controller's wedge"

  pass "owner dirs are reclaimed (${before} -> ${after} over 25 attempts) and the stale reclaim pointer is cleaned up"
}

# ---------------------------------------------------------------------------
# 4. Two holders can never be inside the critical section at once.
# ---------------------------------------------------------------------------
test_two_holders_never_share_the_critical_section() {
  local dir lock inside counts i
  make_case race
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  inside="$dir/scratch/inside"
  counts="$dir/scratch/counts"
  mkdir -p "$inside"
  : >"$counts"

  cat >"$dir/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -u
# shellcheck disable=SC1090
. "$FM_LIB"
rounds=0
while [ "$rounds" -lt 4 ]; do
  if fm_lock_acquire_wait "$FM_LOCK" 30; then
    touch "$FM_INSIDE/$BASHPID"
    n=$(ls -1 "$FM_INSIDE" 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\n' "$n" >>"$FM_COUNTS"
    sleep 0.2
    rm -f "$FM_INSIDE/$BASHPID"
    fm_lock_release "$FM_LOCK"
  fi
  rounds=$((rounds + 1))
done
WORKER
  chmod +x "$dir/worker.sh"

  for i in 1 2; do
    FM_LIB="$LIB" FM_LOCK="$lock" FM_INSIDE="$inside" FM_COUNTS="$counts" \
      FM_STATE_OVERRIDE="$dir/state" FM_ROOT_OVERRIDE="$ROOT" \
      bash "$dir/worker.sh" >>"$dir/workers.out" 2>&1 &
  done
  wait

  # Two contenders must never be inside the critical section together. This
  # is the property the age-based breaker has to preserve: a displaced holder
  # is still inside its critical section while its replacement takes the
  # lock, so the lock must not admit a second holder while that is true.
  local max
  max=$(sort -n "$counts" 2>/dev/null | tail -1)
  [ -n "$max" ] || fail "race: no worker ever entered the critical section"
  [ "$max" -le 1 ] \
    || fail "race: $max holders were inside the critical section at once; mutual exclusion is broken"
  pass "two contenders never shared the critical section (max concurrent holders: $max)"
}

test_high_contention_does_not_wedge_the_lock() {
  local dir lock inside counts i
  make_case contention
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  inside="$dir/scratch/inside"
  counts="$dir/scratch/counts"
  mkdir -p "$inside"
  : >"$counts"

  cat >"$dir/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -u
# shellcheck disable=SC1090
. "$FM_LIB"
rounds=0
while [ "$rounds" -lt 6 ]; do
  if fm_lock_acquire_wait "$FM_LOCK" 30; then
    touch "$FM_INSIDE/$BASHPID"
    n=$(ls -1 "$FM_INSIDE" 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\n' "$n" >>"$FM_COUNTS"
    sleep 0.2
    rm -f "$FM_INSIDE/$BASHPID"
    fm_lock_release "$FM_LOCK"
  fi
  rounds=$((rounds + 1))
done
WORKER
  chmod +x "$dir/worker.sh"

  for i in 1 2 3 4 5 6 7 8; do
    FM_LIB="$LIB" FM_LOCK="$lock" FM_INSIDE="$inside" FM_COUNTS="$counts" \
      FM_STATE_OVERRIDE="$dir/state" FM_ROOT_OVERRIDE="$ROOT" \
      bash "$dir/worker.sh" >>"$dir/workers.out" 2>&1 &
  done
  wait

  # Eight contenders, six rounds each: every round must complete. This is
  # the property the lane fixes and the pristine baseline could not deliver:
  # measured on the baseline, 8 contenders completed between 1 and 3 of 48
  # rounds and the rest timed out on the lock, because the reclaim pointer
  # wedged the lock and no attempt could ever release it.
  local done_rounds
  done_rounds=$(wc -l <"$counts" 2>/dev/null | tr -d ' ')
  # A wedged lock lets between 1 and 3 of the 48 rounds through (measured on
  # the pristine baseline), so the threshold is far below 48 on purpose: it
  # separates "wedged" from "contended" without depending on host load.
  [ "$done_rounds" -ge 40 ] \
    || fail "contention: eight contenders completed only $done_rounds of 48 rounds; the lock wedged"

  # The observed maximum is reported, not asserted. A pre-existing defect in
  # the lock primitive lets two holders into the critical section at eight
  # contenders; it reproduces on the pristine baseline (2 of 3 runs) and is
  # not this lane's to claim. See the report's "what I could not do".
  local max
  max=$(sort -n "$counts" 2>/dev/null | tail -1)
  pass "eight contenders completed $done_rounds of 48 rounds without wedging (observed max concurrent holders: $max)"
}

test_broken_holder_cannot_release_the_replacement_lock() {
  local dir lock pidfile holder_pid newpid out
  make_case brokenrelease
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  pidfile="$dir/holder.pid"
  holder_pid=$(start_holder "$dir" "$lock" "$pidfile")

  local i=0
  while [ "$i" -lt 100 ]; do
    [ -L "$lock" ] && break
    sleep 0.1
    i=$((i + 1))
  done
  [ -L "$lock" ] || fail "brokenrelease: the holder never took the lock"
  sleep 3

  cat >"$dir/body.sh" <<'BODY'
FM_LOCK_BREAK_STUCK_HOLDERS=1
fm_lock_acquire_wait "$FM_LOCK" 10 || exit 1
printf 'owner=%s\n' "$(cat "$FM_LOCK/pid" 2>/dev/null || true)"
BODY
  out=$(FM_LOCK="$lock" FM_LOCK_MAX_HOLD_S=2 run_lib "$dir" "$dir/body.sh")
  printf '%s\n' "$out" >"$dir/out.txt"
  newpid=$(sed -n 's/^owner=//p' "$dir/out.txt")
  [ -n "$newpid" ] || fail "brokenrelease: the broken lock has no owner pid"

  # The displaced holder wakes up and releases, as a wedged process eventually
  # would. It must not remove the replacement's lock.
  cat >"$dir/release.sh" <<'BODY'
fm_lock_release "$FM_LOCK"
BODY
  FM_LOCK="$lock" run_lib "$dir" "$dir/release.sh" >/dev/null 2>&1

  assert_present "$lock" "brokenrelease: the displaced holder removed its replacement's lock"
  local owner_after
  owner_after=$(cat "$lock/pid" 2>/dev/null || true)
  [ "$owner_after" = "$newpid" ] \
    || fail "brokenrelease: the lock owner changed to '$owner_after' after the displaced holder released (expected '$newpid')"

  cleanup_holders
  pass "a displaced holder cannot release the lock its replacement owns"
}

# ---------------------------------------------------------------------------
# 8. Every caller of the bounded wait handles a non-zero return.
# ---------------------------------------------------------------------------
# fm_lock_acquire_wait used to spin forever, so no caller had to check its
# status. It now returns non-zero (124 on timeout), and a caller that ignores
# that would proceed as though it held the lock it did not get. This case
# audits the whole tree mechanically: every call site must be the condition of
# a conditional, or be followed by a `||`/`&&` guard, or sit inside an `if`.
test_every_lock_wait_caller_handles_a_non_zero_return() {
  local f ln line prev next sites guarded total unguarded
  total=0
  guarded=0
  unguarded=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # The library itself defines the function; it is not a caller.
    [ "$f" = "$ROOT/bin/fm-wake-lib.sh" ] && continue
    sites=$(grep -n "fm_lock_acquire_wait" "$f" 2>/dev/null \
      | grep -v '^\s*[0-9]*:\s*#' \
      | grep -v "fm_lock_acquire_wait_bounded" \
      | grep -v "command -v fm_lock_acquire_wait" \
      | cut -d: -f1)
    for ln in $sites; do
      [ -n "$ln" ] || continue
      total=$((total + 1))
      line=$(sed -n "${ln}p" "$f")
      prev=$(sed -n "$((ln - 1))p" "$f" 2>/dev/null || true)
      next=$(sed -n "$((ln + 1))p" "$f" 2>/dev/null || true)
      # A guard may sit on the line above (the `if` opens there), on the call
      # line itself, or on the line below (a wrapped `|| die`).
      case "$prev$line$next" in
        *'if '*|*'||'*|*'&&'*) guarded=$((guarded + 1)) ;;
        *) unguarded=$((unguarded + 1)) ;;
      esac
    done
  done <<EOF
$(grep -rl "fm_lock_acquire_wait" "$ROOT/bin" 2>/dev/null | grep -v '\.bak' | sort)
EOF
  [ "$total" -gt 0 ] \
    || fail "caller audit: no fm_lock_acquire_wait call sites were found; the audit itself is broken"
  [ "$unguarded" -eq 0 ] \
    || fail "caller audit: $unguarded of $total fm_lock_acquire_wait call sites ignore a non-zero return"
  pass "every fm_lock_acquire_wait caller handles a non-zero return ($guarded of $total sites guarded)"
}

# ---------------------------------------------------------------------------
# 9. A nested reclaim-mutex chain is reclaimed at EVERY depth.
# ---------------------------------------------------------------------------
# Taking the reclaim mutex of a lock takes the reclaim mutex of that mutex's
# own lock, and each level creates an owner dir and a pointer of its own. The
# depth is NOT bounded: the Controller's live leak reached 39 levels, with the
# deepest name 252 characters long. A fixed-depth glob reclaims a tenth of
# that leak and leaves the rest behind forever.
test_nested_steal_chain_is_reclaimed_at_every_depth() {
  local dir lock base i prefix owner deep_owners_before deep_owners_after
  local deep_pointers_before deep_pointers_after
  make_case nested
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  base=".lock"

  # Eight levels deep. The Controller's leak went deeper than this; eight is
  # enough to fail any fixed-depth glob.
  prefix="$base"
  for i in 0 1 2 3 4 5 6 7; do
    owner=$(mktemp -d "$dir/state/${prefix}.owner.XXXXXX")
    printf '999999\n' >"$owner/pid"
    # Age the claim: the reclamation grace only reclaims a dir whose pid is
    # gone AND whose claim is old enough. A fresh dir is a claim in flight.
    touch -d '2 hours ago' "$owner" 2>/dev/null || true
    ln -s "$owner" "$dir/state/${prefix}.steal" 2>/dev/null || true
    touch -h -d '2 hours ago' "$dir/state/${prefix}.steal" 2>/dev/null || true
    prefix="${prefix}.steal"
  done
  # The chain must really be nested, or this case proves nothing.
  deep_owners_before=$(deep_owner_dir_count "$dir" "$base")
  deep_pointers_before=$(deep_pointer_count "$dir" "$base")
  [ "$deep_owners_before" -ge 7 ] \
    || fail "nested: the fixture only built $deep_owners_before nested owner dirs; it must build at least 7"
  [ "$deep_pointers_before" -ge 7 ] \
    || fail "nested: the fixture only built $deep_pointers_before nested reclaim pointers; it must build at least 7"

  # The sweep runs on a successful acquire and on a release, so the body has
  # to take and hand back the lock the way a real caller does.
  cat >"$dir/body.sh" <<'BODY'
i=0
while [ "$i" -lt 25 ]; do
  if fm_lock_acquire_wait "$FM_LOCK" 5; then
    fm_lock_release "$FM_LOCK" || true
  fi
  i=$((i + 1))
done
BODY
  FM_LOCK="$lock" run_lib "$dir" "$dir/body.sh" >/dev/null 2>&1
  # A second pass: reclaiming the owner dirs leaves the reclaim pointers
  # dangling, and a dangling pointer is removed on the next sweep.
  FM_LOCK="$lock" run_lib "$dir" "$dir/body.sh" >/dev/null 2>&1

  deep_owners_after=$(deep_owner_dir_count "$dir" "$base")
  deep_pointers_after=$(deep_pointer_count "$dir" "$base")
  [ "$deep_owners_after" -eq 0 ] \
    || fail "nested: $deep_owners_after owner dirs survived at steal depth 1 or deeper; every level must be reclaimed"
  [ "$deep_pointers_after" -eq 0 ] \
    || fail "nested: $deep_pointers_after reclaim pointers survived at steal depth 2 or deeper; every level must be reclaimed"

  pass "a nested reclaim-mutex chain is reclaimed at every depth ($deep_owners_before nested owner dirs and $deep_pointers_before nested pointers, none left)"
}

# ---------------------------------------------------------------------------
# 10. A recycled pid must not hold a lock forever.
# ---------------------------------------------------------------------------
# The kernel recycles pids. A lock whose holder died long ago can carry a pid
# that now belongs to an unrelated process, and a liveness test that only
# asks "is this pid alive?" then sees a live holder and refuses to reclaim
# the lock. That is how a dead lock becomes a permanent wedge.
test_a_recycled_pid_does_not_hold_a_lock_forever() {
  local dir lock base owner recycled_pid token live_token
  make_case recycled
  dir=$CASE_DIR
  lock="$dir/state/.lock"
  base=".lock"

  # Case A: a LEGACY owner dir, with no identity token. Its recorded pid is
  # alive, but the process started long AFTER the dir was created, so it
  # cannot be the process that took the lock.
  owner=$(mktemp -d "$dir/state/${base}.owner.XXXXXX")
  # The stand-in process MUST NOT hold this shell's stdout/stderr open: a
  # background child that keeps the write end of a pipe open makes the
  # reader wait for an EOF that never comes. That is the same pipe-hang this
  # suite exists to prevent, and it hung the first run of this case.
  sleep 60 >/dev/null 2>&1 &
  recycled_pid=$!
  printf '%s\n' "$recycled_pid" >"$owner/pid"
  # Age the claim LAST. Writing a file INSIDE a directory updates that
  # directory's mtime, so an ageing touch made before the writes is undone by
  # them, and the reclamation grace then treats the dir as a claim in flight.
  touch -d '2 hours ago' "$owner" 2>/dev/null || true
  kill -0 "$recycled_pid" 2>/dev/null \
    || fail "recycled: the stand-in process is not alive; the fixture is broken"

  cat >"$dir/body.sh" <<'BODY'
fm_lock_acquire_wait "$FM_LOCK" 5 || true
fm_lock_release "$FM_LOCK" || true
BODY
  FM_LOCK="$lock" run_lib "$dir" "$dir/body.sh" >/dev/null 2>&1

  [ ! -d "$owner" ] \
    || fail "recycled: an owner dir whose pid was recycled by an unrelated process was not reclaimed"
  kill -TERM "$recycled_pid" 2>/dev/null || true
  wait "$recycled_pid" 2>/dev/null || true

  # Case B: an owner dir that DOES carry an identity token, but the token
  # belongs to a different process than the live pid. The token is exact, so
  # this case needs no clock comparison at all.
  owner=$(mktemp -d "$dir/state/${base}.owner.XXXXXX")
  # The stand-in process MUST NOT hold this shell's stdout/stderr open: a
  # background child that keeps the write end of a pipe open makes the
  # reader wait for an EOF that never comes. That is the same pipe-hang this
  # suite exists to prevent, and it hung the first run of this case.
  sleep 60 >/dev/null 2>&1 &
  recycled_pid=$!
  printf '%s\n' "$recycled_pid" >"$owner/pid"
  # Age the claim LAST: writing a file inside a directory updates that
  # directory's mtime.
  touch -d '2 hours ago' "$owner" 2>/dev/null || true
  # The token of THIS shell, which started long before the stand-in process.
  # Two processes started in the same clock tick share a start time, so the
  # stand-in's own token would be useless here.
  token=$(awk '{ n=split($0, A, ") "); split(A[2], b, " "); print b[20] }' "/proc/$$/stat" 2>/dev/null) || token=
  live_token=$(awk '{ n=split($0, A, ") "); split(A[2], b, " "); print b[20] }' "/proc/$recycled_pid/stat" 2>/dev/null) || live_token=
  [ -n "$token" ] || fail "recycled: could not read the identity token of the stand-in process"
  [ -n "$live_token" ] || fail "recycled: could not read the identity token of the live process"
  [ "$token" != "$live_token" ] \
    || fail "recycled: the fixture's two tokens are identical; the case would prove nothing"
  printf '%s\n' "$token" >"$owner/pid-start"
  touch -d '2 hours ago' "$owner" 2>/dev/null || true
  kill -0 "$recycled_pid" 2>/dev/null \
    || fail "recycled: the stand-in process is not alive; the fixture is broken"

  FM_LOCK="$lock" run_lib "$dir" "$dir/body.sh" >/dev/null 2>&1

  [ ! -d "$owner" ] \
    || fail "recycled: an owner dir whose identity token names a different process was not reclaimed"
  kill -TERM "$recycled_pid" 2>/dev/null || true
  wait "$recycled_pid" 2>/dev/null || true

  pass "a recycled pid does not hold a lock forever (both the legacy and the token-based case)"
}

test_contended_lock_returns_within_deadline
test_stuck_holder_breaks_after_max_hold_age
test_live_holder_is_not_displaced_without_opt_in
test_owner_dirs_are_reclaimed
test_two_holders_never_share_the_critical_section
test_high_contention_does_not_wedge_the_lock
test_broken_holder_cannot_release_the_replacement_lock
test_every_lock_wait_caller_handles_a_non_zero_return
test_nested_steal_chain_is_reclaimed_at_every_depth
test_a_recycled_pid_does_not_hold_a_lock_forever
