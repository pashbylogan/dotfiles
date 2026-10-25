"""Source provenance checks stay offline; update checks never apply changes. [D-AGENT-SKILLS]"""
from contextlib import redirect_stdout
import io
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from agent_sources import REPO, check_updates, validate_sources


class AgentSourcesTests(unittest.TestCase):
    def test_real_inventory_validates_offline(self):
        resources = validate_sources()
        self.assertEqual({name for name, _ in resources},
                         {'skill/ub-mode', 'tool/crapper', 'tool/dryer', 'tool/mutator'})

    def fixture(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        shutil.copytree(REPO / 'agents', root / 'agents', ignore=shutil.ignore_patterns('__pycache__', '.pytest_cache', '.venv'))
        return root

    def test_vendored_edit_rejected(self):
        repo = self.fixture()
        (repo / 'agents/skills/ub-mode/SKILL.md').write_text('local change')
        with self.assertRaisesRegex(ValueError, 'Vendored content changed'):
            validate_sources(repo)

    def test_tool_pin_drift_rejected(self):
        repo = self.fixture()
        recipe = repo / 'agents/tools/pyproject.toml'
        recipe.write_text(recipe.read_text().replace('6fd92c4c9bcc56efb64a2f8743d5a2993bcfd42d', '0' * 40))
        with self.assertRaisesRegex(ValueError, 'Tool recipe differs'):
            validate_sources(repo)

    def test_unknown_reference_tool_rejected(self):
        repo = self.fixture()
        manifest = repo / 'agents/sources.toml'
        manifest.write_text(manifest.read_text().replace('"mutator"]', '"missing"]'))
        with self.assertRaisesRegex(ValueError, 'Unknown reference tool'):
            validate_sources(repo)

    def test_unknown_skill_rejected(self):
        repo = self.fixture()
        (repo / 'agents/skills/unknown').mkdir()
        with self.assertRaisesRegex(ValueError, 'inventory differs'):
            validate_sources(repo)

    def test_update_report_current_and_changed(self):
        resources = [('skill/demo', {'repository': 'https://example.test/demo.git', 'commit': 'a' * 40})]
        def run(command, **kwargs):
            self.assertEqual(command[:3], ['git', 'ls-remote', '--exit-code'])
            self.assertEqual(kwargs['env']['GIT_TERMINAL_PROMPT'], '0')
            return subprocess.CompletedProcess(command, 0, 'b' * 40 + '\tHEAD\n')
        stream = io.StringIO()
        with redirect_stdout(stream):
            self.assertEqual(check_updates(resources, runner=run), 0)
        self.assertIn('CHANGED (review required)', stream.getvalue())
        def current(command, **kwargs):
            return subprocess.CompletedProcess(command, 0, 'a' * 40 + '\tHEAD\n')
        with redirect_stdout(stream):
            self.assertEqual(check_updates(resources, runner=current), 0)
        self.assertIn('CURRENT', stream.getvalue())

    def test_network_failure_is_not_current(self):
        def fail(command, **kwargs):
            raise subprocess.TimeoutExpired(command, 30)
        stream = io.StringIO()
        with redirect_stdout(stream):
            failures = check_updates([('skill/demo', {'repository': 'https://example.test/demo.git', 'commit': 'a' * 40})], runner=fail)
        self.assertEqual(failures, 1)
        self.assertIn('check failed', stream.getvalue())


if __name__ == '__main__':
    unittest.main()
