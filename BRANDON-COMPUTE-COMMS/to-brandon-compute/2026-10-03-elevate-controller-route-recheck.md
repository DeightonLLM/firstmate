# Controller-provided Elevate route recheck (read-only)

Captured 2026-10-03. This evidence supplements the existing Elevate outage work order; it does not enlarge its write boundary.

## Confirmed host distinction

- Physical `hd2stack` is Contabo `vmi3238503`, a separate coding-capable host. Its Herdr machine profile is now registered as `hd2stack`; its remote Herdr inventory currently shows only a root shell, not a Secondmate home or agent.
- The existing `hd2stack` Secondmate home `/root/secondmates/hd2stack` and pane `wD6:p3` are controller-local. Do not treat that home as running on the physical Contabo host.
- The Elevate service probe in this task targets `brandon-compute:3001`, not physical `hd2stack`.

## Live, read-only Elevate evidence

- The public Elevate page references `https://agents.elevatesci.com/api/embed` and `https://agents.elevatesci.com/embed/anythingllm-chat-widget.min.js`.
- Public `GET https://agents.elevatesci.com/api/embed` returned HTTP 200 with `text/html`, not API data. The public root page SHA-256 was `ca56afc721709ff4ac01a1c9798bb741305d51d238c5a4e08f2466e108b7ac9b`.
- On `brandon-compute`, container `hd2stack-anythingllm` is `Up 4 days (healthy)` and port 3001 is bound on loopback and the host interface. `GET http://127.0.0.1:3001/api/embed` also returned HTTP 200 with `text/html`; the internal root page SHA-256 exactly matched the public Elevate root hash.
- The widget asset and public `/embed/<id>` page returned HTTP 200. No chat POST, credential, workspace, database, Docker mutation, proxy edit, or service restart was performed.
- Core's public page references `llm.hd2.ai` for its embed, a separate service. Do not copy Core's embed or workspace configuration into Elevate.

## Existing boundary and resume instructions

The old 2026-09-19 route record is superseded for the current public root path by the live hash match above; it remains useful historical context, not the current route. The existing work order still governs: repair only Elevate's workspace with a checkpoint and reversible change; keep Core read-only; do not restart the shared service, write the database, alter Docker/volumes, access secrets, or change DNS/TLS/proxy routes. The remote Secondmate should read its own charter and this work order, not try to read the controller's `/root` tree. It must create/verify its visible dependency-aware To-Do before further task action.

The observed failure is at the expected embed API path returning HTML instead of API data, while the underlying :3001 container is healthy. Continue read-only diagnosis of the Elevate embed/workspace contract and checkpoint requirements. Stop and report before any action that changes the shared API/proxy route, touches the database, or cannot be limited to a verified Elevate workspace.
