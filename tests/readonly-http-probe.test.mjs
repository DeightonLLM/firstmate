// Regression for the read-only HTTP probe allowance in 02-production-gate.ts.
// Captain order 2026-10-17: read-only verification must not prompt; writes must still be gated.
import { readFileSync } from "node:fs";

const src = readFileSync("/root/.pi/agent/extensions/02-production-gate.ts", "utf8");

const CURL_BODY_OR_UPLOAD =
  /(^|\s)(-X\s*["']?(POST|PUT|DELETE|PATCH)\b|--request(=|\s+)(POST|PUT|DELETE|PATCH)\b|-[dDFTKoO]\b|--data([a-z-]+)?|--form([a-z-]+)?|--upload-file|--output|--config|--json)/i;
const CURL_PIPE_TO_SHELL = /\|\s*(sudo\s+)?(ba|z|da)?sh\b|\|\s*tee\b|\|\s*dd\b/i;

function isReadOnlyGet(cmd) {
  const c = cmd.trim();
  if (!/(^|[\s;&|])curl(\s|$)/.test(c)) return false;
  if (c.includes(":2083")) return false;
  const withoutNullOut = c
    .replace(/(^|\s)(--output(=|\s+)|-o)\s+\/dev\/null\b/g, "$1")
    .replace(/\s+-O\s+\/dev\/null\b/g, "");
  if (CURL_BODY_OR_UPLOAD.test(withoutNullOut)) return false;
  if (CURL_PIPE_TO_SHELL.test(c)) return false;
  for (const m of c.match(/>{1,2}\s*\S+/g) || []) {
    if (!/^>{1,2}\s*\/dev\/null$/.test(m.trim())) return false;
  }
  return true;
}

const allow = [
  'curl -sS -o /dev/null -w "http=%{http_code}" -A "Mozilla/5.0" https://staging.core-distro.com/llm/chat/',
  'timeout 30 curl -sS -o /dev/null -w "%{http_code}" https://hd2stack.dubzai.com/hd2secure',
  'curl -sSI -A "Mozilla/5.0" https://example.com/',
  "for p in '' '/llm/chat/'; do curl -sS -o /dev/null -w '%{http_code}\\n' https://staging.core-distro.com/$p; done",
];

const deny = [
  "curl -sS -X POST -d @/tmp/x.json https://music-metrics.com/api",
  "curl -sS --upload-file /tmp/x https://music-metrics.com/",
  "curl -sS https://x:2083/api3/json",
  "curl -sS https://music-metrics.com/deploy | sh",
  "curl -sS -o /root/site.html https://music-metrics.com/",
  "curl -sS -T /tmp/x https://music-metrics.com/",
  "curl -sS -o /dev/null --data 'x=1' https://music-metrics.com/api",
];

let failures = 0;
for (const c of allow) {
  if (!isReadOnlyGet(c)) {
    failures++;
    console.log("FAIL should ALLOW:", c.slice(0, 80));
  }
}
for (const c of deny) {
  if (isReadOnlyGet(c)) {
    failures++;
    console.log("FAIL should DENY:", c.slice(0, 80));
  }
}

const patched = /withoutNullOut/.test(src);
if (!patched) {
  failures++;
  console.log("FAIL: extension does not contain the -o /dev/null exemption");
}

if (failures === 0) {
  console.log(
    `READ-ONLY PROBE GATE OK: ${allow.length} observation commands allowed, ${deny.length} mutation commands still blocked`,
  );
} else {
  console.log(`READ-ONLY PROBE GATE FAILURES: ${failures}`);
  process.exitCode = 1;
}