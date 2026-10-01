"""Exercise cleanup selection without deleting real installations. [D-CI]"""

import contextlib
import io
import os
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import prune_mise


class CleanupTests(unittest.TestCase):
    def run_cleanup(self, roots, scans, refresh=None, dry_run=False, returncode=0):
        versions = [roots] + ([refresh] if refresh is not None else [roots] * len(roots))
        with (
            patch.object(prune_mise, "candidates", side_effect=versions),
            patch.object(prune_mise, "consumers", side_effect=scans),
            patch.object(prune_mise.subprocess, "run") as run,
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            run.return_value.returncode = returncode
            status = prune_mise.main(["--dry-run"] if dry_run else [])
        return status, [call.args[0] for call in run.call_args_list]

    def test_busy_version_retained_while_idle_version_removed(self):
        roots = {"/busy": "tool@1", "/idle": "tool@2"}
        status, commands = self.run_cleanup(
            roots, [([(42, "worker", ["tool@1"])], []), ([], [])]
        )
        self.assertEqual(status, 0)
        self.assertEqual(commands, [["mise", "uninstall", "--yes", "--quiet", "tool@2"]])

    def test_all_busy_is_successful_noop(self):
        status, commands = self.run_cleanup(
            {"/busy": "tool@1"}, [([(42, "worker", ["tool@1"])], [])]
        )
        self.assertEqual((status, commands), (0, []))

    def test_new_consumer_prevents_removal(self):
        status, commands = self.run_cleanup(
            {"/idle": "tool@1"}, [([], []), ([(42, "worker", ["tool@1"])], [])]
        )
        self.assertEqual((status, commands), (0, []))

    def test_new_config_reference_prevents_removal(self):
        status, commands = self.run_cleanup(
            {"/idle": "tool@1"}, [([], [])], refresh={}
        )
        self.assertEqual((status, commands), (0, []))

    def test_dry_run_never_uninstalls(self):
        status, commands = self.run_cleanup(
            {"/idle": "tool@1"}, [([], [])], dry_run=True
        )
        self.assertEqual((status, commands), (0, []))

    def test_uninstall_failure_is_reported(self):
        status, commands = self.run_cleanup(
            {"/idle": "tool@1"}, [([], []), ([], [])], returncode=1
        )
        self.assertEqual(status, 1)
        self.assertEqual(len(commands), 1)

    def test_uninstall_failure_does_not_stop_other_candidates(self):
        status, commands = self.run_cleanup(
            {"/one": "tool@1", "/two": "tool@2"},
            [([], []), ([], []), ([], [])],
            returncode=1,
        )
        self.assertEqual(status, 1)
        self.assertEqual(len(commands), 2)

    def test_open_file_reference(self):
        with tempfile.TemporaryDirectory() as root:
            with open(root + "/resource", "w"):
                matches, _ = prune_mise.consumers({root: "fixture@1"})
                self.assertTrue(any(pid == os.getpid() for pid, _, _ in matches))

    def test_live_cwd_reference_and_directory_boundary(self):
        with tempfile.TemporaryDirectory() as root:
            worker = subprocess.Popen(["/usr/bin/sleep", "30"], cwd=root)
            try:
                matches, _ = prune_mise.consumers({root: "fixture@1"})
                self.assertTrue(any(pid == worker.pid for pid, _, _ in matches))
                matches, _ = prune_mise.consumers({root + "-other": "fixture@2"})
                self.assertFalse(any(pid == worker.pid for pid, _, _ in matches))
            finally:
                worker.terminate()
                worker.wait()


if __name__ == "__main__":
    unittest.main()
