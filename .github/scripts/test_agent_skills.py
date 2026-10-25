"""Managed copies preserve unrelated skills and reject local drift. [D-AGENT-SKILLS]"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('agent_skills', Path(__file__).with_name('agent_skills.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SkillDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.repo = self.root / 'repo'
        self.source = self.repo / 'agents/skills/demo'
        self.source.mkdir(parents=True)
        (self.source / 'SKILL.md').write_text('canonical skill\n')
        self.deploy = module.Deployment(self.repo, self.home)
        self.dest = self.home / '.agents/skills/demo'

    def install_copies(self):
        self.deploy.copy_skills(self.deploy.plan())

    def test_real_copies_and_idempotent(self):
        self.install_copies()
        before = self.dest.stat().st_mtime_ns
        state = self.deploy.state.read_bytes()
        self.install_copies()
        self.assertFalse(self.dest.is_symlink())
        self.assertEqual(self.dest.stat().st_mtime_ns, before)
        self.assertEqual(self.deploy.state.read_bytes(), state)
        self.assertEqual(len(self.deploy.records()), len(module.ROOTS))

    def test_managed_update(self):
        self.install_copies()
        (self.source / 'SKILL.md').write_text('new version\n')
        self.install_copies()
        self.assertEqual((self.dest / 'SKILL.md').read_text(), 'new version\n')

    def test_new_skill_is_discovered_without_a_hardcoded_list(self):
        self.install_copies()
        added = self.source.parent / 'another-skill'
        added.mkdir()
        (added / 'SKILL.md').write_text('new skill\n')
        self.install_copies()
        for root in module.ROOTS:
            self.assertEqual((self.home / root / 'another-skill/SKILL.md').read_text(), 'new skill\n')
        self.assertEqual(len(self.deploy.records()), 2 * len(module.ROOTS))

    def test_simplify_preserves_claude_and_deploys_to_other_roots(self):
        added = self.source.parent / 'simplify'
        added.mkdir()
        (added / 'SKILL.md').write_text('portable simplify\n')
        claude = self.home / '.claude/skills/simplify'
        claude.mkdir(parents=True)
        (claude / 'SKILL.md').write_text('existing personal skill')
        self.install_copies()
        for root in module.ROOTS:
            if root != '.claude/skills':
                copy = self.home / root / 'simplify'
                self.assertFalse(copy.is_symlink())
                self.assertEqual((copy / 'SKILL.md').read_text(), 'portable simplify\n')
        self.assertEqual((claude / 'SKILL.md').read_text(), 'existing personal skill')
        self.assertNotIn('.claude/skills/simplify', self.deploy.records())
        self.assertEqual(len(self.deploy.records()), 2 * len(module.ROOTS) - 1)

    def test_local_edit_blocks_entire_plan(self):
        self.install_copies()
        changed = self.home / '.config/opencode/skills/demo/SKILL.md'
        changed.write_text('user edit')
        (self.source / 'SKILL.md').write_text('new version')
        with self.assertRaisesRegex(ValueError, 'Local edits'):
            self.install_copies()
        self.assertEqual((self.dest / 'SKILL.md').read_text(), 'canonical skill\n')
        self.assertEqual(changed.read_text(), 'user edit')

    def test_unmanaged_conflict_preserved(self):
        self.dest.mkdir(parents=True)
        (self.dest / 'SKILL.md').write_text('unmanaged')
        with self.assertRaisesRegex(ValueError, 'unmanaged'):
            self.install_copies()
        self.assertFalse(self.deploy.state.exists())

    def test_identical_existing_tree_can_be_adopted(self):
        self.dest.mkdir(parents=True)
        (self.dest / 'SKILL.md').write_text('canonical skill\n')
        self.install_copies()
        self.assertEqual(len(self.deploy.records()), len(module.ROOTS))

    def test_unrelated_skills_preserved(self):
        unrelated = self.dest.parent / 'other'
        unrelated.mkdir(parents=True)
        (unrelated / 'SKILL.md').write_text('other')
        self.install_copies()
        self.assertEqual((unrelated / 'SKILL.md').read_text(), 'other')

    def test_added_files_and_directories_are_drift(self):
        self.install_copies()
        (self.dest / 'personal-notes').mkdir()
        with self.assertRaises(ValueError):
            self.deploy.plan()

    def test_source_and_destination_symlinks_rejected(self):
        self.dest.parent.mkdir(parents=True)
        self.dest.symlink_to(self.source, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'real skill directory'):
            self.deploy.plan()
        self.dest.unlink()
        (self.source / 'link').symlink_to(self.source / 'SKILL.md')
        with self.assertRaisesRegex(ValueError, 'symlink inside'):
            self.deploy.plan()

    def test_symlinked_parent_rejected(self):
        outside = self.root / 'outside'
        outside.mkdir()
        (self.home / '.agents').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlinked parent'):
            self.deploy.plan()
        self.assertFalse((outside / 'skills').exists())

    def test_stale_manifest_version_rejected(self):
        self.deploy.state.parent.mkdir(parents=True)
        self.deploy.state.write_text(json.dumps({'version': 999, 'skills': {}}))
        with self.assertRaisesRegex(ValueError, 'Unsupported ownership'):
            self.deploy.plan()

    def test_cli_conflicts_rejected(self):
        directory = self.home / '.local/bin'
        directory.mkdir(parents=True)
        (directory / 'dryer').write_text('unmanaged')
        with self.assertRaisesRegex(ValueError, 'executable'):
            self.deploy.links()

    def test_runtime_failure_does_not_publish_skills(self):
        with patch.object(module.subprocess, 'run', side_effect=OSError('uv failed')):
            with self.assertRaisesRegex(OSError, 'uv failed'):
                self.deploy.install()
        self.assertFalse(self.dest.exists())
        self.assertFalse(self.deploy.state.exists())

    def test_verify_success_and_recipe_drift(self):
        self.install_copies()
        self.deploy.recipe.mkdir(parents=True)
        for name in ('pyproject.toml', 'uv.lock', '.python-version'):
            (self.deploy.recipe / name).write_text('pinned')
        for link, target in self.deploy.links():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('#!/bin/sh\nexit 0\n')
            target.chmod(0o755)
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(target)
        receipt = self.deploy.runtime / '.dotfiles-recipe.sha256'
        receipt.write_text(self.deploy.recipe_hash() + '\n')
        self.deploy.verify()
        (self.deploy.recipe / 'uv.lock').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'recipe changed'):
            self.deploy.verify()

    def test_verify_is_read_only_on_missing_install(self):
        before = sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))
        with self.assertRaises(ValueError):
            self.deploy.verify()
        self.assertEqual(before, sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*')))


if __name__ == '__main__':
    unittest.main()
