#!/usr/bin/env bash
# Tests for bin/fm-brandon-queue-push.sh (controller queue publisher).
# Deterministic fake transport only; never contacts live Brandon.
# Publisher contract under test: options --queue --inbox --state --ssh --scp;
# remote staging dir is "$INBOX/.staging"; one receipt per pushed file under
# --state; queue files are never modified or deleted; unsafe queue entries
# (symlink/irregular) fail the run without copying anything.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUSH="$HERE/../bin/fm-brandon-queue-push.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "ok - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "NOT ok - $1${2:+ — $2}"; }
assert_eq() { # desc got want
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got '$2' want '$3'"; fi
}

# --- fake transport fixtures ------------------------------------------------
FAKE_REMOTE="$(mktemp -d)"
FAKE_BIN="$(mktemp -d)"
QUEUE="$(mktemp -d)"
STATE="$(mktemp -d)"
INBOX="$FAKE_REMOTE/inbox"
STAGING="$FAKE_REMOTE/inbox/.staging"
trap 'rm -rf "$FAKE_REMOTE" "$FAKE_BIN" "$QUEUE" "$STATE"' EXIT

mkdir -p "$STAGING"
CORRUPT_MARKER="$FAKE_REMOTE/.corrupt"

cat >"$FAKE_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# fake ssh: supports -G pin check (stub) and the publisher's remote commands
if [ "${1:-}" = "-G" ]; then
  echo "user hd2admin"
  echo "hostname 100.106.6.22"
  echo "identityfile $0"
  echo "userknownhostsfile /etc/hostname"
  exit 0
fi
# the publisher's remote command is the last argument
CMD="${@: -1}"
case "$CMD" in
  sha256sum\ *)
    f="${CMD#sha256sum }"
    sha256sum "$f" | awk '{print $1"  "$2}'
    ;;
  mv\ *)
    pair="${CMD#mv }"
    src="$(printf '%s' "$pair" | sed -E "s/^'([^']*)' .*$/\1/")"
    dst="$(printf '%s' "$pair" | sed -E "s/^'[^']*' '([^']*)'$/\1/")"
    mv "$src" "$dst"
    ;;
  rm\ -f\ *)
    p="${CMD#rm -f }"
    rm -f "$p"
    ;;
  mkdir\ -p\ *)
    dirs="${CMD#mkdir -p }"
    eval "mkdir -p $dirs"
    ;;
  *)
    echo "fake-ssh: unexpected command: $CMD" >&2
    exit 97
    ;;
esac
EOF
chmod +x "$FAKE_BIN/ssh"

cat >"$FAKE_BIN/scp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# fake scp: <opts...> <local> <remote-ish dst> — stages under the fake root
src=""
dst=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) shift 2 ;;
    -*) shift ;;
    *) if [ -z "$src" ]; then src="$1"; else dst="$1"; fi; shift ;;
  esac
done
name="$(basename "$dst")"
cp "$src" "__STAGING__/$name"
if [ -f "__CORRUPT__" ]; then printf 'corrupted' >>"__STAGING__/$name"; fi
EOF
sed -i "s|__STAGING__|$STAGING|; s|__CORRUPT__|$CORRUPT_MARKER|" "$FAKE_BIN/scp"
chmod +x "$FAKE_BIN/scp"

write_msg() { # name body -> prints sha
  printf '%s\n' "$2" >"$QUEUE/$1"
  sha256sum "$QUEUE/$1" | awk '{print $1}'
}

sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

run_push() {
  "$PUSH" --queue "$QUEUE" --inbox "$INBOX" --state "$STATE" \
    --ssh "$FAKE_BIN/ssh" --scp "$FAKE_BIN/scp" "$@"
}

# --- T1 happy path: copy, verify hash, atomic rename, receipt, queue intact --
ONE="20260924T0000Z-test-one.md"
ONE_SHA="$(write_msg "$ONE" "controller message one")"
ONE_QSHA_BEFORE="$(sha_of "$QUEUE/$ONE")"

if run_push >/dev/null 2>&1; then pass "T1 push exits 0"; else fail "T1 push exits 0"; fi
if [ -f "$INBOX/$ONE" ]; then pass "T1 remote final file exists"; else fail "T1 remote final file exists" "missing"; fi
assert_eq "T1 remote hash matches local" "$(sha_of "$INBOX/$ONE")" "$ONE_SHA"
assert_eq "T1 exactly one receipt" "$(find "$STATE" -name '*.receipt' | wc -l)" "1"
assert_eq "T1 queue file untouched" "$(sha_of "$QUEUE/$ONE")" "$ONE_QSHA_BEFORE"

