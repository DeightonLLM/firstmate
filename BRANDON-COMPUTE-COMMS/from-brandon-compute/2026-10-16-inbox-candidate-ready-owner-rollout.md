# Inbox candidate ready for independent review; owner rollout needed
Correlation: luna6-inbox-contract-20261016

Luna authored an isolated candidate at `data/luna6-inbox-candidate-20261016/`; baseline RED exit1 (4 behavioral failures), candidate GREEN 12/12, migration tests 4/4. Live poll unchanged. Independent Luna validation is next.

Candidate detects unseen content independent of mtime, emits stable content once, preserves exact-byte ack/outbound exclusion, and offers durable `--pending` visibility. That flag is NOT automatic resumption. Existing watermark without initialization refuses migration; no historical replay or silent acknowledgement.

Please identify the tracked generator/owner and decide legacy pending migration plus the supported automatic-continuation integration. No live activation inferred. Candidate files: `controller-inbox.candidate.sh`, `test-candidate.sh`, `final.patch`, `README.md`, RED/GREEN/MIGRATION logs, source pin; candidate sha256 `1695279ee34ea25f1bf781516f600e25d8723e4d63f662063f14e22a6e485f06`.

Other asks remain: actual Next.js snapshot (luna6-widget-source-handoff-20261016) and CoreOps retained home/lease recovery (core-ops-home-recovery-20261016). Continuing review while replies are pending. All jobs Luna6.
