#!/usr/bin/env bash
# Regression tests for bounded coordinate lease restoration and refresh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/bin/fm-coordinate-lease.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/fm-coordinate-lease.XXXXXX")"
campaign="$tmp/campaign"
mkdir -m 700 "$campaign"
task="$tmp/canonical-task.md"
calls="$tmp/calls"
lease="$tmp/lease-stub"
pane_old='w1:p1'
pane_new='w2:p7'

cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT

printf '%s\n' 'COORDINATES: /root/agent-work/deightonllm-firstmate' > "$task"
cat > "$lease" <<'EOF'
#!/usr/bin/env bash
printf 'approved=%s args=%s\n' "${HERDR_OPERATOR_APPROVED:-0}" "$*" >> "$FM_COORDINATE_TEST_CALLS"
exit 0
EOF
chmod 755 "$lease"
: > "$calls"

sha="$(sha256sum "$task" | awk '{print $1}')"
write_marker() {
  local pane=$1 expires=$2
  local key="${pane//[^A-Za-z0-9_.:-]/_}"
  cat > "$campaign/$key.antigravity" <<EOF
expires:$expires
fingerprint:test
pid:999999
task_sha:$sha
task_file:$task
ttl:900
artifact:<none>
model:Pi MiniMax M3
pane:$pane
EOF
}

run() {
  FM_COORDINATE_LEASE_BIN="$lease" \
  HERDR_CAMPAIGN_STATE_DIR="$campaign" \
  FM_COORDINATE_AGENT=antigravity \
  FM_COORDINATE_PANE_ID="$pane_new" \
  FM_COORDINATE_TEST_CALLS="$calls" \
  "$SCRIPT" "$@"
}

run_with_override() {
  FM_COORDINATE_TASK_FILE="$1" run "${@:2}"
}

now="$(date +%s)"
write_marker "$pane_old" "$((now + 3600))"
if ! run --restore >/dev/null; then
  echo 'FAIL: active prior marker was not restored after pane restart' >&2
  exit 1
fi
grep -q "approved=1 args=--pane $pane_new --agent antigravity --register-task $task" "$calls" || {
  echo 'FAIL: restoration did not bind the new pane to the original task' >&2
  exit 1
}

: > "$calls"
write_marker "$pane_new" "$((now + 3600))"
if ! run --refresh >/dev/null; then
  echo 'FAIL: active current marker was not refreshed' >&2
  exit 1
fi
grep -q "approved=0 args=--pane $pane_new --agent antigravity$" "$calls" || {
  echo 'FAIL: current-marker refresh unexpectedly re-registered with operator approval' >&2
  exit 1
}

: > "$calls"
write_marker "$pane_old" "$((now + 3600))"
rm -f "$campaign/w2:p7.antigravity"
printf '%s\n' 'changed bytes' >> "$task"
if run --restore >/dev/null 2>&1; then
  echo 'FAIL: changed canonical task was accepted' >&2
  exit 1
fi
[ ! -s "$calls" ] || { echo 'FAIL: changed task invoked the lease writer' >&2; exit 1; }

printf '%s\n' 'COORDINATES: /root/agent-work/deightonllm-firstmate' > "$task"
: > "$calls"
write_marker "$pane_old" "$((now + 3600))"
rm -f "$campaign/w2:p7.antigravity"
if run_with_override "$tmp/other-task.md" --restore >/dev/null 2>&1; then
  echo 'FAIL: alternate task override broadened the canonical binding' >&2
  exit 1
fi
[ ! -s "$calls" ] || { echo 'FAIL: alternate task override invoked the lease writer' >&2; exit 1; }

: > "$calls"
write_marker "$pane_old" "$((now - 1))"
rm -f "$campaign/w2:p7.antigravity"
if run --restore >/dev/null 2>&1; then
  echo 'FAIL: expired campaign was restored' >&2
  exit 1
fi
[ ! -s "$calls" ] || { echo 'FAIL: expired campaign invoked the lease writer' >&2; exit 1; }

: > "$calls"
write_marker "$pane_old" "$((now + 3600))"
rm -f "$campaign/w2:p7.antigravity"
sed -i "s#^task_file:.*#task_file:$tmp/missing-task.md#" "$campaign/w1:p1.antigravity"
if run --restore >/dev/null 2>&1; then
  echo 'FAIL: missing canonical task file was accepted' >&2
  exit 1
fi
[ ! -s "$calls" ] || { echo 'FAIL: missing canonical task invoked the lease writer' >&2; exit 1; }

echo 'PASS: coordinate lease expiry, restart restoration, bounded refresh, task integrity, and missing-file refusal'
