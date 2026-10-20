# Exact tracker provider verification - primary correction

At2026-10-13 primary ran `pi list` read-only; it lists npm:@juicesharp/rpiv-todo@2.12.0 at /home/hd2admin/.pi/agent/npm/node_modules/@juicesharp/rpiv-todo.
Fresh exact ctx_read of that package.json succeeded: name @juicesharp/rpiv-todo, version2.12.0, Pi extensions ./index.ts, files include task-graph/reducer and tool sources; dependency @juicesharp/rpiv-config^2.12.0.

Thus the child-readiness.md conclusion that no active dependency-aware provider exists based on empty ctx_ls/find results is NOT established and package absence is disproven. Listing behavior/root scoping/gitignore may explain omitted files, but that cause is not proven. Disabled old todo.ts and stock Pi example do not determine the installed rpiv provider's capabilities.

Existing lead was told to inspect exact named installed provider files and revise minimal scout-only config draft; no package install, plugin/source/config write or new child launch. Actual child loading, dependency support and noninteractive-visible result behavior still require source/behavioral proof. This evidence does not claim child capability repair or live proof.
