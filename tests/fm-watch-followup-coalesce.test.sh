#!/usr/bin/env bash
# Watcher Follow-up queue flood regression.
#
# Behavioral only: the real extension runs against a fake Pi runtime and a fake
# arm script. The fake models the installed Pi dispatcher: a queued follow-up is
# consumed either at user message_start (mid-run queue drain) or as the prompt of
# a starting run (before_agent_start). No source-byte assertions, no live model,
# network, or auth calls. The classifier script under bin/ is the real one.
set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SRC=${FM_SRC_DIR:-$ROOT/.pi/extensions}
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
export NODE_NO_WARNINGS=1

install_fixture() {
  local repo=$1
  mkdir -p "$repo/.pi/extensions/lib" \
    "$repo/node_modules/@earendil-works/pi-coding-agent" \
    "$repo/node_modules/@earendil-works/pi-tui" \
    "$repo/node_modules/typebox" \
    "$repo/bin"
  cp "$SRC/fm-primary-pi-watch.ts" "$repo/.pi/extensions/fm-primary-pi-watch.ts"
  cp "$SRC/lib/fm-calm-visibility.ts" "$repo/.pi/extensions/lib/fm-calm-visibility.ts"
  cp "$SRC/lib/fm-operational-input.ts" "$repo/.pi/extensions/lib/fm-operational-input.ts"
  cp "$ROOT/bin/fm-operational-input.sh" "$repo/bin/fm-operational-input.sh"
  chmod +x "$repo/bin/fm-operational-input.sh"
  printf '{"name":"@earendil-works/pi-coding-agent","type":"module","exports":"./index.js"}\n' \
    > "$repo/node_modules/@earendil-works/pi-coding-agent/package.json"
  cat > "$repo/node_modules/@earendil-works/pi-coding-agent/index.js" <<'JS'
export function getMarkdownTheme() { return {}; }
export class UserMessageComponent { render() { return []; } invalidate() {} }
JS
  printf '{"name":"@earendil-works/pi-tui","type":"module","exports":"./index.js"}\n' \
    > "$repo/node_modules/@earendil-works/pi-tui/package.json"
  cat > "$repo/node_modules/@earendil-works/pi-tui/index.js" <<'JS'
export class Box { addChild() {} clear() {} setBgFn() {} }
export class Container {}
export class Text {}
JS
  printf '{"name":"typebox","type":"module","exports":"./index.js"}\n' \
    > "$repo/node_modules/typebox/package.json"
  cat > "$repo/node_modules/typebox/index.js" <<'JS'
export const Type = { Object(properties) { return { type: "object", properties, additionalProperties: false }; } };
JS
  # Fake arm: one durable wake-queue event per invocation, a readiness line
  # before anything else, then hold / actionable / persistent failure depending
  # on gate files under $FM_HOME/state/gates and FM_TEST_HOLD_AFTER.
  cat > "$repo/bin/fm-watch-arm.sh" <<'SH'
#!/usr/bin/env bash
state_dir="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
mkdir -p "$state_dir"
gates="$state_dir/gates"
n=$(cat "$state_dir/.armcount" 2>/dev/null || echo 0)
n=$((n + 1))
printf '%s\n' "$n" > "$state_dir/.armcount"
printf 'wake: durable event %s\n' "$n" >> "$state_dir/.wake-queue"
printf 'watcher: started pid=%s\n' "$$"
# freeze gate: cycles numbered at or above freeze-from park (polling the gate)
# instead of closing, so a scenario can observe an exact queue depth with no
# successor chain racing in. Raising the gate number releases exactly the parked
# cycle and re-parks the next one, which keeps every step deterministic.
fz=$(cat "$gates/freeze-from" 2>/dev/null || printf '999999999')
if [ "$n" -ge "$fz" ]; then
  while :; do
    cur=$(cat "$gates/freeze-from" 2>/dev/null || printf '999999999')
    [ "$cur" -gt "$n" ] && break
    sleep 0.1
  done
fi
if [ -f "$gates/fail-on" ]; then
  printf 'watcher: FAILED - synthetic continuity failure (cycle %s)\n' "$n"
  exit 3
fi
hold_after=$(cat "$state_dir/.holdafter" 2>/dev/null || printf '%s' "${FM_TEST_HOLD_AFTER:-0}")
if [ "$hold_after" -gt 0 ] && [ "$n" -gt "$hold_after" ]; then
  while true; do sleep 1; done
fi
if [ -f "$gates/hold" ]; then
  while true; do sleep 1; done
fi
printf 'signal: cycle %s actionable\n' "$n"
exit 0
SH
  chmod +x "$repo/bin/fm-watch-arm.sh"
}

