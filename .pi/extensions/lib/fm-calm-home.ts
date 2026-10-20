// Firstmate home resolution for the home-local Calm preference.
//
// docs/configuration.md owns the home-local Calm preference contract. The
// extension path only names a Firstmate home when Calm is installed
// project-local (…/<home>/.pi/extensions/fm-calm.ts). An account-level install
// (…/.pi/agent/extensions/fm-calm.ts) sits outside every home, so deriving the
// home from the extension path alone would give every home one shared
// preference file. The session's own working directory is the signal that
// separates them.
import { statSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";

export type CalmHomeSource =
  | "explicit"
  | "project-extension"
  | "session"
  | "extension-root";

export type CalmHomeResolution = {
  home: string;
  source: CalmHomeSource;
};

const MAX_HOME_LOOKUP_DEPTH = 64;

function isDirectory(path: string): boolean {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

// A Firstmate home carries its own private config/, data/ and state/
// directories. The markers are deliberately narrow: an ordinary project
// directory, the OS home or the Pi account directory must never be mistaken
// for a home, because writing a preference there would move a home-local
// choice to a shared location.
export function isFirstmateHome(candidate: string): boolean {
  return (
    isDirectory(resolve(candidate, "config")) &&
    isDirectory(resolve(candidate, "data")) &&
    isDirectory(resolve(candidate, "state"))
  );
}

// The nearest enclosing Firstmate home of a directory, or undefined when that
// directory belongs to no home.
export function findFirstmateHome(startDirectory?: string): string | undefined {
  if (!startDirectory) return undefined;
  let current = resolve(startDirectory);
  for (let depth = 0; depth < MAX_HOME_LOOKUP_DEPTH; depth += 1) {
    if (isFirstmateHome(current)) return current;
    const parent = dirname(current);
    if (parent === current) return undefined;
    current = parent;
  }
  return undefined;
}

// The home that owns a project-local Calm install, or undefined for an
// account-level install, whose extension directory belongs to no home.
export function projectExtensionHome(extensionDir: string): string | undefined {
  if (basename(extensionDir) !== "extensions") return undefined;
  if (basename(dirname(extensionDir)) !== ".pi") return undefined;
  const candidate = resolve(extensionDir, "../..");
  return isFirstmateHome(candidate) ? candidate : undefined;
}

// Resolve the effective Firstmate home for the Calm preference.
//
// Precedence: an explicit home (FM_HOME, then FM_ROOT_OVERRIDE), then the home
// that owns a project-local extension, then the session's own home, then the
// extension-derived root. The project-local branch keeps every existing
// project-local install on exactly the home it already used; the session
// branch is what keeps an account-level install from collapsing every home
// onto one shared preference file.
export function resolveCalmHome(options: {
  extensionDir: string;
  sessionCwd?: string | undefined;
  env?: Record<string, string | undefined>;
}): CalmHomeResolution {
  const env = options.env ?? process.env;
  const explicit = env.FM_HOME || env.FM_ROOT_OVERRIDE;
  if (explicit) return { home: resolve(explicit), source: "explicit" };

  const projectHome = projectExtensionHome(options.extensionDir);
  if (projectHome) return { home: projectHome, source: "project-extension" };

  const sessionHome = findFirstmateHome(options.sessionCwd);
  if (sessionHome) return { home: sessionHome, source: "session" };

  return {
    home: resolve(options.extensionDir, "../.."),
    source: "extension-root",
  };
}
