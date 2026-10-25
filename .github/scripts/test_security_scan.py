"""Exercise privilege routing without elevating privileges or scanning files.

[D-SECURITY-SCAN]
"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "bin/.local/bin/security-scan"


@unittest.skipIf(os.geteuid() == 0, "privilege routing requires an unprivileged caller")
class SecurityScanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="security-scan-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.capture = self.root / "sudo-args"
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}")
        self.command("sudo", f"printf '%s\\n' \"$@\" > '{self.capture}'\nexit 73\n")

    def command(self, name, body):
        path = self.root / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)
        return path

    def run_scan(self, *args, script=SCRIPT):
        return subprocess.run(
            [str(script), *args], env=self.env, capture_output=True, text=True
        )

    def test_full_scan_resolves_symlink_and_preserves_arguments(self):
        target = self.root / "directory with spaces" / "security-scan"
        target.parent.mkdir()
        target.write_text(SCRIPT.read_text())
        target.chmod(0o755)
        link = self.root / "security-scan"
        link.symlink_to(target)
        logs = str(self.root / "logs with spaces")
        result = self.run_scan("--no-freshclam", "--log-dir", logs, script=link)
        self.assertEqual(result.returncode, 73)
        self.assertEqual(
            self.capture.read_text().splitlines(),
            ["--", str(target), "--no-freshclam", "--log-dir", logs],
        )
        self.assertFalse(Path(logs).exists())

    def test_help_and_invalid_options_do_not_request_sudo(self):
        for args, status in [
            (["--help"], 0),
            (["--unknown"], 2),
            (["--log-dir"], 2),
            (["unexpected-argument"], 2),
            (["--skip-malware", "--skip-posture"], 2),
        ]:
            with self.subTest(args=args):
                self.assertEqual(self.run_scan(*args).returncode, status)
                self.assertFalse(self.capture.exists())

    def test_posture_only_does_not_request_sudo(self):
        # Stub host inspection so this routing test never traverses real files.
        for name in ("find", "getcap", "ss"):
            self.command(name, "exit 0\n")
        for name in ("pacman", "systemctl", "sshd"):
            self.command(name, "exit 1\n")
        result = self.run_scan(
            "--skip-malware", "--log-dir", str(self.root / "logs")
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Posture checks", result.stdout)
        self.assertFalse(self.capture.exists())

    def test_quick_scan_does_not_request_sudo(self):
        self.command(
            "clamscan",
            '''for arg do
  case "$arg" in --log=*) printf 'Infected files: 0\\n' > "${arg#--log=}" ;; esac
done
''',
        )
        result = self.run_scan(
            "--quick", "--skip-posture", "--no-freshclam",
            "--log-dir", str(self.root / "logs"),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.capture.exists())


if __name__ == "__main__":
    unittest.main()