DRIVER=$(cat <<'JS'
import { writeFileSync, readFileSync, mkdirSync, unlinkSync } from "node:fs";
import { pathToFileURL } from "node:url";

const scenario = process.env.FM_TEST_SCENARIO;
const handlers = new Map();
const queue = [];
const rejected = [];
let sendCalls = 0;
let armCommand = null;

const pi = {
  on(name, handler) { handlers.set(name, handler); return () => {}; },
  events: { on() {} },
  registerCommand(name, options) { if (name === "fm-watch-arm-pi") armCommand = options.handler; },
  registerTool() {},
  sendUserMessage: async (message, options) => {
    sendCalls += 1;
    if (options?.deliverAs !== "followUp") throw new Error(`deliverAs=${String(options?.deliverAs)}`);
    const text = String(message);
    if (scenario === "send-reject" && sendCalls === 1) {
      rejected.push(text);
      throw new Error("queue rejected");
    }
    // Reject exactly the FIRST critical (typed failure) send of this scenario and
    // accept every later one, so a retained critical can be proven to deliver on a
    // subsequent ordinary path instead of being swallowed by the rejection.
    if (scenario === "critical-reject" && /watcher: FAILED/.test(text) && !rejected.some((m) => /watcher: FAILED/.test(m))) {
      rejected.push(text);
      throw new Error("queue rejected");
    }
    queue.push(text);
  },
};

const home = process.env.FM_HOME;
mkdirSync(`${home}/state`, { recursive: true });
writeFileSync(`${home}/state/.lock`, `${process.pid}\n`);
writeFileSync(`${home}/state/.holdafter`, process.env.FM_TEST_HOLD_AFTER || "0");
const mod = await import(pathToFileURL(process.env.PLUGIN).href);
mod.default(pi);

const fire = async (name, event) => handlers.get(name)?.(event, {});
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const settle = (ms) => wait(ms);
const gates = () => `${home}/state/gates`;
const gate = (name) => { mkdirSync(gates(), { recursive: true }); writeFileSync(`${gates()}/${name}`, "go\n"); };
const ungate = (name) => { try { unlinkSync(`${gates()}/${name}`); } catch {} };
const freezeFrom = (cycle) => {
  mkdirSync(gates(), { recursive: true });
  writeFileSync(`${gates()}/freeze-from`, `${cycle}\n`);
};
const durable = () => {
  try {
    return (readFileSync(`${home}/state/.wake-queue`, "utf8").match(/wake: durable event/g) || []).length;
  } catch { return 0; }
};
// Installed Pi consumes a queued follow-up either as a mid-run user
// message_start or as the prompt of a starting run. The fake exposes both and
// consumes by EXACT identity, oldest first: a LIFO pop of the newest queued
// hint would let a replayed or extra hint satisfy an assertion about the live
// generation's wake.
const takeExact = (prompt) => {
  const at = queue.indexOf(prompt);
  if (at < 0) return "";
  queue.splice(at, 1);
  return prompt;
};
// The real message_start payload shape: a content ARRAY of typed blocks, not a
// bare string, optionally carrying non-text parts.
const asContentArray = (text) => [
  { type: "text", text },
  { type: "image", url: "https://example.invalid/ignored.png" },
];
const consumeViaMessageStart = async (prompt = queue[0]) => {
  if (prompt === undefined) return "";
  const at = queue.indexOf(prompt);
  if (at < 0) return "";
  queue.splice(at, 1);
  await fire("message_start", { type: "message_start", message: { role: "user", content: prompt } });
  return prompt;
};
const consumeArrayViaMessageStart = async (prompt = queue[0]) => {
  if (prompt === undefined) return "";
  const at = queue.indexOf(prompt);
  if (at < 0) return "";
  queue.splice(at, 1);
  await fire("message_start", { type: "message_start", message: { role: "user", content: asContentArray(prompt) } });
  return prompt;
};
const consumeViaBeforeAgentStart = async (prompt = queue[0]) => {
  if (prompt === undefined) return "";
  const at = queue.indexOf(prompt);
  if (at < 0) return "";
  queue.splice(at, 1);
  await fire("before_agent_start", { type: "before_agent_start", messageType: "user", prompt });
  return prompt;
};

await fire("session_start", { type: "session_start", reason: "startup" });
if (!armCommand) { console.error("arm command not registered"); process.exit(2); }
await armCommand("", { ui: { notify() {} } });

const result = { scenario, queue: [], sendCalls, durable: 0 };

if (scenario === "busy-burst") {
  // 22 actionable cycles then a holding successor, while the agent stays busy.
  await settle(1500);
  result.queueDepth = queue.length;
  result.durable = durable();
  result.allFollowUp = queue.every((m) => m.includes("FIRSTMATE WATCHER WAKE"));
} else if (scenario === "consume-midrun") {
  await settle(800);
  result.depthBefore = queue.length;
  const first = await consumeViaMessageStart();
  result.firstConsumed = Boolean(first);
  result.depthAfterConsume = queue.length;
  await settle(700);
  result.depthAfterNextWake = queue.length;
  result.nextPromptDiffers = queue.length === 1 && queue[0] !== first;
  result.durable = durable();
} else if (scenario === "unrelated-starts") {
  await settle(800);
  const depth = queue.length;
  await fire("before_agent_start", { type: "before_agent_start", messageType: "user", prompt: "please check the deploy log" });
  await fire("message_start", { type: "message_start", message: { role: "user", content: "unrelated captain text" } });
  await fire("agent_end", { type: "agent_end" });
  result.depthBefore = depth;
  result.depthAfter = queue.length;
} else if (scenario === "critical-after-ordinary") {
  await settle(800);
  gate("fail-on");
  // Persistent failure: with retry limit 1 the extension exhausts retries and
  // must surface a critical failure while the ordinary hint is still pending.
  await settle(1400);
  ungate("fail-on");
  result.depthWhilePending = queue.length;
  result.pendingIsOrdinary = queue.length === 1 && !queue[0].includes("FAILED");
  await consumeViaMessageStart();
  await settle(700);
  result.depthAfterConsume = queue.length;
  result.criticalDelivered = queue.length === 1 && queue[0].includes("FAILED");
  await consumeViaMessageStart();
  result.criticalConsumed = queue.length === 0;
} else if (scenario === "repeated-critical") {
  gate("fail-on");
  await settle(1400);
  result.depthFirstCritical = queue.length;
  const first = queue[0] ?? "";
  // Another failing cycle while the critical notification is pending: dedupe.
  await armCommand("", { ui: { notify() {} } });
  await settle(500);
  result.depthStillOne = queue.length;
  await consumeViaMessageStart();
  // A distinct later failure (different cycle number) must deliver again.
  await armCommand("", { ui: { notify() {} } });
  await settle(700);
  const later = queue[queue.length - 1] ?? "";
  result.distinctLaterCritical = queue.length === 1 && later.includes("FAILED") && later !== first;
} else if (scenario === "send-reject") {
  // Freeze the successor chain from cycle 2 so the queue depth after the
  // rejection is observed exactly, with no other wake racing in.
  freezeFrom(2);
  await settle(1200);
  result.depthAfterReject = queue.length;
  result.durableAfterReject = durable();
  // SAME-GENERATION release: no session_shutdown/session_start. Releasing cycle
  // 2 must deliver inside THIS generation, which is the only way to prove the
  // delivery reservation was actually released rather than reset by a new
  // generation's fresh state.
  freezeFrom(3);
  await settle(1200);
  result.depthAfterNextWake = queue.length;
  result.sameGenerationDelivered = queue.length === 1 && queue[0].includes("FIRSTMATE WATCHER WAKE");
  result.durableAfterNextWake = durable();
  // And the released reservation can be consumed, then notified again.
  const first = queue[0] ?? "";
  result.firstConsumed = Boolean(await consumeViaMessageStart(first));
  freezeFrom(4);
  await settle(1200);
  result.depthAfterConsume = queue.length;
  result.notifiedAgainAfterConsume = queue.length === 1 && queue[0] !== first;
  result.durableAtEnd = durable();
} else if (scenario === "message-start-array") {
  // The real consumption path: a user message_start carrying a typed content
  // ARRAY, not a bare string. Only exact text may release the reservation.
  freezeFrom(2);
  await settle(1200);
  const pending = queue[0] ?? "";
  result.pendingBefore = queue.length;
  result.pendingIsWatcherWake = pending.includes("FIRSTMATE WATCHER WAKE");
  // An assistant turn replaying the same text must NOT acknowledge.
  await fire("message_start", {
    type: "message_start",
    message: { role: "assistant", content: asContentArray(pending) },
  });
  result.assistantRoleDidNotAck = queue.length === result.pendingBefore;
  // A user turn whose text is not the exact queued hint must NOT acknowledge.
  await fire("message_start", {
    type: "message_start",
    message: { role: "user", content: [{ type: "text", text: `${pending} trailing captain note` }] },
  });
  result.nonExactTextDidNotAck = queue.length === result.pendingBefore;
  // The exact array-form user message must acknowledge.
  result.arrayFormConsumed = Boolean(await consumeArrayViaMessageStart(pending));
  result.depthAfterArrayConsume = queue.length;
  // And a genuinely later wake is delivered again.
  freezeFrom(3);
  await settle(1200);
  result.depthAfterNextWake = queue.length;
  result.nextWakeIsDistinct = queue.length === 1 && queue[0] !== pending && queue[0].includes("FIRSTMATE WATCHER WAKE");
  result.durable = durable();
} else if (scenario === "critical-reject") {
  // A CRITICAL send is rejected by the queue. The evidence must survive inside
  // THIS generation and a later ordinary wake must still deliver it, rather than
  // the typed failure disappearing together with the rejected send.
  gate("fail-on");
  await settle(1600);
  result.rejectedWasCritical = rejected.filter((m) => /watcher: FAILED/.test(m)).length;
  result.rejectedRetryExhaustion = rejected.some((m) => /after 1 retries/.test(m));
  result.depthAfterReject = queue.length;
  result.durableAfterReject = durable();
  // Supervision continues WITHOUT leaving the generation: an ordinary actionable
  // cycle must deliver normally, and the successor chain is frozen so the queue
  // depth after the acknowledgement is exact.
  ungate("fail-on");
  // Cycle 3 is the next one to run, so park from cycle 4: it delivers exactly one
  // ordinary wake and its successor stays parked.
  freezeFrom(4);
  await armCommand("", { ui: { notify() {} } });
  await settle(1200);
  result.depthAfterOrdinary = queue.length;
  result.ordinaryDelivered = queue.length === 1 && !queue[0].includes("watcher: FAILED");
  // Consume the ordinary hint through the real message_start content array: the
  // retained critical evidence must arrive as its own notification.
  const ordinary = queue[0] ?? "";
  result.ordinaryConsumed = Boolean(await consumeArrayViaMessageStart(ordinary));
  await settle(900);
  result.depthAfterOrdinaryConsumed = queue.length;
  result.criticalRecovered = queue.length === 1 &&
    queue[0].includes("watcher: FAILED") &&
    queue[0].includes("after 1 retries");
  result.criticalIsRetainedNotFresh = queue.length === 1 && !queue[0].includes("signal: cycle");
  result.criticalConsumed = Boolean(await consumeArrayViaMessageStart(queue[0] ?? ""));
  result.depthAtEnd = queue.length;
  result.durableAtEnd = durable();
} else if (scenario === "stale-cannot-drain-critical") {
  // A stale generation's prompt must not release the live generation's
  // reservation, and must not drain its coalesced critical upgrade early.
  await settle(800);
  const stalePrompt = queue[0] ?? "";
  await fire("session_shutdown", { type: "session_shutdown", reason: "new" });
  await fire("session_start", { type: "session_start", reason: "startup" });
  await armCommand("", { ui: { notify() {} } });
  await settle(900);
  const liveOrdinary = queue[queue.length - 1] ?? "";
  gate("fail-on");
  await settle(1600);
  result.depthWithCriticalCoalesced = queue.length;
  result.livePendingIsOrdinary = liveOrdinary !== "" && !liveOrdinary.includes("watcher: FAILED");
  // The stale prompt, delivered through BOTH real consumption shapes.
  const sendsBeforeStale = sendCalls;
  await fire("before_agent_start", { type: "before_agent_start", messageType: "user", prompt: stalePrompt });
  await fire("message_start", {
    type: "message_start",
    message: { role: "user", content: asContentArray(stalePrompt) },
  });
  result.staleDeliveredNothing = sendCalls === sendsBeforeStale;
  result.staleDidNotDrainUpgrade = queue.length === result.depthWithCriticalCoalesced;
  result.staleStillQueued = queue.includes(stalePrompt);
  // Consume the LIVE pending wake by exact identity only.
  await consumeArrayViaMessageStart(liveOrdinary);
  await settle(700);
  result.liveStaleNotConsumed = queue.includes(stalePrompt);
  result.upgradeAfterLiveConsume = queue.some((m) => /watcher: FAILED/.test(m) && m.includes("after 1 retries"));
  result.depthAfterUpgrade = queue.length;
} else if (scenario === "stale-generation") {
  await settle(800);
  const stalePrompt = queue[0] ?? "";
  await fire("session_shutdown", { type: "session_shutdown", reason: "new" });
  const sendsBefore = sendCalls;
  await fire("before_agent_start", { type: "before_agent_start", messageType: "user", prompt: stalePrompt });
  await fire("message_start", { type: "message_start", message: { role: "user", content: stalePrompt } });
  result.staleAckSendsNothing = sendCalls === sendsBefore;
  // A fresh session generation arms again and its wake id is unique.
  await fire("session_start", { type: "session_start", reason: "startup" });
  await armCommand("", { ui: { notify() {} } });
  await settle(700);
  const fresh = queue[queue.length - 1] ?? "";
  result.freshWakeDelivered = sendCalls > sendsBefore && fresh.includes("FIRSTMATE WATCHER WAKE");
  result.freshIdDiffers = fresh !== stalePrompt;
  // FIFO order is asserted explicitly so a LIFO pop of the newest queued hint can
  // never stand in for consuming the live generation's wake.
  result.queueOrderOldestFirst = queue.length === 2 && queue[0] === stalePrompt && queue[1] === fresh;
  // The stale prompt must not acknowledge the new generation's pending wake.
  await fire("before_agent_start", { type: "before_agent_start", messageType: "user", prompt: stalePrompt });
  const sendsAfterStale = sendCalls;
  result.staleStillQueuedAfterReplay = queue.includes(stalePrompt);
  const consumed = await consumeViaBeforeAgentStart(fresh);
  result.staleCannotAckNew = consumed === fresh;
  result.staleNotConsumedWithLive = queue.length === 1 && queue[0] === stalePrompt;
  result.newAckSendsNoExtra = sendCalls === sendsAfterStale;
  // Consuming the genuinely stale hint afterwards is still a no-op.
  const sendsAfterLive = sendCalls;
  await consumeViaMessageStart(stalePrompt);
  result.staleConsumeSendsNoExtra = sendCalls === sendsAfterLive;
  result.depthAtEnd = queue.length;
}

result.queue = [...queue];
result.sendCalls = sendCalls;
result.rejected = rejected;
console.log(JSON.stringify(result));
process.exit(0);
JS
)

