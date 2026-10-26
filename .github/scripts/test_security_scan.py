"""Exercise privilege routing and privileged-file classification in isolation.

[D-SECURITY-SCAN]
"""

import os
from pathlib import Path
import pwd
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
        self.command("pacman", '[ "$1" = -Qq ]\n')
        for name in ("systemctl", "sshd"):
            self.command(name, "exit 1\n")
        result = self.run_scan(
            "--skip-malware", "--log-dir", str(self.root / "logs")
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Posture checks", result.stdout)
        self.assertFalse(self.capture.exists())

    def mock_clamscan(self):
        self.command(
            "clamscan",
            '''for arg do
  case "$arg" in --log=*) printf 'Infected files: 0\\n' > "${arg#--log=}" ;; esac
done
''',
        )

    def test_default_log_parent_is_created_as_invoking_user(self):
        user = pwd.getpwuid(os.getuid()).pw_name
        home = self.root / "home"
        home.mkdir()
        self.command(
            "getent",
            f"printf '%s\\n' '{user}:x:{os.getuid()}:{os.getgid()}::{home}:/bin/sh'\n",
        )
        self.command(
            "sudo",
            f'''printf '%s\\n' "$@" > '{self.capture}'
[ "$1" = -u ] && [ "$2" = '{user}' ] && [ "$3" = -- ] || exit 99
shift 3
[ "$1" = mkdir ] || exit 99
exec "$@"
''',
        )
        # Simulate root routing in a copy; every command still runs unprivileged.
        simulated_root = self.root / "root-security-scan"
        simulated_root.write_text(SCRIPT.read_text().replace('"$EUID"', '"0"'))
        simulated_root.chmod(0o755)
        self.env.update(SUDO_USER=user, XDG_STATE_HOME=str(home / ".local/state"))
        self.mock_clamscan()
        result = self.run_scan(
            "--quick", "--skip-posture", "--no-freshclam", script=simulated_root
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.capture.read_text().splitlines()[:5],
            ["-u", user, "--", "mkdir", "-p"],
        )
        parent = home / ".local/state/security-scan"
        self.assertEqual(parent.stat().st_uid, os.getuid())
        self.capture.unlink()
        result = self.run_scan("--quick", "--skip-posture", "--no-freshclam")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.capture.exists())

    def test_quick_scan_does_not_request_sudo(self):
        self.mock_clamscan()
        result = self.run_scan(
            "--quick", "--skip-posture", "--no-freshclam",
            "--log-dir", str(self.root / "logs"),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.capture.exists())


class PrivilegedFileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="privileged-files-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.logs = self.root / "logs"
        self.logs.mkdir()
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}")
        self.script = SCRIPT.read_text().rsplit('\nmain "$@"', 1)[0]
        self.command("pacman", '[ "$1" = -Qq ] || [ "$2" = /usr/bin/owned ]\n')
        self.command("getcap", "exit 0\n")

    def command(self, name, body):
        path = self.root / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)

    def inventory(self, bits=(), caps=(), failed=False):
        # Exercise production classification; intercept traversal to avoid /.
        self.command(
            "find",
            'printf "%s\\n" "$@" > "$TEST_ARGS"\n'
            'while [ "$1" != -fprint ]; do shift; done\n'
            'printf "%s" "$TEST_BITS" > "$2"\n'
            'printf "%s" "$TEST_CAPS"\n'
            + ('echo "Permission denied" >&2; exit 1\n' if failed else ""),
        )
        self.env.update(
            TEST_BITS="".join(f"{p}\n" for p in bits),
            TEST_CAPS="".join(f"{p} cap_setuid=ep\n" for p in caps),
            TEST_ARGS=str(self.root / "find-args"),
        )

    def run_check(self, extra="", finish=False):
        ending = '\nfinish\n' if finish else '\nprintf "COUNTS %s %s\\n" "$FINDINGS" "$SCAN_ERRORS"\n'
        return subprocess.run(
            ["bash", "-c", self.script + '\nLOG_DIR="$1"\n' + extra
             + '\ncheck_privileged_files\n' + ending,
             "test", str(self.logs)],
            env=self.env, capture_output=True, text=True,
        )

    def lines(self, name):
        return (self.logs / f"privileged-files{name}.txt").read_text().splitlines()

    def test_stored_copies_are_retained_but_host_anomalies_still_flagged(self):
        snapshot = "/.snapshots/796/snapshot/usr/bin/passwd"
        container = "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/42/fs/bin/su"
        unusual = "/var/lib/containerd/unexpected-suid"
        self.inventory(
            bits=[snapshot, container, unusual, "/usr/bin/owned", "/opt/rogue with spaces"],
            caps=[snapshot, "/usr/local/bin/cap with spaces cap_marker"],
        )
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("COUNTS 1 0", result.stdout)
        self.assertEqual(self.lines("-snapshots"), [snapshot])
        self.assertEqual(self.lines("-containers"), [container])
        self.assertEqual(self.lines("-unowned"), sorted([
            unusual, "/opt/rogue with spaces", "/usr/local/bin/cap with spaces cap_marker",
        ]))
        self.assertEqual(len(self.lines("")), 6)
        args = (self.root / "find-args").read_text().splitlines()
        self.assertIn("-prune", args)
        self.assertIn("-exec", args)
        self.assertNotIn("-xdev", args)
        self.assertNotIn("-r", args)

    def test_only_stored_copies_do_not_raise_host_finding(self):
        self.inventory(bits=["/.snapshots/1/snapshot/bin/su"])
        result = self.run_check()
        self.assertIn("COUNTS 0 0", result.stdout)
        self.assertIn("0 checked", result.stdout)
        self.assertEqual(self.lines("-unowned"), [])

    def test_failures_never_claim_clean_ownership(self):
        for failure in ("traversal", "getcap", "database"):
            with self.subTest(failure=failure):
                self.inventory(failed=failure == "traversal")
                extra = ""
                if failure == "getcap":
                    extra = 'have() { [ "$1" != getcap ] && command -v "$1" >/dev/null; }'
                if failure == "database":
                    self.command("pacman", "exit 1\n")
                result = self.run_check(extra)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("COUNTS 0 1", result.stdout)
                self.assertNotIn("every live-host", result.stdout)

    def test_path_lookalikes_are_not_exempt(self):
        paths = [
            "/.snapshots/not-a-number/snapshot/bin/su",
            "/.snapshots/1/unexpected/bin/su",
            "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/42/work/su",
        ]
        self.inventory(bits=paths)
        result = self.run_check()
        self.assertIn("COUNTS 1 0", result.stdout)
        self.assertEqual(self.lines("-unowned"), sorted(paths))

    def test_incomplete_exit_and_strict_finding_exit(self):
        self.inventory(failed=True)
        result = self.run_check(finish=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("incomplete scans:   1", result.stdout)
        self.inventory(bits=["/opt/rogue"])
        self.assertEqual(self.run_check(finish=True).returncode, 0)
        self.assertEqual(self.run_check("STRICT=1", finish=True).returncode, 1)

    def test_missing_package_tool_is_incomplete(self):
        result = self.run_check(
            'have() { [ "$1" != pacman ] && command -v "$1" >/dev/null; }'
        )
        self.assertIn("COUNTS 0 1", result.stdout)

    def test_shared_traversal_finds_bits_and_capabilities(self):
        fixture = self.root / "filesystem"
        fixture.mkdir()
        suid = fixture / "suid with spaces"
        suid.touch()
        suid.chmod(0o4755)
        cap = fixture / "cap with spaces"
        cap.touch()
        self.command("getcap", 'for path do case "$path" in *"/cap with spaces") printf "%s cap_setuid=ep\\n" "$path";; esac; done\n')
        self.script = self.script.replace('find / \\(', f'find "{fixture}" \\(')
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("COUNTS 1 0", result.stdout)
        self.assertEqual(self.lines("-unowned"), sorted([str(suid), str(cap)]))
        self.command("getcap", 'echo "capability read failed" >&2; exit 1\n')
        result = self.run_check()
        self.assertIn("COUNTS 1 1", result.stdout)
        self.assertNotIn("every live-host", result.stdout)


if __name__ == "__main__":
    unittest.main()
