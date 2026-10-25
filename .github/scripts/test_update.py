"""Exercise the update wrapper without updating or pruning this machine. [D-CI]"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]


class UpdateTests(unittest.TestCase):
    def run_update(self, mise_version="2026.10.13", **failures):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "commands"
            for command in ("omarchy", "uv", "mise", "pacman"):
                script = root / command
                script.write_text(
                    '#!/bin/sh\n'
                    f'printf "%s\\n" "{command} $*" >> "$COMMAND_LOG"\n'
                    f'if [ "{command} $*" = "mise version" ]; then\n'
                    '  printf "%s\\n" "$MISE_VERSION"; exit 0\n'
                    'fi\n'
                    f'exit "${{{command.upper()}_STATUS:-0}}"\n'
                )
                script.chmod(0o755)
            # Override only verification: invoking the real target would inspect
            # the host instead of the command sequence under test.
            override = root / "Makefile"
            override.write_text(
                f'include {REPO / "Makefile"}\n'
                'verify:\n\t@printf "verify\\n" >> "$$COMMAND_LOG"\n'
            )
            env = {
                **os.environ,
                "PATH": f"{root}:{os.environ['PATH']}",
                "COMMAND_LOG": str(log),
                "NO_COLOR": "1",
                "OMARCHY_STATUS": "0",
                "UV_STATUS": "0",
                "MISE_STATUS": "0",
                "MISE_VERSION": mise_version,
                **{f"{command.upper()}_STATUS": str(code) for command, code in failures.items()},
            }
            # Drop inherited make state so the test also works inside make ci.
            for name in ("MAKEFLAGS", "MFLAGS", "MAKELEVEL", "MAKEFILES"):
                env.pop(name, None)
            result = subprocess.run(
                [shutil.which("make"), "--no-print-directory", "update"],
                cwd=root, env=env, capture_output=True, text=True, timeout=20,
            )
            return result, log.read_text().splitlines()

    def test_native_delegation_without_pacman_preflight(self):
        result, commands = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "omarchy update -y", "uv self update", "mise version",
            "mise prune --tools --yes", "verify",
        ])
        self.assertIn("Omarchy owns orphan review", result.stdout)

    def test_omarchy_failure_still_runs_remaining_steps(self):
        result, commands = self.run_update(omarchy=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("returned non-zero", result.stdout)
        self.assertEqual(commands[-2:], ["mise prune --tools --yes", "verify"])

    def test_uv_failure_still_prunes_and_verifies(self):
        result, commands = self.run_update(uv=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("'uv self update' returned non-zero", result.stdout)
        self.assertEqual(commands[-2:], ["mise prune --tools --yes", "verify"])

    def test_old_mise_is_not_pruned_even_when_update_fails(self):
        result, commands = self.run_update(mise_version="2026.9.14", omarchy=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("mise prune --tools --yes", commands)
        self.assertIn("requires mise >= 2026.10.13", result.stdout)
        self.assertEqual(commands[-1], "verify")

    def test_prune_failure_still_verifies(self):
        result, commands = self.run_update(mise=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Mise cleanup failed", result.stdout)
        self.assertEqual(commands[-1], "verify")


if __name__ == "__main__":
    unittest.main()