run_scenario() {
  local name=$1 hold_after=${2:-0}
  local repo="$TMP_ROOT/$name" home="$TMP_ROOT/$name-home"
  mkdir -p "$repo" "$home/state" "$home/config"
  install_fixture "$repo"
  PLUGIN="$repo/.pi/extensions/fm-primary-pi-watch.ts" \
  FM_HOME="$home" FM_ROOT_OVERRIDE="$repo" FM_STATE_OVERRIDE="$home/state" FM_CONFIG_OVERRIDE="$home/config" \
  FM_TEST_SCENARIO="$name" FM_TEST_HOLD_AFTER="$hold_after" \
  FM_WATCH_REARM_RETRY_BASE_MS=5 FM_WATCH_REARM_RETRY_MAX_MS=10 FM_WATCH_REARM_RETRY_LIMIT=1 \
  timeout 60 node --input-type=module <<EOF
$DRIVER
EOF
}

field() { printf '%s' "${1:-}" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let o={};try{o=JSON.parse(s.trim().split("\n").filter(l=>l.startsWith("{")).pop()||"{}")}catch{o={}}const v=process.argv[1].split(".").reduce((a,k)=>a?.[k],o);console.log(v===undefined||v===null?"":typeof v==="object"?JSON.stringify(v):String(v));});' "$2"; }

