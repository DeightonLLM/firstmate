# Scope registry enforcement scout report

## Outcome

Implemented a runnable, read-only scope checker at `bin/fm-scope-check.sh` and a focused test at `tests/fm-scope-check.test.sh`. The checker produces an explicit `ALLOW` only when the named owner has an exact match in `write_domains` and that exact domain is not in `exclusions`; every other condition refuses. This is a decision aid, not a dispatch authorization or execution grant, and no dispatch integration was changed.

## Source inspected

Read the actual routing source first: `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`. Its header is exactly `owner`, `surface`, `read_domains`, `write_domains`, `exclusions`, `notes` (six tab-separated columns). In particular, the actual `hetzner-compute` row lists `PROJECT.APPLICATION.CODE` in exclusions and describes that lane as read-only on project application code. The `core-ops` row lists `core-distro.stage` in `write_domains`; the `core-ops` and `hetzner-compute` entries therefore provided a real-registry positive and negative spot check.

The checker uses exact identifiers from `write_domains`; it does not infer from `read_domains`, `surface`, or prose in `notes`. The exclusion lookup takes precedence over the write match. Source rows are checked for six fields, and the header must match all six column names in order. See `bin/fm-scope-check.sh:10-35` for registry selection and preflight and `:38-85` for schema checks and decisions.

## Fail-closed behavior and interface

Invocation: `bin/fm-scope-check.sh [--registry PATH] OWNER ACTION_DOMAIN`; callers may also set `FM_AGENT_SCOPES_REGISTRY`. The default registry path is the controller-provided `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`.

- Missing, unreadable, or non-regular registry: `REFUSE` (script lines 33-36).
- Invalid header or malformed row: `REFUSE` with a diagnostic (lines 40-58, 79-83).
- Unknown owner: `REFUSE` (lines 61-64).
- Domain not exactly listed in that owner's `write_domains`: `REFUSE` (lines 65-75). A domain belonging to a different owner does not make it permissible for this owner.
- Exact exclusion match overrides an exact write-domain match: `REFUSE` (lines 67-72).
- Only exact write-domain match without an exclusion prints `ALLOW` (line 77).

Exit code zero means the scope matched; nonzero means refused or invalid invocation. The checker reads only; it does not modify the registry or invoke a dispatcher. A caller must treat both output and exit status as a pre-dispatch refusal check, and must not interpret `ALLOW` as an authorization grant.

## Validation evidence

RED: Added the test first and ran `tests/fm-scope-check.test.sh` before implementation. All six assertions failed with exit 127 because `bin/fm-scope-check.sh` did not yet exist (`No such file or directory`); this is the expected initial missing-implementation failure.

GREEN / final: `tests/fm-scope-check.test.sh` reported **6 passed, 0 failed**. The six cases are: in-scope allow; out-of-scope refuse; cross-domain refuse although another owner owns the domain; unknown-owner refuse; exclusion overrides matching write-domain; and unreadable-registry refuse (mode 000 fixture). The test definitions are at `tests/fm-scope-check.test.sh:40-54`.

Additional checks passed: `bash -n bin/fm-scope-check.sh tests/fm-scope-check.test.sh` and `git diff --check`. Against the actual TSV, `hetzner-compute PROJECT.APPLICATION.CODE` printed `REFUSE: action domain is explicitly excluded for owner` (exit 13), and `core-ops core-distro.stage` printed `ALLOW: exact action domain appears in owner write_domains` (exit 0). The first real-registry result demonstrates the exclusion match; note the script intentionally does not allow merely because another owner has a matching write domain.

No live dispatch, service, credential, GitHub, or browser operation was performed. Only the two requested worktree files and this report were created; the registry was not modified.

## Registry limits and recommendations

The TSV contains the six requested columns, so no requested input column is absent. However, enforcement semantics are not fully machine-definable from its current content:

1. There is no formal domain grammar or declared matching rule (for example, whether `core-distro` is a parent of `core-distro.api`, or whether matching is always exact). This checker deliberately uses exact comma-separated tokens and performs no parent/child expansion, globbing, or prefix inference.
2. The proposed input is a domain, but the registry does not encode action types or operation-specific conditions. `write_domains` supports only a conservative proposed-write check; it cannot decide read access, publishing versus code edits, or nuanced conditions from notes.
3. `exclusions` is a flat token list without a declared syntax, scope (owner-wide versus domain/subdomain), or structured conditions. This implementation honors exact tokens only. Notes such as “requires explicit Captain authority” remain prose and cannot be converted safely into conditions by this checker.
4. The checker is not wired into task intake or dispatch. Its `ALLOW` is a scope match, not authorization; downstream policy must still check task intent, required approvals, and live-target/action-specific guards. A later enforcement change should call this refusal check before dispatch and keep authorization independent.
5. The default absolute registry path is specific to the supplied deployment. Other homes need an explicit `--registry` or `FM_AGENT_SCOPES_REGISTRY` setting; absence is a refusal, not a silent fallback.

Recommendation: establish and validate the identifier/matching grammar, encode conditional authority as structured fields if it must be mechanically enforced, and integrate this as a pre-dispatch refusal-only check. Keep the dispatch's authorization decision separate from this allow-of-scope result.
