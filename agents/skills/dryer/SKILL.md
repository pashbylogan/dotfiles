---
name: dryer
description: Find structural code duplication with Uncle Bob's dryer. Use for ub-mode duplication checks, duplicate-code review, or before consolidating similar functions.
---

# Dryer

This is a locally maintained integration skill, not an upstream-authored skill.
The pinned upstream CLI is installed at `~/.local/bin/dryer`.
Read `references/upstream.md` beside this skill for normalization details.

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

Maintenance: the `agents/` directory in your dotfiles checkout (see its README).
