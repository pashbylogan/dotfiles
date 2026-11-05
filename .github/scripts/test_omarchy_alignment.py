"""Check native Omarchy contracts without touching the desktop. [D-CI]"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
VERIFY = (REPO / '.github/scripts/verify.sh').read_text()
INSTALL = (REPO / 'install').read_text()


def section(text, start, end):
    return start + text.split(start, 1)[1].split(end, 1)[0]


class OmarchyAlignmentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)

    def run_shell(self, body, path=None):
        result = subprocess.run(
            ['/bin/bash', '-c',
             'pretty() { echo "$1"; }; pass() { echo PASS; }; miss() { echo MISS; };\n' + body],
            env={**os.environ, 'HOME': str(self.home),
                 'PATH': str(path or '/usr/bin'), 'REPO': str(REPO)},
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def check_agents(self, relative_path='.local/share/mise/shims'):
        shims = self.home / '.local/share/mise/shims'
        shims.mkdir(parents=True)
        selected = self.home / relative_path
        selected.mkdir(parents=True, exist_ok=True)
        for agent in 'codex claude crush agy copilot opencode pi omp grok'.split():
            shim = shims / agent
            shim.symlink_to('/usr/bin/true')
            if selected != shims:
                binary = selected / agent
                binary.write_text('#!/bin/sh\nexit 99\n')
                binary.chmod(0o755)
        body = section(VERIFY, 'for agent in codex ', '\ncheck_jq_fixed_point()')
        return self.run_shell(body, path=selected)

    def test_native_shims(self):
        self.assertEqual(self.check_agents().splitlines(), ['PASS'] * 9)

    def test_mise_activation_can_precede_shims(self):
        result = self.check_agents('.local/share/mise/installs/agent/latest/bin')
        self.assertEqual(result.splitlines(), ['PASS'] * 9)

    def test_unmanaged_binaries_are_reported(self):
        self.assertEqual(self.check_agents('unmanaged').splitlines(), ['MISS'] * 9)

    def test_retired_plugin_cleanup_preserves_local_files(self):
        plugin = self.home / '.config/omarchy/plugins/pashbyl.workspaces'
        plugin.mkdir(parents=True)
        manifest = plugin / 'manifest.json'
        manifest.symlink_to(REPO / 'omarchy/.config/omarchy/plugins/pashbyl.workspaces/manifest.json')
        qml = plugin / 'Workspaces.qml'
        qml.write_text('personal replacement')
        self.run_shell(section(INSTALL, 'for plugin_file in manifest.json ', '\nSTOW_PKGS='))
        self.assertFalse(manifest.is_symlink())
        self.assertEqual(qml.read_text(), 'personal replacement')

    def test_t3_installation_contract(self):
        appimage = self.home / '.local/share/t3code/T3-Code.AppImage'
        launcher = self.home / '.local/share/applications/t3code.desktop'
        body = 'source "$REPO/lib/style.sh"; if t3code_installed; then echo PASS; else echo MISS; fi'
        self.assertEqual(self.run_shell(body).strip(), 'MISS')
        appimage.parent.mkdir(parents=True)
        appimage.touch(mode=0o755)
        self.assertEqual(self.run_shell(body).strip(), 'MISS')
        launcher.parent.mkdir(parents=True)
        launcher.touch()
        self.assertEqual(self.run_shell(body).strip(), 'PASS')
        appimage.chmod(0o644)
        self.assertEqual(self.run_shell(body).strip(), 'MISS')

    def test_layout_checks_all_sections(self):
        shell = self.home / '.config/omarchy/shell.json'
        shell.parent.mkdir(parents=True)
        layout = {'left': [{'id': 'omarchy.menu'}, {'id': 'omarchy.workspaces'}],
                  'centerBegin': [], 'center': [], 'centerEnd': [], 'right': [], 'tray': []}
        body = section(VERIFY, 'SHELL_JSON=', '\n# Git checkout,')
        shell.write_text(json.dumps({'bar': {'layout': layout}}))
        self.assertEqual(self.run_shell(body).strip(), 'PASS')
        layout['centerEnd'].append({'id': 'pashbyl.workspaces'})
        shell.write_text(json.dumps({'bar': {'layout': layout}}))
        self.assertEqual(self.run_shell(body).strip(), 'MISS')


if __name__ == '__main__':
    unittest.main()
