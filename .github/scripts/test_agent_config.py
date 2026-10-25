"""Static assets, guidance and Pi configuration preserve unrelated state. [D-AGENT-SKILLS] [D-PI-WEB]"""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from agent_config import AgentConfig, INSTRUCTIONS, STATIC


class AgentConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.config = AgentConfig(self.root / 'repo', self.home)
        # Pi's real convergence has its own disposable-home integration tests.
        for method in ('plan', 'install', 'verify'):
            patcher = patch.object(self.config.pi, method)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.config.pi.install.side_effect = self.config.pi.verify
        self.config.source.parent.mkdir(parents=True)
        self.config.source.write_text('Shared user guidance\n')
        for source in STATIC.values():
            path = self.config.harnesses / source
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('static asset')

    def stow(self, command, **kwargs):
        self.assertIn('--no-folding', command)
        if '--simulate' not in command:
            for relative, source in STATIC.items():
                link = self.home / relative
                link.parent.mkdir(parents=True, exist_ok=True)
                if not link.is_symlink():
                    link.symlink_to(self.config.harnesses / source)
        return subprocess.CompletedProcess(command, 0)

    def install(self):
        with patch('agent_config.subprocess.run', side_effect=self.stow):
            self.config.install()

    def test_install_and_idempotence_preserve_local_state(self):
        auth = self.home / '.pi/agent/auth.json'
        auth.parent.mkdir(parents=True)
        auth.write_text('local fixture secret')
        self.install()
        before = {name: (self.home / name).stat().st_mtime_ns for name in INSTRUCTIONS}
        self.install()
        self.assertEqual(auth.read_text(), 'local fixture secret')
        for name in INSTRUCTIONS:
            self.assertFalse((self.home / name).is_symlink())
            self.assertEqual((self.home / name).stat().st_mtime_ns, before[name])
        self.assertTrue((self.home / '.claude').is_dir())
        self.assertFalse((self.home / '.claude').is_symlink())

    def test_existing_flow_includes_pi_install_and_offline_verification(self):
        self.install()
        self.config.pi.install.assert_called_once_with()
        self.config.pi.verify.assert_called_once_with()
        self.config.verify()
        self.assertEqual(self.config.pi.verify.call_count, 2)

    def test_invalid_pi_config_blocks_static_deployment(self):
        self.config.pi.plan.side_effect = ValueError('Invalid Pi configuration')
        with patch('agent_config.subprocess.run') as run:
            with self.assertRaisesRegex(ValueError, 'Invalid Pi'):
                self.config.install()
            run.assert_not_called()
        self.assertFalse(self.config.state.exists())

    def test_managed_instruction_update(self):
        self.install()
        self.config.source.write_text('Revised guidance\n')
        self.install()
        for name in INSTRUCTIONS:
            self.assertEqual((self.home / name).read_text(), 'Revised guidance\n')

    def test_unmanaged_or_locally_changed_guidance_blocks_stow(self):
        dest = self.home / INSTRUCTIONS[0]
        dest.parent.mkdir(parents=True)
        dest.write_text('private rules')
        with patch('agent_config.subprocess.run') as run:
            with self.assertRaisesRegex(ValueError, 'Local edits'):
                self.config.install()
            run.assert_not_called()
        self.assertEqual(dest.read_text(), 'private rules')

    def test_stow_conflict_does_not_publish_guidance(self):
        with patch('agent_config.subprocess.run', side_effect=subprocess.CalledProcessError(1, 'stow')):
            with self.assertRaises(subprocess.CalledProcessError):
                self.config.install()
        self.assertFalse(self.config.state.exists())
        self.assertFalse((self.home / INSTRUCTIONS[0]).exists())

    def test_identical_guidance_adopted_but_symlink_rejected(self):
        dest = self.home / INSTRUCTIONS[0]
        dest.parent.mkdir(parents=True)
        dest.write_bytes(self.config.source.read_bytes())
        self.install()
        dest.unlink()
        dest.symlink_to(self.config.source)
        with self.assertRaisesRegex(ValueError, 'regular instruction'):
            self.config.plan()

    def test_verify_missing_install_is_read_only(self):
        before = list(self.home.rglob('*'))
        with self.assertRaises(ValueError):
            self.config.verify()
        self.assertEqual(before, list(self.home.rglob('*')))

    def test_known_legacy_links_migrate(self):
        for relative, source in STATIC.items():
            link = self.home / relative
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(self.config.repo / source)
        self.install()
        self.config.verify()

    def test_failed_stow_restores_known_legacy_links(self):
        relative, source = next(iter(STATIC.items()))
        link = self.home / relative
        link.parent.mkdir(parents=True, exist_ok=True)
        old = self.config.repo / source
        link.symlink_to(old)
        with patch('agent_config.subprocess.run', side_effect=subprocess.CalledProcessError(1, 'stow')):
            with self.assertRaises(subprocess.CalledProcessError):
                self.config.install()
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.readlink(), old)
        self.assertFalse(self.config.state.exists())

    def test_stow_command_owns_only_named_static_packages(self):
        command = self.config.stow_command()
        self.assertEqual(command[-2:], ['claude', 'pi'])
        self.assertEqual(command[2], str(self.config.harnesses))
        self.assertNotIn('--adopt', command)


if __name__ == '__main__':
    unittest.main()