FAILURES=0
check() {
  local label=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then printf 'ok   %s (%s)\n' "$label" "$got"
  else printf 'FAIL %s: got %s want %s\n' "$label" "$got" "$want"; FAILURES=$((FAILURES + 1)); fi
}

# check_ge <label> <got> <min>: a floor assertion for counters that legitimately grow
# with the number of arm cycles a scenario needs, so durability is proven as
# "never lost, only appended" rather than against a brittle exact constant.
check_ge() {
  local label=$1 got=$2 min=$3
  if [ -n "$got" ] && [ "$got" -ge "$min" ] 2>/dev/null; then printf 'ok   %s (>=%s)\n' "$label" "$min"
  else printf 'FAIL %s: got %s want >=%s\n' "$label" "$got" "$min"; FAILURES=$((FAILURES + 1)); fi
}

check_gt() {
  local label=$1 got=$2 floor=$3
  if [ -n "$got" ] && [ "$got" -gt "$floor" ] 2>/dev/null; then printf 'ok   %s (>%s)\n' "$label" "$floor"
  else printf 'FAIL %s: got %s want >%s\n' "$label" "$got" "$floor"; FAILURES=$((FAILURES + 1)); fi
}

printf '== busy burst: 22 actionable cycles while the agent is busy ==\n'
R=$(run_scenario busy-burst 22) || { echo "scenario busy-burst crashed"; FAILURES=$((FAILURES+1)); }
check "one outstanding queued watcher hint after 22 cycles" "$(field "$R" queueDepth)" "1"
check "all durable wake-queue events preserved" "$(field "$R" durable)" "23"
check "every queued hint is a watcher follow-up" "$(field "$R" allFollowUp)" "true"

