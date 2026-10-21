import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { encodeFirstmateOperationalInput } from "./lib/fm-operational-input.ts";

let guardFollowupActive = false;

type LockOwnership = "owned" | "missing" | "other";

const extensionFile = fileURLToPath(import.meta.url);
const extensionDir = dirname(extensionFile);
const root = resolve(extensionDir, "../..");
const fmHome = process.env.FM_HOME || process.env.FM_ROOT_OVERRIDE || root;
const state = process.env.FM_STATE_OVERRIDE || `${fmHome}/state`;
const marker = `${state}/.pi-turnend-extension-loaded`;
const autoHandoffPath = process.env.FM_AUTO_HANDOFF_PATH || "/root/bin/auto-handoff";
const guardAttestPath = process.env.FM_GUARD_ATTEST_PATH || "/root/bin/guard-attest";
const handoffPath = process.env.FM_HANDOFF_PATH || `${fmHome}/data/HANDOFF-AUTO.md`;
const extensionVersion = `sha256:${createHash("sha256").update(readFileSync(extensionFile)).digest("hex")}`;

function parentPid(pid: string): string {
  const result = spawnSync("ps", ["-o", "ppid=", "-p", pid], { encoding: "utf8" });
  if (result.status !== 0) return "";
  return result.stdout.trim();
}

function pidAlive(pid: string): boolean {
  try {
    process.kill(Number(pid), 0);
    return true;
  } catch {
    return false;
  }
}

function lockOwnership(): LockOwnership {
  let lockPid = "";
  try {
    lockPid = readFileSync(`${state}/.lock`, "utf8").trim();
  } catch {
    return "missing";
  }
  if (!/^[0-9]+$/.test(lockPid) || lockPid === "1") return "other";
  let pid = String(process.pid);
  for (let i = 0; i < 8; i += 1) {
    if (pid === lockPid) return "owned";
    pid = parentPid(pid);
    if (!pid || pid === "1") break;
  }
  return pidAlive(lockPid) ? "other" : "missing";
}

function markLoaded(): void {
  if (!existsSync(state) || lockOwnership() === "other") return;
  writeFileSync(marker, `${extensionVersion}\n${process.pid}\n`);
}

function runSessionstartNudge(): string {
  const result = spawnSync(`${root}/bin/fm-sessionstart-nudge.sh`, [], { encoding: "utf8" });
  if (result.status !== 0) return "";
  return result.stdout.trim();
}

function runGuard(): Promise<{ code: number; stderr: string }> {
  return new Promise((resolveResult) => {
    const child = spawn(`${root}/bin/fm-turnend-guard.sh`, {
      stdio: ["pipe", "ignore", "pipe"],
    });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", () => resolveResult({ code: 0, stderr: "" }));
    child.on("close", (code) => resolveResult({ code: code ?? 0, stderr }));
    child.stdin.end('{"stop_hook_active":false}');
  });
}

// PreToolUse seatbelts (bin/fm-arm-pretool-check.sh, docs/arm-pretool-check.md;
// bin/fm-cd-pretool-check.sh, docs/cd-guard.md). Both piggyback on this same
// extension file rather than separate ones so no extra Pi -e flag is needed at
// launch - the primary already loads this file for the turn-end guard, and
// pi.on("tool_call", ...) can block (verified 2026-07-09 against pi 0.80.5:
// returning {block: true} prevents the bash command from running). Each owner
// script owns its own decision and is inert outside the real primary checkout.
function runChecker(script: string, command: string): Promise<{ code: number; stderr: string }> {
  return new Promise((resolveResult) => {
    const child = spawn(`${root}/bin/${script}`, ["--command", command], {
      stdio: ["ignore", "ignore", "pipe"],
    });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", () => resolveResult({ code: 0, stderr: "" }));
    child.on("close", (code) => resolveResult({ code: code ?? 0, stderr }));
  });
}

function runPretoolCheck(command: string): Promise<{ code: number; stderr: string }> {
  return runChecker("fm-arm-pretool-check.sh", command);
}

function runCdCheck(command: string): Promise<{ code: number; stderr: string }> {
  return runChecker("fm-cd-pretool-check.sh", command);
}

