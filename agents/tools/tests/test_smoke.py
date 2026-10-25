"""Exercise installed CLIs in disposable projects; never mutate a user's repo."""
import os
from pathlib import Path
import shlex
import subprocess
import sys

import pytest

# Runtime stays disposable; dotfiles owns the recipe and tests. [D-AGENT-SKILLS]
ROOT = Path.home() / '.local/share/unclebob-tools'


def run(tool, cwd, *args):
    result = subprocess.run(
        [str(ROOT / '.venv/bin' / tool), *args], cwd=cwd,
        text=True, capture_output=True, timeout=90,
        env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'},
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


@pytest.fixture
def project(tmp_path):
    (tmp_path / 'demo.py').write_text(
        'def first(x):\n'
        '    y = abs(x)\n'
        '    z = y + 1\n'
        '    return z\n\n'
        'def second(value):\n'
        '    amount = abs(value)\n'
        '    result = amount + 1\n'
        '    return result\n'
    )
    return tmp_path


def test_crapper(project):
    output = run('crapper', project, '--no-coverage', 'demo.py')
    assert 'first' in output and 'second' in output
    assert 'N/A' in output
    assert (project / '.metrics/crap.edn').is_file()


def test_dryer(project):
    output = run('dryer', project, '--threshold', '0.8', '--min-nodes', '1', 'demo.py')
    assert 'DUPLICATE' in output
    assert (project / '.metrics/dry.edn').is_file()


def test_mutator(project):
    original = (project / 'demo.py').read_bytes()
    output = run('mutator', project, '--scan', 'demo.py')
    assert 'demo.py' in output
    assert not (project / '.metrics').exists()
    # Test the crapper integration, worker overlays, baseline, and killed mutations.
    check = (
        'from demo import first, second\n'
        'for f in (first, second):\n'
        '    assert f(-2) == 3\n'
        '    assert f(0) == 1\n'
    )
    # -c imports from the worker cwd; a symlinked script can import the original.
    run('mutator', project, '--no-coverage', '--max-workers', '2',
        '--test-command',
        f'{shlex.quote(sys.executable)} -B -c {shlex.quote(check)}', 'demo.py')
    assert list((project / '.metrics/mutate').glob('*.edn'))
    assert (project / 'demo.py').read_bytes() == original
