#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s --target URL --out FILE [--embed-id ID]\n' "${0##*/}" >&2
}
fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 2
}
target=
out=
embed_id=
while (($#)); do
  case "$1" in
    --target)
      (($# >= 2)) || { usage; fail '--target requires a URL'; }
      target=$2; shift 2 ;;
    --out)
      (($# >= 2)) || { usage; fail '--out requires a file path'; }
      out=$2; shift 2 ;;
    --embed-id)
      (($# >= 2)) || { usage; fail '--embed-id requires an identifier'; }
      embed_id=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; fail "unknown argument: $1" ;;
  esac
done
[[ -n "$target" ]] || { usage; fail '--target is required'; }
[[ -n "$out" ]] || { usage; fail '--out is required'; }
[[ "$target" =~ ^https?://[^/[:space:]]+(/[^[:space:]]*)?$ ]] || fail '--target must be an absolute http(s) URL'
[[ -z "$embed_id" || "$embed_id" =~ ^[A-Za-z0-9_-]+$ ]] || fail '--embed-id may contain only letters, digits, underscore, and hyphen'

python3 - "$target" "$out" "$embed_id" <<'PY'
import json
import re
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlsplit

target, out_path, supplied_embed_id = sys.argv[1:]
parsed = urlsplit(target)
base = target.rstrip("/")
if not parsed.path or parsed.path == "/":
    request_url = base + "/"
else:
    request_url = target
start = time.monotonic()
status = None
body = b""
error = None
try:
    req = urllib.request.Request(request_url, headers={"User-Agent": "ai-infra-probe/1.0"}, method="GET")
    with urllib.request.urlopen(req, timeout=12) as response:
        status = response.status
        body = response.read(512 * 1024)
except urllib.error.HTTPError as exc:
    status = exc.code
    body = exc.read(512 * 1024)
except Exception as exc:
    error = f"{type(exc).__name__}: {exc}"
elapsed_ms = round((time.monotonic() - start) * 1000, 3)
found = re.search(rb"/api/embed/([A-Za-z0-9_-]{8,})", body)
embed_id = supplied_embed_id or (found.group(1).decode("ascii") if found else None)
reachable = status is not None
limitations = [
    "GET-only probe: no chat or model-generation request was sent.",
    "Embedding, vector search, context assembly, chunk count, TTFT, and tokens/second are not exposed by this response and are unknown.",
    "Cold/warm generation comparison and pre-generation synchronization breakdown were not measured.",
]
if error:
    limitations.append("Target request failed before an HTTP response was received.")
result = {
    "target": target,
    "reachable": reachable,
    "http_status": status,
    "request_elapsed_ms": elapsed_ms,
    "embed_id": embed_id,
    "measurements": {
        "embedding_ms": None,
        "vector_search_ms": None,
        "context_assembly_ms": None,
        "chunk_size": None,
        "chunk_overlap": None,
        "chunks_in_prompt": None,
        "time_to_first_token_ms": None,
        "tokens_per_second": None,
        "cold": None,
        "warm": None,
        "pre_generation_sync_ms": None,
    },
    "limitations": limitations,
}
if error:
    result["error"] = error
rendered = json.dumps(result, indent=2, sort_keys=True)
try:
    with open(out_path, "w", encoding="utf-8") as output:
        output.write(rendered + "\n")
except OSError as exc:
    print(f"ERROR: cannot write report {out_path!r}: {exc}", file=sys.stderr)
    raise SystemExit(2)
print(rendered)
if not reachable or status is None or status >= 500:
    raise SystemExit(3)
PY
