# Core Distro staging duplicate-page cleanup

## Outcome

The nine seed-owned duplicate records were drafted through the guarded helper. No records were deleted. The 12 manifest routes remain published and routable. The page-record test and the staging-only route smoke test both pass.

## Before

Read-only snapshot command:

```sh
docker compose exec -T -u www-data wordpress php < tools/wp-dump-pages.php
```

Exit code: 0.

Snapshot counts: 23 page records total; 22 published; 1 draft. IDs 24, 25, 26, 35, 36, 37, 46, 47, and 48 were all published, carried `_cd_seed_hash`, and had the expected `-2`/`-3`/`-4` slugs. All 12 expected route records were published. The two records without a seed marker were ID 2 (`sample-page`, published, 1,345 content bytes) and ID 3 (`privacy-policy`, draft, 5,536 content bytes).

## Helper contract inspected

Read `tools/draft-seed-duplicates.php` and `tools/build-seed-run.py` in full before executing. The PHP target selects only pages with `_cd_seed_hash` and a slug outside the manifest route list, and on apply only changes `post_status` to `draft`. The builder allowlists targets, requires `--expect-ids` for apply, re-reads and compares the live candidate IDs before writing, and verifies the reported drafted IDs. The permitted target used was only `draft-seed-duplicates.php`; no delete target was run.

## Exact commands and results

1. Before snapshot:

```sh
docker compose exec -T -u www-data wordpress php < tools/wp-dump-pages.php
```

Exit code: 0.

2. Required dry run:

```sh
python3 tools/build-seed-run.py --target draft-seed-duplicates.php --run
```

Exit code: 0. Exact proposed candidate IDs: `[24, 25, 26, 35, 36, 37, 46, 47, 48]`; all were published and had the expected duplicate slugs. The set exactly matched the authorized IDs; no additional IDs were proposed. The helper stated that no rows were written.

3. Guarded apply:

```sh
python3 tools/build-seed-run.py --target draft-seed-duplicates.php --run --apply --expect-ids 24,25,26,35,36,37,46,47,48
```

Exit code: 0. The helper reported `drafted=[24,25,26,35,36,37,46,47,48]` and `publish -> draft; no rows deleted`.

4. Required page-record test:

```sh
node tests/wp-page-records.mjs
```

Real exit code: 0. Output summary: `assertions-failures=0`; it reported all nine seed duplicates retained as drafts.

5. Staging route smoke test (read-only GETs to the allowlisted staging origin and 12 manifest paths only):

```sh
node tests/multipage-smoke.mjs
```

Real exit code: 0. All 12 routes returned HTTP 200 with zero redirects; summary `routes=12 passed=12 failed=0 assertion-failures=0`.

6. After snapshot used the same read-only dumper command. Exit code: 0. Result: 23 records total; 13 published; 10 drafts. All 12 expected route slugs were still published with seed markers. The nine target IDs were drafts with their seed markers intact and unchanged content-byte counts: 9,835 / 8,033 / 8,819 bytes for each corresponding product page copy. The unseeded records remained ID 2 published with 1,345 bytes and ID 3 draft with 5,536 bytes, with the same titles and statuses observed before; no author-written record was selected or modified.

## Scope and checks

No deletes, manual SQL, production requests, compose lifecycle commands (`up`, `down`, `restart`, `pull`, or `build`), credential use, form submissions, chatbot activation, Funnel assertion changes, theme changes, or compose configuration changes were performed. The only container commands were read-only `docker compose exec` inspections/tests and the specified bounded helper invocation. All requested checks were run; none were unavailable.

The staging tree is not version-controlled, so no branch commit or code PR was created for this data-only operation.