# --- T2 idempotent: same file+hash re-run copies nothing new -----------------
COPIES_BEFORE="$(find "$STAGING" -type f | wc -l)"
if run_push >/dev/null 2>&1; then pass "T2 idempotent re-run exits 0"; else fail "T2 idempotent re-run exits 0"; fi
assert_eq "T2 no new staging copies on re-run" "$(find "$STAGING" -type f | wc -l)" "$COPIES_BEFORE"
assert_eq "T2 still exactly one remote final" "$(find "$INBOX" -name "$ONE" | wc -l)" "1"

# --- T3 hash mismatch: corrupted staged copy must not land, must fail safe ---
CORR="20260924T0001Z-test-corrupt.md"
CORR_SHA="$(write_msg "$CORR" "message to corrupt")"
touch "$CORRUPT_MARKER"
RC=0
run_push >/dev/null 2>&1 || RC=$?
rm -f "$CORRUPT_MARKER"
if [ "$RC" -ne 0 ]; then pass "T3 corrupted push exits nonzero"; else fail "T3 corrupted push exits nonzero" "exit 0"; fi
if [ ! -f "$INBOX/$CORR" ]; then pass "T3 corrupted file never reaches final"; else fail "T3 corrupted file never reaches final"; fi
if [ -z "$(find "$STATE" -name '*test-corrupt*' -print -quit)" ]; then
  pass "T3 no receipt for failed push"
else
  fail "T3 no receipt for failed push"
fi
assert_eq "T3 queue file intact" "$(sha_of "$QUEUE/$CORR")" "$CORR_SHA"

# --- T4 path safety: symlink entry rejected, nothing copied ------------------
ln -sfn "$QUEUE/$ONE" "$QUEUE/20260924T0002Z-symlink.md"
RC=0
run_push >/dev/null 2>&1 || RC=$?
if [ "$RC" -ne 0 ]; then pass "T4 symlink entry rejected"; else fail "T4 symlink entry rejected" "exit 0"; fi
if [ ! -e "$INBOX/20260924T0002Z-symlink.md" ]; then
  pass "T4 symlink never copied"
else
  fail "T4 symlink never copied"
fi
rm -f "$QUEUE/20260924T0002Z-symlink.md"

# --- T5 path validation: metacharacter inbox rejected before any transport ---
RC=0
"$PUSH" --queue "$QUEUE" --inbox "/tmp/bad;inbox" --state "$STATE" \
  --ssh "$FAKE_BIN/ssh" --scp "$FAKE_BIN/scp" >/dev/null 2>&1 || RC=$?
if [ "$RC" -ne 0 ]; then pass "T5 unsafe inbox path rejected"; else fail "T5 unsafe inbox path rejected" "exit 0"; fi

# --- T6 cwd-independence (regression: wrapper cwd defect) -------------------
# Top-level only; inner invocations set FM_QUEUE_PUSH_T6_GUARD=1 to avoid recursion.
if [ "${FM_QUEUE_PUSH_T6_GUARD:-}" != "1" ]; then
  if ( cd / && FM_QUEUE_PUSH_T6_GUARD=1 bash "$HERE/fm-brandon-queue-push.test.sh" >/dev/null 2>&1 ); then
    pass "T6 suite green via absolute path from arbitrary cwd"
  else
    fail "T6 suite green via absolute path from arbitrary cwd"
  fi
  if ( cd / && FM_QUEUE_PUSH_T6_GUARD=1 "$PUSH" --help >/dev/null 2>&1 ); then
    pass "T6 publisher --help via absolute path from arbitrary cwd"
  else
    fail "T6 publisher --help via absolute path from arbitrary cwd"
  fi
  if ( cd "$HERE/.." && FM_QUEUE_PUSH_T6_GUARD=1 bin/fm-brandon-queue-push.sh --help >/dev/null 2>&1 ); then
    pass "T6 publisher --help via repo-root-relative path"
  else
    fail "T6 publisher --help via repo-root-relative path"
  fi
fi

echo "----------------------------------------"
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
