#!/usr/bin/env python3
"""Stow static harness assets; copy shared guidance without owning runtime state. [D-AGENT-SKILLS]"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from agent_skills import REPO, atomic_json, install_lock, real_parents

INSTRUCTIONS = ('.pi/agent/AGENTS.md', '.codex/AGENTS.md',
                '.claude/CLAUDE.md', '.config/opencode/AGENTS.md')
STATIC = {
    '.claude/statusline-command.sh': 'claude/.claude/statusline-command.sh',
    '.pi/agent/extensions/pi-web-access-pdf-compat.ts': 'pi/.pi/agent/extensions/pi-web-access-pdf-compat.ts',
}


class AgentConfig:
    def __init__(self, repo=REPO, home=None):
        self.repo = Path(repo)
        self.home = Path(home or Path.home()).resolve()
        self.harnesses = self.repo / 'agents/harnesses'
        self.source = self.repo / 'agents/instructions/AGENTS.md'
        self.state = self.home / '.local/state/dotfiles/agent-instructions.json'

    def plan(self):
        previous = {}
        if self.state.exists():
            previous = json.loads(self.state.read_text())
            if previous.get('version') != 1:
                raise ValueError('Unsupported instruction ownership manifest')
            previous = previous['files']
        content = self.source.read_bytes()
        desired = hashlib.sha256(content).hexdigest()
        for relative in INSTRUCTIONS:
            dest = self.home / relative
            real_parents(dest, self.home)
            if dest.is_symlink() or (dest.exists() and not dest.is_file()):
                raise ValueError(f'Expected a regular instruction file: {dest}')
            if dest.exists():
                current = hashlib.sha256(dest.read_bytes()).hexdigest()
                if current not in (desired, previous.get(relative)):
                    raise ValueError(f'Local edits/unmanaged instructions: {dest}; save and resolve first')
        return content, desired

    def stow_command(self):
        return ['stow', '--dir', str(self.harnesses), '--target', str(self.home),
                '--no-folding', '-R', 'claude', 'pi']

    def install(self):
        content, desired = self.plan()
        for relative in STATIC:
            real_parents(self.home / relative, self.home)
        # Migrate only exact links from the former top-level Stow packages.
        legacy = []
        for relative, source in STATIC.items():
            dest = self.home / relative
            if dest.is_symlink() and dest.resolve() == (self.repo / source).resolve():
                legacy.append((dest, dest.readlink()))
        try:
            for dest, _ in legacy:
                dest.unlink()
            # A dry run surfaces all other conflicts before guidance is deployed.
            subprocess.run(self.stow_command() + ['--simulate'], check=True)
            subprocess.run(self.stow_command(), check=True)
        except BaseException:
            for dest, target in legacy:
                if not dest.exists() and not dest.is_symlink():
                    dest.symlink_to(target)
            raise
        records = json.loads(self.state.read_text())['files'] if self.state.exists() else {}
        for relative in INSTRUCTIONS:
            dest = self.home / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.exists() or dest.read_bytes() != content:
                with tempfile.NamedTemporaryFile(dir=dest.parent, delete=False) as stream:
                    tmp = Path(stream.name)
                    stream.write(content)
                try:
                    tmp.chmod(0o644)
                    tmp.replace(dest)
                finally:
                    tmp.unlink(missing_ok=True)
            records[relative] = desired
            atomic_json(self.state, {'version': 1, 'files': records})
        self.verify()

    def verify(self):
        content, desired = self.plan()
        records = json.loads(self.state.read_text())['files'] if self.state.exists() else {}
        for relative in INSTRUCTIONS:
            dest = self.home / relative
            if not dest.is_file() or dest.read_bytes() != content or records.get(relative) != desired:
                raise ValueError(f'Missing/stale shared instructions: {dest}')
        for relative, source in STATIC.items():
            dest = self.home / relative
            real_parents(dest, self.home)
            if not dest.is_symlink() or dest.resolve() != (self.harnesses / source).resolve():
                raise ValueError(f'Missing/stale Stow asset: {dest}')
        print('Agent config: shared instruction copies and per-file Stow assets verified')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('install', 'verify'))
    args = parser.parse_args()
    config = AgentConfig()
    try:
        if args.action == 'install':
            with install_lock(config.home):
                config.install()
        else:
            config.verify()
    except (KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Agent config: {error}\n')


if __name__ == '__main__':
    main()
