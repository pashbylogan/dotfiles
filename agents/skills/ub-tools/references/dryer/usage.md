# Dryer

Locally maintained integration notes, not upstream-authored.
The pinned upstream CLI is installed at `~/.local/bin/dryer`.
Read `upstream.md` beside this file for normalization details.

Run from the project root:

```sh
dryer --help
dryer --threshold 0.8 path/to/source
dryer --threshold 0.8 --changed
```

- Supports Clojure, Java, Go, TypeScript/JavaScript, Rust, and Python. Only compares forms in the same language.
- Set `--threshold 0.8` explicitly for ub-mode; the upstream default is 0.82.
- Defaults omit candidates below four source lines or twenty normalized nodes. A clean report is not evidence that smaller duplicates do not exist. Broaden with `--min-lines` / `--min-nodes` only when useful.
- Scores describe structural similarity, not semantic equivalence. Inspect both sides; consolidate shared domain decisions rather than introducing an abstraction merely because code looks alike.
- Output: stdout plus `.metrics/dry.edn`. A normal report exits 0 even when duplicates exist: inspect candidates instead of treating exit status as a quality gate.
- Pin behavior with tests before consolidating; rerun tests and dryer afterward.
- Follow project policy for generated metrics; report scope, threshold, reviewed candidates, justified exceptions, and remaining duplication.