printf '== consuming the queued hint mid-run releases the gate ==\n'
R=$(run_scenario consume-midrun) || { echo "scenario consume-midrun crashed"; FAILURES=$((FAILURES+1)); }
check "hint queued before consumption" "$(field "$R" depthBefore)" "1"
check "exact queued hint acknowledged at message_start" "$(field "$R" depthAfterConsume)" "0"
check "a genuinely later wake is delivered again" "$(field "$R" depthAfterNextWake)" "1"
check "later wake carries a unique id, not a replay" "$(field "$R" nextPromptDiffers)" "true"

printf '== unrelated starts must not acknowledge ==\n'
R=$(run_scenario unrelated-starts) || { echo "scenario unrelated-starts crashed"; FAILURES=$((FAILURES+1)); }
check "unrelated human prompt, message, and agent_end leave the hint queued" "$(field "$R" depthAfter)" "$(field "$R" depthBefore)"

printf '== critical failure is not swallowed by a pending ordinary hint ==\n'
R=$(run_scenario critical-after-ordinary) || { echo "scenario critical-after-ordinary crashed"; FAILURES=$((FAILURES+1)); }
[ -n "${FM_TEST_DEBUG:-}" ] && printf 'RAW: %s\n' "$R"
check "ordinary hint stays single while critical failure coalesces" "$(field "$R" depthWhilePending)" "1"
check "pending hint is not itself the failure" "$(field "$R" pendingIsOrdinary)" "true"
check "failure delivered as its own bounded notification after consumption" "$(field "$R" criticalDelivered)" "true"
check "critical notification consumed exactly once" "$(field "$R" criticalConsumed)" "true"

