#!/usr/bin/env bash
# fm-merge-packet.sh - produce one merge packet so the Captain can say one word.
#
# Requirements & Contract:
# 1. Read-only reporter. It never merges, rebases, checks out, resets, stashes,
#    pushes, cherry-picks, or writes to the target repository. The Captain gives
#    the merge word. The packet only informs it.
# 2. One artifact. The packet carries a header, a one-screen summary table, and
#    per branch: identity, diff summary, plain-terms change summary, blast
#    radius, the byte-identical-copy invariant check, test evidence, proven
#    conflicts, rollback commands, and a recommendation. It closes with the
#    proposed merge order and the single decision requested.
# 3. Honest evidence. Every conflict claim is proven with git merge-tree and the
#    tool output is quoted verbatim. Every test result is labelled INHERITED
#    FROM A REPORT or NOT RUN BY THIS PACKET. A combination that was not tested
#    is UNTESTED, never clean.
# 4. The invariant check is the most important check in the packet. Copies of a
#    file that must stay byte-identical are compared by sha256 on the branch.
# 5. The packet never widens merge authority. The closing section states what one
#    word authorises and what it does not.
#
# The merge proof writes tree objects, so it redirects GIT_OBJECT_DIRECTORY to a
# temporary directory that reads the real objects as an alternate. The target
# repository receives no new object, no new ref, no index change, and no
# working tree change.
#
# Usage:
#   fm-merge-packet.sh --repo <path> --branch <branch> [<branch> ...] --out <file>
#   fm-merge-packet.sh --repo <path> --stdin --out <file>
#
# Options:
#   --repo <path>       Repository or worktree to report on. Required.
#   --branch <name> ... Branch names. Repeatable, and one flag may carry many.
#   --stdin             Read additional branch names from stdin, one per line.
#   --out <file>        Write the packet to this file. Default is stdout.
#   --base <ref>        Override the detected base branch.
#   --parity <a>=<b>    Extra pair of paths that must stay byte-identical. Repeatable.
#   --evidence <path>   Extra evidence artifact to cite. Repeatable.
#
# Exit codes:
#   0 - packet written
#   1 - error: missing repository, unknown branch, or unusable input
#   2 - usage error
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: fm-merge-packet.sh --repo <path> --branch <branch> [<branch> ...] [--out <file>]
       fm-merge-packet.sh --repo <path> --stdin [--out <file>]

Options:
  --repo <path>       Repository or worktree to report on. Required.
  --branch <name> ... Branch names. Repeatable, and one flag may carry many.
  --stdin             Read additional branch names from stdin, one per line.
  --out <file>        Write the packet to this file. Default is stdout.
  --base <ref>        Override the detected base branch.
  --parity <a>=<b>    Extra pair of paths that must stay byte-identical. Repeatable.
  --evidence <path>   Extra evidence artifact to cite. Repeatable.
  -h, --help          Print this help and exit 0.

Exit codes: 0 packet written, 1 error, 2 usage error.
The script is a read-only reporter. It never merges, rebases, checks out, resets,
stashes, cherry-picks, or pushes, and it never writes to the target repository.
USAGE
}

REPO=""
OUT=""
BASE=""
USE_STDIN=0
BRANCHES=()
PARITY=()
EVIDENCE=()

die_usage() {
  printf 'fm-merge-packet.sh: %s\n' "$1" >&2
  usage >&2
  exit 2
}

