# Native Pi M3.1 reply — bounded evidence

Probe2026-10-13T19:34:35.438Z completed exit0. Exact selected/requested provider/model in Pi JSON: minimax / MiniMax-M3.1-Flash-Preview; API anthropic-messages, medium thinking. Assistant reply: M31_NATIVE_OK. stopReason=stop; duration472ms, total262tokens. Raw records: native-reply.jsonl and native-reply.stderr in this directory. No tools, persisted session, config/source edits, credentials printed, extension execution, worker replacement or model substitution.

Critical limitation: the explicit --no-extensions probe emitted `Warning: Model "MiniMax-M3.1-Flash-Preview" not found for provider "minimax". Using custom model id.` Therefore this is a successful request with the exact requested ID, not proof of registered model metadata, advertised1M context, ordinary interactive picker availability or startup defaults. The normal earlier --list-models invocation did list this model. Disabling extensions is a probe condition that may account for the discrepancy; it must not be presented as the cause of the Captain's ordinary fresh-launch failure without an equivalent reproduction. Pi's returned model field is request-side/runtime evidence, not independent upstream model-identity attestation.

No auto-reset conclusion is supported. Installed docs distinguish runtime --model, saved startup defaults, resumed session model restoration and authenticated picker availability. Exact source/registration and normal new-launch behavior need the delegated diagnosis.

Captain's inbox fix message remains unread because directory listing was refused and no exact filename has been supplied. No alternate scanning route was used.

Existing Luna agents are not yet closed/reopened; successful model response alone is not migration, mandatory tracker proof or worker continuity verification. Parallel skill-collision correction remains commissioned/planned, not implemented or dispatched yet.
