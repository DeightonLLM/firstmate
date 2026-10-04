// Pi PreToolUse guard: a secondmate home may never act as a controller.
//
// Authority model: only the primary home owns the controller seats. A home
// whose root carries the .fm-secondmate-home identity marker (written by
// bin/fm-home-seed.sh, validated by secondmate-provisioning, documented in
// docs/configuration.md) is a secondmate, so it may never run the two
// controller entry points - bin/fm-session-start.sh and bin/fm-watch-arm.sh -
// and may never call the controller's own Pi watcher tool fm_watch_arm_pi.
// A secondmate routes that work to the primary firstmate instead.
//
// Everything else is allowed, and a home WITHOUT the marker is never denied:
// this guard keys on the session home root (FM_HOME, then FM_ROOT_OVERRIDE,
// then the checkout holding this extension) and returns {} for every call
// whenever that root has no marker. It therefore cannot fault a primary home
// even if it is loaded there by mistake.
//
// The decision is Pi-native: returning { block: true, reason } from a
// tool_call listener stops the call before the tool runs (verified against
// pi 0.80.5 in .pi/extensions/fm-primary-turnend-guard.ts, which blocks
// execution the same way). Nothing here executes, sources, or evaluates the
// submitted command, and the guard holds no mutable state.
//
// Colocated test: .pi/extensions/fm-secondmate-guard.test.sh
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const extensionRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

// A home carrying this marker is a secondmate, not a controller.
const HOME_MARKER = ".fm-secondmate-home";
// The controller seats a secondmate may never take.
const CONTROLLER_SCRIPTS = ["fm-session-start.sh", "fm-watch-arm.sh"];
const CONTROLLER_TOOL = "fm_watch_arm_pi";
// Leading words that hand the rest of a segment to a shell or a runner, so
// `bash bin/fm-session-start.sh` and `env FOO=1 bin/fm-watch-arm.sh` are still
// invocations of the script rather than invocations of the wrapper.
const WRAPPERS = new Set([
  "bash",
  "sh",
  "zsh",
  "ksh",
  "dash",
  "env",
  "exec",
  "source",
  ".",
  "nohup",
  "time",
  "sudo",
  "xargs",
]);

function homeRoot(): string {
  return process.env.FM_HOME || process.env.FM_ROOT_OVERRIDE || extensionRoot;
}

function isSecondmateHome(): boolean {
  return existsSync(`${homeRoot()}/${HOME_MARKER}`);
}

// Strip the cheap obfuscation the arm prefilter also strips (line
// continuations, quotes, CR) so `bin/fm-watc\<newline>h-arm.sh` and
// 'bin/fm-watch-arm.sh' classify as the plain invocations they are. A newline
// that is not a continuation stays a separator.
function normalize(command: string): string {
  return command.replace(/\\\r?\n/g, "").replace(/["'`]/g, "").replace(/\r/g, "");
}

function basename(token: string): string {
  const parts = token.split("/");
  return parts[parts.length - 1] ?? "";
}

function isControllerScript(token: string): boolean {
  return CONTROLLER_SCRIPTS.includes(basename(token));
}

// Split on the operators that begin a new simple command, so a controller
// script is found in any position, not only the first segment.
function segments(command: string): string[] {
  return normalize(command)
    .split(/(?:;|&&|\|\||\||&|\n)/)
    .map((segment) => segment.trim())
    .filter(Boolean);
}

function deniesSegment(segment: string): boolean {
  const tokens = segment.split(/\s+/).filter(Boolean);
  if (!tokens.length) return false;
  // A shell or runner wrapper makes any named controller script in the
  // segment an invocation, including one behind wrapper flags such as
  // `sudo -u fm bin/fm-watch-arm.sh`.
  if (WRAPPERS.has(tokens[0])) return tokens.some(isControllerScript);
  // Otherwise only the command word itself is an invocation, so a read that
  // merely names the file (`cat bin/fm-watch-arm.sh`) stays allowed. Leading
  // VAR=value assignments are also inspected, because that is how a command
  // word can be smuggled in for later expansion (`ARM=bin/fm-watch-arm.sh;
  // "$ARM"`).
  let index = 0;
  let smuggled = false;
  for (; index < tokens.length; index += 1) {
    const assignment = /^[A-Za-z_][A-Za-z0-9_]*=/.exec(tokens[index]);
    if (!assignment) break;
    if (isControllerScript(tokens[index].slice(assignment[0].length))) smuggled = true;
  }
  return smuggled || isControllerScript(tokens[index] ?? "");
}

function denyReason(what: string): string {
  return (
    `fm-secondmate-guard: denied - this session's home root has the ${HOME_MARKER} marker, so it is a ` +
    `secondmate home and a secondmate may never act as a controller. Blocked: ${what}. ` +
    `Route this to the primary firstmate instead of running it here.`
  );
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (event.type !== "tool_call") return {};
    if (!isSecondmateHome()) return {};
    const toolName = String((event as { toolName?: unknown }).toolName ?? "");
    if (toolName === CONTROLLER_TOOL) {
      return { block: true, reason: denyReason(`the ${CONTROLLER_TOOL} tool call`) };
    }
    if (toolName !== "bash") return {};
    const command = String((event as { input?: { command?: unknown } }).input?.command ?? "");
    if (!command) return {};
    const denied = segments(command).find((segment) => deniesSegment(segment));
    if (!denied) return {};
    return { block: true, reason: denyReason(`bash: ${command}`) };
  });
}