// Degradation trip-wire (2026-10-15). The 2026-10-15 session degraded at 37% of
// context — repeated outputs, re-run checks, narrowing focus — and compaction was
// never the cause, so no context limit would have caught it. This counts repeated
// tool signatures across the session and, at the limit, writes an auto-handoff and
// injects a follow-up telling the session to hand back control.
const DEGRADATION_LIMIT = 3;
const DEGRADATION_WINDOW = 40;
let actionCounts = new Map<string, { count: number; stamps: number[] }>();
let degradationInjected = false;

function actionSignature(command: string): string {
  const lines = command.split(/\r?\n/).filter((l) => l.trim().length > 0 && !/^\s*#/.test(l));
  const head = (lines[0] ?? "").replace(/\s+/g, " ").trim().slice(0, 60);
  const tail = (lines[lines.length - 1] ?? "").replace(/\s+/g, " ").trim().slice(0, 40);
  return `${lines.length}|${head}|${tail}`;
}

function degradationTripwire(command: string): { tripped: boolean; detail: string } {
  const sig = actionSignature(command);
  const now = Date.now();
  const prior = actionCounts.get(sig) ?? { count: 0, stamps: [] };
  prior.count += 1;
  prior.stamps = prior.stamps.filter((t) => now - t < DEGRADATION_WINDOW * 1000);
  prior.stamps.push(now);
  actionCounts.set(sig, prior);
  return {
    tripped: prior.count >= DEGRADATION_LIMIT,
    detail: `"${sig}" seen ${prior.count} times in the last ${DEGRADATION_WINDOW} tool calls`,
  };
}

// Write the auto-handoff from live files when the trip-wire trips, so the session
// hands back with real state rather than a summary the model composed.
function attest(name: string, result: "FIRED" | "CLEAR" | "ERROR", detail: string): void {
  spawnSync(guardAttestPath, ["run", name, result, detail.slice(0, 160)], {
    encoding: "utf8",
    timeout: 30000,
  });
}

function hasInFlightWork(): { active: boolean; fingerprint: string } {
  const inputs: Array<[string, string]> = [];
  const laneFile = `${state}/.factory-lanes.tsv`;
  if (existsSync(laneFile)) {
    const lanes = readFileSync(laneFile, "utf8");
    if (lanes.split(/\r?\n/).some((line) => line.trim() && !/^\s*(?:lane(?:\s|$)|#)/i.test(line))) {
      inputs.push([laneFile, lanes]);
    }
  }

  const inbox = `${fmHome}/INBOX`;
  if (existsSync(inbox)) {
    for (const name of readdirSync(inbox).filter((entry) => entry.endsWith(".md") && entry !== "README.md").sort()) {
      const file = `${inbox}/${name}`;
      inputs.push([file, readFileSync(file, "utf8")]);
    }
  }

  const attestDir = `${state}/attestations`;
  if (existsSync(attestDir)) {
    for (const name of readdirSync(attestDir).filter((entry) =>
      entry.endsWith(".tsv") && !["auto-handoff.tsv", "turn-end-handoff.tsv", "degradation-tripwire.tsv"].includes(entry),
    ).sort()) {
      const file = `${attestDir}/${name}`;
      const contents = readFileSync(file, "utf8");
      const last = contents.trimEnd().split(/\r?\n/).at(-1) ?? "";
      if (last.split("\t")[2] === "FIRED") inputs.push([file, contents]);
    }
  }

  const imports = `${fmHome}/data/imports-20261015`;
  if (existsSync(imports)) {
    for (const name of readdirSync(imports).sort()) {
      const dir = `${imports}/${name}`;
      if (!statSync(dir).isDirectory()) continue;
      const report = `${dir}/report.md`;
      if (!existsSync(report)) continue;
      const contents = readFileSync(report, "utf8");
      if (/^VERDICT:\s*PASS\b/m.test(contents)) inputs.push([report, contents]);
    }
  }

  const digest = createHash("sha256");
  for (const [path, contents] of inputs) digest.update(path).update("\0").update(contents).update("\0");
  return { active: inputs.length > 0, fingerprint: digest.digest("hex") };
}

function writeStopHandoff(): void {
  const { active, fingerprint } = hasInFlightWork();
  const reason = `turn-end ${active ? `in-flight sha256:${fingerprint}` : "idle"}`;
  if (active && existsSync(handoffPath) && readFileSync(handoffPath, "utf8").includes(reason)) {
    attest("turn-end-handoff", "FIRED", `current ${fingerprint}`);
    return;
  }
  if (active) {
    const result = spawnSync(autoHandoffPath, [reason, handoffPath], {
      encoding: "utf8",
      timeout: 120000,
    });
    if (result.status !== 0 || !existsSync(handoffPath)) {
      attest("turn-end-handoff", "ERROR", `handoff write failed: ${result.status ?? "spawn"}`);
      return;
    }
    attest("turn-end-handoff", "FIRED", `written ${fingerprint}`);
  } else {
    attest("turn-end-handoff", "CLEAR", "no in-flight work");
  }
}

function runDegradationHandoff(detail: string): void {
  const out = spawnSync(autoHandoffPath, ["degradation trip-wire: " + detail, handoffPath], {
    encoding: "utf8",
    timeout: 120000,
  });
  try {
    writeFileSync(`${state}/.degradation-handoff-last`, `${Date.now()}\n${detail}\n${out.stdout ?? ""}`, { mode: 0o600 });
  } catch {
  }
  attest("degradation-tripwire", out.status === 0 && existsSync(handoffPath) ? "FIRED" : "ERROR", detail);
}

export default function (pi: ExtensionAPI) {
  pi.on?.("session_start", (event) => {
    const reason = String((event as { reason?: unknown }).reason ?? "");
    const nudge = ["startup", "new", "resume"].includes(reason) ? runSessionstartNudge() : "";
    markLoaded();
    if (!nudge) return;
    try {
      pi.sendMessage({
        customType: "firstmate-sessionstart-nudge",
        content: nudge,
        display: false,
        details: { kind: "session-start" },
      });
    } catch {
    }
  });

  pi.on("tool_call", async (event) => {
    if (event.type !== "tool_call" || event.toolName !== "bash") return {};
    const command = String((event.input as { command?: unknown })?.command ?? "");
    if (!command) return {};
    const cdResult = await runCdCheck(command);
    if (cdResult.code === 2) {
      return { block: true, reason: cdResult.stderr.trim() || "denied by the cd-guard PreToolUse seatbelt" };
    }
    const result = await runPretoolCheck(command);
    if (result.code !== 2 && !degradationInjected) {
      const trip = degradationTripwire(command);
      if (trip.tripped) {
        degradationInjected = true;
        try {
          await runDegradationHandoff(trip.detail);
        } catch {
        }
        return {
          block: true,
          reason:
            "DEGRADATION TRIP-WIRE: " +
            trip.detail +
            ". Repetition is the failure mode no context limit catches. " +
            "Write the handoff, hand back control, and stop. Re-arm the trip-wire after the handoff.",
        };
      }
    }
    if (result.code !== 2) return {};
    return { block: true, reason: result.stderr.trim() || "denied by the watcher-arm PreToolUse seatbelt" };
  });

  pi.on("agent_settled", async () => {
    writeStopHandoff();
    if (guardFollowupActive) {
      guardFollowupActive = false;
      return;
    }

    // Clear the degradation latch on a settled turn that was not tripped, so a
    // genuinely new action pattern is never blocked by a stale repeat count.
    if (!degradationInjected) {
      actionCounts.clear();
    }


    const result = await runGuard();
    if (result.code !== 2) return;

    guardFollowupActive = true;
    try {
      const content = encodeFirstmateOperationalInput(
        "turn-end-guard",
        "TURN WOULD END BLIND - supervision is off. " +
          "The watcher cycle is missing, failed, or unhealthy. Follow the harness recovery instruction below before ending the turn.\n\n" +
          result.stderr,
      );
      await pi.sendUserMessage(content, { deliverAs: "followUp" });
    } catch {
      guardFollowupActive = false;
    }
  });

  markLoaded();
}
