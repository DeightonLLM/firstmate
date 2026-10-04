# DeepSeek Harness Installation & Verification Report

- **Date:** 2026-09-28
- **Target Host:** `brandon-compute` (via `ssh brandon-compute`)
- **Install Directory:** `/opt/deepseek-harness`
- **Owner / Permissions:** `hd2admin:hd2admin` (755)
- **Status:** Complete & Verified

---

## 1. Executive Summary

DeepSeek Harness (`dsh`) version `0.2.0-rc.1` has been installed and verified on `brandon-compute`.
All installations and builds were strictly contained within `/opt/deepseek-harness` using user-local Node.js (via Corepack and pnpm). No system packages, system services, Docker containers, or running Pi agents were altered.

---

## 2. Preflight Findings

1. **Disk Headroom:**
   - Command: `df -h /`
   - Filesystem `/dev/md2` available space: **358 GB** free out of 437 GB (well exceeds the 20 GB minimum requirement).
2. **User & Environment:**
   - User: `hd2admin` (UID 1000, GID 1000)
   - OS: Linux 6.8.0-139-generic x86_64 (Ubuntu)
   - Node.js: `v22.23.2` at `/home/hd2admin/.nvm/versions/node/v22.23.2/bin/node` (satisfies the repo's `>= 22.19` requirement).
   - Package Manager: `corepack enable` activated Corepack; pnpm was resolved directly to pinned version `11.7.0`.
   - Git: `2.43.0`

---

## 3. Installation Details

- **Repository:** `https://github.com/deepseek-ai/deepseek-harness`
- **Checked-out Commit:** `4878cdabd87d4041bdaff61d04c966883b9fd07a`
- **Tag / Release:** `0.2.0-rc.1` (`release(dsh): 0.2.0-rc.1 (#5387)`)
- **Directory:** `/opt/deepseek-harness`
- **Steps executed:**
  1. Cloned repository into `/opt/deepseek-harness`.
  2. Activated Corepack for user `hd2admin` (`corepack enable`).
  3. Installed dependencies: `pnpm install` (resolved and fetched 1,400 packages in 10.4s).
  4. Built workspace artifacts: `pnpm run build` (compiled host runtime, client bundles, and generated 347 client artifacts).

---

## 4. Smoke Check & Verification Evidence

### A. CLI Version and Help
```sh
$ cd /opt/deepseek-harness && pnpm dsh --version
0.2.0-rc.1

$ cd /opt/deepseek-harness && pnpm dsh --help
Usage: dsh [--profile] <name> [options] [app-args...]
       dsh plugin --profile <name> <pnpm-args...>

dsh: boot a DeepSeek Harness profile — an ordered stack of plugin-bundle patch
layers under your own overrides.
...
```

### B. Invariant & Architecture Verification Scripts
- **Application Entrypoints:**
  ```sh
  $ pnpm run verify-application-entrypoints
  verify-application-entrypoints: dsh is the only supported Node application launcher.
  ```
- **Runtime Closure:**
  ```sh
  $ pnpm run verify-runtime-closure
  verify-runtime-closure: 4 agent presets and 177 workspace packages form a closed runtime dependency graph.
  ```

### C. Typecheck & Contract Verification
- Command: `pnpm run typecheck`
- Output: Successfully validated all client contracts and TypeScript compilation across all 339 workspace projects with exit code 0.

### D. Unit Test Verification
- Command: `pnpm exec vitest run packages/preset/agent-preset-registry/tests/invariant.spec.ts`
- Result: `2 passed (2)` in 50ms.

### E. Live Server Startup Test
- Command: `pnpm dsh web --no-open --port 3088`
- Result: Successfully booted web profile and produced token-secured URL:
  `dsh web: http://127.0.0.1:3088/?token=<TOKEN>`
- Connectivity test: HTTP requests without token received expected `401 Unauthorized` security enforcement.

*Note regarding port 3080:* Port 3080 is currently bound by an existing background process (`pid 98507`, launched via `npx @deepseek-ai/dsh web` on Sep 27). The newly installed build can run on any port (such as 3088), or the operator may stop the older process.

---

## 5. Operator Launch Guide

### Web UI
To launch the Web UI on an available port (e.g. 3088):
```sh
ssh brandon-compute
cd /opt/deepseek-harness
pnpm dsh web --no-open --port 3088
```
To access from a local machine, forward the port via SSH:
```sh
ssh -L 3088:127.0.0.1:3088 brandon-compute
```
Then navigate in your browser to the URL printed in the console (including the token parameter `?token=...`).

### Headless Mode
To run a single automated task from the CLI:
```sh
cd /opt/deepseek-harness
pnpm dsh headless "your task description"
```

### TUI Mode
To run the terminal user interface:
```sh
cd /opt/deepseek-harness
pnpm dsh tui
```

---

## 6. Exact Rollback Procedure

To completely remove DeepSeek Harness and revert all changes on `brandon-compute`:
```sh
sudo rm -rf /opt/deepseek-harness
```
*(Optional: clear user pnpm/corepack caches if desired: `rm -rf /home/hd2admin/.cache/node/corepack`)*

---

## 7. Operator Decisions & Next Steps

1. **API Keys:**
   - DeepSeek Harness requires an LLM API key for active agent turns (e.g. `DEEPSEEK_API_KEY`). Configure this in your environment or profile configuration before running agent sessions.
2. **Port 3080 Disposition:**
   - Process `pid 98507` (`node /home/hd2admin/.npm/_npx/1e7f6d9597241db0/node_modules/.bin/dsh web`) is currently holding port 3080. If you wish the new build to use default port 3080, terminate `pid 98507`:
     ```sh
     kill 98507
     ```
3. **Model Configuration:**
   - Review provider settings in `$DSH_HOME/profiles` or pass custom `--patch` configs to select model providers and parameters.