printf '== repeated identical failures dedupe while pending ==\n'
R=$(run_scenario repeated-critical) || { echo "scenario repeated-critical crashed"; FAILURES=$((FAILURES+1)); }
check "first critical failure queues exactly one notification" "$(field "$R" depthFirstCritical)" "1"
check "repeated failing cycles do not pile up" "$(field "$R" depthStillOne)" "1"
check "a distinct later failure delivers again" "$(field "$R" distinctLaterCritical)" "true"

printf '== send rejection releases the delivery reservation in the SAME generation ==\n'
R=$(run_scenario send-reject 0) || { echo "scenario send-reject crashed"; FAILURES=$((FAILURES+1)); }
[ -n "${FM_TEST_DEBUG:-}" ] && printf 'RAW: %s\n' "$R"
check "rejected send queues nothing" "$(field "$R" depthAfterReject)" "0"
check_ge "durable events survive a rejected send" "$(field "$R" durableAfterReject)" 1
check "a later cycle in the same generation delivers" "$(field "$R" depthAfterNextWake)" "1"
check "same-generation wake is a watcher follow-up" "$(field "$R" sameGenerationDelivered)" "true"
check_gt "durable events keep growing after the rejection" "$(field "$R" durableAfterNextWake)" "$(field "$R" durableAfterReject)"
check "the released reservation is consumable" "$(field "$R" firstConsumed)" "true"
check "notified again once consumed" "$(field "$R" depthAfterConsume)" "1"
check "the re-notified wake is not a replay" "$(field "$R" notifiedAgainAfterConsume)" "true"
check_ge "every durable wake event is still queued" "$(field "$R" durableAtEnd)" "$(field "$R" durableAfterNextWake)"

