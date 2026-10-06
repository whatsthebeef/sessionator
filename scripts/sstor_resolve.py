#!/usr/bin/env python3
"""sstor --glob <id> --resolve: merge origin/<base> into a glob's branch in the developer's mergetool.

Usage: sstor_resolve.py <worktree> <glob-id> <base-branch>

Standard library only. Runs git in the worktree with the terminal attached, so the developer's
mergetool opens in their own terminal. Never force-pushes and never involves Claude or a routine.
"""
import os
import subprocess
import sys

MARKER_PREFIXES = ("<<<<<<< ", ">>>>>>> ")


class ResolveError(Exception):
    """A refusal or failure, reported as one line (exit 1)."""


def git(worktree: str, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(
        ["git", "-C", worktree, *args],
        stdout=subprocess.PIPE,
        text=True,
        check=False,
    )
    if check and result.returncode != 0:
        raise ResolveError(f"git {' '.join(args)} failed in {worktree}")
    return result


def git_interactive(worktree: str, *args: str) -> int:
    """Runs git attached to the developer's terminal (stdin, stdout and stderr inherited)."""
    return subprocess.run(["git", "-C", worktree, *args], check=False).returncode


def say(message: str) -> None:
    print(f"sstor: {message}", file=sys.stderr)


def merge_in_progress(worktree: str) -> bool:
    return git(worktree, "rev-parse", "-q", "--verify", "MERGE_HEAD", check=False).returncode == 0


def unmerged_files(worktree: str) -> list[str]:
    out = git(worktree, "diff", "--name-only", "--diff-filter=U").stdout
    return [line for line in out.splitlines() if line]


def files_with_markers(worktree: str, files: list[str]) -> list[str]:
    found = []
    for name in files:
        path = os.path.join(worktree, name)
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                if any(line.startswith(MARKER_PREFIXES) for line in handle):
                    found.append(name)
        except OSError:
            continue  # deleted by the resolution
    return found


def merged_files(worktree: str) -> list[str]:
    out = git(worktree, "diff", "--cached", "--name-only").stdout
    return [line for line in out.splitlines() if line]


def sync_branch(worktree: str, glob_id: str, base: str) -> None:
    """Fetches the base and the glob's branch and checks the branch is at origin/<id>."""
    if git(worktree, "fetch", "--quiet", "origin", base, glob_id, check=False).returncode != 0:
        raise ResolveError(f"could not fetch origin/{base} and origin/{glob_id}")
    branch = git(worktree, "symbolic-ref", "--quiet", "--short", "HEAD", check=False).stdout.strip()
    if branch != glob_id:
        raise ResolveError(
            f"{worktree} is on '{branch or 'a detached HEAD'}', not {glob_id}; "
            f"check out {glob_id} there (git -C {worktree} switch {glob_id}) and run this again"
        )
    remote = f"origin/{glob_id}"
    if git(worktree, "rev-parse", "HEAD").stdout == git(worktree, "rev-parse", remote).stdout:
        return
    if git(worktree, "merge-base", "--is-ancestor", "HEAD", remote, check=False).returncode == 0:
        git(worktree, "merge", "--ff-only", "--quiet", remote)
        say(f"fast-forwarded {glob_id} to {remote}")
    elif git(worktree, "merge-base", "--is-ancestor", remote, "HEAD", check=False).returncode == 0:
        raise ResolveError(
            f"{glob_id} has commits that are not on {remote}; push them first "
            f"(git -C {worktree} push origin {glob_id}). Nothing was merged"
        )
    else:
        raise ResolveError(
            f"{glob_id} and {remote} have diverged; sort that out first "
            f"(git -C {worktree} log --oneline --graph {glob_id} {remote}). Nothing was merged"
        )


def run_mergetool(worktree: str) -> None:
    configured = git(worktree, "config", "--get", "merge.tool", check=False).stdout.strip()
    if configured:
        say(f"opening your mergetool ({configured}) on {len(unmerged_files(worktree))} conflicted file(s)")
    else:
        say("no merge.tool is configured, so git picks the first tool it finds")
        say("set one with: git config --global merge.tool <vimdiff|nvimdiff|meld|...>")
    git_interactive(worktree, "mergetool")


def finish_hint(worktree: str) -> str:
    return (
        f"to continue: git -C {worktree} mergetool (then run sstor --resolve again); "
        f"to abort: git -C {worktree} merge --abort"
    )


def resolve(worktree: str, glob_id: str, base: str, checks: str | None = None) -> int:
    resuming = merge_in_progress(worktree)
    if resuming:
        say(f"a merge is already in progress in {worktree}; carrying on with it")
    else:
        if git(worktree, "status", "--porcelain", "--untracked-files=no").stdout.strip():
            raise ResolveError(
                f"{glob_id} has uncommitted changes in {worktree}; commit them (or stash them) "
                f"and run this again. Nothing was merged"
            )
        sync_branch(worktree, glob_id, base)
        up_to_date = git(worktree, "merge-base", "--is-ancestor", f"origin/{base}", "HEAD", check=False)
        if up_to_date.returncode == 0:
            say(f"{glob_id} already contains origin/{base}; nothing to merge")
            return 0
        merged = git(worktree, "merge", "--no-commit", "--no-ff", f"origin/{base}", check=False)
        if merged.returncode == 0:
            say(f"origin/{base} merged into {glob_id} cleanly; no mergetool needed")
        elif not unmerged_files(worktree):
            git(worktree, "merge", "--abort", check=False)
            raise ResolveError(f"merging origin/{base} into {glob_id} failed without conflicts; nothing was merged")
    if unmerged_files(worktree):
        run_mergetool(worktree)
        left = unmerged_files(worktree)
        if left:
            say(f"still unresolved: {', '.join(left)}")
            say(finish_hint(worktree))
            return 1
    marked = files_with_markers(worktree, merged_files(worktree))
    if marked:
        say(f"conflict markers remain in: {', '.join(marked)}")
        say(f"fix them and 'git -C {worktree} add' each file, then run sstor --resolve again; "
            f"to abort: git -C {worktree} merge --abort")
        return 1
    if checks:
        say(f"running checks: {checks}")
        if subprocess.run(checks, shell=True, cwd=worktree, check=False).returncode != 0:
            say(f"the checks failed; the merge is left staged in {worktree}. Fix it, then run sstor --resolve again, "
                f"or abort with: git -C {worktree} merge --abort")
            return 1
    else:
        say("no fast checks known to sstor for this project; skipping them")
    if git(worktree, "commit", "-q", "-m", f"{glob_id}: Merge {base}", check=False).returncode != 0:
        raise ResolveError(f"could not commit the merge in {worktree}")
    if git_interactive(worktree, "push", "origin", glob_id) != 0:
        say(f"the merge is committed but the push failed; run: git -C {worktree} push origin {glob_id}")
        return 1
    say(f"merged origin/{base} into {glob_id} and pushed")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print("usage: sstor_resolve.py <worktree> <glob-id> <base-branch>", file=sys.stderr)
        return 2
    worktree, glob_id, base = argv[1:]
    try:
        return resolve(worktree, glob_id, base, os.environ.get("SSTOR_CHECKS") or None)
    except ResolveError as err:
        say(str(err))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
