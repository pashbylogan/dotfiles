"""Exercise Pi bootstrap and repair without package downloads or model calls. [D-PI-WEB]"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class PiInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.agent = self.home / ".pi/agent"
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        self.log = self.home / "pi-calls"
        launcher = self.bin / "pi"
        launcher.write_text(
            "#!/bin/bash\n"
            'printf "%s\\n" "$*" >>"$HOME/pi-calls"\n'
            '[ ! -f "$HOME/fail-install" ] || exit 2\n'
            'mkdir -p "$PI_CODING_AGENT_DIR/npm/node_modules/pi-web-access"\n'
            'printf \'{"name":"pi-web-access","version":"%s"}\\n\' "${2##*@}" '
            '>"$PI_CODING_AGENT_DIR/npm/node_modules/pi-web-access/package.json"\n'
        )
        launcher.chmod(0o755)

    def write_json(self, name, value):
        self.agent.mkdir(parents=True, exist_ok=True)
        (self.agent / name).write_text(json.dumps(value))

    def configure(self, extra_env=None, require_node=False):
        # Source the installer's actual helpers; keep every machine-wide step out.
        return subprocess.run(
            [
                "bash",
                "-c",
                'source <(sed \'/^# ── prerequisites/,$d\' "$0"); '
                + ('have() { [ "$1" != npm ] || [ -f "$HOME/npm-ready" ]; }; '
                   'omarchy() { printf "%s\\n" "$*" >"$HOME/omarchy-calls"; touch "$HOME/npm-ready"; }; '
                   if require_node else '')
                + 'configure_pi',
                str(REPO / "install"),
            ],
            env={**{k: v for k, v in os.environ.items() if k not in {"XDG_CONFIG_HOME", "PI_CODING_AGENT_DIR"}}, "HOME": str(self.home), **(extra_env or {})},
            text=True,
            capture_output=True,
        )

    def assert_configured(self):
        result = self.configure()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads((self.agent / "settings.json").read_text())

    def test_fresh_bootstrap_and_idempotency(self):
        settings = self.assert_configured()
        self.assertEqual(settings["packages"], ["npm:pi-web-access@0.35.0"])
        self.assertEqual(settings["defaultProvider"], "openai")
        config = json.loads((self.agent / "web-search.json").read_text())
        self.assertEqual(config["searchRouting"]["providers"], ["openai", "exa"])
        self.assertEqual(config["pdf"]["provider"], "unpdf")
        self.assertEqual((self.agent / "web-search.json").stat().st_mode & 0o777, 0o600)
        before = [(self.agent / name).read_bytes() for name in ["settings.json", "web-search.json"]]
        self.assert_configured()
        after = [(self.agent / name).read_bytes() for name in ["settings.json", "web-search.json"]]
        self.assertEqual(before, after)
        self.assertEqual(self.log.read_text().splitlines(), ["install npm:pi-web-access@0.35.0"])
        # A retained declaration does not prove the package is still on disk.
        (self.agent / "npm/node_modules/pi-web-access/package.json").unlink()
        self.assert_configured()
        self.assertEqual(len(self.log.read_text().splitlines()), 2)
        self.assertFalse((self.agent / "auth.json").exists())

    def test_preserves_local_state_and_replaces_only_owned_package(self):
        other = {"source": "npm:other-extension", "skills": []}
        self.write_json("settings.json", {
            "deviceId": "local-device", "theme": "light", "lastChangelogVersion": "local",
            "packages": ["npm:pi-web-access@0.34.0", other, "npm:pi-web-access-extra"],
        })
        self.write_json("web-search.json", {
            "provider": "openai", "searchProvider": "exa", "exaApiKey": "local-secret",
            "tools": {"fetchContent": {"enabled": False, "custom": "preserve"}},
        })
        self.write_json("auth.json", {"openai": {"type": "oauth", "secret": "fixture-only"}})
        auth_before = (self.agent / "auth.json").read_bytes()
        package = self.agent / "npm/node_modules/pi-web-access/package.json"
        package.parent.mkdir(parents=True)
        package.write_text('{"name":"pi-web-access","version":"0.34.0"}')
        settings = self.assert_configured()
        self.assertEqual(settings["packages"], [other, "npm:pi-web-access-extra", "npm:pi-web-access@0.35.0"])
        self.assertEqual(settings["deviceId"], "local-device")
        self.assertEqual(settings["theme"], "light")
        self.assertEqual(settings["lastChangelogVersion"], "local")
        self.assertEqual((self.agent / "auth.json").read_bytes(), auth_before)
        config = json.loads((self.agent / "web-search.json").read_text())
        self.assertNotIn("provider", config)
        self.assertNotIn("searchProvider", config)
        self.assertEqual(config["exaApiKey"], "local-secret")
        self.assertEqual(config["tools"]["fetchContent"], {"enabled": True, "custom": "preserve"})

    def test_xdg_config_is_applied_at_the_extensions_effective_path(self):
        xdg = self.home / "config"
        result = self.configure({"XDG_CONFIG_HOME": str(xdg)})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        config = json.loads((xdg / "pi/web-search.json").read_text())
        self.assertEqual(config["searchRouting"]["providers"], ["openai", "exa"])
        self.assertFalse((self.agent / "web-search.json").exists())
        self.assertTrue((self.agent / "settings.json").exists())

    def test_missing_npm_uses_omarchys_node_setup(self):
        result = self.configure(require_node=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.home / "omarchy-calls").read_text().strip(), "install dev-env node")
        self.assertEqual(self.log.read_text().strip(), "install npm:pi-web-access@0.35.0")

    def test_install_failure_is_not_reported_as_success(self):
        (self.home / "fail-install").touch()
        result = self.configure()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Pi extension installation failed", result.stderr)

    def test_malformed_settings_are_not_replaced(self):
        self.agent.mkdir(parents=True)
        settings = self.agent / "settings.json"
        settings.write_text("{invalid")
        result = self.configure()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(settings.read_text(), "{invalid")
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
