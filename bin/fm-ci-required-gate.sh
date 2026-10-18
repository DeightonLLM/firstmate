#!/usr/bin/env bash
# Require every named GitHub Actions job result to be success.
# Usage: fm-ci-required-gate.sh job=result [job=result ...]
set -eu

if [ "$#" -eq 0 ]; then
  echo "fm-ci-required-gate: expected at least one job=result argument" >&2
  exit 2
fi

failed=0
for result in "$@"; do
  case "$result" in
    *=*)
      job=${result%%=*}
      state=${result#*=}
      ;;
    *)
      echo "fm-ci-required-gate: invalid job result: $result" >&2
      failed=1
      continue
      ;;
  esac
  if [ -z "$job" ] || [ -z "$state" ]; then
    echo "fm-ci-required-gate: invalid job result: $result" >&2
    failed=1
  elif [ "$state" != success ]; then
    echo "::error::CI job '$job' did not pass (result: $state)"
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "All required CI jobs passed."
