#!/usr/bin/env python3
"""Offline source validation or explicit read-only upstream checks. [D-AGENT-SKILLS]"""
import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tomllib

REPO = Path(__file__).resolve().parents[2]


def validate_sources(repo=REPO):
    agents = Path(repo) / 'agents'
    data = tomllib.loads((agents / 'sources.toml').read_text())
    if data.get('version') != 1:
        raise ValueError('Unsupported agents/sources.toml version')
    skills = data.get('skills', {})
    actual = {p.name for p in (agents / 'skills').iterdir() if p.is_dir()}
    if set(skills) != actual:
        raise ValueError('Skill inventory differs from sources.toml')
    dependencies = tomllib.loads((agents / 'tools/pyproject.toml').read_text())['project']['dependencies']
    lock = tomllib.loads((agents / 'tools/uv.lock').read_text())
    packages = {p['name']: p for p in lock['package']}
    resources = []
    for name, skill in skills.items():
        if skill.get('kind') not in ('local', 'vendored'):
            raise ValueError(f'Unknown source kind: {name}')
        if not (agents / 'skills' / name / 'SKILL.md').is_file():
            raise ValueError(f'Missing SKILL.md: {name}')
        if skill['kind'] == 'local':
            if set(skill.get('reference_tools', [])) - set(data.get('tools', {})):
                raise ValueError(f'Unknown reference tool: {name}')
            continue
        hashes = skill.get('sha256', {})
        if not hashes:
            raise ValueError(f'Vendored skill needs file hashes: {name}')
        root = agents / 'skills' / name
        files = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()}
        if set(hashes) != files:
            raise ValueError(f'Vendored file inventory differs: {name}')
        for relative, expected in hashes.items():
            path = root / relative
            if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
                raise ValueError(f'Invalid vendored path: {name}/{relative}')
            if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise ValueError(f'Vendored content changed: {name}/{relative}; review and record its source')
        resources.append((f'skill/{name}', skill))
    for name, tool in data.get('tools', {}).items():
        pin = f"{name} @ git+{tool['repository']}@{tool['commit']}"
        if pin not in dependencies:
            raise ValueError(f'Tool recipe differs from source manifest: {name}')
        source = packages.get(name, {}).get('source', {}).get('git', '')
        if not source.startswith(tool['repository']) or not source.endswith('#' + tool['commit']):
            raise ValueError(f'uv.lock differs from source manifest: {name}')
        resources.append((f'tool/{name}', tool))
    for name, source in resources:
        if not re.fullmatch(r'[0-9a-f]{40}', source.get('commit', '')):
            raise ValueError(f'Expected a full reviewed commit: {name}')
        if not source.get('repository', '').startswith('https://') or not source.get('license'):
            raise ValueError(f'Missing HTTPS repository or license provenance: {name}')
    return resources


def check_updates(resources, runner=subprocess.run):
    failures = 0
    for name, source in resources:
        try:
            result = runner(['git', 'ls-remote', '--exit-code', source['repository'], source.get('ref', 'HEAD')],
                            capture_output=True, text=True, check=True, timeout=30,
                            env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'})
            rows = result.stdout.splitlines()
            if len(rows) != 1 or not re.fullmatch(r'[0-9a-f]{40}', rows[0].split()[0]):
                raise ValueError('upstream ref did not resolve to one commit')
            latest = rows[0].split()[0]
            status = 'CURRENT' if latest == source['commit'] else 'CHANGED (review required)'
            print(f"{name}: {status}; pinned={source['commit']} upstream={latest}")
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            failures += 1
            print(f'{name}: check failed ({type(error).__name__}); no files changed')
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('verify', 'check-updates'))
    args = parser.parse_args()
    try:
        resources = validate_sources()
        if args.action == 'check-updates':
            raise SystemExit(1 if check_updates(resources) else 0)
        print('Agent sources: inventory, vendored hashes, recipe and lockfile pins verified (offline)')
    except (KeyError, ValueError, OSError) as error:
        parser.exit(1, f'Agent sources: {error}\n')


if __name__ == '__main__':
    main()
