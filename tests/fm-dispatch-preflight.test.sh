#!/usr/bin/env bash
set -uo pipefail

GATE=${GATE:-/root/bin/fm-dispatch-preflight}
passed=0
failed=0

test_case() {
  local name=$1 expected=$2; shift 2
  local output status
  output=$("$GATE" "$@" 2>&1)
  status=$?
  if [[ "$status" -eq "$expected" ]]; then
    printf 'PASS: %s (exit %s): %s\n' "$name" "$status" "$output"
    ((passed+=1))
  else
    printf 'FAIL: %s (expected exit %s, got %s): %s\n' "$name" "$expected" "$status" "$output"
    ((failed+=1))
  fi
}

test_case 'accept named checker label' 0 dispatch-controller-glm53f-preflight bounded-pi-checker
test_case 'accept named scout label' 0 research-hd2-pi-scout scout
test_case 'reject generic worker label' 64 worker bounded-pi-worker
test_case 'reject generic agent label' 64 agent scout
test_case 'reject generic task label' 64 task bounded-pi-checker
test_case 'reject generic none label' 64 none bounded-pi-worker
test_case 'reject missing task segment' 64 dispatch-controller-glm53f bounded-pi-worker
test_case 'reject missing surface segment' 64 dispatch--glm53f-preflight bounded-pi-worker
test_case 'reject unknown agent' 64 dispatch-controller-glm53f-preflight anonymous-agent
test_case 'reject empty label' 64 '' bounded-pi-worker
test_case 'reject empty agent' 64 dispatch-controller-glm53f-preflight ''
test_case 'reject absent arguments' 64

printf 'RESULT: %s passed; %s failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