printf '== a rejected critical send keeps its evidence and later delivers ==\n'
R=$(run_scenario critical-reject) || { echo "scenario critical-reject crashed"; FAILURES=$((FAILURES+1)); }
[ -n "${FM_TEST_DEBUG:-}" ] && printf 'RAW: %s\n' "$R"
check "the rejected send was a critical failure" "$(field "$R" rejectedWasCritical)" "1"
check "the rejected evidence was the retry-exhaustion failure" "$(field "$R" rejectedRetryExhaustion)" "true"
check "a rejected critical queues nothing" "$(field "$R" depthAfterReject)" "0"
check_ge "durable events survive the rejected critical" "$(field "$R" durableAfterReject)" 1
check "a later ordinary cycle still delivers" "$(field "$R" depthAfterOrdinary)" "1"
check "the later wake is the ordinary hint" "$(field "$R" ordinaryDelivered)" "true"
check "the ordinary hint is consumable at message_start" "$(field "$R" ordinaryConsumed)" "true"
check "the retained critical then arrives alone" "$(field "$R" depthAfterOrdinaryConsumed)" "1"
check "the retained critical evidence is recovered" "$(field "$R" criticalRecovered)" "true"
check "the recovery is the retained failure, not a fresh one" "$(field "$R" criticalIsRetainedNotFresh)" "true"
check "the recovered critical is consumable exactly once" "$(field "$R" criticalConsumed)" "true"
check "the queue is drained afterwards" "$(field "$R" depthAtEnd)" "0"
check_ge "every durable wake event survived the rejection" "$(field "$R" durableAtEnd)" "$(field "$R" durableAfterReject)"

