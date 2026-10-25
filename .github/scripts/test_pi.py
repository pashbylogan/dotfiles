"""Offline integration tests for agent configuration's Pi overlay. [D-PI-WEB] [D-IDEMPOTENT]"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
WEB = "npm:pi-web-access@0.44.0"
SOL = "git:github.com/NVlabs/SoL-Pi@219568034fa54ed121ede80961655e33dfb9d0e3"


class PiInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.agent = self.home / ".pi/agent"
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = {
            k: v for k, v in os.environ.items()
            if k not in {"PI_CODING_AGENT_DIR", "PI_BIN", "XDG_CONFIG_HOME"}
        }
        self.env.update(HOME=str(self.home), PATH=f"{self.bin}:{os.environ['PATH']}",
                        PYTHONPATH=str(REPO / '.github/scripts'))
        self.log = self.home / "calls"
        self.mock("pi", r'''#!/bin/bash
set -eu
printf 'pi %s\n' "$*" >>"$HOME/calls"
[ ! -e "$HOME/fail-install" ] || exit 2
agent="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
if [ "$1" = remove ]; then
  jq '.packages |= map(select((if type == "string" then . else .source end | test("^npm:sol-pi(@|$)")) | not))' "$agent/settings.json" >"$agent/removed"
  cat "$agent/removed" >"$agent/settings.json"
  rm "$agent/removed"
  rm -rf "$agent/npm/node_modules/sol-pi"
  exit
fi
case "$2" in
  npm:pi-web-access@*)
    root="$agent/npm/node_modules"
    mkdir -p "$root/pi-web-access" "$root/undici"
    printf '{"name":"pi-web-access","version":"%s"}\n' "${2##*@}" >"$root/pi-web-access/package.json"
    [ -f "$root/undici/package.json" ] || printf '{"version":"8.12.2"}\n' >"$root/undici/package.json"
    ;;
  git:*)
    root="$agent/git/github.com/NVlabs/SoL-Pi"
    mkdir -p "$root/.git" "$root/src/sol-pi"
    touch "$root/src/sol-pi/index.ts"
    printf '%s\n' "${2##*@}" >"$root/.git/mock-head"
    ;;
  *) exit 3 ;;
esac
''')
        # Only the synthetic SoL checkout is intercepted; real git stays available.
        self.mock("git", r'''#!/bin/bash
if [[ "$1" = -C && "$2" = */git/github.com/NVlabs/SoL-Pi ]]; then
  case "$3" in
    rev-parse) cat "$2/.git/mock-head" ;;
    status) [ ! -f "$2/.git/mock-dirty" ] || printf ' M src/sol-pi/index.ts\n' ;;
    *) exit 2 ;;
  esac
else
  exec /usr/bin/git "$@"
fi
''')
        self.mock("npm", r'''#!/bin/bash
set -eu
printf 'npm %s\n' "$*" >>"$HOME/calls"
[ ! -e "$HOME/fail-npm" ] || exit 2
[ "$1 $2 $3 $5 $6" = 'update undici --prefix --ignore-scripts --legacy-peer-deps' ] || exit 3
find "$4/node_modules" -path '*/undici/package.json' -exec sh -c 'printf '\''{"version":"8.12.2"}\n'\'' >"$1"' sh {} \;
''')

    def mock(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_helper(self, command="install", ok=True):
        result = subprocess.run(
            ["python3", "-B", "-c", f"from agent_config import PiConfig; PiConfig().{command}()"], env=self.env,
            text=True, capture_output=True,
        )
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def write_json(self, name, value):
        path = self.agent / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))
        return path

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def snapshot(self):
        return {
            str(p.relative_to(self.home)): (p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns)
            for p in self.home.rglob("*") if p.is_file()
        }

    def test_fresh_and_idempotent(self):
        self.run_helper()
        settings = json.loads((self.agent / "settings.json").read_text())
        self.assertEqual(settings["packages"], [WEB, SOL])
        self.assertEqual(settings["defaultProvider"], "openai")
        sol = json.loads((self.agent / "sol-pi.json").read_text())
        for flag in ("actionFusion", "observationPack", "onlineContextCompact"):
            self.assertTrue(sol[flag])
        self.assertFalse(sol["evidencePreservingReducer"])
        web = json.loads((self.agent / "web-search.json").read_text())
        self.assertFalse(web["allowBrowserCookies"])
        self.assertEqual(web["fetchRouting"]["providers"], ["http"])
        self.assertFalse(web["fetchRouting"]["allowRemoteHostedProviders"])
        self.assertFalse(web["video"]["enabled"])
        self.assertEqual(web["pdf"]["provider"], "unpdf")
        for name in ("settings.json", "web-search.json", "sol-pi.json"):
            self.assertEqual((self.agent / name).stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.calls(), [f"pi install {WEB}", f"pi install {SOL}"])
        before = self.snapshot()
        self.run_helper()
        self.assertEqual(before, self.snapshot())
        self.assertFalse((self.agent / "auth.json").exists())

    def test_each_missing_package_repaired_independently(self):
        for name, source in (("npm/node_modules/pi-web-access/package.json", WEB),
                             ("git/github.com/NVlabs/SoL-Pi/src/sol-pi/index.ts", SOL)):
            with self.subTest(source=source):
                self.run_helper()
                (self.agent / name).unlink()
                before = len(self.calls())
                self.run_helper()
                self.assertEqual(self.calls()[before:], [f"pi install {source}"])

    def test_wrong_versions_and_dirty_git_are_repaired(self):
        self.run_helper()
        self.write_json("npm/node_modules/pi-web-access/package.json", {"name": "pi-web-access", "version": "0.1.0"})
        head = self.agent / "git/github.com/NVlabs/SoL-Pi/.git/mock-head"
        head.write_text("wrong")
        self.run_helper()
        self.assertEqual(self.calls()[-2:], [f"pi install {WEB}", f"pi install {SOL}"])
        (head.parent / "mock-dirty").touch()
        self.run_helper("verify", ok=False)

    def test_unrelated_state_and_modes_preserved(self):
        other = {"source": "npm:other-extension", "skills": []}
        settings = self.write_json("settings.json", {"deviceId": "local", "theme": "light", "packages": ["npm:pi-web-access@0.1.0", other, "npm:pi-web-access-extra"]})
        settings.chmod(0o640)
        self.write_json("web-search.json", {"exaApiKey": "fixture", "tools": {"fetchContent": {"custom": "keep"}}})
        auth = self.write_json("auth.json", {"openai": {"secret": "fixture"}})
        before = auth.read_bytes(), auth.stat().st_mtime_ns
        self.run_helper()
        data = json.loads(settings.read_text())
        self.assertEqual(data["packages"], [other, "npm:pi-web-access-extra", WEB, SOL])
        self.assertEqual(data["deviceId"], "local")
        self.assertEqual(data["theme"], "light")
        self.assertEqual(settings.stat().st_mode & 0o777, 0o640)
        self.assertEqual(before, (auth.read_bytes(), auth.stat().st_mtime_ns))
        web = json.loads((self.agent / "web-search.json").read_text())
        self.assertEqual(web["exaApiKey"], "fixture")
        self.assertEqual(web["tools"]["fetchContent"]["custom"], "keep")

    def test_privacy_profile_disables_previously_enabled_remote_features(self):
        self.write_json("sol-pi.json", {"version": 1, "evidencePreservingReducer": True})
        self.write_json("web-search.json", {
            "allowBrowserCookies": True,
            "fetchRouting": {"providers": ["http", "jina"], "allowRemoteHostedProviders": True},
            "video": {"enabled": True}, "pdf": {"provider": "gemini"},
        })
        self.run_helper()
        sol = json.loads((self.agent / "sol-pi.json").read_text())
        web = json.loads((self.agent / "web-search.json").read_text())
        self.assertFalse(sol["evidencePreservingReducer"])
        self.assertFalse(web["allowBrowserCookies"])
        self.assertFalse(web["fetchRouting"]["allowRemoteHostedProviders"])
        self.assertEqual(web["fetchRouting"]["providers"], ["http"])
        self.assertFalse(web["video"]["enabled"])
        self.assertEqual(web["pdf"]["provider"], "unpdf")
        self.run_helper("verify")

    def test_custom_agent_directory_and_launcher(self):
        self.agent = self.home / "custom-agent"
        self.env["PI_CODING_AGENT_DIR"] = str(self.agent)
        launcher = self.bin / "custom-pi"
        (self.bin / "pi").rename(launcher)
        self.env["PI_BIN"] = str(launcher)
        self.env["XDG_CONFIG_HOME"] = str(self.home / "xdg")
        self.run_helper()
        self.run_helper("verify")
        self.assertTrue((self.agent / "web-search.json").exists())
        self.assertFalse((self.home / ".pi").exists())
        self.assertFalse((self.home / "xdg").exists())

    def test_xdg_and_legacy_web_discovery(self):
        xdg = self.home / "xdg"
        self.env["XDG_CONFIG_HOME"] = str(xdg)
        self.run_helper()
        self.assertTrue((xdg / "pi/web-search.json").exists())
        self.assertFalse((self.agent / "web-search.json").exists())
        (xdg / "pi/web-search.json").unlink()
        legacy = self.home / ".pi/web-search.json"
        legacy.write_text('{"exaApiKey":"fixture"}')
        self.run_helper()
        self.assertEqual(json.loads(legacy.read_text())["exaApiKey"], "fixture")
        self.assertFalse((xdg / "pi/web-search.json").exists())

    def test_invalid_configs_fail_before_mutation(self):
        cases = [("settings.json", "{invalid"), ("settings.json", "[]"),
                 ("settings.json", '{"packages":{}}'),
                 ("web-search.json", "{} {}"),
                 ("sol-pi.json", '{"actionFusion":"yes"}'),
                 ("sol-pi.json", '{"unknown":true}')]
        for name, content in cases:
            with self.subTest(name=name, content=content):
                path = self.agent / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
                before = self.snapshot()
                self.run_helper(ok=False)
                self.assertEqual(before, self.snapshot())
                path.unlink()
        self.assertEqual(self.calls(), [])

    def test_install_and_update_failures(self):
        (self.home / "fail-install").touch()
        result = self.run_helper(ok=False)
        self.assertIn("CalledProcessError", result.stderr)
        self.assertEqual(self.calls(), [f"pi install {WEB}"])
        (self.home / "fail-install").unlink()
        self.run_helper()
        self.write_json("npm/node_modules/undici/package.json", {"version": "8.12.1"})
        (self.home / "fail-npm").touch()
        self.run_helper(ok=False)
        self.run_helper("verify", ok=False)

    def test_verify_is_offline_read_only_and_reports_drift(self):
        self.run_helper()
        for name in ("pi", "npm"):
            self.mock(name, '#!/bin/bash\nprintf "unexpected network tool\\n" >>"$HOME/calls"\nexit 99\n')
        before = self.snapshot()
        self.run_helper("verify")
        self.assertEqual(before, self.snapshot())
        for name in ("settings.json", "web-search.json", "sol-pi.json"):
            path = self.agent / name
            original = path.read_bytes()
            path.write_text("{}")
            before = self.snapshot()
            self.run_helper("verify", ok=False)
            self.assertEqual(before, self.snapshot())
            path.write_bytes(original)
        (self.agent / "npm/node_modules/pi-web-access/package.json").unlink()
        before = self.snapshot()
        self.run_helper("verify", ok=False)
        self.assertEqual(before, self.snapshot())

    def test_vulnerable_undici_update_survives_lock_and_is_idempotent(self):
        self.run_helper()
        lock = self.write_json("npm/package-lock.json", {"fixture": "retained lock"})
        original = lock.read_bytes()
        for version in ("8.0.0", "8.12.1", "8.12.2-beta.1"):
            with self.subTest(version=version):
                self.write_json("npm/node_modules/undici/package.json", {"version": version})
                before = self.snapshot()
                self.run_helper("verify", ok=False)
                self.assertEqual(before, self.snapshot())
                count = len(self.calls())
                self.run_helper()
                self.assertEqual(self.calls()[count:], [f"npm update undici --prefix {self.agent}/npm --ignore-scripts --legacy-peer-deps"])
                self.run_helper("verify")
                before = self.snapshot()
                self.run_helper()
                self.assertEqual(before, self.snapshot())
        self.assertEqual(original, lock.read_bytes())
        for version in ("7.99.0", "8.12.2", "8.13.0", "9.0.0"):
            self.write_json("npm/node_modules/undici/package.json", {"version": version})
            before = self.snapshot()
            self.run_helper()
            self.run_helper("verify")
            self.assertEqual(before, self.snapshot())

    def test_legacy_sol_npm_migrates_before_settings_merge(self):
        self.write_json("settings.json", {"packages": ["npm:sol-pi@1.1.0", "npm:other"]})
        legacy = self.write_json("npm/node_modules/sol-pi/package.json", {"name": "sol-pi"})
        self.run_helper()
        self.assertEqual(self.calls(), ["pi remove npm:sol-pi", f"pi install {WEB}", f"pi install {SOL}"])
        self.assertFalse(legacy.exists())
        self.assertEqual(json.loads((self.agent / "settings.json").read_text())["packages"], ["npm:other", WEB, SOL])
        self.run_helper("verify")
        before = self.snapshot()
        self.run_helper()
        self.assertEqual(before, self.snapshot())


if __name__ == "__main__":
    unittest.main()
