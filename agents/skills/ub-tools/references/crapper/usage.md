# Crapper

Locally maintained integration notes, not upstream-authored.
The pinned upstream CLI is installed at `~/.local/bin/crapper`.
Read `upstream.md` beside this file for language-specific behavior.

Run from the project root, targeting changed files first:

```sh
crapper --help
crapper --use-existing-coverage path/to/source
crapper --no-coverage path/to/source
```

- Supports Clojure, Java, Go, TypeScript/JavaScript, Rust, and Python.
- Default runs regenerate coverage, run project tests, and may install missing coverage dependencies into the project. Inspect project scripts first and obtain permission before unrequested dependency changes or expensive runs. Prefer `--use-existing-coverage` when appropriate; disclose stale or missing reports.
- `--no-coverage` measures complexity only: CRAP and coverage are unknown, not passing.
- Failed tests or missing tools can yield zero coverage while analysis still produces a report. A successful analysis is not proof of a passing test suite.
- Output: stdout plus `.metrics/crap.edn` in the project. Do not commit generated metrics without following project policy.
- ub-mode requires each function's CRAP strictly below 10. `--threshold 10` exits 2 only for values *above* 10, so explicitly inspect equality at 10; do not present that flag as an exact ub-mode gate.
- Reproduce high scores, improve behavioral tests or simplify the function, then rerun. Do not refactor solely to game the metric.
- Report scope, coverage provenance, test failures, worst scores, remaining violations, and generated files.
