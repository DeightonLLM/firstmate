// Pi PreToolUse guard: a secondmate home may never take the controller's own
// Pi watcher seat.
//
// Authority model: only the primary home owns the controller seats. A home
// whose root carries a genuine .fm-secondmate-home identity marker (written by
// bin/fm-home-seed.sh, validated by secondmate-provisioning, documented in
// docs/configuration.md) is a secondmate, so it may never call the primary's
// Pi watcher tool fm_watch_arm_pi. A secondmate routes that one call to the
// primary firstmate instead.
//
// What a secondmate may NOT be denied is its OWN supervision. The per-home
// bin/fm-session-start.sh and bin/fm-watch-arm.sh are legitimate inside a
// secondmate home, and blocking them would break a seeded home at startup:
//   - its charter tells it to "run normal firstmate bootstrap and recovery
//     through bin/fm-session-start.sh for your own home" (bin/fm-brief.sh),
//   - bin/fm-watch-arm.sh --restart resolves exactly THIS home's watcher pid
//     from this home's state/.watch.lock, so it can never touch a sibling
//     (see its header on why `pkill -f bin/fm-watch.sh` is forbidden), and
//   - bin/fm-turnend-guard.sh already treats a marked home as running its own
//     primary firstmate session.
// So the deny list is exactly one call. There is no bash classifier here: a
// command string is not a reliable identity for a seat, and a home that
// legitimately runs both scripts must not be told otherwise.
//
// Everything else is allowed, and a home WITHOUT a genuine marker is never
// denied: this guard keys on the session home root (FM_HOME, then
// FM_ROOT_OVERRIDE, then the checkout holding this extension) and returns {}
// for every call whenever that root has no genuine marker. It therefore cannot
// fault a primary home even if it is loaded there by mistake.
//
// The marker predicate below mirrors fm_root_is_secondmate_home in
// bin/fm-primary-scope-lib.sh exactly, including its edge semantics, so the
// two layers cannot drift into disagreeing about which home this is: a
// symlinked marker, a marker that is not a regular file, a marker whose first
// line is empty or whitespace-only, an id outside [A-Za-z0-9._-], and a marker
// with no trailing newline are all NOT secondmate homes; only the FIRST line
// is read and ALL ASCII whitespace in it is stripped before the charset test.
// Seeding always writes the id with a trailing newline.
//
// The decision is Pi-native: returning { block: true, reason } from a
// tool_call listener stops the call before the tool runs (verified against
// pi 0.80.5 in .pi/extensions/fm-primary-turnend-guard.ts, which blocks
// execution the same way). Nothing here executes, sources, or evaluates the
// submitted command, and the guard holds no mutable state.
//
// Colocated test: .pi/extensions/fm-secondmate-guard.test.sh
import { lstatSync, readFileSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const extensionRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

// A home carrying a genuine version of this marker is a secondmate, not a
// controller.
const HOME_MARKER = ".fm-secondmate-home";
// The single controller seat a secondmate may never take.
const CONTROLLER_TOOL = "fm_watch_arm_pi";
// The id charset the shell predicate accepts, after stripping whitespace.
const VALID_ID = /^[A-Za-z0-9._-]+$/;
// Exactly the ASCII set bash's [[:space:]] removes under LC_ALL=C, which is the
// locale fm_root_is_secondmate_home pins before stripping the id.
const ASCII_WHITESPACE = /[ \t\n\v\f\r]/g;

function homeRoot(): string {
  return process.env.FM_HOME || process.env.FM_ROOT_OVERRIDE || extensionRoot;
}

// Mirrors fm_root_is_secondmate_home (bin/fm-primary-scope-lib.sh). A marker
// that is merely PRESENT is not enough: the shell accepts a home only when the
// marker is a real file holding a real id, and this guard must agree, or one
// layer would arm a controller the other believes is a secondmate.
function isSecondmateHome(): boolean {
  const marker = `${homeRoot()}/${HOME_MARKER}`;
  try {
    // [ -L "$marker" ] && return 1: a symlink is rejected even when it points
    // at a perfectly good marker.
    if (lstatSync(marker).isSymbolicLink()) return false;
    // [ -f "$marker" ] || return 1: a directory or device is not a marker.
    if (!statSync(marker).isFile()) return false;
  } catch {
    return false;
  }

  let content: string;
  try {
    content = readFileSync(marker, "utf8");
  } catch {
    return false;
  }

  // `IFS= read -r id < marker` reads the FIRST line and returns non-zero when
  // it hits EOF with no newline, which the shell treats as no marker at all.
  const newline = content.indexOf("\n");
  if (newline === -1) return false;

  // id=${id//[[:space:]]/} strips whitespace everywhere in the line, not just
  // around it, then [ -n "$id" ] and the [A-Za-z0-9._-] case test follow.
  const id = content.slice(0, newline).replace(ASCII_WHITESPACE, "");
  if (!id) return false;
  return VALID_ID.test(id);
}

function denyReason(what: string): string {
  return (
    `fm-secondmate-guard: denied - this session's home root has a genuine ${HOME_MARKER} marker, so it is a ` +
    `secondmate home, and a secondmate may never take the controller's own watcher seat. Blocked: ${what}. ` +
    `Route watcher arming to the primary firstmate instead. This guard does NOT block this home's own ` +
    `bin/fm-session-start.sh or bin/fm-watch-arm.sh: those are legitimate per-home supervision in a secondmate home.`
  );
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    if (event.type !== "tool_call") return {};
    if (!isSecondmateHome()) return {};
    const toolName = String((event as { toolName?: unknown }).toolName ?? "");
    if (toolName !== CONTROLLER_TOOL) return {};
    return { block: true, reason: denyReason(`the ${CONTROLLER_TOOL} tool call`) };
  });
}
