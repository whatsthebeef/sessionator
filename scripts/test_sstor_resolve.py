#!/usr/bin/env python3
"""Tests for sstor_resolve.py, in scratch git repos. Run: python3 -m unittest scripts/test_sstor_resolve.py"""
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sstor_resolve  # noqa: E402

GLOB = "s1t1"


def run(cwd: str, *args: str) -> str:
    return subprocess.run(args, cwd=cwd, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def write(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


class ResolveTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = self._tmp.name
        self.origin = os.path.join(root, "origin.git")
        self.work = os.path.join(root, "work")
        self.other = os.path.join(root, "other")
        run(root, "git", "init", "-q", "--bare", "-b", "main", self.origin)
        run(root, "git", "clone", "-q", self.origin, self.work)
        for repo in (self.work,):
            self.configure(repo)
        write(os.path.join(self.work, "a.txt"), "base\n")
        run(self.work, "git", "add", "a.txt")
        run(self.work, "git", "commit", "-qm", "base")
        run(self.work, "git", "push", "-q", "origin", "main")
        run(self.work, "git", "switch", "-qc", GLOB)
        run(self.work, "git", "push", "-q", "-u", "origin", GLOB)
        # A second clone moves main on.
        run(root, "git", "clone", "-q", self.origin, self.other)
        self.configure(self.other)

    def configure(self, repo: str) -> None:
        run(repo, "git", "config", "user.email", "t@example.com")
        run(repo, "git", "config", "user.name", "t")
        # A mergetool that takes the other side (REMOTE) without prompting.
        run(repo, "git", "config", "merge.tool", "takeremote")
        run(repo, "git", "config", "mergetool.takeremote.cmd", 'cat "$REMOTE" > "$MERGED"')
        run(repo, "git", "config", "mergetool.takeremote.trustExitCode", "true")
        run(repo, "git", "config", "mergetool.prompt", "false")
        run(repo, "git", "config", "mergetool.keepBackup", "false")

    def commit(self, repo: str, name: str, text: str, branch_push: str) -> None:
        write(os.path.join(repo, name), text)
        run(repo, "git", "add", name)
        run(repo, "git", "commit", "-qm", f"change {name}")
        run(repo, "git", "push", "-q", "origin", branch_push)

    def move_main(self, name: str, text: str) -> None:
        run(self.other, "git", "pull", "-q", "origin", "main")
        self.commit(self.other, name, text, "main")

    def test_clean_merge_commits_and_pushes_without_mergetool(self) -> None:
        self.commit(self.work, "b.txt", "glob\n", GLOB)
        self.move_main("c.txt", "main\n")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main"), 0)
        self.assertEqual(run(self.work, "git", "log", "-1", "--format=%s"), f"{GLOB}: Merge main")
        self.assertEqual(run(self.work, "git", "rev-parse", "HEAD"), run(self.work, "git", "rev-parse", f"origin/{GLOB}"))
        self.assertTrue(os.path.exists(os.path.join(self.work, "c.txt")))

    def test_conflict_opens_mergetool_then_commits_and_pushes(self) -> None:
        self.commit(self.work, "a.txt", "glob side\n", GLOB)
        self.move_main("a.txt", "main side\n")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main"), 0)
        with open(os.path.join(self.work, "a.txt"), encoding="utf-8") as handle:
            self.assertEqual(handle.read(), "main side\n")  # the tool took REMOTE (origin/main)
        self.assertEqual(run(self.work, "git", "log", "-1", "--format=%s"), f"{GLOB}: Merge main")
        self.assertEqual(run(self.work, "git", "rev-parse", "HEAD"), run(self.work, "git", "rev-parse", f"origin/{GLOB}"))
        self.assertEqual(len(run(self.work, "git", "rev-list", "--parents", "-1", "HEAD").split()), 3)  # a merge commit

    def test_aborted_mergetool_leaves_merge_in_progress(self) -> None:
        run(self.work, "git", "config", "mergetool.takeremote.cmd", "exit 1")
        self.commit(self.work, "a.txt", "glob side\n", GLOB)
        self.move_main("a.txt", "main side\n")
        before = run(self.work, "git", "rev-parse", f"origin/{GLOB}")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main"), 1)
        self.assertTrue(sstor_resolve.merge_in_progress(self.work))
        self.assertEqual(run(self.work, "git", "rev-parse", f"origin/{GLOB}"), before)  # nothing pushed

    def test_markers_left_in_file_stop_before_commit(self) -> None:
        run(self.work, "git", "config", "mergetool.takeremote.cmd", "true")  # exits 0, leaving the markers
        self.commit(self.work, "a.txt", "glob side\n", GLOB)
        self.move_main("a.txt", "main side\n")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main"), 1)
        self.assertTrue(sstor_resolve.merge_in_progress(self.work))

    def test_resumes_after_manual_resolution(self) -> None:
        run(self.work, "git", "config", "mergetool.takeremote.cmd", "exit 1")
        self.commit(self.work, "a.txt", "glob side\n", GLOB)
        self.move_main("a.txt", "main side\n")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main"), 1)
        write(os.path.join(self.work, "a.txt"), "hand merged\n")
        run(self.work, "git", "add", "a.txt")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main"), 0)
        self.assertFalse(sstor_resolve.merge_in_progress(self.work))

    def test_uncommitted_changes_refused(self) -> None:
        write(os.path.join(self.work, "a.txt"), "dirty\n")
        with self.assertRaises(sstor_resolve.ResolveError):
            sstor_resolve.resolve(self.work, GLOB, "main")

    def test_unpushed_commits_refused(self) -> None:
        write(os.path.join(self.work, "b.txt"), "local\n")
        run(self.work, "git", "add", "b.txt")
        run(self.work, "git", "commit", "-qm", "local only")
        self.move_main("c.txt", "main\n")
        with self.assertRaises(sstor_resolve.ResolveError):
            sstor_resolve.resolve(self.work, GLOB, "main")

    def test_already_up_to_date_does_nothing(self) -> None:
        before = run(self.work, "git", "rev-parse", "HEAD")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main"), 0)
        self.assertEqual(run(self.work, "git", "rev-parse", "HEAD"), before)

    def test_failing_checks_stop_before_commit(self) -> None:
        self.commit(self.work, "b.txt", "glob\n", GLOB)
        self.move_main("c.txt", "main\n")
        before = run(self.work, "git", "rev-parse", "HEAD")
        self.assertEqual(sstor_resolve.resolve(self.work, GLOB, "main", checks="false"), 1)
        self.assertEqual(run(self.work, "git", "rev-parse", "HEAD"), before)
        self.assertTrue(sstor_resolve.merge_in_progress(self.work))


if __name__ == "__main__":
    unittest.main()
