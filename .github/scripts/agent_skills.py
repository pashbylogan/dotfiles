#!/usr/bin/env python3
"""Deploy repo-owned skill copies and an isolated, locked CLI environment. [D-AGENT-SKILLS]"""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[2]
TOOLS = ('crapper', 'dryer', 'mutator')
# Codex and Pi discover the shared root natively. Keep OpenCode's compatibility
# copy until its installed API can confirm native shared-root discovery.
ROOTS = ('.agents/skills', '.claude/skills', '.config/opencode/skills')


def digest(directory):
    """Include every entry so added files or symlinks cannot be silently lost."""
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError(f'Expected a real skill directory: {directory}')
    entries = {}
    for path in sorted(directory.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Refusing symlink inside skill: {path}')
        if path.is_file():
            value = hashlib.sha256(path.read_bytes()).hexdigest()
        elif path.is_dir():
            value = 'directory'
        else:
            raise ValueError(f'Unsupported skill entry: {path}')
        entries[str(path.relative_to(directory))] = value
    return hashlib.sha256(json.dumps(entries, sort_keys=True).encode()).hexdigest()


def real_parents(path, home):
    for parent in (path.parent, *path.parents):
        if parent == home:
            break
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError(f'Refusing non-directory or symlinked parent: {parent}')


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as stream:
        tmp = Path(stream.name)
        json.dump(data, stream, sort_keys=True, indent=2)
        stream.write('\n')
    try:
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)


class Deployment:
    def __init__(self, repo=REPO, home=None):
        self.repo = Path(repo)
        self.home = Path(home or Path.home()).resolve()
        self.sources = self.repo / 'agents/skills'
        self.runtime = self.home / '.local/share/unclebob-tools'
        self.state = self.home / '.local/state/dotfiles/agent-skills.json'
        self.recipe = self.repo / 'agents/tools'

    def records(self):
        if not self.state.exists():
            return {}
        data = json.loads(self.state.read_text())
        if data.get('version') != 1 or not isinstance(data.get('skills'), dict):
            raise ValueError(f'Unsupported ownership manifest: {self.state}')
        return data['skills']

    def plan(self):
        previous = self.records()
        result = []
        for source in sorted(self.sources.iterdir()):
            if not (source / 'SKILL.md').is_file():
                raise ValueError(f'Missing SKILL.md: {source}')
            desired = digest(source)
            for root in ROOTS:
                # Preserve Claude's bundled command and its native invocation semantics.
                if root == '.claude/skills' and source.name == 'simplify':
                    continue
                destination = self.home / root / source.name
                real_parents(destination, self.home)
                relative = str(destination.relative_to(self.home))
                if destination.exists() or destination.is_symlink():
                    current = digest(destination)
                    if current not in (desired, previous.get(relative)):
                        raise ValueError(f'Local edits/unmanaged skill: {destination}; save and resolve first')
                result.append((source, destination, relative, desired))
        return result

    def links(self):
        result = []
        for tool in TOOLS:
            link = self.home / '.local/bin' / tool
            target = self.runtime / '.venv/bin' / tool
            real_parents(link, self.home)
            if link.exists() or link.is_symlink():
                if not link.is_symlink() or link.readlink() != target:
                    raise ValueError(f'Refusing to overwrite executable: {link}')
            result.append((link, target))
        return result

    def recipe_hash(self):
        sha = hashlib.sha256()
        for name in ('pyproject.toml', 'uv.lock', '.python-version'):
            sha.update(name.encode() + b'\0' + (self.recipe / name).read_bytes())
        return sha.hexdigest()

    def copy_skills(self, plan):
        records = self.records()
        for source, destination, relative, desired in plan:
            if not destination.exists() or digest(destination) != desired:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with tempfile.TemporaryDirectory(prefix='.dotfiles-skill-', dir=destination.parent) as tmp:
                    stage = Path(tmp) / 'new'
                    shutil.copytree(source, stage)
                    backup = Path(tmp) / 'old'
                    if destination.exists():
                        destination.rename(backup)
                    try:
                        stage.rename(destination)
                    except BaseException:
                        if backup.exists():
                            backup.rename(destination)
                        raise
            records[relative] = desired
            # Record completed copies incrementally; a partial run can be resumed.
            atomic_json(self.state, {'version': 1, 'skills': records})

    def install(self):
        plan = self.plan()  # Refuse all known conflicts before touching runtime or skills.
        links = self.links()
        real_parents(self.runtime / '.venv', self.home)
        env = {**os.environ, 'UV_PROJECT_ENVIRONMENT': str(self.runtime / '.venv'),
               'PYTHONDONTWRITEBYTECODE': '1'}
        subprocess.run(['uv', 'sync', '--project', str(self.recipe), '--locked'], env=env, check=True)
        subprocess.run([str(self.runtime / '.venv/bin/pytest'), '-q', '-p', 'no:cacheprovider',
                        str(self.recipe / 'tests')], env=env, check=True)
        self.copy_skills(plan)
        for link, target in links:
            link.parent.mkdir(parents=True, exist_ok=True)
            if not link.is_symlink():
                link.symlink_to(target)
        (self.runtime / '.dotfiles-recipe.sha256').write_text(self.recipe_hash() + '\n')
        self.verify()

    def verify(self):
        records = self.records()
        for _, destination, relative, desired in self.plan():
            if not destination.exists() or digest(destination) != desired:
                raise ValueError(f'Missing or stale skill copy: {destination}')
            if records.get(relative) != desired:
                raise ValueError(f'Missing or stale ownership record: {destination}')
        for link, target in self.links():
            if not link.is_symlink() or not target.is_file() or not os.access(target, os.X_OK):
                raise ValueError(f'Missing executable link or runtime: {link}')
        receipt = self.runtime / '.dotfiles-recipe.sha256'
        if not receipt.is_file() or receipt.read_text().strip() != self.recipe_hash():
            raise ValueError('Tool recipe changed or not installed; run make agent-skills')
        print('Agent skills: copied directories, ownership records, CLI links and tool recipe verified')


@contextmanager
def install_lock(home):
    directory = home / '.local/state/dotfiles'
    real_parents(directory / 'agent-skills.lock', home)
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / 'agent-skills.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('install', 'verify'))
    args = parser.parse_args()
    deployment = Deployment()
    try:
        from agent_sources import validate_sources
        validate_sources()
        if args.action == 'install':
            with install_lock(deployment.home):
                deployment.install()
        else:
            deployment.verify()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Agent skills: {error}\n')


if __name__ == '__main__':
    main()