die_error() {
  printf 'fm-merge-packet.sh: %s\n' "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || die_usage "--repo needs a path"
      REPO="$2"
      shift 2
      ;;
    --branch)
      [ $# -ge 2 ] || die_usage "--branch needs at least one branch name"
      consumed=0
      while [ $# -ge 2 ] && [ "${2#--}" = "$2" ]; do
        BRANCHES+=("$2")
        consumed=$((consumed + 1))
        shift
      done
      [ "$consumed" -gt 0 ] || die_usage "--branch needs at least one branch name"
      shift
      ;;
    --out)
      [ $# -ge 2 ] || die_usage "--out needs a file path"
      OUT="$2"
      shift 2
      ;;
    --base)
      [ $# -ge 2 ] || die_usage "--base needs a ref"
      BASE="$2"
      shift 2
      ;;
    --parity)
      [ $# -ge 2 ] || die_usage "--parity needs <pathA>=<pathB>"
      PARITY+=("$2")
      shift 2
      ;;
    --evidence)
      [ $# -ge 2 ] || die_usage "--evidence needs a path"
      EVIDENCE+=("$2")
      shift 2
      ;;
    --stdin)
      USE_STDIN=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown argument: $1"
      ;;
  esac
done

if [ -z "$REPO" ]; then
  die_usage "--repo is required"
fi

if [ ! -e "$REPO" ]; then
  die_error "repository path does not exist: $REPO"
fi

if [ ! -d "$REPO" ]; then
  die_error "repository path is not a directory: $REPO"
fi

if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  die_error "repository path is not a git repository: $REPO"
fi

if [ "$USE_STDIN" -eq 1 ]; then
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [ -n "$line" ] || continue
    BRANCHES+=("$line")
  done
fi

if [ "${#BRANCHES[@]}" -eq 0 ]; then
  die_usage "no branches given: use --branch or --stdin"
fi

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fm-merge-packet.XXXXXX") || die_error "cannot create a work directory"
trap 'rm -rf "$WORK_DIR"' EXIT

BRANCH_FILE="$WORK_DIR/branches.txt"
PARITY_FILE="$WORK_DIR/parity.txt"
EVIDENCE_FILE="$WORK_DIR/evidence.txt"
: > "$BRANCH_FILE"
: > "$PARITY_FILE"
: > "$EVIDENCE_FILE"

for b in "${BRANCHES[@]}"; do
  printf '%s\n' "$b" >> "$BRANCH_FILE"
done
for p in "${PARITY[@]}"; do
  printf '%s\n' "$p" >> "$PARITY_FILE"
done
for e in "${EVIDENCE[@]}"; do
  printf '%s\n' "$e" >> "$EVIDENCE_FILE"
done

PY_ARGS=(
  --repo "$REPO"
  --out "$OUT"
  --branches-file "$BRANCH_FILE"
  --parity-file "$PARITY_FILE"
  --evidence-file "$EVIDENCE_FILE"
)
if [ -n "$BASE" ]; then
  PY_ARGS+=(--base "$BASE")
fi

python3 - "${PY_ARGS[@]}" <<'PY'
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime

HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")
TEST_DIR_NAMES = {"tests", "test", "spec", "specs", "testing"}
FIXTURE_DIR_NAMES = {"fixture", "fixtures", "__fixtures__", "testdata", "test-data", "node_modules"}
REPORT_HINT_RE = re.compile(r"(report|verdict|evidence|result|output|proof)", re.IGNORECASE)


def git(repo, args, env=None, check=False):
    proc = subprocess.run(
        ["git", "-C", repo] + list(args),
        capture_output=True,
        text=True,
        env=env,
    )
    if check and proc.returncode != 0:
        sys.stderr.write("git %s failed: %s\n" % (" ".join(args), proc.stderr.strip()))
        sys.exit(1)
    return proc.returncode, proc.stdout, proc.stderr


def git_text(repo, args, env=None, default=""):
    rc, out, err = git(repo, args, env=env)
    if rc != 0:
        return default
    return out


def strip_rev_prefix(line):
    # git grep prefixes every path with the revision it searched.
    match = re.match(r"^[0-9a-f]{7,40}:(.*)$", line)
    if match:
        return match.group(1)
    return line


def grep_files(repo, pattern, rev, pathspec=None):
    args = ["grep", "-l", "-F", pattern, rev]
    if pathspec:
        args += ["--", pathspec]
    hits = []
    for line in git_text(repo, args).splitlines():
        line = strip_rev_prefix(line.strip())
        if line:
            hits.append(line)
    return hits


def read_lines(path):
    if not path or not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as handle:
        return [line.strip() for line in handle if line.strip()]


def truncate(text, limit):
    text = text.rstrip()
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def detect_base(repo, override):
    if override:
        rc, _, _ = git(repo, ["rev-parse", "--verify", "--quiet", override + "^{commit}"])
        if rc != 0:
            sys.stderr.write("fm-merge-packet.sh: base ref does not resolve: %s\n" % override)
            sys.exit(1)
        return override
    rc, out, _ = git(repo, ["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"])
    if rc == 0 and out.strip():
        return out.strip().replace("refs/remotes/", "", 1)
    for candidate in ("origin/main", "origin/master"):
        rc, _, _ = git(repo, ["rev-parse", "--verify", "--quiet", candidate + "^{commit}"])
        if rc == 0:
            return candidate
    for candidate in ("main", "master"):
        rc, _, _ = git(repo, ["rev-parse", "--verify", "--quiet", candidate + "^{commit}"])
        if rc == 0:
            return candidate
    return None


def resolve_branch(repo, name):
    rc, out, _ = git(repo, ["rev-parse", "--verify", "--quiet", name + "^{commit}"])
    if rc != 0:
        return None
    return out.strip()


def sha256_of_blob(repo, rev, path):
    proc = subprocess.run(
        ["git", "-C", repo, "cat-file", "blob", "%s:%s" % (rev, path)],
        capture_output=True,
    )
    if proc.returncode != 0:
        return None
    return hashlib.sha256(proc.stdout).hexdigest()


def split_numstat_line(line):
    parts = line.split("\t")
    if len(parts) < 3:
        return None
    adds, dels, path = parts[0], parts[1], "\t".join(parts[2:])
    adds = 0 if adds == "-" else int(adds)
    dels = 0 if dels == "-" else int(dels)
    return adds, dels, path


def parse_hunks(diff_text):
    regions = []
    adds = []
    dels = []
    for line in diff_text.splitlines():
        match = HUNK_RE.match(line)
        if match:
            old_start, old_len, new_start, new_len, section = match.groups()
            name = section.strip()
            if not name:
                count = int(new_len or "1")
                if count == 1:
                    name = "line %s" % new_start
                else:
                    last = int(new_start) + count - 1
                    name = "lines %s to %s" % (new_start, last)
            regions.append(name)
            continue
        if line.startswith("+++") or line.startswith("---"):
            continue
        if line.startswith("+"):
            adds.append(line[1:])
        elif line.startswith("-"):
            dels.append(line[1:])
    return regions, adds, dels


def is_test_path(path):
    parts = path.split("/")
    if any(part in FIXTURE_DIR_NAMES for part in parts):
        return False
    base = parts[-1]
    if base in ("README.md", "readme.md"):
        return False
    in_test_dir = any(part in TEST_DIR_NAMES for part in parts[:-1])
    named_test = (
        base.startswith("test_")
        or base.endswith(("_test.py", "_test.php", "_test.mjs", "_test.js", "_test.ts", "_test.sh"))
        or base.endswith((".test.mjs", ".test.js", ".test.ts", ".spec.mjs", ".spec.js", ".spec.ts"))
        or base.endswith(("Test.php", "Tests.php", "Spec.php"))
    )
    return in_test_dir or named_test


def run_command_for(path):
    base = path.split("/")[-1]
    if base.endswith(".php"):
        return "php %s" % path
    if base.endswith(".py"):
        return "python3 %s" % path
    if base.endswith(".mjs") or base.endswith(".js"):
        return "node %s" % path
    if base.endswith(".sh"):
        return "bash %s" % path
    if base.endswith(".ts"):
        return None
    return None


def tree_files(repo, rev):
    out = git_text(repo, ["ls-tree", "-r", "--name-only", rev])
    return [line for line in out.splitlines() if line.strip()]


def blob_oid(repo, rev, path):
    rc, out, _ = git(repo, ["rev-parse", "--verify", "--quiet", "%s:%s" % (rev, path)])
    if rc != 0:
        return None
    return out.strip()


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", default="")
    parser.add_argument("--base", default="")
    parser.add_argument("--branches-file", required=True)
    parser.add_argument("--parity-file", default="")
    parser.add_argument("--evidence-file", default="")
    args = parser.parse_args()

    repo = os.path.abspath(args.repo)
    branch_names = read_lines(args.branches_file)
    parity_specs = read_lines(args.parity_file)
    extra_evidence = read_lines(args.evidence_file)

    base_ref = detect_base(repo, args.base)
    if base_ref is None:
        sys.stderr.write(
            "fm-merge-packet.sh: cannot detect a base branch in %s; pass --base <ref>\n" % repo
        )
        sys.exit(1)

    base_commit = resolve_branch(repo, base_ref)
    remote_url = git_text(repo, ["remote", "get-url", "origin"]).strip()
    if not remote_url:
        remotes = git_text(repo, ["remote"]).split()
        remote_url = remotes[0] if remotes else "(none)"

    # Duplicate branch names are removed while keeping the caller's order.
    seen = set()
    ordered_branches = []
    for name in branch_names:
        if name not in seen:
            seen.add(name)
            ordered_branches.append(name)

    unknown = [name for name in ordered_branches if resolve_branch(repo, name) is None]
    if unknown:
        sys.stderr.write(
            "fm-merge-packet.sh: branch does not resolve in %s: %s\n"
            % (repo, ", ".join(unknown))
        )
        sys.exit(1)

    # The merge proof writes objects, so it runs with a redirected object
    # directory that reads the real objects as an alternate.
    objects_path = git_text(repo, ["rev-parse", "--git-path", "objects"]).strip()
    objects_path = os.path.abspath(os.path.join(repo, objects_path))
    proof_dir = tempfile.mkdtemp(prefix="fm-merge-packet-objects.")
    proof_objects = os.path.join(proof_dir, "objects")
    os.makedirs(proof_objects)
    proof_env = dict(os.environ)
    proof_env["GIT_OBJECT_DIRECTORY"] = proof_objects
    proof_env["GIT_ALTERNATE_OBJECT_DIRECTORIES"] = objects_path
    proof_env["GIT_AUTHOR_NAME"] = "merge packet"
    proof_env["GIT_AUTHOR_EMAIL"] = "merge-packet@localhost"
    proof_env["GIT_COMMITTER_NAME"] = "merge packet"
    proof_env["GIT_COMMITTER_EMAIL"] = "merge-packet@localhost"

    def merge_tree(left, right):
        proc = subprocess.run(
            ["git", "-C", repo, "merge-tree", "--write-tree", "--messages", left, right],
            capture_output=True,
            text=True,
            env=proof_env,
        )
        return proc.returncode, proc.stdout, proc.stderr

    def merge_tree_tree(rc, stdout):
        for line in stdout.splitlines():
            candidate = line.strip()
            if re.fullmatch(r"[0-9a-f]{40}", candidate):
                return candidate
        return None

    def make_merge_commit(tree, parents, message):
        args_list = ["commit-tree", tree]
        for parent in parents:
            args_list += ["-p", parent]
        args_list += ["-m", message]
        proc = subprocess.run(
            ["git", "-C", repo] + args_list, capture_output=True, text=True, env=proof_env
        )
        if proc.returncode != 0:
            return None
        return proc.stdout.strip()

    # --- per branch facts ---------------------------------------------------

    branches = []
    for name in ordered_branches:
        head = resolve_branch(repo, name)
        merge_base = git_text(repo, ["merge-base", base_ref, name]).strip() or base_commit
        subject = git_text(repo, ["log", "-1", "--format=%s", name]).strip()
        author_date = git_text(repo, ["log", "-1", "--format=%aI", name]).strip()
        author = git_text(repo, ["log", "-1", "--format=%an <%ae>", name]).strip()
        first_parent = git_text(repo, ["rev-parse", "--verify", "--quiet", name + "^1"]).strip()
        commit_count_text = git_text(repo, ["rev-list", "--count", "%s..%s" % (merge_base, name)]).strip()
        try:
            commit_count = int(commit_count_text)
        except ValueError:
            commit_count = 0
        subjects = [
            line.strip()
            for line in git_text(
                repo, ["log", "--format=%s", "%s..%s" % (merge_base, name)]
            ).splitlines()
            if line.strip()
        ]

        numstat = []
        for line in git_text(repo, ["diff", "--numstat", merge_base, name]).splitlines():
            parsed = split_numstat_line(line)
            if parsed:
                numstat.append(parsed)
        name_status = {}
        for line in git_text(repo, ["diff", "--name-status", merge_base, name]).splitlines():
            bits = line.split("\t")
            if len(bits) >= 2:
                name_status[bits[-1]] = bits[0]

        total_adds = sum(item[0] for item in numstat)
        total_dels = sum(item[1] for item in numstat)

        # push state
        push_state = "UNKNOWN"
        push_detail = ""
        if not remote_url or remote_url == "(none)":
            push_state = "NO REMOTE"
            push_detail = "the repository has no origin remote to compare against"
        else:
            proc = subprocess.run(
                ["git", "-C", repo, "ls-remote", "--heads", "origin", name],
                capture_output=True,
                text=True,
            )
            if proc.returncode != 0:
                push_state = "UNKNOWN"
                push_detail = "ls-remote failed: %s" % truncate(proc.stderr.strip(), 160)
            else:
                remote_line = proc.stdout.strip()
                if not remote_line:
                    push_state = "NOT PUSHED"
                    push_detail = "the remote has no branch named %s" % name
                else:
                    remote_sha = remote_line.split()[0]
                    if remote_sha == head:
                        push_state = "PUSHED"
                        push_detail = "the remote branch is at the same commit"
                    else:
                        push_state = "PUSHED, REMOTE BEHIND"
                        push_detail = "the remote branch is at %s, the local head is %s" % (
                            remote_sha[:8],
                            head[:8],
                        )

        branches.append(
            {
                "name": name,
                "head": head,
                "short": head[:8],
                "merge_base": merge_base,
                "base_subject": subject,
                "author_date": author_date,
                "author": author,
                "first_parent": first_parent,
                "commit_count": commit_count,
                "subjects": subjects,
                "numstat": numstat,
                "name_status": name_status,
                "total_adds": total_adds,
                "total_dels": total_dels,
                "push_state": push_state,
                "push_detail": push_detail,
            }
        )

    # --- contested files ----------------------------------------------------

    changed_sets = {item["name"]: {path for _, _, path in item["numstat"]} for item in branches}
    contested = set()
    seen_files = {}
    for name, paths in changed_sets.items():
        for path in paths:
            seen_files.setdefault(path, []).append(name)
    for path, owners in seen_files.items():
        if len(owners) > 1:
            contested.add(path)

    def contested_lines(item):
        return sum(
            adds + dels for adds, dels, path in item["numstat"] if path in contested
        )

    # --- invariant groups ---------------------------------------------------

    def identical_twin_groups(rev):
        groups = {}
        for line in git_text(repo, ["ls-tree", "-r", rev]).splitlines():
            bits = line.split()
            if len(bits) < 4:
                continue
            oid = bits[2]
            path = bits[3]
            groups.setdefault(path.split("/")[-1], []).append((oid, path))
        twins = []
        for base_name, entries in groups.items():
            if len(entries) > 1 and len({oid for oid, _ in entries}) == 1:
                twins.append((base_name, sorted(path for _, path in entries)))
        return sorted(twins, key=lambda entry: entry[0])

    base_twins = identical_twin_groups(base_commit)
    twin_paths = {}
    for base_name, paths in base_twins:
        for path in paths:
            twin_paths[path] = paths

    explicit_pairs = []
    for spec in parity_specs:
        if "=" in spec:
            left, right = spec.split("=", 1)
            explicit_pairs.append((left.strip(), right.strip()))

    for item in branches:
        groups = []
        reported = set()
        for path in sorted(changed_sets[item["name"]]):
            if path in twin_paths and path not in reported:
                siblings = twin_paths[path]
                key = tuple(siblings)
                if key not in reported:
                    reported.add(key)
                    groups.append(list(siblings))
        for left, right in explicit_pairs:
            if left in changed_sets[item["name"]] or right in changed_sets[item["name"]]:
                if [left, right] not in groups:
                    groups.append([left, right])
        # A group is only interesting when the branch actually moves one of its
        # copies, which is what breaks parity.
        groups = [
            group
            for group in groups
            if any(path in changed_sets[item["name"]] for path in group)
        ]
        group_results = []
        for group in groups:
            entries = []
            digests = {}
            for path in group:
                digest = sha256_of_blob(repo, item["head"], path)
                if digest is None:
                    entries.append((path, "MISSING ON BRANCH", None))
                else:
                    digests[path] = digest
                    entries.append((path, digest, digest))
            unique = {digest for digest in digests.values()}
            if len(group) != len(digests):
                verdict = "BROKEN"
            elif len(unique) == 1:
                verdict = "HOLDS"
            else:
                verdict = "BROKEN"
            group_results.append({"paths": group, "entries": entries, "verdict": verdict})
        item["invariant_groups"] = group_results
        item["parity_broken"] = any(g["verdict"] == "BROKEN" for g in group_results)

    # --- pairwise conflicts -------------------------------------------------

    pair_results = {}
    for i in range(len(branches)):
        for j in range(i + 1, len(branches)):
            left = branches[i]["name"]
            right = branches[j]["name"]
            rc, stdout, stderr = merge_tree(left, right)
            pair_results[(left, right)] = {
                "rc": rc,
                "stdout": stdout,
                "stderr": stderr,
                "verdict": "CLEAN" if rc == 0 else ("CONFLICTING" if rc == 1 else "UNTESTED"),
            }

    def pair_verdict(a, b):
        if (a, b) in pair_results:
            return pair_results[(a, b)]
        return pair_results[(b, a)]

    # --- proposed merge order ----------------------------------------------

    def try_merge(accumulated, name):
        rc, stdout, stderr = merge_tree(accumulated, name)
        return rc, stdout, stderr

    remaining = [item["name"] for item in branches]
    order = []
    order_steps = []
    accumulated = base_commit
    order_verdict = "CLEAN"
    while remaining:
        best = None
        for name in remaining:
            rc, stdout, stderr = try_merge(accumulated, name)
            if rc != 0:
                continue
            item = next(b for b in branches if b["name"] == name)
            score = (contested_lines(item), item["total_adds"] + item["total_dels"])
            if best is None or score < best[0]:
                best = (score, name, rc, stdout, stderr)
        if best is None:
            name = min(
                remaining,
                key=lambda n: (
                    contested_lines(next(b for b in branches if b["name"] == n)),
                    next(b for b in branches if b["name"] == n)["total_adds"]
                    + next(b for b in branches if b["name"] == n)["total_dels"],
                ),
            )
            rc, stdout, stderr = try_merge(accumulated, name)
            best = ((0, 0), name, rc, stdout, stderr)
        _, chosen, rc, stdout, stderr = best
        order.append(chosen)
        tree = merge_tree_tree(rc, stdout)
        step = {
            "name": chosen,
            "rc": rc,
            "stdout": stdout,
            "stderr": stderr,
            "verdict": "CLEAN" if rc == 0 else ("CONFLICTING" if rc == 1 else "UNTESTED"),
            "pre_merge_commit": accumulated,
            "tree": tree,
        }
        order_steps.append(step)
        if rc == 0 and tree:
            merged = make_merge_commit(
                tree, [accumulated, chosen], "merge packet: temporary merge commit"
            )
            if merged is None:
                order_verdict = "UNTESTED"
                remaining.remove(chosen)
                break
            accumulated = merged
        else:
            if rc == 1:
                order_verdict = "CONFLICTING"
            else:
                order_verdict = "UNTESTED"
            remaining.remove(chosen)
            break
        remaining.remove(chosen)

    if order_verdict == "CLEAN" and len(order) != len(branches):
        order_verdict = "UNTESTED"

    # --- all branches three way verdict ------------------------------------

    three_way_verdict = "UNTESTED"
    three_way_notes = []
    if len(branches) == 1:
        three_way_verdict = "CLEAN"
        three_way_notes.append("only one branch was requested, so the single branch merge is the whole set")
    elif order_verdict == "CLEAN" and len(order) == len(branches):
        three_way_verdict = "CLEAN"
        three_way_notes.append(
            "every step of the proposed order merged clean in sequence, so the whole set merges clean"
        )
    elif order_verdict == "CONFLICTING":
        three_way_verdict = "CONFLICTING"
        three_way_notes.append("the sequential merge hit a conflict, so the set does not merge clean")
    else:
        three_way_verdict = "UNTESTED"
        three_way_notes.append("the sequential merge could not be completed, so the set is untested")

    # --- test evidence ------------------------------------------------------

    base_files = set(tree_files(repo, base_commit))
    for item in branches:
        branch_files = tree_files(repo, item["head"])
        test_files = [path for path in branch_files if is_test_path(path)]
        added_tests = [path for path in test_files if path in changed_sets[item["name"]]]

        referencing = set()
        for _, _, path in item["numstat"]:
            base_name = path.split("/")[-1]
            if not base_name:
                continue
            for hit in grep_files(repo, base_name, item["head"]):
                if hit in test_files:
                    referencing.add(hit)

        related_tests = sorted(set(added_tests) | referencing)
        unrelated_tests = [path for path in test_files if path not in related_tests]

        runners = []
        for path in related_tests:
            base_name = path.split("/")[-1]
            if base_name.startswith("run") and "test" in base_name.lower():
                runners.append(path)

        evidence_hits = set()
        for _, _, path in item["numstat"]:
            base_name = path.split("/")[-1]
            if not base_name:
                continue
            for hit in grep_files(repo, base_name, item["head"], "evidence/"):
                if REPORT_HINT_RE.search(hit):
                    evidence_hits.add(hit)

        item["related_tests"] = related_tests
        item["unrelated_tests"] = unrelated_tests
        item["runners"] = runners
        item["evidence_hits"] = sorted(evidence_hits)
        item["added_tests"] = added_tests

    for path in extra_evidence:
        for item in branches:
            if path not in item["evidence_hits"]:
                item["evidence_hits"].append(path)

    # --- blast radius -------------------------------------------------------

    for item in branches:
        dependents = []
        for _, _, path in item["numstat"]:
            base_name = path.split("/")[-1]
            hits = set()
            if base_name:
                for hit in grep_files(repo, base_name, item["merge_base"]):
                    hits.add(hit)
            for hit in grep_files(repo, path, item["merge_base"]):
                hits.add(hit)
            for hit in sorted(hits):
                if hit in changed_sets[item["name"]]:
                    continue
                if hit not in dependents:
                    dependents.append(hit)
        item["dependents"] = dependents

    # --- plain terms --------------------------------------------------------

    for item in branches:
        files_detail = []
        for adds, dels, path in item["numstat"]:
            diff_text = git_text(repo, ["diff", "--unified=0", "--no-color", item["merge_base"], item["head"], "--", path])
            regions, add_lines, del_lines = parse_hunks(diff_text)
            files_detail.append(
                {
                    "path": path,
                    "status": item["name_status"].get(path, "M"),
                    "adds": adds,
                    "dels": dels,
                    "regions": regions,
                    "add_samples": [truncate(x, 140) for x in add_lines if x.strip()][:3],
                    "del_samples": [truncate(x, 140) for x in del_lines if x.strip()][:3],
                }
            )
        item["files_detail"] = files_detail

    # --- recommendations ----------------------------------------------------

    order_position = {name: index + 1 for index, name in enumerate(order)}
    step_verdict = {step["name"]: step["verdict"] for step in order_steps}
    for item in branches:
        name = item["name"]
        reasons = []
        verdict = "MERGE NOW"
        own_step = step_verdict.get(name)
        conflicts = [
            other["name"]
            for other in branches
            if other["name"] != name
            and pair_verdict(name, other["name"])["verdict"] == "CONFLICTING"
        ]
        position = order_position.get(name, 0)
        predecessor = order[position - 2] if position >= 2 else None
        has_test_evidence = bool(item["related_tests"] or item["evidence_hits"])

        if item["parity_broken"]:
            verdict = "DO NOT MERGE"
            reasons.append("the byte-identical invariant is BROKEN on this branch")
        elif own_step == "CONFLICTING":
            verdict = "MERGE AFTER CONFLICT RESOLUTION"
        elif own_step == "UNTESTED":
            verdict = "MERGE AFTER CONFLICT PROOF"
        elif not has_test_evidence:
            verdict = "MERGE AFTER TEST EVIDENCE"
        elif predecessor is not None:
            verdict = "MERGE AFTER %s" % predecessor
        elif item["push_state"] == "NOT PUSHED":
            verdict = "MERGE AFTER PUSH"

        if own_step == "CONFLICTING":
            reasons.append(
                "the merge of this branch into the accumulated state conflicts, so it needs a hand resolution first"
            )
        elif own_step == "UNTESTED":
            reasons.append(
                "the merge of this branch into the accumulated state could not be proven, so it is untested"
            )
        if conflicts:
            reasons.append(
                "it conflicts pairwise with %s"
                % ", ".join("`%s`" % other for other in conflicts)
            )
        if not has_test_evidence:
            reasons.append("no test in the repository exercises the changed files")
        if item["push_state"] == "NOT PUSHED":
            reasons.append(
                "the head %s is not on the remote, so the work exists only on this machine and must be pushed before it is merged"
                % item["short"]
            )
        elif item["push_state"] == "PUSHED, REMOTE BEHIND":
            reasons.append("the remote branch is behind the local head %s" % item["short"])
        elif item["push_state"] == "UNKNOWN":
            reasons.append("the push state could not be established: %s" % item["push_detail"])
        if predecessor is not None:
            reasons.append(
                "it lands %d%s in the proposed order, after `%s`"
                % (position, ordinal_suffix(position), predecessor)
            )
        elif position == 1:
            reasons.append(
                "it lands 1st in the proposed order, as the first increment on the base"
            )
        if not reasons:
            reasons.append("every check in this packet passed for this branch")
        item["verdict"] = verdict
        item["reasons"] = reasons

    # --- render -------------------------------------------------------------

    out = []
    w = out.append

    generated_at = datetime.now().astimezone().isoformat(timespec="seconds")
    host = os.uname().nodename

    w("# Merge packet")
    w("")
    w("Generated at: %s" % generated_at)
    w("Host: %s" % host)
    w("Repo: %s" % repo)
    w("Remote: %s" % remote_url)
    w("Base branch: %s (%s)" % (base_ref, base_commit[:8]))
    w("Branches: %d" % len(branches))
    w("Tool: bin/fm-merge-packet.sh (read-only reporter)")
    w("")
    w("## 1. Summary")
    w("")
    w("| # | Branch | Head | Pushed | Files | +/- | Parity | Conflicts | Recommendation |")
    w("|---|---|---|---|---|---|---|---|---|")
    for index, item in enumerate(branches, start=1):
        name = item["name"]
        conflict_bits = []
        for other in branches:
            if other["name"] == name:
                continue
            verdict = pair_verdict(name, other["name"])["verdict"]
            conflict_bits.append("%s:%s" % (other["short"], verdict))
        conflict_cell = " ".join(conflict_bits) if conflict_bits else "no other branch"
        parity_cell = (
            "HOLDS" if item["invariant_groups"] and not item["parity_broken"]
            else ("BROKEN" if item["parity_broken"] else "NO IDENTICAL TWIN")
        )
        w(
            "| %d | `%s` | `%s` | %s | %d | +%d/-%d | %s | %s | %s |"
            % (
                index,
                name,
                item["short"],
                item["push_state"],
                len(item["numstat"]),
                item["total_adds"],
                item["total_dels"],
                parity_cell,
                conflict_cell,
                item["verdict"],
            )
        )
    w("")
    w("All-branches three-way merge: **%s**" % three_way_verdict)
    w("")
    w("Proposed merge order: %s" % (" -> ".join("`%s`" % name for name in order) if order else "(none)"))
    w("")

    w("## 2. Method and safety")
    w("")
    w("The packet is a report. It never merges, rebases, checks out, resets, stashes,")
    w("cherry-picks, or pushes, and it never writes to the target repository.")
    w("Conflict proof uses `git merge-tree --write-tree --messages`, run with")
    w("`GIT_OBJECT_DIRECTORY` redirected to a temporary directory that reads the real")
    w("objects as an alternate, so the repository gains no object, no ref, no index")
    w("change, and no working tree change.")
    w("The packet does not run a test suite. Every test result below is either")
    w("INHERITED FROM A REPORT, with the artifact path cited, or NOT RUN BY THIS")
    w("PACKET. Nothing is claimed as observed now that was not observed now.")
    w("")

    w("## 3. Base branch and merge bases")
    w("")
    w("Base branch: `%s`" % base_ref)
    w("Base commit: `%s`" % base_commit)
    w("Base subject: %s" % git_text(repo, ["log", "-1", "--format=%s", base_commit]).strip())
    w("")
    w("| Branch | Merge base with base branch | Commits ahead |")
    w("|---|---|---|")
    for item in branches:
        w(
            "| `%s` | `%s` | %d |"
            % (item["name"], item["merge_base"][:8], item["commit_count"])
        )
    w("")

    w("## 4. Branch detail")
    for index, item in enumerate(branches, start=1):
        name = item["name"]
        w("")
        w("### 4.%d `%s`" % (index, name))
        w("")

        w("#### Identity")
        w("")
        w("| Field | Value |")
        w("|---|---|")
        w("| Branch | `%s` |" % name)
        w("| Head commit | `%s` |" % item["head"])
        w("| Subject | %s |" % (item["subjects"][0] if item["subjects"] else "(no subject)"))
        w("| Author | %s |" % item["author"])
        w("| Author date | %s |" % item["author_date"])
        w("| Merge base with `%s` | `%s` |" % (base_ref, item["merge_base"]))
        w("| First parent of head | `%s` |" % (item["first_parent"][:8] if item["first_parent"] else "(none)"))
        w("| Commits ahead of merge base | %d |" % item["commit_count"])
        w("| Pushed to remote | %s |" % item["push_state"])
        w("| Push detail | %s |" % (item["push_detail"] or "-"))
        w("")
        if item["commit_count"] > 0:
            w("Commits on this branch:")
            w("")
            for subject in item["subjects"]:
                w("- %s" % subject)
            w("")
        if item["push_state"] == "NOT PUSHED":
            w("Risk: the head of this branch is not a copy that exists on the remote.")
            w("Merging it merges work that only this machine holds.")
            w("")
        elif item["push_state"] == "PUSHED, REMOTE BEHIND":
            w("Risk: the remote branch is behind the local head, so the remote does not")
            w("hold this exact commit.")
            w("")
        elif item["push_state"] == "UNKNOWN":
            w("Risk: the push state could not be established, so this branch may be")
            w("local only. Detail: %s" % item["push_detail"])
            w("")
        elif item["push_state"] == "NO REMOTE":
            w("Note: this repository has no origin remote, so no push state exists.")
            w("")

        w("#### Diff summary")
        w("")
        w("Base for the diff is the merge base `%s` with `%s`." % (item["merge_base"][:8], base_ref))
        w("")
        w("| File | Status | +/- |")
        w("|---|---|---|")
        for adds, dels, path in item["numstat"]:
            w(
                "| `%s` | %s | +%d/-%d |"
                % (path, item["name_status"].get(path, "M"), adds, dels)
            )
        w("| **Total** | %d file%s | **+%d/-%d** |" % (
            len(item["numstat"]),
            "" if len(item["numstat"]) == 1 else "s",
            item["total_adds"],
            item["total_dels"],
        ))
        w("")
        if not item["numstat"]:
            w("This branch changes no file against the base, so it is already contained")
            w("in the base branch and there is nothing to merge.")
            w("")

        w("#### What it changes, in plain terms")
        w("")
        if item["subjects"]:
            w("The commit says: %s" % item["subjects"][0])
        else:
            w("The branch carries no commit message.")
        w("")
        for detail in item["files_detail"]:
            w("- `%s` (%s, +%d/-%d)" % (detail["path"], detail["status"], detail["adds"], detail["dels"]))
            if detail["regions"]:
                w("  - Regions touched: %s" % "; ".join(detail["regions"][:6]))
            elif detail["status"] == "A":
                w("  - Regions touched: the file is new in this branch")
            else:
                w("  - Regions touched: none reported by the diff hunk headers")
            if detail["add_samples"]:
                w("  - Added, representative lines:")
                for line in detail["add_samples"]:
                    w("    - `%s`" % line.replace("`", "'"))
            if detail["del_samples"]:
                w("  - Removed, representative lines:")
                for line in detail["del_samples"]:
                    w("    - `%s`" % line.replace("`", "'"))
        w("")

        w("#### Blast radius")
        w("")
        w("Files and regions changed: %d file(s), %d changed line(s)."
          % (len(item["numstat"]), item["total_adds"] + item["total_dels"]))
        contested_here = [path for path in changed_sets[name] if path in contested]
        if contested_here:
            w("")
            w("Files this branch changes that another branch in this packet also changes:")
            for path in contested_here:
                others = [owner for owner in seen_files[path] if owner != name]
                w("- `%s` (also changed by %s)" % (path, ", ".join("`%s`" % o for o in others)))
        if item["dependents"]:
            w("")
            w("Other tracked files in the repository that reference the changed files (%d):"
              % len(item["dependents"]))
            for path in item["dependents"][:25]:
                w("- `%s`" % path)
            if len(item["dependents"]) > 25:
                w("- ... and %d more" % (len(item["dependents"]) - 25))
        else:
            w("")
            w("No other tracked file in the repository references the changed files by name.")
        w("")

        w("#### Invariant check: copies that must stay byte-identical")
        w("")
        if not item["invariant_groups"]:
            w("No group of byte-identical copies is touched by this branch.")
            w("The check is not applicable to this branch, so no parity is claimed.")
        else:
            for group in item["invariant_groups"]:
                w("Group: %s" % ", ".join("`%s`" % path for path in group["paths"]))
                w("")
                w("| Copy | sha256 on `%s` |" % item["short"])
                w("|---|---|")
                for path, digest, _ in group["entries"]:
                    w("| `%s` | `%s` |" % (path, digest))
                w("")
                w("Parity: **%s**" % group["verdict"])
                if group["verdict"] == "HOLDS":
                    w("Both copies are byte-identical on this branch.")
                else:
                    w("The copies are not byte-identical on this branch. Merging this branch breaks the invariant.")
                w("")
        w("")

        w("#### Test evidence")
        w("")
        w("Provenance: the packet does not run tests. A row is either INHERITED FROM A")
        w("REPORT, with the artifact path cited, or NOT RUN BY THIS PACKET.")
        w("")
        if item["related_tests"]:
            w("Tests in the repository that touch the changed files:")
            w("")
            w("| Test | Run command | Provenance |")
            w("|---|---|---|")
            for path in item["related_tests"]:
                command = run_command_for(path)
                command_cell = "`%s`" % command if command else "no canonical command inferred"
                provenance = "NOT RUN BY THIS PACKET"
                if path in item["added_tests"]:
                    provenance = "NOT RUN BY THIS PACKET (added by this branch)"
                w("| `%s` | %s | %s |" % (path, command_cell, provenance))
        else:
            w("No test in the repository references the changed files by name.")
            w("")
            w("This is a gap in the evidence, not a pass.")
        w("")
        if item["runners"]:
            w("Aggregate runners in the repository that cover these tests:")
            for path in item["runners"]:
                w("- `%s`" % path)
            w("")
        if item["evidence_hits"]:
            w("Recorded evidence artifacts that mention the changed files (INHERITED FROM A REPORT):")
            for path in item["evidence_hits"][:20]:
                w("- `%s`" % path)
            if len(item["evidence_hits"]) > 20:
                w("- ... and %d more" % (len(item["evidence_hits"]) - 20))
            w("")
            w("These artifacts are the prior record. This packet did not re-run them.")
        else:
            w("No recorded evidence artifact in the repository mentions the changed files.")
        w("")

        w("#### Conflicts")
        w("")
        w("Proof method: `git merge-tree --write-tree --messages <a> <b>`, run against a")
        w("redirected object directory so the repository is not written to.")
        w("")
        others = [other for other in branches if other["name"] != name]
        if others:
            for other in others:
                result = pair_verdict(name, other["name"])
                w("Against `%s`: **%s** (rc=%d)" % (other["name"], result["verdict"], result["rc"]))
                w("")
                w("Verbatim tool output:")
                w("")
                w("```")
                for line in result["stdout"].splitlines():
                    w(line)
                if result["stderr"].strip():
                    w(result["stderr"].strip())
                w("```")
                w("")
        else:
            w("Only one branch was requested, so there is no pair to merge against.")
            w("")
        w("All-branches three-way merge: **%s**" % three_way_verdict)
        for note in three_way_notes:
            w("- %s" % note)
        w("")

        w("#### Rollback")
        w("")
        w("For the proposed merge order, this branch merges as step %d."
          % order_position.get(name, 0))
        w("")
        w("Undo this merge, before it is pushed:")
        w("")
        w("```")
        w("git reset --hard HEAD^")
        w("```")
        w("")
        w("Undo this merge, after it is pushed:")
        w("")
        w("```")
        w("git revert -m 1 --no-edit HEAD")
        w("```")
        w("")
        w("Verify the rollback worked:")
        w("")
        w("```")
        w("git status --porcelain")
        w("git log --oneline -1")
        w("git diff --stat %s HEAD" % base_commit[:8])
        w("```")
        w("")
        w("The working tree must be clean, the top commit must be the undo commit, and")
        w("the diff against the base commit must not list the files this branch changed:")
        for _, _, path in item["numstat"]:
            w("- `%s`" % path)
        w("")

        w("#### Recommendation")
        w("")
        w("**%s**" % item["verdict"])
        w("")
        for reason in item["reasons"]:
            w("- %s" % reason)
        w("")

    w("## 5. Proposed merge order")
    w("")
    if not order:
        w("No order could be proposed.")
    else:
        w("The order below merges the smallest contested change first, so every")
        w("intermediate state is the smallest possible increment on the base and stays")
        w("shippable. Each step is proven with the same merge-tree command, quoted")
        w("verbatim, so a step is only placed here when it merged clean against the")
        w("accumulated state.")
        w("")
        w("| Step | Branch | Verdict against the accumulated state | Pre-merge state |")
        w("|---|---|---|---|")
        for index, step in enumerate(order_steps, start=1):
            w(
                "| %d | `%s` | %s (rc=%d) | `%s` |"
                % (index, step["name"], step["verdict"], step["rc"], step["pre_merge_commit"][:8])
            )
        w("")
        w("Step by step, verbatim tool output:")
        for index, step in enumerate(order_steps, start=1):
            w("")
            w("Step %d, merging `%s`:" % (index, step["name"]))
            w("")
            w("```")
            for line in step["stdout"].splitlines():
                w(line)
            if step["stderr"].strip():
                w(step["stderr"].strip())
            w("```")
        w("")
        w("All-branches three-way merge: **%s**" % three_way_verdict)
        for note in three_way_notes:
            w("- %s" % note)
    w("")

    w("## 6. The single decision requested")
    w("")
    w("============================================================")
    w("DECISION REQUESTED: one word from the Captain")
    w("============================================================")
    w("")
    w("The word **merge** authorises exactly this and nothing else:")
    w("")
    w("- Creating merge commits on `%s` in the proposed order above, for these" % base_ref)
    w("  branches only:")
    for name in order:
        w("  - `%s`" % name)
    w("- Pushing those merge commits to the remote `%s`." % remote_url)
    w("")
    w("The word **merge** does NOT authorise:")
    w("")
    w("- Any deployment, to staging or to production.")
    w("- Any change to a production database, or any data migration.")
    w("- Any credential, secret, or token rotation.")
    w("- Any work in another repository, project, or lane.")
    w("- Merging, rebasing, cherry-picking, or pushing anything not listed above.")
    w("- Deleting, force-pushing, or rewriting any branch or history.")
    w("- Editing the code that this packet reports on.")
    w("")
    w("Merge authority is the Captain's alone. This packet informs the decision and")
    w("does not widen it.")
    w("")
    w("Anything the Captain wants changed first, say so instead of the single word.")
    w("")

    packet = "\n".join(out) + "\n"

    if args.out and args.out != "-":
        out_dir = os.path.dirname(os.path.abspath(args.out))
        if out_dir and not os.path.isdir(out_dir):
            sys.stderr.write(
                "fm-merge-packet.sh: output directory does not exist: %s\n" % out_dir
            )
            sys.exit(1)
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write(packet)
    else:
        sys.stdout.write(packet)

    shutil.rmtree(proof_dir, ignore_errors=True)


def ordinal_suffix(number):
    if 10 <= number % 100 <= 20:
        return "th"
    return {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")


main()
PY
rc=$?
exit $rc
