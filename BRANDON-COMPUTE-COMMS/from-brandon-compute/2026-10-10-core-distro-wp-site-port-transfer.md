# Core Distro WordPress port — docs and restore-point status

Date: 2026-10-10
To: Crisp-R / Dubz Controller
From: Brandon Firstmate, per Captain

The Captain asked that the Core Distro WordPress port status and documentation be easy to find and synced through the established Controller channel.

## Curated documentation bundle

The local landing folder is:

`/home/hd2admin/kun-agent-workspace/warehouse/core-distro-wp-site-port/`

It contains a Controller handoff, document index, dated copies of the current handoff/evidence, and a docs-only archive:

`core-distro-wp-site-port-docs-2026-10-10.tar.gz`

Verify that archive with `BUNDLE.sha256`.
The bundle excludes `.env`, `wp-config.php`, database dumps, WordPress-volume archives, raw screenshots, and source code.

## Current staging status

- Private staging remains at `http://100.106.6.22:8087/`; no production changes, repository creation, or push occurred.
- Read-only checks report a fixed, visually hidden drawer without `inert` or `aria-hidden` in all 11 non-home page records. The theme script controls only the separate header nav. The contact-page Tab run reports focus entering the duplicate; exact link inventory remains unresolved. No code fix is authorized.
- The nine protected duplicate page records remain unchanged; forms/CRM/chatbot/API interactions remain inactive.
- Android, screen-reader, open-menu focus, reliable complete Tab-order, and full visual-parity evidence remain open. Lighthouse results are not a WCAG or production-readiness claim.

## Local restore point

An integrity-checked restore package is stored on Brandon at:

`/home/hd2admin/campaign/core-distro-stage/backups/core-distro-restorepoint-20261010T214158Z/`

Its manifest and checksums are included in the documentation bundle; its project archive, database dump, and WordPress-volume archive are **not** included or synced.
`.env` and `wp-config.php` are excluded from the restore package. No restore/import test was run because database writes are not authorized; the snapshot is integrity-checked, not restore-tested.

## Delivery status

This is a durable outbound note, not proof of receipt.
A read-only SSH connectivity check for the documented `scp` destination `vmi3196300` failed with `Temporary failure in name resolution`; no `scp` transfer occurred and no remote copy is confirmed.
Please sync the curated docs folder and acknowledge through the established `from-brandon-compute` channel when reachable.
Do not transfer the private backup payload without separate Captain approval.
