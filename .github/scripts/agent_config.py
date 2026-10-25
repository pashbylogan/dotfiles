#!/usr/bin/env python3
"""Deploy shared guidance, static assets and mutable Pi overlays. [D-AGENT-SKILLS] [D-PI-WEB]"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from agent_skills import REPO, atomic_json, install_lock, real_parents

INSTRUCTIONS = ('.pi/agent/AGENTS.md', '.codex/AGENTS.md',
                '.claude/CLAUDE.md', '.config/opencode/AGENTS.md')
STATIC = {
    '.claude/statusline-command.sh': 'claude/.claude/statusline-command.sh',
    '.pi/agent/extensions/pi-web-access-pdf-compat.ts': 'pi/.pi/agent/extensions/pi-web-access-pdf-compat.ts',
}


class PiConfig:
    """Converge owned deltas/pins, never credentials or sessions. [D-PI-WEB]"""

    def __init__(self, repo=REPO, home=None):
        self.repo = Path(repo)
        self.home = Path(home or Path.home()).resolve()
        self.agent = Path(os.environ.get('PI_CODING_AGENT_DIR') or self.home / '.pi/agent')
        self.settings = self.agent / 'settings.json'
        self.filters = self.repo / 'agents/harnesses/pi'
        xdg = os.environ.get('XDG_CONFIG_HOME')
        web = Path(xdg) / 'pi/web-search.json' if xdg else self.agent / 'web-search.json'
        if os.environ.get('PI_CODING_AGENT_DIR'):
            web = self.agent / 'web-search.json'
        elif not web.exists() and (self.home / '.pi/web-search.json').exists():
            web = self.home / '.pi/web-search.json'
        self.files = {self.settings: 'settings', web: 'web-search', self.agent / 'sol-pi.json': 'sol-pi'}
        self.env = {**os.environ, 'HOME': str(self.home)}

    def desired(self, value, delta):
        result = subprocess.run(
            ['jq', '-f', str(self.filters / f'{delta}.jq')],
            input=json.dumps(value), text=True, capture_output=True)
        if result.returncode:
            raise ValueError(f'Invalid Pi {delta} configuration: {result.stderr.strip()}')
        return json.loads(result.stdout)

    def plan(self):
        result = {}
        for path, delta in self.files.items():
            value = json.loads(path.read_text()) if path.exists() else {}
            if not isinstance(value, dict):
                raise ValueError(f'Invalid JSON object: {path}')
            if delta == 'settings':
                packages = value.get('packages')
                if packages is not None and (not isinstance(packages, list) or any(
                    not isinstance(p, str) and not (isinstance(p, dict) and isinstance(p.get('source'), str))
                    for p in packages
                )):
                    raise ValueError(f'Invalid packages schema: {path}')
            result[path] = self.desired(value, delta)
        return result

    def sources(self):
        return self.desired({}, 'settings')['packages']

    def installed(self, source):
        if source.startswith('npm:'):
            name, version = source[4:].rsplit('@', 1)
            path = self.agent / 'npm/node_modules' / name / 'package.json'
            if not path.is_file():
                return False
            package = json.loads(path.read_text())
            return package.get('name') == name and package.get('version') == version
        if source.startswith('git:github.com/NVlabs/SoL-Pi@'):
            root = self.agent / 'git/github.com/NVlabs/SoL-Pi'
            if not (root / 'src/sol-pi/index.ts').is_file():
                return False
            head = subprocess.run(['git', '-C', str(root), 'rev-parse', 'HEAD'],
                                  text=True, capture_output=True)
            # Native npm hydration rewrites the lock; tracked source edits still fail.
            status = subprocess.run(['git', '-C', str(root), 'status', '--porcelain',
                                     '--untracked-files=no', '--', '.', ':(exclude)package-lock.json'],
                                    text=True, capture_output=True)
            return (head.returncode == status.returncode == 0 and
                    head.stdout.strip() == source.rsplit('@', 1)[1] and not status.stdout.strip())
        raise ValueError(f'Unsupported owned Pi source: {source}')

    def vulnerable_undici(self):
        for path in (self.agent / 'npm/node_modules').rglob('undici/package.json'):
            version = json.loads(path.read_text())['version']
            match = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)([-+].*)?', version)
            if not match:
                raise ValueError(f'Invalid undici version: {path}')
            major, minor, patch = map(int, match.group(1, 2, 3))
            if major == 8 and ((minor, patch) < (12, 2) or version.startswith('8.12.2-')):
                return True
        return False

    def install(self):
        # Preflight all inputs before any command or write. [D-IDEMPOTENT]
        plan = self.plan()
        pi = os.environ.get('PI_BIN') or 'pi'
        for command in (pi, 'npm'):
            if not shutil.which(command):
                raise ValueError(f'Pi configuration requires {command} on PATH')
        if self.settings.exists():
            packages = json.loads(self.settings.read_text()).get('packages') or []
            if any(re.match(r'^npm:sol-pi(@|$)', p if isinstance(p, str) else p['source']) for p in packages):
                subprocess.run([pi, 'remove', 'npm:sol-pi'], env=self.env, check=True)
                plan = self.plan()
        for path, value in plan.items():
            if path.exists() and json.loads(path.read_text()) == value:
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists():
                path.touch(mode=0o600)
            path.write_text(json.dumps(value, indent=2) + '\n')
        for source in self.sources():
            if not self.installed(source):
                subprocess.run([pi, 'install', source], env=self.env, check=True)
                if not self.installed(source):
                    raise ValueError(f'Pi did not install the requested package: {source}')
        if self.vulnerable_undici():
            subprocess.run(['npm', 'update', 'undici', '--prefix', str(self.agent / 'npm'),
                            '--ignore-scripts', '--legacy-peer-deps'], env=self.env, check=True)
        self.verify()

    def verify(self):
        # No Pi/npm invocation or provider traffic: inspect files only.
        for path, value in self.plan().items():
            if not path.is_file() or json.loads(path.read_text()) != value:
                raise ValueError(f'Missing/drifted Pi configuration: {path}')
        for source in self.sources():
            if not self.installed(source):
                raise ValueError(f'Missing or wrong Pi package: {source}')
        if self.vulnerable_undici():
            raise ValueError('Vulnerable undici 8.x; re-run make agent-config')
        print('Agent config: Pi packages and privacy-preserving settings verified')


class AgentConfig:
    def __init__(self, repo=REPO, home=None):
        self.repo = Path(repo)
        self.home = Path(home or Path.home()).resolve()
        self.harnesses = self.repo / 'agents/harnesses'
        self.source = self.repo / 'agents/instructions/AGENTS.md'
        self.state = self.home / '.local/state/dotfiles/agent-instructions.json'
        self.pi = PiConfig(self.repo, self.home)

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
        self.pi.plan()
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
        self.pi.install()
        self.verify_assets()

    def verify(self):
        self.verify_assets()
        self.pi.verify()

    def verify_assets(self):
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
