# Lean-ctx Task-Scoped Repository Mapping Strategy

## Core Principles

1. **No Automatic Full Scans**: Full-repository mapping must not run automatically on routine agent tasks.
2. **Task-Scoped Discovery**: Begin every task with session restoration (`ctx_session(action: "load")`), record the task scope (`ctx_session(action: "task", value: "...")`), and inspect named targets before expanding scope.
3. **Progressive Disclosure**: Use targeted, shallow searches and tree listings before invoking wider context mapping.
4. **Session Caching**: Reusable context and file maps are stored within Lean-ctx's active session state and refreshed incrementally after edits.

---

## Decision Table: Task Shape to Lean-ctx Operation

| Task Shape | Lean-ctx Operation | Target Scope | Session & Cache Behavior |
| ---------- | ------------------ | ------------ | ------------------------ |
| **Known-file edit** | `ctx_read(path, "full")` | Specific file path | Direct read; no directory scan |
| **Named bug** | `ctx_search(pattern, path)` | Feature or package subdirectory | Locate target pattern; cache file reference |
| **Unfamiliar module** | `ctx_tree(path)` / `ctx_compose` | Specific module directory | Generate localized tree map; save to session |
| **Cross-service incident** | `ctx_search(pattern, service_dir)` | Targeted service directories | Search affected microservice directories only |
| **Prompt generation** | `ctx_read(spec_path)` | Explicit specification files | Read input docs; no repo scan |
| **Documentation reconciliation** | `ctx_read` + `ctx_search` | Specific doc and code paths | Scope to diffed files and target docs |
| **Full architecture audit** | `ctx_overview` / full `ctx_tree` | Workspace root (`/root`) | Perform initial scan only when explicitly authorized |

---

## Excluded / Non-Preloaded Paths

Agents must **never** preload or broadly scan:
- Full Git history logs (`git log` without limits);
- Historical roadmaps, past closeouts, or archived task folders unless requested;
- Build artifacts (`dist/`, `build/`, `node_modules/`, `.next/`, `target/`);
- System backups or quarantine directories;
- Dependency trees or vendor packages;
- Environment files (`.env`), credentials, or secret stores.