printf '== the real user message_start content-array consumption path ==\n'
R=$(run_scenario message-start-array) || { echo "scenario message-start-array crashed"; FAILURES=$((FAILURES+1)); }
[ -n "${FM_TEST_DEBUG:-}" ] && printf 'RAW: %s\n' "$R"
check "a watcher hint is queued before consumption" "$(field "$R" pendingBefore)" "1"
check "the queued hint is a watcher follow-up" "$(field "$R" pendingIsWatcherWake)" "true"
check "an assistant message_start does not acknowledge" "$(field "$R" assistantRoleDidNotAck)" "true"
check "non-exact user text does not acknowledge" "$(field "$R" nonExactTextDidNotAck)" "true"
check "the exact content array is consumed at message_start" "$(field "$R" arrayFormConsumed)" "true"
check "acknowledgement empties the queue" "$(field "$R" depthAfterArrayConsume)" "0"
check "a genuinely later wake is delivered again" "$(field "$R" depthAfterNextWake)" "1"
check "the later wake is distinct, not a replay" "$(field "$R" nextWakeIsDistinct)" "true"
check_ge "durable wake events are preserved" "$(field "$R" durable)" 2

printf '== a stale generation prompt cannot drain the live generation critical ==\n'
R=$(run_scenario stale-cannot-drain-critical) || { echo "scenario stale-cannot-drain-critical crashed"; FAILURES=$((FAILURES+1)); }
[ -n "${FM_TEST_DEBUG:-}" ] && printf 'RAW: %s\n' "$R"
check "the live generation holds one ordinary hint" "$(field "$R" depthWithCriticalCoalesced)" "2"
check "the live pending hint is the ordinary one" "$(field "$R" livePendingIsOrdinary)" "true"
check "the stale prompt delivers nothing" "$(field "$R" staleDeliveredNothing)" "true"
check "the stale prompt does not drain the coalesced critical" "$(field "$R" staleDidNotDrainUpgrade)" "true"
check "the stale prompt stays queued, unconsumed" "$(field "$R" staleStillQueued)" "true"
check "consuming the live wake does not consume the stale one" "$(field "$R" liveStaleNotConsumed)" "true"
check "the critical upgrade fires only after the live ack" "$(field "$R" upgradeAfterLiveConsume)" "true"
check "the upgrade is queued on top of the stale hint" "$(field "$R" depthAfterUpgrade)" "2"

printf '== stale generation cannot ack or replay ==\n'
R=$(run_scenario stale-generation) || { echo "scenario stale-generation crashed"; FAILURES=$((FAILURES+1)); }
check "stale-generation ack attempts deliver nothing" "$(field "$R" staleAckSendsNothing)" "true"
check "new generation wake delivered" "$(field "$R" freshWakeDelivered)" "true"
check "new wake id differs from stale prompt" "$(field "$R" freshIdDiffers)" "true"
check "the queue is strictly oldest-first, not LIFO" "$(field "$R" queueOrderOldestFirst)" "true"
check "stale prompt cannot ack the new pending wake" "$(field "$R" staleCannotAckNew)" "true"
check "the stale hint is still queued after the replay attempt" "$(field "$R" staleStillQueuedAfterReplay)" "true"
check "consuming the live wake does not consume the stale hint" "$(field "$R" staleNotConsumedWithLive)" "true"
check "acknowledging the new wake sends no extra" "$(field "$R" newAckSendsNoExtra)" "true"
check "consuming the stale hint afterwards sends no extra" "$(field "$R" staleConsumeSendsNoExtra)" "true"
check "the queue is drained at the end" "$(field "$R" depthAtEnd)" "0"

printf '\n'
if [ "$FAILURES" -eq 0 ]; then echo "ALL TESTS PASSED"; exit 0; fi
printf '%s TEST(S) FAILED\n' "$FAILURES"; exit 1
